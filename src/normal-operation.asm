; UMR2
; copyright John Staskevich, 2017
; john@codeandcopper.com
;
; This work is licensed under a Creative Commons Attribution 4.0 International License.
; http://creativecommons.org/licenses/by/4.0/
;
; isr.asm
;
; Main program loop
;
		list p=16F1939
		#include	<p16f1939.inc>
		#include	<umr2.inc>

; =================================
;
; Normal Operation
;
; =================================

start_normal_vector code	0x0800
	GLOBAL	start_normal_vector
start_normal_vector
	goto	start_normal
;start_normal code
start_normal	code	0x0C00
start_normal


; =================================
;
; Variable Init
;
; =================================
	clrf	STATE_FLAGS
; check mode
	btfss	PORTA,4
	bsf	STATE_FLAGS,4
; load channel and first note setting from data PROM.
	banksel	EEADRL
	movlw	PROM_CHANNEL
	movwf	EEADRL
	bcf	EECON1,EEPGD
	bsf	EECON1,RD
; store channel in TEMP
	movfw	EEDATL
	movwf	TEMP
; store first note in TEMP_2
	incf	EEADRL,f
	bsf	EECON1,RD
	movfw	EEDATL
	movwf	TEMP_2
; store setup flag in TEMP_3
	incf	EEADRL,f
	bsf	EECON1,RD
	movfw	EEDATL
	movwf	TEMP_3
	clrf	BSR
; init channel
	movfw	TEMP
	addlw	0x80
	movwf	NOTE_OFF_STATUS
	addlw	0x10
	movwf	NOTE_ON_STATUS
; init first note
	movfw	TEMP_2
	movwf	FIRST_NOTE
; if setup procedure has not been completed, don't operate.
;	btfss	TEMP_3,0	
;	goto	normal_no_setup

; wipe the key state buffer
; there are 512 bytes in buffer (9 select lines: 2^9 bytes)
	clrf	FSR0L
	movlw	0x22
	movwf	FSR0H
key_bit_wipe_loop
	clrf	INDF0
	incfsz	FSR0L,f
	goto	key_bit_wipe_loop

	incf	FSR0H,f
key_bit_wipe_loop2
	clrf	INDF0
	incfsz	FSR0L,f
	goto	key_bit_wipe_loop2

; set up pointer to key state bits
; INDF0 should point to 0x2200
	decf	FSR0H,f

; =================================
;
; Configure Timers
;
; =================================

; =================================
;
; LED Init
;
; =================================

; LED init & test
		clrf	PORTC
		call	blink_delay
		call	blink_delay
		call	blink_delay

; check matrix polarity
; if polarity input = high (pulled up), then clear PORTD bits
; if polarity input = low (pulled down), then set PORTD bits
		movlw	0xff
		movwf	PORTD
		btfsc	PORTC,5
		clrf	PORTD

; Reset Activity LED
		movlw	B'00001000'
		movwf	PORTC


; =================================
;
; MIDI Init
;
; =================================

; Flush the FIFO
		banksel	RCREG
		movfw	RCREG
		movfw	RCREG
; flush out any bytes & errors sitting around
		banksel	RCSTA
		bcf	RCSTA,CREN
; if TX mode, leave RX disabled.
		btfss	STATE_FLAGS,4
		bsf	RCSTA,CREN
		clrf	BSR
; Flush more
		banksel	RCREG
		movfw	RCREG
		movfw	RCREG
		clrf	BSR
; Enable Interrupts
		movlw	B'11000000'
		movwf	INTCON

; ==================================================================
; ==================================================================
;
; MAIN LOOP
;
; ==================================================================
; ==================================================================

; check mode.
		btfsc	STATE_FLAGS,4
		goto	go_tx
; check polarity.  If negative, we'll have to complement the select address.
		btfsc	PORTC,5
		goto	poll_rx_neg

; continuously load key states from select address onto data lines
poll_rx_pos
		movfw	PORTB
		movwf	FSR0L
		bcf	FSR0H,0
		btfsc	PORTA,0
		bsf	FSR0H,0
		bsf	BSR,0
		comf	INDF0,w
		movwf	TRISD
		clrf	BSR
		goto	poll_rx_pos

