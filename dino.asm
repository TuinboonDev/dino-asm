%define ICANON (1<<1)
%define ECHO   (1<<3)
%define IOCTL 16
%define F_GETFL 3
%define F_SETFL 4
%define O_NONBLOCK 00004000
%define TCGETS 21505
%define TCSETS 21506  

%define EAGAIN 11
%define EWOULDBLOCK 11

struc termios
    resb 12
	.flags: resb 12
	resb 44
endstruc

section .bss
	stty resb termios_size
	tty  resb termios_size

	buffer resb 1
	flags resd 1

	obstacleX resb 1
	obstacleHeight resb 1
	dinoHeight resb 1
	lineI resb 1

section .data
	debug_no_input: db "No input", 10
    debug_no_input_len: equ $-debug_no_input

	stdin_fd equ 0
		 
	timespec:
	    dq 1
		dq 0

	original_termios db 32 dup(0)
	
	w: db "wow", 10
	wLen: equ $-w

	ansi_home: db 27,"[H"
	ansi_home_len: equ $-ansi_home

	ansi_clear: db 27,"[2J"
	ansi_clear_len: equ $-ansi_clear

; 	dinoHeight: db 0

	dino: db "☺"
	dinoLen: equ $-dino

	obstacle: db "█", 10, "█", 10, "█", 10
	obstacleLen: equ $-obstacle

	newline: db 10
	newlineLen: equ $-newline

	floor: db "▀▀▀▀▀▀▀▀▀▀▀▀", 10
	floorLen: equ $-floor

section .text
	global _start

	_start:
		mov byte [dinoHeight], 0
		mov byte [obstacleX], 0
		mov byte [obstacleHeight], 0
		mov byte [lineI], 0

		call unbuffer
		call main_loop

	dino_up:
		mov al, [dinoHeight]
		inc al
		mov [dinoHeight], al

		add al, "0"
		mov [buffer], al

		mov rax, 1
		mov rdi, 1
		lea rsi, buffer
		mov rdx, 1
		syscall

		jmp main_loop

	main_loop:	
		call render_frame
		call get_input
		mov al, [buffer]

		cmp al, ' '
		je dino_up

		cmp al, 'q'
		je exit

		mov rsi, 65
		mov rdx, 1
		mov rdi, 1
		mov rax, 1
		syscall

		lea rdi, [timespec]
		mov rsi, 0
		mov rax, 35
		syscall
		
		jmp main_loop

	debug_buffer:
	    mov rax, 1
		mov rdi, 1             
		lea rsi, [buffer]
		mov rdx, 1
		syscall
		ret

	clear_term:
	    mov rsi, ansi_clear
		mov rdx, ansi_clear_len
		mov rdi, 1
		mov rax, 1
		syscall

		mov rsi, ansi_home
		mov rdx, ansi_home_len
		mov rdi, 1
		mov rax, 1
		syscall

		ret

	render_frame:
		mov rsi, dino
		mov rdx, dinoLen
		mov rdi, 1
		mov rax, 1
		syscall

		ret

	exit:
		call restore_buffer
		
		mov rax, 60
		mov rdi, 0
		syscall

	get_input:
		mov rdi, stdin_fd
		lea rsi, [buffer]
		mov rdx, 1
		mov rax, 0
		syscall

		ret

	set_nonblocking:
        mov rax, 72
        mov rdi, 0
        mov rsi, F_GETFL
        mov rdx, 0
        syscall     

        or rax, O_NONBLOCK
        mov [flags], rax

        mov rax, 72
        mov rdi, 0
        mov rsi, F_SETFL
        mov rdx, [flags]
        syscall      

        ret
	
	unbuffer:
		mov rax, stty
		mov rdx, 0
		call ioctl

		mov rax, tty
		mov rdx, 0
		call ioctl
				        
		and dword [tty+termios.flags], (~ICANON)
		and dword [tty+termios.flags], (~ECHO)
	
		mov rax, tty
		mov rdx, 1
		call ioctl

		call set_nonblocking

		ret

	restore_buffer:
		mov rax, stty
		mov rdx, 1
		call ioctl

		ret

	ioctl:
		push rdi
		push rsi

		add rdx, TCGETS
		mov rsi, rdx
		mov rdx, rax
		mov rdi, 0
		mov rax, IOCTL
		syscall

		pop rsi
		pop rdi
		
		ret
