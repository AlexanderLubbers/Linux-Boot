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

unconditional jump is jmp

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


## How to calculate physical address
physical address = 16 * segment + offset