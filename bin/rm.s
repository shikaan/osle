bits 16
%include "sdk/osle.inc"
mov ah, 0x00
mov al, 0x03
int 0x10

mov di, PM_ARGS           ; bail on missing argument
cmp byte [di], 0
mov si, ERR_INVALID_ARG
je fail

mov bx, FILE_BUFFER       ; try locate the argument file
int INT_FS_FIND
mov si, ERR_NOT_FOUND
jc fail

push ax                   ; zero the whole file block
  mov cx, FS_BLOCK_SIZE
  mov di, FILE_BUFFER
zero_byte:
  mov byte [di], 0
  inc di
  loop zero_byte
pop ax

mov bx, FILE_BUFFER       ; write the block on disk
mov dl, al
int INT_FS_WRITE
mov si, ERR_WRITE
jc fail

mov si, SUCCESS           ; communicate result to the user
mov cx, 0xFF
call str_print

exit:
  mov si, RETURN
  mov cx, 0xFF
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

; fail(si: u8* string) -> void
; Prints the error message in si and exits the program.
fail:
  mov cx, 0xFF
  call str_print
  mov cx, 0xFF
  mov si, USAGE
  call str_print
  jmp exit

ERR_INVALID_ARG:  db "Invalid argument", 0
ERR_NOT_FOUND:    db "File not found", 0
ERR_WRITE:        db "Cannot edit file", 0
SUCCESS:          db "Success!", 0
RETURN:           db 0x0a, 0x0d, "Press any key to return", 0
USAGE:            db 0x0a, 0x0d, 0x0a, 0x0d, "  Usage: rm <file>", 0x0a, 0x0d, 0

FILE_BUFFER     equ 0x4000

; vim: ft=nasm tw=80 cc=+0 commentstring=;\ %s