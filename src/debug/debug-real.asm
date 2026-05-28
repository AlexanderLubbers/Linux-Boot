[BITS 16]

print:
    cld ; reset direction flag to go forward
    mov ah, 0x0E ; Teletype output
    mov si, debug
.loop:
    lodsb ; load next byte
    cmp al, 0
    je .done
    int 10h ; teletype output to print char in al register and advance the cursor
    jmp .loop

.done:
    ret

debug : db 'debug', 0