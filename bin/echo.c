#include "../sdk/osle.h"

static void done(void) {
  putl("Press any key to continue...");
  (void)getc();
  exit();
}

int main(int argc, char **argv) {
  int i;

  for (i = 0; i < argc; i++) {
    puts(argv[i]);
    putc(' ');
  }
  putc('\n');
  putc('\r');

  done();
}
