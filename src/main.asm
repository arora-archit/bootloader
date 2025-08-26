; BIOS loads first sector of each bootable device into memory at 0x7C00
ORG 0x7C00

BITS 16 ; tells assembler to use 16-bit mode

%DEFINE ENDL 0x0D,0x0A ; new line

START:
  JMP MAIN
;---------------------------------------------;
; PUTS function to print a string
;   parameters: ds:si point to string
PUTS:
  PUSH SI
  PUSH AX

.LOOP:
  LODSB ; Loads next character in AL
  OR AL,AL ; checks if next character is null
  JZ .DONE

  MOV AH,0x0E ; call BIOS interrupt for writing in  TTY mode
  MOV BH,0 ; Page Number
  INT 0x10 ; INT 10H for `video` to print to screen

  JMP .LOOP

.DONE:
  POP AX
  POP SI
  RET



MAIN:
  ;---------------------------------------------;
  ; setting up  data segments
  MOV AX,0
  MOV DS,AX ; can't write to ds/es directly
  MOV ES,AX
  ;---------------------------------------------;

  ;---------------------------------------------;
  ; setting up stack
  MOV SS,AX
  MOV SP,0x7C00 ; stack grows downwards so we set it up before the OS which starts at 0x7C00
  ;---------------------------------------------;

  MOV SI, MSG
  CALL PUTS

  HLT ; halt


;---------------------------------------------;
; infinite loop to halt
.HALT:
  JMP .HALT
; `hlt` can be overriden by an interrupt
;---------------------------------------------;

MSG: DB 'Hello World!', ENDL, 0
;---------------------------------------------;
; pads the 510 bytes because we only need to define last two bytes as AA55
TIMES 510-($-$$) DB 0
; times is like run instruction `510` times
; $-$$ gives size of program in two bytes
;----------------------------------------------;

DW 0AA55H ; write AA55 to last two bites


