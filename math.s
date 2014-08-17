;------------------------------------------------------------------------------
;           Maths functions
;           Ted John
;           Version 1.0
;           12th February 2013
;
; Functions for any mathematical functions.
;
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; udivision() - performs an unsigned division, taken from example
;               by J.G.
;
; IO R0 - numerator (updated to quotient)
; I  R1 - denominator
; O  R2 - remainder (output only)
;
; R3 - loop counter
;------------------------------------------------------------------------------
udivision
               PUSH    {R3, LR}

               MOV     R2, #0                                  ; AccH
               MOV     R3, #32                                 ; Number of bits in division
               ADDS    R0, R0, R0                              ; Shift dividend
udivision_loop
               ADC     R2, R2, R2                              ; Shift AccH, carry into LSB
               CMP     R2, R1                                  ; Will it go?
               SUBHS   R2, R2, R1                              ; If so, subtract
               ADCS    R0, R0, R0                              ; Shift dividend & Acc. result
               SUB     R3, R3, #1                              ; Loop count
               TST     R3, R3                                  ; Leaves carry alone
               BNE     udivision_loop                          ; Repeat as required
               POP     {R3, PC}

