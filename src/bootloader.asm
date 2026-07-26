[BITS 16] ; produce 16 bit code since we are on 16bit real mode right now
[ORG 0x7c00] ; address in which BIOS loads bootloader. tells assembler that code will be loaded at the given address

%ifdef SECTORS
    KERNEL_LOADER_SECTORS equ SECTORS
%else
    KERNEL_LOADER_SECTORS equ 1
%endif

struc DiskAddressPacket
    .size resb 1 ; size of packet
    .reserved resb 1 ; should always be zero
    .sectors resw 1 ; number of sectors to transfer. The max is usually 127
    .buffer resd 1 ; transfer buffer (where to load in RAM)
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

    mov [boot_drive], dl
    sti ; interupts enabled after the next instruction

    ; clear screen
    mov ah, 0x06 ; requests the scroll up function
    mov al, 0x00 ; instrcut BIOS to clear window
    mov bh, 0x02 ; specify white text on black
    mov cx, 0x0000 ; top coordinates (0,0)
    mov dx, 0x184f ; bottom coordinates (furthest down and furthest right)
    int 0x10

    ; reset cursor pos to beginning
    mov ah, 0x02
    mov bh, 0x00
    mov dx, 0x0000 ; coordinates (0,0)
    int 0x10

    call get_a20
    cmp ax, 1
    jne enable_a20

continue:
    ; check whether extended read and write services are supported
    mov ah, 0x41
    mov bx, 0x55aa
    mov dl, 0x80
    int 0x13

    jc error
    test cx, 0x0001
    jz error
    cmp bx, 0xaa55
    jne error

    call stage_two

    ; check whether operation was successful
    jc reload
    cmp ah, 0x00
    jne reload
    
load_kernel_loader:
    xor dl, dl
    mov dl, [boot_drive]
    push 0x7e00 ; push address of stage 2 to top of stack
    ret ; pop it from top of the stack and jump to it

; get whether the A20 line is enabled or not
; ax register is one if A20 line is enabled
get_a20:
    ; preserve current state of program
    pushf
    push si
    push di
    push ds
    push es
    cli

    ; apply physical address = 16 * segment + offset to get the following
    ; ds:si = 0x0000:0x0500 = (0x00000500)
    mov ax, 0x0000
    mov ds, ax ; ds = 0x0000
    mov si, 0x0500

    ; es:di = 0xFFFF:0x0510 = (0x00100500)
    not ax ; ax = 0xFFFF
    mov es, ax ; es = 0xFFFF
    mov di, 0x0510

    ; save old memory adddresses
    mov al, [ds:si]
    mov [.buffer_below_mb], al
    mov al, [es:di]
    mov [.buffer_over_mb], al

    mov ah, 1
    mov byte [ds:si], 0
    mov byte [es:di], 1
    mov al, [ds:si]
    cmp al, [es:di]
    jne .exit
    dec ah
.exit:
    mov al, [.buffer_below_mb]
    mov [ds:si], al
    mov al, [.buffer_over_mb]
    mov [es:di], al
    shr ax, 8 ; shift right 8. move ah to al and clear ah
    pop es
    pop ds
    pop di
    pop si
    popf ; also renables interrupts since interrupts being active or not are dicated by flags
    ret

.buffer_below_mb: db 0
.buffer_over_mb: db 0

; enables A20 lines
; stops bootloader and prints out incompatible hardware error if int 0x15 is not supported
; most BIOSes should support int 0x15 (1990s onward)
enable_a20:
    mov ax, 0x2403 ; query A20 gate support
    int 0x15
    jc error
    test ah, ah
    jnc error

    mov ax, 0x2401 ; enable A20 gate
    int 0x15
    jc error
    test ah, ah
    jnc error
    jmp continue


; loads stage 2 into mememory
stage_two:
    mov si, packet
    mov ah, 0x42
    mov dl, [boot_drive]
    int 0x13
    ret

; attempt to reload stage 2 of the bootloader from memory 3 times
reload:
    mov cx, 3
.retry:
    mov ah, 0x00
    int 0x13 ; reset the disk services
    call stage_two

    ; check whether operation was successful
    jc .failed
    cmp ah, 0x00
    jne .failed
    jmp load_kernel_loader

.failed:
    loop .retry
error:
    mov si, hardware_error
    call print
hang:
    jmp hang


print:
    cld ; reset direction flag to go forward
    mov ah, 0x0e ; Teletype output
.loop:
    lodsb ; load next byte
    cmp al, 0
    je .done
    int 10h ; teletype output to print char in al register and advance the cursor
    jmp .loop

.done:
    ret


debug : db 'debug', 0
hardware_error : db 'incompatible-hardware-error', 0
boot_drive: db 0

align 4 ; insert padding so that the next thing is aligned on a 4 byte boundary. happens during assembly time
packet: istruc DiskAddressPacket
    at DiskAddressPacket.size, db 0x10
    at DiskAddressPacket.reserved, db 0
    at DiskAddressPacket.sectors, dw KERNEL_LOADER_SECTORS
    at DiskAddressPacket.buffer, dd 0x7e00
    at DiskAddressPacket.address, dq 1
iend


; times = repeating following instruction n times
; $ = current addess
; $$ = start address
; 510 - (current - start) = remaining space left to fill
times 510 - ($ - $$) db 0 ; pad until you reach a total of 510 bytes

dw 0xaa55 ; boot signature
