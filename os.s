;------------------------------------------------------------------------------
;           Project
;           Ted John
;           Version 1.4
;           16 April 2013
;
; Operating system
;
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; Generic constants
;------------------------------------------------------------------------------
FALSE          EQU     0
TRUE           EQU     1

;------------------------------------------------------------------------------
; Sector division offsets
;------------------------------------------------------------------------------
OFFSET_OS      EQU     &0                                      ; start address for the OS (code in supervisor mode)
OFFSET_IRQ     EQU     &7900                                   ; start address for interupt code (IRQ mode)
OFFSET_USER    EQU     &8000                                   ; start address for the user code (user mode)
OFFSET_ENDRAM  EQU     &27C00                                  ; the last available RAM address

;------------------------------------------------------------------------------
; Architecture constants
;------------------------------------------------------------------------------
PSR_CLR_MODE   EQU     &1F
PSR_USR        EQU     &10
PSR_FIQ        EQU     &11
PSR_IRQ        EQU     &12
PSR_SVC        EQU     &13
PSR_ABT        EQU     &17
PSR_UND        EQU     &1B
PSR_SYS        EQU     &1F

;------------------------------------------------------------------------------
; I/O constants
;------------------------------------------------------------------------------
port_area      EQU     &10000000
port_LCD_DATA  EQU     &0
port_LCD_CTRL  EQU     &4
port_BUTTONS   EQU     &4
port_TIMER     EQU     &8
port_TIMER_CMP EQU     &C
port_INT_REQ   EQU     &18
port_INT_EN    EQU     &1C

fpga_area      EQU     &20000000

;------------------------------------------------------------------------------
; BUTTON constants
;------------------------------------------------------------------------------
BTN_1          EQU     (1 << 3)
BTN_2          EQU     (1 << 7)
BTN_3          EQU     (1 << 6)
BTN_MASK       EQU     (BTN_1 | BTN_2 | BTN_3)
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; Interrupt constants
;------------------------------------------------------------------------------
INT_TIMER_CMP  EQU     (1 << 0)
INT_SPARTAN    EQU     (1 << 1)
INT_VIRTEX     EQU     (1 << 2)
INT_ETHERNET   EQU     (1 << 3)
INT_SERIAL_RR  EQU     (1 << 4)
INT_SERIAL_TR  EQU     (1 << 5)
INT_BTN_UPPER  EQU     (1 << 6)
INT_BTN_LOWER  EQU     (1 << 7)

;------------------------------------------------------------------------------
; Buzzer constants
;------------------------------------------------------------------------------
BUZZER_ENABLE_MASK     EQU     &8000

;------------------------------------------------------------------------------
               ORG     0
;------------------------------------------------------------------------------
; Exception table
;------------------------------------------------------------------------------
os_exception_table
               B       os_reset                                ; reset
               B       os_undefined_instruction                ; undefined instruction
               B       os_svc                                  ; SVC
               B       os_prefetch_abort                       ; prefetch abort
               B       os_data_abort                           ; data abort
               B       os_trapper_exception                    ; -
               B       os_irq                                  ; IRQ
               B       os_fiq                                  ; FIQ

;------------------------------------------------------------------------------
; Operating system variables
;------------------------------------------------------------------------------
os_tick_count  DEFW    0                                       ; the number of elapsed ms

;------------------------------------------------------------------------------
; os_undefined_instruction() - trapper
;------------------------------------------------------------------------------
os_undefined_instruction
               B       os_undefined_instruction

;------------------------------------------------------------------------------
; os_prefetch_abort() - trapper
;------------------------------------------------------------------------------
os_prefetch_abort
               B       os_prefetch_abort

;------------------------------------------------------------------------------
; os_data_abort() - trapper
;------------------------------------------------------------------------------
os_data_abort
               B       os_data_abort

;------------------------------------------------------------------------------
; os_trapper_exception() - trapper
;------------------------------------------------------------------------------
os_trapper_exception
               B       os_trapper_exception

;------------------------------------------------------------------------------
; os_fiq() - trapper
;------------------------------------------------------------------------------
os_fiq
               B       os_fiq

;------------------------------------------------------------------------------
; SVC CALL TYPES
;------------------------------------------------------------------------------
SVC_EXIT               EQU     0
SVC_LCD_LIGHT          EQU     1
SVC_LCD_CLEAR          EQU     2
SVC_LCD_WRITE          EQU     3
SVC_LCD_WRITE_CHAR     EQU     4
SVC_LCD_SET_CURSOR     EQU     5
SVC_LCD_COMMAND        EQU     6
SVC_BUZZ_SET           EQU     7
SVC_KEYPAD_SCAN        EQU     8

