; UMR2
; copyright John Staskevich, 2017
; john@codeandcopper.com
;
; This work is licensed under a Creative Commons Attribution 4.0 International License.
; http://creativecommons.org/licenses/by/4.0/
;
; checksum.asm
;
; Checksum the application firmware image.
;
		list p=16F1939
		#include	<p16f1939.inc>
		#include	<umr2.inc>

checksum_code		code	0x740

; =================================
;
; Flush the RX buffer
;
; ================================

	GLOBAL	compute_checksum
compute_checksum

; checksum the firmware
		clrf	TEMP
		clrf	TEMP_2
		banksel	EEADRL
		clrf	EEADRL
		clrf	EEADRH
		bsf		EECON1,EEPGD

; add all opcodes from 0x0000 to 0x1FFF
checksum_loop
		bsf		EECON1,RD
		nop
		nop
		movfw	EEDATL
		addwf	TEMP,f
		movfw	EEDATH
		addwfc	TEMP_2,f
; increment program address
		incfsz	EEADRL,f
		goto	checksum_loop
		incf	EEADRH,f
		btfss	EEADRH,5
		goto	checksum_loop

; sum value is now in TEMP_2,TEMP
		movlw	PROM_CHECKSUM
		movwf	EEADRL
		bcf		EECON1,EEPGD
		bsf		EECON1,RD
		movfw	EEDATL
		movwf	TEMP_4
		incf	EEADRL,f
		bsf		EECON1,RD
		movfw	EEDATL
		movwf	TEMP_3

; complement value is now in TEMP_4,TEMP_3
		bsf		STATUS,C
		movfw	TEMP_3
		addwfc	TEMP,f
		movfw	TEMP_4
		addwfc	TEMP_2,f

; check for zero
		movfw	TEMP_2
		bnz		checksum_error
		movfw	TEMP
		bnz		checksum_error

checksum_ok
; continue with init
		clrf	BSR
		return

checksum_error
; blink the activity LED and do nothing.
		clrf	BSR
; blink off
checksum_error_blink
		movlw	B'00001100'
		movwf	PORTC
		clrf	COUNTER_L
		clrf	COUNTER_M
		movlw	0x08
		movwf	COUNTER_H
error_loop_a
		nop
		decfsz	COUNTER_L,f
		goto	error_loop_a
		decfsz	COUNTER_M,f
		goto	error_loop_a
		decfsz	COUNTER_H,f
		goto	error_loop_a

; blink on
		movlw	B'00000100'
		movwf	PORTC
		clrf	COUNTER_L
		clrf	COUNTER_M
		movlw	0x08
		movwf	COUNTER_H
error_loop_b
		nop
		decfsz	COUNTER_L,f
		goto	error_loop_b
		decfsz	COUNTER_M,f
		goto	error_loop_b
		decfsz	COUNTER_H,f
		goto	error_loop_b

		goto	checksum_error_blink

; should never execute here.
		return
		end
