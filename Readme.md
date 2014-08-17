The University of Manchester  
COMP22712 Microcontrollers Project  
Ted John, May 2013  
http://intelorca.co.uk

***

# Description
An audio player which uses the piezo-electric buzzer (usually on a keypad) to
play music. The music is played by controlling the time period that the buzzer
will play a tone at. The music is represented by tracks, channels and sequences.

The code was written to deal with multiple channels but was not tested due to
time constraints. Tracks contain channels which are a playlist of sequences.
Sequences are a playlist of notes stored as words.

The FPGA was adapter to allow hardware timing for the buzzer output. The PIO_8
schematic was edited to use my own PIO schematic. This PIO schematic implemented
a hardware timer to pulse the buzzer output automatically using a time period
represented by a 16 bit integer in microseconds.

The keypad is used to control the player. The digit buttons, 1 to 9 select which
track to play. Asterisk pauses the current track. Hash resumes the track.
0 stops the track and shows the about screen.

# Technicalities
Examples of the music formatting can be seen at the bottom of this file. A
compiler was written in C# to parse the sequence files and generate an assembly
file defining the binary data representing the music. The notes are formatted as
follows:
    <key>[accidential][octave][timing]`

Key must always be specified... C, D, E, F, G, A, B or ~ for a rest.
Accidentals can be placed after # for sharp, flat was not implemented. The
octave and timing are optional parameters. If either is omitted then the
previous octave or timing state is maintained. Timing is measured in bars of
which there are always four beats in. It must be formatted as a fraction in
square brackets. For example: [1/2] for a minim, [1/4] for a crotchet, [1/32]
for a hemidemisemiquaver. [4/1] for a longa etc.

Each note is stored as a word.
```
  |-------------- bar fraction (value of 128 0x80 represents 1/2 bar)
  |  |----------- bars
  |  |  |-------- octave
  |  |  |  |----- key (0 for rest, 1 for C, 2 for D etc.)
  |  |  |  |
 80 01 05 01
```
The above is **C5[3/2]**.

The assembly code itself implements a small operating system on the board. There
are various unused functions which are not used and left there from previous
exercises. Most of the code sticks to a code convention.

Registers are used to pass arguments to a subroutine. A subroutine will always
preserve the contents of registers unless the registers are used as output
arguments. Typically registers are always used in order from R0. Subroutines
will usually push registers it uses for local variables at the start, onto the
stack and pop them before returning back to the caller address. If registers
need to be pushed or another subroutine is called within the subroutine, then
the link register will be pushed too and popped into the program counter
register as a return mechanism.

To help organise code, variables and reduce address constants, structures are
used. The project, player and user interface are separated into modules which
use structures to contain their relevant variables. Subroutines are then called
with the address of their module structure as the first argument. This is then
use as a base pointer to reference structure members.

The buzzer time period data bus is hard-wired to `0x20000000`. Storing a byte at
`0x20000000` and `0x20000001` will control the buzzer. The bytes are little endian.
The most significant bit in `0x20000001` is the enable pin for the buzzer.

The LCD functions allow double buffered writing to the screen as well as
scrolling. The LCD is only called to write over characters that have changed.

As programming in assembly can be quite tedious, breaking the program down
into many small subroutines helps reduce errors and debugging time in expense
for call and register preservation overhead.

# Running
To run the project, simply use komodo to load fpga.bit into the fpga using the
features dialog. Then load project.kmd into the board memory and run.

# File list
```
noteseq/*                      - noteseq, the C# application for compiling
                                 sequence files into ARM assembly. Also a
                                 simulator.

pio.eps                        - postscript of the altered PIO
fpga.bit                       - fpga netlist for changing buzzer on PIOA

keypad.s                       - functions for reading the keypad
lcd.s                          - functions for controlling the LCD
math.s                         - mathematical functions (just udivision really)
os.s                           - operating system and os functions
player.s                       - player module, functions for reading and
                                 playing the music tracks
project.s                      - main program loop
string.s                       - functions for manipulating strings
ui.s                           - user interface module, functions for displaying
                                 things on the LCD and reading user input

music_data.s                   - the data "file" containing the music tracks

project.kmd                    - pre-compiled copy of the program
```