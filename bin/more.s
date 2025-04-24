%include "sdk/osle.inc"
%include "sdk/bochs.inc"

bits 16

mov ax, 0x0003  ; Set video mode: 80x25 text mode, color
int 0x10

mov di, PM_ARGS
mov bx, FILE_BUFFER_ADDR
int INT_FS_FIND
jc fail

mov cx, [bx + FS_SIZE_OFFSET]
lea si, [bx + FS_DATA_OFFSET]
call print_buffer
mov si, MSG
mov cx, MSG_LEN
call print_string
jmp done

fail:
  mov si, ERROR
  mov cx, ERROR_LEN
  call print_string
  mov si, MSG
  mov cx, MSG_LEN
  call print_string
  ; cascades

done:
  xor ax, ax
  int 0x16
  int INT_RETURN
  jmp $

print_string:
  mov ah, 0x0E
.loop:
  lodsb
  test al, al
  je .done
  int 0x10
  loop .loop
.done:
  ret

print_buffer:
  mov ah, 0x0E
.loop:
  lodsb
  int 0x10
  loop .loop
  ret

ERROR: db "Cannot read file", 0
ERROR_LEN equ $-ERROR
MSG: db 0x0A, 0x0D, 0x0A, 0x0D, "Press any key to continue", 0
MSG_LEN equ $-MSG
FILE_BUFFER_ADDR equ 0x4000

; vim: ft=nasm tw=80 cc=+0 commentstring=;\ %s
