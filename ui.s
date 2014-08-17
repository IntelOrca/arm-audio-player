;------------------------------------------------------------------------------
;           UI module
;           Ted John
;           Version 1.0
;           23 April 2013
;
; Functions for interfacing with the LCD.
;
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; MODULE_UI - structure for storing the UI variables
;------------------------------------------------------------------------------
RECORD
MODULE_UI_PROJECT                  WORD
MODULE_UI_SCROLL_SAVETICK          WORD
MODULE_UI_TIME_SAVETICK            WORD
MODULE_UI_LCD_SCROLLERS            BYTE      (LCD_SCROLLER_SIZE * 2)
MODULE_UI_BUFFER                   BYTE      256
MODULE_UI_LAST_KEYPAD_SCAN         WORD
MODULE_UI_SIZE                     ALIAS

;------------------------------------------------------------------------------
; ui_init() - initialises the ui module
;
; I  R0 - ui module address
; I  R1 - project module address
;------------------------------------------------------------------------------
ui_init
               PUSH    {R0, R1, R2, R3, LR}
               STR     R1, [R0, #MODULE_UI_PROJECT]

               MOV     R2, #0
               STR     R2, [R0, #MODULE_UI_SCROLL_SAVETICK]
               STR     R2, [R0, #MODULE_UI_TIME_SAVETICK]

               SVC     SVC_LCD_CLEAR
               SVC     SVC_LCD_LIGHT

               ADD     R0, R0, #MODULE_UI_LCD_SCROLLERS
               MOV     R1, #0
               BL      lcd_scroller_init
               ADD     R0, R0, #LCD_SCROLLER_SIZE
               MOV     R1, #1
               BL      lcd_scroller_init
               POP     {R0, R1, R2, R3, PC}

;------------------------------------------------------------------------------
; ui_show_about() - shows the about screen / credits
;
; I  R0 - ui module address
;------------------------------------------------------------------------------
ui_show_about_sz_top
               DEFB    "Music Player",0
               ALIGN
ui_show_about_sz_bottom
               DEFB    "Ted John, 2013",0
               ALIGN
ui_show_about
               PUSH    {R0, R1, LR}
               ADD     R0, R0, #MODULE_UI_LCD_SCROLLERS        ; get top scroller
               ADR     R1, ui_show_about_sz_top                ; set the top scroller text
               BL      lcd_scroller_set_text   
               ADD     R0, R0, #LCD_SCROLLER_SIZE              ; get bottom scroller
               ADR     R1, ui_show_about_sz_bottom             ; set the bottom scroller text
               BL      lcd_scroller_set_text
               POP     {R0, R1, PC}

;------------------------------------------------------------------------------
; ui_track_changed() - called when the track has changed
;
; I  R0 - ui_module address
;------------------------------------------------------------------------------ 
ui_track_changed
               PUSH    {R1, R2, R3, LR}
               LDR     R1, [R0, #MODULE_UI_PROJECT]            ; get project module address
               LDR     R1, [R1, #MODULE_PROJECT_PLAYER]        ; get player module address

               PUSH    {R0, R1, R2}
               LDR     R3, [R1, #MODULE_PLAYER_TRACK_NAME]     ; get track name address
               ADD     R0, R0, #MODULE_UI_BUFFER               ; get buffer address
               LDR     R1, [R1, #MODULE_PLAYER_TRACK_INDEX]    ; get track index
               ADD     R1, R1, #1                              ; make it base from 1
               MOV     R2, #0
               BL      int2str
               MOV     R1, #':'                                ; append colon
               BL      appendchar
               ADD     R0, R0, #1
               MOV     R1, #' '                                ; append space
               BL      appendchar
               ADD     R0, R0, #1
               MOV     R1, R3                                  ; write track name
               BL      strcpy
               POP     {R0, R1, R2}

               MOV     R2, R0                                  ; preserve R0
               ADD     R0, R0, #MODULE_UI_LCD_SCROLLERS        ; get top scroller
               ADD     R1, R2, #MODULE_UI_BUFFER
               BL      lcd_scroller_set_text                   ; set the top scroller text
               MOV     R0, R2                                  ; restore R0

               BL      ui_refresh_time                         ; update track info
               POP     {R1, R2, R3, PC}

;------------------------------------------------------------------------------
; ui_track_updated() - called when the track has updated, state or time
;
; I  R0 - ui_module address
;------------------------------------------------------------------------------
ui_track_updated
               PUSH    {R1, R2, LR}

               MOV     R2, R0                                  ; preserve R0

               ADD     R0, R2, #MODULE_UI_TIME_SAVETICK
               MOV     R1, #250
               BL      has_elapsed_by
               CMP     R0, #FALSE
               MOVNE   R0, R2
               BLNE    ui_refresh_time                         ; refresh time and state

               ADD     R0, R2, #MODULE_UI_SCROLL_SAVETICK
               MOV     R1, #500
               BL      has_elapsed_by
               CMP     R0, #FALSE
               BEQ     ui_track_updated_return                 ; refresh time and state

               ADD     R0, R2, #MODULE_UI_LCD_SCROLLERS
               BL      lcd_scroller_update

ui_track_updated_return
               MOV     R0, R2                                  ; restore R0
               POP     {R1, R2, PC}

;------------------------------------------------------------------------------
; ui_refresh_time() - refresh the track time and state
;
; I  R0 - ui_module address
;------------------------------------------------------------------------------
ui_refresh_time
               PUSH    {R0, R1, R2, R3, R4, LR}
               LDR     R1, [R0, #MODULE_UI_PROJECT]            ; get project module address
               LDR     R1, [R1, #MODULE_PROJECT_PLAYER]        ; get player module address

               LDR     R2, [R1, #MODULE_PLAYER_ELAPSED_TICKS]
               ADD     R3, R0, #MODULE_UI_BUFFER

               PUSH    {R0, R1}
               MOV     R4, R0                                  ; put ui module address in R4
               MOV     R0, R3                                  ; write the time
               LDR     R1, [R1, #MODULE_PLAYER_ELAPSED_TICKS]
               BL      ui_write_time

               LDR     R1, [R4, #MODULE_UI_PROJECT]            ; write the current state
               LDR     R1, [R1, #MODULE_PROJECT_STATE]
               BL      ui_write_state
               POP     {R0, R1}

               ADD     R2, R0, #MODULE_UI_LCD_SCROLLERS        ; get bottom scroller
               ADD     R2, R2, #LCD_SCROLLER_SIZE

               MOV     R0, R2                                  ; scroller
               MOV     R1, R3                                  ; string
               BL      lcd_scroller_set_text

               POP     {R0, R1, R2, R3, R4, PC}

;------------------------------------------------------------------------------
; ui_write_time() - write a time to a string
;
; IO R0 - destination string address (updated to end)
; I  R1 - total milliseconds
;
;    R1 - minutes
;    R3 - seconds
;------------------------------------------------------------------------------
ui_write_time
               PUSH    {R1, R2, R3, LR}

               MOV     R3, R0                                  ; preserve R0
               MOV     R0, R1                                  ; get total seconds
               MOV     R1, #1000
               BL      udivision
               MOV     R1, #60                                 ; get minutes and seconds
               BL      udivision
               MOV     R1, R0
               MOV     R0, R3                                  ; restore R0
               MOV     R3, R2

               MOV     R2, #2                                  ; write minutes
               BL      int2str
               MOV     R1, #':'                                ; write colon
               BL      appendchar
               ADD     R0, R0, #1
               MOV     R1, R3                                  ; write seconds
               BL      int2str
               POP     {R1, R2, R3, PC}

;------------------------------------------------------------------------------
; ui_write_state() - write a state to a string
;
; IO R0 - destination string address (updated to end)
; I  R1 - state
;------------------------------------------------------------------------------
ui_write_state_sz_stopped
               DEFB    " - stopped",0
               ALIGN
ui_write_state_sz_playing
               DEFB    " - playing",0
               ALIGN
ui_write_state
               PUSH    {R1, LR}
               CMP     R1, #STATE_PLAYING
               ADREQ   R1, ui_write_state_sz_playing
               ADRNE   R1, ui_write_state_sz_stopped
               BL      strcpy
               BL      strend
               POP     {R1, PC}

;------------------------------------------------------------------------------
; ui_handle_input()
;
; I  R0 - ui_module address
;------------------------------------------------------------------------------
ui_handle_input
               PUSH    {R1, R2, R3, LR}
               MOV     R2, R0

               SVC     SVC_KEYPAD_SCAN                         ; scan the keyboard
               MOV     R1, R0
               LDR     R0, [R2, #MODULE_UI_LAST_KEYPAD_SCAN]   ; get last scan
               STR     R1, [R2, #MODULE_UI_LAST_KEYPAD_SCAN]   ; set last scan to new scan
               BL      keypad_get_new_presses                  ; get new presses
               BL      keypad_scan_read_index

               CMP     R1, #KEYPAD_NOBUTTON
               BEQ     ui_handle_input_return
               CMP     R1, #8
               BLE     ui_handle_input_track
               CMP     R1, #KEYPAD_IDX_ASTERISK
               BEQ     ui_handle_input_stop
               CMP     R1, #KEYPAD_IDX_0
               BEQ     ui_handle_input_about
               CMP     R1, #KEYPAD_IDX_HASH
               BEQ     ui_handle_input_play
               B       ui_handle_input_return

ui_handle_input_about
               LDR     R3, [R2, #MODULE_UI_PROJECT]            ; get project module address
               MOV     R1, #STATE_ABOUT                        ; set about state
               STR     R1, [R3, #MODULE_PROJECT_STATE]
               MOV     R0, R2                                  ; show about page
               BL      ui_show_about
               BL      player_stop_all_channels                ; stop any notes currently playing
               B       ui_handle_input_return

ui_handle_input_track
               LDR     R3, [R2, #MODULE_UI_PROJECT]            ; get project module address
               LDR     R0, [R3, #MODULE_PROJECT_MUSIC]         ; get music data address
               LDR     R0, [R0, #(tl_track_count-music_data)]  ; get number of tracks
               CMP     R1, R0                                  ; check if track is out of range
               BGE     ui_handle_input_return

               LDR     R0, [R3, #MODULE_PROJECT_PLAYER]        ; get player module address
               BL      player_load_track                       ; load the track
               MOV     R0, R2
               BL      ui_track_changed

               LDR     R1, [R3, #MODULE_PROJECT_STATE]         ; check if in about state
               CMP     R1, #STATE_ABOUT
               MOVEQ   R1, #STATE_PLAYING                      ; set to playing state
               STREQ   R1, [R3, #MODULE_PROJECT_STATE]
               B       ui_handle_input_return

ui_handle_input_stop
               LDR     R3, [R2, #MODULE_UI_PROJECT]            ; get project module address
               LDR     R1, [R3, #MODULE_PROJECT_STATE]         ; check if in about state
               CMP     R1, #STATE_ABOUT
               BEQ     ui_handle_input_return
               MOV     R1, #STATE_STOPPED                      ; set to stopped state
               STR     R1, [R3, #MODULE_PROJECT_STATE]
               BL      player_stop_all_channels                ; stop any notes currently playing
               B       ui_handle_input_return

ui_handle_input_play
               LDR     R3, [R2, #MODULE_UI_PROJECT]            ; get project module address
               LDR     R1, [R3, #MODULE_PROJECT_STATE]         ; check if in about state
               CMP     R1, #STATE_ABOUT
               BEQ     ui_handle_input_return
               CMP     R1, #STATE_FINISHED                     ; check if in finished state
               BEQ     ui_handle_input_return
               MOV     R1, #STATE_PLAYING                      ; set to playing state
               STR     R1, [R3, #MODULE_PROJECT_STATE]
               B       ui_handle_input_return
               
ui_handle_input_return
               MOV     R0, R2
               POP     {R1, R2, R3, PC}




