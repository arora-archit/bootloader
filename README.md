# Bootloader

### An x86 assembly bootloader using legacy BIOS interrupts to parse a FAT12 file system and load a kernel from a floppy disk into memory

## Requirements

- `make`
- `nasm`
- `qemu-system-x86`
- `bochs-x`, `bochsbios`, `vgabios` for debugging

## Build Instructions

run `make`

## Running with qemu

execute `qemu-system-i386 -fda build/main_floppy.img`

## Debugging

run `./debug.sh`
