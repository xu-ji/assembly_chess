#include<stdio.h>
#include<stdint.h>
#include<string.h>
#include<stdlib.h>
#include<assert.h>

typedef uint8_t bool_t;
typedef uint8_t byte_t;
typedef int8_t signed_byte_t;

#define FALSE 0
#define TRUE 1

#define BOARD_SIZE (8*8)
#define BOARD_ROW 8
#define BOARD_COL 8

#define PIECE_S 0 // piece space
#define PIECE_P 1 // piece pawn
#define PIECE_H 2 // piece knight(horse)
#define PIECE_B 3 // piece bishop
#define PIECE_R 4 // piece rook
#define PIECE_Q 5 // piece queen
#define PIECE_K 6 // piece king

#define BYTE_UNDEFINED 0xFF

bool_t cur_player; // 0 = white player // 1 = black player
bool_t has_selected; // has current player select a piece.
bool_t is_clicked; // is user click on this iteration

byte_t en_passant_flag; // capture col of the pawn that move 2 block last turn
byte_t castle_flag; // remember that have each rook and king ever moved before
       // bit 0 = white_rook_left, 4 = white_king, 1 = white_rook_right
       // bit 2 = black_rook_left, 5 = black_king, 3 = black_rook_right

byte_t selected_pos; // if has_selected then it is position of selected piece
byte_t current_pos; // position of current click

byte_t* cells_type; // must be one of PIECE_?
bool_t* are_marked; // is this cell legal to move by selected piece
bool_t* cells_side; // 0 = fst player side // 1 = snd player side
        // if cells_type[i] = PIECE_S then cells_side[i] is meaningless

void display();
void manage_input();
byte_t promote_pawn();
void game_over();
void initialise();
bool_t is_game_over(bool_t player_id);
void process();
bool_t is_in_check(bool_t player_id, byte_t src_pos, byte_t des_pos);
bool_t legal_move(byte_t src_pos, byte_t des_pos, bool_t update);
bool_t is_own_piece(byte_t target_pos);
bool_t is_path_clear(byte_t src_pos, byte_t des_pos
  , bool_t enable_horizontal_vertical, bool_t enable_digonal);
void actual_move(byte_t src_pos, byte_t des_pos);
byte_t to_pos(byte_t row, byte_t col);
byte_t absolute(signed_byte_t number);

int main() {
  while(1) {
    initialise();
    while(!is_game_over(cur_player)) {
      display();
      manage_input();
      if(is_clicked)
        process();
    }
    display();
    game_over();
  }
}

