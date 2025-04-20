%macro debugger 0
  xchg bx,bx
%endmacro

bits 16

mov ax, 0x0003  ; Set video mode: 80x25 text mode, color
int 0x10

mov di, this_file
int 0x21
mov si, FIND_EXT
jc fail
call ok

mov di, filename
mov bx, FILE_BUFFER_ADDR
int 0x22
mov si, CREATE
jc fail
call ok

mov cx, filename_len
mov si, filename
mov di, bx
repe cmpsb
mov si, NAME
jne fail
call ok

mov di, filename
int 0x21
mov si, FIND_NEW
jc fail
call ok

done:
  mov si, MSG
  call str_print
  xor ax, ax                      ; Function 0: Read Character
  int 0x16

  cmp al, 0x0D                    ; key is ENTER
  int 0x20

ok:
  call str_print
  mov si, OK
  call str_print
  ret

fail:
  call str_print
  mov si, FAIL
  call str_print
  jmp done

str_print:
  mov ah, 0x0E   ; teletype function for interrupt 0x10
  mov cx, 100
.loop:
  lodsb
  test al, al    ; is end of the string?
  je .done
  int 0x10
  loop .loop
.done:
  ret
   
FILE_BUFFER_ADDR equ 0x4000

OK:   db " OK ", 0x0D, 0x0A, 0
FAIL: db "FAIL", 0x0D, 0x0A, 0

CREATE:     db "create   ", 0
FIND_NEW:   db "find new ", 0
FIND_EXT:   db "find ext ", 0
NAME:       db "name     ", 0

MSG:    db  0x0D, 0x0A, "Total: 4", 0x0D, 0x0A, "Press RETURN to continue", 0

filename: db "test.txt", 0
filename_len equ $-filename
this_file: db "fs.bin"

; vim: ft=nasm tw=80 cc=+0 commentstring=;\ %s
