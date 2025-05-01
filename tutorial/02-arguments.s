; Hello again!
;
; Our second program is just slightly more complex than the first one. We will
; code an `echo` program, where the user will pass a string as an argument and
; we will print it on the screen.
;
; Let's go!

; Once egain, we instruct the assembler to generate 16-bit code and include the
; OSle SDK in our program.
bits 16
%include "sdk/osle.inc"

; Same as before, we are cleaning the screen before printing anything new.
mov ah, 0x00
mov al, 0x03
int 0x10

; OSle stores the arguments passed to your program in a special place in memory 
; at address `PM_ARGS`. PM stands for Process Management and you can read more
; about it in "sdk/osle.inc".
; Unlike what you would see in C, for example, all the arguments are in one 
; string and the receiving application needs to parse it (for example, dividing
; arguments by space).
; Here we need not parsing, we'll pass the arguments as they are to `str_print`.
mov si, PM_ARGS
mov cx, 0xFF
call str_print

; As in the previous exercise, we tell the user how to leave the program.
mov si, RETURN
mov cx, 0xFF
call str_print

; This block waits for a new character (BIOS interrupt 0x16, function 0).
mov ax, 0
int 0x16

; We are finally ready to return control to the OS.
int INT_RETURN

; Once you are ready compile and bundle this program in your OSle image with
;
;   sdk/build tutorial/02-arguments.s
;   sdk/pack tutorial/02-arguments.bin
;
; Check out the README to make sure you have all the required dependencies.

; Definitions
; -----------

; str_print(si: u8* string, cx: u16 max_length) -> void
; Prints up to up to cx characters of the string in si on screen.
str_print:
  pusha
    mov ah, 0x0E    ; 0x0E is teletype function for interrupt 0x10. It means
.loop:              ; "print char and advance cursor"
    lodsb
    test al, al     ; String are null terminated. Stop when current byte is 0
    je .done
    int 0x10        ; Issue interrupt to print on screen
    loop .loop
.done:
  popa
  ret

; Again, `0x0a 0x0d` is a new line.
RETURN: db 0x0a, 0x0d, "Press any key to return", 0

; vim: ft=nasm tw=80 cc=+0 commentstring=;\ %s