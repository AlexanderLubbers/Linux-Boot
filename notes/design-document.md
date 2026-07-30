# Design Document


## What Is This Document?

This document contains all the research I had to do to make this project happen. As well as serving as a bookkeeping document for all the aspects of booting up a kernel that I learned in order to make this bootloader, this document will also contain the outline to the approach that I will take to implement my custom bootloader.

## What Is A Bootloader?
A Bootloader is a special program that runs immediately when the computer is powered on and then it initializes the hardware and launches the operating system.

## What Does A Bootloader Do?
It has to bring the kernel into memory as well as provide it with everything it with the correct environment and the resources it needs to function correclty. Finally, the bootloader should transfer control over to the kernel.

## Linux-Boot Design Overview

### Target Architecture
My bootloader will target x86_64 architecture because it has broad compatibility with modern operating systems including Linux which uses x86_64 extensively.

### Environment
Since most linux operating systems use Long Mode (>99%), excluding embedded systems that require extreme resource efficiency, it makes the most sense to have this bootloader support Long Mode.

### Bootloader Architecture
Single stage bootloaders require that everything fits into the Master Boot Record which means that there is going to be about 446 bytes of usable data for the code. For the scope and goals of this project, 446 bytes is simply not enough space to do everything the bootloader must do. Because of this, a two stage bootloader design is going to be implemented.

### Operational Logic

stage 1:
set up segments and stack, and then load stage two of the bootloader


stage: 2

perform memory map detection, detect available video modes, enable A20, load a global descriptor table,
enter protected mode

TODO: Figure out how to set up Long mode


### Features

## Appendix

### What is this section?
This section contains everything I found interesting or worth knowing as I have been working on this project

### Real Mode vs Protected Mode vs Long Mode
Real mode is 16 bit and whenever the power button is pressed on a computer, this is the mode the CPU starts in. Real Mode is limited to 1mb of RAM and memory is accessed using segmentation. In order to access something at a specific place, shift the segment register by 4 bits and then add the corresponding offset. There is zero security when it comes to real mode. Any program can write to any memory address

Protected Mode is where a lot of the modern computing features become available. Protected Mode allows for up to 4gb of RAM. It also introduced the Global Descriptor Table instead of raw memory segments. This means that the CPU can use selectors to point to entries which defines where memory starts and ends as well as what is allowed to access these memory entries. Protected Mode also introduces privilege levels. Ring 0 is the most privileged (OS kernel) and Ring 3 is the least privileged (user applications). Paging was also introduced as well.

In theory, with Long Mode, 16 Exabytes of memory of address space is possible, but modern hardware significantly limits this. General purpose registers have been expanded from 32 bits to 64 bits. In order to user Long mode, Paging must be enabled (you need a page table). It can run 32 bit Protected Mode code but Real Mode compatibility is iffy.

### Paging
The idea behind paging is to break programs into smaller fixed size blocks called pages. This means that the process does not have to be allocated in contiguous memory space helping solve the problem of fragmentation as well as the whole process not having to be in main memory. This means that some pages can be put away while other pages are using the main memory and when a certain page is needed, it can simply be loaded. This allows for more processes and processes larger than main memory to run.

### POST
Power-On-Self-Test. The instant a computer is turned on, a diagnostic process called POST is run on the motherboard's firmware. If the diagnostics indicate the the computer's firmware is working as intended, then the comptuer will then search for a bootable device. BIOS firmware will initialize will initialize CPU, memory, and other hardware components. BIOS firmware code is copied from ROM to RAM for faster execution.

### Master Boot Record
BIOS checks bootable devices for boot signatures. A bootable device is any sort of hardware that contains the instructions needed to boot a computer. The boot signature is in the boot sector which is sector number 0 and contains the byte sequence 0x55(byte offset 510) and 0xAA(byte offset 511). The bootsector should be loaded into memory at 0x0000:0x7c00.

### IDT
Interupt descriptor table. protected mode version of the real mode interrupt vector table. its a table of descriptors that says if this interrupt fires,
call this handler function

### Segments
logical, and variable sized chunk of memory that is used to organize data. rather than having a large contiguous memory space, The OS breaks a program's memory into meaningful chunks. each segment holds a logical part of the program

### ROM vs RAM
RAM is random access memory. It is fast, temporary, volatile, and is used by the CPU to hold relavent data. ROM is read only memory, and it is slow and permanent. It retains its memory without power, and is used to store important firmware like startup instructions.

### A20 Gate
In short, it allows for memory access that is above 1mb. Some processors are equiped with the A20 gate to ensure backward comapitibiltiy with software that relied on address wrap arounds. The A20 gate must be enabled to ensure that address wrap arounds do not occur and is needed for accessing higher memory and protected mode.

