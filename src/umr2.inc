; UMR2
; copyright John Staskevich, 2017
; john@codeandcopper.com
;
; This work is licensed under a Creative Commons Attribution 4.0 International License.
; http://creativecommons.org/licenses/by/4.0/
;
; umr2.inc
;
; Include file with global variables, constants
;

; =================================
;
; Bank 0 Variables
;
; =================================

COUNTER_L		equ	0x20
COUNTER_M		equ	0x21
COUNTER_H		equ	0x22
COUNTER_T0		equ	0x23
FIRST_NOTE		equ	0x24
NOTE_COUNT		equ	0x25
SETUP_COUNT		equ	0x26

SELECT_FLAGS		equ	0x50
KEY_BITS		equ	0x60

; global space for routines that access multiple banks
INBOUND_STATUS		equ	0x70
INBOUND_D0		equ	0x71
BYTE_COUNT		equ	0x72
NOTE_ON_STATUS		equ	0x73
NOTE_ON_STATUS_LEARN	equ	0x73
NOTE_OFF_STATUS		equ	0x74
; General purpose registers for data manipulation
TEMP			equ	0x75
TEMP_2			equ	0x76
TEMP_3			equ	0x77
TEMP_4			equ	0x78
TEMP_5			equ	0x79
TEMP_6			equ	0x7A
TEMP_7			equ	0x7B
MESSAGE_TYPE		equ	0x7C
TEMP_ISR		equ	0x7E
STATE_FLAGS		equ	0x7F

; =================================
;
; Bank 1 Variables
;
; =================================

FIRMWARE_BUFFER	equ	0xA0

; =================================
;
; Bank 2 Variables
;
; =================================

; =================================
;
; Bank 3 Variables
;
; =================================

; =================================
;
; Constants
;
; =================================

; Values for MESSAGE_TYPE
NOT_SUPPORTED		equ	B'00000000'
NOTE_OFF		equ	B'00000001'
NOTE_ON			equ	B'00000010'
AFTERTOUCH		equ	B'00000100'
CONTROLLER		equ	B'00001000'
PROGRAM_CHANGE		equ	B'00010000'
CHANNEL_PRESSURE	equ	B'00100000'
PITCH_WHEEL		equ	B'01000000'
SYSEX			equ	B'10000000'

; EEPROM addresses
PROM_VERSION		equ	0x00
PROM_CHECKSUM		equ	0x01
PROM_CHANNEL		equ	0x03
PROM_FIRST_NOTE		equ	0x04
PROM_NOTE_COUNT		equ	0x05
PROM_SETUP_COUNT	equ	0x06

; Sysex-related constants
; Fixed data for header
; Manufacturer ID
SYSEX_HEADER_0		equ	0x00
SYSEX_HEADER_1		equ	0x01
SYSEX_HEADER_2		equ	0x5D
; Product ID
SYSEX_HEADER_3		equ	0x07

; Other
COUNTER_T0_MAX		equ	0x1F
