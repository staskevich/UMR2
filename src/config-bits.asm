; UMR2
; copyright John Staskevich, 2017
; john@codeandcopper.com
;
; This work is licensed under a Creative Commons Attribution 4.0 International License.
; http://creativecommons.org/licenses/by/4.0/
;
; config-bits.asm
;
; PIC config bits
;
		list p=16F1939
		#include	<p16f1939.inc>
		#include	<umr2.inc>

;Program Configuration Register
; with ROM protection
		__CONFIG _CONFIG1, 0x3E44

; no ROM protection
;		__CONFIG _CONFIG1, 0x3FC4

		__CONFIG _CONFIG2, 0x1FEF

	end