### Debugging Tips
* debug assumptions too not just code
* prove everything when debugging

### Memory map
```
0x00000 - 0x003FF   Interrupt Vector Table (IVT) — 1KB, 256 vectors × 4 bytes
0x00400 - 0x004FF   BIOS Data Area (BDA) — don't touch this
0x00500 - 0x07BFF   Free conventional memory — safe to use
0x07C00 - 0x07DFF   Your bootloader (loaded here by BIOS)
0x07E00 - 0x7FFFF   Free conventional memory — safe to use
0x80000 - 0x9FFFF   Extended BIOS Data Area (EBDA) — avoid, size varies
0xA0000 - 0xBFFFF   Video memory (VGA buffers etc.)
0xC0000 - 0xFFFFF   ROM/BIOS — completely off limits
```

the first free conventional memory block has 30,000+ free bytes, so all of the boot info will be stored there

### 32bit and 64bit registers in real mode
32 bit registers require operand size overide prefixes because 16bit operation size is the default in 16bit real mode

### Frame buffer
Essentially, it is a portion of RAM where pixel data is stored. each part of this portion of RAM corresponds to a pixel. This is used to display things to the screen. A linear frame buffer means the entire frame buffer can be accessed as a contiguous array of bytes

### NMI
stands for non maskable interrupt and unlike normal hardware interrupts, these do not get disabled using `cli`

NMI is used to severe events like memory parity errors and hardware failures. NMI can interrupt code.

### Global Descriptor Table
GDT entries are 8 bytes long and entry zero must always be null. access entries in the table by using Segment Selectors and loading them into segmentation registers via assembly or interrupts

Segment Selectors are 16 bit binary data structures. it is an index into the GDT.

Each Entry in the Global Descriptor Table describes a section of memory (i.e. where it begins, how big it is, whether it is executable or writable, and its privilege level)

```
bits 0-15: limit
bits 16-31: base
bits 32-39: base
bits 40-47: access byte
bits 48-51: limit
bits 52-55: flags
bits 56-63: base
```

Limit is a 20 bit value and it informs the CPU how far into this segment a program is allowed to access. for example, if a segment started at 0x100000 then you could access through 0x100FFF until a general protection fault is thrown.

0xfffff is about 1 mb. the granularity bit being zero means limit is measured in bytes, but if G=0 then the limit is measured in 4kb pages instead

Base address is a 32bit value indicating where the segment begins

Access byte
```
bit 0: A
bit 1: RW
bit 2: DC
bit 3: E
bit 4: S
bit 5: DPL
bit 6: DPL
bit 7: P
```

P = present bit. must be set to 1 for it to be a valid segment

RW = readable / writeable bit. for data segments, 1 for writeable and 0 for not. for code, 1 for read access allowed, 0 for not.

DC = direction bit / conforming bit. for data, 0 means segment grows up, 1 means it grows down. for code, 1 means code can be executed from an equal or lower privilege level.

E = Executable bit. 0 means descriptor defines a data segment. 1 means code.

S = Descriptor type bit. 0 means system segment, 1 means data or code segment

DPL = privilege level field. 0 is highest privilege, 3 is user

A = accessed bit CPU will set it when the segment is accessed unless set to 1 in advance. usually set to 1.


Flags:
```
bit 0: reserved
bit 1: L
bit 2: DB
bit 3: G
```

L: long mode code flag
DB: size flag. 0 means 16 bit protected mode segment, 1 means 32 bit protected mode segment. GDT can have both types at the same time
G: granularity flag

### Page Table
There is a virtual address space (logical memory address used by a program) and a physical address space (RAM). Page tables are the translation between the two.

```
Virtual Address
        │
        ▼
PML4
        │
        ▼
PDPT
        │
        ▼
Page Directory
        │
        ▼
Page Table
        │
        ▼
Physical Page
```

There are multiple tables for resource efficiency. each table maps to another table until you reach the physical address

PML4 table answeres the question of which chunk of virtual memory is the virtual address inside?

each section of the PML4 points to a section of PDPT and PDPT further divides the virtual address space

PDPT points to a page directory which further narrows down the virtual address space before we finally reach a page table

Virtual Address space is pretty much always way bigger than physical address space

Not all virtual pages have to be backed by physical RAM at the same time. Pages can be brought into RAM only when they are needed.

A page is simply a fixed size block of memory. the standard page size is typically 4KiB

In the context of Intel, every page table occupies one page, therefore, every page table is 4KiB

virtual addresses typically start at 0x1000 which is one page after 0. 0 is avoided because mapping 0x0 to vaid memory addresses can introduce bugs that are hard to fix
