; BIOS loads first sector of each bootable device into memory at 0x7C00
ORG 0x7C00

BITS 16 ; tells assembler to use 16-bit mode

%DEFINE ENDL 0x0D,0x0A ; new line

;--------------------------------------------;
; FAT12 header
JMP SHORT START
NOP

bdb_oem:                    db 'MSWIN4.1'
bdb_bytes_per_sector:       dw 512
bdb_sectors_per_cluster:    db 1
bdb_reserved_sectors:       dw 1
bdb_fat_count:              db 2
bdb_dir_entries_count:      dw 0E0h
bdb_total_sectors:          dw 2880
bdb_media_descriptor_type:  db 0F0h
bdb_sectors_per_fat:        dw 9
bdb_sectors_per_track:      dw 18
bdb_heads:                  dw 2
bdb_hidden_sectors:         dd 0
bdb_large_sector_counts:    dd 0

ebr_drive_number:           db 0
                            db 0
ebr_signature:              db 29h
ebr_volume_id:              db 12h,34h,45h,78h
ebr_volume_label:           db 'LABEL      '
ebr_system_id:              db 'FAT12   '
;---------------------------------------------;


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


