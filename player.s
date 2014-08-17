;------------------------------------------------------------------------------
;           Project
;           Ted John
;           Version 1.0
;           16 April 2013
;
; Code for loading, reading and playing music.
;
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; player_time_periods (in microseconds)
;------------------------------------------------------------------------------
player_time_periods
       ;      C,    C#,     D,    D#,     E,     F,    F#,     G,    G#,     A,    A#,     B
    DEFW  61162, 57737, 54496, 51414, 48544, 45809, 43253, 40816, 38521, 36364, 34317, 32394  ; octave 0
    DEFW  30581, 28860, 27241, 25714, 24272, 22910, 21622, 20408, 19264, 18182, 17161, 16197  ; octave 1
    DEFW  15288, 14430, 13620, 12857, 12134, 11453, 10811, 10204,  9631,  9091,  8581,  8099  ; octave 2
    DEFW   7645,  7216,  6811,  6428,  6068,  5727,  5405,  5102,  4816,  4545,  4290,  4050  ; octave 3
    DEFW   3822,  3608,  3405,  3214,  3034,  2863,  2703,  2551,  2408,  2273,  2145,  2025  ; octave 4
    DEFW   1911,  1804,  1703,  1607,  1517,  1432,  1351,  1276,  1204,  1136,  1073,  1012  ; octave 5
    DEFW    956,   902,   851,   804,   758,   716,   676,   638,   602,   568,   536,   506  ; octave 6
    DEFW    478,   451,   426,   402,   379,   358,   338,   319,   301,   284,   268,   253  ; octave 7
    DEFW    239,   225,   213,   201                                                          ; octave 8

;------------------------------------------------------------------------------
PLAYER_MAX_CHANNELS    EQU     2

BEATS_PER_BAR          EQU     4

NOTE_BARFRAC_SHIFT     EQU     24
NOTE_BAR_SHIFT         EQU     16
NOTE_OCTAVE_SHIFT      EQU     8
NOTE_KEY_SHIFT         EQU     0

SEQUENCE_INDEX_END     EQU     -1
SEQUENCE_END           EQU     0

;------------------------------------------------------------------------------
; MODULE_PLAYER structure
;------------------------------------------------------------------------------
RECORD
MODULE_PLAYER_PROJECT              WORD
MODULE_PLAYER_TRACK_INDEX          WORD
MODULE_PLAYER_TRACK_NAME           WORD
MODULE_PLAYER_TEMPO                WORD
MODULE_PLAYER_NUM_CHANNELS         WORD
MODULE_PLAYER_LAST_TICK            WORD
MODULE_PLAYER_ELAPSED_TICKS        WORD
MODULE_PLAYER_CHANNELS             BYTE      (CHANNEL_STATE_SIZE * PLAYER_MAX_CHANNELS)
MODULE_PLAYER_SIZE                 ALIAS

;------------------------------------------------------------------------------
; CHANNEL_STATE structure
;------------------------------------------------------------------------------
RECORD
CHANNEL_STATE_INDEX                WORD
CHANNEL_STATE_FINISHED             WORD
CHANNEL_STATE_WAITTIME             WORD
CHANNEL_STATE_SEQINDEX_ADDRESS     WORD
CHANNEL_STATE_SEQUENCE_ADDRESS     WORD
CHANNEL_STATE_SIZE                 ALIAS

