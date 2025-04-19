[org 0]
bits 16

mov ax, 0x0003  ; Set video mode: 80x25 text mode, color
int 0x10

mov si, HELLO
mov cx, 0xFF
call str_print

mov si, RETURN
mov cx, 0xFF
call str_print

xor ax, ax                      ; Function 0: Read Character
int 0x16

cmp al, 0x0D                    ; key is ENTER
je .cmd
.cmd:
  int 0x20

jmp $           ; Infinite loop to halt execution
  
str_print:
  mov ah, 0x0E   ; teletype function for interrupt 0x10
.loop:
  lodsb
  test al, al    ; is end of the string?
  je .done
  int 0x10
  loop .loop
.done:
  ret

HELLO: db "Hello, world!", 0x0a, 0x0d, 0
RETURN: db "Press ENTER to return", 0

times 510-($-$$) db 0 ; Pad with zeros to make 512 bytes
dw 0xAA55           ; Boot signature

; vim: ft=nasm tw=80 cc=+0 commentstring=;\ %s