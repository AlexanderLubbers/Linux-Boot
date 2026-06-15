# Assembly notes

There are several parts of the CPU.

- Registers are one piece of the functionality of the CPU. Registers are small storage locations inside the CPU. EX `mov rax, 5`

- RAM exists outside the cpu and it is slower `mov rax, [addr]` (read value stored at addr and then put it in rax register)

- Instruction pointer: pointer to the next instruction. The CPU always trackes the next instruction

in x86-64, registers are 64 bit

 - General purpose registers (16)

```
RAX
RBX
RCX
RDX

RSI
RDI

RBP
RSP

R8
R9
R10
R11
R12
R13
R14
R15
```

There are very many specialized registers

```
RIP     Instruction pointer
RFLAGS  Status flags

CS
DS
ES
FS
GS
SS

CR0
CR2
CR3
CR4
CR8

XMM0-XMM31
YMM0-YMM31
ZMM0-ZMM31
```

for my use case for this project, I will mainly be using

```
RAX-R15
RIP
RFLAGS
CR0
CR3
CR4
```

 - Registers can also be accessed in smaller pieces, 

Ex:
```
RAX  64 bits
EAX  32 bits
AX   16 bits
AH    8 bits
AL    8 bits
```

```
mov rax, 0
mov al, 5
```
```
rax = 5
```

because al is a part of rax

- The Stack

lifo

push (put on top of stack)

pop (remove top of stack)

`pop es` means put value on the top of the stack into es. `push es` means push the value in es to the top of the stack  

stack pointer points to top of stack `rsp`

`rbp` = base pointer and points to the base of the current function's stack frame

This allowes for ease in accessing local variables and function parameters

EX:
`sub rsp, 32` means move stack pointer down 32 bytes

 - Memory Addressing

 [val] = get value stored at val

 - Operations
 
mov = copy data

add = add

sub = sub

inc = increment

dec = decrement

mul = unsigned multiply

or = bitwise or

and = bitwise and

 - Flags Register
```
ZF Zero
CF Carry
OF Overflow
SF Sign
```

flags belong to RFLAGS which is a register

`pushfq` pushes the RFLAGS register onot the stack so you can read flags

 - comparison

uses cmp

`cmp rax, rbx`

internally is `rax - rbx`. flags are updated and results are discarded

Ex
```
cmp rax, 50
je somewhere
```

cmp and then jump if equal

common jumps:
```
je
jne
jg
jl
jge
jle
```

with respect to these meanins

```
equal
not equal
greater
less
greater/equal
less/equal
```

unconditional jump is jmp. One use case of this command is to jmp to an absolute address and hand over control to another program

- loops

```
loop_start:

cmp rax, 10
jge done

inc rax

jmp loop_start

done:
```

 - functions

`call foo`

the cpu automatically pushes the return address and then jumps to foo.

return address is the sender's location

return = ret

`ret` automatically pops and then jumps to the return address

 - Stack Frames in Functions

```
push rbp
mov rbp, rsp

sub rsp, 32
```

save the functions base pointer `push rbp`.
then create a new stack frame by using `mov rbp, rsp`. this sets the base pointer for this function. also the rbp and rsp are at the same spot.
`sub rsp, 32` reserves 32 bytes of space for local variables. This moves the rsp down 32 bytes creating 32 bytes of unused, but reserved space.

result:
```
┌─────────────────────┐
│   return address    │  ← RBP + 8
│   saved old RBP     │  ← RBP
│                     │
│   32 bytes of       │
│   local var space   │
│                     │  ← RSP
└─────────────────────┘
```

this creates space for local variables.

To access them:

`[RBP - 8]` → first local variable
`[RBP - 16]` → second local variable
`[RBP - 24]` → third
`[RBP - 32]` → fourth

to get rid of the local variables do:

```
mov rsp, rbp
pop rbp
ret
```
this restores the previous stack

 - Calling Conventions

```
RDI arg1
RSI arg2
RDX arg3
RCX arg4
R8  arg5
R9  arg6
```

so now `add(6,7)` becomes:

```
mov RDI, 6
mov RSI, 7
call add
```

return value is RAX

 - Control Registers

CR0 enables protected mode and paging

CR3 contains page table root

CR4 is used for advanced CPU features

 - Paging

virtual address -> page tables -> physical address

 - How do brackets work?

brackets means memory dereferencing
```
mov rbx, rax ;  move the value at rax into rbx register
mov rbx, [rax] ; treat value of rax as a memory address, go to that memory address, retrieve the value and put it in rbx
```

-  Conditional Assembly

tell the assembler to include or exclude blocks depending on conditions
```
; comment out the undef to enable the LINUX "do things" code
%define WINDOWS
%undef WINDOWS
%ifdef WINDOWS
; perform operations for windows
%else
; do something else
%endif
```

 - Alignment

