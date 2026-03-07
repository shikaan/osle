#include "../sdk/osle.h"

typedef enum {
  BLOCK_I,
  BLOCK_L,
  BLOCK_J,
  BLOCK_T,
  BLOCK_S,
  BLOCK_Z,
  BLOCK_O,
  BLOCKS
} block_t;

// Character used to render a full cell in the grid
#define FULL 0xDB
// Character used to render an empty cell in the grid
#define EMPTY 0xB0
// Number of rows in the grid
#define ROWS 32
// Number of cols in the grid
#define COLS 16
// Number of possible orientations (up, right, down, left)
#define ORIS 4
// Position of the grid on the screen
#define GX 4
#define GY 32

// The game grid where all the fallen blocks are stored
static word_t grid[ROWS] = {};
// Falling tetromino state
static byte_t row = 0, col = 0, score = 0, ori = 0;
static block_t type = BLOCK_I;

// 4x4 bitmaps encoding all the possible blocks in all rotations
static word_t shapes[BLOCKS][ORIS] = {
    {0b1111000000000000, 0b1000100010001000, 0b1111000000000000,
     0b1000100010001000},
    {0b1000100011000000, 0b1110100000000000, 0b1100010001000000,
     0b0010111000000000},
    {0b0100010011000000, 0b1000111000000000, 0b1100100010000000,
     0b1110001000000000},
    {0b1110010000000000, 0b0100110001000000, 0b0100111000000000,
     0b1000110010000000},
    {0b0110110000000000, 0b1000110001000000, 0b0110110000000000,
     0b1000110001000000},
    {0b1100011000000000, 0b0100110010000000, 0b1100011000000000,
     0b0100110010000000},
    {0b1100110000000000, 0b1100110000000000, 0b1100110000000000,
     0b1100110000000000},
};

// Puts a character directy in VGA memory without using hardware cursor.
// Used to prevent flickering
static void vput(byte_t r, byte_t c, byte_t ch) {
  word_t off = (r * 80 + c) * 2;
  __asm__ volatile("pushw %%es\n"
                   "mov $0xB800, %%ax\n"
                   "mov %%ax, %%es\n"
                   "movb %[ch], %%es:(%[off])\n"
                   "popw %%es\n"
                   :
                   : [off] "D"(off), [ch] "q"(ch)
                   : "ax", "memory");
}

// Reads the keyboard buffer. Returns a byte_t if a key is pressed, else -1.
static int key(void) {
  int ax = -1;
  __asm__ volatile("mov $0x01, %%ah\n"
                   "int $0x16\n"
                   "jz done\n"
                   "mov $0x00, %%ah\n"
                   "int $0x16\n"
                   "done:"
                   : "=a"(ax)
                   :
                   :);
  return ax;
}

// Returns the number of clock ticks since midnight

// Makes the terminal cells square - makes the game look nicer
static void sqfont(void) {
  __asm__ volatile("mov $0x1112, %%ax\n"
                   "xor %%bl, %%bl\n"
                   "int $0x10"
                   :
                   :
                   : "ax", "bx");
}

// Waits for the screen vertical retrace. Used to debounce draw calls and not
// cause flickering.
static void vsync(void) {
  __asm__ volatile("mov $0x3DA, %%dx\n"
                   "wait_end: in %%dx, %%al\n"
                   "test $0x08, %%al\n"
                   "jnz wait_end\n"
                   "wait_start: in %%dx, %%al\n"
                   "test $0x08, %%al\n"
                   "jz wait_start\n"
                   :
                   :
                   : "ax", "dx");
}

// Returns true if there is a collision between the falling block and the grid
static int hit(byte_t r, byte_t c) {
  word_t s = shapes[type][ori];

  for (byte_t i = 0; i < 4; i++) {
    for (byte_t j = 0; j < 4; j++) {
      if (s & 0x8000) {
        byte_t gr = r + i;
        byte_t gc = c + j;
        if (gr >= ROWS || gc >= COLS || grid[gr] & (1 << gc))
          return 1;
      }
      s <<= 1;
    }
  }
  return 0;
}

