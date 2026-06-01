all:
	nasm -I./src/ -f bin ./src/bootloader.asm -o ./bin/boot.bin
	nasm -I./src/ -f bin ./src/kernel-loader.asm -o ./bin/loader.bin
	cd bin && cat boot.bin loader.bin > bootloader.bin && cd ..

clean:
	rm -f ./bin/*