use `align` to align something to a given boundary like for example an 8 byte boundary

 - Include

`%include "file.asm"` to include other assembly files

Include guards

```
; at the top of gdt.asm
%ifndef GDT_ASM
%define GDT_ASM

    ; ... all your gdt code ...

%endif
```

 - Structures

EX

```
struc MemoryMapEntry
    .base:      resq 1    ; 8 bytes — base address
    .length:    resq 1    ; 8 bytes — length of region
    .type:      resd 1    ; 4 bytes — type (1=usable, 2=reserved, etc)
    .acpi:      resd 1    ; 4 bytes — ACPI extended attributes
endstruc
```

how to use a struct

EX:
```
; say RBX points to a MemoryMapEntry in memory
mov rax, [rbx + MemoryMapEntry.base]    ; read the base address field
mov rcx, [rbx + MemoryMapEntry.length]  ; read the length field
mov edx, [rbx + MemoryMapEntry.type]    ; read the type field
```

It is done this way because after the struc is parsed, items like MemoryMapEntry.base get turned into an offset from the beginning

## How to calculate physical address
physical address = 16 * segment + offset

## Table of commonly used instructions

```
ADC - add a value, plus 
ADD - add two registers together
DEC - decrement by 1
DIV - unsigned divide
IDIV - signed divide
IMUL - signed multiply
INC - increment by 1
MUL - unsigned multiply
NEG - two's complement (multiply by -1)
SBB - subtract with borrow (carry flag)
SUB - subtract
LEA - load effective address (formed by some expression / addressing mode) into register

AND - logical AND two registers together
NOT - one's complement (invert all the bits in the operand)
OR - logical OR
XOR - logical exclusive or
TEST - logical compare

CALL - call a subroutine/function/procedure
SYSCALL - call an OS function (Linux, Mac)
ENTER - make stack for procedure parameters
LEAVE - high level procedure exit
RET - return from subroutine
CMP - compare two operands
JA - jump if result of unsigned compare is above
JAE - jump if result of unsigned compare is above or equal
JB - jump if result of unsigned compare is below
JBE - jump if result of unsigned compare is below or equal
JC - jump if carry flag is set
JE - jump if equal
JG - jump if greater than 
JGE - jump if greater than or equal
JNC - jump if carry not set
JMP - go to / jmp (simply loads the RPC register with the address)

BT - bit test (test a bit)
BTC - bit test and complement
BTR - bit test and reset
BTS - bit test and set
RCL - rotate 9 bits (carry flag, 8 bits in operand) left count bits
RCR - rotate 9 bits (carry flag, 8 bits in operand) right count bits
ROL - rotate 8 bits in operand left count bits
ROR - rotate 8 bits in operand right count bits
SAL - arithmetic shift operand left count bits
SAR - arithmetic shift operand right count bits (maintains sign bit)
SHL - logical shift operand left count bits (same as SAL)
SHR - logical shift operand right count bits (does not maintain sign bit)

MOV - move register to register, move register to memory, move memory to register
XCHG - exchange register/memory with register
CBW - convert byte to word
CDQ - convert word to double word/convert double word to quad word

CLC - clear carry flag/bit in flags register
CLD - clear direction bit in flags register
STC - set carry flag
STD - set direction flag

POP - pop a register off the stack
POPF - pop stack into flags register
PUSH - push a register on the stack
PUSHF - push flags register on the stack
```

borrowed from here:
https://github.com/mschwartz/assembly-tutorial#permissions-sections-and-privileged-instructions

## Assembly Directives
 - code generation
EX:
`[BITS 16]`

 - Origin

`[ORG 0x7c00]`

Sets the memory address where the assembler will place the code and data. It also tells the assembler how to calculate the memory labels and addresses

 - Data Definition

```
db 0x55           ; define byte  (1 byte)
dw 0x1234         ; define word  (2 bytes)
dd 0xDEADBEEF     ; define dword (4 bytes)
dq 0x123456789    ; define qword (8 bytes)

db "Hello", 0     ; string followed by null terminator
```

 - Section Directives

These are also assembly directives

EX:
```
section .text     ; code goes here
section .data     ; initialized data goes here
section .bss      ; uninitialized data goes here
```

## Assembly time versus Run time

Directives are for the assembler and commands like jmp and mov are CPU instructions so they occur during run time.

Examples of directives include align, [BITS xx], [ORG ...], equ, struc/endstruc, istruc/iend, times.

A tip that is in my opinion helpful in differentiating between directives and explicit CPU actions is to look for a command that directly modifies and interracts with CPU registers or CPU interactions