// Adds a falling block to the grid
static void lock(byte_t r, byte_t c) {
  word_t s = shapes[type][ori];

  for (byte_t i = 0; i < 4; i++) {
    for (byte_t j = 0; j < 4; j++) {
      if (s & 0x8000)
        grid[r + i] |= (1 << (c + j));
      s <<= 1;
    }
  }
}

// Clean up filled lines and increases the score
static void sweep(void) {
  byte_t n = 0;
  for (int i = ROWS - 1; i >= 0; i--) {
    if (grid[i] == 0xFFFF) {
      n++;
      for (int j = i; j > 0; j--)
        grid[j] = grid[j - 1];
      grid[0] = 0;
      i++;
    }
  }
  score += n * (n + 1) / 2;
}

// Spawns a new block at the top of the screen
static void spawn(void) {
  row = 0;
  col = 6;
  type = ticks() % BLOCKS;
  ori = 0;
}

// Draws a game frame
static void render(void) {
  word_t mask[ROWS] = {};
  word_t s = shapes[type][ori];

  for (byte_t i = 0; i < 4; i++) {
    for (byte_t j = 0; j < 4; j++) {
      if (s & 0x8000)
        mask[row + i] |= (1 << (col + j));
      s <<= 1;
    }
  }

  vsync();

  // NOTE: This part is full of magic numbers used to make the UI look nicer.
  //       Handle with extreme care!
  const char *title = "TETRIS    v1.0";
  for (byte_t i = 0; title[i]; i++)
    vput(1, 33 + i, title[i]);

  for (byte_t i = 0; i < ROWS; i++) {
    word_t r = grid[i] | mask[i];
    for (byte_t j = 0; j < COLS; j++)
      vput(GX + i, GY + j, r & (1 << j) ? FULL : EMPTY);
  }

  const char *lbl = "Score: ";
  for (byte_t i = 0; lbl[i]; i++)
    vput(GX + ROWS + 2, GY + i + 1, lbl[i]);

  int sc = score;
  for (int i = 6; i >= 0; i--) {
    vput(GX + ROWS + 2, GY + 7 + i + 1, '0' + (sc % 10));
    sc /= 10;
  }

  const char *ctrl = "Controls:";
  for (byte_t i = 0; ctrl[i]; i++)
    vput(GX + ROWS + 4, GY + i + 1, ctrl[i]);

  const char *keys[] = {"  W: rotate", "  A: left  ", "  S: down  ",
                        "  D: right ", "  Q: quit  "};
  for (byte_t i = 0; i < 5; i++)
    for (byte_t j = 0; keys[i][j]; j++)
      vput(GX + ROWS + 6 + i, GY + 1 + j, keys[i][j]);
}

// Wait and handle keyboard input
static void input(void) {
  int k = key();
  if (k < 0)
    return;

  char c = (char)(k & 0xFF);

  if (c == 'a' && col > 0 && !hit(row, col - 1))
    col--;
  if (c == 'd' && !hit(row, col + 1))
    col++;
  if (c == 's' && !hit(row + 1, col))
    row++;
  if (c == 'w') {
    byte_t old = ori;
    ori = (ori + 1) % ORIS;
    if (hit(row, col))
      ori = old;
  }
  if (c == 'q')
    exit();

  render();
}

int main(int argc, char **argv) {
  cls();
  sqfont();
  spawn();

  word_t prevtick = ticks();
  while (1) {
    input();

    word_t currtick = ticks();

    // Unscientific way of making the game progression feel better
    word_t speed = score / 3 < 4 ? 6 - score / 3 : 2;
    if (currtick - prevtick > speed) {
      if (hit(row + 1, col)) {
        lock(row, col);
        sweep();
        spawn();

        // Whenever a new block cannot be spawned (i.e., spawns but is already
        // colliding, the game is over)
        if (hit(row, col)) {
          cls();
          putl("Game over! Press any key to quit.");
          (void)getc();
          exit();
        }
      } else {
        row++;
      }
      prevtick = currtick;
      render();
    }
    sleep(33333);
  }

  return 0;
}
