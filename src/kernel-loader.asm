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

cpuid_edx_ext_feat_lm equ 1 << 29

; lower bits are reserved for flags
pt_address_mask equ 0xffffffffff000
pt_present equ 1                 ; marks the entry as in use
pt_readable equ 2                ; marks the entry as r/w. 0 = readable only


cr4_page_enable equ 1 << 5

cpuid_get_features equ 7
cpuid_features_pml5 equ 1 << 16


cr4_la57 equ 1 << 12

; efer stands for extended feature enable register
; msr stands for model specific register
efer_msr equ 0xC0000080
efer_lm_enable equ 1 << 8

cr0_pg_enable equ 1 << 31



present equ 1 << 7
not_sys equ 1 << 4
exec equ 1 << 3
dc equ 1 << 2
rw equ 1 << 1
accessed equ 1 << 0

gran_4k equ 1 << 7
sz_32 equ 1 << 6
long_mode equ 1 << 5




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
        mov [boot_drive], dl
        mov dword [kernel_load_address], kernel_address
        cld
        ; detecting memory map
        call get_memory_map
        ; detect video modes
        mov word [video_mode_location], di
        call get_vesa

        mov word [frame_buffer_location], di
        call find_best_mode

        call frame_buffer
        
        ; store boot drive in memory
        mov ax, [frame_buffer_location]
        add ax, 0x100
        mov word [boot_drive_location], ax
        mov ax, 0x0
        mov es, ax
        mov di, [boot_drive_location]
        mov al, [boot_drive]
        mov [es:di], al

        ; store kernel load address in memory
        add di, 0x1
        mov [kernel_load_address_location], di
        mov eax, [kernel_load_address]
        mov [es:di], eax
        add di, 0x4
        ; align memory to 4 kib boundary
        add di, 0x0FFF
        and di, 0xF000

        mov [page_start], di

        ; call switch_video_mode

        ; switch to protected mode
        cli
        call disable_nmi
        lgdt [gdt_descriptor]
        mov eax, cr0
        or al, 1 ; set protected mode enable bit in control register 0
        mov cr0, eax

        jmp 0x08:pm_main

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

disable_nmi:
    mov al, 0x0f | 0x80
    out 0x70, al
    in al, 0x71
    ret

enable_nmi:
    mov al, 0x0f
    out 0x70, al
    in al, 0x71
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

[BITS 32]
pm_main:
    ; set up the stack
    mov ax, 0x10 ; data offset
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov ss, ax
    mov gs, ax

    mov ebp, 0x7c00
    mov esp, ebp

    xor eax, eax
    call check_cpuid
    cmp eax, 0x0
    je no_long_mode

    call test_long_mode

    call pml5_supported
    mov [pml5_is_supported], ecx

    call enable_pml5
    
    call initialize_page_addresses

    call prepare_paging

    call enable_paging

    call configure_cpu

    call switch_to_long
    
    jmp protected_hang


no_long_mode:
    mov eax, 0 ; temp

protected_hang:
    hlt
    jmp protected_hang

; Check whether the processor supports CPUID. do this by testing the ID bit in EFLAGS
; This bit is only modifiable if CPUID is supported.
; set eax equal to zero and call this function. if eax is non-zero, then CPUID is supported
check_cpuid:
    pushfd ; save EFLAGS
    pushfd ; store EFLAGS
    xor dword [esp], 0x00200000 ; invert ID bit
    popfd ; loaded the stored flags
    pushfd ; then store the flags again
    pop eax
    xor eax, [esp] ; eax becomes whichever bits were changed
    popfd ; restore the original flags
    and eax, 0x00200000
    ret ; eax becomes zero if the ID bit cannot be changed


test_long_mode:
    mov eax, 0x80000000 ; extended CPUID leaf
    cpuid ; eax contains the highest supported extended CPUID leaf
    cmp eax, 0x80000001 ; check whether CPU supports the minimum leaf
    jb no_long_mode
    mov eax, 0x80000001
    cpuid
    test edx, cpuid_edx_ext_feat_lm
    jz no_long_mode
    ret

