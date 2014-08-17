;------------------------------------------------------------------------------
;           String and LCD functions
;           Ted John
;           Version 1.1
;           24th February 2013
;
; Functions for manipulating strings and interfacing with the LCD.
;
;------------------------------------------------------------------------------

INT2STR_SPACES EQU     &80000000

;------------------------------------------------------------------------------
; strlen() - gets the length of a string
;
; IO R0 - source string address, changed to length of string
;------------------------------------------------------------------------------
strlen
               PUSH    {R1, LR}
               MOV     R1, R0                                  ; save start address
               BL      strend                                  ; find end address
               SUB     R0, R0, R1                              ; return difference
               POP     {R1, PC}

;------------------------------------------------------------------------------
; strend() - gets the address of the string terminator character
;
; IO R0 - source string / terminator address
;------------------------------------------------------------------------------
strend
               PUSH    {R1, LR}
strend_loop
               LDRB    R1, [R0], #1                            ; find string terminator
               CMP     R1, #0
               BNE     strend_loop
               SUB     R0, R0, #1
               POP     {R1, PC}

;------------------------------------------------------------------------------
; appendchar() - appends an ascii character to the end of a string
;
; I  R0 - destination string address
; I  R1 - ascii character to append
;------------------------------------------------------------------------------
appendchar
               PUSH    {R0, R1, LR}
appendchar_loop
               BL      strend
               STRB    R1, [R0]                                ; overwrite the terminator with the character
               MOV     R1, #0                                  ; write a new terminator
               STRB    R1, [R0, #1]
               POP     {R0, R1, PC}

;------------------------------------------------------------------------------
; strcat() - appends a source string to the end of a destination string
;
; I  R0 - destination string address
; I  R1 - source string address
;------------------------------------------------------------------------------
strcat
               PUSH    {R0, LR}
               BL      strend
               BL      strcpy
               POP     {R0, PC}

;------------------------------------------------------------------------------
; strcpy() - copies a source string to a destination address
;
; I  R0 - destination string address
; I  R1 - source string address
;------------------------------------------------------------------------------
strcpy
               PUSH    {R0, R1, R2, LR}
strcpy_loop
               LDRB    R2, [R1], #1                            ; copy character
               STRB    R2, [R0], #1
               CMP     R2, #0                                  ; check if string terminator
               BNE     strcpy_loop
               POP     {R0, R1, R2, PC}

;------------------------------------------------------------------------------
; int2str() - converts a 32-bit integer from a register and writes it to
;             a string buffer with a specified number width (0s or spaces)
;
; IO R0 - string buffer (updated to address of character directly after the last digit)
; I  R1 - integer
; I  R2 - minimum length (INT2STR_SPACES specifies whether to use spaces (set) or numbers (clear))
;
;    R0 - integer as its divided or temp
;    R1 - divisor (always 10)
;    R2 - remainder (digit)
;    R3 - string start address (after negative sign)
;    R4 - string current address
;    R5 - string end address
;    R6 - minimum length (backup)
;------------------------------------------------------------------------------
int2str
               PUSH    {R1, R2, R3, R4, R5, R6, LR}

               MOV     R3, R0                                  ; set the string address pointers
               MOV     R4, R0
               MOV     R6, R2                                  ; move minimum length to a different register

               CMP     R1, #0                                  ; check if input number is 0 (special case)
               BNE     int2str_negative_check
               MOV     R0, #'0'                                ; just append a single ascii 0
               STRB    R0, [R4], #1
               B       int2str_digit_finalise                  ; jump to the finalise code

int2str_negative_check
               TST     R1, R1                                  ; check if input number is negative
               BPL     int2str_digit_write
               MOV     R0, #'-'                                ; store ascii negative sign, increment address
               STRB    R0, [R4], #1
               RSB     R1, R1, #0                              ; perform 2's complement, (invert bits and add 1)
               MOV     R3, R4                                  ; set start of string address as well, (negative sign is not included in reorder)

int2str_digit_write
               MOV     R0, R1                                  ; set left over digits to input number
               MOV     R1, #10          
int2str_digit_write_loop
               CMP     R0, #0                                  ; check if there are any left over digits
               BEQ     int2str_digit_finalise
               BL      udivision
               ADD     R2, R2, #'0'                            ; convert remainder to ascii
               STRB    R2, [R4], #1                            ; store ascii digit, increment address
               B       int2str_digit_write_loop

int2str_digit_finalise
               BIC     R5, R6, #INT2STR_SPACES                 ; get minimum length of string
               ADD     R5, R5, R3                              ; add string start address
               CMP     R5, R4                                  ; check if end address is less than current address
               MOVLT   R5, R4                                  ;   if so then set end address to current address
               
int2str_digit_fill
               BLE     int2str_digit_reverse                   ; skip this step if number was longer than minimum length
               MOV     R0, #'0'
               TST     R6, #INT2STR_SPACES                     ; if sign bit set, use spaces instead of zeros
               MOVNE   R0, #' '
               BIC     R6, R6, #INT2STR_SPACES                 ; clear sign bit so it is just the length
int2str_digit_fill_loop
               STRB    R0, [R4], #1                            ; append the padding ascii value until we have reached the minimum length
               CMP     R4, R5
               BLT     int2str_digit_fill_loop

int2str_digit_reverse
               SUB     R4, R4, #1
int2str_digit_reverse_loop
               LDRB    R0, [R3]                                ; load character a and b
               LDRB    R1, [R4]
               STRB    R0, [R4], #-1                           ; store characters in swapped locations and adjust pointers
               STRB    R1, [R3], #1
               CMP     R3, R4                                  ; check if left pointer and right pointer have met up or crossed over
               BLT     int2str_digit_reverse_loop

               MOV      R0, #0
               STRB     R0, [R5]                               ; null terminate
               MOV      R0, R5                                 ; set R0 to address of character after number
               POP      {R1, R2, R3, R4, R5, R6, PC}

