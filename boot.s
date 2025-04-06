
; Calling convention
;   - function preserves bx;
;   - invoker preserves ax, cx, di, si;
;   - ax is the return register;
%macro fn_start 0
  push bx
%endmacro

%macro fn_end 0
  pop bx
  ret
%endmacro

[org 0x7c00]
bits 16
xor ax, ax      
mov ds, ax      ; Data segment
mov es, ax      ; Extra segment
mov ss, ax      ; Stack segment
mov sp, 0x7c00  ; Set stack pointer

mov ax, 0x0003  ; Set video mode: 80x25 text mode, color
int 0x10

main:
  call shell
  jmp $          ; Infinite loop

; Definitions
; ===========

; Shell
; -----

; shell(void)
; Launches an interactive command prompt, the entry point of our real-mode OS.
shell:
.print_prompt:
  mov si, PROMPT
  mov cx, 3
  call str_print

.wait_for_key:
  call kbd_get_key
  cmp al, 0x0D                    ; key is ENTER
  je .cmd
  cmp al, 0x08                    ; key is BACKSPACE
  je .backspace
  jne .print_char                 ; else, try to print

; TODO: this can overflow.
.print_char:
  mov bh, 0
  mov bl, [input_len]             ; append to input
  mov byte [input + bx], al
  mov byte [input + bx + 1], 0    ; null terminate the input
  inc byte [input_len]
  
  mov di, ax
  call scr_tty                    ; write the new character on screen

  jmp .wait_for_key

.backspace:
  mov di, ax                      ; print backspace (move backwards)
  call scr_tty
  
  mov di, 0                       ; delete last char on screen
  call scr_put_char
  
  mov bx, [input_len]             ; remove last char from input
  mov byte [input + bx], 0x0
  dec byte [input_len]
  
  jmp .wait_for_key
  
.cmd:
  call sh_cr
  
  mov di, input
  mov si, CLEAR
  mov cx, 5
  repe cmpsb
  je .cmd_clear                     ; command is the builtin clear

  mov di, input
  mov si, ECHO
  mov cx, 5
  repe cmpsb
  je .cmd_echo                      ; command is the builtin echo
  
  jmp .cmd_error                    ; command is unknown

.cmd_clear:
  call scr_clear      
  mov di, -1                      ; move cursor outside of the page 
  call cur_set                    ; it will be restored in .flush
  jmp .flush

.cmd_echo:
  lea si, [input + 5]             ; the input string without "echo "
  mov cx, 0xFF
  call str_print
  jmp .flush

.cmd_error:
  mov si, input                   ; print input command
  mov cx, [input_len]
  call str_print

  mov si, ERROR                   ; print the rest of the message
  mov cx, 0XFF
  call str_print

.flush:
  call sh_cr
  mov byte [input], 0
  mov byte [input_len], 0
  jmp .print_prompt

.break:
  ret

; sh_cr(void)
; Moves the cursor at the beginning of the next line.
sh_cr:
  mov si, CR
  mov cx, 3
  call str_print
  ret

; Keyboard
; --------

; kbd_get_key(void) -> (ax: u16 scan_code|key_code)
; Waits for a key press and returns the key code in al and scan code in ah
kbd_get_key:
  mov ah, 0x00  ; Function 0: Read character
  int 0x16
  ret

; String
; ------

; str_print(si: u8* string, cx: count) -> void
; Prints a string up to cx chars
str_print:
  mov ah, 0x0E   ; teletype function for interrupt 0x10
.loop:
  lodsb
  test al, al    ; is end of the string?
  jz .done
  int 0x10
  loop .loop
.done:
  ret

; Cursor
; ------

; cur_set(di: u16 col|row)
; Sets the cursor position on the screen. Low byte is column, high byte is row.
cur_set:
fn_start
  mov dx, di
  mov ah, 0x02
  mov bh, 0x00
  int 0x10
fn_end

; Screen
; ------

; scr_clear(void)
; Clears the screen and scrolls the window up.
scr_clear:
fn_start
  mov ax, 0x0600  ; scroll up and clear window
  mov cx, 0x0000  ; top left corner = 0,0
  mov dx, 0x184F  ; bottom right corner = 18,4F
  mov bh, 0x07    ; set background color
  int 0x10
fn_end

; scr_put_char(di: u8 char) -> void
; Writes a character to the screen at the current cursor position.
scr_put_char:
fn_start
  mov ax, di
  mov ah, 0x0A    ; 0A: write character
  mov bh, 0x00    ; page = 0
  mov cx, 1       ; how many repetitions?
  int 0x10
fn_end

; scr_tty(di: u8 char) -> void
; Like put_char, but advances the cursor as well.
scr_tty:
fn_start
  mov ax, di
  mov ah, 0x0E  ; 0E: teletype
  mov bh, 0x00  ; page = 0
  int 0x10
fn_end

; Data
; ====
; Uppercase values are constants.

input     times 0x20 db 0
input_len db 0
CLEAR     db 'clear', 0
ECHO      db 'echo ', 0             ; The space is to not match "echowhatever"
ERROR     db ': malformed command', 0
CR        db 0x0A, 0x0D, 0
PROMPT    db "$ ", 0

; Pad the file to reach 510 byte and add boot signature at the end.
times 510-($-$$) db 0
dw 0xAA55
; vim: ft=nasm tw=80 cc=+0 commentstring=;\ %s
