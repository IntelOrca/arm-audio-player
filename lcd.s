;------------------------------------------------------------------------------
;           LCD functions
;           Ted John
;           Version 1.2
;           16 April 2013
;
; Functions for interfacing with the LCD.
;
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; LCD constants
;------------------------------------------------------------------------------
LCD_E          EQU     (1 << 0)
LCD_RS         EQU     (1 << 1)
LCD_RW         EQU     (1 << 2)
LCD_BACKLIGHT  EQU     (1 << 5)
LCD_BUSY       EQU     (1 << 7)

LCD_CMD_CLEAR  EQU     &1
LCD_CMD_SETCUR EQU     &80

LCD_CHARS_VISIBLE_PER_LINE       EQU     16
LCD_CHARS_PER_LINE               EQU     64

LCD_CHARWRITE  EQU     (1 << 31)

;------------------------------------------------------------------------------
; LCD_SCROLLER - structure for scrolling text along a line in the LCD
;------------------------------------------------------------------------------
RECORD
LCD_SCROLLER_TEXT                BYTE        256
LCD_SCROLLER_BUFFER              BYTE        LCD_CHARS_VISIBLE_PER_LINE
LCD_SCROLLER_X                   WORD
LCD_SCROLLER_Y                   WORD
LCD_SCROLLER_TEXT_LEN            WORD
LCD_SCROLLER_SIZE                WORD

