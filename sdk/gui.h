#ifndef GUI_H
#define GUI_H

#include "osle.h"

// ==== BIOS GUI PRIMITIVES (NO EXTERNAL LIBS) ====
//
// These helpers use direct VGA memory access and are safe for
// real-mode/boot-sector style environments.

// Switches to VGA 320x200x256 mode (Mode 13h).
static void gui_mode13(void) {
  __asm__ volatile("mov $0x0013, %%ax\n"
                   "int $0x10"
                   :
                   :
                   : "ax", "cc");
}

// Returns to 80x25 text mode (Mode 03h).
static void gui_text_mode(void) {
  __asm__ volatile("mov $0x0003, %%ax\n"
                   "int $0x10"
                   :
                   :
                   : "ax", "cc");
}

// Draws one pixel in Mode 13h.
static void gui_pixel(word_t x, word_t y, byte_t color) {
  if (x >= 320 || y >= 200)
    return;

  word_t off = y * 320 + x;
  __asm__ volatile("pushw %%es\n"
                   "movw $0xA000, %%dx\n"
                   "movw %%dx, %%es\n"
                   "movw %[off], %%di\n"
                   "movb %[color], %%al\n"
                   "stosb\n"
                   "popw %%es\n"
                   :
                   : [off] "rm"(off), [color] "rm"(color)
                   : "ax", "dx", "di", "memory", "cc");
}

// Fills a rectangle in Mode 13h.
static void gui_fill_rect(word_t x, word_t y, word_t w, word_t h,
                          byte_t color) {
  word_t yy_end = y + h;
  word_t xx_end = x + w;

  if (x >= 320 || y >= 200)
    return;
  if (xx_end > 320)
    xx_end = 320;
  if (yy_end > 200)
    yy_end = 200;

  word_t span = xx_end - x;
  word_t off = y * 320 + x;
  word_t rows = yy_end - y;

  for (word_t yy = 0; yy < rows; yy++) {
    __asm__ volatile("pushw %%es\n"
                     "movw $0xA000, %%dx\n"
                     "movw %%dx, %%es\n"
                     "movw %[off], %%di\n"
                     "movw %[count], %%cx\n"
                     "movb %[color], %%al\n"
                     "cld\n"
                     "rep stosb\n"
                     "popw %%es\n"
                     :
                     : [off] "rm"(off), [count] "rm"(span), [color] "rm"(color)
                     : "ax", "cx", "dx", "di", "memory", "cc");
    off += 320;
  }
}

// Draws a 1px frame in Mode 13h.
static void gui_frame(word_t x, word_t y, word_t w, word_t h, byte_t color) {
  if (!w || !h)
    return;

  gui_fill_rect(x, y, w, 1, color);
  if (h > 1)
    gui_fill_rect(x, y + h - 1, w, 1, color);
  if (h > 2) {
    gui_fill_rect(x, y + 1, 1, h - 2, color);
    if (w > 1)
      gui_fill_rect(x + w - 1, y + 1, 1, h - 2, color);
  }
}

#endif
