build:
	nasm -f elf64 dino.asm -o dino.o
	ld dino.o -o dino -z noseparate-code --strip-all
	rm dino.o

run: build
	./dino

uri: build
	echo "data:application/octet-stream;base64,"$$(base64 dino -w0) > uri.txt

qr: uri
	qrencode -o qr.png $$(cat uri.txt)
	rm uri.txt
	rm dino
