// Welcome to the optional GUI tutorial step!
//
// This example shows how to use the separated GUI library in BIOS mode.
// It draws a simple panel in VGA mode 13h and returns to text mode.

#include "../../sdk/osle.h"
#include "../../sdk/gui.h"

static void done(void) {
  gui_text_mode();
  putl("Press any key to return");
  (void)getc();
  exit();
}

int main(int argc, char **argv) {
  (void)argc;
  (void)argv;

  gui_mode13();

  // Background
  gui_fill_rect(0, 0, 320, 200, 1);

  // Window
  gui_fill_rect(28, 20, 264, 160, 8);
  gui_fill_rect(32, 24, 256, 152, 7);
  gui_frame(32, 24, 256, 152, 15);

  // Header and buttons
  gui_fill_rect(32, 24, 256, 18, 3);
  gui_frame(32, 24, 256, 18, 15);

  gui_fill_rect(54, 132, 90, 30, 2);
  gui_frame(54, 132, 90, 30, 15);
  gui_fill_rect(176, 132, 90, 30, 4);
  gui_frame(176, 132, 90, 30, 15);

  (void)getc();
  done();
}
