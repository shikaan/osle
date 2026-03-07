#include "../sdk/osle.h"

static file_t file;
static handle_t handle;

static void done(void) {
  putl("Press any key to continue...");
  (void)getc();
  exit();
}

static void error(const char *msg) {
  putl(msg);
  done();
}

static void usage(void) {
  putl("Usage: touch [FILE]");
  done();
}

int main(int argc, char **argv) {
  if (argc != 1) {
    error("Missing file name.");
  }

  char *filename = argv[0];

  if (0 != create(filename, &handle, &file)) {
    error("Unable to create file.");
  }

  puts("File ");
  putsn(filename, FS_PATH_SIZE);
  putl(" created successfully.");

  done();
}
