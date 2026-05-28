all:
	nasm -f bin ./src/boot.asm -o ./bin/boot.bin

clean:
	rm -f ./bin/*

run:
	qemu-system-x86_64 -hda ./bin/boot.bin