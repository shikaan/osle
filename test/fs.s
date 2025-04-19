%macro debugger 0
  xchg bx,bx
%endmacro

bits 16

mov ax, 0x0003  ; Set video mode: 80x25 text mode, color
int 0x10

mov di, filename
int INT_FS_FIND
jc fail
call ok

done:
  xor ax, ax                      ; Function 0: Read Character
  int 0x16

  cmp al, 0x0D                    ; key is ENTER
  int INT_RETURN

ok:
  mov si, OK
  call str_print
  ret

fail:
  mov si, FAIL
  call str_print
  jmp done

str_print:
  mov ah, 0x0E   ; teletype function for interrupt 0x10
  mov cx, 10
.loop:
  lodsb
  test al, al    ; is end of the string?
  je .done
  int 0x10
  loop .loop
.done:
  ret

INT_RETURN    equ 0x20
INT_FS_CREATE equ 0x21
INT_FS_WRITE  equ 0x22
INT_FS_FIND   equ 0x23
INT_FS_DELETE equ 0x24

OK:   db " OK ", 0x0D, 0x0A, 0
FAIL: db "FAIL", 0x0D, 0x0A, 0

filename: db "snake.bin", 0

; vim: ft=nasm tw=80 cc=+0 commentstring=;\ %s