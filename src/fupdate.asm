; UMR2
; copyright John Staskevich, 2017
; john@codeandcopper.com
;
; This work is licensed under a Creative Commons Attribution 4.0 International License.
; http://creativecommons.org/licenses/by/4.0/
;
; fupdate.asm
;
; bootloader / firmware update over MIDI
;
		list p=16F1939
		#include	<p16f1939.inc>
		#include	<umr2.inc>
; =================================
;
; Firmware Update ISR
;
; =================================
isr_fupdate_code code 0x0100

; ==================================================================
;
; firmware update--all functionality in isr.
;
; ==================================================================

; STATE_FLAGS alternative bits
; 0 - Sysex has begun and we're listening
; 1 - Sysex Header is Valid
; 2 - 
; 3 - Firmware Update Mode (isr selector)
; 4 - Current chunk is checksum
; 5 - Current chunk is code
; 6 - 
; 7 - 

		GLOBAL	isr_fupdate
isr_fupdate
; new context
		clrf	STATUS
		clrf	BSR
;		clrf	PCLATH
; check for RX interrupt
		btfsc	PIR1,RCIF
		goto	fupdate_handle_rx
; no other interrupts should be on!
		goto	fupdate_sysex_error


fupdate_handle_rx
; Grab the RX byte
		banksel	RCREG
		movfw	RCREG
;		movwf	TXREG
		movwf	TEMP
		clrf	BSR

;		retfie

; is SysEx begin?
		movlw	0xF0
		subwf	TEMP,w
		bz		fupdate_sysex_begin

; is SysEx end?
		movlw	0xF7
		subwf	TEMP,w
		bz		fupdate_sysex_end

; real time status (ignored)?
		movfw	TEMP
		andlw	B'11111000'
		sublw	B'11111000'
		bz		fupdate_isr_finish

; some other status?
		btfsc	TEMP,7
		goto	fupdate_sysex_error

; are we still checking?
		btfss	STATE_FLAGS,0
		goto	fupdate_isr_finish

; is the header complete?
		btfsc	STATE_FLAGS,1
		goto	fupdate_get_data

; check header for validity
fupdate_check
		incf	BYTE_COUNT,f
		movfw	BYTE_COUNT
		movwf	TEMP_2

fupdate_check_1
		decfsz	TEMP_2,f
		goto	fupdate_check_2
		movlw	0x00
		subwf	TEMP,w
		bnz		fupdate_sysex_error
		goto	fupdate_isr_finish
		
fupdate_check_2
		decfsz	TEMP_2,f
		goto	fupdate_check_3
		movlw	0x01
		subwf	TEMP,w
		bnz		fupdate_sysex_error
		goto	fupdate_isr_finish
		
fupdate_check_3
		decfsz	TEMP_2,f
		goto	fupdate_check_4
		movlw	0x5D
		subwf	TEMP,w
		bnz		fupdate_sysex_error
		goto	fupdate_isr_finish
		
fupdate_check_4
		decfsz	TEMP_2,f
		goto	fupdate_sysex_error
		movlw	0x07
		subwf	TEMP,w
		bnz		fupdate_sysex_error
; header now relevant
		bsf		STATE_FLAGS,1
; reset bytecount
		clrf	BYTE_COUNT
		goto	fupdate_isr_finish

fupdate_sysex_begin
; new message
		clrf	BYTE_COUNT
; incomplete
		bsf		STATE_FLAGS,0
; not yet relevant
		bcf		STATE_FLAGS,1
		goto	fupdate_isr_finish

fupdate_get_data
; check for chunk start
		incf	BYTE_COUNT,f
		movfw	BYTE_COUNT
		movwf	TEMP_2

fupdate_get_1
		decfsz	TEMP_2,f
		goto	fupdate_get_chunk_body
		movlw	0x7E
		subwf	TEMP,w
		bz		fupdate_get_code_begin
		movlw	0x7F
		subwf	TEMP,w
		bz		fupdate_get_checksum_begin

		movfw	TEMP
		bnz		fupdate_sysex_error
; for zero byte, treat as filler and wait for a chunk start byte
		decf	BYTE_COUNT,f
		goto	fupdate_isr_finish

fupdate_get_chunk_body
		btfsc	STATE_FLAGS,5
		goto	fupdate_get_code_chunk
		btfsc	STATE_FLAGS,4
		goto	fupdate_get_checksum_chunk
		goto	fupdate_sysex_error

fupdate_get_code_begin
; set the code chunk flag
		bsf		STATE_FLAGS,5
