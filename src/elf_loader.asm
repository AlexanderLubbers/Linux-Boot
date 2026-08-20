; Loaded by stage 1 (boot sector)
; Loads and hands control to loader.elf to prepare computer environment and load kernel
[BITS 16]
[org 0x0500]

; program headers and elf header is in the first sector of the elf file
SECTORS equ 1
SECTOR_SIZE equ 512
ELF_MAGIC_NUM equ 0x7f454c46
TEMPORARY_BUFFER_LOCATION equ 0x3000

struc DiskAddrPacket
    .size resb 1 ; size of packet
    .reserved resb 1 ; should always be zero
    .sectors resw 1 ; number of sectors to transfer. The max is usually 127
    .buffer resd 1 ; transfer buffer (where to load in RAM)
    .address resq 1 ; LBA address of sector to read from disk
endstruc

elf_loader:
    mov [boot_drive], dl
    mov si, debug_
    call print

    call load_elf_header
    jc reload
    cmp ah, 0x00
    jne reload

verify_elf:
    ; verify elf characteristics
    ; verify magic number
    mov eax, dword [elf_header]
    cmp eax, ELF_MAGIC_NUM
    jne invalid_elf
    ; verify class
    mov al, byte [elf_header + 4]
    cmp al, 2
    jne invalid_elf
    ; verify endianness
    mov al, byte [elf_header + 5]
    cmp al, 1
    jne invalid_elf
    ; verify version
    mov al, byte [elf_header + 6]
    cmp al, 1
    jne invalid_elf

    ; record entry point
    mov ax, word [elf_header + 24]
    mov [entry_point], ax

    mov bx, dword [elf_header + 32]
    mov [phoff], bx
    add bx, elf_header

    ; ensure program header is pt_load
    mov ax, [bx]
    cmp ax, 1
    jne invalid_elf

    ; determine the number of sectors to load
    mov eax, dword [bx + 16]
    mov [offset], eax
    mov eax, dword [bx + 40] ; file size
    mov [file_size], eax
    add eax, SECTOR_SIZE - 1
    div eax, SECTOR_SIZE

    mov [ph_sectors], eax

load_stage_2:
    call load_exe
    jc reload_load_exe
    cmp ah, 0x00
    jne reload_load_exe

transfer_exe:
    mov ax, 0
    mov es, ax
    mov di, TEMPORARY_BUFFER_LOCATION
    add di, 64 ; move past elf header
    add di, 56 ; move past program header
    add di, [offset] ; get to the section that must be loaded
    mov cx, [file_size]
    mov dx, [entry_point] ; dx points to entry point of stage 2 of the bootloader
.transfer_data:
    mov al, byte [di]
    mov byte [dx], al
    inc dx
    loop .transfer_data

go_to_entry:
    mov ax, [entry_point]
    push ax
    ret

load_elf_header:
    mov si, pckt
    mov ah, 0x42
    mov dl, [boot_drive]
    int 0x13
    ret

reload:
    mov cx, 3
.retry:
    mov ah, 0x00
    int 0x13 ; reset the disk services
    call load_elf_header

    ; check whether operation was successful
    jc .failed
    cmp ah, 0x00
    jne .failed
    jmp verify_elf

.failed:
    loop .retry

load_exe:
    mov si, load_packet
    mov ah, 0x42
    int 0x13
    ret

; retry loading the executable if failure
reload_load_exe:
    mov cx, 3
.retry:
    mov ah, 0x00
    int 0x13
    call reload_load_exe

    jc .failed
    cmp ah, 0x00
    jne .failed
    jmp transfer_exe
.failed:
    loop .retry

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

invalid_elf:
    mov si, invalid_elf_msg
    call print
    jmp enter_hang

enter_hang:
    jmp enter_hang

debug_: db 'entered elf_loader', 0
invalid_elf_msg: db 'invalid elf executable', 0
boot_drive: db 0
entry_point: dw 0
phoff: dw 0
offset: dw 0
file_size: dw 0
ph_sectors: db 0 ; program header sectors i.e. sections containing data from the pt_load section in the program header
align 4 ; insert padding so that the next thing is aligned on a 4 byte boundary. happens during assembly time
pckt: istruc DiskAddrPacket
    at DiskAddrPacket.size, db 0x10
    at DiskAddrPacket.reserved, db 0
    at DiskAddrPacket.sectors, dw SECTORS
    at DiskAddrPacket.buffer, dd elf_header
    at DiskAddrPacket.address, dq sector + 1
iend

align 4 ; insert padding so that the next thing is aligned on a 4 byte boundary. happens during assembly time
load_packet: istruc DiskAddrPacket
    at DiskAddrPacket.size, db 0x10
    at DiskAddrPacket.reserved, db 0
    at DiskAddrPacket.sectors, dw [ph_sectors]
    at DiskAddrPacket.buffer, dd TEMPORARY_BUFFER_LOCATION
    at DiskAddrPacket.address, dq sector + 1
iend

elf_header:
    times 512 db 0


times (512 - ($ % 512)) % 512 db 0 ; ensure that elf_loader.asm ends on a 512 byte boundary
; number of sectors elf_loader occupies
file_size equ $ - elf_loader
sector equ (file_size + SECTOR_SIZE - 1) / SECTOR_SIZE