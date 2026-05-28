[BITS 16] ; produce 16 bit code since we are on 16bit real mode right now
[ORG 0x7c00] ; address in which BIOS loads bootloader. tells assembler that code will be loaded at the given address

start:
    cli
    ; zero out CPU registers to gurantee a clean state
    mov ax, 0x00
    mov ds, ax ; data segment
    mov es, ax ; extra segment
    mov ss, ax ; stack segment
    mov sp, 0x7c00 ; code will start at stack pointer so code will go from 0x00 to 0x7c00
    sti ; interupts enabled after the next instruction
    mov si, msg ; source index register. points to source of memory operation. commonly used for string and arrays
    call print

print:
    mov ah, 0x0E ; Teletype output
.loop:
    lodsb ; load next byte
    cmp al, 0
    je .done
    int 10h ; teletype output to print char in al register and advance the cursor
    jmp .loop

.done:
    ret


msg : db 'Test', 0 ; db can take a comma separated list of bytes. 'Test' is expanded to comma separated list of bytes

; times = repeating following instruction n times
; $ = current addess
; $$ = start address
; 510 - (current - start) = remaining space left to fill
times 510 - ($ - $$) db 0 ; pad until you reach a total of 510 bytes

dw 0xAA55 ; boot signature

