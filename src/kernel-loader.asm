[BITS 16]
[ORG 0x7e00]

; number of entries will be stored at this address
entry_number_offset equ 0x0500
entry_number_segment equ 0x0000
 ; entries start at this address
entry_start_offset equ 0x0504
entry_start_segment equ 0x0000

start:
    cld
    ; detecting memory map
    call get_memory_map

    mov si, end_msg
    call print

hang:
    jmp hang

get_memory_map:
    mov ax, entry_start_segment
    mov es, ax
    mov di, entry_start_offset
    xor ebx, ebx ; clear ebx
    mov edx, 0x0534d4150 ; magic number
    mov eax, 0xe820
    mov ecx, 0x18
    int 0x15
    jc .failed ; carry flag set after first read, memory map is invalid
    cmp eax, 0x0534d4150
    jne .failed ; eax register corrupted, memory map is invalid
    cmp ebx, 0
    je .failed ; we reached the end after one read, memory map is invalid
    mov edx, 0x0534d4150 ; possibly un-needed
    cmp cl, 20
    jb .failed
    cmp cl, 20
    je .attribute ; uint32_t attribute bitfield not included in BIOS
.first_continue:
    call .increment
    jmp .read
.failed:
    mov si, memory_err
    call print
    jmp hang
.attribute: ; force a valid APCI entry
    mov [di + 20], dword 1
    jmp .first_continue
.increment:
    add di, 24
    add [es:entry_number_offset], dword 1
    ret
.read:
    mov eax, 0xe820
    mov edx, 0x0534d4150     
    mov ecx, 0x18
    int 0x15
    jc .done ; carry flag will be set after accessing last valid entry
    cmp ebx, 0
    je .done
    cmp cl, 20
    jb .failed
    cmp cl, 20
    je .read_attribute
.continue:
    call .increment
    cmp eax, 0x0534d4150
    jne .failed
    jmp .read
.read_attribute:
    mov [di + 20], dword 1
    jmp .continue
.done:
    ret

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


memory_err : db 'Error Reading Memory Map', 13, 10, 0
boot_msg : db 'please select an operating system', 13, 10, 0 ; 13 = carriage return (move cursor to beginning of current line)
end_msg : db 'end', 13, 10, 0 ; 10 = line feed (move cursor down one line)