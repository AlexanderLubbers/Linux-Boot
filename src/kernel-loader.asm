[BITS 16]
[ORG 0x7E00]

entry_number equ 0x8000 ; number of entries will be stored at this address
entry_start equ 0x8004 ; entries start at this address
start:
    cld
    ; detecting memory map
    call get_memory_map

    mov eax, [entry_number]
    call print_hex_32

    mov si, end_msg
    call print

hang:
    jmp hang
; debug edx register has wrong value at the end of memory map reading process
; verify debug symbols in binary
get_memory_map:
    mov di, entry_start
    ; mov [es:di], dword entry_start
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
    add [entry_number], dword 1
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

print_hex_32:
    mov cx, 8 ; We need to process 8 nibbles (32 bits / 4)
    mov bx, hex_buffer ; Pointer to where the string will be stored

.loop:
    rol eax, 4 ; Rotate left by 4 bits to get the current nibble
    mov dl, al 
    and dl, 0x0F ; bit mask to get only the nibble
    
    ; Convert to ASCII character
    cmp dl, 0x09
    jbe .add_zero
    add dl, 7
.add_zero:
    add dl, '0' ; Add ASCII base for 0

    mov [bx], dl ; Save character to buffer
    inc bx ; Move buffer pointer forward
    dec cx ; Decrement loop counter
    jnz .loop

    ; Print the string using BIOS INT 0x10
    mov ah, 0x0E
    mov si, hex_buffer
.print_char:
    lodsb
    or al, al
    jz .done
    int 0x10
    jmp .print_char

.done:
    ret


memory_err : db 'Error Reading Memory Map', 13, 10, 0
boot_msg : db 'please select an operating system', 13, 10, 0 ; 13 = carriage return (move cursor to beginning of current line)
end_msg : db 'end', 13, 10, 0 ; 10 = line feed (move cursor down one line)
debug: db 'debug', 13, 10, 0
hex_buffer: db '00000000', 13, 10, 0