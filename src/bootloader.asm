[BITS 16] ; produce 16 bit code since we are on 16bit real mode right now
[ORG 0x7c00] ; address in which BIOS loads bootloader. tells assembler that code will be loaded at the given address

KERNEL_LOADER_SECTORS equ 10 ; subject to change

struc DiskAddressPacket
    .size resb 1 ; size of packet
    .reserved resb 1 ; should always be zero
    .sectors resw 1 ; number of sectors to transfer. The max is usually 127
    .buffer resd 1 ; transfer buffer
    .address resq 1 ; LBA address of sector to read from disk
endstruc

start:
    cli
    ; zero out CPU registers to gurantee a clean state
    mov ax, 0x00
    mov ds, ax ; data segment
    mov es, ax ; extra segment
    mov ss, ax ; stack segment
    mov sp, 0x7c00 ; stack starts below bootloader and grows to lower addresses
    sti ; interupts enabled after the next instruction
    ; read stage 2 from disk
    mov ah, 0x41
    mov bx, 0x55AA
    mov dl, 0x80
    int 0x13 ; call BIOS disk services to check whether extended read and write services are supported
    test cx, 0x0001
    jz error ; bit zero of cx is not set.
    jc error ; jump if carry flag is set
    cmp bx, 0xAA55
    jne error

    mov si, debug
    call print

    mov ax, 0x00
    mov ds, ax ; ensure that ds is pointing to segment 0
    mov si, packet
    mov ah, 0x42
    mov dl, 0x80 ; the C drive
    int 0x13

    ; check whether operation was successful
    jc error
    cmp ah, 0x00
    jne error
    
    jmp hang

error:
    mov si, hardwareerr
    call print
hang:
    jmp hang


print:
    cld ; reset direction flag to go forward
    mov ah, 0x0E ; Teletype output
.loop:
    lodsb ; load next byte
    cmp al, 0
    je .done
    int 10h ; teletype output to print char in al register and advance the cursor
    jmp .loop

.done:
    ret

debug : db 'debug', 0
hardwareerr : db 'incompatible-hardware-error', 0

align 4 ; insert padding so that the next thing is aligned on a 4 byte boundary. happens during assembly time
packet: istruc DiskAddressPacket
    at DiskAddressPacket.size, db 0x10
    at DiskAddressPacket.reserved, db 0
    at DiskAddressPacket.sectors, dw KERNEL_LOADER_SECTORS
    at DiskAddressPacket.buffer, dd 0x7E00
    at DiskAddressPacket.address, dq 1
iend
; times = repeating following instruction n times
; $ = current addess
; $$ = start address
; 510 - (current - start) = remaining space left to fill
times 510 - ($ - $$) db 0 ; pad until you reach a total of 510 bytes

dw 0xAA55 ; boot signature
