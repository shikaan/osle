#include "../sdk/osle.h"

static const char *VERSION = "\n\rOSle - https://github.com/shikaan/osle";
static const char *BUILTINS = "\n\rBuiltins:\n\r  - ls: list all files and commands\n\r  - cl: clear the screen";
static const char *PROGRAMS = "\n\rPrograms:";
static const char *PROGRAM_LIST[] = {
    "  - ed <text-file>: open a text editor",
    "  - help: show this help",
    "  - more <text-file>: preview the content of a file",
    "  - mv <source-path> <destination-path>: move file from source to destination",
    "  - rm <file-path>: delete a file",
    "  - touch <file-path>: create a file",
    "  - tetris: launch a tetris game",
    "  - echo <arguments>: It writes the arguments you type to the console."
};
static const char *INFO = "\n\rFor any feedack please refer to \n\rhttps://github.com/shikaan/osle/issues";

static void done(void) {
  puts("\n\rPress any key to return");
  (void)getc();
  exit();
}

int main(int argc, char **argv) {
    putl(VERSION);
    putl(BUILTINS);
    putl(PROGRAMS);

    int i = 0;
    for (i = 0; i < ARRAY_SIZE(PROGRAM_LIST); i++) {
        putl(PROGRAM_LIST[i]);
    }

    putl(INFO);

    done();
}
