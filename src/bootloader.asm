[BITS 16] ; produce 16 bit code since we are on 16bit real mode right now
[ORG 0x7c00] ; address in which BIOS loads bootloader. tells assembler that code will be loaded at the given address


%include "debug/debug-real.asm"

start:
    cli
    ; zero out CPU registers to gurantee a clean state
    mov ax, 0x00
    mov ds, ax ; data segment
    mov es, ax ; extra segment
    mov ss, ax ; stack segment
    mov sp, 0x7c00 ; stack starts below bootloader and grows to lower addresses
    sti ; interupts enabled after the next instruction
    call print
; times = repeating following instruction n times
; $ = current addess
; $$ = start address
; 510 - (current - start) = remaining space left to fill
times 510 - ($ - $$) db 0 ; pad until you reach a total of 510 bytes

dw 0xAA55 ; boot signature
