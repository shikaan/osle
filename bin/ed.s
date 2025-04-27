%include "sdk/osle.inc"
%include "sdk/bochs.inc"

bits 16

mov ax, 0x0003
int 0x10

mov di, PM_ARGS         ; try reading the file passed as argument, if any
call open_file
jnc initial_render

mov si, NEW_FILE        ; write the default file name in the current file buffer
mov cx, NEW_FILE_LEN
mov di, FILE_BUFFER
repe movsb

initial_render:
  call render

  mov dx, CURSOR_INIT
  call set_cursor

wait_for_key:
  xor ax, ax
  int 0x16

  call arrow
  jc wait_for_key

  call control_key
  jc wait_for_key

  call is_printable
  jne wait_for_key

  call insert_char
  call render
  call arrow.right
  jmp wait_for_key

; arrow(ax: u16 input, dh: line, dl: column)
; Sets carry flag if input is handled
arrow:
  push ax
    call get_cursor
  pop ax
  cmp ax, 0x4B00
  je .left
  cmp ax, 0x4D00
  je .right
  cmp ax, 0x4800
  je .up
  cmp ax, 0x5000
  je .down
  clc
  ret

.left:
  cmp dl, 0
  je .handled                       ; don't move left if start of line
  dec dl
  jmp .update

.right:
  movzx bx, dh
  cmp dl, byte [line_length + bx]
  jae .handled                       ; don't move right if end of line

  inc dl
  jmp .update

.up:
  cmp dh, 1
  je .handled
  dec dh
  call clamp_to_line
  jmp .update

.down:
  cmp dh, MAX_ROWS-1
  je .handled

  movzx bx, dh
  inc bx
  cmp byte [line_length + bx], 0
  je .handled                       ; if next line is empty, don't go down

  inc dh
  call clamp_to_line
  jmp .update

.update:
  call set_cursor
.handled:
  stc
  ret

; arrow(ax: u16 input, dh: line, dl: column)
; Handles control keys. Sets carry flag if input is handled
control_key:
  cmp ax, 0x0e08  ; backspace
  je .backspace
  cmp ax, 0x1c0D  ; enter
  je .return
  cmp ax, 0x0f09  ; tab
  je .handled
  cmp ax, 0x1F13  ; Ctrl+S
  je .save
  cmp ax, 0x1011  ; Ctrl+Q
  je .quit
  clc
  ret

.save:
  call save_file
  jc .save_error
  jmp .save_success

.save_error:
  mov si, NOTIFICATION_SAVE_ERROR
  mov cx, NOTIFICATION_SAVE_ERROR_LEN
  call render_notification
  jmp .save_done

.save_success:
  mov si, NOTIFICATION_SAVED
  mov cx, NOTIFICATION_SAVED_LEN
  call render_notification
  jmp .save_done

.save_done:
  call render_header                                  ; remove * from header
  jmp .handled

.quit:
  int 0x20
  jmp .handled

.backspace:
  cmp dl, 0
  je .handled

  call get_buffer_position
  mov bx, ax
  sub bx, 2
  mov ax, word [FILE_BUFFER + FILE_HEADER_SIZE + bx]  ; if removing CRLF, remove
  cmp ax, CRLF                                        ; both bytes
  jne .delete_once                                    ; else just delete once

  call delete_char
  call arrow.left

.delete_once:
  call delete_char
  call arrow.left

  call render
  jmp .handled

.return:
  cmp dh, MAX_ROWS-1
  je .handled
  mov al, 0x0D
  call insert_char
  mov al, 0x0A
  call insert_char
  call render
  inc dh
  mov dl, 0
  call set_cursor
  ; cascades

.handled:
  stc
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

; print_char(al: u8)
; Prints printable characters plus carriage return, line feed, and null byte.
print_char:
  pusha
    cmp al, 0x0D
    je .print
    cmp al, 0x0A
    je .print
    cmp al, 0x00
    je .null

    call is_printable
    je .print
    jmp .done

.null:
    mov al, 0XFE
    jmp .print

.print:
    mov ah, 0x0e
    xor bh, bh
    int 0x10