//--------------------------------- I/O part ---------------------------------//
void display() {
  const byte_t CELL_ROW = 6;
  const byte_t CELL_COL = 14;

  char img[7][5][10] = {{"         "
                        ,"         "
                        ,"         "
                        ,"         "
                        ,"         "}

                       ,{"         "
                        ,"         "
                        ,"         "
                        ,"  @@@@@  "
                        ,"  @@@@@  "}

                       ,{"  @@@@@  "
                        ," @@   @@ "
                        ," @@   @@ "
                        ,"     @@  "
                        ," @@@@@@@ "}

                       ,{"    @    "
                        ,"  @@ @@  "
                        ,"   @@@   "
                        ,"    @    "
                        ," @@@@@@@ "}

                       ,{"@@ @@@ @@"
                        ,"@@@@@@@@@"
                        ,"   @@@   "
                        ,"   @@@   "
                        ," @@@@@@@ "}

                       ,{"@@ @@@ @@"
                        ,"@@ @@@ @@"
                        ,"@@ @@@ @@"
                        ," @@@@@@@ "
                        ," @@@@@@@ "}

                       ,{"@   @   @"
                        ,"@ @@@@@ @"
                        ,"@   @   @"
                        ," @@@@@@@ "
                        ," @@@@@@@ "}};

  signed_byte_t cur_row = current_pos / BOARD_COL;
  signed_byte_t cur_col = current_pos % BOARD_COL;
  signed_byte_t iter_row;
  signed_byte_t iter_col;
  byte_t iter_pos;
  printf("cur_player   == %s\n",cur_player ? "TRUE" : "FALSE");
  printf("has_selected == %s\n",has_selected ? "TRUE" : "FALSE");
  printf("is_clicked   == %s\n",is_clicked ? "TRUE" : "FALSE");
  printf("selected_pos == (%d,%d);\n"
      ,selected_pos/BOARD_COL,selected_pos%BOARD_COL);
  printf("current_pos  == (%d,%d);\n"
      ,current_pos/BOARD_COL,current_pos%BOARD_COL);
  printf("en_paasant_flag  == %d;\n",en_passant_flag);
  printf("castle_flag      == %d;\n",castle_flag);
  for(int i=BOARD_ROW*CELL_ROW+1-1;i>=0;i--,putchar('\n'))
    for(int j=0;j<BOARD_COL*CELL_COL+1;j++) {
      iter_row = i/CELL_ROW;
      iter_col = j/CELL_COL;
      iter_pos = to_pos(iter_row,iter_col);
      if(!(i%CELL_ROW) && !(j%CELL_COL))
        putchar('+');
      else if(!(i%CELL_ROW)) {
        if((iter_row == cur_row || iter_row == cur_row + 1)
          && iter_col == cur_col)
          putchar(has_selected ? '#' : '@');
        else if(j%2)
          putchar(' ');
        else
          putchar('-');
      }
      else if(!(j%CELL_COL)) {
        if((iter_col == cur_col || iter_col == cur_col + 1)
          && iter_row == cur_row)
          putchar(has_selected ? '#' : '@');
        else if(i%2)
          putchar(' ');
        else
          putchar('|');
      }
      else if(!((j+1)%CELL_COL) || !((j-1+CELL_COL)%CELL_COL)
           || !((j+2)%CELL_COL) || !((j-2+CELL_COL)%CELL_COL)) {
        if(iter_pos == current_pos)
          putchar(has_selected ? '#' : '@');
        else if(iter_pos == selected_pos)
          putchar('*');
        else if(are_marked[iter_pos])
          putchar('$');
        else
          putchar(' ');
      }
      else {
        if(img[cells_type[iter_pos]][CELL_ROW-i%CELL_ROW-1][j%CELL_COL-3]==' ')
          putchar(' ');
        else if(cells_side[iter_pos])
          putchar('O');
        else
          putchar('X');
      }
    }
}
void manage_input() {
  char input[2];
  signed_byte_t cur_row = current_pos / BOARD_COL;
  signed_byte_t cur_col = current_pos % BOARD_COL;
  is_clicked = FALSE;
  printf("Get input (aswd for direction, f for click) : ");
  scanf("%s",input);
  switch(input[0]) {
    case 'a': cur_col = (cur_col-1+BOARD_COL)%BOARD_COL; break;
    case 'd': cur_col = (cur_col+1+BOARD_COL)%BOARD_COL; break;
    case 's': cur_row = (cur_row-1+BOARD_ROW)%BOARD_ROW; break;
    case 'w': cur_row = (cur_row+1+BOARD_ROW)%BOARD_ROW; break;
    case 'f': is_clicked = TRUE;                         break;
    default : fprintf(stderr,"cannot recognise the input"); break;
  }
  current_pos = to_pos(cur_row,cur_col);
}
byte_t promote_pawn() {
  char input[2];
  printf("The current pawn is promoting... \n");
  printf("Which type that you want your pawn to be... \n");
  printf("a(knight) s(bishop) d(rook) w(queen) : ");
  scanf("%s",input);
  switch(input[0]) {
    case 'a': return PIECE_H;
    case 'd': return PIECE_B;
    case 'w': return PIECE_R;
    case 's': return PIECE_Q;
  }
  fprintf(stderr,"cannot recognise the input");
  return -1;
}
void game_over() {
  if(is_in_check(cur_player,current_pos,current_pos)) {
    printf("\n\n");
    printf("*****************************\n");
    printf("* Game Over Player %c win. *\n",!cur_player ? 'X' : 'O');
    printf("*****************************\n");
    printf("\n\n\n\n\n");
  } else {
    printf("\n\n");
    printf("***********************\n");
    printf("* Game Over Stalemate *\n");
    printf("***********************\n");
    printf("\n\n\n\n\n");
  }
}
//----------------------------------------------------------------------------//

