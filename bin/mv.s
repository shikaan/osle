bits 16
%include "sdk/bochs.inc"
%include "sdk/osle.inc"

mov ah, 0x00                  ; clean screen
mov al, 0x03
int 0x10

mov si, PM_ARGS               ; parse cli arguments replacing spaces with 0
push si
mov cx, FS_PATH_SIZE*2 + 1
mov dx, 1
parse:
  cmp byte [si], ' '
  jne .continue
.split:
  mov byte [si], 0
  mov bx, si
  inc bx
  inc dx
  push bx
.continue:
  inc si
  loop parse

mov si, ERR_INVALID_ARG       ; if there aren't exactly two arguments, bail
cmp dx, 2
jne fail

pop si
mov word [DESTINATION], si    ; validate destination path:
mov cx, FS_PATH_SIZE          ;   if there are non-printable chars, error
validate:
  mov al, [si]
  call is_printable
  je .continue 
.error:
  mov si, ERR_INVALID_ARG
  jmp fail
.continue:
  loop validate
  
pop di                        ; try locate the source file
mov word [SOURCE], di
mov bx, FILE_BUFFER
int INT_FS_FIND
mov si, ERR_NOT_FOUND
jc fail

push ax
  mov cx, FS_PATH_SIZE
  lea di, [FILE_BUFFER + FS_PATH_OFFSET]
zero_byte:                    ; zero the name portion of the header
  mov byte [di], 0
  inc di
  loop zero_byte

  mov si, [DESTINATION]       ; copy the new file name in file header
  lea di, [FILE_BUFFER + FS_PATH_OFFSET]
  mov cx, FS_PATH_SIZE
  repe movsb
pop ax

mov bx, FILE_BUFFER           ; write file on disk
mov dl, al
int INT_FS_WRITE
mov si, ERR_WRITE
jc fail

mov si, SUCCESS               ; communicate success to the user
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

; is_printable(al: u8)
; Sets zero flag when al is a printable character
is_printable:
  cmp al, 32
  jb .false
  cmp al, 126
  ja .false
  cmp al, al    ; sets zero flag
  ret
.false:
  cmp al, 32    ; clears zero flag (al cannot be 32)
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

ERR_NOT_FOUND:    db "Unable to find source file", 0
ERR_INVALID_ARG:  db "Invalid arguments", 0
ERR_WRITE:        db "Cannot edit file", 0
SUCCESS:          db "Success!", 0
RETURN:           db 0x0a, 0x0d, "Press any key to return", 0
USAGE:            db 0x0a, 0x0d, 0x0a, 0x0d
                  db "  Usage: mv <source-file> <destination-file>"
                  db 0x0a, 0x0d, 0

FILE_BUFFER       equ 0x4000
SOURCE            equ 0x3000
DESTINATION       equ 0x3018

; vim: ft=nasm tw=80 cc=+0 commentstring=;\ %s