; clear the code counter
		clrf	TEMP_3
		goto	fupdate_isr_finish

fupdate_get_checksum_begin
; set the checksum chunk flag
		bsf		STATE_FLAGS,4
		goto	fupdate_isr_finish

fupdate_get_checksum_chunk
fg_sum_1
		decfsz	TEMP_2,f
		goto	fg_sum_2
; checksum low data
		movfw	TEMP
		movwf	TEMP_4
		goto	fupdate_isr_finish
fg_sum_2
		decfsz	TEMP_2,f
		goto	fg_sum_3
; checksum low check
		movfw	TEMP_4
		addlw	B'10000000'
		addwf	TEMP,f
		incfsz	TEMP,f
		goto	fupdate_sysex_error
		goto	fupdate_isr_finish
fg_sum_3
		decfsz	TEMP_2,f
		goto	fg_sum_4
; checksum mid data
		movfw	TEMP
		movwf	TEMP_6
		goto	fupdate_isr_finish
fg_sum_4
		decfsz	TEMP_2,f
		goto	fg_sum_5
; checksum mid check
		movfw	TEMP_6
		addlw	B'10000000'
		addwf	TEMP,f
		incfsz	TEMP,f
		goto	fupdate_sysex_error
		goto	fupdate_isr_finish
fg_sum_5
		decfsz	TEMP_2,f
		goto	fg_sum_6
; checksum high data
		movfw	TEMP
		movwf	TEMP_7
		goto	fupdate_isr_finish
fg_sum_6
		decfsz	TEMP_2,f
		goto	fg_sum_7
; checksum high check
		movfw	TEMP_7
		addlw	B'10000000'
		addwf	TEMP,f
		incfsz	TEMP,f
		goto	fupdate_sysex_error
; move all 16 bits to TEMP_6,TEMP_4
		btfsc	TEMP_6,0
		bsf		TEMP_4,7
		btfsc	TEMP_7,0
		bsf		TEMP_6,7
		bcf		STATUS,C
		rrf		TEMP_6,f
		btfsc	TEMP_7,1
		bsf		TEMP_6,7
		goto	fupdate_isr_finish
fg_sum_7
		decfsz	TEMP_2,f
		goto	fg_sum_8
; version data
		movfw	TEMP
		movwf	TEMP_7
		goto	fupdate_isr_finish
fg_sum_8
		decfsz	TEMP_2,f
		goto	fupdate_sysex_error
; version check
		movfw	TEMP_7
		addlw	B'10000000'
		addwf	TEMP,f
		incfsz	TEMP,f
		goto	fupdate_sysex_error
; store the checksum & version to data EEPROM
; store to EEPROM
; turn off all interrupts
		bcf		INTCON,GIE
		btfsc	INTCON,GIE
		goto	$-2
; make sure any writes are complete
		banksel	EECON1
		btfsc	EECON1,WR
		goto	$-1
; write version
		movfw	TEMP_7
		movwf	EEDATL
		movlw	PROM_VERSION
		movwf	EEADRL
		bcf		EECON1,EEPGD
		bsf		EECON1,WREN
		movlw	0x55
		movwf	EECON2
		movlw	0xAA
		movwf	EECON2
		bsf		EECON1,WR
; make sure any writes are complete
		btfsc	EECON1,WR
		goto	$-1
; write high byte
		movfw	TEMP_6
		movwf	EEDATL
		incf	EEADRL,f
		bsf		EECON1,WREN
		movlw	0x55
		movwf	EECON2
		movlw	0xAA
		movwf	EECON2
		bsf		EECON1,WR
; make sure any writes are complete
		btfsc	EECON1,WR
		goto	$-1
; write low byte
		movfw	TEMP_4
		movwf	EEDATL
		incf	EEADRL,f
		bcf		EECON1,EEPGD
		bsf		EECON1,WREN
		movlw	0x55
		movwf	EECON2
		movlw	0xAA
		movwf	EECON2
		bsf		EECON1,WR
; make sure any writes are complete
		btfsc	EECON1,WR
		goto	$-1
; shut off activity LED and wait for user to power cycle
		clrf	BSR
		movlw	B'11001100'
		movwf	PORTC
fupdate_wait_for_reset
		goto	fupdate_wait_for_reset

fupdate_get_code_chunk
fg_code_1
		decfsz	TEMP_2,f
		goto	fg_code_2
; address low data
		movfw	TEMP
		movwf	TEMP_6
		goto	fupdate_isr_finish

fg_code_2
		decfsz	TEMP_2,f
		goto	fg_code_3
