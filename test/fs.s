%include "sdk/osle.inc"
%include "sdk/bochs.inc"

[org 0]
bits 16

mov ax, 0x0003  ; Set video mode: 80x25 text mode, color
int 0x10

; Tries to locate this file (which surely exists)
mov di, this_file
mov bx, FILE_BUFFER_ADDR
int INT_FS_FIND
mov si, FIND_EXT
jc fail
call ok

; Creates a new file whose name is `filename`
mov di, filename
int INT_FS_CREATE
mov si, CREATE
jc fail
call ok

; Reads the name of the newly created file
mov cx, filename_len
mov si, filename
mov di, bx
repe cmpsb
mov si, NAME
jne fail
call ok

; Tries to locate the newly created file
mov di, filename
int INT_FS_FIND
pusha
  mov si, FIND_NEW
  jc fail
  call ok
popa

; Updates the newly created file
mov word [bx + FS_DATA_OFFSET], 0xbeef
mov dl, al
int INT_FS_WRITE
jc fail
mov word [bx + FS_DATA_OFFSET], 0x0000 ; clean memory
mov di, filename
int INT_FS_FIND
jc fail
cmp word [bx + FS_DATA_OFFSET], 0xbeef
mov si, UPDATE
jne fail
call ok

; Renames the newly created file
mov si, new_file
lea di, [bx + FS_PATH_OFFSET]
mov cx, filename_len
repe movsb
int INT_FS_WRITE
jc fail
mov di, new_file
int INT_FS_FIND
mov si, RENAME
jc fail
call ok

done:
  mov si, MSG
  call str_print
  xor ax, ax                      ; Function 0: Read Character
  int 0x16

  cmp al, 0x0D                    ; key is ENTER
  int INT_RETURN

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
RENAME:     db "rename   ", 0
UPDATE:     db "update   ", 0

MSG:    db  0x0D, 0x0A, "Total: 6", 0x0D, 0x0A, "Press RETURN to continue", 0

new_file: db "aaaa.txt", 0
filename: db "text.txt", 0
filename_len equ $-filename
this_file: db "fs"

; vim: ft=nasm tw=80 cc=+0 commentstring=;\ %s
