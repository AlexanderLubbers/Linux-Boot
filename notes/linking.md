# Linker script
the main purpose of a linker script is to assign memory addresses

## Entry
set the entry point address

not mandatory but required when using gdb debugger for the ELF

Syntax:
```
Entry(synbol_name) or Entry(Start)
```
## Memory
Used to describe different memory sections in the target (start addresses and size)

Linker uses this info to assign memory to merged sections

Calculate total code and memory consumed so far and possible throw error of memory exceeded

typically only one memory command per linker

Syntax:
```
MEMORY 
{
    name(attr) : ORIGIN = origin, LENGTH = len
}
```
name(attr) defines name of memory region

ORIGIN defines start address

LENGTH defines length of memory region

attr defines attribute list of memory region

valid attribute lists must be made of:

```
R - read only sections
W - read and write sections
X - excutable code
A - allocated
I - initialized section
L - same as I
! - invert the meaning of a, attribute
```
## Sections
Used to create different output sections in the final ELF generated

Used to instruct linker how to merge input sections into an output section

Controls order in which different output sections appear in the ELF file generated

Use this command to specify the placement of a section in memory. For example, tell linker to place .text section in memory region A (specified by memory command)

Example:
```
SECTIONS
{
    .text:
    {

    }>(vma) AT>(lma)

    .data:
    {

    }>(vma) AT>(lma)
}
```

This creates two sections in the final output ELF file

.text has all the .text sections of the input files
.data has all the data sections of the inptu files
## Keep
Acts as an override for linker's garbage collection mechanism. It ensures that certain code / data is kept even if it looks like it will not be used
## Align
align something to a certain boundary. for example, ensure code / data starts at an address that is a multiple of 4
## AT>
`> REGION1 AT > REGION2` specifies that a section has a runtime address in REGION1 but its original data is stored in REGION2
## .
location counter. tracks current memory address being processed by linker