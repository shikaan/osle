bits 16
%include "sdk/osle.inc"
mov ah, 0x00
mov al, 0x03
int 0x10

mov si, VERSION
mov cx, 0xFFFF
call str_print

mov si, BUILTINS
mov cx, 0xFFFF
call str_print

mov si, PROGRAMS
mov cx, 0xFFFF
call str_print

mov si, INFO
mov cx, 0xFFFF
call str_print

mov ax, 0
int 0x16
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

VERSION:  db 0x0a, 0x0d
          db "OSle - https://github.com/shikaan/osle"
          db 0x0a, 0x0d, 0

BUILTINS: db 0x0a, 0x0d, "Builtins:", 0x0a, 0x0d
          db "  - ls: list all files and commands", 0x0a, 0x0d
          db "  - cl: clear the screen", 0x0a, 0x0d, 0x0a, 0x0d, 0

PROGRAMS: db "Programs:", 0x0a, 0x0d
          db "  - ed <text-file>: open a text editor", 0x0a, 0x0d
          db "  - help: show this help", 0x0a, 0x0d
          db "  - more <text-file>: preview the content of a file", 0x0a, 0x0d
          db "  - mv <source-path> <destination-path>: move file from source"
          db    " to destination", 0x0a, 0x0d
          db "  - rm <file-path>: delete a file", 0x0a, 0x0d
          db "  - snake: launch a snake game", 0x0a, 0x0d, 0x0a, 0x0d, 0

INFO:     db "For any feedack please refer to "
          db "https://github.com/shikaan/osle/issues", 0x0a, 0x0d, 0

RETURN:   db 0x0a, 0x0d, "Press any key to return", 0

; vim: ft=nasm tw=80 cc=+0 commentstring=;\ %s