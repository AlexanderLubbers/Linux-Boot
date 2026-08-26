; Loaded by stage 1 (boot sector)
; Loads and hands control to loader.elf to prepare computer environment and load kernel
[BITS 16]

%ifdef DEBUG
%else
    [org 0x0500]
%endif

; assumptions made
; only one loadable section
; no .bss
; loader.elf is less than 64 kib

; program headers and elf header is in the first sector of the elf file
SECTORS equ 1
SECTOR_SIZE equ 512
ELF_MAGIC_NUM equ 0x464c457f
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

    mov bx, word [elf_header + 32]
    mov [phoff], bx
    add bx, elf_header

    ; ensure program header is pt_load
    mov ax, [bx]
    cmp ax, 1
    jne invalid_elf

    ; determine the number of sectors to load
    xor eax, eax
    mov ax, word [bx + 0x08] ; offset from beginning of elf file
    mov [offset], ax
    mov ax, word [bx + 0x18] ; loadable section phyiscal address
    mov [paddr], ax
    mov ax, word [bx + 0x20] ; file size
    mov [file_size], ax
    ; calculate number of sectors to load
    mov ax, [offset]
    add ax, [file_size]
    add ax, SECTOR_SIZE - 1
    shr ax, 9

    mov [ph_sectors], ax
    mov dx, load_packet ; debug statement
    mov cx, sector ; debug statement
    mov [load_packet + DiskAddrPacket.sectors], eax
    xor eax, eax
    mov ax, TEMPORARY_BUFFER_LOCATION
    mov [load_packet + DiskAddrPacket.buffer], ax

load_stage_2:
    call load_exe
    jc reload_load_exe
    cmp ah, 0x00
    jne reload_load_exe

transfer_exe:
    mov ax, 0
    mov es, ax
    mov di, TEMPORARY_BUFFER_LOCATION
    add di, [offset] ; get to the section that must be loaded
    mov cx, [file_size]
    mov si, [paddr] ; dx points physical address of loadable segment
.transfer_data:
    mov al, byte [di]
    mov byte [si], al
    inc si
    inc di
    loop .transfer_data


go_to_entry:
    mov dl, [boot_drive]
    mov ax, [entry_point]
    push ax
    ret
    jmp enter_hang

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
    mov dl, [boot_drive]
    int 0x13
    ret

; retry loading the executable if failure
reload_load_exe:
    mov cx, 3
.retry:
    mov ah, 0x00
    int 0x13
    call load_exe

    jc .failed
    cmp ah, 0x00
    jne .failed
    jmp transfer_exe
.failed:
    loop .retry
    jmp enter_hang

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
paddr: dw 0
ph_sectors: dw 0 ; program header sectors i.e. sections containing data from the pt_load section in the program header
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
    at DiskAddrPacket.sectors, dw 0
    at DiskAddrPacket.buffer, dd TEMPORARY_BUFFER_LOCATION
    at DiskAddrPacket.address, dq sector + 1
iend

elf_header:
    times 512 db 0


times (512 - (($ - $$) % 512)) % 512 db 0 ; ensure that elf_loader.asm ends on a 512 byte boundary
; number of sectors elf_loader occupies
elf_loader_file_size equ $ - elf_loader
sector equ (elf_loader_file_size + SECTOR_SIZE - 1) / SECTOR_SIZE