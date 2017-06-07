; UMR2
; copyright John Staskevich, 2017
; john@codeandcopper.com
;
; This work is licensed under a Creative Commons Attribution 4.0 International License.
; http://creativecommons.org/licenses/by/4.0/
;
; boot.asm
;
; Board initialization
;
		list p=16F1939
		#include	<p16f1939.inc>
		#include	<umr2.inc>

	EXTERN	start_normal_vector
	EXTERN	start_learn_vector
	EXTERN	isr_normal_vector
	EXTERN	isr_learn_vector
	EXTERN	isr_fupdate
	EXTERN	compute_checksum

; =================================
;
; vectors
;
; =================================

reset_code code		0x0000
		goto	go_boot
isr_code code		0x0004
; new context
;		clrf	STATUS
;		clrf	BSR
		clrf	PCLATH
; check for firmware update / learn mode
		btfsc	STATE_FLAGS,0
		goto	isr_select
; normal operation isr
		pagesel	isr_normal_vector
		goto	isr_normal_vector

isr_select
; choose alternate isr
		btfss	STATE_FLAGS,2
		goto	isr_fupdate

		pagesel	isr_learn_vector
		goto	isr_learn_vector


boot_code	code			0x0700

go_boot

; =================================
;
; boot
;
; =================================

; Init the output ports & clock source

; Configure Timer 0 and PORTB pull-ups
; pull-ups off
; timer as slow as possible
		banksel	OPTION_REG
		movlw	B'10000111'
		movwf	OPTION_REG

; Init output ports
		clrf	BSR
		clrf	PORTA
		clrf	PORTB
; start with LEDs off
		movlw	B'11001100'
		movwf	PORTC
		clrf	PORTD
		clrf	PORTE
;		banksel	LATA
;		clrf	LATA
;		clrf	LATB
;		clrf	LATD
;		clrf	LATE
		banksel	ANSELA
		clrf	ANSELA
		clrf	ANSELB
		clrf	ANSELD
		clrf	ANSELE

; Configure the internal clock
		banksel	OSCCON
		movlw	B'11110000'
		movwf	OSCCON

; Configure port A for digital i/o.
		banksel	TRISA
		movlw	B'01111111'
		movwf	TRISA

; Configure port B for digital i/o.
		movlw	B'11111111'
		movwf	TRISB

; Configure port C for digital i/o.
		movlw	B'11100000'
		movwf	TRISC

; Configure port D for digital i/o.
		movlw	B'11111111'
		movwf	TRISD

; Configure port E for digital i/o.
		movlw	B'11111000'
		movwf	TRISE


; =================================
;
; Set up the USART
;
; =================================

; Set up the baud rate generator
; 32 MHz / 31.25 kHz / 16 - 1 = 63
; 32 MHz / [16 (63 + 1)] = 31250
		banksel	SPBRGL
		movlw	D'63'
		movwf	SPBRGL
; Set the transmit control bits
		movlw	B'00100110'
		movwf	TXSTA
; Set the receive control bits
		movlw	B'10010000'
		movwf	RCSTA

; Enable receive interrupts
		banksel	PIE1
		bsf	PIE1,RCIE

; init state flags
		clrf	BSR
		clrf	STATE_FLAGS
; check for PRGM input
		btfss	PORTA,5
		goto	fupdate_wait

; firmware checksum
		call	compute_checksum
; normal operation
		pagesel	start_normal_vector
		goto	start_normal_vector

fupdate_wait
; set LEDs
		movlw	B'11000100'
		movwf	PORTC
; set flag for fupdate mode and for learn mode
		bsf		STATE_FLAGS,0
; Listen for incoming MIDI
		movlw	B'11000000'
		movwf	INTCON
; Check if the PRGM0 input is released.
; If not, wait forever for update sysex.
		btfss	PORTA,5
		goto	$-1
; PRGM0 released--enter learn mode
		bcf	INTCON,GIE
		nop
		nop
		bsf	STATE_FLAGS,2
; firmware checksum
		call	compute_checksum
; start learn mode
		pagesel	start_learn_vector
		goto	start_learn_vector





;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

		end

