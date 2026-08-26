FILE_SIZE=$$(wc -c < bin/loader.bin)
ELF_LOADER_SIZE=$$(wc -c < bin/elf_loader.bin)
SECTOR_SIZE=512
CONSTANT=1
NUM_SECTORS=$$(( ($(FILE_SIZE) + $(SECTOR_SIZE) - $(CONSTANT)) / $(SECTOR_SIZE) ))
ELF_SIZE=$$(wc -c < elf/loader.elf)
ELF_SECTORS=$$(( ($(ELF_SIZE) + $(SECTOR_SIZE) - $(CONSTANT)) / $(SECTOR_SIZE) ))
ELF_LOADER_SECTORS=$$(( ($(ELF_LOADER_SIZE) + $(SECTOR_SIZE) - $(CONSTANT)) / $(SECTOR_SIZE) ))

all:
	nasm -f bin ./src/kernel-loader.asm -o ./bin/loader.bin
	@echo "stage 2 is $(FILE_SIZE) bytes"
	@echo "number of sectors $(NUM_SECTORS)"
	nasm -f bin -d SECTORS=$(NUM_SECTORS) ./src/bootloader.asm -o ./bin/boot.bin
	cd bin && cat boot.bin loader.bin > bootloader.bin && cd ..
clean:
	rm -f ./bin/*
	rm -f ./elf/*

setup:
	if ([ ! -d "bin" ]); then mkdir bin; fi
	if ([ ! -d "elf" ]); then mkdir elf; fi
	echo "setup complete"
debug:
	nasm -f bin ./src/kernel-loader.asm -o ./bin/loader.bin
	nasm -f elf32 -g -F dwarf -DDEBUG ./src/kernel-loader.asm -o ./elf/loader.o
	ld -m elf_i386 -Ttext 0x7e00 -o ./elf/loader.elf ./elf/loader.o
	@echo "stage 2 is $(FILE_SIZE) bytes"
	@echo "number of sectors $(NUM_SECTORS)"
	nasm -f bin -d SECTORS=$(NUM_SECTORS) ./src/bootloader.asm -o ./bin/boot.bin
	cd bin && cat boot.bin loader.bin > bootloader.bin && cd ..

test:
	nasm -f elf64 -DDEBUG ./src/kernel-loader.asm -o ./elf/loader.o
	gcc -m64 -ffreestanding -c ./src/fat_driver.c -o ./elf/fat_driver.o
	gcc -m64 -ffreestanding -c ./src/rsdp.c -o ./elf/rsdp.o
	ld -T linker.ld ./elf/loader.o ./elf/fat_driver.o ./elf/rsdp.o -o ./elf/loader.elf
	@echo "stage 2 is $(ELF_SIZE) bytes"
	@echo "number of sectors $(ELF_SECTORS)"
	nasm -f bin ./src/elf_loader.asm -o ./bin/elf_loader.bin
	@echo "stage 2 is $(ELF_LOADER_SIZE) bytes"
	@echo "number of sectors $(ELF_LOADER_SECTORS)"
	nasm -f bin -d SECTORS=$(ELF_LOADER_SECTORS) ./src/bootloader.asm -o ./bin/boot.bin
	nasm -f elf32  -DDEBUG -g -F dwarf ./src/elf_loader.asm -o ./elf/elfdebug.o
	ld -m elf_i386 -Ttext 0x0500 -o ./elf/elfdebug.elf ./elf/elfdebug.o
	nasm -f elf32 -g -F dwarf -DDEBUG ./src/kernel-loader.asm -o ./elf/loaderdebug.o
	ld -m elf_i386 -Ttext 0x7e00 -o ./elf/loaderdebug.elf ./elf/loaderdebug.o
	cat ./bin/boot.bin ./bin/elf_loader.bin ./elf/loader.elf > ./elf/bootloader.img