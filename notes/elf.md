# ELF files
Stands for Executable and Linkable Format and is used for storing a great many program times

For an executable program, an ELF header and a segment are the bare minimum an. Commonly contains sections
 .text and .data are the most common types of sections

## How to load ELF file
* verify that the file starts with the magic 4 ELF bytes
* read the ELF header (always at beginning)
* read executable program headers. specifies where program segments are located and where they must be loaded
* read program headers to determine the number of program segments that need to be loaded into memory
* load each of the loadable segments. do this by allocating memory and then loading that segment into the allocated memory
* read the executables entry point from ELF header, and then jump to it

## Helpful resource
https://wiki.osdev.org/ELF