prepare_paging:
    ; inform the CPU of the PML4's physical address
    mov ax, [page_start]
    mov edi, eax
    mov cr3, edi

    mov al, [pml5_is_supported]
    cmp al, 1
    je .five_level_paging

    xor eax, eax ; 0x00000000 to clear memory
    mov ecx, 4096 ; how many double words to write to memory pointed to by edi
    rep stosd ; 4 * 4096 bytes for 4 page tables
    mov edi, cr3
    jmp .done

; prepare memory for 5 level paging
.five_level_paging:
    xor eax, eax
    mov ecx, 5120
    rep stosd ; 4 * 5120 bytes for 5 page tables
.done:
    mov edi, cr3 ; move di back to beginning of page table
    ret

initialize_page_addresses:
    mov al, [pml5_is_supported]
    cmp al, 1
    je .five
    mov ax, [page_start]
    mov [pml4_location], ax
    add ax, 0x1000
    mov [pdpt_location], ax
    add ax, 0x1000
    mov [page_directory_location], ax
    add ax, 0x1000
    mov [page_table_location], ax
    jmp .done
.five:
    mov ax, [page_start]
    mov [pml5_location], ax
    add ax, 0x1000
    mov [pml4_location], ax
    add ax, 0x1000
    mov [pdpt_location], ax
    add ax, 0x1000
    mov [page_directory_location], ax
    add ax, 0x1000
    mov [page_table_location], ax
.done:
    ret

; links together PML4, PDPT, page directory, page table
link_4_paging:
    mov cx, [pdpt_location]
    or ecx, pt_present
    or ecx, pt_readable
    ; link first entries of each table, all other entries remain un-mapped
    mov dword [edi], ecx ; first PML4 entry points to PDPT
    mov di, [pdpt_location]
    mov cx, [page_directory_location]
    or ecx, pt_present
    or ecx, pt_readable
    mov dword [edi], ecx ; first PDPT entry points to page directory
    mov di, [page_directory_location]
    mov cx, [page_table_location]
    or ecx, pt_present
    or ecx, pt_readable
    mov dword [edi], ecx ; first page directory entry points to page table
    ret
; links together PML5, PML4, PDPT, page directory, page table
link_5_paging:
    mov cx, [pml4_location]
    or ecx, pt_present
    or ecx, pt_readable
    mov dword [edi], ecx ; first PML5 entry points to PML4 table
    mov di, [pml4_location]
    mov cx, [pdpt_location]
    or ecx, pt_present
    or ecx, pt_readable
    mov dword [edi], ecx
    mov di, [pdpt_location]
    mov cx, [page_directory_location]
    or ecx, pt_present
    or ecx, pt_readable
    mov dword [edi], ecx
    mov di, [page_directory_location]
    mov cx, [page_table_location]
    or ecx, pt_present
    or ecx, pt_readable
    mov dword [edi], ecx
    ret

enable_paging:
    mov al, [pml5_is_supported]
    cmp al, 1
    je .5_level_supported
    call link_4_paging
    jmp .fill_table

.5_level_supported:
    call link_5_paging

.fill_table:
    ; fill page table
    mov di, [page_table_location]
    mov ebx, pt_present | pt_readable
    mov ecx, 512

    ; identity mapping (ex: virtual address 0x1000 maps to physical address 0x1000)
.set_entry:
    mov dword [edi], ebx
    add ebx, 0x1000
    add edi, 8 ; 8 is size of page table entry in bytes
    loop .set_entry

    call enable_pae

; configure the CPU to enter long mode
configure_cpu:
    mov ecx, efer_msr
    rdmsr ; read msr in ecx register
    or eax, efer_lm_enable
    wrmsr ; write msr whose number is in ecx

    ; enable paging
    mov eax, cr0
    or eax, cr0_pg_enable
    mov cr0, eax

.done:
    ret
; enable phyiscal address extension
enable_pae:
    mov eax, cr4
    or eax, cr4_page_enable
    mov cr4, eax
    ret
; check whether level 5 paging is supported
; ecx will be set to 0 if level 5 paging is not supported
; ecx will be set to 1 if level 5 paging is supported
pml5_supported:
    mov eax, cpuid_get_features
    xor ecx, ecx
    cpuid
    test ecx, cpuid_features_pml5
    jnz .supported
