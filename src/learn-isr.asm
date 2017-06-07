; UMR2
; copyright John Staskevich, 2017
; john@codeandcopper.com
;
; This work is licensed under a Creative Commons Attribution 4.0 International License.
; http://creativecommons.org/licenses/by/4.0/
;
; learn-isr.asm
;
; Interrupt service routines for "learning" about host key matrix
;
		list p=16F1939
		#include	<p16f1939.inc>
		#include	<umr2.inc>

; ==================================================================
; ==================================================================
;
; Learn-Mode ISR
;
; ==================================================================
; ==================================================================

isr_learn_vector	code	0x1004
	GLOBAL	isr_learn_vector
isr_learn_vector
;	goto	isr_learn
;isr_learn	code
isr_learn

; New context
		clrf	BSR

; Check for serial receive
		btfsc	PIR1,RCIF
		goto	handle_rx_learn

; Check for timer0 expiry
		btfsc	INTCON,TMR0IF
		goto	handle_timer_0_learn

		retfie

; =================================
;
; process incoming midi byte
;
; =================================

handle_rx_learn

; Grab the incoming byte
		banksel	RCREG
		movfw	RCREG
		movwf	TEMP_ISR
		banksel	PORTA
; Check if first note has been received yet.
		btfss	STATE_FLAGS,3
		goto	handle_rx_learn_process

; shut down the RX
		banksel	PIE1
		bcf	PIE1,RCIE
		retfie

handle_rx_learn_process
; If byte is a data byte, process it
		btfss	TEMP_ISR,7
		goto	process_data_byte_learn

process_status_byte_learn
; Don't let real time messages interrupt running status - check for them now
; real time message is status B'11111xxx'
		comf	TEMP_ISR,w
		andlw	B'11111000'
		btfsc	STATUS,Z
		retfie
; Check for note-on (0x9?)
		movlw	B'11110000'
		andwf	TEMP_ISR,w
		sublw	0x90
		bz	flag_note_on_learn
; All other status bytes and subsequent data are ignored.
ignore_message_learn
; Data will be ignored for other status bytes.
		clrf	MESSAGE_TYPE
		retfie

flag_note_on_learn
		movlw	NOTE_ON
		movwf	MESSAGE_TYPE
; store note-on status.  We'll use channel later.
		movfw	TEMP_ISR
		movwf	NOTE_ON_STATUS
; reset byte count
		bcf	STATE_FLAGS,1
		retfie

process_data_byte_learn
; always store the first data byte
		btfss	STATE_FLAGS,1
		goto	store_d0_learn

; second data byte.  reset byte count and check for relevant status
		bcf	STATE_FLAGS,1
; ignore data for message other than note on
		btfsc	MESSAGE_TYPE,1
		goto	process_note_on_learn
		retfie

store_d0_learn
		movfw	TEMP_ISR
		movwf	INBOUND_D0
		bsf	STATE_FLAGS,1
		retfie

; =================================
;
; handle Note On message
;
; =================================

process_note_on_learn
; Check for zero velocity (note off)
		movf	TEMP_ISR,f
		btfsc	STATUS,Z
		retfie

; store the note number.
		movfw	INBOUND_D0
		movwf	FIRST_NOTE

; advance to next step in learn procedure
		bsf	STATE_FLAGS,3
		retfie

; =================================
;
; handle Timer 0 expiry
;
; =================================

handle_timer_0_learn
; blinking STBY LED stuff
		bcf	INTCON,TMR0IF
		decfsz	COUNTER_T0,f
		retfie

		movlw	COUNTER_T0_MAX
		movwf	COUNTER_T0
		movlw	B'00000100'
		xorwf	PORTC,f
		retfie

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

		end