SVC_SVC_COUNT          EQU     9
;------------------------------------------------------------------------------
; os_svc() - Runs a supervisor instruction
;
; R14 - mode
;------------------------------------------------------------------------------
os_svc
               PUSH    {R14}                                   ; push scratch register
               LDR     R14, [R14, #-4]                         ; read SVC instruction
               BIC     R14, R14, #&FF000000                    ; mask off opcode
               CMP     R14, #SVC_SVC_COUNT                     ; check if SVC instruction exists
               BHS     os_undefined_instruction
os_svc_jump                                                    ; SVC switch
               ADD     R14, PC, R14, LSL #2
               LDR     R14, [R14, #(os_svc_jumptable-os_svc_jump-8)]
               PUSH    {R14}
               MOV     R14, #os_svc_return
               POP     {PC}
os_svc_return
               POP     {PC}^
os_svc_jumptable                                               ; SVC case jump table
               DEFW    os_exit
               DEFW    lcd_setlight
               DEFW    lcd_clear
               DEFW    lcd_putstring
               DEFW    lcd_putchar
               DEFW    lcd_setcursor
               DEFW    lcd_command
               DEFW    buzz_set
               DEFW    keypad_scan

;------------------------------------------------------------------------------
; os_irq() - interrupt handler
;------------------------------------------------------------------------------
os_irq
               SUB     LR, LR, #4                              ; Convert return address to interrupted instruction address
               PUSH    {R0, R1, R2, LR}
               MOV     R0, #port_area
               LDR     R1, [R0, #port_INT_REQ]                 ; Obtain the interrupt request
               TST     R1, #INT_TIMER_CMP                      ; Test if timer compare
               BLNE    os_update_tick_count
               MOV     R1, #0                                  ; Clear the interrupt requests
               STR     R1, [R0, #port_INT_REQ]
               POP     {R0, R1, R2, PC}^                       ; Return to last code and mode

;------------------------------------------------------------------------------
; os_reset() - reset the operating system
;
; R14 - mode
;------------------------------------------------------------------------------ 
os_reset
               MOV     SP, #OFFSET_IRQ                         ; initialise supervisor stack

               MOV     R0, #0                                  ; initialise os variables
               MOV     R1, #os_tick_count
               STR     R0, [R1]

               MOV     R1, #0
               MOV     R0, #port_area
               STRB    R1, [R0, #port_LCD_CTRL]                ; store port value
               MOV     R0, #fpga_area
               STRH    R1, [R0]                                ; store buzzer output

               MSR     CPSR_c, #&D2                            ; change to IRQ mode
               MOV     SP, #OFFSET_USER                        ; initialise interrupt stack
               MOV     R0, #port_area
               MOV     R1, #0                                  ; clear the interrupt requests
               STR     R1, [R0, #port_INT_REQ]
               MOV     R1, #INT_TIMER_CMP                      ; enable the timer compare interrupt
               STR     R1, [R0, #port_INT_EN]
               MOV     R1, #1                                  ; set the timer compare to be 1ms
               STR     R1, [R0, #port_TIMER_CMP]
               
               MOV     R14, #&50                               ; user mode, with interrupts
               MSR     SPSR, R14
               MOV     LR, #OFFSET_USER                        ; set main as the user code entry point
               ADD     LR, LR, #(main-OFFSET_USER)
               MOVS    PC, LR                                  ; switch to user code

;------------------------------------------------------------------------------
; os_exit() - ends the program and operating system
;------------------------------------------------------------------------------
os_exit
               B       os_exit

;------------------------------------------------------------------------------
; os_update_tick_count() - increments the tick count and resets the timer
;
; R0 - port area address
; R1 - ticks
; R2 - os tick count variable reference
;------------------------------------------------------------------------------
os_update_tick_count
               PUSH    {R0, R1, R2, LR}
               MOV     R2, #os_tick_count
               MOV     R0, #port_area
               MOV     R1, #0                                  ; Clear the timer
               STR     R1, [R0, #port_TIMER]
               LDR     R1, [R2]                                ; Increment the OS tick count
               ADD     R1, R1, #1
               STR     R1, [R2]
               POP     {R0, R1, R2, PC}

;------------------------------------------------------------------------------
; buzz_set() - sets the buzzer to play a certain frequency
;
; I  R0 - time period
; I  R1 - port
;    R2 - general purpose value
;------------------------------------------------------------------------------
buzz_set
               PUSH    {R2, R3, LR}
               MOV     R2, #fpga_area                          ; get port address
               ADD     R2, R2, R1 LSL #2
               MOV     R3, R0, LSR #8                          ; store high
               STRB    R3, [R2, #1]
               STRB    R0, [R2, #0]
               POP     {R2, R3, PC}

;------------------------------------------------------------------------------
; memset() - sets a number of bytes to a value
; I  R0 - address
; I  R1 - value
; I  R2 - length
;------------------------------------------------------------------------------
memset
               PUSH    {R0, R2, LR}

memset_loop
               CMP     R2, #1
               STRGEB  R1, [R0], #1
               SUBGE   R2, R2, #1
               BGE     memset_loop
               POP     {R0, R2, PC}

;------------------------------------------------------------------------------
; has_elapsed_by()
;
; IO R0 - address of tick save, output true if so otherwise false
; I  R1 - number of ticks
;
;    R2 - current tick count
;    R3 - last tick count / elapsed
;------------------------------------------------------------------------------
has_elapsed_by
               PUSH    {R2, R3, LR}
               MOV     R2, #os_tick_count                      ; get current tick
               LDR     R2, [R2]
               LDR     R3, [R0]                                ; get last tick
               SUB     R3, R2, R3                              ; get elapsed ticks
               CMP     R3, R1                                  ; check if elapsed ticks > R1
               MOVLT   R0, #FALSE
               BLT     has_elapsed_by_return
               STR     R2, [R0]                                ; set last tick
               MOV     R0, #TRUE
has_elapsed_by_return
               POP     {R2, R3, PC}

;------------------------------------------------------------------------------
               INCLUDE lcd.s
               INCLUDE keypad.s
               INCLUDE math.s
               INCLUDE string.s

