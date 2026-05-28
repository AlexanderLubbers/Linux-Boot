all:
	nasm -I./src/ -f bin ./src/bootloader.asm -o ./bin/boot.bin

clean:
	rm -f ./bin/*