; address low check
		movfw	TEMP_6
		addlw	B'10000000'
		addwf	TEMP,f
		incfsz	TEMP,f
		goto	fupdate_sysex_error
		goto	fupdate_isr_finish

fg_code_3
		decfsz	TEMP_2,f
		goto	fg_code_4
; address high data
		movfw	TEMP
		movwf	TEMP_7
		goto	fupdate_isr_finish

fg_code_4
		decfsz	TEMP_2,f
		goto	fg_code_5
; address high check
		movfw	TEMP_7
		addlw	B'10000000'
		addwf	TEMP,f
		incfsz	TEMP,f
		goto	fupdate_sysex_error
; change address from 7:7 to 6:8
		btfsc	TEMP_7,0
		bsf		TEMP_6,7
		bcf		STATUS,C
		rrf		TEMP_7,f
		goto	fupdate_isr_finish

fg_code_5
		decfsz	TEMP_2,f
		goto	fg_code_6
; opcode low data
		movfw	TEMP
;		movwf	TEMP_4
		movwf	TEMP_5
		goto	fupdate_isr_finish

fg_code_6
		decfsz	TEMP_2,f
		goto	fg_code_7
; opcode low check
;		movfw	TEMP_4
		movfw	TEMP_5
		addlw	B'10000000'
		addwf	TEMP,f
		incfsz	TEMP,f
		goto	fupdate_sysex_error
		goto	fupdate_isr_finish

fg_code_7
		decfsz	TEMP_2,f
		goto	fg_code_8
; opcode high data
		movfw	TEMP
		movwf	TEMP_4
		goto	fupdate_isr_finish

fg_code_8
		decfsz	TEMP_2,f
		goto	fupdate_sysex_error
; opcdode high check
		movfw	TEMP_4
		addlw	B'10000000'
		addwf	TEMP,f
		incfsz	TEMP,f
		goto	fupdate_sysex_error
; ok--munged opcode is now TEMP_4(7) : TEMP_5 (7)
; change from 7:7 to 6:8
		btfsc	TEMP_4,0
		bsf		TEMP_5,7
		bcf		STATUS,C
		rrf		TEMP_4,f
; ok--munged opcode is now in TEMP_4:TEMP_5
; de-munge the opcode
		movfw	TEMP_4
		bnz		demunge_check_clrw
; high byte is zero--
; no operations necessary.
		goto	fg_code_store

; clrw   (1 0000 0000)
demunge_check_clrw
		movfw	TEMP_4
		sublw	0x01
		bnz		demunge_bit_oriented
		movfw	TEMP_5
		bz		fg_code_store

; de-munge the bit-oriented opcodes
; use the opcode counter to cycle modifications
demunge_bit_oriented
; bit oriented instructions are 01 iibb bfff ffff
; check for the 01
		movfw	TEMP_4
		andlw	B'00110000'
		sublw	B'00010000'
		bnz		demunge_reg_lit

		btfsc	TEMP_3,1
		goto	demunge_bit_oriented_1x
demunge_bit_oriented_0x
		btfsc	TEMP_3,0
		goto	demunge_bit_oriented_01
demunge_bit_oriented_00
		movlw	B'00001001'
		xorwf	TEMP_4,f
		goto	demunge_reg_lit
demunge_bit_oriented_01
		movlw	B'00000010'
		xorwf	TEMP_4,f
		goto	demunge_reg_lit
demunge_bit_oriented_1x
		btfsc	TEMP_3,0
		goto	demunge_bit_oriented_11
demunge_bit_oriented_10
		movlw	B'00001110'
		xorwf	TEMP_4,f
		goto	demunge_reg_lit
demunge_bit_oriented_11
		movlw	B'00000101'
		xorwf	TEMP_4,f

; de-munge the registers & literals
; use the opcode counter to cycle modifications
demunge_reg_lit
		btfsc	TEMP_3,1
		goto	demunge_reg_lit_1x
demunge_reg_lit_0x
		btfsc	TEMP_3,0
		goto	demunge_reg_lit_01
demunge_reg_lit_00
		movlw	B'00011011'
		xorwf	TEMP_5,f
		goto	fg_code_store
demunge_reg_lit_01
		movlw	B'00100001'
		xorwf	TEMP_5,f
		goto	fg_code_store
demunge_reg_lit_1x
		btfsc	TEMP_3,0
		goto	demunge_reg_lit_11
demunge_reg_lit_10
		movlw	B'00000111'
		xorwf	TEMP_5,f
		goto	fg_code_store
demunge_reg_lit_11
		movlw	B'00110010'
		xorwf	TEMP_5,f


