# Pontifex

Pontifex (latin for bridge builder) is a custom bootloader that leverages BIOS firmware to boot an elf kernel

## How To Set Up and Build

```
make setup
make all
```
## Disk format
LBA 0: boot.bin

LBA 1+: loader.bin

## Memory Map Format

Entry format:

base address (8 bytes), length (8 bytes), region type (4 bytes), ACPI attributes (4 bytes)

types:

type 1 (usable)

type 2 (reserved)

type 3 (ACPI reclaimable memory)

type 4 (ACPI NVS memory)

type 5 (bad memory)