void initialise() {
  cur_player = FALSE; // set to first player
  has_selected = FALSE; // now on hover state
  is_clicked = FALSE;

  en_passant_flag = BYTE_UNDEFINED; // no pawn has moved
  castle_flag = 0x00; // no rook nor king have moved

  selected_pos = BYTE_UNDEFINED; // undefined by now
  current_pos = BOARD_SIZE/2 + BOARD_COL/2; // at middle of board

  cells_type = (byte_t*)malloc(BOARD_SIZE*sizeof(byte_t));
  assert(cells_type != NULL);
  memset(cells_type,PIECE_S,BOARD_SIZE);
  memset(cells_type+(2-1)*BOARD_COL,PIECE_P,BOARD_COL);
  memset(cells_type+(7-1)*BOARD_COL,PIECE_P,BOARD_COL);
  cells_type[0] = cells_type[BOARD_SIZE-BOARD_COL+0] = PIECE_R;
  cells_type[1] = cells_type[BOARD_SIZE-BOARD_COL+1] = PIECE_H;
  cells_type[2] = cells_type[BOARD_SIZE-BOARD_COL+2] = PIECE_B;
  cells_type[3] = cells_type[BOARD_SIZE-BOARD_COL+3] = PIECE_Q;
  cells_type[4] = cells_type[BOARD_SIZE-BOARD_COL+4] = PIECE_K;
  cells_type[5] = cells_type[BOARD_SIZE-BOARD_COL+5] = PIECE_B;
  cells_type[6] = cells_type[BOARD_SIZE-BOARD_COL+6] = PIECE_H;
  cells_type[7] = cells_type[BOARD_SIZE-BOARD_COL+7] = PIECE_R;

  are_marked = (bool_t*)malloc(BOARD_SIZE*sizeof(bool_t));
  assert(are_marked != NULL);
  memset(are_marked,FALSE,BOARD_SIZE);

  cells_side = (bool_t*)malloc(BOARD_SIZE*sizeof(bool_t));
  assert(cells_side != NULL);
  memset(cells_side             ,FALSE,BOARD_SIZE/2);
  memset(cells_side+BOARD_SIZE/2,TRUE ,BOARD_SIZE/2);
}

bool_t is_game_over(bool_t player_id) {
  bool_t tmp_cur_player = cur_player;
  cur_player = player_id;
  bool_t result = TRUE;
  for(byte_t src_pos = 0; src_pos < BOARD_SIZE; src_pos++)
    if(cells_type[src_pos] != PIECE_S && cells_side[src_pos] == player_id)
      for(byte_t des_pos = 0; des_pos < BOARD_SIZE; des_pos++)
        result &= is_in_check(player_id,src_pos,des_pos)
                  || !legal_move(src_pos,des_pos,FALSE);
  cur_player = tmp_cur_player;
  return result;
}

void process() {
  assert(0 <= current_pos && current_pos < BOARD_SIZE);
  if(!has_selected) {
    if(!is_own_piece(current_pos)) // illegal selection
      return;
    for(byte_t iter = 0; iter<BOARD_SIZE; iter++)
      are_marked[iter] = !is_in_check(cur_player,current_pos,iter)
                       && legal_move(current_pos,iter,FALSE);
    selected_pos = current_pos;
    has_selected = TRUE;
  } else {
    assert(0 <= selected_pos && selected_pos < BOARD_SIZE);
    if(are_marked[current_pos]) { // click on legal cell
      legal_move(selected_pos,current_pos,TRUE);
      cur_player = !cur_player;
      printf("change turn\n");
      if(is_in_check(!cur_player,0,0))
        printf("Player %d, you are in check!!!\n",!cur_player);
      if(is_in_check(cur_player,0,0))
        printf("Player %d, you are in check!!!\n", cur_player);
    }
    for(byte_t iter = 0; iter<BOARD_SIZE; iter++)
      are_marked[iter] = FALSE;
    selected_pos = BYTE_UNDEFINED;
    has_selected = FALSE;
  }
}

