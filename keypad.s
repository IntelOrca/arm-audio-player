;------------------------------------------------------------------------------
;           Keypad peripheral functions
;           Ted John
;           Version 1.0
;           26th February 2013
;
; Functions for reading the keys.
;
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; Keypad constants
;------------------------------------------------------------------------------
KEYPAD_ROW_1   EQU     (1 << 0)
KEYPAD_ROW_2   EQU     (1 << 1)
KEYPAD_ROW_3   EQU     (1 << 2)
KEYPAD_ROW_4   EQU     (1 << 3)
KEYPAD_UNKOWN  EQU     (1 << 4)
KEYPAD_COL_3   EQU     (1 << 5)
KEYPAD_COL_2   EQU     (1 << 6)
KEYPAD_COL_1   EQU     (1 << 7)
KEYPAD_ROWS    EQU     (KEYPAD_ROW_1 | KEYPAD_ROW_2 | KEYPAD_ROW_3 | KEYPAD_ROW_4)
KEYPAD_COLS    EQU     (KEYPAD_COL_1 | KEYPAD_COL_2 | KEYPAD_COL_3)

KEYPAD_NOBUTTON        EQU     -1
KEYPAD_IDX_ASTERISK    EQU     9
KEYPAD_IDX_0           EQU     10
KEYPAD_IDX_HASH        EQU     11

;------------------------------------------------------------------------------
keypad_variables
keypad_port    DEFW    fpga_area

keypad_button_index_table
               DEFB 0, 3, 6,  9
               DEFB 1, 4, 7, 10
               DEFB 2, 5, 8, 11

keypad_ascii_table
               DEFB '1', '2', '3'
               DEFB '4', '5', '6'
               DEFB '7', '8', '9'
               DEFB '*', '0', '#'

;------------------------------------------------------------------------------
; keypad_get_new_presses()
;
; IO R0 - last scan (output new keys)
; I  R1 - new scan
;------------------------------------------------------------------------------
keypad_get_new_presses
               EOR     R0, R0, R1
               AND     R0, R0, R1
               MOV     PC, LR

;------------------------------------------------------------------------------
; keypad_button_index_to_ascii() - returns the ascii character for the
;                                  specified button index
;
; IO R0 - index (ouput ascii)
;------------------------------------------------------------------------------
keypad_button_index_to_ascii
               CMP     R0, #KEYPAD_NOBUTTON
               MOVEQ   R0, #0
               MOVEQ   PC, LR
               ADD     R0, R0, #keypad_ascii_table
               LDRB    R0, [R0]
               MOV     PC, LR

;------------------------------------------------------------------------------
; keypad_scan_read_index() - returns the button index for the first found
;                            corresponding bit, the bit is then cleared
;
; IO R0 - scan (output with first found bit cleared)
;  O R1 - bit index (output button index)
;    R2 - bit mask
;------------------------------------------------------------------------------
keypad_scan_read_index
               PUSH    {R2, LR}
               MOV     R1, #0                                  ; initialise index and mask
               MOV     R2, #1
keypad_scan_read_ascii_loop
               TST     R0, R2                                  ; test scan bit
               BNE     keypad_scan_read_ascii_found
               CMP     R1, #11                                 ; check if all bits have been tested
               MOVEQ   R1, #KEYPAD_NOBUTTON
               POPEQ   {R2, PC}
               ADD     R1, R1, #1                              ; increment index and mask
               MOV     R2, R2, LSL #1
               B       keypad_scan_read_ascii_loop
keypad_scan_read_ascii_found
               BIC     R0, R0, R2                              ; clear tested bit
               ADD     R1, R1, #keypad_button_index_table
               LDRB    R1, [R1]
               POP     {R2, PC}

;------------------------------------------------------------------------------
; keypad_scan() - scans the keypad and updates the changed key states
;
;  O R0 - result scan (output)

;    R1 - scan shift
;    R2 - control bits
;    R3 - port
;    R4 - data bits
;------------------------------------------------------------------------------
keypad_scan
               PUSH    {R1, R2, R3, R4, LR}

               LDR     R3, keypad_port
               MOV     R2, #(KEYPAD_ROWS | KEYPAD_UNKOWN)      ; Set everything to input apart from the column selectors
               STRB    R2, [R3, #3]

               MOV     R0, #0                                  ; Initialise result scan
               MOV     R1, #0
               MOV     R2, #KEYPAD_COL_1
keypad_scan_loop
               STRB    R2, [R3, #2]                            ; Store output control bits (column selector)
               LDRB    R4, [R3, #2]                            ; Load data bits
               AND     R4, R4, #KEYPAD_ROWS                    ; Place it into the scan result
               MOV     R4, R4, LSL R1
               ORR     R0, R0, R4
               CMP     R2, #KEYPAD_COL_3                       ; Check if all columns have been scanned
               MOVNE   R2, R2, LSR #1                          ; Select next column
               ADDNE   R1, R1, #4
               BNE     keypad_scan_loop
               POP     {R1, R2, R3, R4, PC}