;------------------------------------------------------------------------------
; player_init() - initialises the player module
;
; I  R0 - player module address
; I  R1 - project module address
;------------------------------------------------------------------------------
player_init
               PUSH    {R2, R3, LR}
               STR     R1, [R0, #MODULE_PLAYER_PROJECT]

               MOV     R3, #0                                  ; set each channel state index
               ADD     R2, R0, #MODULE_PLAYER_CHANNELS

player_init_loop
               STR     R3, [R2, #CHANNEL_STATE_INDEX]
               ADD     R2, R2, #CHANNEL_STATE_SIZE
               ADD     R3, R3, #1
               CMP     R3, #PLAYER_MAX_CHANNELS
               BLT     player_init_loop

               POP     {R2, R3, PC}

;------------------------------------------------------------------------------
; player_load_track() - loads a particular track
;
; I  R0 - player module address
; I  R1 - track index
;------------------------------------------------------------------------------
player_load_track
               PUSH    {R1, R2, R3, LR}
               STR     R1, [R0, #MODULE_PLAYER_TRACK_INDEX]    ; set track index

               LDR     R2, [R0, #MODULE_PLAYER_PROJECT]        ; get music data address
               LDR     R2, [R2, #MODULE_PROJECT_MUSIC]
               ADD     R3, R2, #(tl_tracks-music_data)         ; get track data address
               LDR     R1, [R3, R1 LSL #2]

               BL      player_read_track_info                  ; read the track info
               BL      player_read_track_channels              ; read the track channels

               MOV     R3, #0                                  ; initialise timing
               STR     R3, [R0, #MODULE_PLAYER_LAST_TICK]
               STR     R3, [R0, #MODULE_PLAYER_ELAPSED_TICKS]

               POP     {R1, R2, R3, PC}

;------------------------------------------------------------------------------
; player_read_track_info() - read the track information from the given stream
;
; I  R0 - player module address
; IO R1 - stream
;------------------------------------------------------------------------------
player_read_track_info
               PUSH    {R2, LR}
               STR     R1, [R0, #MODULE_PLAYER_TRACK_NAME]     ; load track name
               MOV     R2, R0                                  ; preserve R0
               MOV     R0, R1
               BL      strend                                  ; get null terminator address
               ADD     R0, R0, #4                              ; skip null terminator and alignment
               BIC     R1, R0, #3
               MOV     R0, R2                                  ; restore R0

               LDR     R2, [R1], #4                            ; load tempo
               STR     R2, [R0, #MODULE_PLAYER_TEMPO]
               LDR     R2, [R1], #4                            ; load number of channels
               STR     R2, [R0, #MODULE_PLAYER_NUM_CHANNELS]
               POP     {R2, PC}

;------------------------------------------------------------------------------
; player_read_track_channels() - initialises all the channel states
;
; I  R0 - player module address
; IO R1 - stream (doesn't read > 2 channels, stream would be in wrong place)
;
;    R2 - address of channel state
;    R3 - number of channels
;    R4 - channel iterator index
;------------------------------------------------------------------------------
player_read_track_channels
               PUSH    {R2, R3, R4, LR}
               ADD     R2, R0, #MODULE_PLAYER_CHANNELS         ; get address of first channel state
               LDR     R3, [R0, #MODULE_PLAYER_NUM_CHANNELS]   ; get num channels
               MOV     R4, #0                                  ; set channel iterator index

player_read_track_channels_loop
               CMP     R4, R3                                  ; loop condition
               BGE     player_read_track_channels_end
               CMP     R4, #PLAYER_MAX_CHANNELS                ; skip rest of the channels
               BGE     player_read_track_channels_end
               BL      player_read_track_channel               ; read the channel

player_read_track_channels_next
               ADD     R2, R4, #CHANNEL_STATE_SIZE             ; next channel
               ADD     R4, R3, #1
               B       player_read_track_channels_loop

player_read_track_channels_end
               POP     {R2, R3, R4, PC}

;------------------------------------------------------------------------------
; player_read_track_channel() - initialises a single channel state
;
; I  R0 - player module address
; IO R1 - stream
; I  R2 - channel state address
; I  R4 - first sequence index
;------------------------------------------------------------------------------
player_read_track_channel
               PUSH    {R1, R3, R4, LR}
               MOV     R3, #FALSE                              ; initialise channel
               STR     R3, [R2, #CHANNEL_STATE_FINISHED]
               MOV     R3, #0
               STR     R3, [R2, #CHANNEL_STATE_WAITTIME]
               STR     R3, [R2, #CHANNEL_STATE_SEQUENCE_ADDRESS]
                                                               ; set the sequence index address
               STR     R1, [R2, #CHANNEL_STATE_SEQINDEX_ADDRESS]
               LDR     R4, [R1]

player_read_track_channel_loop                                 ; skip the rest of the indicies
               LDR     R3, [R1], #4
               CMP     R3, #SEQUENCE_INDEX_END
               BNE     player_read_track_channel_loop

               MOV     R1, R2                                  ; channel state address
               MOV     R2, R4                                  ; sequence index
               BL      player_channel_load_sequence

               POP     {R1, R3, R4, PC}

;------------------------------------------------------------------------------
; player_update() - plays any outstanding notes
;
; I  R0 - player module address
; O  R1 - true if the track has not finished, otherwise false
;------------------------------------------------------------------------------
player_update
               PUSH    {LR}
               BL      player_tick                             ; check if there has been a tick
               CMP     R1, #FALSE
               MOVEQ   R1, #TRUE
               BLNE    player_update_channels                  ; update channels if so
               POP     {PC}

;------------------------------------------------------------------------------
; player_tick() - checks if there has been a tick since last call
;
; I  R0 - player module address
; O  R1 - true if there has been a tick, otherwise false
;------------------------------------------------------------------------------
player_tick
               PUSH    {R2, LR}
               MOV     R2, #os_tick_count                      ; calculate elapsed milliseconds
               LDR     R2, [R2]
               LDR     R1, [R0, #MODULE_PLAYER_LAST_TICK]
               SUB     R3, R2, R1
               CMP     R3, #0                                  ; check if at least 1ms has elapsed, otherwise return false
               MOVEQ   R1, #FALSE
               BEQ     player_tick_return

               STR     R2, [R0, #MODULE_PLAYER_LAST_TICK]      ; update player last tick
               LDR     R2, [R0, #MODULE_PLAYER_ELAPSED_TICKS]  ; update player elapsed milliseconds
               ADD     R2, R2, #1
               STR     R2, [R0, #MODULE_PLAYER_ELAPSED_TICKS]
               MOVEQ   R1, #TRUE

player_tick_return
               POP     {R2, PC}

;------------------------------------------------------------------------------
; player_update_channels() - updates all the channels
;
; I  R0 - player module address
; O  R1 - true if not all channels are finished, otherwise false
;
;    R1 - channel state address
;    R2 - channel state index
;    R3 - num channels
;    R4 - not all channels finished flag
;------------------------------------------------------------------------------
player_update_channels
               PUSH    {R2, R3, R4, R5, LR}
               MOV     R4, #FALSE                              ; set not all channels finished flag
               ADD     R1, R0, #MODULE_PLAYER_CHANNELS         ; initialise channel state loop
               MOV     R2, #0
               LDR     R3, [R0, #MODULE_PLAYER_NUM_CHANNELS]

player_update_channels_loop
               CMP     R2, R3                                  ; loop condition
               BGE     player_update_channels_end
               BL      player_update_channel                   ; update channel
               LDR     R5, [R1, #CHANNEL_STATE_FINISHED]       ; check if channel has not finished
               CMP     R5, #FALSE
               BNE     player_update_channels_next
               MOV     R4, #TRUE

player_update_channels_next
               ADD     R1, R2, #CHANNEL_STATE_SIZE             ; next iteration
               ADD     R2, R2, #1
               B       player_update_channels_loop
player_update_channels_end
               MOV     R1, R4                                  ; return all channels finished flag
               POP     {R2, R3, R4, R5, PC}

;------------------------------------------------------------------------------
; player_update_channel() - updates a channel
;
; I  R0 - player module address
; I  R1 - channel state address
;------------------------------------------------------------------------------
player_update_channel
               PUSH    {R2, R3, LR}
               LDR     R2, [R1, #CHANNEL_STATE_FINISHED]       ; check if channel has finished
               CMP     R2, #FALSE
               BNE     player_update_channel_return

               LDR     R2, [R1, #CHANNEL_STATE_WAITTIME]       ; decrease wait time by elapsed ticks
               SUB     R2, R2, #1
               STR     R2, [R1, #CHANNEL_STATE_WAITTIME]
               CMP     R2, #0              
               BLLE    player_channel_next_note                ; play the next note on the channel    
           
player_update_channel_return
               POP     {R2, R3, PC}

;------------------------------------------------------------------------------
; player_channel_next_note() - moves the channel onto the next note and starts
;                              playing it
;
; I  R0 - player module address
; I  R1 - channel state address
;------------------------------------------------------------------------------
player_channel_next_note
               PUSH    {R0, R1, R2, R3, LR}
               
               LDR     R2, [R1, #CHANNEL_STATE_SEQUENCE_ADDRESS]
               LDR     R3, [R2]                                ; get the note
               CMP     R3, #SEQUENCE_END                       ; check if this is a sequence end marker
               ADREQ   LR, player_channel_next_note_return     ; call next sequence and return if end of sequence
               BEQ     player_channel_next_sequence

               ADD     R2, R2, #4
               STR     R2, [R1, #CHANNEL_STATE_SEQUENCE_ADDRESS]
               MOV     R2, R0                                  ; move player module address to R2
               MOV     R0, R3                                  ; play the note
               MOV     R3, R1                                  ; move channel state address to R3
               LDR     R1, [R3, #CHANNEL_STATE_INDEX]
               BL      player_play_note

               LDR     R1, [R2, #MODULE_PLAYER_TEMPO]
               BL      player_get_note_time
               STR     R0, [R3, #CHANNEL_STATE_WAITTIME]

player_channel_next_note_return
               POP     {R0, R1, R2, R3, PC}

;------------------------------------------------------------------------------
; player_channel_next_sequence() - moves the channel onto the next seqeuence
;                                  and plays the first note
;
; I  R0 - player module address
; I  R1 - channel state address
;------------------------------------------------------------------------------
player_channel_next_sequence
               PUSH    {R2, LR}
                                                               ; get sequence index address
               LDR     R2, [R1, #CHANNEL_STATE_SEQINDEX_ADDRESS]
               ADD     R2, R2, #4                              ; move to next index
               STR     R2, [R1, #CHANNEL_STATE_SEQINDEX_ADDRESS]
               LDR     R2, [R2]                                ; load actual index
               CMP     R2, #SEQUENCE_INDEX_END                 ; check if the end of sequence
               BEQ     player_channel_next_sequence_fi

               BL      player_channel_load_sequence
               BL      player_channel_next_note
               B       player_channel_next_sequence_re

player_channel_next_sequence_fi
               MOV     R2, #TRUE                               ; set finished state
               STR     R2, [R1, #CHANNEL_STATE_FINISHED]
               MOV     R2, R0                                  ; preserve R0
               LDR     R0, [R1, #CHANNEL_STATE_INDEX]          ; stop this channel
               BL      player_stop_note
               MOV     R2, #0                                  ; restore R0

player_channel_next_sequence_re
               POP     {R2, PC}

;------------------------------------------------------------------------------
; player_channel_load_sequence() - loads the first note of the 
;                                  and plays the first note
;
; I  R0 - player module address
; I  R1 - channel state address
; I  R2 - sequence index
;------------------------------------------------------------------------------
player_channel_load_sequence
               PUSH    {R3, LR}
               LDR     R3, [R0, #MODULE_PLAYER_PROJECT]        ; get music data address
               LDR     R3, [R3, #MODULE_PROJECT_MUSIC]
               ADD     R3, R3, #(tl_seq-music_data)            ; get sequence data address
               LDR     R3, [R3, R2 LSL #2]
                                                               ; set channel state sequence
               STR     R3, [R1, #CHANNEL_STATE_SEQUENCE_ADDRESS]
               POP     {R3, PC}

;------------------------------------------------------------------------------
; player_stop_all_channels() - stops each channel note
;
;    R0 - channel index
;    R1 - number of channels
;------------------------------------------------------------------------------
player_stop_all_channels
               PUSH    {R0, R1, LR}
               MOV     R1, #PLAYER_MAX_CHANNELS
               MOV     R0, #0
player_stop_all_channels_loop
               CMP     R0, R1
               BGE     player_stop_all_channels_return
               BL      player_stop_note
               ADD     R0, R0, #1
               B       player_stop_all_channels_loop
player_stop_all_channels_return
               POP     {R0, R1, PC}

;------------------------------------------------------------------------------
; player_stop_note() - stops whatever note is playing on a channel
;
; I  R0 - channel index
;------------------------------------------------------------------------------
player_stop_note
               PUSH    {R0, R1, LR}
               MOV     R1, R0
               MOV     R0, #0
               SVC     SVC_BUZZ_SET
               POP     {R0, R1, PC}

;------------------------------------------------------------------------------
; player_play_note() - plays a certain note on a channel
;
; I  R0 - note
; I  R1 - channel index
;------------------------------------------------------------------------------
player_play_note_periods_offset
               DEFW    player_time_periods
player_play_note
               PUSH    {R0, R2, R3, LR}

               MOV     R2, R0 LSR #NOTE_KEY_SHIFT              ; get key and octave from word
               AND     R2, R2, #&FF
               MOV     R3, R0 LSR #NOTE_OCTAVE_SHIFT
               AND     R3, R3, #&FF

               CMP     R2, #0                                  ; check if note is a rest
               BLEQ    player_stop_note
               BEQ     player_play_note_return

               MOV     R0, #12                                 ; combine key and octave for lookup table
               MUL     R3, R3, R0
               ADD     R2, R2, R3
               SUB     R2, R2, #1                              ; offset by -1, (rest not in lookup table)

               LDR     R3, player_play_note_periods_offset     ; get note time period from lookup table
               LDR     R0, [R3, R2 LSL #2]
               ORR     R0, R0, #BUZZER_ENABLE_MASK             ; set enable
               SVC     SVC_BUZZ_SET

player_play_note_return
               POP     {R0, R2, R3, PC}

;------------------------------------------------------------------------------
; player_get_note_time() - gets the number of ticks to play a specific note for
;
; IO R0 - note / time
; I  R1 - tempo
;------------------------------------------------------------------------------
player_get_note_time
               PUSH    {R1, R2, R3, LR}
               MOV     R2, R0 LSR #(NOTE_BAR_SHIFT - 8)        ; get bar length
               AND     R2, R2, #&FF00
               MOV     R3, R0 LSR #NOTE_BARFRAC_SHIFT
               AND     R3, R3, #&FF
               ORR     R2, R2, R3
               MOV     R2, R2 LSL #2                           ; multiply by BEATS_PER_BAR
               MOV     R0, #60                                 ; convert to milliseconds
               MUL     R2, R2, R0
               MOV     R0, #1000
               MUL     R2, R2, R0
               MOV     R0, R2 LSR #8                           ; divide by 256 (bar value)
               BL      udivision                               ; divide by tempo
               POP     {R1, R2, R3, PC}