bool_t is_in_check(bool_t player_id, byte_t src_pos, byte_t des_pos) {
  byte_t tmp_cell_type = cells_type[des_pos];
  bool_t tmp_cell_side = cells_side[des_pos];
  bool_t tmp_cur_player = cur_player;
  cur_player = !player_id;
  byte_t king_pos,killer_pos;
  bool_t check = FALSE;
  actual_move(src_pos,des_pos);
  for(king_pos = 0; king_pos<BOARD_SIZE; king_pos++)
    if(cells_type[king_pos] == PIECE_K && cells_side[king_pos] == player_id)
      break;
  if(king_pos < BOARD_SIZE)
    for(killer_pos = 0; killer_pos<BOARD_SIZE; killer_pos++)
      check |= legal_move(killer_pos,king_pos,FALSE);
  actual_move(des_pos,src_pos);
  cells_type[des_pos] = tmp_cell_type;
  cells_side[des_pos] = tmp_cell_side;
  cur_player = tmp_cur_player;
  return check;
}

bool_t legal_move(byte_t src_pos, byte_t des_pos, bool_t update) {
  if(!is_own_piece(src_pos)) // can move own piece only
    return FALSE;
  else if(is_own_piece(des_pos)) // cannot capture ally
    return FALSE;
  else if(src_pos == des_pos) // cannot move to the same cell
    return FALSE;
  else if(!(0 <= src_pos && src_pos < BOARD_SIZE)) // src_pos out of bound
    return FALSE;
  else if(!(0 <= des_pos && des_pos < BOARD_SIZE)) // des_pos out of bound
    return FALSE;

  signed_byte_t src_row = src_pos / BOARD_COL;
  signed_byte_t src_col = src_pos % BOARD_COL;
  signed_byte_t des_row = des_pos / BOARD_COL;
  signed_byte_t des_col = des_pos % BOARD_COL;

  switch(cells_type[src_pos]) {
  case PIECE_S:
    return FALSE;
  case PIECE_P:
    if(absolute(src_col - des_col) > 1) // another column
      return FALSE;
    else if((!(src_row < des_row) && !cells_side[src_pos]) // non-forward
         || (!(src_row > des_row) &&  cells_side[src_pos]))
      return FALSE;
    else if(src_col == des_col) { // move
      if(absolute(src_row - des_row) == 1) { // normal move
        if(cells_type[des_pos] != PIECE_S)
          return FALSE;
      } else if(absolute(src_row - des_row) == 2) { // fast started move
        if(cells_type[des_pos] != PIECE_S
        || cells_type[(src_pos+des_pos)/2] != PIECE_S
        || src_row != (!cells_side[src_pos] ? 1 : 6))
          return FALSE;
        if(update)
          en_passant_flag = src_col + BOARD_COL;
      } else
        return FALSE;
    } else { // capture
      if(absolute(src_row - des_row) != 1)
        return FALSE;
      else if(cells_type[des_pos] == PIECE_S) {
        if(des_col == en_passant_flag
        && des_row == (!cells_side[src_pos] ? 5 : 2)) {
          if(update)
            cells_type[to_pos(src_row,des_col)] = PIECE_S;
        }
        else
          return FALSE;
      }
    }
    if(update && des_row == (!cells_side[src_pos] ? 7 : 0))
      cells_type[src_pos] = promote_pawn();
    break;
  case PIECE_H:
    if(!(absolute(src_col - des_col) == 1 && absolute(src_row - des_row) == 2)
    && !(absolute(src_col - des_col) == 2 && absolute(src_row - des_row) == 1))
      return FALSE;
    break;
  case PIECE_B:
    if(!is_path_clear(src_pos,des_pos,FALSE,TRUE))
      return FALSE;
    break;
  case PIECE_R:
    if(!is_path_clear(src_pos,des_pos,TRUE,FALSE))
      return FALSE;
    if(update) {
      if(src_pos == to_pos(0,0))
        castle_flag |= 1<<0;
      if(src_pos == to_pos(0,7))
        castle_flag |= 1<<1;
      if(src_pos == to_pos(7,0))
        castle_flag |= 1<<2;
      if(src_pos == to_pos(7,7))
        castle_flag |= 1<<3;
    }
    break;
  case PIECE_Q:
    if(!is_path_clear(src_pos,des_pos,TRUE,TRUE))
      return FALSE;
    break;
  case PIECE_K:
    if(absolute(src_col - des_col) <= 1 && absolute(src_row - des_row) <= 1) {
      if(update)
        castle_flag |= 1<<(4+cur_player);
      break;
    }
    // castle
    if(src_col != 4 || src_row != (!cur_player ? 0 : 7))
      return FALSE;
    if(castle_flag>>(4+cur_player)&1)
      return FALSE;
    if(src_row != des_row)
      return FALSE;
    if(absolute(src_col - des_col) != 2)
      return FALSE;
    byte_t direction_col = (des_col - src_col)/absolute(src_col - des_col);
    if(castle_flag >> (cur_player*2 + (direction_col == 1)) & 1)
      return FALSE;
    if(!is_path_clear(src_pos,cur_player*7*8+(direction_col==1)*7,TRUE,FALSE))
      return FALSE;
    if(is_in_check(cur_player,src_pos,src_pos))
      return FALSE;
    if(is_in_check(cur_player,src_pos,src_pos+direction_col))
      return FALSE;
    if(is_in_check(cur_player,src_pos,src_pos+2*direction_col))
      return FALSE;
    if(update) {
      actual_move(cur_player*7*8+(direction_col==1)*7,src_pos+direction_col);
      castle_flag |= 1<<(4+cur_player);
    }
    break;
  }
  if(update) {
    actual_move(src_pos,des_pos);
    if(en_passant_flag != BYTE_UNDEFINED && en_passant_flag >= BOARD_COL)
      en_passant_flag -= BOARD_COL;
    else
      en_passant_flag = BYTE_UNDEFINED;
    if(des_pos == to_pos(0,0))
      castle_flag |= 1<<0;
    if(des_pos == to_pos(0,7))
      castle_flag |= 1<<1;
    if(des_pos == to_pos(7,0))
      castle_flag |= 1<<2;
    if(des_pos == to_pos(7,7))
      castle_flag |= 1<<3;
  }
  return TRUE;
}

