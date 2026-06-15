FILE_SIZE=$$(wc -c < bin/loader.bin)
SECTOR_SIZE=512
CONSTANT=1
NUM_SECTORS=$$(( ($(FILE_SIZE) + $(SECTOR_SIZE) - $(CONSTANT)) / $(SECTOR_SIZE) ))

all:
	nasm -I./src/ -f bin ./src/kernel-loader.asm -o ./bin/loader.bin
	@echo "stage 2 is $(FILE_SIZE) bytes"
	@echo "number of sectors $(NUM_SECTORS)"
	nasm -I./src/ -f bin -d SECTORS=$(NUM_SECTORS) ./src/bootloader.asm -o ./bin/boot.bin
	cd bin && cat boot.bin loader.bin > bootloader.bin && cd ..

clean:
	rm -f ./bin/*

setup:
	if ([ ! -d "bin" ]); then mkdir bin; fi
	echo "setup complete"
debug:
	nasm -I./src/ -f elf32 -g -F dwarf bin ./src/kernel-loader.asm -o ./bin/loader.bin 
	@echo "stage 2 is $(FILE_SIZE) bytes"
	@echo "number of sectors $(NUM_SECTORS)"
	nasm -I./src/ -f bin -d SECTORS=$(NUM_SECTORS) ./src/bootloader.asm -o ./bin/boot.bin -g
	cd bin && cat boot.bin loader.bin > bootloader.bin && cd ..
	ld ...