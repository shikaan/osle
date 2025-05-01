; Hello!
; This little example will guide you through writing your first OSle program.
;
; As tradition demands, our first program will be a "Hello World". It will give
; us a chance to speak about OSle's SDK and capabilities without becoming too
; complex.
;
; Our program will just print on screen "Hello world" and upon pressing any key
; it will return to the OS.
;
; Let's go!

; Here we are instructing the assembler to generate 16-bit code.
; OSle is a real-mode OS: programs have direct access to the hardware, but it 
; comes at the price of not having memory protection or multitasking, and only
; 1mb memory limit. 
bits 16

; Here we are including the OSle SDK.
; OSle's SDK is a collection of preprocessor directives which won't affect the 
; size of your final code.
%include "sdk/osle.inc"

; This block clears the screen.
; We use the BIOS interrupt 0x10, function 0x00 which means "setup screen" and
; the value `0x03` means 80x25, our current configuration.
mov ah, 0x00
mov al, 0x03
int 0x10

; Data is defined at the end of the file. `HELLO` is pointer to our "Hello 
; world!" string. We call str_print to print the string in si. Go check the
; function signature in this file for more details.
mov si, HELLO
mov cx, 0xFF
call str_print

; Same as above, but for the RETURN string
mov si, RETURN
mov cx, 0xFF
call str_print

; This block waits for a new character (BIOS interrupt 0x16, function 0).
mov ax, 0
int 0x16

; ...And finally we are using the first OSle-specific feature!
; OSle exposes some services (also known as syscalls or software interrupts)
; that we will use to build our programs. Go check the "sdk/osle.inc" file for
; more details.
; This interrupt triggers the INT_RETURN service, which returns the control to
; the OS once we are done.
;
; Check out the README for informatio on how to run this code.
int INT_RETURN

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

; These are the string definitions of our program. `0x0a 0x0d` is a new line.
HELLO: db "Hello, world!", 0x0a, 0x0d, 0
RETURN: db "Press any key to return", 0

; vim: ft=nasm tw=80 cc=+0 commentstring=;\ %s