;------------------------------------------------------------------------------
; lcd_scroller_set_text()
;
; I  R0 - lcd_scroller address
; I  R1 - y
;------------------------------------------------------------------------------
lcd_scroller_init
               PUSH    {R1, R2, R3, LR}
               MOV     R3, R1
               MOV     R1, #0
               MOV     R2, #LCD_SCROLLER_SIZE
               BL      memset
               STR     R3, [R0, #LCD_SCROLLER_Y]
               POP     {R1, R2, R3, PC}

;------------------------------------------------------------------------------
; lcd_scroller_set_text()
;
; I  R0 - lcd_scroller address
; I  R1 - source text address
;------------------------------------------------------------------------------
lcd_scroller_set_text
               PUSH    {R0, R1, R2, R3, LR}
               MOV     R3, R0
               
               ADD     R2, R3, #LCD_SCROLLER_TEXT              ; destination text
               
               MOV     R0, R2
               BL      strcpy
               BL      strlen                                  ; save text length
               MOV     R1, R0
               STR     R1, [R2, #LCD_SCROLLER_TEXT_LEN]
               
               ADD     R0, R1, R2                              ; end of string address
               RSB     R2, R1, #&100                           ; length of memory
               MOV     R1, #0                                  ; value
               BL      memset
               
               MOV     R0, #0                                  ; reset x position
               STR     R0, [R3, #LCD_SCROLLER_X]
               MOV     R0, R3                                  ; update the scroller
               BL      lcd_scroller_update
               POP     {R0, R1, R2, R3, PC}

;------------------------------------------------------------------------------
; lcd_scroller_update()
;
; I  R0 - lcd_scroller address
;
;    R0 - general purpose
;    R1 - destination character
;    R2 - text address
;    R3 - buffer address
;    R4 - lcd_scoller address
;    R5 - buffer x position
;    R6 - buffer y position
;    R7 - source character
;------------------------------------------------------------------------------
lcd_scroller_update
               PUSH    {R0, R1, R2, R3, R4, R5, R6, R7, LR}
               MOV     R4, R0
               
               MOV     R5, #0                                  ; set buffer x to 0
               LDR     R6, [R4, #LCD_SCROLLER_Y]               ; get y position (line index)
               ADD     R2, R4, #LCD_SCROLLER_TEXT              ; get text address (R2)
               LDR     R0, [R4, #LCD_SCROLLER_X]               ; skip x characters
               ADD     R2, R2, R0
               ADD     R3, R4, #LCD_SCROLLER_BUFFER            ; get buffer cache address (R3)
               
lcd_scroller_update_loop
               LDRB    R7, [R2]                                ; get source character
               LDRB    R1, [R3]                                ; get destination character
               CMP     R7, R1                                  ; check if we need to update buffer
               BEQ     lcd_scroller_update_next
               
               MOV     R0, R5                                  ; x position
               MOV     R1, R6            
               SVC     SVC_LCD_SET_CURSOR
               MOV     R0, R7                                  ; character to write
               SVC     SVC_LCD_WRITE_CHAR               
               STRB    R7, [R3]                                ; update buffer cache
               
lcd_scroller_update_next
               ADD     R2, R2, #1                              ; next character
               ADD     R3, R3, #1
               ADD     R5, R5, #1
               CMP     R5, #LCD_CHARS_VISIBLE_PER_LINE         ; check if whole buffer has been updated
               BLT     lcd_scroller_update_loop
               
lcd_scroller_update_end
               LDR     R0, [R4, #LCD_SCROLLER_TEXT_LEN]        ; get string length
               CMP     R0, #LCD_CHARS_VISIBLE_PER_LINE         ; no scrolling if text length < LCD_CHARS_VISIBLE_PER_LINE
               BLE     lcd_scroller_update_return

               SUB     R0, R0, #(LCD_CHARS_VISIBLE_PER_LINE-1) ; give some spaces after the string when scrolling
               LDR     R1, [R4, #LCD_SCROLLER_X]               ; get current x
               ADD     R1, R1, #1                              ; increment current x
               CMP     R1, R0                                  ; check if ready to reset x
               BLT     lcd_scroller_update_save_x
               MOV     R1, #0                                  ; reset x
lcd_scroller_update_save_x
               STR     R1, [R4, #LCD_SCROLLER_X]               ; set current x
lcd_scroller_update_return
               POP     {R0, R1, R2, R3, R4, R5, R6, R7, PC}

;------------------------------------------------------------------------------
; lcd_setlight() - sets the backlight of the LCD to either on or off
;
; I  R0 - TRUE to turn the backlight on, FALSE to turn it off
;    R1 - port area
;    R2 - port area value
;------------------------------------------------------------------------------
lcd_setlight
               PUSH    {R1, R2, LR}
               MOV     R1, #port_area
               LDRB    R2, [R1, #port_LCD_CTRL]               ; load port value
               CMP     R0, #FALSE                             ; set backlight bit based on argument
               ORRNE   R2, R2, #LCD_BACKLIGHT
               BICEQ   R2, R2, #LCD_BACKLIGHT
               STRB    R2, [R1, #port_LCD_CTRL]               ; store port value
               POP     {R1, R2, PC}

;------------------------------------------------------------------------------
; lcd_clear() - clears the LCD display
;
;    R0 - command
;------------------------------------------------------------------------------
lcd_clear
               PUSH    {R0, LR}
               MOV     R0, #LCD_CMD_CLEAR
               BL      lcd_command
               POP     {R0, PC}

;------------------------------------------------------------------------------
; lcd_putstring() - writes a null terminated string to the LCD
;
; I  R0 - address of string (first character)
;    R0 - current character value
;    R1 - address of character position
;------------------------------------------------------------------------------
lcd_putstring
               PUSH    {R0, R1, LR}
               MOV     R1, R0                                  ; use another register for string address
lcd_putstring_loop
               LDRB    R0, [R1], #1                            ; read character
               CMP     R0, #0                                  ; check if null terminator reached
               POPEQ   {R0, R1, PC}                            ; return
               ADR     LR, lcd_putstring_loop                  ; write the character and then loop
               B       lcd_putchar

;------------------------------------------------------------------------------
; lcd_putchar() - writes an ascii character to the LCD
;
; I  R0 - ascii character to write
;------------------------------------------------------------------------------
lcd_putchar
               PUSH    {R0, LR}
               CMP     R0, #0                                  ; change char 0 to space
               MOVEQ   R0, #' '
               ORR     R0, R0, #LCD_CHARWRITE                  ; set write character flag
               BL      lcd_command
               POP     {R0, PC}

;------------------------------------------------------------------------------
; lcd_setcursor() - sets the LCD cursor position
;
; I  R0 - x position
; I  R1 - y position
;------------------------------------------------------------------------------
lcd_setcursor_line_offsets                                     ; lookup table for line start offsets
               DEFW    (LCD_CHARS_PER_LINE * 0)
               DEFW    (LCD_CHARS_PER_LINE * 1)
               DEFW    (LCD_CHARS_PER_LINE * 2)
               DEFW    (LCD_CHARS_PER_LINE * 3)
lcd_setcursor
               PUSH    {R0, R2, LR}
               ADRL    R2, lcd_setcursor_line_offsets          ; get line start offset
               LDR     R2, [R2, R1 LSL #2]
               ADD     R2, R2, R0                              ; add x position
               ADD     R0, R2, #LCD_CMD_SETCUR                 ; produce lcd command
               BL      lcd_command
               POP     {R0, R2, PC}

;------------------------------------------------------------------------------
; lcd_command() - sends a command or character to the LCD
;
; I  R0 - command (set bit LCD_CHARWRITE for character write)
;    R1 - port area address
;    R2 - data register
;------------------------------------------------------------------------------
lcd_command
               PUSH    {R1, R2, LR}
               MOV     R1, #port_area                          ; keep port address in R1
               BL      lcd_wait_until_ready
               LDRB    R2, [R1, #port_LCD_CTRL]                ; read from control port
               BIC     R2, R2, #LCD_RW                         ; set write signal

               TST     R0, #LCD_CHARWRITE                      ; test command / character flag
               ORRNE   R2, R2, #LCD_RS                         ;   set data port IO
               BICEQ   R2, R2, #LCD_RS                         ;   set control port IO

               STRB    R2, [R1, #port_LCD_CTRL]                ;     write to control port
               STRB    R0, [R1, #port_LCD_DATA]                ; write data port
               ORR     R2, R2, #LCD_E                          ; enable bus
               STRB    R2, [R1, #port_LCD_CTRL]                ;   write to control port
               BIC     R2, R2, #LCD_E                          ; disable bus
               STRB    R2, [R1, #port_LCD_CTRL]                ;   write to control port
               POP     {R1, R2, PC}

;------------------------------------------------------------------------------
; lcd_wait_until_ready() - waits until the LCD display is ready
;
;    R0 - port area address
;    R1 - control register
;    R2 - data register
;------------------------------------------------------------------------------
lcd_wait_until_ready
               PUSH    {R0, R1, R2, LR}
               MOV     R0, #port_area                          ; keep port address in R0
               LDRB    R1, [R0, #port_LCD_CTRL]                ; read control port
               ORR     R1, R1, #LCD_RW                         ; set read signal
               BIC     R1, R1, #LCD_RS                         ; set control register
               STRB    R1, [R0, #port_LCD_CTRL]                ;   write control port
lcd_wait_until_ready_loop
               ORR     R1, R1, #LCD_E                          ; enable bus
               STRB    R1, [R0, #port_LCD_CTRL]                ;   write control port
               LDRB    R2, [R0, #port_LCD_DATA]                ; read data port
               BIC     R1, R1, #LCD_E                          ; disable bus
               STRB    R1, [R0, #port_LCD_CTRL]                ;   write control port
               TST     R2, #LCD_BUSY                           ; test busy bit
               BNE     lcd_wait_until_ready_loop
               POP     {R0, R1, R2, PC}
