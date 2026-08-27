FILE_SIZE=$$(wc -c < bin/loader.bin)
ELF_LOADER_SIZE=$$(wc -c < bin/elf_loader.bin)
SECTOR_SIZE=512
CONSTANT=1
NUM_SECTORS=$$(( ($(FILE_SIZE) + $(SECTOR_SIZE) - $(CONSTANT)) / $(SECTOR_SIZE) ))
ELF_SIZE=$$(wc -c < elf/loader.elf)
ELF_SECTORS=$$(( ($(ELF_SIZE) + $(SECTOR_SIZE) - $(CONSTANT)) / $(SECTOR_SIZE) ))
ELF_LOADER_SECTORS=$$(( ($(ELF_LOADER_SIZE) + $(SECTOR_SIZE) - $(CONSTANT)) / $(SECTOR_SIZE) ))

all:
	nasm -f elf64 ./src/kernel-loader.asm -o ./elf/loader.o
	gcc -m64 -ffreestanding -c ./src/fat_driver.c -o ./elf/fat_driver.o
	gcc -m64 -ffreestanding -c ./src/rsdp.c -o ./elf/rsdp.o
	ld -T linker.ld ./elf/loader.o ./elf/fat_driver.o ./elf/rsdp.o -o ./elf/loader.elf
	nasm -f bin ./src/elf_loader.asm -o ./bin/elf_loader.bin
	@echo "elf loader is $(ELF_LOADER_SIZE) bytes"
	@echo "number of sectors in elf loader $(ELF_LOADER_SECTORS)"
	@echo "stage 2 is $(ELF_SIZE) bytes"
	@echo "number of sectors in stage 2 $(ELF_SECTORS)"
	nasm -f bin -d SECTORS=$(ELF_LOADER_SECTORS) ./src/bootloader.asm -o ./bin/boot.bin
	cat ./bin/boot.bin ./bin/elf_loader.bin ./elf/loader.elf > ./elf/bootloader.img
clean:
	rm -f ./bin/*
	rm -f ./elf/*

setup:
	if ([ ! -d "bin" ]); then mkdir bin; fi
	if ([ ! -d "elf" ]); then mkdir elf; fi
	echo "setup complete"
debug:
	nasm -f elf64 ./src/kernel-loader.asm -o ./elf/loader.o
	gcc -m64 -ffreestanding -c -g ./src/fat_driver.c -o ./elf/fat_driver.o
	gcc -m64 -ffreestanding -c -g ./src/rsdp.c -o ./elf/rsdp.o
	ld -T linker.ld ./elf/loader.o ./elf/fat_driver.o ./elf/rsdp.o -o ./elf/loader.elf
	nasm -f bin ./src/elf_loader.asm -o ./bin/elf_loader.bin
	@echo "elf loader is $(ELF_LOADER_SIZE) bytes"
	@echo "number of sectors in elf loader $(ELF_LOADER_SECTORS)"
	@echo "stage 2 is $(ELF_SIZE) bytes"
	@echo "number of sectors in stage 2 $(ELF_SECTORS)"
	nasm -f bin -d SECTORS=$(ELF_LOADER_SECTORS) ./src/bootloader.asm -o ./bin/boot.bin
	nasm -f elf64 -g -F dwarf -DDEBUG ./src/kernel-loader.asm -o ./elf/loaderdebug.o
	ld -T linker.ld ./elf/loaderdebug.o ./elf/fat_driver.o ./elf/rsdp.o -o ./elf/loaderdebug.elf
	cat ./bin/boot.bin ./bin/elf_loader.bin ./elf/loader.elf > ./elf/bootloader.img