fg_code_store
; store opcode low byte in buffer
		clrf	FSR0H
		movlw	FIRMWARE_BUFFER
		movwf	FSR0L
		movfw	TEMP_3
		addwf	FSR0L,f
		addwf	FSR0L,f
		movfw	TEMP_5
		movwf	INDF0
; store opcode high byte in buffer
		incf	FSR0L,f
		movfw	TEMP_4
		movwf	INDF0
; increment the opcode counter
		incf	TEMP_3,f
; check for chunk completion
		movlw	D'32'
		subwf	TEMP_3,w
		bz	fg_code_chunk_complete
; prepare bytecount for next 4-byte opcode
		movlw	0x04
		subwf	BYTE_COUNT,f
		goto	fupdate_isr_finish

fg_code_chunk_complete
; write the code chunk to program EEPROM
; disable interrupts
		bcf		INTCON,GIE
		btfsc	INTCON,GIE
		goto	$-2

;		goto	fupdate_flush

;;;;
; erase EEPROM block before write
;;;;
		banksel	EEADRH
		movfw	TEMP_7
		movwf	EEADRH
		movfw	TEMP_6
		movwf	EEADRL
		bsf		EECON1,EEPGD
		bsf		EECON1,WREN
		bsf		EECON1,FREE
		movlw	0x55
		movwf	EECON2
		movlw	0xAA
		movwf	EECON2
		bsf		EECON1,WR
		nop
		nop
		bcf		EECON1,FREE
		bcf		EECON1,WREN
;;;;
; write code to EEPROM
;;;;
; FSR0L points to code buffer
		clrf	FSR0H
		movlw	FIRMWARE_BUFFER
		movwf	FSR0L
; EEADRH:EEADR point to program chunk to write
		movfw	TEMP_7
		movwf	EEADRH
		movfw	TEMP_6
		movwf	EEADRL
; EECON1 stuff
		bsf		EECON1,WREN
; 32 words to write
		movlw	D'32'
		movwf	TEMP
fg_code_write_loop
; set up the opcode
		moviw	INDF0++
		movwf	EEDATL
		moviw	INDF0++
		movwf	EEDATH
; clear LWLO only for last of groups of 8 words
; ---> EEADRL[2:0] = B'111'
		bsf		EECON1,LWLO
		movf	EEADRL,w
		xorlw	0x07
		andlw	0x07
		btfsc	STATUS,Z
		bcf		EECON1,LWLO
fg_code_write_trigger
; trigger the write
		movlw	0x55
		movwf	EECON2
		movlw	0xAA
		movwf	EECON2
		bsf		EECON1,WR
		nop
		nop
; next opcode
		incf	EEADR,f
; in aligned 32-word chunk, EEADRH is never incremented
		decfsz	TEMP,f
		goto	fg_code_write_loop
		bcf		EECON1,WREN

fupdate_flush
; flush RX
		banksel	RCREG
		movfw	RCREG
		movfw	RCREG
		banksel	PIR1
		bcf		PIR1,5
		banksel	RCREG
		bcf		RCSTA,4
		bsf		RCSTA,4
		clrf	BSR
; re-enable interrupts
		bsf		INTCON,GIE
; clear the code chunk flag
		bcf		STATE_FLAGS,5
; reset the bytecount
		clrf	BYTE_COUNT
; wait for more chunks
		goto	fupdate_isr_finish


fupdate_sysex_end
; execution here is an error condition
; ignore other data
		bcf		STATE_FLAGS,1
		bcf		STATE_FLAGS,0
; clear LED
		clrf	BSR
; porta read-mod-write ok here
;		bsf		PORTA,0
		goto	$-1


fupdate_sysex_error
; ignore rest of message.
		bcf		STATE_FLAGS,1
		bcf		STATE_FLAGS,0
; blink the activity LED and do nothing.
		clrf	BSR
; blink off
fupdate_error_blink
		movlw	B'11001100'
		movwf	PORTC
		clrf	COUNTER_L
		clrf	COUNTER_H
		nop
		nop
		nop
		nop
		decfsz	COUNTER_L,f
		goto	$-5
		decfsz	COUNTER_H,f
		goto	$-7

; blink on
		movlw	B'11000100'
		movwf	PORTC
		clrf	COUNTER_L
		clrf	COUNTER_H
		nop
		nop
		nop
		nop
		decfsz	COUNTER_L,f
		goto	$-5
		decfsz	COUNTER_H,f
		goto	$-7
		goto	fupdate_error_blink

fupdate_isr_finish
		retfie

		end

