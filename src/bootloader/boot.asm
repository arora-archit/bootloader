; TODO:https://youtu.be/srbnMNk7K7k?list=PLFjM7v6KGMpjWYxnihhd4P3G0BhMB9ReG&t=760 
org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A


;
; FAT12 Boot Sector
;
jmp short start
nop

bdb_oem:                    db 'MSWIN4.1'           ; OEM identifier (8 bytes)
bdb_bytes_per_sector:       dw 512                  ; sector size = 512 bytes
bdb_sectors_per_cluster:    db 1                    ; 1 sector per cluster
bdb_reserved_sectors:       dw 1                    ; reserved sectors (boot sector)
bdb_fat_count:              db 2                    ; number of FAT tables
bdb_dir_entries_count:      dw 0E0h                 ; max root dir entries (224)
bdb_total_sectors:          dw 2880                 ; total sectors (2880 * 512 = 1.44MB)
bdb_media_descriptor_type:  db 0F0h                 ; F0h = 3.5" floppy
bdb_sectors_per_fat:        dw 9                    ; sectors per FAT
bdb_sectors_per_track:      dw 18                   ; geometry: sectors per track
bdb_heads:                  dw 2                    ; geometry: number of heads
bdb_hidden_sectors:         dd 0                    ; hidden sectors (not used)
bdb_large_sector_count:     dd 0                    ; total sectors if > 65535

; Extended Boot Record
ebr_drive_number:           db 0                    ; BIOS drive number (0x00 = floppy, 0x80 = HDD)
                            db 0                    ; reserved (unused)
ebr_signature:              db 29h                  ; EBR signature
ebr_volume_id:              db 12h, 34h, 56h, 78h   ; volume serial number (arbitrary)
ebr_volume_label:           db 'NANOBYTE OS'        ; volume label (11 bytes, padded with spaces)
ebr_system_id:              db 'FAT12   '           ; filesystem type (8 bytes)

;
; Bootloader code
;

start:
    ; Initialize data segments
    mov ax, 0
    mov ds, ax
    mov es, ax
    
    ; Initialize stack
    mov ss, ax
    mov sp, 0x7C00              ; stack starts at boot sector load address

    ; Some BIOSes load at 07C0:0000 instead of 0000:7C00
    ; Ensure execution continues at the correct segment
    push es
    push word .after
    retf

.after:

    ; Save boot drive number (set by BIOS in DL)
    mov [ebr_drive_number], dl

    ; Display "Loading..." message
    mov si, msg_loading
    call puts

    ; Query drive geometry from BIOS (sectors per track, head count)
    push es
    mov ah, 08h
    int 13h
    jc floppy_error
    pop es

    and cl, 0x3F                        ; clear upper 2 bits (keep 6-bit sector count)
    xor ch, ch
    mov [bdb_sectors_per_track], cx     ; store sectors/track

    inc dh
    mov [bdb_heads], dh                 ; store head count

    ; Compute LBA of root directory = reserved + (fats * sectors_per_fat)
    mov ax, [bdb_sectors_per_fat]
    mov bl, [bdb_fat_count]
    xor bh, bh
    mul bx                              ; ax = fats * sectors_per_fat
    add ax, [bdb_reserved_sectors]      ; add reserved sectors
    push ax

    ; Compute root directory size = (32 * entries) / bytes_per_sector
    mov ax, [bdb_dir_entries_count]
    shl ax, 5                           ; multiply by 32 (bytes per entry)
    xor dx, dx
    div word [bdb_bytes_per_sector]     ; result = sectors needed

    test dx, dx                         ; if remainder != 0, need 1 more sector
    jz .root_dir_after
    inc ax
.root_dir_after:

    ; Read root directory into memory
    mov cl, al                          ; number of sectors to read
    pop ax                              ; LBA of root directory
    mov dl, [ebr_drive_number]          ; restore drive number
    mov bx, buffer                      ; buffer location
    call disk_read

    ; Search root directory for "KERNEL.BIN"
    xor bx, bx
    mov di, buffer

.search_kernel:
    mov si, file_kernel_bin
    mov cx, 11                          ; compare 11 chars (8.3 filename)
    push di
    repe cmpsb
    pop di
    je .found_kernel

    add di, 32                          ; move to next entry (32 bytes each)
    inc bx
    cmp bx, [bdb_dir_entries_count]
    jl .search_kernel

    ; File not found
    jmp kernel_not_found_error

.found_kernel:

    ; Load starting cluster number of kernel
    mov ax, [di + 26]                   ; offset 26 = first cluster
    mov [kernel_cluster], ax

    ; Load FAT into memory
    mov ax, [bdb_reserved_sectors]
    mov bx, buffer
    mov cl, [bdb_sectors_per_fat]
    mov dl, [ebr_drive_number]
    call disk_read

    ; Load kernel by following FAT chain
    mov bx, KERNEL_LOAD_SEGMENT
    mov es, bx
    mov bx, KERNEL_LOAD_OFFSET