poll_rx_neg
		comf	PORTB,w
		movwf	FSR0L
		bcf	FSR0H,0
		btfss	PORTA,0
		bsf	FSR0H,0
		bsf	BSR,0
		comf	INDF0,w
		movwf	TRISD
		clrf	BSR
		goto	poll_rx_neg

go_tx
; sample select & data states to get defaults.
poll_tx_normal
; sample select & data.
		call	take_snapshot_normal
; is number of active select lines exactly 1?
		decfsz	TEMP_4,f
		goto	poll_tx_normal
; new key activity?
		call	point_to_key_data_normal
		movfw	TEMP_3
		xorwf	INDF0,w
		bz	poll_tx_normal
; store change bit pattern in TEMP_4
		movwf	TEMP_4
; does this key correspond to a note?
		call	point_to_tx_map_normal
		btfsc	INDF1,7
		goto	poll_tx_normal
; groom the change bitmask so it has only one bit set.
groom_0
		btfss	TEMP_4,0
		goto	groom_1
		movlw	B'00000001'
		movwf	TEMP_4
		goto	groom_complete
groom_1
		btfss	TEMP_4,1
		goto	groom_2
		movlw	B'00000010'
		movwf	TEMP_4
		goto	groom_complete
groom_2
		btfss	TEMP_4,2
		goto	groom_3
		movlw	B'00000100'
		movwf	TEMP_4
		goto	groom_complete
groom_3
		btfss	TEMP_4,3
		goto	groom_4
		movlw	B'00001000'
		movwf	TEMP_4
		goto	groom_complete
groom_4
		btfss	TEMP_4,4
		goto	groom_5
		movlw	B'00010000'
		movwf	TEMP_4
		goto	groom_complete
groom_5
		btfss	TEMP_4,5
		goto	groom_6
		movlw	B'00100000'
		movwf	TEMP_4
		goto	groom_complete
groom_6
		btfss	TEMP_4,6
		goto	groom_7
		movlw	B'01000000'
		movwf	TEMP_4
		goto	groom_complete
groom_7
		movlw	B'10000000'
		movwf	TEMP_4
groom_complete
; send note on or off
; LED indication
		clrf	PORTC
		clrf	TMR0
		bcf	INTCON,TMR0IF
		bsf	INTCON,TMR0IE
; internal note number is in INDF1
; put velocity in TEMP_5
		movlw	0x7F
		movwf	TEMP_5
		movfw	TEMP_4
		andwf	TEMP_3,w
		btfsc	STATUS,Z
		clrf	TEMP_5
		movfw	NOTE_ON_STATUS
		call	transmit_byte_normal
		movfw	INDF1
		addwf	FIRST_NOTE,w
		andlw	B'01111111'
		call	transmit_byte_normal
		movfw	TEMP_5
		call	transmit_byte_normal
; update key state.
		movfw	TEMP_4
		xorwf	INDF0,f
		goto	poll_tx_normal

; =================================
;
; delay to for slow LED blink
;
; =================================
blink_delay
		movlw	0xff
		movwf	COUNTER_H
blink_loop_a
		movlw	0xff
		movwf	COUNTER_L
blink_loop_b
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop

		decfsz	COUNTER_L,f
		goto	blink_loop_b
		decfsz	COUNTER_H,f
		goto	blink_loop_a

		return

; =================================
;
; take a snapshot of select and data lines
; select in TEMP_2:TEMP
;   data in        TEMP_3
;
; =================================
take_snapshot_normal
; TEMP: Select 8-1
		movfw	PORTB
		movwf	TEMP
; TEMP_2: Select 9
		movfw	PORTA
		movwf	TEMP_2
; TEMP_3: Data 1-8
		movfw	PORTD
		movwf	TEMP_3
; resample a to make sure snapshot is stable
		movfw	PORTB
		subwf	TEMP,w
		btfss	STATUS,Z
		return
		movfw	PORTA
		subwf	TEMP_2,w
		btfss	STATUS,Z
		return
		movfw	PORTD
		subwf	TEMP_3,w
		btfss	STATUS,Z
		return
; check matrix polarity
		btfss	PORTC,5
		goto	count_active_select_normal
; negative polarity. complement everything.
		comf	TEMP,f
		comf	TEMP_2,f
		comf	TEMP_3,f
count_active_select_normal
; sample is only valid if the number of active select lines is 1
; store number of active select lines in TEMP_4
		clrf	TEMP_4
		btfsc	TEMP,0
		incf	TEMP_4,f
		btfsc	TEMP,1
		incf	TEMP_4,f
		btfsc	TEMP,2
		incf	TEMP_4,f
		btfsc	TEMP,3
		incf	TEMP_4,f
		btfsc	TEMP,4
		incf	TEMP_4,f
		btfsc	TEMP,5
		incf	TEMP_4,f
		btfsc	TEMP,6
		incf	TEMP_4,f
		btfsc	TEMP,7
		incf	TEMP_4,f
		btfsc	TEMP_2,0
		incf	TEMP_4,f

		return

; =================================
;
; Set up FSR0 to point to key state data
; FSR0L is select line number from 0-8.
;
; =================================
point_to_key_data_normal
		clrf	FSR0H
		movlw	KEY_BITS
		movwf	FSR0L

		btfsc	TEMP,0
		return
		incf	FSR0L,f
		btfsc	TEMP,1
		return
		incf	FSR0L,f
		btfsc	TEMP,2
		return
		incf	FSR0L,f
		btfsc	TEMP,3
		return
		incf	FSR0L,f
		btfsc	TEMP,4
		return
		incf	FSR0L,f
		btfsc	TEMP,5
		return
		incf	FSR0L,f
		btfsc	TEMP,6
		return
		incf	FSR0L,f
		btfsc	TEMP,7
		return
; at this point, TEMP_2,0 is assumed to be set
		incf	FSR0L,f
		return

point_to_tx_map_normal
; tx map info.  one byte indexed by select 1-12 x data 1-8
		movlw	0xBC
		movwf	FSR1H
		movlw	0x80
		movwf	FSR1L
; point to correct block of 8.
point_to_tx_map_select_normal
		btfsc	TEMP,0
		goto	point_to_tx_map_data_normal
		movlw	D'8'
		addwf	FSR1L,f
		btfsc	TEMP,1
		goto	point_to_tx_map_data_normal
		movlw	D'8'
		addwf	FSR1L,f
		btfsc	TEMP,2
		goto	point_to_tx_map_data_normal
		movlw	D'8'
		addwf	FSR1L,f
		btfsc	TEMP,3
		goto	point_to_tx_map_data_normal
		movlw	D'8'
		addwf	FSR1L,f
		btfsc	TEMP,4
		goto	point_to_tx_map_data_normal
		movlw	D'8'
		addwf	FSR1L,f
		btfsc	TEMP,5
		goto	point_to_tx_map_data_normal
		movlw	D'8'
		addwf	FSR1L,f
		btfsc	TEMP,6
		goto	point_to_tx_map_data_normal
		movlw	D'8'
		addwf	FSR1L,f
		btfsc	TEMP,7
		goto	point_to_tx_map_data_normal
; at this point, TEMP_2,0 is assumed to be set
		movlw	D'8'
		addwf	FSR1L,f
; point to correct byte.
point_to_tx_map_data_normal
		btfsc	TEMP_4,0
		return
		incf	FSR1L,f
		btfsc	TEMP_4,1
		return
		incf	FSR1L,f
		btfsc	TEMP_4,2
		return
		incf	FSR1L,f
		btfsc	TEMP_4,3
		return
		incf	FSR1L,f
		btfsc	TEMP_4,4
		return
		incf	FSR1L,f
		btfsc	TEMP_4,5
		return
		incf	FSR1L,f
		btfsc	TEMP_4,6
		return
; at this point, TEMP_4,7 is assumed to be set.
		incf	FSR1L,f
		return


; =================================
;
; Send a MIDI byte from W register.
; Wait to make sure USART is ready.
;
; =================================
transmit_byte_normal
		nop
		nop
		btfss	PIR1,TXIF
		goto	$-1
		banksel	TXREG
		movwf	TXREG
		clrf	BSR
		return

; =================================
;
; operation halts if setup procedure was not completed.
;
; =================================
;normal_no_setup
;		movlw	B'00001100'
;		movwf	PORTC
;		call	blink_delay
;		movlw	B'00000000'
;		movwf	PORTC
;		call	blink_delay
;		goto	normal_no_setup

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

		end

