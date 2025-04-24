; This file includes utility macros to work with bochs

; Allows using the magic breakpoin with the debugger keyword.
;
; Usage:
;   add ax, 1
;   debugger
;   sub ax, 1
;
%macro debugger 0
  xchg bx,bx
%endmacro