bool_t is_own_piece(byte_t target_pos) {
  return cells_type[target_pos] != PIECE_S
      && cells_side[target_pos] == cur_player;
}

// for moving horizontal, vertical or diagonal ,if it is not return FALSE
// is the way clear
bool_t is_path_clear(byte_t src_pos, byte_t des_pos
    , bool_t enable_horizontal_vertical, bool_t enable_digonal) {
  assert(0 <= src_pos && src_pos < BOARD_SIZE);
  assert(0 <= des_pos && des_pos < BOARD_SIZE);
  signed_byte_t src_row = src_pos / BOARD_COL;
  signed_byte_t src_col = src_pos % BOARD_COL;
  signed_byte_t des_row = des_pos / BOARD_COL;
  signed_byte_t des_col = des_pos % BOARD_COL;
  signed_byte_t diff_row = absolute(src_row - des_row);
  signed_byte_t diff_col = absolute(src_col - des_col);
  if(diff_row != 0 && diff_col != 0 && diff_row != diff_col)
    return FALSE;
  else if(src_pos == des_pos)
    return TRUE;
  signed_byte_t distance = diff_row >= diff_col ? diff_row : diff_col;
  signed_byte_t direction_row = !diff_row ? 0 : (des_row - src_row)/distance;
  signed_byte_t direction_col = !diff_col ? 0 : (des_col - src_col)/distance;
  signed_byte_t tmp_pos;

  if((direction_row != 0) & (direction_col != 0)) { // diagonal
    if(!enable_digonal)
      return FALSE;
  }
  if((direction_row != 0) ^ (direction_col != 0)) { // horizontal_vertical
    if(!enable_horizontal_vertical)
      return FALSE;
  }

  for(signed_byte_t iter = 1; iter < distance; iter++) {
    tmp_pos = to_pos(src_row + direction_row*iter,src_col + direction_col*iter);
    if(cells_type[tmp_pos] != PIECE_S)
      return FALSE;
  }
  return TRUE;
}

void actual_move(byte_t src_pos, byte_t des_pos) {
  assert(0 <= src_pos && src_pos < BOARD_SIZE);
  assert(0 <= des_pos && des_pos < BOARD_SIZE);
  if(src_pos == des_pos)
    return;
  cells_type[des_pos] = cells_type[src_pos];
  cells_side[des_pos] = cells_side[src_pos];
  cells_type[src_pos] = PIECE_S;
}

byte_t to_pos(byte_t row, byte_t col) {
  return row*BOARD_COL + col;
}

byte_t absolute(signed_byte_t number) {
  return ((number >= 0)*2-1)*number;
}
