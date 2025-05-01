; Welcome back!
;
; In the last part of our tutorial we will implement the `rm` utility: a program
; that deletes the file that is passed as argument. It will give us the chance
; to look at OSle's approach to the file system.
;
; Let's go!

; We know the drill now, this is how we include OSle's SDK in our program and
; subsequently clean up the screen.
bits 16
%include "sdk/osle.inc"
mov ah, 0x00
mov al, 0x03
int 0x10

; The first thing we want to do is making sure the file that is passed as an 
; argument exists.
; OSle provides a service, INT_FS_FIND, to perform a lookup in the file system;
; if the file is found, it returns it in the memory address in bx, otherwise it
; sets the carry flag to signal failure.
; As always, you can read more about INT_FS_FIND in "sdk/osle.inc".
;
; More specifically in this block we are collecting the filename from the args,
; as we did it before, and we will load the file in memory at `FILE_BUFFER`
mov di, PM_ARGS
mov bx, FILE_BUFFER
int INT_FS_FIND
mov si, ERR_NOT_FOUND
jc fail

; Deleting a file in OSle is a matter of zeroing the disk location associated 
; with it. In the previous call we obtained a buffer, so we can now zero it and
; later on we will write it back to the disk.
push ax
  mov cx, FS_BLOCK_SIZE
  mov di, FILE_BUFFER
zero_byte:
  mov byte [di], 0
  inc di
  loop zero_byte
pop ax

; Good job! Now the in-memory version of our file is completely zeroed out.
; We are ready to write it back to the disk.
; OSle provides the INT_FS_WRITE interrupt to write files back on disk.
; Go check out "sdk/osle.inc" for more details.
;
; The INT_FS_FIND call we did early returned in ax a file handle; a pointer to 
; the location on disk where the file lived. Along with bx, which works like
; before, this handle is the other argument for INT_FS_WRITE. 
mov bx, FILE_BUFFER
mov dl, al
int INT_FS_WRITE
mov si, ERR_WRITE
jc fail

; If everything went alright, we can let our users know.
mov si, SUCCESS
mov cx, 0xFF
call str_print

; This is the same exit routine as all the other exercises so far.
;
; With this, you know all you need to start developing your OSle programs.
; Take a look at the other utilities in `/bin` for more examples.
;
; Congratulations!
;
; If you have feedback on this course, or OSle in general, feel free to open an
; issue https://github.com/shikaan/OSle/issues/new
exit:
  ; As in the previous exercise, we tell the user how to leave the program.
  mov si, RETURN
  mov cx, 0xFF
  call str_print

  ; This block waits for a new character (BIOS interrupt 0x16, function 0).
  mov ax, 0
  int 0x16

  ; We are finally ready to return control to the OS.
  ;
  ; Once you are ready compile and bundle this program in your OSle image with
  ;
  ;   sdk/build tutorial/03-files.s
  ;   sdk/pack tutorial/03-files.bin
  ;
  ; Check out the README to make sure you have all the required dependencies.
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
  jmp exit

; Again, `0x0a 0x0d` is a new line.
ERR_NOT_FOUND:  db "Unable to remove file: file not found", 0
ERR_WRITE:      db "Unable to remove file: cannot write on file", 0
SUCCESS:        db "Success!", 0
RETURN:         db 0x0a, 0x0d, "Press any key to return", 0

; Memory location where we store the file in memory
FILE_BUFFER     equ 0x4000

; vim: ft=nasm tw=80 cc=+0 commentstring=;\ %s