.done:
  popa
  ret

; print_byte_inverted(al: u8)
; Prints any character, regardless if they're printable, with inverted colors
; (black on white).
print_byte_inverted:
  pusha
    mov ah, 0x09      ; write character interrupt function
    mov cx, 1
    xor bh, bh
    mov bl, 0x70      ; this means black on white
    int 0x10
    call get_cursor   ; we cannot use tty here (it doesn't support background),
    inc dl            ;    we need to advance the cursor manually
    call set_cursor
  popa
  ret

; insert_char(al: u8 char, dh: line, dl: column)
; Insert the char in al at the cursor position, moving the buffer around it.
insert_char:
  push ax
    call get_buffer_position
    mov di, ax
  pop ax
  push di
    call push_right
  pop di
  mov byte [FILE_BUFFER + FILE_HEADER_SIZE + di], al

  movzx bx, dh
  inc word [file_data_len]
  ret

; delete_char(dh: line, dl: column)
; Deletes the char at the cursor position, moving the buffer around it.
delete_char:
  call get_buffer_position
  mov di, ax
  call shift_left
  movzx bx, dh
  dec word [file_data_len]
  ret

; push_right(di: u16 logical_position)
; Pushes the file buffer right from a given logical position
;      buf: 11 22 33 44, di: 1
;   becomes
;     11 22 22 33 44
push_right:
  mov bx, MAX_LEN - 1
  mov cx, bx
  sub cx, di
  inc cx
  lea si, [FILE_BUFFER + FILE_HEADER_SIZE + bx]
  lea di, [FILE_BUFFER + FILE_HEADER_SIZE + bx + 1]
  std
  repe movsb
  cld
  mov byte [modified], 1
  ret

; shift_left(di: u16 logical_position)
; Shifts the file buffer left from a given logical position
;      buf: 11 22 33 44, di: 1
;   becomes
;     11 33 44
shift_left:
  mov bx, di
  dec bx
  mov cx, MAX_LEN
  sub cx, bx
  lea si, [FILE_BUFFER + FILE_HEADER_SIZE + bx + 1]
  lea di, [FILE_BUFFER + FILE_HEADER_SIZE + bx]
  cld
  repe movsb
  mov byte [modified], 1
  ret

; get_buffer_position(dh: line, dl: column)
; Takes a visual cursor position and returns its logical position in the buffer
; The calculation is: pos = sum(length of lines before current) + cursor
get_buffer_position:
  xor ax, ax                        ; ax will be the position in the buffer
  movzx bx, dh
  cmp dh, 1
  jbe .current_line                 ; no sum of previous lines, if is first
  movzx cx, dh                      ; repeat dh times
  dec bx                            ; previous lines, not current
.sum_loop:
  add al, byte [line_length + bx]
  dec bx
  loop .sum_loop
.current_line:
  add al, dl
  ret

; get_cursor() -> (dh: line, dl: column)
; Returns current visual cursor position
get_cursor:
  mov ah, 0x03
  xor bh, bh
  int 0x10
  ret

; set_cursor(dh: line, dl: column)
; Sets visual cursor position
set_cursor:
  mov ah, 0x02      ; Set cursor position function
  xor bh, bh        ; Page number = 0
  int 0x10
  ret

; clamp_to_line(dh: line, dl: column)
; Clamps cursor coordinates within the current line. Does not update the cursor!
clamp_to_line:
  push bx
    movzx bx, dh
    cmp dl, byte [line_length + bx]
    jbe .done
    mov dl, byte [line_length + bx]
.done:
  pop bx
  ret

; render(void)
; Clears the screen, prints the headline, displays the buffer, recalculates line
; lengths, and returns.
render:
  call clear_screen
  call render_header
  call render_footer
  call print_buffer
  call recalculate_line_lengths
  ret

; clear(void)
; Issues the interrupt to clear the screen
clear_screen:
  pusha
    mov ax, 0x0600
    xor cx, cx
    mov dx, 0x184F
    mov bh, 0x07
    int 0x10
  popa
  ret

; print_buffer(void)
; Prints the entire buffer on screen, saving the cursor position.
print_buffer:
  call get_cursor
  push dx
    mov dx, CURSOR_INIT
    call set_cursor
    lea si, [FILE_BUFFER + FILE_HEADER_SIZE]
    mov cx, [file_data_len]
    inc cx                          ; null terminate printing
.loop:
    mov al, byte [si]
    call print_char
    inc si
    loop .loop
  pop dx
  call set_cursor
  ret

; recalculate_line_lengths(void)
; Recalculates the line lengths in the buffer which might have changed as a
; result of adding or removing chars
recalculate_line_lengths:
  pusha
    mov di, 1                         ; line index
    mov bx, 0                         ; buffer index
    mov dl, 0                         ; column index (index on a line)
    mov cx, [file_data_len]
    cmp cx, 0
    je .done
.loop:
    mov ax, word [FILE_BUFFER + FILE_HEADER_SIZE + bx]
    cmp ax, CRLF
    je .new_line
    inc bx
    inc dl
    jmp .continue
.new_line:
    add dl, 2                         ; account for crlf in column index
    add bx, 2                         ; account for crlf in buffer index
    dec cx                            ; account for cflf in the loop counter
    mov byte [line_length + di], dl
    inc di
    mov dx, 0
    ; cascade
.continue:
    loop .loop
    mov byte [line_length + di], dl
.done:
  popa
  ret

; open_file(di: u8* filename)
; Opens a file with a given name in the current buffer. Sets carry on failure.
open_file:
  mov bx, FILE_BUFFER
  int INT_FS_FIND
  jc .done

  mov byte [open_file_handle], al   ; store file handle
  mov ax, [bx + FS_SIZE_OFFSET]
  mov word [file_data_len], ax      ; store file size
.done:
  ret

; save_file(di: u8* filename)
; Saves the current buffer to a file with specified name. If missing, the file
; will be created. Sets carry on failure.
save_file:
  cmp byte [open_file_handle], 0              ; handle is zero only if no file
  jne .save                                   ;   is open - create a file then

.create_file_and_update_content:
  lea si, [FILE_BUFFER + FS_DATA_OFFSET]      ; copy current buffer in a temp
  mov di, TMP_BUFFER                          ;   area to safely open a new file
  mov cx, word [file_data_len]
  repe movsb

  mov di, NEW_FILE                            ; create a new file and load it in
  mov bx, FILE_BUFFER                         ;   the file buffer location
  int INT_FS_CREATE
  jc .done

  mov byte [open_file_handle], al             ; copy data from the temp buffer
  mov si, TMP_BUFFER                          ;   into the file buffer location
  lea di, [FILE_BUFFER + FS_DATA_OFFSET]
  mov cx, word [file_data_len]
  repe movsb
.save:
  mov ax, word [file_data_len]                ; update file size
  mov word [FILE_BUFFER + FS_SIZE_OFFSET], ax

  mov bx, FILE_BUFFER                         ; write file on disk
  mov dl, byte [open_file_handle]
  int INT_FS_WRITE
  jnc .done
  mov byte [modified], 0                      ; unset modified flag on success
.done:
  ret

; render_header(void)
; Renders the top bar of the editor where name, file, and modified flag are.
render_header:
  call get_cursor
  push dx                     ; save cursor to restore it at the end
    xor dx, dx
    call set_cursor

    mov cx, MAX_COLS          ; print a full line of inverted null-bytes to make
    mov al, 0                 ;   a white line
.print_background:
    call print_byte_inverted
    loop .print_background

    mov dx, HEADER_POSITION   ; reposition cursor to header text start
    call set_cursor

    mov si, NAME              ; print this programs name and version
    mov cx, NAME_LEN
.print_program_name:
    mov al, byte [si]
    call print_byte_inverted
    inc si
    loop .print_program_name

    xor bx, bx                ; calculate length of the file name to render it
    mov cx, FS_PATH_SIZE
    lea si, [FILE_BUFFER + FS_PATH_OFFSET]
.calculate_name_length
    lodsb
    test al, al
    je .done_calculate_name_length
    inc bx
    loop .calculate_name_length

.done_calculate_name_length:
    push bx
      shr bl, 1                 ; move the cursor in the middle of the bar
      mov dl, MAX_COLS/2
      sub dl, bl
      call set_cursor
    pop cx
    lea si, [FILE_BUFFER + FS_PATH_OFFSET]  ; prints the filename
.print_filename:
    lodsb
    call print_byte_inverted
    loop .print_filename

    cmp byte [modified], 0      ; signal modified file (i.e., changed but not
    je .done                    ;   saved on disk) with an * next to the name
    mov al, '*'

    call print_byte_inverted
.done:
  pop dx
  call set_cursor
  ret

; render_footer(void)
; Renders the footer of the editor where instructions are printed.
render_footer:
  call get_cursor
  push dx                     ; save cursor to restore it at the end
    mov dx, FOOTER_POSITION
    call set_cursor           ; position cursor on line 24/18h (bottom line)

    mov si, INSTRUCTIONS
    mov cx, INSTRUCTIONS_LEN
    xor bx, bx                ; when bx = 1 we print black on white (invert),
.print_instructions:          ;   else usual white on black
    mov al, byte [si]

    cmp al, '['               ; chars in [] will be inverted
    je .set_invert            ;   [ starts inverting, ] ends inverting
    cmp al, ']'
    je .unset_invert

    cmp bx, 1                 ; print inverted or normal based on bx
    je .inverted_print
    call print_char
    jmp .continue

.inverted_print:
    call print_byte_inverted
    jmp .continue

.unset_invert:
    xor bx, bx
    jmp .continue

.set_invert:
    mov bx, 1
    ; cascades

.continue:
    inc si
    loop .print_instructions

.done:
  pop dx
  call set_cursor
  ret

; render_notification(si: u8* message, cl: u8 message_len)
; Renders a notification in the notification area. Notifications will disappear
; on the next re-render.
render_notification:
  mov bx, cx
  call get_cursor                   ; save cx and copy it in bx to modify it
  mov cx, bx
  push dx
    mov dx, NOTIFICATION_POSITION
    shr bl, 1                       ; divide string len by two
    mov dl, MAX_COLS/2
    sub dl, bl                      ; to print in the middle, start typing at
    call set_cursor                 ;     pos = MAX_COLS/2 - str.len/2
.print_message:
    lodsb
    call print_char
    loop .print_message
  pop dx
  call set_cursor
  ret

NAME:                   db "ed v0.0.1", 0
NAME_LEN                equ $-NAME

INSTRUCTIONS:           db "          [^S] Save                      "
                        db "                      [^Q] Quit          "
INSTRUCTIONS_LEN        equ $-INSTRUCTIONS

NEW_FILE:               db "new.txt",0
NEW_FILE_LEN            equ $-NEW_FILE

NOTIFICATION_SAVED      db "[ File saved ]"
NOTIFICATION_SAVED_LEN  equ $-NOTIFICATION_SAVED

NOTIFICATION_SAVE_ERROR      db "[ ERROR unable to save ]"
NOTIFICATION_SAVE_ERROR_LEN  equ $-NOTIFICATION_SAVE_ERROR

MAX_ROWS              equ 23
MAX_COLS              equ 80
MAX_LEN               equ MAX_COLS * MAX_ROWS
FILE_HEADER_SIZE      equ 24
FILE_BUFFER           equ 0x9000
TMP_BUFFER            equ 0x7000
CURSOR_INIT           equ 0x0100
CRLF                  equ 0x0D0A
HEADER_POSITION       equ 0x0002  ; first line, third column
FOOTER_POSITION       equ 0x1800  ; last line, third column
NOTIFICATION_POSITION equ 0x1700  ; last but one line, first column

open_file_handle      db 0x00               ; file handle of currently open file
file_data_len         dw 0x0000             ; length of current file
modified              db 0x00               ; it is 1 when the current file has
                                            ;   changed but it's not saved yet
line_length           times MAX_ROWS db 0   ; tracks the length of the lines in
                                            ;   the buffer

; vim: ft=nasm tw=80 cc=+0 commentstring=;\ %s
