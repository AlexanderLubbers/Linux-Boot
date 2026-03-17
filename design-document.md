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

### Target Firmware Interface

BIOS is generally not the best. It cannot support all devices and does not even have support for sound, network cards, GPUS, and input devices (like mice). It only has a fraction of the features UEFI does. Because of this, the firmware I am going to target is UEFI.

### Environment
Since most linux operating systems use Long Mode (>99%), excluding embedded systems that require extreme resource efficiency, it makes the most sense to have this bootloader support Long Mode.

### Operational Logic

## Appendix

### What is this section?
This section contains everything I found interesting or worth knowing as I have been working on this project

### Real Mode vs Protected Mode vs Long Mode
Real mode is 16 bit and whenever the power button is pressed on a computer, this is the mode the CPU starts in. Real Mode is limited to 1mb of RAM and memory is accessed using segmentation. In order to access something at a specific place, shift the segment register by 4 bits and then add the corresponding offset. There is zero security when it comes to real mode. Any program can write to any memory address

Protected Mode is where a lot of the modern computing features become available. Protected Mode allows for up to 4gb of RAM. It also introduced the Global Descriptor Table instead of raw memory segments. This means that the CPU can use selectors to point to entries which defines where memory starts and ends as well as what is allowed to access these memory entries. Protected Mode also introduces privilege levels. Ring 0 is the most privileged (OS kernel) and Ring 3 is the least privileged (user applications). Paging was also introduced as well.

In theory, with Long Mode, 16 Exabytes of memory of address space is possible, but modern hardware significantly limits this. General purpose registers have been expanded from 32 bits to 64 bits. In order to user Long mode, Paging must be enabled (you need a page table). It can run 32 bit Protected Mode code but Real Mode compatibility is iffy.

### Paging
The idea behind paging is to break programs into smaller fixed size blocks called pages. This means that the process does not have to be allocated in contiguous memory space helping solve the problem of fragmentation as well as the whole process not having to be in main memory. This means that some pages can be put away while other pages are using the main memory and when a certain page is needed, it can simply be loaded. This allows for more processes and processes larger than main memory to run.