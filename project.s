;------------------------------------------------------------------------------
;           Project
;           Ted John
;           Version 1.0
;           16 April 2013
;
; This programme is an audio player.
;
;------------------------------------------------------------------------------
               INCLUDE ./os.s

;------------------------------------------------------------------------------
               ORG     OFFSET_USER

;------------------------------------------------------------------------------
; 
;------------------------------------------------------------------------------
STATE_ABOUT            EQU     0
STATE_STOPPED          EQU     1
STATE_PLAYING          EQU     2
STATE_FINISHED         EQU     3
STATE_END              EQU     4

;------------------------------------------------------------------------------
; Program variables
;------------------------------------------------------------------------------
module_project         DEFS    MODULE_PROJECT_SIZE
module_ui              DEFS    MODULE_UI_SIZE
module_player          DEFS    MODULE_PLAYER_SIZE
               ALIGN

;------------------------------------------------------------------------------
; main() - user program entry point
;
; R7 - port i/o
;------------------------------------------------------------------------------ 
main
               MOV     SP, #OFFSET_ENDRAM                      ; initialise user stack pointer

               MOV     R3, #OFFSET_USER
               ADD     R0, R3, #(module_project-OFFSET_USER)
               ADD     R1, R3, #(module_ui-OFFSET_USER)
               ADD     R2, R3, #(module_player-OFFSET_USER)
               BL      project_init                            ; initialise the project module
               BL      project_run                             ; run the project program
               SVC     SVC_EXIT                                ; close the operating system

;------------------------------------------------------------------------------
; MODULE_PROJECT - structure for storing the project variables
;------------------------------------------------------------------------------
RECORD
MODULE_PROJECT_UI                  WORD
MODULE_PROJECT_PLAYER              WORD
MODULE_PROJECT_MUSIC               WORD
MODULE_PROJECT_STATE               WORD
MODULE_PROJECT_SIZE                ALIAS

;------------------------------------------------------------------------------
; project_init() - display information on the LCD
;
; I  R0 - project module address
; I  R1 - ui module address
; I  R2 - player module address
;------------------------------------------------------------------------------
project_init_music_offset
               DEFW    music_data
project_init
               PUSH    {R0, R1, R3, LR}
               STR     R1, [R0, #MODULE_PROJECT_UI]            ; store ui module address
               STR     R2, [R0, #MODULE_PROJECT_PLAYER]        ; store player module address

               LDR     R3, project_init_music_offset           ; store music data address
               STR     R3, [R0, #MODULE_PROJECT_MUSIC]

               MOV     R1, R0                                  ; project module address
               MOV     R0, R2                                  ; player module address
               BL      player_init                             ; initialise player module

               LDR     R0, [R1, #MODULE_PROJECT_UI]
               BL      ui_init

               POP     {R0, R1, R3, PC}

;------------------------------------------------------------------------------
; project_run() - run the project program
;
; I  R0 - project module address
;
;    R2 - project module address
;------------------------------------------------------------------------------
project_run
               PUSH    {R0, R1, R2, LR}
               MOV     R2, R0
                                                               ; initialisation
               MOV     R0, #STATE_ABOUT                        ; set about state
               STR     R0, [R2, #MODULE_PROJECT_STATE]
               LDR     R0, [R2, #MODULE_PROJECT_UI]
               BL      ui_show_about

project_run_loop
               LDR     R1, [R2, #MODULE_PROJECT_STATE]
               CMP     R1, #STATE_PLAYING
               BNE     project_run_post_playing_check

               LDR     R0, [R2, #MODULE_PROJECT_PLAYER]        ; update the player
               BL      player_update
               CMP     R1, #FALSE                              ; check if track has finished
               MOVEQ   R1, #STATE_FINISHED                     ;   set state to stopped
               STREQ   R1, [R2, #MODULE_PROJECT_STATE]

project_run_post_playing_check
               LDR     R0, [R2, #MODULE_PROJECT_UI]            ; update the ui (time)

               CMP     R1, #STATE_ABOUT
               BEQ     project_run_post_about_check               
               BL      ui_track_updated

project_run_post_about_check
               BL      ui_handle_input                         ; handle input

               LDR     R0, [R2, #MODULE_PROJECT_STATE]
               CMP     R0, #STATE_END
               BNE     project_run_loop

               POP     {R0, R1, R2, PC}

;------------------------------------------------------------------------------
; Include other modules
;------------------------------------------------------------------------------
               INCLUDE ./player.s
               INCLUDE ./ui.s

;------------------------------------------------------------------------------
; Include the music data
;------------------------------------------------------------------------------
music_data
               INCLUDE ./music_data.s