.load_kernel_loop:
    
    ; Read one cluster
    mov ax, [kernel_cluster]
    add ax, 31                          ; cluster → LBA (hardcoded for 1.44MB FAT12)
    mov cl, 1
    mov dl, [ebr_drive_number]
    call disk_read

    add bx, [bdb_bytes_per_sector]      ; advance buffer pointer

    ; Look up next cluster in FAT
    mov ax, [kernel_cluster]
    mov cx, 3
    mul cx
    mov cx, 2
    div cx                              ; ax = FAT entry index, dx = cluster parity

    mov si, buffer
    add si, ax
    mov ax, [ds:si]                     ; fetch FAT entry

    or dx, dx
    jz .even

.odd:
    shr ax, 4                           ; odd cluster
    jmp .next_cluster_after

.even:
    and ax, 0x0FFF                      ; even cluster

.next_cluster_after:
    cmp ax, 0x0FF8                      ; check for end-of-chain
    jae .read_finish

    mov [kernel_cluster], ax
    jmp .load_kernel_loop

.read_finish:
    
    ; Jump to loaded kernel
    mov dl, [ebr_drive_number]          ; boot device in DL

    mov ax, KERNEL_LOAD_SEGMENT         ; set DS/ES to kernel segment
    mov ds, ax
    mov es, ax

    jmp KERNEL_LOAD_SEGMENT:KERNEL_LOAD_OFFSET

    jmp wait_key_and_reboot             ; should never return

    cli                                 ; disable interrupts
    hlt                                 ; halt CPU


;
; Error handling
;

floppy_error:
    mov si, msg_read_failed
    call puts
    jmp wait_key_and_reboot

kernel_not_found_error:
    mov si, msg_kernel_not_found
    call puts
    jmp wait_key_and_reboot

wait_key_and_reboot:
    mov ah, 0
    int 16h                     ; wait for key press
    jmp 0FFFFh:0                ; jump to BIOS reset vector (reboot)

.halt:
    cli                         ; disable interrupts
    hlt                         ; halt CPU


;
; Print a null-terminated string to the screen
; Input:
;   DS:SI → string address
;
puts:
    push si
    push ax
    push bx

.loop:
    lodsb                       ; load next char into AL
    or al, al                   ; check for null terminator
    jz .done

    mov ah, 0x0E                ; BIOS teletype output
    mov bh, 0                   ; display page 0
    int 0x10

    jmp .loop

.done:
    pop bx
    pop ax
    pop si    
    ret

;
; Disk I/O routines
;

;
; Convert LBA → CHS
; Input:
;   AX = LBA
; Output:
;   CX[0-5] = sector
;   CX[6-15] = cylinder
;   DH = head
;
lba_to_chs:

    push ax
    push dx

    xor dx, dx
    div word [bdb_sectors_per_track]    ; LBA / sectors_per_track -> quotient = track, remainder = sector
    inc dx                              ; sector = remainder + 1
    mov cx, dx                          ; CX = sector

    xor dx, dx
    div word [bdb_heads]                ; track / number of heads -> quotient = cylinder, remainder = head
    mov dh, dl                          ; DH = head
    mov ch, al                          ; CH = cylinder low byte
    shl ah, 6
    or cl, ah                           ; put cylinder high bits in CL

    pop ax
    mov dl, al                          ; restore DL
    pop ax
    ret


;
; Read sectors from disk
; Input:
;   AX = starting LBA
;   CL = number of sectors (≤128)
;   DL = drive number
;   ES:BX = buffer address
;
disk_read:

    push ax
    push bx
    push cx
    push dx
    push di

    push cx                             ; save sector count
    call lba_to_chs                     ; convert LBA → CHS
    pop ax                              ; AL = sector count
    
    mov ah, 02h                         ; BIOS read sectors
    mov di, 3                           ; retry counter

.retry:
    pusha
    stc                                 ; some BIOSes need carry set
    int 13h
    jnc .done                           ; success if carry clear

    ; Read failed → reset controller and retry
    popa
    call disk_reset

    dec di
    test di, di
    jnz .retry

.fail:
    ; All retries exhausted
    jmp floppy_error

.done:
    popa

    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret


;
; Reset disk controller
; Input:
;   DL = drive number
;
disk_reset:
    pusha
    mov ah, 0
    stc
    int 13h
    jc floppy_error
    popa
    ret


msg_loading:            db 'Loading...', ENDL, 0
msg_read_failed:        db 'Read from disk failed!', ENDL, 0
msg_kernel_not_found:   db 'KERNEL.BIN file not found!', ENDL, 0
file_kernel_bin:        db 'KERNEL  BIN'
kernel_cluster:         dw 0

KERNEL_LOAD_SEGMENT     equ 0x2000
KERNEL_LOAD_OFFSET      equ 0


times 510-($-$$) db 0
dw 0AA55h

buffer:
