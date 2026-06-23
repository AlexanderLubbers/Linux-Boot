[BITS 16]

%ifdef DEBUG
%else
    [ORG 0x7e00]
%endif


; number of entries will be stored at this address
entry_number_offset equ 0x0500
entry_number_segment equ 0x0000
 ; entries start at this address
entry_start_offset equ 0x0504
entry_start_segment equ 0x0000

kernel_address equ 0x100000

struc VesaInfoBlock				;	VesaInfoBlock_size = 512 bytes
	.Signature		resb 4		;	must be 'VESA'
	.Version		resw 1
	.OEMNamePtr		resd 1
	.Capabilities		resd 1

	.VideoModesOffset	resw 1
	.VideoModesSegment	resw 1

	.CountOf64KBlocks	resw 1
	.OEMSoftwareRevision	resw 1
	.OEMVendorNamePtr	resd 1
	.OEMProductNamePtr	resd 1
	.OEMProductRevisionPtr	resd 1
	.Reserved		resb 222
	.OEMData		resb 256
endstruc

struc VesaModeInfoBlock
	.ModeAttributes		resw 1
	.FirstWindowAttributes	resb 1
	.SecondWindowAttributes	resb 1
	.WindowGranularity	resw 1
	.WindowSize		resw 1
	.FirstWindowSegment	resw 1
	.SecondWindowSegment	resw 1
	.WindowFunctionPtr	resd 1
	.BytesPerScanLine	resw 1

	.Width			resw 1
	.Height			resw 1
	.CharWidth		resb 1
	.CharHeight		resb 1
	.PlanesCount		resb 1
	.BitsPerPixel		resb 1
	.BanksCount		resb 1
	.MemoryModel		resb 1
	.BankSize		resb 1
	.ImagePagesCount	resb 1
	.Reserved1		resb 1

	.RedMaskSize		resb 1
	.RedFieldPosition	resb 1
	.GreenMaskSize		resb 1
	.GreenFieldPosition	resb 1
	.BlueMaskSize		resb 1
	.BlueFieldPosition	resb 1
	.ReservedMaskSize	resb 1
	.ReservedMaskPosition	resb 1
	.DirectColorModeInfo	resb 1

	.LFBAddress		resd 1
	.OffscreenMemoryOffset	resd 1
	.OffscreenMemorySize	resw 1
	.Reserved2		resb 206
endstruc

section .text

global _start

_start:
    cld
    ; detecting memory map
    call get_memory_map
    ; detect video modes
    mov word [video_mode_location], di
    call get_vesa

    mov word [frame_buffer_location], di
    call find_best_mode

    call frame_buffer

    ; mov si, end_msg
    ; call print

    ; push es
    ; push di
    ; call switch_video_mode
    ; pop di
    ; pop es

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
    je .complete ; ebx means the last entry has been reached
    mov edx, 0x0534d4150
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
    jc .done ; carry flag means the end of the list has already been reached 
    cmp ebx, 0
    je .complete
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
.complete:
    cmp cl, 20
    jb .failed
    cmp eax, 0x0534d4150
    jne .failed
    cmp cl, 20
    je .write_last_attribute
    call .increment
    jmp .done
.write_last_attribute:
    mov [di + 20], dword 1
    call .increment
.done:
    ret

; get array of all supported video modes
get_vesa:
    mov ax, 0x00
    mov es, ax
    mov dword [di], "VBE2"
    clc ; some BIOS functions require that the carry flag is not set before calling it
    mov ax, 0x4f00
    int 0x10
    jc .failed
    cmp ax, 0x004f
    jne .failed
    add di, 0x200
    ret
.failed:
    mov si, video_err
    call print
    jmp hang

; finds the best video mode
; the best video mode is defined as the video mode with the highest
; resolution and the highest color depth (prefer 32 bits per pixel).
; must also support linear frame buffer and must be a graphics mode (not text mode)
find_best_mode:
    mov bx, [video_mode_location]
    mov ax, [bx + VesaInfoBlock.VideoModesSegment]
    mov es, ax

    mov di, VesaModeInfoBlockBuffer

    mov bx, [bx + VesaInfoBlock.VideoModesOffset]
    mov cx, [es:bx]
    cmp cx, 0xffff
    je .no_modes

    ; zero out variables
    mov word [best_video_mode], 0x00
    mov dword [best_resolution], 0x00
    mov dword [best_color_depth], 0x00
.loop:
    cmp cx, 0xffff
    je .done

    ; get video mode info
    mov ax, 0x4f01
    int 0x10
    cmp ax, 0x004f
    jne .failed
    
    mov dx, word [VesaModeInfoBlockBuffer + VesaModeInfoBlock.ModeAttributes]
    test dx, 0b00010000
    jz .next ; video mode is not a graphics mode
    test dx, 0b10000000
    jz .next ; video mode does not have a linear frame buffer
    ; calculate resolution
    xor edx, edx
    xor eax, eax
    movzx edx, word [VesaModeInfoBlockBuffer + VesaModeInfoBlock.Width]
    movzx eax, word [VesaModeInfoBlockBuffer + VesaModeInfoBlock.Height]
    mul edx

    ; determine whether this video mode is better than the current best video mode
    cmp eax, dword [best_resolution]
    ja .set_best
    je .tie_break
.next:
    ; increment
    add bx, 2
    mov cx, [bx]

    jmp .loop
.failed:
    mov si, video_detail_err
    call print
    jmp hang
.no_modes:
    mov si, no_modes_err
    call print
    jmp hang
.set_best:
    mov word [best_video_mode], cx
    mov dword [best_resolution], eax
    mov edx, [VesaModeInfoBlockBuffer + VesaModeInfoBlock.BitsPerPixel]
    mov dword [best_color_depth], edx
    jmp .next
.tie_break:
    mov edx, dword [VesaModeInfoBlockBuffer + VesaModeInfoBlock.BitsPerPixel]
    cmp edx, dword [best_color_depth]
    ja .set_best
    jmp .next
.done:
    ret

; places info of chosen video mode into memory
frame_buffer:
    mov ax, 0
    mov es, ax
    mov di, [frame_buffer_location]
    mov cx, [best_video_mode]
    mov ax, 0x4f01
    int 0x10
    ret
.failed:
    mov si, video_err
    call print
    jmp hang


; sets the video mode to the chosen best video mode
switch_video_mode:
    mov ax, 0
    mov es, ax
    mov di, [frame_buffer_location]
    mov ax, 0x4f02
    mov bx, [best_video_mode]
    or bx, 0x4000
    int 0x10
    jc .failed
    ret
.failed:
    mov si, video_switch_err
    call print
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

section .data

video_mode_location: dw 1    
frame_buffer_location: dw 1
best_video_mode: dw 1
best_resolution: dd 1
best_color_depth: dd 1

align 4
VesaModeInfoBlockBuffer:	istruc VesaModeInfoBlock
	times VesaModeInfoBlock_size db 0
iend

section .rodata

memory_err : db "Error Reading Memory Map", 13, 10, 0
boot_msg : db "Please select an operating system", 13, 10, 0 ; 13 = carriage return (move cursor to beginning of current line)
end_msg : db "end", 13, 10, 0 ; 10 = line feed (move cursor down one line)
video_err : db "Error while detecting video modes", 13, 10, 0
video_detail_err : db "Unable to retrieve video mode info", 13, 10, 0 ; error reading video mode info, or video mode list is empty
video_switch_err : db "Failed to switch to graphical video mode", 13, 10, 0
no_modes_err: db "No Valid Video Modes", 13, 10, 0