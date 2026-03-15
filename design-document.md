# Design Document


## What Is This Document?

This document contains all the research I had to do to make this project happen. As well as serving as a bookkeeping document for all the aspects of booting up a kernel that I learned in order to make this bootloader, this document will also contain the outline to the approach that I will take to implement my custom bootloader.

## What Is A Bootloader?
A Bootloader is a special program that runs immediately when the computer is powered on and then it initializes the hardware and launches the operating system.

## What Does A Bootloader Do?
It has to bring the kernel into memory as well as provide it with everything it with the correct environment and the resources it needs to function correclty. Finally, the bootloader should transfer control over to the kernel.

## Linux-Boot Design Overview