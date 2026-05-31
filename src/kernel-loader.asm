[BITS 16]
[ORG 0x7E00]

start:


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


bootmsg : db 'successfully-booted', 0