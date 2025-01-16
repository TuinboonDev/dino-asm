%define ICANON (1<<1)
%define ECHO   (1<<3)
%define IOCTL 16
%define F_GETFL 3
%define F_SETFL 4
%define O_NONBLOCK 00004000
%define TCGETS 21505
%define TCSETS 21506  

; https://syscalls.w3challs.com/?arch=x86_64
; https://github.com/torvalds/linux/

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

section .data
	stdin_fd equ 0
		 
	obstacleX db 0
	obstacleHeight db 0
	dinoHeight db 0
	lineI db 0
	columnI db 0

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

	dino: db "☺"
	dinoLen: equ $-dino

	obstacle: db "█", 10
	obstacleLen: equ $-obstacle

	space: db " "
	spaceLen: equ $-space

	newline: db 10
	newlineLen: equ $-newline

	floor: db "▀▀▀▀▀▀▀▀▀▀▀▀", 10
	floorLen: equ $-floor

section .text
	global _start

	_start:
		mov byte [dinoHeight], 0
		mov byte [obstacleX], 10
		mov byte [obstacleHeight], 0
		mov byte [lineI], 0
		mov byte [columnI], 0

		call unbuffer
		call main_loop

	dino_up:
		inc byte [dinoHeight]

		jmp main_loop

	shift_obstacle:
		mov byte [obstacleX], 10

	main_loop:
		mov byte [lineI], 4
		mov byte [buffer], 0
		cmp byte [obstacleX], 1
		je shift_obstacle

		call render_frame
		call get_input
		mov al, [buffer]

		cmp al, ' '
		je dino_up

		cmp al, 'q'
		je exit

		lea rdi, [timespec]
		mov rsi, 0
		mov rax, 35
		syscall

		dec byte [obstacleX]

		jmp main_loop

	debug:
	    mov rsi, w
		mov rdx, wLen
		mov rdi, 1
		mov rax, 1
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

	draw_floor:
		mov rsi, floor
		mov rdx, floorLen
		mov rdi, 1
		mov rax, 1
		syscall

		ret

	draw_wall:
		mov rsi, obstacle
		mov rdx, obstacleLen
		mov rdi, 1
		mov rax, 1
		syscall

		ret

	draw_dino:
		mov rsi, dino
		mov rdx, dinoLen
		mov rdi, 1
		mov rax, 1
		syscall

		ret

	dino_logic:
		mov al, [dinoHeight]
		mov ah, [lineI]
		cmp byte ah, al
		je dino_check
		jne draw_space

		ret

	draw_space:
		mov rsi, space
		mov rdx, spaceLen
		mov rdi, 1
		mov rax, 1
		syscall

		ret

	dino_check:
		cmp byte [columnI], 2
		je draw_dino
		jne draw_space

		ret

	wall_logic:
		call dino_logic

		mov al, [obstacleX]
		mov ah, [columnI]
		inc byte [columnI]
		cmp byte ah, al
		je draw_wall
		jl wall_logic

		ret

	line_logic:
		dec byte [lineI]
		mov byte [columnI], 0

	    cmp byte [lineI], 0	
	    je draw_floor
		jg wall_logic

		ret
		
	render_frame:
		call line_logic
		
		cmp byte [lineI], 0
		jge render_frame

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
