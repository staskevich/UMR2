; UMR2
; copyright John Staskevich, 2017
; john@codeandcopper.com
;
; This work is licensed under a Creative Commons Attribution 4.0 International License.
; http://creativecommons.org/licenses/by/4.0/
;
; normal-isr.asm
;
; Interrupt service routines.
;
		list p=16F1939
		#include	<p16f1939.inc>
		#include	<umr2.inc>

; ==================================================================
; ==================================================================
;
; ISR
;
; ==================================================================
; ==================================================================

isr_normal_vector	code	0x0804
	GLOBAL	isr_normal_vector
isr_normal_vector
;	goto	isr_normal
;isr_normal	code
isr_normal
; New context
		clrf	BSR

; Check for serial receive
		btfsc	PIR1,RCIF
		goto	handle_rx

; Check for timer0 expiry
		btfsc	INTCON,TMR0IF
		goto	handle_timer_0

		retfie

; =================================
;
; Handle Timer 0 expiry
;
; =================================

handle_timer_0
		bcf	INTCON,TMR0IE
		bcf	INTCON,TMR0IF
; Turn off blinked LED
		movlw	B'00001000'
		movwf	PORTC
		retfie

; =================================
;
; process incoming midi byte
;
; =================================

handle_rx
; Grab the incoming byte
		banksel	RCREG
		movfw	RCREG
		movwf	TXREG
		movwf	TEMP_ISR
		clrf	BSR

; If byte is a data byte, process it
		btfss	TEMP_ISR,7
		goto	process_data_byte

process_status_byte
; Don't let real time messages interrupt running status - check for them now
; real time message is status B'11111xxx'
		comf	TEMP_ISR,w
		andlw	B'11111000'
		btfsc	STATUS,Z
		retfie
; check for note-off (0x8?)
		movfw	NOTE_OFF_STATUS
		subwf	TEMP_ISR,f
		bz	flag_note_off
; Check for note-on (0x9?)
		movlw	0x10
		subwf	TEMP_ISR,f
		bz	flag_note_on
; All other status bytes and subsequent data are ignored.
ignore_message
; Data will be ignored for other status bytes.
		clrf	MESSAGE_TYPE
		retfie

flag_note_on
		movlw	NOTE_ON
		movwf	MESSAGE_TYPE
; reset byte count
		bcf	STATE_FLAGS,1
		retfie
flag_note_off
		movlw	NOTE_OFF
		movwf	MESSAGE_TYPE
; reset byte count
		bcf	STATE_FLAGS,1
		retfie


process_data_byte
; always store the first data byte
		btfss	STATE_FLAGS,1
		goto	store_d0

; second data byte.  reset byte count and check for relevant status
		bcf	STATE_FLAGS,1
; ignore data for message other than note off/on
		btfsc	MESSAGE_TYPE,0
		goto	process_note_off
		btfsc	MESSAGE_TYPE,1
		goto	process_note_on
		retfie

store_d0
; subtract first note from D0 to get internal note number.
; wrap at 128.
		movfw	FIRST_NOTE
		subwf	TEMP_ISR,w
		andlw	B'01111111'
		movwf	INBOUND_D0
		bsf	STATE_FLAGS,1
; blink activity LED
		clrf	PORTC
		clrf	TMR0
		bcf	INTCON,TMR0IF
		bsf	INTCON,TMR0IE
		retfie

; =================================
;
; handle Note Off message
;
; =================================

process_note_off
; clear the key bit for this note number.
		movfw	INBOUND_D0
		movwf	FSR0L
		movlw	0xBD
		movwf	FSR0H
; 3-byte record for each note number:
; - lo indirect address for keybits byte
		movfw	INDF0
		movwf	FSR1L
; - hi indirect address for keybits byte
		incf	FSR0H,f
		movfw	INDF0
		movwf	FSR1H
; - bitmask to apply to keybits byte
		incf	FSR0H,f
		comf	INDF0,w
		andwf	INDF1,f
; blink the activity LED
;		clrf	PORTC
;		clrf	TMR0
;		bcf	INTCON,TMR0IF
;		bsf	INTCON,TMR0IE
		retfie

; =================================
;
; handle Note On message
;
; =================================

process_note_on
; Check for zero velocity (note off)
		movf	TEMP_ISR,f
		bz	process_note_off

; set the key bit for this note number.
		movfw	INBOUND_D0
		movwf	FSR0L
		movlw	0xBD
		movwf	FSR0H
; 3-byte record for each note number:
; - lo indirect address for keybits byte
		movfw	INDF0
		movwf	FSR1L
; - hi indirect address for keybits byte
		incf	FSR0H,f
		movfw	INDF0
		movwf	FSR1H
; - bitmask to apply to keybits byte
		incf	FSR0H,f
		movfw	INDF0
		iorwf	INDF1,f
; blink the activity LED
;		clrf	PORTC
;		clrf	TMR0
;		bcf	INTCON,TMR0IF
;		bsf	INTCON,TMR0IE
		retfie

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

		end