.not_supported:
    xor ecx, ecx
    jmp .done
.supported:
    xor ecx, ecx
    mov ecx, 1
.done:
    ret

enable_pml5:
    mov al, [pml5_is_supported]
    cmp eax, 1
    jne .done ; pml5 is not supported
    mov eax, cr4
    or eax, cr4_la57
    mov cr4, eax
.done:
    ret

switch_to_long:
    lgdt [long_gdt.Pointer]
    jmp long_gdt.Code:long_main


[bits 64]

long_main:
    mov ax, long_gdt.Data
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; stack grows downward
    ; place top of stack at the top of the free memory region. it will grow towards smaller addresses
    mov rbp, 0x7FFFF
    mov rsp, rbp

    mov rax, 0x1122334455667788
    mov rbx, 0x1122334455667788

    cmp rax, rbx
    mov rsi, debug
    call print_string

long_hang:
    jmp long_hang


print_string:
    mov rbx, 0xB8000

.print_loop:
    mov al, [rsi]
    test al, al
    jz .done

    mov [rbx], al
    mov byte [rbx + 1], 0x07

    add rbx, 2
    inc rsi

    jmp .print_loop

.done:
    ret

section .data

video_mode_location: dw 1    
frame_buffer_location: dw 1
rsdp_location: dw 1
boot_drive_location: dw 1
kernel_load_address_location: dw 1
best_video_mode: dw 1
best_resolution: dd 1
best_color_depth: dd 1
boot_drive: db 1
kernel_load_address: dd 1
pml5_is_supported: db 0
pml5_location: dw 1
pml4_location: dw 1
pdpt_location: dw 1
page_directory_location: dw 1
page_table_location: dw 1
page_start: dw 1
align 4
VesaModeInfoBlockBuffer:	istruc VesaModeInfoBlock
	times VesaModeInfoBlock_size db 0
iend

section .rodata

memory_err: db "Error Reading Memory Map", 13, 10, 0
boot_msg: db "Please select an operating system", 13, 10, 0 ; 13 = carriage return (move cursor to beginning of current line)
end_msg: db "end", 13, 10, 0 ; 10 = line feed (move cursor down one line)
video_err: db "Error while detecting video modes", 13, 10, 0
video_detail_err: db "Unable to retrieve video mode info", 13, 10, 0 ; error reading video mode info, or video mode list is empty
video_switch_err: db "Failed to switch to graphical video mode", 13, 10, 0
no_modes_err: db "No Valid Video Modes", 13, 10, 0
debug: db "Entered Long Mode", 0

gdt:
    ; first gdt entry must be null
    dd 0x0
    dd 0x0

    ; code segment descriptor
    dw 0xffff ; limit
    dw 0x0000 ; base
    db 0x00   ; base
    db 10011010b ; access byte
    db 11001111b ; flags
    db 0x00 ; base

    ; data segment descriptor
    dw 0xffff ; limit
    dw 0x0000 ; base
    db 0x00   ; base
    db 10010010b ; access byte
    db 11001111b ; flags + limit
    db 0x00 ; base
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt - 1
    dd gdt


long_gdt:
    .Null: equ $ - long_gdt
        dq 0
    .Code: equ $ - long_gdt
        .Code.limit_lo: dw 0xffff
        .Code.base_lo: dw 0
        .Code.base_mid: db 0
        .Code.access: db present | not_sys | exec | rw
        .Code.flags: db gran_4k | long_mode | 0xF   ; Flags & Limit (high, bits 16-19)
        .Code.base_hi: db 0
    .Data: equ $ - long_gdt
        .Data.limit_lo: dw 0xffff
        .Data.base_lo: dw 0
        .Data.base_mid: db 0
        .Data.access: db present | not_sys | rw
        .Data.Flags: db gran_4k | sz_32 | 0xF       ; Flags & Limit (high, bits 16-19)
        .Data.base_hi: db 0
    .Pointer:
        dw $ - long_gdt - 1
        dq long_gdt