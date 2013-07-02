;-----------------------------------------------------------------------------
; Xu Ji, Bora Mollamustafaoglu, Gun Pinyo (Imperial College London) 
; {xj1112, bm1212, gp1712}@imperial.ac.uk
;
; Created as part of our first year C project
; 
;-----------------------------------------------------------------------------

  B       .main

  ANDEQ   r0, r0, r0    ; padding to ensure the frame buffer structure
  ANDEQ   r0, r0, r0    ;  has 0s in the bottom four bits - it 
  ANDEQ   r0, r0, r0    ;  must be instruction 16
  ANDEQ   r0, r0, r0
  ANDEQ   r0, r0, r0
  ANDEQ   r0, r0, r0
  ANDEQ   r0, r0, r0
  ANDEQ   r0, r0, r0
  ANDEQ   r0, r0, r0
  ANDEQ   r0, r0, r0
  ANDEQ   r0, r0, r0
  ANDEQ   r0, r0, r0
  ANDEQ   r0, r0, r0
  ANDEQ   r0, r0, r0
  ANDEQ   r0, r0, r0

frame_buffer_info_data:
  DCD     1920                    ; Width  (screen)
  DCD     1080                    ; Height (screen)
  DCD     640                     ; vWidth (frame buffer)
  DCD     640                     ; vHeight (frame buffer)
  DCD     0                       ; RETURNED BY GPU - Pitch (num bytes per row)
  DCD     32                      ; Bit Depth, RGB32 colour
  DCD     0                       ; x offset from top left of screen 
  DCD     0                       ; y offset from top left of screen
  DCD     0                       ; RETURNED BY GPU - Pointer to frame buffer
  DCD     0                       ; RETURNED BY GPU - num bytes in frame buffer

get_frame_buffer_info_data_address:  ; ADR distance from label is restricted
  ADR     r0, frame_buffer_info_data
  MOV     pc, lr

;---------------------------------------MAIN----------------------------------
.main:
  main_while_all_game:
    BL init_stack
    BL init_pins  
    BL initialise

    main_while_each_game:
      BL get_cur_player
      BL is_game_over
      CMP r0, #0
      BNE main_end_each_game  

      BL display
      BL manage_input
      BL get_is_clicked
      CMP r0, #0
      BLNE process
      B main_while_each_game
    
    main_end_each_game:
      BL display
      BL game_over
    
    B main_while_all_game

manage_input:
    ; up is pin 23
    ; left is pin 18
    ; down is pin 4
    ; right is pin 17
    ; selected is pin 22
    ; reset is pin 27
    STR     lr, [sp, #4]!
    STR     r0, [sp, #4]!
    STR     r1, [sp, #4]!
    STR     r2, [sp, #4]!
    
    BL      get_current_pos
    BL      reverse_row
    MOV     r1, r0              ; r1 holds current_pos
    MOV     r2, r0              ; r2 is another copy, to test if it changes

  manage_input_left:
    BL      wait
   
    MOV     r0, #18
    BL      get_gpio_input
    CMP     r0, #0
    BNE     manage_input_up
 
    MOV     r0, #0              ; not a click
    BL      set_is_clicked

    AND     r0, r1, #7          ; r0 = r1 % 8
    CMP     r0, #0
    SUBNE   r1, r1, #1          ; move cursor left
    ADDEQ   r1, r1, #7          ; wrap around
    
    B       manage_input_end

  manage_input_up:  
    MOV     r0, #23
    BL      get_gpio_input
    CMP     r0, #0
    BNE     manage_input_down
    MOV     r0, #0              ; not a click
    BL      set_is_clicked

    CMP     r1, #7              ; check that cursor is not in top row
    SUBGT   r1, r1, #8          ; move cursor up
    ADDLE   r1, r1, #56         ; wrap around
    
    B       manage_input_end

  manage_input_down: 
    MOV     r0, #4
    BL      get_gpio_input
    CMP     r0, #0
    BNE     manage_input_right
    
    MOV     r0, #0              ; not a click
    BL      set_is_clicked

    CMP     r1, #56             ; check that cursor is not in bottom row
    ADDLT   r1, r1, #8          ; move cursor down
    SUBGE   r1, r1, #56         ; wrap around
    
    B       manage_input_end

  manage_input_right:
    MOV     r0, #17
    BL      get_gpio_input
    CMP     r0, #0
    BNE     manage_input_selected
    
    MOV     r0, #0              ; not a click
    BL      set_is_clicked

    AND     r0, r1, #7          ; r0 = r1 % 8
    CMP     r0, #7
    ADDNE   r1, r1, #1          ; move cursor right
    SUBEQ   r1, r1, #7          ; wrap around
   
    B       manage_input_end

 manage_input_selected:
    MOV     r0, #22
    BL      get_gpio_input
    CMP     r0, #0 
    BNE     manage_input_reset

    MOV     r0, #1
    BL      set_is_clicked
      
    B       manage_input_end

 manage_input_reset:
    MOV     r0, #27
    BL      get_gpio_input
    CMP     r0, #0
    BNE     manage_input_left
    B     .main

  manage_input_end:
    MOV     r0, r1              ; set current pos
    BL      reverse_row
      
    CMP     r1, r2              ; check if current_pos has been updated
    BLNE    set_current_pos

    LDR     r2, [sp], #-4 
    LDR     r1, [sp], #-4    
    LDR     r0, [sp], #-4
    LDR     pc, [sp], #-4

game_over:  ; displays the game over screen
    STR     lr, [sp, #4]!
    STR     r0, [sp, #4]!
    STR     r1, [sp, #4]!
    STR     r2, [sp, #4]!
    STR     r3, [sp, #4]!
    STR     r4, [sp, #4]!
    STR     r5, [sp, #4]!

                                          ; let the state of the game board
    BL      led_blink                     ; stay on the screen before game over
    BL      led_blink

    ; set up parameters to draw_square, and call it

    BL      get_player_two_outline_colour ; game over outline is grey
    MOV     r4, r0

    MOV     r3, #0                        ; text is white (0xFFFFFFFF)
    SUB     r3, r3, #1

    BL      get_cur_player                ; current player is the loser
    CMP     r0, #0                        ; winner becomes background colour
    BLEQ    get_player_two_colour
    BLNE    get_player_one_colour
    MOV     r2, r0

    ; check if there is actually a winner, make stalemate colour
    ; if stalemate
    STR     r2, [sp, #4]!                 ; store this to call is_in_check

    MOV     r1, #0                        ; r1 must == r2 when calling is_in_check
    MOV     r2, #0                        ;  in this case

    BL      get_cur_player
    BL      is_in_check

    LDR     r2, [sp], #-4                 ; restore the current colour
                                          ;  which may be changed
    CMP     r0, #0
    BLEQ    get_stalemate_colour
    MOVEQ   r2, r0    

    MOV     r1, #'G'                      ; 'G' for game over

    BL      get_frame_buffer_info_data_address
    LDR     r0, [r0, #32]                 ; get pointer to frame buffer
    LDR     r5, [r0, #8]                  ; get width of frame buffer (in pixels)

    BL      draw_square                   ; display game-over screen

                                          ; let it stay on the screen
    BL      led_blink                     ; before game restarts
    BL      led_blink
    

    LDR     r5, [sp], #-4
    LDR     r4, [sp], #-4
    LDR     r3, [sp], #-4
    LDR     r2, [sp], #-4
    LDR     r1, [sp], #-4
    LDR     r0, [sp], #-4
    LDR     pc, [sp], #-4

;------------------------------------------------------------------------------

; Asks player to choose promotion
; puts result, 'Q', 'C', 'B', 'H'
promote_pawn:
    STR     lr, [sp, #4]!                            
    STR     r6, [sp, #4]! 

    MOV     r6, #0                 ; r6 is flag for currently selected piece
    promote_pawn_loop:
        MOV     r0, r6
        BL      promote_pawn_draw
 
    promote_pawn_manage_input_left:
        MOV     r0, #0xB6000       ; wait
        BL      wait
   
        MOV     r0, #18
        BL      get_gpio_input
        CMP     r0, #0
        BNE     promote_pawn_manage_input_right

        CMP     r6, #0
        SUBNE   r6, r6, #1
        B       promote_pawn_loop
    
        promote_pawn_manage_input_right:
        MOV     r0, #17
        BL      get_gpio_input
        CMP     r0, #0
        BNE     promote_pawn_manage_input_selected

        CMP     r6, #3    
        ADDNE   r6, r6, #1 
        B       promote_pawn_loop

        promote_pawn_manage_input_selected:
        MOV     r0, #22
        BL      get_gpio_input
        CMP     r0, #0 
        BNE     promote_pawn_manage_input_reset

        B       promote_pawn_end   ; terminate w/ index in r6

        promote_pawn_manage_input_reset:
        MOV     r0, #27
        BL      get_gpio_input
        CMP     r0, #0
        BNE     promote_pawn_manage_input_left
        B       .main

promote_pawn_end:                  ; return the appropriate piece
        CMP     r6, #0
        MOVEQ   r0, #'Q'
        CMP     r6, #1
        MOVEQ   r0, #'R'
        CMP     r6, #2
        MOVEQ   r0, #'B'
        CMP     r6, #3
        MOVEQ   r0, #'H'

        LDR   r6, [sp], #-4
        LDR   pc, [sp], #-4

promote_pawn_draw:                 ; takes in r0 the index of the square to draw
    
    STR     lr, [sp, #4]!
    STR     r0, [sp, #4]!
    STR     r1, [sp, #4]!                            
    STR     r2, [sp, #4]!                            
    STR     r3, [sp, #4]!                            
    STR     r4, [sp, #4]!                            
    STR     r5, [sp, #4]!                            
    STR     r6, [sp, #4]!                            
    STR     r7, [sp, #4]!                            
    STR     r8, [sp, #4]!                            
    STR     r9, [sp, #4]!                            
    STR     r10, [sp, #4]!                            
    STR     r11, [sp, #4]!                            
    STR     r12, [sp, #4]!                            
    
    MOV     r11, r0               ; r11 is square index

    BL      get_length_square
    MOV     r8, r0                ; r8 is length of square in bytes
    LSL     r8, #2 
                                  ; draw background squares, light grey
    BL      get_frame_buffer_info_data_address     
    LDR     r5, [r0, #0x00000020] ; r5 is current address (to allow f calls)
    
    SUB     r8, r8, #4
    LDR     r7, [r0, #0x00000008] ; r7 is vwidth
    MUL     r10, r7, r8           ; r10 is 79 * 640 * 4 + 80*2
    ADD     r8, r8, #4            ; left of next row
    ADD     r10, r10, r8, LSL #1  ; it's the offset from sq 6 to top
 
    MOV     r0, #3                ; r5 is 80th pixel on row 3 (in bytes)  
    MUL     r0, r0, r7
    MUL     r0, r0, r8
    ADD     r0, r0, r8
    ADD     r5, r5, r0
    MOV     r9, r5                ; store initial r5, will need for draw pieces

    MOV     r6, #0                ; r6 counter

    promote_pawn_background_loop:
            CMP     r6, #12
            BGE     promote_pawn_draw_options

            CMP     r6, #6        ; if at square 6 in background squares
            ADDEQ     r5, r5, r10
            
            MOV     r1, #'S'      ; r1 = piece type
            BL      get_promote_background_colour
            MOV     r2, r0        ; r2 - r4 are colours
            MOV     r3, r5        ; temp address
        
            BL      get_length_square
            MOV     r5, r0
            MOV     r0, r3
            BL      draw_square
            MOV     r5, r3

            ADD     r5, r5, r8    ; address += 80*4
            ADD     r6, r6, #1    ; counter ++ 
            B       promote_pawn_background_loop

    promote_pawn_draw_options:
            MOV     r5, r9
            MOV     r6, #39       ; r6 is offset from our space: (39 * 640 * 4) + 80 * 4
            MUL     r6, r6, r7
            LSL     r6, #2 
            ADD     r6, r6, r8
            ADD     r5, r5, r6

            MOV     r12, r5                         ; r12 = store this value of r5 

            MOV     r1, #'Q'                        ; r2 is already background colour
            BL      get_square_background_one       ; r2 - r4 are colours
            MOV     r3, r0
            MOV     r4, r0
            MOV     r6, r5        ; r0 is address   
            BL      get_length_square
            MOV     r5, r0  
            MOV     r0, r6        ; enter correct address                         
            BL      draw_square
            MOV     r5, r6        ; restore address to r5

            ADD     r5, r5, r8
            MOV     r1, #'R'
            MOV     r6, r5        ; r0 is address   
            BL      get_length_square
            MOV     r5, r0  
            MOV     r0, r6        ; enter correct address                         
            BL      draw_square
            MOV     r5, r6        ; restore address to r5

            ADD     r5, r5, r8
            MOV     r1, #'B'
            MOV     r6, r5        ; r0 is address   
            BL      get_length_square
            MOV     r5, r0  
            MOV     r0, r6        ; enter correct address                         
            BL      draw_square
            MOV     r5, r6        ; restore address to r5

            ADD     r5, r5, r8
            MOV     r1, #'H'
            MOV     r6, r5        ; r0 is address   
            BL      get_length_square
            MOV     r5, r0  
            MOV     r0, r6        ; enter correct address                         
            BL      draw_square
            MOV     r5, r6        ; restore address to r5

    promote_pawn_draw_square:
            BL      get_current_pos_colour
            MOV     r1, r0        ; r1 is colour
            MUL     r11, r11, r8  ; index * 80 * 4
            ADD     r12, r12, r11
            MOV     r0, r12       ; r0 is address
            BL      draw_border                         
                      
        LDR   r12, [sp], #-4
        LDR   r11, [sp], #-4
        LDR   r10, [sp], #-4
        LDR   r9, [sp], #-4
        LDR   r8, [sp], #-4
        LDR   r7, [sp], #-4
        LDR   r6, [sp], #-4
        LDR   r5, [sp], #-4
        LDR   r4, [sp], #-4
        LDR   r3, [sp], #-4
        LDR   r2, [sp], #-4
        LDR   r1, [sp], #-4
        LDR   r0, [sp], #-4
        LDR   pc, [sp], #-4

;-----------------------------------------------------------------------------
get_promote_background_colour:
    STR     lr, [sp, #4]!
    BL      get_player_two_outline_colour
    LDR     pc, [sp], #-4
;------------------------------------------------------------------------------
;                               
get_current_pos_colour:
        STR     lr, [sp, #4]!

        BL      get_cur_player
        CMP     r0, #0                              ; check whether white/black
        BLEQ    get_player_one_colour               ; set up cursor depending
        BLNE    get_player_two_colour               ; current player

        LDR     pc, [sp], #-4
; push every register from r0 to r12
push_all_r0_r12:
  STR     r0, [sp, #4]!
  STR     r1, [sp, #4]!
  STR     r2, [sp, #4]!
  STR     r3, [sp, #4]!
  STR     r4, [sp, #4]!
  STR     r5, [sp, #4]!
  STR     r6, [sp, #4]!
  STR     r7, [sp, #4]!
  STR     r8, [sp, #4]!
  STR     r9, [sp, #4]!
  STR     r10, [sp, #4]!
  STR     r11, [sp, #4]!
  STR     r12, [sp, #4]!
  MOV     pc, lr

; push every register from r0 to r12 ; for void function
pop_all_r0_r12:
  LDR     r12, [sp], #-4
  LDR     r11, [sp], #-4
  LDR     r10, [sp], #-4
  LDR     r9, [sp], #-4
  LDR     r8, [sp], #-4
  LDR     r7, [sp], #-4
  LDR     r6, [sp], #-4
  LDR     r5, [sp], #-4
  LDR     r4, [sp], #-4
  LDR     r3, [sp], #-4
  LDR     r2, [sp], #-4
  LDR     r1, [sp], #-4
  LDR     r0, [sp], #-4
  MOV     pc, lr

; push every register from r0 to r12 ; for non-void function
pop_all_r1_r12:
  LDR     r12, [sp], #-4
  LDR     r11, [sp], #-4
  LDR     r10, [sp], #-4
  LDR     r9, [sp], #-4
  LDR     r8, [sp], #-4
  LDR     r7, [sp], #-4
  LDR     r6, [sp], #-4
  LDR     r5, [sp], #-4
  LDR     r4, [sp], #-4
  LDR     r3, [sp], #-4
  LDR     r2, [sp], #-4
  LDR     r1, [sp], #-4
  SUB     sp, sp, #4
  MOV     pc, lr

;-------------------------------------------------------------------------------
;int main() {                                                                    
;   initialise();
;   while (1) {                                                                 
;     while(!is_game_over(cur_player)) {                                                  
;       display();                                                              
;       manage_input();                                                         
;       if(is_clicked)                                                          
;         process();                                                            
;     }
;     display();
;     game_over();                                                              
;   }
; }
;-------------------------------------------------------------------------------


;-------------------------------------------------------------------------------
;void initialise() {
;  cur_player = FALSE; // set to first player
;  has_selected = FALSE; // now on hover state
;  is_clicked = FALSE
;
;  en_passant_flag = BYTE_UNDEFINED; // no pawn has moved
;  castle_flag = 0x00; // no rook nor king have moved
;
;  selected_pos = BYTE_UNDEFINED; // undefined by now
;  current_pos = to_pos(1,4); // at middle of board
;
;  cells_type = (byte_t*)malloc(BOARD_SIZE*sizeof(byte_t));
;  assert(cells_type != NULL);
;  memset(cells_type,PIECE_S,BOARD_SIZE);
;  memset(cells_type+(2-1)*BOARD_COL,PIECE_P,BOARD_COL);
;  memset(cells_type+(7-1)*BOARD_COL,PIECE_P,BOARD_COL);
;  cells_type[0] = cells_type[BOARD_SIZE-BOARD_COL+0] = PIECE_R;
;  cells_type[1] = cells_type[BOARD_SIZE-BOARD_COL+1] = PIECE_H;
;  cells_type[2] = cells_type[BOARD_SIZE-BOARD_COL+2] = PIECE_B;
;  cells_type[3] = cells_type[BOARD_SIZE-BOARD_COL+3] = PIECE_Q;
;  cells_type[4] = cells_type[BOARD_SIZE-BOARD_COL+4] = PIECE_K;
;  cells_type[5] = cells_type[BOARD_SIZE-BOARD_COL+5] = PIECE_B;
;  cells_type[6] = cells_type[BOARD_SIZE-BOARD_COL+6] = PIECE_H;
;  cells_type[7] = cells_type[BOARD_SIZE-BOARD_COL+7] = PIECE_R;
;
;  are_marked = (bool_t*)malloc(BOARD_SIZE*sizeof(bool_t));
;  assert(are_marked != NULL);
;  memset(are_marked,FALSE,BOARD_SIZE);
;
;  cells_side = (bool_t*)malloc(BOARD_SIZE*sizeof(bool_t));
;  assert(cells_side != NULL);
;  memset(cells_side             ,FALSE,BOARD_SIZE/2);
;  memset(cells_side+BOARD_SIZE/2,TRUE ,BOARD_SIZE/2);
;}
;-------------------------------------------------------------------------------

initialise:
  STR     lr, [sp, #4]!             ; push lr
  BL      push_all_r0_r12

  MOV     r0, #0
  BL      set_cur_player            ; cur_player = FALSE
  BL      set_has_selected          ; has_selected = FALSE
  BL      set_is_clicked            ; is_clicked = FALSE

  MOV     r0, #0
  SUB     r0, r0, #1
  BL      set_en_passant_flag       ; en_passant_flag = UNDEFINED
  MOV     r0, #0x00
  BL      set_castle_flag           ; castle_flag = 0x00 

  MOV     r0, #0
  SUB     r0, r0, #1
  BL      set_selected_pos          ; selected_pos = UNDEFINED
  MOV     r0, #0xC                  ; 0xC = (1<<3) + 4
  BL      set_current_pos           ; current_pos = to_pos(1,4)

initialise_for_begin:
  MOV     r8, #0                    ; byte_t iter = 0
initialise_for_next:
  CMP     r8, #64                   ; iter < BOARD_SIZE
  BGE     initialise_for_end

  MOV     r0, r8
  MOV     r1, #0x10                 ; 0x08 = to_pos(1,0)
  MOV     r2, #0x2F                 ; 0x30 = to_pos(6,7)
  BL      is_between
  CMP     r0, #0                    ; is_between(iter,to_pos(1,0),to_pos(6,7))

  MOV     r0, r8
  MOVNE   r1, #'S'
  MOVEQ   r1, #'P'
  BL      set_cells_type            ; cells_type[iter] = PIECE_S

  MOV     r0, r8
  MOV     r1, #0
  BL      set_are_marked            ; are_marked[iter] = FALSE

  MOV     r0, r8
  MOV     r1, r0, LSR #5
  BL      set_cells_side            ; cells_side[iter] = iter >= 32

  ADD     r8, r8, #1                ; iter++
  B       initialise_for_next
initialise_for_end:

  MOV     r1, #'R'
  MOV     r0, #0x00
  BL      set_cells_type            ; cells_type[to_pos(0,0)] = PIECE_R
  MOV     r0, #0x07
  BL      set_cells_type            ; cells_type[to_pos(0,7)] = PIECE_R
  MOV     r0, #0x38
  BL      set_cells_type            ; cells_type[to_pos(7,0)] = PIECE_R
  MOV     r0, #0x3F
  BL      set_cells_type            ; cells_type[to_pos(7,7)] = PIECE_R

  MOV     r1, #'H'
  MOV     r0, #0x01
  BL      set_cells_type            ; cells_type[to_pos(0,1)] = PIECE_H
  MOV     r0, #0x06
  BL      set_cells_type            ; cells_type[to_pos(0,6)] = PIECE_H
  MOV     r0, #0x39
  BL      set_cells_type            ; cells_type[to_pos(7,1)] = PIECE_H
  MOV     r0, #0x3E
  BL      set_cells_type            ; cells_type[to_pos(7,6)] = PIECE_H

  MOV     r1, #'B'
  MOV     r0, #0x02
  BL      set_cells_type            ; cells_type[to_pos(0,2)] = PIECE_B
  MOV     r0, #0x05
  BL      set_cells_type            ; cells_type[to_pos(0,5)] = PIECE_B
  MOV     r0, #0x3A
  BL      set_cells_type            ; cells_type[to_pos(7,2)] = PIECE_B
  MOV     r0, #0x3D
  BL      set_cells_type            ; cells_type[to_pos(7,5)] = PIECE_B

  MOV     r1, #'Q'
  MOV     r0, #0x03
  BL      set_cells_type            ; cells_type[to_pos(0,3)] = PIECE_Q
  MOV     r0, #0x3B
  BL      set_cells_type            ; cells_type[to_pos(7,3)] = PIECE_Q

  MOV     r1, #'K'
  MOV     r0, #0x04
  BL      set_cells_type            ; cells_type[to_pos(0,4)] = PIECE_K
  MOV     r0, #0x3C
  BL      set_cells_type            ; cells_type[to_pos(7,4)] = PIECE_K

  BL      pop_all_r0_r12
  LDR     lr, [sp], #-4             ; pop lr
  MOV     pc, lr

;-------------------------------------------------------------------------------
;bool_t is_game_over(bool_t player_id) {
;  bool_t tmp_cur_player = cur_player;
;  cur_player = player_id;
;  bool_t result = TRUE;
;  for(byte_t src_pos = 0; src_pos < BOARD_SIZE; src_pos++)
;    if(cells_type[src_pos] != PIECE_S && cells_side[src_pos] == player_id)
;      for(byte_t des_pos = 0; des_pos < BOARD_SIZE; des_pos++)
;        result &= is_in_check(player_id,src_pos,des_pos)
;                  || !legal_move(src_pos,des_pos,FALSE);
;  cur_player = tmp_cur_player;
;  return result;
;}
;-------------------------------------------------------------------------------

is_game_over:
  STR     lr, [sp, #4]!             ; push lr
  BL      push_all_r0_r12
  MOV     r10, r0                   ; r10 as player_id
  BL      get_cur_player
  MOV     r7, r0                    ; r7 as tmp_cur_player
  MOV     r0, r10
  BL      set_cur_player            ; cur_player = player_id
  MOV     r6, #1                    ; r6 as result = TRUE

  BL     get_is_clicked            ; for optimisation
  CMP     r0, #0                    ; if(is_clicked == FALSE)
  MOVEQ   r6, #0                    ; result = FALSE
  BEQ     is_game_over_return

is_game_over_src_for_begin:
  MOV     r8, #0                    ; r8 as src_pos = 0
is_game_over_src_for_next:
  CMP     r8, #64                   ; src_pos < BOARD_SIZE
  BGE     is_game_over_src_for_end

  MOV     r0, r8
  BL      get_cells_type
  CMP     r0, #'S'                  ; if(cells_type[src_pos] == PIECE_S)
  BEQ     is_game_over_src_for_continue

  MOV     r0, r8
  BL      get_cells_side
  CMP     r0, r10                   ; if(cells_side[src_pos] != player_id)
  BNE     is_game_over_src_for_continue

is_game_over_des_for_begin:
  MOV     r9, #0                    ; r9 as des_pos
is_game_over_des_for_next:
  CMP     r9, #64                   ; des_pos < BOARD_SIZE
  BGE     is_game_over_des_for_end

  MOV     r0, r8
  MOV     r1, r9
  MOV     r2, #0
  BL      legal_move                ; legal_move(src_pos,des_pos,FALSE)
  RSB     r3, r0, #1

  MOV     r0, r10
  MOV     r1, r8
  MOV     r2, r9
  BL      is_in_check               ; is_in_check(player_id,src_pos,des_pos)
  ORR     r0, r0, r3
  AND     r6, r6, r0                ; result &= is_in_check() || !legal_move()

  ADD     r9, r9, #1
  B       is_game_over_des_for_next
is_game_over_des_for_end:

is_game_over_src_for_continue:
  ADD     r8, r8, #1
  B       is_game_over_src_for_next
is_game_over_src_for_end:

is_game_over_return:
  MOV     r0, r7
  BL      set_cur_player            ; restore tmp_cur_player
  MOV     r0, r6                    ; return result
  BL      pop_all_r1_r12
  LDR     lr, [sp], #-4             ; pop lr
  MOV     pc, lr

;-------------------------------------------------------------------------------
;void process() {
;  assert(0 <= current_pos && current_pos < BOARD_SIZE);
;  if(!has_selected) {
;    if(!is_own_piece(current_pos)) // illegal selection
;      return;
;    for(byte_t iter = 0; iter<BOARD_SIZE; iter++)
;      are_marked[iter] = !is_in_check(cur_player,current_pos,iter)
;                       && legal_move(current_pos,iter,FALSE);
;    selected_pos = current_pos;
;    has_selected = TRUE;
;  } else {
;    assert(0 <= selected_pos && selected_pos < BOARD_SIZE);
;    if(are_marked[current_pos]) { // click on legal cell
;      legal_move(selected_pos,current_pos,TRUE);
;      cur_player = !cur_player;
;    }
;    for(byte_t iter = 0; iter<BOARD_SIZE; iter++)
;      are_marked[iter] = FALSE;
;    selected_pos = BYTE_UNDEFINED;
;    has_selected = FALSE;
;  }
;}
;-------------------------------------------------------------------------------

process:
  STR     lr, [sp, #4]!             ; push lr
  BL      push_all_r0_r12

  BL      get_has_selected
  CMP     r0, #0                    ; if(!has_selected)
  BEQ     process_if_has_selected
  BNE     process_else_has_selected

process_if_has_selected:
  BL      get_current_pos
  BL      is_own_piece
  CMP     r0, #0                    ; if(!is_own_piece)
  BEQ     process_return

process_if_has_selected_for_begin:
  MOV     r8, #0                    ; byte_t iter = 0
process_if_has_selected_for_next:
  CMP     r8, #64                   ; iter < BOARD_SIZE
  BGE     process_if_has_selected_for_end

  MOV     r2, r8
  BL      get_current_pos
  MOV     r1, r0
  BL      get_cur_player
  BL      is_in_check               ; is_in_check(cur_player,current_pos,iter)
  RSB     r3, r0, #1

  BL      get_current_pos
  MOV     r1, r8
  MOV     r2, #0
  BL      legal_move                ; legal_move(current_pos,iter,FALSE)

  AND     r1, r0, r3
  MOV     r0, r8
  BL      set_are_marked            ; are_marked[iter]=legal_move &&!is_in_check

  ADD     r8, r8, #1
  B       process_if_has_selected_for_next
process_if_has_selected_for_end:

  BL      get_current_pos
  BL      set_selected_pos          ; selected_pos = current_pos
  MOV     r0, #1
  BL      set_has_selected          ; has_selected = TRUE
  B       process_return

process_else_has_selected:
  BL      get_current_pos
  BL      get_are_marked
  CMP     r0, #0                    ; if(are_marked[current_pos])
  BEQ     process_else_has_selected_if_end

process_else_has_selected_if_begin:
  MOV     r2, #1
  BL      get_current_pos
  MOV     r1, r0
  BL      get_selected_pos
  BL      legal_move                ; legal_move(selected_pos,current_pos,TRUE)
  BL      get_cur_player
  RSB     r0, r0, #1
  BL      set_cur_player            ; cur_player = !cur_player
process_else_has_selected_if_end:

process_else_has_selected_for_begin:
  MOV     r8, #0                    ; byte_t iter = 0
process_else_has_selected_for_next:
  CMP     r8, #64                   ; iter < BOARD_SIZE
  BGE     process_else_has_selected_for_end

  MOV     r0, r8
  MOV     r1, #0
  BL      set_are_marked            ; are_marked[iter] = FALSE

  ADD     r8, r8, #1
  B       process_else_has_selected_for_next
process_else_has_selected_for_end:

  MOV     r0, #0
  SUB     r0, r0, #1
  BL      set_selected_pos          ; selected_pos = BYTE_UNDEFINED
  MOV     r0, #0
  BL      set_has_selected          ; has_selected = FALSE
  B       process_return

process_return:
  BL      pop_all_r0_r12
  LDR     lr, [sp], #-4             ; pop lr
  MOV     pc, lr

;-------------------------------------------------------------------------------
;bool_t is_in_check(bool_t player_id, byte_t src_pos, byte_t des_pos) {
;  byte_t tmp_cell_type = cells_type[des_pos];
;  bool_t tmp_cell_side = cells_side[des_pos];
;  byte_t king_pos,killer_pos;
;  bool_t check = FALSE;
;  bool_t tmp_cur_player = cur_player;
;  cur_player = !player_id;
;  actual_move(src_pos,des_pos);
;  for(king_pos = 0; king_pos<BOARD_SIZE; king_pos++)
;    if(cells_type[king_pos] == PIECE_K && cells_side[king_pos] == player_id)
;      break;
;  if(king_pos < BOARD_SIZE)
;    for(killer_pos = 0; killer_pos<BOARD_SIZE; killer_pos++)
;      check |= legal_move(killer_pos,king_pos,FALSE);
;  actual_move(des_pos,src_pos);
;  cells_type[des_pos] = tmp_cell_type;
;  cells_side[des_pos] = tmp_cell_side;
;  cur_player = tmp_cur_player;
;  return check;
;}
;-------------------------------------------------------------------------------
is_in_check:
  STR     lr, [sp, #4]!             ; push lr
  BL      push_all_r0_r12
  MOV     r10, r0                   ; r10 as player_id
  MOV     r11, r1                   ; r11 as src_pos
  MOV     r12, r2                   ; r12 as des_pos
  
  MOV     r5, #0                    ; r5 as check
  MOV     r0, r12
  BL      get_cells_type
  MOV     r8, r0                    ; r8 as tmp_cell_type
  MOV     r0, r12
  BL      get_cells_side
  MOV     r9, r0                    ; r9 as tmp_cell_side
  BL      get_cur_player
  MOV     r4, r0                    ; r4 as tmp_cur_player
  RSB     r0, r10, #1
  BL      set_cur_player            ; cur_player = !player_id
  ; afterward r6 as king_pos and r7 as killer_pos

  MOV     r0, r11
  MOV     r1, r12
  BL      actual_move               ; actual_move(src_pos,des_pos)

is_in_check_king_begin:
  MOV     r6, #0                    ; king_pos = 0
is_in_check_king_next:
  CMP     r6, #64                   ; if(king_pos < BOARD_SIZE)
  BGE     is_in_check_return        ; prepare to return directly

  MOV     r0, r6
  BL      get_cells_type
  MOV     r1, r0                    ; r1 = cells_type[king_pos]
  MOV     r0, r6
  BL      get_cells_side
  CMP     r0, r10                   ; if(cells_side[king_pos] == id_player)
  CMPEQ   r1, #'K'                  ; and if(cells_type[king_pos] == PIECE_K)
  BEQ     is_in_check_king_end      ; break

  ADD     r6, r6, #1                ; king_pos ++
  B       is_in_check_king_next
is_in_check_king_end:

is_in_check_killer_begin:
  MOV     r7, #0                    ; killer_pos = 0
is_in_check_killer_next:
  CMP     r7, #64                   ; if(killer_pos < BOARD_SIZE)
  BGE     is_in_check_killer_end
  
  MOV     r0, r7
  MOV     r1, r6
  MOV     r2, #0
  BL      legal_move                ; legal_move(killer_pos,king_pos,FALSE)
  ORR     r5, r5, r0

  ADD     r7, r7, #1                ; killer_pos ++
  B       is_in_check_killer_next
is_in_check_killer_end:

is_in_check_return:
  MOV     r0, r12
  MOV     r1, r11
  BL      actual_move               ; actual_move(des_pos,src_pos)
  MOV     r0, r12
  MOV     r1, r8
  BL      set_cells_type            ; restore tmp_cell_type
  MOV     r0, r12
  MOV     r1, r9
  BL      set_cells_side            ; restore tmp_cell_side
  MOV     r0, r4
  BL      set_cur_player            ; restore tmp_cur_player

  MOV     r0, r5                    ; return check
  BL      pop_all_r1_r12
  LDR     lr, [sp], #-4             ; pop lr
  MOV     pc, lr

;-------------------------------------------------------------------------------
;bool_t legal_move(byte_t src_pos, byte_t des_pos, bool_t update) {
;  if(!is_own_piece(src_pos)) // can move own piece only
;    return FALSE;
;  else if(is_own_piece(des_pos)) // cannot capture ally
;    return FALSE;
;  else if(src_pos == des_pos) // cannot move to the same cell
;    return FALSE;
;  else if(!(0 <= src_pos && src_pos < BOARD_SIZE)) // src_pos out of bound
;    return FALSE;
;  else if(!(0 <= des_pos && des_pos < BOARD_SIZE)) // des_pos out of bound
;    return FALSE;
;
;  signed_byte_t src_row = src_pos / BOARD_COL;
;  signed_byte_t src_col = src_pos % BOARD_COL;
;  signed_byte_t des_row = des_pos / BOARD_COL;
;  signed_byte_t des_col = des_pos % BOARD_COL;
;
;  switch(cells_type[src_pos]) {
;  case PIECE_S:
;    return FALSE;
;  case PIECE_P:
;    if(absolute(src_col - des_col) > 1) // another column
;      return FALSE;
;    else if((!(src_row < des_row) && !cells_side[src_pos]) // non-forward
;         || (!(src_row > des_row) &&  cells_side[src_pos]))
;      return FALSE;
;    else if(src_col == des_col) { // move
;      if(absolute(src_row - des_row) == 1) { // normal move
;        if(cells_type[des_pos] != PIECE_S)
;          return FALSE;
;      } else if(absolute(src_row - des_row) == 2) { // fast started move
;        if(cells_type[des_pos] != PIECE_S
;        || cells_type[(src_pos+des_pos)/2] != PIECE_S
;        || src_row != (!cells_side[src_pos] ? 1 : 6))
;          return FALSE;
;        if(update)
;          en_passant_flag = src_col + BOARD_COL;
;      } else
;        return FALSE;
;    } else { // capture
;      if(absolute(src_row - des_row) != 1)
;        return FALSE;
;      else if(cells_type[des_pos] == PIECE_S) {
;        if(des_col == en_passant_flag
;        && des_row == (!cells_side[src_pos] ? 5 : 2)) {
;          if(update)
;            cells_type[to_pos(src_row,des_col)] = PIECE_S;
;        }
;        else
;          return FALSE;
;      }
;    }
;    if(update && des_row == (!cells_side[src_pos] ? 7 : 0))
;      cells_type[src_pos] = promote_pawn();
;    break;
;  case PIECE_H:
;    if(!(absolute(src_col - des_col) == 1 && absolute(src_row - des_row) == 2)
;    && !(absolute(src_col - des_col) == 2 && absolute(src_row - des_row) == 1))
;      return FALSE;
;    break;
;  case PIECE_B:
;    if(!is_path_clear(src_pos,des_pos,FALSE,TRUE))
;      return FALSE;
;    break;
;  case PIECE_R:
;    if(!is_path_clear(src_pos,des_pos,TRUE,FALSE))
;      return FALSE;
;    if(update) {
;      if(src_pos == to_pos(0,0))
;        castle_flag |= 1<<0;
;      if(src_pos == to_pos(0,7))
;        castle_flag |= 1<<1;
;      if(src_pos == to_pos(7,0))
;        castle_flag |= 1<<2;
;      if(src_pos == to_pos(7,7))
;        castle_flag |= 1<<3;
;    }
;    break;
;  case PIECE_Q:
;    if(!is_path_clear(src_pos,des_pos,TRUE,TRUE))
;      return FALSE;
;    break;
;  case PIECE_K:
;    if(absolute(src_col - des_col) <= 1 && absolute(src_row - des_row) <= 1) {
;      if(update)
;        castle_flag |= 1<<(4+cur_player);
;      break;
;    }
;    // castle
;    if(src_col != 4 || src_row != (!cur_player ? 0 : 7))
;      return FALSE;
;    if(castle_flag>>(4+cur_player)&1)
;      return FALSE;
;    if(src_row != des_row)
;      return FALSE;
;    if(absolute(src_col - des_col) != 2)
;      return FALSE;
;    byte_t direction_col = (des_col - src_col)/absolute(src_col - des_col);
;    if(castle_flag >> (cur_player*2 + (direction_col == 1)) & 1)
;      return FALSE;
;    if(!is_path_clear(src_pos,cur_player*7*8+(direction_col==1)*7,TRUE,FALSE))
;      return FALSE;
;    if(is_in_check(cur_player,src_pos,src_pos))
;      return FALSE;
;    if(is_in_check(cur_player,src_pos,src_pos+direction_col))
;      return FALSE;
;    if(is_in_check(cur_player,src_pos,src_pos+2*direction_col))
;      return FALSE;
;    if(update) {
;      actual_move(cur_player*7*8+(direction_col==1)*7,src_pos+direction_col);
;      castle_flag |= 1<<(4+cur_player);
;    }
;    break;
;  }
;  if(update) {
;    actual_move(src_pos,des_pos);
;    if(en_passant_flag != BYTE_UNDEFINED && en_passant_flag >= BOARD_COL)
;      en_passant_flag -= BOARD_COL;
;    else
;      en_passant_flag = BYTE_UNDEFINED;
;      if(des_pos == to_pos(0,0))
;        castle_flag |= 1<<0;
;      if(des_pos == to_pos(0,7))
;        castle_flag |= 1<<1;
;      if(des_pos == to_pos(7,0))
;        castle_flag |= 1<<2;
;      if(des_pos == to_pos(7,7))
;        castle_flag |= 1<<3;
;  }
;  return TRUE;
;}
;-------------------------------------------------------------------------------
legal_move:
  STR     lr, [sp, #4]!             ; push lr
  BL      push_all_r0_r12
  MOV     r11, r0                   ; r11 as src_pos
  MOV     r12, r1                   ; r12 as des_pos
  MOV     r10, r2                   ; r10 as update

  MOV     r0, r11
  BL      is_own_piece
  CMP     r0, #0                    ; if(!is_own_piece(src_pos))
  BEQ     legal_move_return_false

  MOV     r0, r12
  BL      is_own_piece
  CMP     r0, #0                    ; if(is_own_piece(des_pos))
  BNE     legal_move_return_false

  CMP     r11, r12                  ; if(src_pos == des_pos)
  BEQ     legal_move_return_false

  MOV     r6, r11, LSR #3           ; r6 as src_row
  AND     r7, r11, #7               ; r7 as src_col
  MOV     r8, r12, LSR #3           ; r8 as des_row
  AND     r9, r12, #7               ; r8 as des_col

  SUB     r0, r6, r8
  BL      absolute
  MOV     r4, r0                   ; r4 as absolute(src_row - des_row), diff_row
  SUB     r0, r7, r9
  BL      absolute
  MOV     r5, r0                   ; r5 as absolute(src_col - des_col), diff_col

  ; start of switch
  MOV     r0, r11
  BL      get_cells_type
  CMP     r0, #'S'
  BEQ     legal_move_piece_s
  CMP     r0, #'P'
  BEQ     legal_move_piece_p
  CMP     r0, #'H'
  BEQ     legal_move_piece_h
  CMP     r0, #'B'
  BEQ     legal_move_piece_b
  CMP     r0, #'R'
  BEQ     legal_move_piece_r
  CMP     r0, #'Q'
  BEQ     legal_move_piece_q
  CMP     r0, #'K'
  BEQ     legal_move_piece_k
  B       legal_move_return_false  ; invalid piece should return FALSE

legal_move_piece_s:
  B       legal_move_return_false   ; alway return false

legal_move_piece_p:
  CMP     r5, #1                    ; if(absolute(src_col - des_col) > 1)
  BGT     legal_move_return_false

legal_move_piece_p_non_forward_white:
  MOV     r0, r11
  BL      get_cells_side
  CMP     r0, #0                    ; if(!cells_side[src_pos])
  BNE     legal_move_piece_p_non_forward_black
  CMP     r6, r8                    ; and if(!(src_row < des_row))
  BGE     legal_move_return_false

legal_move_piece_p_non_forward_black:
  MOV     r0, r11
  BL      get_cells_side
  CMP     r0, #0                    ; if(cells_side[src_pos])
  BEQ     legal_move_piece_p_decision
  CMP     r6, r8                    ; and if(!(src_row > des_row))
  BLE     legal_move_return_false
 
legal_move_piece_p_decision:
  CMP     r7, r9                    ; if(src_pos == des_pos)
  BEQ     legal_move_piece_p_move
  BNE     legal_move_piece_p_capture

legal_move_piece_p_move:
  CMP     r4, #1                    ; if(diff_col == 1)
  BEQ     legal_move_piece_p_move_normal
  CMP     r4, #2                    ; if(diif_row == 2)
  BEQ     legal_move_piece_p_move_fast_started
  B       legal_move_return_false

legal_move_piece_p_move_normal:
  MOV     r0, r12
  BL      get_cells_type
  CMP     r0, #'S'                  ; if(cells_type[des_pos] != PIECE_S)
  BNE     legal_move_return_false
  BEQ     legal_move_promotion

legal_move_piece_p_move_fast_started:
  MOV     r0, r12
  BL      get_cells_type
  CMP     r0, #'S'                  ; if(cells_type[des_pos] != PIECE_S)
  BNE     legal_move_return_false

  ADD     r0, r11, r12
  MOV     r0, r0, LSR #1            ; r0 = (src_pos + des_pos)/2
  BL      get_cells_type
  CMP     r0, #'S'                  ; if(cells_type[des_pos] != PIECE_S)
  BNE     legal_move_return_false

  MOV     r0, r11
  BL      get_cells_side
  CMP     r0, #0
  MOVEQ   r1, #1
  MOVNE   r1, #6                    ; r1 = !cells_side[src_pos] ? 1 : 6
  CMP     r6, r1
  BNE     legal_move_return_false

  CMP     r10, #0                   ; if(!update)
  BEQ     legal_move_promotion

  ADD     r0, r7, #8
  BL      set_en_passant_flag       ; en_passant_flag = src_col + BOARD_COL
  B       legal_move_promotion

legal_move_piece_p_capture:
  CMP     r4, #1                    ; if(diff_row != 1)
  BNE     legal_move_return_false
  
  MOV     r0, r12
  BL      get_cells_type
  CMP     r0, #'S'                  ; else if(cells_type[des_pos] == PIECE_S)
  BNE     legal_move_promotion

  MOV     r0, r11
  BL      get_cells_side
  CMP     r0, #0
  MOVEQ   r1, #5
  MOVNE   r1, #2                    ; r1 = !cells_side[src_pos] ? 5 : 2

  BL      get_en_passant_flag
  CMP     r9, r0                    ; if(des_col == en_passant_flag)
  CMPEQ   r8, r1                    ; and if(des_row == r1)
  BNE     legal_move_return_false

  CMP     r10, #0                   ; if(!update)
  BEQ     legal_move_promotion

  ADD     r0, r9, r6, LSL #3        ; r0 = to_pos(src_row,des_col)
  MOV     r1, #'S'
  BL      set_cells_type            ; cells_type[r0] = PIECE_S
  B       legal_move_promotion

legal_move_promotion:
  CMP     r10, #0                   ; if(!update)
  BEQ     legal_move_return_true

  MOV     r0, r11
  BL      get_cells_side
  CMP     r0, #0
  MOVEQ   r0, #7
  MOVNE   r0, #0                    ; r0 = !cells_side[src_pos] ? 7 : 0
  CMP     r0, r8                    ; if(!des_col == r0)
  BNE     legal_move_return_true

  BL      promote_pawn
  MOV     r1, r0
  MOV     r0, r11
  BL      set_cells_type            ; cells_type[src_pos] = promote_pawn()
  B       legal_move_return_true

legal_move_piece_h:
  CMP     r4, #1
  CMPEQ   r5, #2
  MOVEQ   r0, #0
  MOVNE   r0, #1                    ; r0 = !(diff_row == 1 && diff_col == 2)

  CMP     r4, #2
  CMPEQ   r5, #1
  MOVEQ   r1, #0
  MOVNE   r1, #1                    ; r1 = !(diff_row == 2 && diff_col == 1)

  TST     r0, r1
  BNE     legal_move_return_false
  BEQ     legal_move_return_true

legal_move_piece_b:
  MOV     r0, r11
  MOV     r1, r12
  MOV     r2, #0
  MOV     r3, #1
  BL      is_path_clear             ; is_path_clear(src_pos,des_pos,FALSE,TRUE)
  CMP     r0, #0
  BEQ     legal_move_return_false
  BNE     legal_move_return_true

legal_move_piece_r:
  MOV     r0, r11
  MOV     r1, r12
  MOV     r2, #1
  MOV     r3, #0
  BL      is_path_clear             ; is_path_clear(src_pos,des_pos,TRUE,FALSE)
  CMP     r0, #0
  BEQ     legal_move_return_false

  CMP     r10, #0                   ; if(!update)
  BEQ     legal_move_return_true

  BL      get_castle_flag
  CMP     r11, #0x00                ; if(src_pos == to_pos(0,0))
  ORREQ   r0, r0, #0x1              ; castle_flag |= 1<<0
  CMP     r11, #0x07                ; if(src_pos == to_pos(0,7))
  ORREQ   r0, r0, #0x2              ; castle_flag |= 1<<1
  CMP     r11, #0x38                ; if(src_pos == to_pos(7,0))
  ORREQ   r0, r0, #0x4              ; castle_flag |= 1<<2
  CMP     r11, #0x3F                ; if(src_pos == to_pos(7,7))
  ORREQ   r0, r0, #0x8              ; castle_flag |= 1<<3
  BL      set_castle_flag
  B       legal_move_return_true

legal_move_piece_q:
  MOV     r0, r11
  MOV     r1, r12
  MOV     r2, #1
  MOV     r3, #1
  BL      is_path_clear             ; is_path_clear(src_pos,des_pos,TRUE,TRUE)
  CMP     r0, #0
  BEQ     legal_move_return_false
  BNE     legal_move_return_true

legal_move_piece_k:
  CMP     r4, #1                    ; if(diff_row > 1)
  BGT     legal_move_piece_k_castle
  CMP     r5, #1                    ; if(diff_col > 1)
  BGT     legal_move_piece_k_castle

  CMP     r10, #0                   ; if(!update)
  BEQ     legal_move_return_true

  BL      get_cur_player
  CMP     r0, #0
  MOVEQ   r1, #0x10
  MOVNE   r1, #0x20
  BL      get_castle_flag
  ORR     r0, r0, r1
  BL      set_castle_flag           ; castle_flag |= 1<<(4+cur_player)
  B       legal_move_return_true

legal_move_piece_k_castle:
  CMP     r7, #4                    ; if(src_col != 4)
  BNE     legal_move_return_false

  BL      get_cur_player
  CMP     r0, #0
  MOVEQ   r1, #0
  MOVNE   r1, #7
  CMP     r6, r1                    ; if(src_row != (!cur_player ? 0 : 7))
  BNE     legal_move_return_false

  BL      get_cur_player
  CMP     r0, #0
  MOVEQ   r1, #0x10
  MOVNE   r1, #0x20
  BL      get_castle_flag
  TST     r0, r1                    ; if(castle_flag & (1<<(cur_player+4)))
  BNE     legal_move_return_false

  CMP     r6, r8                    ; if(src_row != des_row)
  BNE     legal_move_return_false

  CMP     r5, #2                    ; if(diff_col != 2)
  BNE     legal_move_return_false

  BL      get_cur_player
  CMP     r0, #0
  MOVEQ   r1, #0x1
  MOVNE   r1, #0x4                  ; r1 = 1<<(2*cur_player)
  CMP     r7, r9
  MOVLT   r1, r1, LSL #1            ; r1 <<= src_col < des_col
  BL      get_castle_flag
  TST     r0, r1                    ; if(castle_flag & r1)
  BNE     legal_move_return_false

  BL      get_cur_player
  CMP     r0, #0
  MOVEQ   r1, #0
  MOVNE   r1, #0x38                 ; r1 = cur_player*7*BOARD_COL
  CMP     r7, r9
  ADDLT   r1, r1, #0x07             ; rook_pos = r1 + (src_col < des_col)*7
  MOV     r0, r11
  MOV     r2, #1
  MOV     r3, #0
  BL      is_path_clear             ; is_path_clear(src_pos,rook_pos,TRUE,FALSE)
  CMP     r0, #0                    ; if(!is_path_clear(..,..,..,..))
  BEQ     legal_move_return_false

  CMP     r7, r9
  MOVLT   r3, #1                    ; r3 as direction_col
  MOVEQ   r3, #0
  MOVGT   r3, #0
  SUBGT   r3, r3, #1

  BL      get_cur_player
  MOV     r1, r11
  ADD     r2, r11, #0               ; r2 = src_pos
  BL      is_in_check               ; is_in_check(cur_player,src_pos,r2)
  CMP     r0, #0                    ; if(is_in_check(..,..,..))
  BNE     legal_move_return_false

  BL      get_cur_player
  MOV     r1, r11
  ADD     r2, r11, r3               ; r2 = src_pos + direction_col
  BL      is_in_check               ; is_in_check(cur_player,src_pos,r2)
  CMP     r0, #0                    ; if(is_in_check(..,..,..))
  BNE     legal_move_return_false

  BL      get_cur_player
  MOV     r1, r11
  ADD     r2, r11, r3, LSL #1       ; r2 = src_pos + 2*direction_col
  BL      is_in_check               ; is_in_check(cur_player,src_pos,r2)
  CMP     r0, #0                    ; if(is_in_check(..,..,..))
  BNE     legal_move_return_false

  CMP     r10, #0                   ; if(!update)
  BEQ     legal_move_return_true

  BL      get_cur_player
  CMP     r0, #0
  MOVEQ   r1, #0
  MOVNE   r1, #0x38                 ; r1 = cur_player*7*BOARD_COL
  CMP     r3, #1
  ADDEQ   r1, r1, #0x07             ; r1 = r1 + (direction_col == 1)*7
  MOV     r0, r1                    ; r0 = r1
  ADD     r1, r11, r3               ; r1 = src_pos + direction_col
  BL      actual_move               ; actual_move(r0,r1)

  BL      get_cur_player
  CMP     r0, #0
  MOVEQ   r1, #0x10
  MOVNE   r1, #0x20
  BL      get_castle_flag
  ORR     r0, r0, r1
  BL      set_castle_flag           ; castle_flag |= 1<<(4+cur_player)
  B       legal_move_return_true
  ; end of switch

legal_move_return_true:
  CMP     r10, #0                   ; if(update)
  MOVEQ   r0, #1
  BEQ     legal_move_return

  MOV     r0, r11
  MOV     r1, r12
  BL      actual_move               ; actual_move(src_pos,des_pos)

  BL      get_en_passant_flag
  MOV     r3, r0                    ; r3 as tmp, avoid calling function later
  MOV     r1, #8
  MOV     r2, #15
  BL      is_between
  CMP     r0, #0                    ; if(0 <= en_passant_flag-BOARD_COL < 8)
  
  SUBNE   r0, r3, #8                ; en_passant_flag -= BOARD_COL
  MOVEQ   r0, #0
  SUBEQ   r0, r0, #1                ; else en_passant_flag = UNDEFINED
  BL      set_en_passant_flag

  BL      get_castle_flag
  CMP     r12, #0x00                ; if(des_pos == to_pos(0,0))
  ORREQ   r0, r0, #0x1              ; castle_flag |= 1<<0
  CMP     r12, #0x07                ; if(des_pos == to_pos(0,7))
  ORREQ   r0, r0, #0x2              ; castle_flag |= 1<<1
  CMP     r12, #0x38                ; if(des_pos == to_pos(7,0))
  ORREQ   r0, r0, #0x4              ; castle_flag |= 1<<2
  CMP     r12, #0x3F                ; if(des_pos == to_pos(7,7))
  ORREQ   r0, r0, #0x8              ; castle_flag |= 1<<3
  BL      set_castle_flag

  MOV     r0, #1                    ; return TRUE
  B       legal_move_return

legal_move_return_false:
  MOV     r0, #0                    ; return FALSE
  B       legal_move_return

legal_move_return:
  BL      pop_all_r1_r12
  LDR     lr, [sp], #-4             ; pop lr
  MOV     pc, lr


;-------------------------------------------------------------------------------
;bool_t is_own_piece(byte_t target_pos) {
;  return cells_type[target_pos] != PIECE_S
;      && cells_side[target_pos] == cur_player;
;}
;-------------------------------------------------------------------------------
is_own_piece:
  STR     lr, [sp, #4]!             ; push lr
  BL      push_all_r0_r12
  MOV     r8, r0                    ; r8 as target_pos

  MOV     r0, r8
  BL      get_cells_type
  CMP     r0, #'S'
  MOVNE   r1, #1
  MOVEQ   r1, #0                    ; r1 = cells_type[target_pos] != PIECE_S

  MOV     r0, r8
  BL      get_cells_side
  MOV     r2, r0
  BL      get_cur_player
  CMP     r0, r2
  MOVEQ   r2, #1
  MOVNE   r2, #0                    ; r2 = cell_side[target_pos] == cur_player

  AND     r0, r1, r2                ; return r1 && r2

  BL      pop_all_r1_r12
  LDR     lr, [sp], #-4             ; pop lr
  MOV     pc, lr

;-------------------------------------------------------------------------------
;// for moving horizontal, vertical or diagonal ,if it is not return FALSE
;// is the way clear
;bool_t is_path_clear(byte_t src_pos, byte_t des_pos
;    , bool_t enable_horizontal_vertical, bool_t enable_digonal) {
;  assert(0 <= src_pos && src_pos < BOARD_SIZE);
;  assert(0 <= des_pos && des_pos < BOARD_SIZE);
;  signed_byte_t src_row = src_pos / BOARD_COL;
;  signed_byte_t src_col = src_pos % BOARD_COL;
;  signed_byte_t des_row = des_pos / BOARD_COL;
;  signed_byte_t des_col = des_pos % BOARD_COL;
;  signed_byte_t diff_row = absolute(src_row - des_row);
;  signed_byte_t diff_col = absolute(src_col - des_col);
;  if(diff_row != 0 && diff_col != 0 && diff_row != diff_col)
;    return FALSE;
;  else if(src_pos == des_pos)
;    return TRUE;
;  signed_byte_t distance = diff_row >= diff_col ? diff_row : diff_col;
;  signed_byte_t direction_row = !diff_row ? 0 : (des_row - src_row)/distance;
;  signed_byte_t direction_col = !diff_col ? 0 : (des_col - src_col)/distance;
;  signed_byte_t tmp_pos;
;
;  if((direction_row != 0) & (direction_col != 0)) { // diagonal
;    if(!enable_digonal)
;      return FALSE;
;  }
;  if((direction_row != 0) ^ (direction_col != 0)) { // horizontal_vertical
;    if(!enable_horizontal_vertical)
;      return FALSE;
;  }
;
;  for(signed_byte_t iter = 1; iter < distance; iter++) {
;    tmp_pos = to_pos(src_row+ direction_row*iter, src_col+ direction_col*iter);
;    if(cells_type[tmp_pos] != PIECE_S)
;      return FALSE;
;  }
;  return TRUE;
;}
;-------------------------------------------------------------------------------
is_path_clear:
  STR     lr, [sp, #4]!             ; push lr
  BL      push_all_r0_r12

  MOV     r6, r0, LSR #3            ; r6 as src_row
  AND     r7, r0, #7                ; r7 as src_col
  MOV     r8, r1, LSR #3            ; r8 as des_row
  AND     r9, r1, #7                ; r9 as des_col
  ; Noice that after this line r0 and r1 are not as src_pos and des_pos anymore.

  SUB     r0, r6, r8
  BL      absolute
  MOV     r11, r0                   ; r11 as diff_row
  SUB     r0, r7, r9
  BL      absolute
  MOV     r12, r0                   ; r12 as diff_col

  CMP     r11, #0                   ; if(diff_row != 0)
  CMPNE   r12, #0                   ; and if(diff_col != 0)
  CMPNE   r11, r12                  ; and if(diff_row != diff_col)
  BNE     is_path_clear_return_false

  CMP     r6, r8                    ; if(src_row == des_row)
  CMPEQ   r7, r9                    ; and if(src_col == des_col)
  BEQ     is_path_clear_return_true

  CMP     r11, r12
  MOVGE   r10, r11
  MOVLT   r10, r12                  ; r10 as distance

  CMP     r8, r6
  MOVLT   r11, #0
  SUBLT   r11, r11, #1
  MOVEQ   r11, #0
  MOVGT   r11, #1                   ; r11 as direction_row

  CMP     r9, r7
  MOVLT   r12, #0
  SUBLT   r12, r12, #1
  MOVEQ   r12, #0
  MOVGT   r12, #1                   ; r12 as direction_col

  MOV     r1, #1                    ; r1 = TRUE
  MOV     r0, r11
  BL      absolute
  AND     r1, r1, r0                ; r1 = direction_row != 0
  MOV     r0, r12
  BL      absolute
  AND     r1, r1, r0                ; r1 = ... & direction_col != 0
  RSB     r0, r3, #1                ; r0 = !enable_digonal
  TST     r0, r1
  BNE     is_path_clear_return_false

  MOV     r1, #1                    ; r1 = TRUE
  MOV     r0, r11
  BL      absolute
  AND     r1, r1, r0                ; r1 = direction_row != 0
  MOV     r0, r12
  BL      absolute
  EOR     r1, r1, r0                ; r1 = ... ^ direction_col != 0
  RSB     r0, r2, #1                ; r0 = !enable_horizontal_vertical
  TST     r0, r1
  BNE     is_path_clear_return_false

is_path_clear_for_begin:
  MOV     r4, #1                    ; byte_t iter = 1
is_path_clear_for_next:
  CMP     r4, r10                   ; iter < distance
  BGE     is_path_clear_for_end

  CMP     r11, #0
  ADDGT   r2, r6, r4
  MOVEQ   r2, r6
  SUBLT   r2, r6, r4                ; r2 = src_row + direction_row*iter

  CMP     r12, #0
  ADDGT   r3, r7, r4
  MOVEQ   r3, r7
  SUBLT   r3, r7, r4                ; r3 = src_col + direction_col*iter

  ADD     r0, r3, r2, LSL #3        ; r0 = to_pos(r2,r3)
  BL      get_cells_type
  CMP     r0, #'S'                  ; if(cells_type[tmp_pos] != PIECE_S)
  BNE     is_path_clear_return_false

  ADD     r4, r4, #1
  B       is_path_clear_for_next
is_path_clear_for_end:

is_path_clear_return_true:
  MOV     r0, #1                    ; return TRUE
  B       is_path_clear_return

is_path_clear_return_false:
  MOV     r0, #0                    ; return FALSE
  B       is_path_clear_return

is_path_clear_return:
  BL      pop_all_r1_r12
  LDR     lr, [sp], #-4             ; pop lr
  MOV     pc, lr

;-------------------------------------------------------------------------------
;void actual_move(byte_t src_pos, byte_t des_pos) {
;  assert(0 <= src_pos && src_pos < BOARD_SIZE);
;  assert(0 <= des_pos && des_pos < BOARD_SIZE);
;  if(src_pos == des_pos)
;    return;
;  cells_type[des_pos] = cells_type[src_pos];
;  cells_side[des_pos] = cells_side[src_pos];
;  cells_type[src_pos] = PIECE_S;
;}
;-------------------------------------------------------------------------------
actual_move:
  STR     lr, [sp, #4]!             ; push lr
  BL      push_all_r0_r12
  MOV     r8, r0                    ; r8 as src_pos
  MOV     r9, r1                    ; r9 as des_pos

  CMP     r8, r9                    ; if(src_pos == des_pos)
  BEQ     actual_move_return        ; return

  MOV     r0, r8
  BL      get_cells_type
  MOV     r1, r0
  MOV     r0, r9
  BL      set_cells_type            ; cells_type[des_pos] = cells_type[src_pos]

  MOV     r0, r8
  BL      get_cells_side
  MOV     r1, r0
  MOV     r0, r9
  BL      set_cells_side            ; cells_side[des_pos] = cells_side[src_pos]

  MOV     r0, r8
  MOV     r1, #'S'
  BL      set_cells_type            ; cells_type[src_pos] = PIECE_S

actual_move_return:
  BL      pop_all_r0_r12
  LDR     lr, [sp], #-4             ; pop lr
  MOV     pc, lr

;-------------------------------------------------------------------------------
;byte_t absolute(signed_byte_t number) {
;  return ((number >= 0)*2-1)*number;
;}
;-------------------------------------------------------------------------------
absolute:
  STR     lr, [sp, #4]!             ; push lr
  BL      push_all_r0_r12

  CMP     r0, #0
  BGE     absolute_return

  MVN     r0, r0
  ADD     r0, r0, #1

absolute_return:
  BL      pop_all_r1_r12
  LDR     lr, [sp], #-4             ; pop lr
  MOV     pc, lr


;-------------------------------------------------------------------------------
; bool_t is_in_bound(word_t number, word_t lower, word_t upper) {
;   return lower <= number && number <= upper;
; }
;-------------------------------------------------------------------------------
is_between:
  STR     lr, [sp, #4]!             ; push lr
  BL      push_all_r0_r12

  CMP     r1, r0
  MOVLE   r1, #1
  MOVGT   r1, #0                    ; r1 = r1 <= r0

  CMP     r0, r2
  MOVLE   r2, #1
  MOVGT   r2, #0                    ; r2 = r0 <= r2

  AND     r0, r1, r2                ; return r1 && r2

  BL      pop_all_r1_r12
  LDR     lr, [sp], #-4             ; pop lr
  MOV     pc, lr

;------------------------------------------------------------------------------

;------------------------------------DISPLAY-----------------------------------

;******************************************************************************

display: 
    STR     lr, [sp, #4]!
    BL      push_all_r0_r12
                                       ; check whether frame buffer address received
    BL      get_frame_buffer_info_data_address      
    MOV     r1, r0                     ; r0 = address of frame buffer info
    LDR     r1, [r1, #0x00000020]
    CMP     r1, #0
    BLEQ    set_frame_buffer

    LDR     r5, [r0, #0x00000020]      ; r5 is current address (initialised to frame buffer)
    LDR     r6, [r0, #16]              ; r6 is Pitch * 79 (bytes per row * 79 rows)
    BL      get_length_square          ; r7 is length of a square * 4
    MOV     r7, r0
    SUB     r7, r7, #1
    MUL     r6, r6, r7 
    
    MOV     r7, r0, LSL #2      
      
    ; get the colours to be used          
    BL      get_square_background_one  ; r11 is current background colour
    MOV     r11, r0                    ; r8 is max background colour
    BL      get_square_background_two
    ADD     r8, r0, r11

    MOV     r9, #0                     ; r9 is current square index
    MOV     r10, #0                    ; r10 is row's square index (access next 1st square)

display_loop:
    CMP     r9, #64
    BGE     display_end                ; *set function parameters*
        CMP     r10, #8                ; if end of row reached, update row ind + addr
        MOVEQ   r10, #0   
        ADDEQ   r5, r5, r6
        SUBEQ   r11, r8, r11           ; invert colour

        MOV     r0, r9                 ; r3 = piece colour, r4 = outline colour
        BL      reverse_row
        BL      get_cells_side          
        BL      display_get_colour     ; returns piece colour and outline colour
        MOV     r3, r0
        MOV     r4, r1

        MOV     r0, r9                 ; r1 = piece type
        BL      reverse_row
        BL      get_cells_type
        MOV     r1, r0

        MOV     r2, r11                ; r2 = background colour
        

        STR     r5, [sp, #4]!
        BL      get_length_square
        MOV     r12, r0
        MOV     r0, r5                 ; r0 = current address
        MOV     r5, r12
        
        BL      draw_square            
        LDR     r5, [sp], #-4          ; ********************************************
        
        MOV     r0, r9
        BL      reverse_row
        BL      get_are_marked         ; order matters here
        CMP     r0, #0
        BLNE    get_are_marked_colour
        MOVNE   r1, r0
        MOVNE   r0, r5
        BLNE    draw_border            ; ********************************************

        BL      get_current_pos_colour
        MOV     r1, r0
        BL      get_current_pos        ; show border if correct
        BL      reverse_row
        CMP     r0, r9                 ; square
        MOVEQ   r0, r5
        BLEQ    draw_border            ; ******************************************** 

        BL      get_has_selected
        CMP     r0, #0
        BEQ     display_skip_selected
        BL      get_selected_pos
        BL      reverse_row
        CMP     r0, r9
        BLEQ    get_selected_pos_colour
        MOVEQ   r1, r0
        MOVEQ   r0, r5
        BLEQ    draw_border            ; ********************************************

  display_skip_selected:

        ADD     r5, r5, r7             ; *increment counters*                        
        ADD     r9, r9, #1
        ADD     r10, r10, #1
        SUB     r11, r8, r11
        B       display_loop

display_end:
    BL      pop_all_r0_r12
    LDR     pc, [sp], #-4

display_get_colour:                     ; in r0 (side), out r0(piece col) and r1(outline col)
    STR         lr, [sp, #4]!           ; r0 = 0 (white), r0 = 1 (black)

    CMP         r0, #0
    BLEQ        get_player_one_outline_colour
    BLNE        get_player_two_outline_colour

    MOV         r1, r0

    BLEQ        get_player_one_colour
    BLNE        get_player_two_colour
    
    LDR         pc, [sp], #-4

;*********************************************************************************************
draw_square:
; r0 is the address of the top left of the square to draw/fill
; r1 is a character representing the type of the piece (in ASCII)
;   where 'K' == King, 'Q' == Queen, etc, and 'S' means empty
; r2 is the background colour to fill in
; r3 is the piece colour
; r4 is the outline colour
; r5 is the length of the square to draw
; Assumes the global array that will be called is stored in a special format:
;   The first word is the number of elements in the array (excluding the first)
;   Thereafter, each word represents a sequence of a repeated colour.
;   The bottom two bits tell us which colour the sequence is -
;   0 is background, 1 is piece, and 2 is outline (3 does not occur).
;   The remaining 30 bits tell us the length of the sequence in question.
;   We cannot have sequences of length 0
 
    STR     lr, [sp, #4]!       ; push everything
    BL      push_all_r0_r12


    MOV     r7, #0              ; the current sequence number, seq_no
    
    MOV     r8, r0              ; temporary home
    
    BL      get_frame_buffer_info_data_address
    LDR     r10, [r0, #16]      ; r10 = Pitch, which is our BOARD_LENGTH * 4

    MOV     r9, r5              ; r9 = SQUARE_LENGTH

    SUB     r10, r10, r9, LSL #2; num bytes to increment the pointer by when it
                                ; reaches the horizontal end of the square
                                ; as each pixel is 4 bytes
    

    ; use the piece type, given in r1, to determine our source for the piece
    ;  to draw, which will be a pointer to a global array
    
    TEQ     r1, #'K'            ; KING
    BLEQ    get_king_array

    TEQ     r1, #'Q'            ; QUEEN
    BLEQ    get_queen_array

    TEQ     r1, #'B'            ; BISHOP
    BLEQ    get_bishop_array

    TEQ     r1, #'H'            ; KNIGHT
    BLEQ    get_knight_array

    TEQ     r1, #'R'            ; ROOK
    BLEQ    get_rook_array

    TEQ     r1, #'P'            ; PAWN
    BLEQ    get_pawn_array

    TEQ     r1, #'S'            ; EMPTY SQUARE: draw a piece, make outline and
    BLEQ    get_king_array      ; piece colours same as background
    MOVEQ   r3, r2
    MOVEQ   r4, r2

    TEQ     r1, #'G'            ; GAME OVER
    BLEQ    get_game_over_array

    MOV     r5, r0              ; move whatever source we got into r5

    MOV     r0, r8              ; restore the address of the square to fill


    MOV     r1, #0              ; counter from 0 to SQUARE_LENGTH, used for
                                ; fixing the position of the square pointer
    
    LDR     r12, [r5]           ; get NUM_SEQUENCES, the first word from src
    ADD     r5, r5, #4          ; skip the first word of src

  draw_square_outer:
        CMP     r7, r12         ; while seq_no != NUM_SEQUENCES
        BGE     draw_square_end ; end when seq_no => NUM_SEQUENCES

        LDR     r6, [r5]        ; get a sequence to encode
        
        AND     r8, r6, #0x00000003 ; get the bottom two bits - represents colour

        ; get the top 30 bits, the length of the sequence
        MOV     r6, r6, LSR #2  ; do LSR of the sequence in r6

        ; figure out which colour we need to use for this sequence,
        ;  and set the colour

        TEQ     r8, #0          ; BACKGROUND COLOUR
        MOVEQ   r8, r2

        TEQ     r8, #1          ; PIECE COLOUR
        MOVEQ   r8, r3

        TEQ     r8, #2          ; OUTLINE COLOUR
        MOVEQ   r8, r4
        
        ; check if no colour has been set, and set default colour if so
        CMP     r8, #3
        STRCC   r0, [sp, #4]!
        BLCC    get_square_background_one
        MOVCC   r8, r0
        LDRCC   r0, [sp], #-4

        ; encode the current sequence
      draw_square_inner:
          TEQ     r6, #0      ; while seq != 0
          BEQ     draw_square_inner_end ; end if seq == 0
          
          ; make sure the pointer doesn't run off the end of the square
          TEQ     r1, r9      ; if counter == SQUARE_LENGTH
          MOVEQ   r1, #0      ; reset counter
          ADDEQ   r0, r0, r10 ; increment pointer to start of next row

          STR     r8, [r0]    ; update pixel with correct colour
          
          ADD     r0, r0, #4  ; move to next pixel in square
          ADD     r1, r1, #1  ; increment counter
          SUB     r6, r6, #1  ; decrement other counter
            
          B       draw_square_inner   ; loop again

      draw_square_inner_end:
        ADD     r7, r7, #1    ; increment current sequence number
        ADD     r5, r5, #4    ; move to next sequence from src
        B       draw_square_outer

  draw_square_end:
    BL      pop_all_r0_r12
    LDR     pc, [sp], #-4

;******************************************************************************
draw_border:                        ; takes r0(address), r1(colour)
    STR     lr, [sp, #4]!
    BL      push_all_r0_r12   
 
    MOV     r2, r0                  ; r2 is address to insert
    BL      get_length_square
    MOV     r9, r0                  ; r9 = 80
    MOV     r5, #6                  ; r5 = 6*80 = 480
    MUL     r5, r0, r5              ; r6 = 6400-480=5920                    
    SUB     r7, r0, #6              ; r7 = 74
    MOV     r8, #8                  ; r8 = 640 - 80
    MUL     r8, r0, r8                                   
    SUB     r8, r8, r9
    LSL     r8, #2                  ; r8 is number of bytes to add to pointer
                                    ; at the horizontal end of the square
    MUL     r0, r0, r0              ; r0 is total num pixels, 6400                              
    MOV     r6, r5
    SUB     r6, r0, r6
    MOV     r3, #0                  ; r3 is counter
    MOV     r4, #0                  ; r4 is counter for pixel within this row
    
draw_border_loop:
    CMP     r3, r0
    BEQ     draw_border_end
        CMP     r4, r9              ; if r4 == 80 update position within row
        MOVEQ   r4, #0
        ADDEQ   r2, r2, r8          ; address+= 640-80
    
        CMP     r3, r5              ; in top row
        STRLT     r1, [r2]
        
        CMP     r4, #6              ; in 1st column
        STRLT     r1, [r2]
        
        CMP     r4, r7              ; in last column
        STRGE     r1, [r2]
                 
        CMP     r3, r6              ; in bottom row
        STRGE     r1, [r2]

        ADD     r3, r3, #1
        ADD     r4, r4, #1
        ADD     r2, r2, #4
        B       draw_border_loop
         
draw_border_end:
        BL      pop_all_r0_r12
        LDR     pc, [sp], #-4

;******************************************************************************
;                                      FRAME BUFFER
set_frame_buffer:
    STR lr, [sp, #4]!
    STR r0, [sp, #4]!
    STR r1, [sp, #4]!
    STR r2, [sp, #4]!
    STR r3, [sp, #4]!
    STR r4, [sp, #4]!

    BL get_frame_buffer_info_data_address   
    MOV r2, r0
    BL  get_mailbox_base
    bl check_status_field_31
                                ; top 28 bits of write (message)
                                ;     =address of frame_buffer_data
    orr r2, r2, #0x40000000
    mov r3, #0x00000001         ; bottom 4 bits of write (channel)
    add r3, r2, r3              ; use r3, since r2 is used later    

    str r3, [r0, #0x00000020]   ; write the info to mailbox 1

read_mailbox_one: ; check mailbox 1 for zero (frame buffer info OK)
    bl check_status_field_30
    LDR r0, [r0]                ; get from read field
    
    and r4, r0, #0x0000000f
    cmp r4, #0x00000001          
    bne read_mailbox_one        ; if not correct mailbox, keep trying

write_mailbox_one_check_pointer:    
    LDR r0, [r2, #0x00000020]           ; check the pointer field has been set
    cmp r0, #0x00000000
    beq write_mailbox_one_check_pointer  ; if not OK, keep trying
    MOV r0, #0x3F0000                    ;  whilst replugging hdmi cable
    BL wait

    LDR r4, [sp], #-4
    LDR r3, [sp], #-4
    LDR r2, [sp], #-4
    LDR r1, [sp], #-4
    LDR r0, [sp], #-4
    LDR pc, [sp], #-4

;******************************************************************************
check_status_field_31:
    LDR r1, [r0, #0x00000018]    ; status field
    tst r1, #0x80000000
    bne check_status_field_31
    mov pc, lr

;******************************************************************************
check_status_field_30:
    LDR r1, [r0, #0x00000018]    ; status field
    tst r1, #0x40000000
    bne check_status_field_30
    mov pc, lr

;******************************************************************************
;-----------------------------------------------------------------------------;
;                           LED Operations                                    ;
;-----------------------------------------------------------------------------;
led_on:                                                                     
    STR     lr, [sp, #4]!                                                   
    STR     r1, [sp, #4]!                                                   
                                                                            
    BL      get_gpio_start      ; address of GPIO controller start          
                                                                            
    MOV     r1, #1                                                          
    LSL     r1, #16             ; pin 16 for CLEAR and SET sections         
                                                                            
    ; set bit 16 in the CLEAR section of the GPIO controller                
    ;  to turn the LED ON                                                   
    STR     r1, [r0, #0x28]                                                 
                                                                            
    LDR     r1, [sp], #-4                                                   
    LDR     pc, [sp], #-4                                                   
                                                                            
led_off:                                                                    
    STR     lr, [sp, #4]!                                                   
    STR     r1, [sp, #4]!                                                   
                                                                            
    BL      get_gpio_start      ; address of GPIO controller start          
                                                                            
    MOV     r1, #1                                                          
    LSL     r1, #16             ; pin 16 for CLEAR and SET sections         
                                                                            
    ; set bit 16 in the SET section of the GPIO controller                  
    ;  to turn the LED OFF                                                  
    STR     r1, [r0, #0x1C]                                                 
                                                                            
    LDR     r1, [sp], #-4                                                   
    LDR     pc, [sp], #-4                                                   
                                                                            
led_blink:                                                                  
    STR     lr, [sp, #4]!                                                   
    STR     r1, [sp, #4]!                                                   
    STR     r2, [sp, #4]!                                                   
    STR     r3, [sp, #4]!                                                   
    STR     r4, [sp, #4]!                                                   
    STR     r5, [sp, #4]!                                                   
    STR     r6, [sp, #4]!                                                   
                                                                            
    BL      get_gpio_start      ; address of GPIO controller start          
                                                                            
    MOV     r1, #0x001F8000     ; switch LED state after this many loops    
    MOV     r2, #8                                                          
    MUL     r2, r2, r1          ; r2 = no. of times to loop in total        
                                                                            
    MOV     r3, #0              ; little counter, resets on state switch    
    MOV     r4, #0              ; big counter, doesn't reset                
    MOV     r5, #0              ; bool, tells us which LED function to call 
    MOV     r6, #1              ; 1                                         
                                                                            
  led_blink_loop:                                                           
                                                                            
        TEQ     r3, r1          ; check if it is time to flip the LED       
        BEQ     led_blink_flip                                              
                                                                            
    led_blink_loop_cnt:                                                     
        ADD     r3, r3, #1      ; increment both counters                   
        ADD     r4, r4, #1      ;                                           
                                                                            
        CMP     r4, r2          ; check if the loop is done                 
        BNE     led_blink_loop                                              
                                                                            
    LDR     r6, [sp], #-4                                                   
    LDR     r5, [sp], #-4                                                   
    LDR     r4, [sp], #-4                                                   
    LDR     r3, [sp], #-4                                                   
    LDR     r2, [sp], #-4                                                   
    LDR     r1, [sp], #-4                                                   
    LDR     pc, [sp], #-4                                                   
                                                                            
                                                                            
  led_blink_flip:                                                           
    MOV     r3, #0      ; reset little counter                              
    SUB     r5, r6, r5  ; flip the bool to call the other function          
                                                                            
    ; find out which function we should call, and call it -                 
    ;  then return to the loop                                              
    CMP     r5, #0                                                          
    BEQ     led_blink_on                                                    
    BL      led_off                                                         
    B       led_blink_loop_cnt                                              
  led_blink_on:                                                             
    BL      led_on                                                          
    B       led_blink_loop_cnt                                              
;-----------------------------------------------------------------------------;
;                             GPIO Operations                                 ;
;-----------------------------------------------------------------------------;
init_pins:
    STR     lr, [sp, #4]!
    STR     r1, [sp, #4]!

    BL get_gpio_start       ; address of GPIO controller start

    ; prepare command to set GPIO 16 to be an output pin                     
    MOV     r1,  #0x00040000                                                 

    ; set the appropriate bit in the second word                             
    ;  of the GPIO controller, to set GPIO 16 to be an output pin            
    STR     r1,  [r0, #4]

    ; prepare command to set other pins to be input pins
    MOV     r1,  #0x00000000

    STR     r1, [r0]
    STR     r1, [r0, #8]

    LDR     r1, [sp], #-4
    LDR     pc, [sp], #-4                                                    

get_gpio_input:
    ; r0 is the input pin to return the value of (less than 32)
    ; get the start of the pin input section
    STR     lr, [sp, #4]!
    STR     r1, [sp, #4]!
    STR     r2, [sp, #4]!

    MOV     r1, r0
    BL      get_gpio_start
    LDR     r0, [r0, #52]       ; start of input section

    MOV     r2, #1              ; check if the correct bit is set
    AND     r0, r2, r0, LSR r1  

    LDR     r2, [sp], #-4
    LDR     r1, [sp], #-4
    LDR     pc, [sp], #-4
    
       
;-----------------------------------------------------------------------------    
wait:       ; takes the number of iterations to wait in r0
    STR     lr, [sp, #4]!                                                   
    STR     r1, [sp, #4]!                                                   
    STR     r2, [sp, #4]!                                                   
    STR     r3, [sp, #4]!                                                   
    STR     r4, [sp, #4]!                                                   
    STR     r5, [sp, #4]!                                                   
    STR     r6, [sp, #4]!                                                   
                                                                            
                                                                            
    MOV     r1, #0x000D8000     ; switch LED state after this many loops    
    MOV     r2, #1                                                          
    MUL     r2, r2, r1          ; r2 = no. of times to loop in total        
                                                                            
    MOV     r4, #0              ; big counter, doesn't reset                
                                                                            
  wait_loop:                                                           
                                                                    
        ADD     r4, r4, #1      ;                                           
        CMP     r4, r2          ; check if the loop is done                 
        BNE     wait_loop                                             
                                                                            
    LDR     r6, [sp], #-4                                                   
    LDR     r5, [sp], #-4                                                   
    LDR     r4, [sp], #-4                                                   
    LDR     r3, [sp], #-4                                                   
    LDR     r2, [sp], #-4                                                   
    LDR     r1, [sp], #-4                                                   
    LDR     pc, [sp], #-4                                                   

;-----------------------------------------------------------------------------
reverse_row: ; takes an index into the board between 0 and 63, and returns
            ;  an index that corresponds to a reversed row

    STR     r1, [sp, #4]!

    ; halfway point C of the board in the given column is
    ; 28 + (r0 % 8)

    AND     r1, r0, #7

    ADD     r1, r1, #28         ; r1 = C

    ; to reverse the rows, we need to return 2C - r0

    LSL     r1, #1              ; r1 = 2C
    SUB     r0, r1, r0          ; return 2C - r0

    LDR     r1, [sp], #-4

    MOV     pc, lr


;#############################################################################;
;                            GLOBALS START HERE

.global:

; bool_t cur_player = 0; 
; 0 for white, 1 for black ---------------------------------------------------
get_cur_player:  
  ADR     r0, _g_cur_player
  LDR     r0, [r0]

  MOV     pc, lr

set_cur_player:
  STR     r1, [sp, #4]!             ; push r1

  ADR     r1, _g_cur_player
  STR     r0, [r1]
 
  LDR     r1, [sp], #-4             ; pop r1
  MOV     pc, lr

_g_cur_player:
  DCD     0x00000000

; bool_t has_selected = 0; 
;  whether a piece has been selected ------------------------------------------
get_has_selected:
  ADR     r0, _g_has_selected
  LDR     r0, [r0]

  MOV     pc, lr

set_has_selected:
  STR     r1, [sp, #4]!             ; push r1

  ADR     r1, _g_has_selected
  STR     r0, [r1]
 
  LDR     r1, [sp], #-4             ; pop r1
  MOV     pc, lr

_g_has_selected:
  DCD     0x00000000

; bool_t is_clicked = 0; 
; if the select button was pressed---------------------------------------------
get_is_clicked:
  ADR     r0, _g_is_clicked
  LDR     r0, [r0]

  MOV     pc, lr

set_is_clicked:
  STR     r1, [sp, #4]!             ; push r1

  ADR     r1, _g_is_clicked
  STR     r0, [r1]
 
  LDR     r1, [sp], #-4             ; pop r1
  MOV     pc, lr

_g_is_clicked:
  DCD     0x00000000

; byte_t selected_pos = BYTE_UNDEFINE; 
;  index position of the piece selected to move--------------------------------
get_selected_pos:
  ADR     r0, _g_selected_pos
  LDR     r0, [r0]

  MOV     pc, lr

set_selected_pos:
  STR     r1, [sp, #4]!             ; push r1

  ADR     r1, _g_selected_pos
  STR     r0, [r1]
 
  LDR     r1, [sp], #-4             ; pop r1
  MOV     pc, lr

_g_selected_pos:
  DCD     0xFFFFFFFF

; byte_t en_passant_flag = BYTE_UNDEFINED; -------------------------------------
get_en_passant_flag:  
  ADR     r0, _g_en_passant_flag
  LDR     r0, [r0]

  MOV     pc, lr

set_en_passant_flag:
  STR     r1, [sp, #4]!             ; push r1

  ADR     r1, _g_en_passant_flag
  STR     r0, [r1]
 
  LDR     r1, [sp], #-4             ; pop r1
  MOV     pc, lr

_g_en_passant_flag:
  DCD     0xFFFFFFFF

; byte_t castle_flag = 0x00; ---------------------------------------------------
get_castle_flag:  
  ADR     r0, _g_castle_flag
  LDR     r0, [r0]

  MOV     pc, lr

set_castle_flag:
  STR     r1, [sp, #4]!             ; push r1

  ADR     r1, _g_castle_flag
  STR     r0, [r1]
 
  LDR     r1, [sp], #-4             ; pop r1
  MOV     pc, lr

_g_castle_flag:
  DCD     0x00000000

; byte_t current_pos = to_pos(1,4); 
; index position of the cursor -----------------------------------------------
get_current_pos:
  ADR     r0, _g_current_pos
  LDR     r0, [r0]

  MOV     pc, lr

set_current_pos:
  STR     r1, [sp, #4]!             ; push r1

  ADR     r1, _g_current_pos
  STR     r0, [r1]
 
  LDR     r1, [sp], #-4             ; pop r1
  MOV     pc, lr

_g_current_pos:
  DCD     0x0000000C  

; byte_t cells_type[BOARD_SIZE] = <<init>>; 
; the type of piece that is in each square:
; 'K' for king
; 'Q' for queen
; 'B' for bishop
; 'H' for knight
; 'R' for rook
; 'P' for pawn
; 'S' for space (empty square) ------------------------------------------------
get_cells_type:
  
  STR     r1, [sp, #4]!             ; push r1

  ADR     r1, _g_cells_type
  LDR     r0, [r1, r0, LSL #2]

  LDR     r1, [sp], #-4             ; pop r1
  MOV     pc, lr

set_cells_type:
  STR     r2, [sp, #4]!             ; push r2

  ADR     r2, _g_cells_type
  STR     r1, [r2, r0, LSL #2]
 
  LDR     r2, [sp], #-4             ; pop r2
  MOV     pc, lr

_g_cells_type:
  DCD     'R'
  DCD     'H'
  DCD     'B'
  DCD     'Q'
  DCD     'K'
  DCD     'B'
  DCD     'H'
  DCD     'R'

  DCD     'P'
  DCD     'P'
  DCD     'P'
  DCD     'P'
  DCD     'P'
  DCD     'P'
  DCD     'P'
  DCD     'P'

  DCD     'S'
  DCD     'S'
  DCD     'S'
  DCD     'S'
  DCD     'S'
  DCD     'S'
  DCD     'S'
  DCD     'S'

  DCD     'S'
  DCD     'S'
  DCD     'S'
  DCD     'S'
  DCD     'S'
  DCD     'S'
  DCD     'S'
  DCD     'S'

  DCD     'S'
  DCD     'S'
  DCD     'S'
  DCD     'S'
  DCD     'S'
  DCD     'S'
  DCD     'S'
  DCD     'S'

  DCD     'S'
  DCD     'S'
  DCD     'S'
  DCD     'S'
  DCD     'S'
  DCD     'S'
  DCD     'S'
  DCD     'S'

  DCD     'P'
  DCD     'P'
  DCD     'P'
  DCD     'P'
  DCD     'P'
  DCD     'P'
  DCD     'P'
  DCD     'P'
  
  DCD     'R'
  DCD     'H'
  DCD     'B'
  DCD     'Q'
  DCD     'K'
  DCD     'B'
  DCD     'H'
  DCD     'R'

; byte_t are_mark[BOARD_SIZE] = <<init>>; 
; the squares that can be moved to by the currently selected piece ------------
get_are_marked:
  
  STR     r1, [sp, #4]!             ; push r1

  ADR     r1, _g_are_marked
  LDR     r0, [r1, r0, LSL #2]

  LDR     r1, [sp], #-4             ; pop r1
  MOV     pc, lr

set_are_marked:
  STR     r2, [sp, #4]!             ; push r2


  ADR     r2, _g_are_marked
  STR     r1, [r2, r0, LSL #2]
 
  LDR     r2, [sp], #-4             ; pop r2
  MOV     pc, lr

_g_are_marked:
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000

  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000

  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000

  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000

  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000

  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000

  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000

  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000

; byte_t cells_side[BOARD_SIZE] = <<init>>;
; whether the cell is inhabited by white or black------------------------------
get_cells_side:
  
  STR     r1, [sp, #4]!             ; push r1

  ADR     r1, _g_cells_side
  LDR     r0, [r1, r0, LSL #2]

  LDR     r1, [sp], #-4             ; pop r1
  MOV     pc, lr

set_cells_side:
  STR     r2, [sp, #4]!             ; push r2


  ADR     r2, _g_cells_side
  STR     r1, [r2, r0, LSL #2]
 
  LDR     r2, [sp], #-4             ; pop r2
  MOV     pc, lr

_g_cells_side:
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000

  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000

  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000

  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000
  DCD     0x00000000

  DCD     0x00000001
  DCD     0x00000001
  DCD     0x00000001
  DCD     0x00000001
  DCD     0x00000001
  DCD     0x00000001
  DCD     0x00000001
  DCD     0x00000001

  DCD     0x00000001
  DCD     0x00000001
  DCD     0x00000001
  DCD     0x00000001
  DCD     0x00000001
  DCD     0x00000001
  DCD     0x00000001
  DCD     0x00000001

  DCD     0x00000001
  DCD     0x00000001
  DCD     0x00000001
  DCD     0x00000001
  DCD     0x00000001
  DCD     0x00000001
  DCD     0x00000001
  DCD     0x00000001

  DCD     0x00000001
  DCD     0x00000001
  DCD     0x00000001
  DCD     0x00000001
  DCD     0x00000001
  DCD     0x00000001
  DCD     0x00000001
  DCD     0x00000001

; physical start address of the GPIO controller -------------------------------
get_gpio_start:
  STR     lr, [sp, #4]!             ; push lr

  ADR     r0, _g_gpio_start
  LDR     r0, [r0]

  LDR     pc, [sp], #-4             ; pop lr and return

_g_gpio_start:
  DCD     0x20200000

; length of one (small) square on the chess board -----------------------------
get_length_square:
  STR     lr, [sp, #4]!             ; push lr

  ADR     r0, _g_length_square
  LDR     r0, [r0]

  LDR     pc, [sp], #-4             ; pop lr and return

_g_length_square:
  DCD     80

; background colour of one half of the squares --------------------------------
get_square_background_one:
  ADR     r0, _g_square_background_one
  LDR     r0, [r0]
  MOV     pc, lr

_g_square_background_one:
  DCD     0xFFFFFFFF    ; white
; background colour of the other half of squares ------------------------------
get_square_background_two:
  ADR     r0, _g_square_background_two
  LDR     r0, [r0]
  MOV     pc, lr

_g_square_background_two:
  DCD     0xFF462708       ; ABGR      ; blue

; colour of squares that can be moved to --------------------------------------
get_are_marked_colour:
  ADR     r0, _g_are_marked_colour
  LDR     r0, [r0]
  MOV     pc, lr

_g_are_marked_colour:
  DCD     0xFF33CC33        ; green
; colour of the square where the cursor is ------------------------------------
get_selected_pos_colour:
  ADR     r0, _g_selected_pos_colour
  LDR     r0, [r0]
  MOV     pc, lr

_g_selected_pos_colour:
  DCD     0xFF1D9BCD ; gold        

; -----------------------------------------------------------------------------
get_player_one_colour:
  ADR     r0, _g_player_one_colour
  LDR     r0, [r0]
  MOV     pc, lr

_g_player_one_colour:
  DCD     0xFF0000FF ;0xFF1F17B0     ; red
;------------------------------------------------------------------------------
get_player_two_colour:
  ADR     r0, _g_player_two_colour
  LDR     r0, [r0]
  MOV     pc, lr

_g_player_two_colour:
  DCD     0xFF000000        ; black
;------------------------------------------------------------------------------
get_player_one_outline_colour:
  ADR     r0, _g_player_one_outline_colour
  LDR     r0, [r0]
  MOV     pc, lr

_g_player_one_outline_colour:
  DCD     0xFF000000        ; black
;------------------------------------------------------------------------------
get_player_two_outline_colour:
  ADR     r0, _g_player_two_outline_colour
  LDR     r0, [r0]
  MOV     pc, lr

_g_player_two_outline_colour:
  DCD     0xA8A3A5          ; light grey

;------------------------------------------------------------------------------
get_stalemate_colour:
  ADR     r0, _g_stalemate_colour
  LDR     r0, [r0]
  MOV     pc, lr

_g_stalemate_colour:
  DCD     0xA8A3A5          ; light grey

; start address of the mailbox, which is used to communicate with the GPU -----
get_mailbox_base:
  ADR     r0, _g_mailbox_base
  LDR     r0, [r0]
  MOV     pc, lr

_g_mailbox_base:
  DCD     0x2000B880

;#############################################################################;
;                            PIECES START HERE                                ;
get_knight_array:
    ADR     r0, _g_knight_array
    MOV     pc, lr
_g_knight_array:
    DCD      271
    DCD      2392
    DCD      18
    DCD      304
    DCD      6
    DCD      9
    DCD      10
    DCD      296
    DCD      6
    DCD      13
    DCD      10
    DCD      292
    DCD      6
    DCD      17
    DCD      22
    DCD      276
    DCD      10
    DCD      17
    DCD      10
    DCD      9
    DCD      6
    DCD      272
    DCD      10
    DCD      21
    DCD      10
    DCD      13
    DCD      6
    DCD      268
    DCD      6
    DCD      49
    DCD      6
    DCD      260
    DCD      6
    DCD      57
    DCD      6
    DCD      252
    DCD      10
    DCD      61
    DCD      6
    DCD      248
    DCD      6
    DCD      69
    DCD      6
    DCD      240
    DCD      6
    DCD      77
    DCD      6
    DCD      232
    DCD      6
    DCD      85
    DCD      6
    DCD      224
    DCD      10
    DCD      89
    DCD      6
    DCD      220
    DCD      6
    DCD      97
    DCD      6
    DCD      212
    DCD      6
    DCD      105
    DCD      6
    DCD      204
    DCD      6
    DCD      113
    DCD      6
    DCD      196
    DCD      10
    DCD      117
    DCD      6
    DCD      192
    DCD      6
    DCD      117
    DCD      6
    DCD      192
    DCD      6
    DCD      117
    DCD      6
    DCD      196
    DCD      6
    DCD      105
    DCD      18
    DCD      196
    DCD      6
    DCD      105
    DCD      14
    DCD      200
    DCD      6
    DCD      73
    DCD      26
    DCD      13
    DCD      10
    DCD      200
    DCD      6
    DCD      57
    DCD      18
    DCD      20
    DCD      10
    DCD      9
    DCD      6
    DCD      200
    DCD      10
    DCD      53
    DCD      6
    DCD      40
    DCD      18
    DCD      200
    DCD      10
    DCD      57
    DCD      6
    DCD      252
    DCD      6
    DCD      65
    DCD      6
    DCD      248
    DCD      6
    DCD      69
    DCD      6
    DCD      244
    DCD      6
    DCD      73
    DCD      6
    DCD      240
    DCD      6
    DCD      77
    DCD      6
    DCD      236
    DCD      6
    DCD      77
    DCD      10
    DCD      232
    DCD      6
    DCD      81
    DCD      10
    DCD      228
    DCD      6
    DCD      85
    DCD      10
    DCD      224
    DCD      6
    DCD      89
    DCD      6
    DCD      224
    DCD      6
    DCD      93
    DCD      6
    DCD      220
    DCD      6
    DCD      97
    DCD      6
    DCD      212
    DCD      10
    DCD      101
    DCD      6
    DCD      208
    DCD      6
    DCD      109
    DCD      6
    DCD      204
    DCD      6
    DCD      113
    DCD      6
    DCD      200
    DCD      6
    DCD      113
    DCD      10
    DCD      196
    DCD      6
    DCD      117
    DCD      10
    DCD      192
    DCD      6
    DCD      121
    DCD      6
    DCD      192
    DCD      6
    DCD      125
    DCD      6
    DCD      188
    DCD      6
    DCD      129
    DCD      6
    DCD      184
    DCD      6
    DCD      133
    DCD      6
    DCD      180
    DCD      6
    DCD      129
    DCD      10
    DCD      180
    DCD      138
    DCD      184
    DCD      22
    DCD      97
    DCD      6
    DCD      4
    DCD      10
    DCD      208
    DCD      102
    DCD      220
    DCD      102
    DCD      220
    DCD      6
    DCD      93
    DCD      6
    DCD      204
    DCD      6
    DCD      12
    DCD      102
    DCD      220
    DCD      6
    DCD      93
    DCD      6
    DCD      212
    DCD      10
    DCD      101
    DCD      10
    DCD      200
    DCD      10
    DCD      109
    DCD      10
    DCD      196
    DCD      6
    DCD      117
    DCD      6
    DCD      196
    DCD      6
    DCD      117
    DCD      6
    DCD      196
    DCD      6
    DCD      117
    DCD      6
    DCD      196
    DCD      6
    DCD      117
    DCD      6
    DCD      196
    DCD      6
    DCD      117
    DCD      6
    DCD      196
    DCD      6
    DCD      117
    DCD      6
    DCD      196
    DCD      6
    DCD      117
    DCD      6
    DCD      188
    DCD      142
    DCD      180
    DCD      6
    DCD      133
    DCD      6
    DCD      180
    DCD      6
    DCD      133
    DCD      6
    DCD      180
    DCD      6
    DCD      133
    DCD      6
    DCD      180
    DCD      6
    DCD      133
    DCD      6
    DCD      184
    DCD      134
    DCD      2012
;-----------------------------------------------------------------------------
get_bishop_array:
    ADR     r0, _g_bishop_array
    MOV     pc, lr
_g_bishop_array:
     DCD      259
    DCD      2068
    DCD      26
    DCD      292
    DCD      6
    DCD      25
    DCD      6
    DCD      288
    DCD      6
    DCD      25
    DCD      6
    DCD      288
    DCD      6
    DCD      25
    DCD      6
    DCD      288
    DCD      6
    DCD      25
    DCD      6
    DCD      288
    DCD      6
    DCD      25
    DCD      6
    DCD      288
    DCD      6
    DCD      25
    DCD      6
    DCD      280
    DCD      14
    DCD      25
    DCD      14
    DCD      268
    DCD      10
    DCD      41
    DCD      10
    DCD      264
    DCD      10
    DCD      45
    DCD      10
    DCD      260
    DCD      6
    DCD      53
    DCD      6
    DCD      256
    DCD      6
    DCD      61
    DCD      6
    DCD      248
    DCD      6
    DCD      65
    DCD      10
    DCD      244
    DCD      6
    DCD      69
    DCD      6
    DCD      240
    DCD      10
    DCD      69
    DCD      6
    DCD      240
    DCD      6
    DCD      73
    DCD      6
    DCD      240
    DCD      6
    DCD      73
    DCD      6
    DCD      240
    DCD      6
    DCD      77
    DCD      6
    DCD      236
    DCD      6
    DCD      73
    DCD      6
    DCD      240
    DCD      6
    DCD      73
    DCD      6
    DCD      240
    DCD      6
    DCD      73
    DCD      6
    DCD      240
    DCD      10
    DCD      69
    DCD      6
    DCD      244
    DCD      6
    DCD      69
    DCD      6
    DCD      244
    DCD      6
    DCD      69
    DCD      6
    DCD      244
    DCD      10
    DCD      61
    DCD      10
    DCD      248
    DCD      6
    DCD      57
    DCD      10
    DCD      252
    DCD      10
    DCD      53
    DCD      6
    DCD      260
    DCD      6
    DCD      49
    DCD      6
    DCD      260
    DCD      66
    DCD      256
    DCD      10
    DCD      53
    DCD      10
    DCD      252
    DCD      66
    DCD      248
    DCD      14
    DCD      57
    DCD      14
    DCD      240
    DCD      86
    DCD      236
    DCD      6
    DCD      73
    DCD      10
    DCD      228
    DCD      98
    DCD      224
    DCD      6
    DCD      93
    DCD      6
    DCD      220
    DCD      6
    DCD      93
    DCD      6
    DCD      220
    DCD      6
    DCD      93
    DCD      6
    DCD      220
    DCD      102
    DCD      232
    DCD      10
    DCD      57
    DCD      10
    DCD      252
    DCD      6
    DCD      57
    DCD      6
    DCD      256
    DCD      6
    DCD      57
    DCD      6
    DCD      256
    DCD      6
    DCD      57
    DCD      6
    DCD      256
    DCD      6
    DCD      57
    DCD      6
    DCD      256
    DCD      6
    DCD      57
    DCD      6
    DCD      256
    DCD      6
    DCD      61
    DCD      6
    DCD      248
    DCD      10
    DCD      61
    DCD      6
    DCD      248
    DCD      10
    DCD      61
    DCD      6
    DCD      248
    DCD      6
    DCD      65
    DCD      6
    DCD      248
    DCD      6
    DCD      65
    DCD      6
    DCD      248
    DCD      6
    DCD      65
    DCD      6
    DCD      248
    DCD      6
    DCD      65
    DCD      6
    DCD      248
    DCD      6
    DCD      69
    DCD      6
    DCD      240
    DCD      10
    DCD      69
    DCD      6
    DCD      240
    DCD      6
    DCD      73
    DCD      6
    DCD      232
    DCD      98
    DCD      224
    DCD      6
    DCD      89
    DCD      6
    DCD      216
    DCD      114
    DCD      208
    DCD      6
    DCD      105
    DCD      6
    DCD      208
    DCD      6
    DCD      105
    DCD      6
    DCD      208
    DCD      6
    DCD      105
    DCD      6
    DCD      208
    DCD      6
    DCD      105
    DCD      6
    DCD      208
    DCD      6
    DCD      105
    DCD      6
    DCD      204
    DCD      10
    DCD      105
    DCD      10
    DCD      196
    DCD      134
    DCD      188
    DCD      6
    DCD      125
    DCD      6
    DCD      188
    DCD      6
    DCD      125
    DCD      6
    DCD      188
    DCD      6
    DCD      125
    DCD      6
    DCD      188
    DCD      134
    DCD      192
    DCD      126
    DCD      1376
;----------------------------------------------------------------------------
get_king_array:
    ADR     r0, _g_king_array
    MOV     pc, lr
_g_king_array:    
    DCD      261
    DCD      2068
    DCD      30
    DCD      292
    DCD      6
    DCD      21
    DCD      10
    DCD      288
    DCD      6
    DCD      21
    DCD      10
    DCD      288
    DCD      6
    DCD      21
    DCD      10
    DCD      288
    DCD      6
    DCD      21
    DCD      10
    DCD      252
    DCD      42
    DCD      21
    DCD      42
    DCD      220
    DCD      6
    DCD      93
    DCD      6
    DCD      220
    DCD      6
    DCD      93
    DCD      6
    DCD      220
    DCD      6
    DCD      93
    DCD      6
    DCD      220
    DCD      6
    DCD      93
    DCD      6
    DCD      220
    DCD      6
    DCD      93
    DCD      6
    DCD      220
    DCD      42
    DCD      21
    DCD      42
    DCD      256
    DCD      6
    DCD      21
    DCD      6
    DCD      292
    DCD      6
    DCD      21
    DCD      6
    DCD      248
    DCD      50
    DCD      21
    DCD      50
    DCD      204
    DCD      6
    DCD      109
    DCD      6
    DCD      204
    DCD      6
    DCD      109
    DCD      6
    DCD      208
    DCD      6
    DCD      101
    DCD      6
    DCD      212
    DCD      6
    DCD      101
    DCD      6
    DCD      212
    DCD      6
    DCD      101
    DCD      6
    DCD      216
    DCD      6
    DCD      93
    DCD      6
    DCD      220
    DCD      6
    DCD      93
    DCD      6
    DCD      220
    DCD      6
    DCD      93
    DCD      6
    DCD      220
    DCD      10
    DCD      85
    DCD      6
    DCD      228
    DCD      6
    DCD      85
    DCD      6
    DCD      228
    DCD      6
    DCD      85
    DCD      6
    DCD      232
    DCD      6
    DCD      77
    DCD      6
    DCD      236
    DCD      86
    DCD      236
    DCD      6
    DCD      77
    DCD      6
    DCD      236
    DCD      6
    DCD      77
    DCD      6
    DCD      232
    DCD      94
    DCD      224
    DCD      6
    DCD      93
    DCD      6
    DCD      212
    DCD      114
    DCD      208
    DCD      6
    DCD      105
    DCD      6
    DCD      208
    DCD      6
    DCD      105
    DCD      6
    DCD      208
    DCD      6
    DCD      105
    DCD      6
    DCD      208
    DCD      10
    DCD      8
    DCD      98
    DCD      220
    DCD      6
    DCD      85
    DCD      6
    DCD      228
    DCD      6
    DCD      85
    DCD      6
    DCD      228
    DCD      6
    DCD      85
    DCD      6
    DCD      228
    DCD      6
    DCD      85
    DCD      6
    DCD      228
    DCD      6
    DCD      85
    DCD      6
    DCD      228
    DCD      6
    DCD      85
    DCD      6
    DCD      228
    DCD      6
    DCD      85
    DCD      6
    DCD      228
    DCD      6
    DCD      85
    DCD      6
    DCD      228
    DCD      6
    DCD      85
    DCD      6
    DCD      228
    DCD      6
    DCD      85
    DCD      6
    DCD      228
    DCD      6
    DCD      85
    DCD      6
    DCD      228
    DCD      6
    DCD      85
    DCD      6
    DCD      228
    DCD      6
    DCD      85
    DCD      6
    DCD      228
    DCD      6
    DCD      85
    DCD      6
    DCD      228
    DCD      6
    DCD      85
    DCD      6
    DCD      228
    DCD      6
    DCD      85
    DCD      6
    DCD      228
    DCD      6
    DCD      85
    DCD      6
    DCD      228
    DCD      6
    DCD      85
    DCD      6
    DCD      228
    DCD      6
    DCD      85
    DCD      6
    DCD      216
    DCD      118
    DCD      204
    DCD      6
    DCD      109
    DCD      6
    DCD      200
    DCD      126
    DCD      192
    DCD      10
    DCD      117
    DCD      10
    DCD      188
    DCD      10
    DCD      117
    DCD      10
    DCD      188
    DCD      10
    DCD      117
    DCD      10
    DCD      188
    DCD      10
    DCD      117
    DCD      14
    DCD      180
    DCD      142
    DCD      180
    DCD      6
    DCD      133
    DCD      6
    DCD      180
    DCD      6
    DCD      133
    DCD      6
    DCD      180
    DCD      6
    DCD      133
    DCD      6
    DCD      180
    DCD      142
    DCD      184
    DCD      134
    DCD      192
    DCD      126
    DCD      1376
;---------------------------------------------------------------------------
get_pawn_array:
    ADR     r0, _g_pawn_array
    MOV     pc, lr
_g_pawn_array:
     DCD      211
    DCD      3988
    DCD      34
    DCD      276
    DCD      14
    DCD      33
    DCD      10
    DCD      264
    DCD      10
    DCD      45
    DCD      10
    DCD      252
    DCD      10
    DCD      61
    DCD      6
    DCD      244
    DCD      10
    DCD      69
    DCD      10
    DCD      236
    DCD      6
    DCD      77
    DCD      6
    DCD      232
    DCD      6
    DCD      85
    DCD      6
    DCD      224
    DCD      6
    DCD      93
    DCD      6
    DCD      220
    DCD      6
    DCD      93
    DCD      6
    DCD      220
    DCD      6
    DCD      93
    DCD      6
    DCD      220
    DCD      6
    DCD      93
    DCD      6
    DCD      220
    DCD      6
    DCD      93
    DCD      6
    DCD      216
    DCD      6
    DCD      101
    DCD      6
    DCD      212
    DCD      6
    DCD      101
    DCD      6
    DCD      216
    DCD      6
    DCD      93
    DCD      6
    DCD      220
    DCD      6
    DCD      93
    DCD      6
    DCD      220
    DCD      6
    DCD      93
    DCD      6
    DCD      220
    DCD      6
    DCD      93
    DCD      6
    DCD      224
    DCD      6
    DCD      85
    DCD      6
    DCD      228
    DCD      6
    DCD      85
    DCD      6
    DCD      232
    DCD      6
    DCD      77
    DCD      6
    DCD      240
    DCD      6
    DCD      69
    DCD      10
    DCD      220
    DCD      122
    DCD      196
    DCD      6
    DCD      117
    DCD      6
    DCD      196
    DCD      6
    DCD      117
    DCD      6
    DCD      196
    DCD      126
    DCD      216
    DCD      6
    DCD      73
    DCD      6
    DCD      240
    DCD      6
    DCD      73
    DCD      6
    DCD      240
    DCD      6
    DCD      73
    DCD      6
    DCD      240
    DCD      6
    DCD      77
    DCD      6
    DCD      232
    DCD      10
    DCD      77
    DCD      6
    DCD      232
    DCD      6
    DCD      81
    DCD      6
    DCD      232
    DCD      6
    DCD      81
    DCD      6
    DCD      232
    DCD      6
    DCD      81
    DCD      6
    DCD      228
    DCD      10
    DCD      85
    DCD      6
    DCD      224
    DCD      6
    DCD      89
    DCD      6
    DCD      224
    DCD      6
    DCD      89
    DCD      6
    DCD      224
    DCD      6
    DCD      89
    DCD      6
    DCD      212
    DCD      18
    DCD      89
    DCD      18
    DCD      200
    DCD      126
    DCD      196
    DCD      6
    DCD      117
    DCD      10
    DCD      180
    DCD      150
    DCD      172
    DCD      6
    DCD      141
    DCD      6
    DCD      172
    DCD      6
    DCD      141
    DCD      6
    DCD      172
    DCD      6
    DCD      141
    DCD      6
    DCD      172
    DCD      6
    DCD      141
    DCD      6
    DCD      172
    DCD      6
    DCD      141
    DCD      6
    DCD      172
    DCD      6
    DCD      141
    DCD      6
    DCD      172
    DCD      6
    DCD      141
    DCD      6
    DCD      160
    DCD      18
    DCD      141
    DCD      18
    DCD      148
    DCD      174
    DCD      148
    DCD      6
    DCD      165
    DCD      6
    DCD      148
    DCD      6
    DCD      165
    DCD      6
    DCD      148
    DCD      6
    DCD      165
    DCD      6
    DCD      148
    DCD      6
    DCD      165
    DCD      6
    DCD      152
    DCD      166
    DCD      3916
;---------------------------------------------------------------------------
get_queen_array:
    ADR     r0, _g_queen_array
    MOV     pc, lr
_g_queen_array:    
    DCD      267
    DCD      2068
    DCD      26
    DCD      292
    DCD      6
    DCD      25
    DCD      6
    DCD      268
    DCD      18
    DCD      4
    DCD      6
    DCD      25
    DCD      6
    DCD      4
    DCD      18
    DCD      244
    DCD      6
    DCD      17
    DCD      10
    DCD      25
    DCD      10
    DCD      17
    DCD      6
    DCD      232
    DCD      14
    DCD      17
    DCD      10
    DCD      25
    DCD      10
    DCD      17
    DCD      14
    DCD      224
    DCD      6
    DCD      89
    DCD      6
    DCD      224
    DCD      6
    DCD      89
    DCD      6
    DCD      224
    DCD      10
    DCD      81
    DCD      10
    DCD      228
    DCD      6
    DCD      81
    DCD      6
    DCD      232
    DCD      6
    DCD      81
    DCD      6
    DCD      232
    DCD      10
    DCD      77
    DCD      6
    DCD      236
    DCD      6
    DCD      73
    DCD      10
    DCD      236
    DCD      6
    DCD      73
    DCD      6
    DCD      244
    DCD      6
    DCD      69
    DCD      6
    DCD      244
    DCD      6
    DCD      65
    DCD      10
    DCD      244
    DCD      6
    DCD      65
    DCD      6
    DCD      248
    DCD      10
    DCD      61
    DCD      6
    DCD      252
    DCD      6
    DCD      57
    DCD      10
    DCD      252
    DCD      6
    DCD      57
    DCD      6
    DCD      256
    DCD      10
    DCD      49
    DCD      10
    DCD      256
    DCD      66
    DCD      256
    DCD      10
    DCD      49
    DCD      10
    DCD      256
    DCD      6
    DCD      57
    DCD      6
    DCD      248
    DCD      78
    DCD      244
    DCD      6
    DCD      73
    DCD      6
    DCD      232
    DCD      98
    DCD      224
    DCD      6
    DCD      89
    DCD      6
    DCD      224
    DCD      6
    DCD      89
    DCD      6
    DCD      224
    DCD      6
    DCD      89
    DCD      6
    DCD      224
    DCD      98
    DCD      224
    DCD      26
    DCD      49
    DCD      26
    DCD      244
    DCD      6
    DCD      49
    DCD      6
    DCD      264
    DCD      6
    DCD      49
    DCD      6
    DCD      264
    DCD      6
    DCD      49
    DCD      6
    DCD      260
    DCD      10
    DCD      49
    DCD      10
    DCD      256
    DCD      6
    DCD      57
    DCD      6
    DCD      256
    DCD      6
    DCD      57
    DCD      6
    DCD      256
    DCD      6
    DCD      57
    DCD      6
    DCD      256
    DCD      6
    DCD      57
    DCD      6
    DCD      256
    DCD      6
    DCD      57
    DCD      6
    DCD      256
    DCD      6
    DCD      57
    DCD      6
    DCD      256
    DCD      6
    DCD      57
    DCD      6
    DCD      252
    DCD      10
    DCD      57
    DCD      10
    DCD      248
    DCD      10
    DCD      57
    DCD      10
    DCD      248
    DCD      6
    DCD      65
    DCD      6
    DCD      248
    DCD      6
    DCD      65
    DCD      6
    DCD      248
    DCD      6
    DCD      65
    DCD      6
    DCD      248
    DCD      6
    DCD      65
    DCD      6
    DCD      248
    DCD      6
    DCD      65
    DCD      6
    DCD      248
    DCD      6
    DCD      65
    DCD      6
    DCD      244
    DCD      10
    DCD      65
    DCD      10
    DCD      240
    DCD      10
    DCD      65
    DCD      10
    DCD      240
    DCD      10
    DCD      65
    DCD      10
    DCD      240
    DCD      6
    DCD      73
    DCD      6
    DCD      232
    DCD      98
    DCD      224
    DCD      6
    DCD      89
    DCD      6
    DCD      216
    DCD      114
    DCD      208
    DCD      6
    DCD      105
    DCD      6
    DCD      208
    DCD      6
    DCD      105
    DCD      6
    DCD      208
    DCD      6
    DCD      105
    DCD      6
    DCD      208
    DCD      6
    DCD      105
    DCD      6
    DCD      208
    DCD      6
    DCD      105
    DCD      6
    DCD      204
    DCD      122
    DCD      196
    DCD      6
    DCD      121
    DCD      6
    DCD      192
    DCD      6
    DCD      121
    DCD      6
    DCD      192
    DCD      6
    DCD      121
    DCD      6
    DCD      192
    DCD      6
    DCD      121
    DCD      6
    DCD      196
    DCD      122
    DCD      2020
;----------------------------------------------------------------------------
get_rook_array:
    ADR     r0, _g_rook_array
    MOV     pc, lr
_g_rook_array:
    DCD      299
    DCD      1348
    DCD      6
    DCD      988
    DCD      34
    DCD      12
    DCD      34
    DCD      12
    DCD      34
    DCD      196
    DCD      6
    DCD      33
    DCD      6
    DCD      4
    DCD      6
    DCD      33
    DCD      6
    DCD      4
    DCD      6
    DCD      33
    DCD      6
    DCD      192
    DCD      6
    DCD      33
    DCD      6
    DCD      4
    DCD      6
    DCD      33
    DCD      6
    DCD      4
    DCD      6
    DCD      33
    DCD      6
    DCD      192
    DCD      6
    DCD      33
    DCD      6
    DCD      4
    DCD      6
    DCD      33
    DCD      6
    DCD      4
    DCD      6
    DCD      33
    DCD      6
    DCD      192
    DCD      6
    DCD      33
    DCD      6
    DCD      4
    DCD      6
    DCD      33
    DCD      6
    DCD      4
    DCD      6
    DCD      33
    DCD      6
    DCD      192
    DCD      6
    DCD      33
    DCD      14
    DCD      33
    DCD      14
    DCD      33
    DCD      6
    DCD      192
    DCD      6
    DCD      121
    DCD      6
    DCD      192
    DCD      6
    DCD      121
    DCD      6
    DCD      192
    DCD      6
    DCD      121
    DCD      6
    DCD      192
    DCD      6
    DCD      121
    DCD      6
    DCD      192
    DCD      6
    DCD      121
    DCD      6
    DCD      192
    DCD      6
    DCD      121
    DCD      6
    DCD      192
    DCD      6
    DCD      121
    DCD      6
    DCD      192
    DCD      6
    DCD      121
    DCD      6
    DCD      192
    DCD      6
    DCD      121
    DCD      6
    DCD      192
    DCD      6
    DCD      121
    DCD      6
    DCD      192
    DCD      42
    DCD      49
    DCD      42
    DCD      192
    DCD      42
    DCD      49
    DCD      42
    DCD      192
    DCD      6
    DCD      121
    DCD      6
    DCD      192
    DCD      6
    DCD      121
    DCD      6
    DCD      192
    DCD      6
    DCD      121
    DCD      6
    DCD      192
    DCD      6
    DCD      121
    DCD      6
    DCD      192
    DCD      34
    DCD      65
    DCD      34
    DCD      220
    DCD      6
    DCD      65
    DCD      6
    DCD      244
    DCD      10
    DCD      65
    DCD      10
    DCD      240
    DCD      6
    DCD      73
    DCD      6
    DCD      240
    DCD      6
    DCD      73
    DCD      6
    DCD      240
    DCD      6
    DCD      73
    DCD      6
    DCD      240
    DCD      6
    DCD      73
    DCD      6
    DCD      240
    DCD      6
    DCD      73
    DCD      6
    DCD      240
    DCD      6
    DCD      73
    DCD      6
    DCD      240
    DCD      6
    DCD      73
    DCD      6
    DCD      240
    DCD      6
    DCD      73
    DCD      10
    DCD      236
    DCD      6
    DCD      77
    DCD      6
    DCD      232
    DCD      6
    DCD      81
    DCD      6
    DCD      232
    DCD      6
    DCD      81
    DCD      6
    DCD      232
    DCD      6
    DCD      81
    DCD      6
    DCD      232
    DCD      6
    DCD      81
    DCD      6
    DCD      232
    DCD      6
    DCD      81
    DCD      6
    DCD      232
    DCD      6
    DCD      81
    DCD      6
    DCD      232
    DCD      6
    DCD      81
    DCD      6
    DCD      228
    DCD      10
    DCD      81
    DCD      10
    DCD      224
    DCD      6
    DCD      89
    DCD      6
    DCD      224
    DCD      6
    DCD      89
    DCD      6
    DCD      224
    DCD      6
    DCD      89
    DCD      6
    DCD      224
    DCD      6
    DCD      89
    DCD      6
    DCD      224
    DCD      6
    DCD      89
    DCD      6
    DCD      220
    DCD      10
    DCD      89
    DCD      10
    DCD      208
    DCD      18
    DCD      93
    DCD      14
    DCD      200
    DCD      126
    DCD      196
    DCD      6
    DCD      117
    DCD      6
    DCD      188
    DCD      138
    DCD      180
    DCD      6
    DCD      137
    DCD      6
    DCD      176
    DCD      6
    DCD      137
    DCD      6
    DCD      176
    DCD      6
    DCD      137
    DCD      6
    DCD      176
    DCD      6
    DCD      137
    DCD      6
    DCD      176
    DCD      6
    DCD      137
    DCD      6
    DCD      176
    DCD      6
    DCD      137
    DCD      6
    DCD      176
    DCD      6
    DCD      137
    DCD      6
    DCD      164
    DCD      170
    DCD      152
    DCD      6
    DCD      161
    DCD      6
    DCD      152
    DCD      6
    DCD      161
    DCD      6
    DCD      152
    DCD      6
    DCD      161
    DCD      6
    DCD      152
    DCD      6
    DCD      161
    DCD      6
    DCD      152
    DCD      6
    DCD      161
    DCD      6
    DCD      152
    DCD      170
    DCD      160
    DCD      154
    DCD      2004

;-----------------------------------------------------------------------------
;                           GAME OVER MESSAGE HERE
get_game_over_array:
    ADR     r0, _g_game_over_array
    MOV     pc, lr
_g_game_over_array:
    DCD      5699
    DCD      484468
    DCD      66
    DCD      2472
    DCD      22
    DCD      73
    DCD      22
    DCD      2432
    DCD      14
    DCD      121
    DCD      18
    DCD      288
    DCD      66
    DCD      216
    DCD      90
    DCD      212
    DCD      90
    DCD      104
    DCD      270
    DCD      1072
    DCD      10
    DCD      153
    DCD      14
    DCD      272
    DCD      6
    DCD      65
    DCD      6
    DCD      212
    DCD      6
    DCD      85
    DCD      6
    DCD      204
    DCD      6
    DCD      85
    DCD      6
    DCD      104
    DCD      6
    DCD      261
    DCD      6
    DCD      1060
    DCD      10
    DCD      177
    DCD      14
    DCD      260
    DCD      6
    DCD      65
    DCD      6
    DCD      212
    DCD      6
    DCD      85
    DCD      6
    DCD      204
    DCD      6
    DCD      85
    DCD      6
    DCD      104
    DCD      6
    DCD      261
    DCD      6
    DCD      1052
    DCD      10
    DCD      197
    DCD      10
    DCD      248
    DCD      6
    DCD      73
    DCD      6
    DCD      208
    DCD      6
    DCD      89
    DCD      204
    DCD      6
    DCD      85
    DCD      6
    DCD      104
    DCD      6
    DCD      261
    DCD      6
    DCD      1044
    DCD      10
    DCD      217
    DCD      10
    DCD      236
    DCD      6
    DCD      73
    DCD      6
    DCD      208
    DCD      6
    DCD      89
    DCD      6
    DCD      196
    DCD      6
    DCD      89
    DCD      6
    DCD      104
    DCD      6
    DCD      261
    DCD      6
    DCD      1036
    DCD      10
    DCD      233
    DCD      10
    DCD      228
    DCD      6
    DCD      73
    DCD      6
    DCD      208
    DCD      6
    DCD      89
    DCD      6
    DCD      196
    DCD      6
    DCD      89
    DCD      6
    DCD      104
    DCD      6
    DCD      261
    DCD      6
    DCD      1032
    DCD      6
    DCD      249
    DCD      6
    DCD      220
    DCD      6
    DCD      81
    DCD      6
    DCD      204
    DCD      6
    DCD      93
    DCD      196
    DCD      93
    DCD      6
    DCD      104
    DCD      6
    DCD      261
    DCD      6
    DCD      1024
    DCD      10
    DCD      261
    DCD      6
    DCD      212
    DCD      6
    DCD      81
    DCD      6
    DCD      204
    DCD      6
    DCD      93
    DCD      6
    DCD      188
    DCD      6
    DCD      93
    DCD      6
    DCD      104
    DCD      6
    DCD      261
    DCD      6
    DCD      1020
    DCD      6
    DCD      273
    DCD      6
    DCD      208
    DCD      89
    DCD      204
    DCD      6
    DCD      93
    DCD      6
    DCD      188
    DCD      6
    DCD      93
    DCD      6
    DCD      104
    DCD      6
    DCD      261
    DCD      6
    DCD      1016
    DCD      6
    DCD      281
    DCD      6
    DCD      200
    DCD      6
    DCD      89
    DCD      6
    DCD      200
    DCD      6
    DCD      97
    DCD      6
    DCD      180
    DCD      6
    DCD      97
    DCD      6
    DCD      104
    DCD      6
    DCD      261
    DCD      6
    DCD      1008
    DCD      10
    DCD      105
    DCD      14
    DCD      8
    DCD      10
    DCD      24
    DCD      10
    DCD      8
    DCD      14
    DCD      101
    DCD      6
    DCD      200
    DCD      6
    DCD      89
    DCD      6
    DCD      200
    DCD      6
    DCD      97
    DCD      6
    DCD      180
    DCD      6
    DCD      97
    DCD      6
    DCD      104
    DCD      6
    DCD      261
    DCD      6
    DCD      1004
    DCD      10
    DCD      93
    DCD      6
    DCD      4
    DCD      6
    DCD      88
    DCD      14
    DCD      85
    DCD      6
    DCD      196
    DCD      6
    DCD      97
    DCD      6
    DCD      196
    DCD      6
    DCD      101
    DCD      180
    DCD      6
    DCD      97
    DCD      6
    DCD      104
    DCD      6
    DCD      261
    DCD      6
    DCD      1000
    DCD      10
    DCD      85
    DCD      6
    DCD      128
    DCD      6
    DCD      73
    DCD      6
    DCD      196
    DCD      6
    DCD      97
    DCD      6
    DCD      196
    DCD      6
    DCD      101
    DCD      6
    DCD      172
    DCD      6
    DCD      101
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      210
    DCD      996
    DCD      10
    DCD      77
    DCD      10
    DCD      148
    DCD      6
    DCD      61
    DCD      6
    DCD      196
    DCD      6
    DCD      97
    DCD      6
    DCD      196
    DCD      6
    DCD      53
    DCD      6
    DCD      45
    DCD      6
    DCD      172
    DCD      6
    DCD      45
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1200
    DCD      6
    DCD      73
    DCD      10
    DCD      160
    DCD      14
    DCD      49
    DCD      6
    DCD      192
    DCD      6
    DCD      49
    DCD      10
    DCD      49
    DCD      6
    DCD      192
    DCD      6
    DCD      53
    DCD      6
    DCD      49
    DCD      6
    DCD      164
    DCD      6
    DCD      49
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1196
    DCD      6
    DCD      73
    DCD      6
    DCD      176
    DCD      14
    DCD      41
    DCD      6
    DCD      192
    DCD      6
    DCD      49
    DCD      10
    DCD      49
    DCD      6
    DCD      192
    DCD      6
    DCD      53
    DCD      10
    DCD      45
    DCD      6
    DCD      164
    DCD      6
    DCD      45
    DCD      10
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1192
    DCD      6
    DCD      69
    DCD      6
    DCD      192
    DCD      10
    DCD      37
    DCD      6
    DCD      192
    DCD      53
    DCD      10
    DCD      53
    DCD      192
    DCD      6
    DCD      53
    DCD      10
    DCD      45
    DCD      6
    DCD      164
    DCD      6
    DCD      45
    DCD      10
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1188
    DCD      6
    DCD      69
    DCD      10
    DCD      204
    DCD      6
    DCD      29
    DCD      6
    DCD      188
    DCD      6
    DCD      49
    DCD      6
    DCD      8
    DCD      6
    DCD      49
    DCD      6
    DCD      188
    DCD      6
    DCD      53
    DCD      6
    DCD      4
    DCD      6
    DCD      45
    DCD      6
    DCD      156
    DCD      6
    DCD      45
    DCD      6
    DCD      4
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1188
    DCD      6
    DCD      65
    DCD      6
    DCD      216
    DCD      6
    DCD      25
    DCD      6
    DCD      188
    DCD      6
    DCD      49
    DCD      6
    DCD      8
    DCD      6
    DCD      49
    DCD      6
    DCD      188
    DCD      6
    DCD      53
    DCD      6
    DCD      4
    DCD      6
    DCD      45
    DCD      6
    DCD      156
    DCD      6
    DCD      45
    DCD      6
    DCD      4
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1184
    DCD      6
    DCD      65
    DCD      6
    DCD      224
    DCD      10
    DCD      17
    DCD      6
    DCD      184
    DCD      6
    DCD      53
    DCD      6
    DCD      8
    DCD      6
    DCD      53
    DCD      6
    DCD      184
    DCD      6
    DCD      53
    DCD      6
    DCD      4
    DCD      6
    DCD      49
    DCD      156
    DCD      6
    DCD      45
    DCD      6
    DCD      4
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1180
    DCD      6
    DCD      65
    DCD      6
    DCD      236
    DCD      6
    DCD      13
    DCD      6
    DCD      184
    DCD      6
    DCD      49
    DCD      6
    DCD      16
    DCD      6
    DCD      49
    DCD      6
    DCD      184
    DCD      6
    DCD      53
    DCD      6
    DCD      8
    DCD      6
    DCD      45
    DCD      6
    DCD      148
    DCD      6
    DCD      45
    DCD      6
    DCD      8
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1180
    DCD      6
    DCD      61
    DCD      6
    DCD      244
    DCD      6
    DCD      9
    DCD      6
    DCD      184
    DCD      6
    DCD      49
    DCD      6
    DCD      16
    DCD      6
    DCD      53
    DCD      184
    DCD      6
    DCD      53
    DCD      6
    DCD      8
    DCD      6
    DCD      45
    DCD      6
    DCD      148
    DCD      6
    DCD      45
    DCD      6
    DCD      8
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1176
    DCD      6
    DCD      61
    DCD      10
    DCD      248
    DCD      6
    DCD      5
    DCD      6
    DCD      180
    DCD      6
    DCD      49
    DCD      6
    DCD      24
    DCD      53
    DCD      6
    DCD      180
    DCD      6
    DCD      53
    DCD      6
    DCD      12
    DCD      6
    DCD      45
    DCD      6
    DCD      140
    DCD      6
    DCD      45
    DCD      6
    DCD      12
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1176
    DCD      6
    DCD      61
    DCD      6
    DCD      256
    DCD      6
    DCD      184
    DCD      6
    DCD      49
    DCD      6
    DCD      24
    DCD      6
    DCD      49
    DCD      6
    DCD      180
    DCD      6
    DCD      53
    DCD      6
    DCD      12
    DCD      6
    DCD      45
    DCD      6
    DCD      140
    DCD      6
    DCD      45
    DCD      6
    DCD      12
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1172
    DCD      6
    DCD      61
    DCD      6
    DCD      444
    DCD      6
    DCD      53
    DCD      6
    DCD      24
    DCD      6
    DCD      53
    DCD      6
    DCD      176
    DCD      6
    DCD      53
    DCD      6
    DCD      12
    DCD      6
    DCD      45
    DCD      6
    DCD      140
    DCD      6
    DCD      45
    DCD      6
    DCD      12
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1172
    DCD      6
    DCD      57
    DCD      10
    DCD      444
    DCD      6
    DCD      49
    DCD      6
    DCD      32
    DCD      6
    DCD      49
    DCD      6
    DCD      176
    DCD      6
    DCD      53
    DCD      6
    DCD      16
    DCD      6
    DCD      45
    DCD      6
    DCD      132
    DCD      6
    DCD      45
    DCD      6
    DCD      16
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1168
    DCD      6
    DCD      61
    DCD      6
    DCD      448
    DCD      6
    DCD      49
    DCD      6
    DCD      32
    DCD      6
    DCD      49
    DCD      6
    DCD      176
    DCD      6
    DCD      53
    DCD      6
    DCD      16
    DCD      6
    DCD      45
    DCD      6
    DCD      132
    DCD      6
    DCD      45
    DCD      6
    DCD      16
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1168
    DCD      6
    DCD      57
    DCD      6
    DCD      448
    DCD      6
    DCD      53
    DCD      6
    DCD      32
    DCD      6
    DCD      53
    DCD      6
    DCD      172
    DCD      6
    DCD      53
    DCD      6
    DCD      16
    DCD      6
    DCD      49
    DCD      132
    DCD      49
    DCD      6
    DCD      16
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1164
    DCD      6
    DCD      61
    DCD      6
    DCD      448
    DCD      6
    DCD      49
    DCD      6
    DCD      40
    DCD      6
    DCD      49
    DCD      6
    DCD      172
    DCD      6
    DCD      53
    DCD      6
    DCD      20
    DCD      6
    DCD      45
    DCD      6
    DCD      124
    DCD      6
    DCD      45
    DCD      6
    DCD      20
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1164
    DCD      6
    DCD      61
    DCD      452
    DCD      6
    DCD      49
    DCD      6
    DCD      40
    DCD      6
    DCD      53
    DCD      172
    DCD      6
    DCD      53
    DCD      6
    DCD      20
    DCD      6
    DCD      45
    DCD      6
    DCD      124
    DCD      6
    DCD      45
    DCD      6
    DCD      20
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1164
    DCD      6
    DCD      57
    DCD      6
    DCD      448
    DCD      6
    DCD      53
    DCD      48
    DCD      53
    DCD      6
    DCD      168
    DCD      6
    DCD      53
    DCD      6
    DCD      24
    DCD      6
    DCD      45
    DCD      6
    DCD      116
    DCD      6
    DCD      45
    DCD      6
    DCD      24
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1160
    DCD      6
    DCD      61
    DCD      6
    DCD      448
    DCD      6
    DCD      49
    DCD      6
    DCD      48
    DCD      6
    DCD      49
    DCD      6
    DCD      168
    DCD      6
    DCD      53
    DCD      6
    DCD      24
    DCD      6
    DCD      45
    DCD      6
    DCD      116
    DCD      6
    DCD      45
    DCD      6
    DCD      24
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1160
    DCD      6
    DCD      57
    DCD      6
    DCD      448
    DCD      6
    DCD      53
    DCD      6
    DCD      48
    DCD      6
    DCD      53
    DCD      6
    DCD      164
    DCD      6
    DCD      53
    DCD      6
    DCD      24
    DCD      6
    DCD      45
    DCD      6
    DCD      116
    DCD      6
    DCD      45
    DCD      6
    DCD      24
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1160
    DCD      6
    DCD      57
    DCD      6
    DCD      448
    DCD      6
    DCD      49
    DCD      6
    DCD      56
    DCD      6
    DCD      49
    DCD      6
    DCD      164
    DCD      6
    DCD      53
    DCD      6
    DCD      28
    DCD      6
    DCD      45
    DCD      6
    DCD      108
    DCD      6
    DCD      45
    DCD      6
    DCD      28
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1160
    DCD      61
    DCD      6
    DCD      448
    DCD      6
    DCD      49
    DCD      6
    DCD      56
    DCD      6
    DCD      49
    DCD      6
    DCD      164
    DCD      6
    DCD      53
    DCD      6
    DCD      28
    DCD      6
    DCD      45
    DCD      6
    DCD      108
    DCD      6
    DCD      45
    DCD      6
    DCD      28
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1156
    DCD      6
    DCD      57
    DCD      6
    DCD      448
    DCD      6
    DCD      53
    DCD      6
    DCD      56
    DCD      6
    DCD      53
    DCD      6
    DCD      160
    DCD      6
    DCD      53
    DCD      6
    DCD      32
    DCD      49
    DCD      108
    DCD      49
    DCD      32
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1156
    DCD      6
    DCD      57
    DCD      6
    DCD      448
    DCD      6
    DCD      49
    DCD      6
    DCD      64
    DCD      6
    DCD      49
    DCD      6
    DCD      160
    DCD      6
    DCD      53
    DCD      6
    DCD      32
    DCD      6
    DCD      45
    DCD      6
    DCD      100
    DCD      6
    DCD      45
    DCD      6
    DCD      32
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1156
    DCD      6
    DCD      57
    DCD      6
    DCD      448
    DCD      53
    DCD      6
    DCD      64
    DCD      6
    DCD      53
    DCD      160
    DCD      6
    DCD      53
    DCD      6
    DCD      32
    DCD      6
    DCD      45
    DCD      6
    DCD      100
    DCD      6
    DCD      45
    DCD      6
    DCD      32
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1156
    DCD      6
    DCD      57
    DCD      6
    DCD      444
    DCD      6
    DCD      53
    DCD      6
    DCD      68
    DCD      53
    DCD      6
    DCD      156
    DCD      6
    DCD      53
    DCD      6
    DCD      36
    DCD      6
    DCD      45
    DCD      6
    DCD      92
    DCD      6
    DCD      45
    DCD      6
    DCD      36
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1156
    DCD      61
    DCD      6
    DCD      444
    DCD      6
    DCD      49
    DCD      6
    DCD      72
    DCD      6
    DCD      49
    DCD      6
    DCD      156
    DCD      6
    DCD      53
    DCD      6
    DCD      36
    DCD      6
    DCD      45
    DCD      6
    DCD      92
    DCD      6
    DCD      45
    DCD      6
    DCD      36
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1152
    DCD      6
    DCD      57
    DCD      6
    DCD      444
    DCD      6
    DCD      53
    DCD      6
    DCD      72
    DCD      6
    DCD      53
    DCD      6
    DCD      152
    DCD      6
    DCD      53
    DCD      6
    DCD      36
    DCD      6
    DCD      45
    DCD      6
    DCD      92
    DCD      6
    DCD      45
    DCD      6
    DCD      36
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1152
    DCD      6
    DCD      57
    DCD      6
    DCD      444
    DCD      6
    DCD      49
    DCD      6
    DCD      80
    DCD      6
    DCD      49
    DCD      6
    DCD      152
    DCD      6
    DCD      53
    DCD      6
    DCD      40
    DCD      6
    DCD      45
    DCD      6
    DCD      84
    DCD      6
    DCD      45
    DCD      6
    DCD      40
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1152
    DCD      6
    DCD      57
    DCD      6
    DCD      444
    DCD      6
    DCD      49
    DCD      6
    DCD      80
    DCD      6
    DCD      49
    DCD      6
    DCD      152
    DCD      6
    DCD      53
    DCD      6
    DCD      40
    DCD      6
    DCD      45
    DCD      6
    DCD      84
    DCD      6
    DCD      45
    DCD      6
    DCD      40
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      202
    DCD      956
    DCD      6
    DCD      57
    DCD      6
    DCD      440
    DCD      6
    DCD      53
    DCD      6
    DCD      80
    DCD      6
    DCD      53
    DCD      6
    DCD      148
    DCD      6
    DCD      53
    DCD      6
    DCD      44
    DCD      49
    DCD      84
    DCD      49
    DCD      44
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      253
    DCD      6
    DCD      956
    DCD      6
    DCD      57
    DCD      6
    DCD      440
    DCD      6
    DCD      49
    DCD      6
    DCD      88
    DCD      6
    DCD      49
    DCD      6
    DCD      148
    DCD      6
    DCD      53
    DCD      6
    DCD      44
    DCD      6
    DCD      45
    DCD      6
    DCD      76
    DCD      6
    DCD      45
    DCD      6
    DCD      44
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      253
    DCD      6
    DCD      956
    DCD      6
    DCD      57
    DCD      6
    DCD      436
    DCD      6
    DCD      53
    DCD      6
    DCD      88
    DCD      6
    DCD      53
    DCD      148
    DCD      6
    DCD      53
    DCD      6
    DCD      44
    DCD      6
    DCD      45
    DCD      6
    DCD      76
    DCD      6
    DCD      45
    DCD      6
    DCD      44
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      253
    DCD      6
    DCD      956
    DCD      6
    DCD      57
    DCD      6
    DCD      436
    DCD      6
    DCD      53
    DCD      6
    DCD      88
    DCD      6
    DCD      53
    DCD      6
    DCD      144
    DCD      6
    DCD      53
    DCD      6
    DCD      48
    DCD      6
    DCD      45
    DCD      6
    DCD      68
    DCD      6
    DCD      45
    DCD      6
    DCD      48
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      253
    DCD      6
    DCD      956
    DCD      6
    DCD      57
    DCD      6
    DCD      436
    DCD      6
    DCD      49
    DCD      6
    DCD      96
    DCD      6
    DCD      49
    DCD      6
    DCD      144
    DCD      6
    DCD      53
    DCD      6
    DCD      48
    DCD      6
    DCD      45
    DCD      6
    DCD      68
    DCD      6
    DCD      45
    DCD      6
    DCD      48
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      253
    DCD      6
    DCD      956
    DCD      6
    DCD      57
    DCD      6
    DCD      432
    DCD      6
    DCD      53
    DCD      6
    DCD      96
    DCD      6
    DCD      53
    DCD      6
    DCD      140
    DCD      6
    DCD      53
    DCD      6
    DCD      48
    DCD      6
    DCD      45
    DCD      6
    DCD      68
    DCD      6
    DCD      45
    DCD      6
    DCD      48
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      253
    DCD      6
    DCD      952
    DCD      6
    DCD      61
    DCD      6
    DCD      432
    DCD      6
    DCD      53
    DCD      104
    DCD      53
    DCD      6
    DCD      140
    DCD      6
    DCD      53
    DCD      6
    DCD      52
    DCD      6
    DCD      45
    DCD      6
    DCD      60
    DCD      6
    DCD      45
    DCD      6
    DCD      52
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      253
    DCD      6
    DCD      952
    DCD      6
    DCD      61
    DCD      6
    DCD      148
    DCD      154
    DCD      132
    DCD      6
    DCD      49
    DCD      6
    DCD      104
    DCD      6
    DCD      53
    DCD      140
    DCD      6
    DCD      53
    DCD      6
    DCD      52
    DCD      6
    DCD      45
    DCD      6
    DCD      60
    DCD      6
    DCD      45
    DCD      6
    DCD      52
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      253
    DCD      6
    DCD      952
    DCD      6
    DCD      61
    DCD      6
    DCD      148
    DCD      6
    DCD      145
    DCD      6
    DCD      128
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      53
    DCD      6
    DCD      136
    DCD      6
    DCD      53
    DCD      6
    DCD      56
    DCD      49
    DCD      56
    DCD      6
    DCD      49
    DCD      56
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      253
    DCD      6
    DCD      952
    DCD      6
    DCD      61
    DCD      6
    DCD      148
    DCD      6
    DCD      145
    DCD      6
    DCD      128
    DCD      6
    DCD      49
    DCD      6
    DCD      112
    DCD      6
    DCD      49
    DCD      6
    DCD      136
    DCD      6
    DCD      53
    DCD      6
    DCD      56
    DCD      6
    DCD      45
    DCD      6
    DCD      52
    DCD      6
    DCD      45
    DCD      6
    DCD      56
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      253
    DCD      6
    DCD      952
    DCD      6
    DCD      61
    DCD      6
    DCD      148
    DCD      6
    DCD      145
    DCD      6
    DCD      124
    DCD      6
    DCD      53
    DCD      6
    DCD      112
    DCD      6
    DCD      53
    DCD      6
    DCD      132
    DCD      6
    DCD      53
    DCD      6
    DCD      56
    DCD      6
    DCD      45
    DCD      6
    DCD      52
    DCD      6
    DCD      45
    DCD      6
    DCD      56
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      253
    DCD      6
    DCD      952
    DCD      6
    DCD      61
    DCD      6
    DCD      148
    DCD      6
    DCD      145
    DCD      6
    DCD      124
    DCD      6
    DCD      53
    DCD      6
    DCD      112
    DCD      6
    DCD      53
    DCD      6
    DCD      132
    DCD      6
    DCD      53
    DCD      6
    DCD      60
    DCD      6
    DCD      45
    DCD      6
    DCD      44
    DCD      6
    DCD      45
    DCD      6
    DCD      60
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      253
    DCD      6
    DCD      952
    DCD      6
    DCD      61
    DCD      6
    DCD      148
    DCD      6
    DCD      145
    DCD      6
    DCD      124
    DCD      6
    DCD      49
    DCD      6
    DCD      120
    DCD      6
    DCD      49
    DCD      6
    DCD      132
    DCD      6
    DCD      53
    DCD      6
    DCD      60
    DCD      6
    DCD      45
    DCD      6
    DCD      44
    DCD      6
    DCD      45
    DCD      6
    DCD      60
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      202
    DCD      956
    DCD      6
    DCD      57
    DCD      6
    DCD      148
    DCD      6
    DCD      145
    DCD      6
    DCD      120
    DCD      6
    DCD      53
    DCD      6
    DCD      120
    DCD      6
    DCD      53
    DCD      6
    DCD      128
    DCD      6
    DCD      53
    DCD      6
    DCD      60
    DCD      6
    DCD      45
    DCD      6
    DCD      44
    DCD      6
    DCD      45
    DCD      6
    DCD      60
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1152
    DCD      6
    DCD      57
    DCD      6
    DCD      148
    DCD      6
    DCD      145
    DCD      6
    DCD      120
    DCD      6
    DCD      53
    DCD      6
    DCD      124
    DCD      53
    DCD      6
    DCD      128
    DCD      6
    DCD      53
    DCD      6
    DCD      64
    DCD      6
    DCD      45
    DCD      6
    DCD      36
    DCD      6
    DCD      45
    DCD      6
    DCD      64
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1152
    DCD      6
    DCD      57
    DCD      6
    DCD      148
    DCD      6
    DCD      145
    DCD      6
    DCD      120
    DCD      53
    DCD      6
    DCD      128
    DCD      6
    DCD      53
    DCD      128
    DCD      6
    DCD      53
    DCD      6
    DCD      64
    DCD      6
    DCD      45
    DCD      6
    DCD      36
    DCD      6
    DCD      45
    DCD      6
    DCD      64
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1152
    DCD      6
    DCD      57
    DCD      6
    DCD      148
    DCD      6
    DCD      145
    DCD      6
    DCD      116
    DCD      6
    DCD      53
    DCD      6
    DCD      128
    DCD      6
    DCD      53
    DCD      6
    DCD      124
    DCD      6
    DCD      53
    DCD      6
    DCD      68
    DCD      49
    DCD      32
    DCD      6
    DCD      49
    DCD      68
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1152
    DCD      6
    DCD      57
    DCD      6
    DCD      148
    DCD      6
    DCD      145
    DCD      6
    DCD      116
    DCD      6
    DCD      53
    DCD      136
    DCD      6
    DCD      49
    DCD      6
    DCD      124
    DCD      6
    DCD      53
    DCD      6
    DCD      68
    DCD      6
    DCD      45
    DCD      6
    DCD      28
    DCD      6
    DCD      45
    DCD      6
    DCD      68
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1152
    DCD      6
    DCD      57
    DCD      6
    DCD      148
    DCD      6
    DCD      145
    DCD      6
    DCD      112
    DCD      6
    DCD      53
    DCD      6
    DCD      136
    DCD      6
    DCD      53
    DCD      6
    DCD      120
    DCD      6
    DCD      53
    DCD      6
    DCD      68
    DCD      6
    DCD      45
    DCD      6
    DCD      28
    DCD      6
    DCD      45
    DCD      6
    DCD      68
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1152
    DCD      6
    DCD      57
    DCD      6
    DCD      240
    DCD      6
    DCD      53
    DCD      6
    DCD      112
    DCD      6
    DCD      53
    DCD      6
    DCD      136
    DCD      6
    DCD      53
    DCD      6
    DCD      120
    DCD      6
    DCD      53
    DCD      6
    DCD      72
    DCD      6
    DCD      45
    DCD      6
    DCD      20
    DCD      6
    DCD      45
    DCD      6
    DCD      72
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1152
    DCD      6
    DCD      57
    DCD      6
    DCD      240
    DCD      6
    DCD      53
    DCD      6
    DCD      112
    DCD      6
    DCD      49
    DCD      6
    DCD      144
    DCD      6
    DCD      49
    DCD      6
    DCD      120
    DCD      6
    DCD      53
    DCD      6
    DCD      72
    DCD      6
    DCD      45
    DCD      6
    DCD      20
    DCD      6
    DCD      45
    DCD      6
    DCD      72
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1152
    DCD      6
    DCD      57
    DCD      6
    DCD      240
    DCD      6
    DCD      53
    DCD      6
    DCD      108
    DCD      6
    DCD      53
    DCD      6
    DCD      144
    DCD      6
    DCD      53
    DCD      6
    DCD      116
    DCD      6
    DCD      53
    DCD      6
    DCD      72
    DCD      6
    DCD      45
    DCD      6
    DCD      20
    DCD      49
    DCD      6
    DCD      72
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1156
    DCD      61
    DCD      6
    DCD      236
    DCD      6
    DCD      53
    DCD      6
    DCD      108
    DCD      6
    DCD      53
    DCD      6
    DCD      144
    DCD      6
    DCD      53
    DCD      6
    DCD      116
    DCD      6
    DCD      53
    DCD      6
    DCD      76
    DCD      6
    DCD      45
    DCD      6
    DCD      12
    DCD      6
    DCD      45
    DCD      6
    DCD      76
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1156
    DCD      6
    DCD      57
    DCD      6
    DCD      236
    DCD      6
    DCD      53
    DCD      6
    DCD      108
    DCD      265
    DCD      116
    DCD      6
    DCD      53
    DCD      6
    DCD      76
    DCD      6
    DCD      45
    DCD      6
    DCD      12
    DCD      6
    DCD      45
    DCD      6
    DCD      76
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1156
    DCD      6
    DCD      57
    DCD      6
    DCD      236
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      265
    DCD      6
    DCD      112
    DCD      6
    DCD      53
    DCD      6
    DCD      80
    DCD      49
    DCD      8
    DCD      6
    DCD      49
    DCD      80
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1156
    DCD      6
    DCD      57
    DCD      6
    DCD      236
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      265
    DCD      6
    DCD      112
    DCD      6
    DCD      53
    DCD      6
    DCD      80
    DCD      6
    DCD      45
    DCD      6
    DCD      4
    DCD      6
    DCD      45
    DCD      6
    DCD      80
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1156
    DCD      6
    DCD      61
    DCD      236
    DCD      6
    DCD      53
    DCD      6
    DCD      100
    DCD      6
    DCD      273
    DCD      6
    DCD      108
    DCD      6
    DCD      53
    DCD      6
    DCD      80
    DCD      6
    DCD      45
    DCD      6
    DCD      4
    DCD      6
    DCD      45
    DCD      6
    DCD      80
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1160
    DCD      6
    DCD      57
    DCD      6
    DCD      232
    DCD      6
    DCD      53
    DCD      6
    DCD      100
    DCD      6
    DCD      273
    DCD      6
    DCD      108
    DCD      6
    DCD      53
    DCD      6
    DCD      84
    DCD      6
    DCD      45
    DCD      6
    DCD      45
    DCD      6
    DCD      84
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1160
    DCD      6
    DCD      57
    DCD      6
    DCD      232
    DCD      6
    DCD      53
    DCD      6
    DCD      100
    DCD      6
    DCD      277
    DCD      108
    DCD      6
    DCD      53
    DCD      6
    DCD      84
    DCD      6
    DCD      93
    DCD      6
    DCD      84
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1160
    DCD      6
    DCD      57
    DCD      6
    DCD      232
    DCD      6
    DCD      53
    DCD      6
    DCD      96
    DCD      6
    DCD      281
    DCD      6
    DCD      104
    DCD      6
    DCD      53
    DCD      6
    DCD      84
    DCD      6
    DCD      93
    DCD      6
    DCD      84
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1160
    DCD      6
    DCD      61
    DCD      6
    DCD      228
    DCD      6
    DCD      53
    DCD      6
    DCD      96
    DCD      6
    DCD      281
    DCD      6
    DCD      104
    DCD      6
    DCD      53
    DCD      6
    DCD      88
    DCD      6
    DCD      85
    DCD      6
    DCD      88
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1164
    DCD      6
    DCD      57
    DCD      6
    DCD      228
    DCD      6
    DCD      53
    DCD      6
    DCD      92
    DCD      6
    DCD      289
    DCD      6
    DCD      100
    DCD      6
    DCD      53
    DCD      6
    DCD      88
    DCD      6
    DCD      85
    DCD      6
    DCD      88
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1164
    DCD      6
    DCD      61
    DCD      228
    DCD      6
    DCD      53
    DCD      6
    DCD      92
    DCD      6
    DCD      289
    DCD      6
    DCD      100
    DCD      6
    DCD      53
    DCD      6
    DCD      92
    DCD      81
    DCD      6
    DCD      92
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1164
    DCD      6
    DCD      61
    DCD      6
    DCD      224
    DCD      6
    DCD      53
    DCD      6
    DCD      92
    DCD      6
    DCD      289
    DCD      6
    DCD      100
    DCD      6
    DCD      53
    DCD      6
    DCD      92
    DCD      6
    DCD      77
    DCD      6
    DCD      92
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1168
    DCD      6
    DCD      57
    DCD      6
    DCD      224
    DCD      6
    DCD      53
    DCD      6
    DCD      88
    DCD      6
    DCD      53
    DCD      194
    DCD      53
    DCD      6
    DCD      96
    DCD      6
    DCD      53
    DCD      6
    DCD      92
    DCD      6
    DCD      77
    DCD      6
    DCD      92
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1168
    DCD      6
    DCD      61
    DCD      6
    DCD      220
    DCD      6
    DCD      53
    DCD      6
    DCD      88
    DCD      6
    DCD      53
    DCD      6
    DCD      184
    DCD      6
    DCD      53
    DCD      6
    DCD      96
    DCD      6
    DCD      53
    DCD      6
    DCD      96
    DCD      6
    DCD      69
    DCD      6
    DCD      96
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1172
    DCD      6
    DCD      57
    DCD      6
    DCD      220
    DCD      6
    DCD      53
    DCD      6
    DCD      88
    DCD      57
    DCD      192
    DCD      6
    DCD      53
    DCD      96
    DCD      6
    DCD      53
    DCD      6
    DCD      96
    DCD      6
    DCD      69
    DCD      6
    DCD      96
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1172
    DCD      6
    DCD      61
    DCD      6
    DCD      216
    DCD      6
    DCD      53
    DCD      6
    DCD      84
    DCD      6
    DCD      53
    DCD      6
    DCD      192
    DCD      6
    DCD      53
    DCD      6
    DCD      92
    DCD      6
    DCD      53
    DCD      6
    DCD      96
    DCD      6
    DCD      69
    DCD      6
    DCD      96
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1176
    DCD      6
    DCD      61
    DCD      6
    DCD      212
    DCD      6
    DCD      53
    DCD      6
    DCD      84
    DCD      6
    DCD      53
    DCD      6
    DCD      192
    DCD      6
    DCD      53
    DCD      6
    DCD      92
    DCD      6
    DCD      53
    DCD      6
    DCD      100
    DCD      6
    DCD      61
    DCD      6
    DCD      100
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1176
    DCD      6
    DCD      61
    DCD      10
    DCD      208
    DCD      6
    DCD      53
    DCD      6
    DCD      80
    DCD      6
    DCD      53
    DCD      6
    DCD      200
    DCD      6
    DCD      53
    DCD      6
    DCD      88
    DCD      6
    DCD      53
    DCD      6
    DCD      100
    DCD      6
    DCD      61
    DCD      6
    DCD      100
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1180
    DCD      6
    DCD      61
    DCD      6
    DCD      208
    DCD      6
    DCD      53
    DCD      6
    DCD      80
    DCD      6
    DCD      53
    DCD      6
    DCD      200
    DCD      6
    DCD      53
    DCD      6
    DCD      88
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1180
    DCD      6
    DCD      65
    DCD      6
    DCD      204
    DCD      6
    DCD      53
    DCD      6
    DCD      80
    DCD      6
    DCD      53
    DCD      6
    DCD      200
    DCD      6
    DCD      53
    DCD      6
    DCD      88
    DCD      6
    DCD      53
    DCD      6
    DCD      108
    DCD      54
    DCD      108
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1184
    DCD      6
    DCD      65
    DCD      6
    DCD      200
    DCD      6
    DCD      53
    DCD      6
    DCD      76
    DCD      6
    DCD      53
    DCD      6
    DCD      208
    DCD      6
    DCD      53
    DCD      6
    DCD      84
    DCD      6
    DCD      53
    DCD      6
    DCD      268
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1188
    DCD      6
    DCD      65
    DCD      6
    DCD      196
    DCD      6
    DCD      53
    DCD      6
    DCD      76
    DCD      6
    DCD      53
    DCD      6
    DCD      208
    DCD      6
    DCD      53
    DCD      6
    DCD      84
    DCD      6
    DCD      53
    DCD      6
    DCD      268
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1188
    DCD      6
    DCD      69
    DCD      6
    DCD      192
    DCD      6
    DCD      53
    DCD      6
    DCD      76
    DCD      57
    DCD      6
    DCD      212
    DCD      57
    DCD      84
    DCD      6
    DCD      53
    DCD      6
    DCD      268
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1192
    DCD      6
    DCD      69
    DCD      10
    DCD      184
    DCD      6
    DCD      53
    DCD      6
    DCD      72
    DCD      6
    DCD      53
    DCD      6
    DCD      216
    DCD      6
    DCD      53
    DCD      6
    DCD      80
    DCD      6
    DCD      53
    DCD      6
    DCD      268
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1196
    DCD      6
    DCD      73
    DCD      6
    DCD      180
    DCD      6
    DCD      53
    DCD      6
    DCD      72
    DCD      6
    DCD      53
    DCD      6
    DCD      216
    DCD      6
    DCD      53
    DCD      6
    DCD      80
    DCD      6
    DCD      53
    DCD      6
    DCD      268
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1200
    DCD      6
    DCD      73
    DCD      10
    DCD      164
    DCD      10
    DCD      57
    DCD      6
    DCD      68
    DCD      6
    DCD      57
    DCD      6
    DCD      220
    DCD      57
    DCD      6
    DCD      76
    DCD      6
    DCD      53
    DCD      6
    DCD      268
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1200
    DCD      10
    DCD      77
    DCD      10
    DCD      148
    DCD      10
    DCD      65
    DCD      6
    DCD      68
    DCD      6
    DCD      53
    DCD      6
    DCD      224
    DCD      6
    DCD      53
    DCD      6
    DCD      76
    DCD      6
    DCD      53
    DCD      6
    DCD      268
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      1204
    DCD      10
    DCD      85
    DCD      10
    DCD      124
    DCD      14
    DCD      73
    DCD      6
    DCD      68
    DCD      6
    DCD      53
    DCD      6
    DCD      224
    DCD      6
    DCD      53
    DCD      6
    DCD      76
    DCD      6
    DCD      53
    DCD      6
    DCD      268
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      218
    DCD      996
    DCD      10
    DCD      93
    DCD      14
    DCD      92
    DCD      18
    DCD      85
    DCD      6
    DCD      64
    DCD      6
    DCD      57
    DCD      6
    DCD      228
    DCD      6
    DCD      53
    DCD      6
    DCD      72
    DCD      6
    DCD      53
    DCD      6
    DCD      268
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      269
    DCD      6
    DCD      1000
    DCD      10
    DCD      105
    DCD      26
    DCD      28
    DCD      34
    DCD      105
    DCD      6
    DCD      64
    DCD      6
    DCD      53
    DCD      6
    DCD      232
    DCD      6
    DCD      53
    DCD      6
    DCD      72
    DCD      6
    DCD      53
    DCD      6
    DCD      268
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      269
    DCD      6
    DCD      1008
    DCD      6
    DCD      285
    DCD      6
    DCD      64
    DCD      6
    DCD      57
    DCD      6
    DCD      232
    DCD      6
    DCD      57
    DCD      72
    DCD      6
    DCD      53
    DCD      6
    DCD      268
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      269
    DCD      6
    DCD      1012
    DCD      6
    DCD      273
    DCD      10
    DCD      68
    DCD      6
    DCD      57
    DCD      240
    DCD      6
    DCD      53
    DCD      6
    DCD      68
    DCD      6
    DCD      53
    DCD      6
    DCD      268
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      269
    DCD      6
    DCD      1020
    DCD      6
    DCD      257
    DCD      10
    DCD      76
    DCD      6
    DCD      53
    DCD      6
    DCD      240
    DCD      6
    DCD      53
    DCD      6
    DCD      68
    DCD      6
    DCD      53
    DCD      6
    DCD      268
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      269
    DCD      6
    DCD      1024
    DCD      10
    DCD      245
    DCD      10
    DCD      76
    DCD      6
    DCD      57
    DCD      6
    DCD      240
    DCD      6
    DCD      57
    DCD      6
    DCD      64
    DCD      6
    DCD      53
    DCD      6
    DCD      268
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      269
    DCD      6
    DCD      1028
    DCD      10
    DCD      233
    DCD      10
    DCD      84
    DCD      6
    DCD      57
    DCD      248
    DCD      6
    DCD      53
    DCD      6
    DCD      64
    DCD      6
    DCD      53
    DCD      6
    DCD      268
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      269
    DCD      6
    DCD      1036
    DCD      10
    DCD      217
    DCD      10
    DCD      92
    DCD      57
    DCD      6
    DCD      248
    DCD      6
    DCD      57
    DCD      64
    DCD      6
    DCD      53
    DCD      6
    DCD      268
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      269
    DCD      6
    DCD      1044
    DCD      10
    DCD      197
    DCD      10
    DCD      100
    DCD      6
    DCD      57
    DCD      6
    DCD      248
    DCD      6
    DCD      57
    DCD      6
    DCD      60
    DCD      6
    DCD      53
    DCD      6
    DCD      268
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      269
    DCD      6
    DCD      1056
    DCD      6
    DCD      177
    DCD      10
    DCD      112
    DCD      6
    DCD      53
    DCD      6
    DCD      256
    DCD      6
    DCD      53
    DCD      6
    DCD      60
    DCD      6
    DCD      53
    DCD      6
    DCD      268
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      269
    DCD      6
    DCD      1064
    DCD      10
    DCD      153
    DCD      10
    DCD      120
    DCD      6
    DCD      57
    DCD      6
    DCD      256
    DCD      6
    DCD      57
    DCD      6
    DCD      56
    DCD      6
    DCD      53
    DCD      6
    DCD      268
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      269
    DCD      6
    DCD      1080
    DCD      10
    DCD      121
    DCD      18
    DCD      128
    DCD      66
    DCD      256
    DCD      66
    DCD      56
    DCD      62
    DCD      268
    DCD      62
    DCD      104
    DCD      278
    DCD      1096
    DCD      18
    DCD      73
    DCD      22
    DCD      2472
    DCD      6
    DCD      8
    DCD      38
    DCD      12
    DCD      6
    DCD      151000
    DCD      30
    DCD      29
    DCD      30
    DCD      2460
    DCD      14
    DCD      93
    DCD      14
    DCD      600
    DCD      270
    DCD      96
    DCD      150
    DCD      1320
    DCD      10
    DCD      125
    DCD      10
    DCD      148
    DCD      6
    DCD      53
    DCD      6
    DCD      260
    DCD      6
    DCD      53
    DCD      6
    DCD      60
    DCD      6
    DCD      261
    DCD      6
    DCD      92
    DCD      6
    DCD      141
    DCD      30
    DCD      1288
    DCD      10
    DCD      149
    DCD      10
    DCD      136
    DCD      6
    DCD      57
    DCD      6
    DCD      252
    DCD      6
    DCD      57
    DCD      6
    DCD      60
    DCD      6
    DCD      261
    DCD      6
    DCD      92
    DCD      6
    DCD      173
    DCD      18
    DCD      1260
    DCD      10
    DCD      165
    DCD      10
    DCD      132
    DCD      57
    DCD      6
    DCD      252
    DCD      6
    DCD      57
    DCD      64
    DCD      6
    DCD      261
    DCD      6
    DCD      92
    DCD      6
    DCD      189
    DCD      14
    DCD      1240
    DCD      10
    DCD      181
    DCD      10
    DCD      124
    DCD      6
    DCD      57
    DCD      252
    DCD      6
    DCD      53
    DCD      6
    DCD      64
    DCD      6
    DCD      261
    DCD      6
    DCD      92
    DCD      6
    DCD      201
    DCD      10
    DCD      1228
    DCD      6
    DCD      197
    DCD      6
    DCD      120
    DCD      6
    DCD      57
    DCD      6
    DCD      244
    DCD      6
    DCD      57
    DCD      6
    DCD      64
    DCD      6
    DCD      261
    DCD      6
    DCD      92
    DCD      6
    DCD      209
    DCD      10
    DCD      1212
    DCD      10
    DCD      205
    DCD      10
    DCD      116
    DCD      6
    DCD      53
    DCD      6
    DCD      244
    DCD      6
    DCD      53
    DCD      6
    DCD      68
    DCD      6
    DCD      261
    DCD      6
    DCD      92
    DCD      6
    DCD      217
    DCD      10
    DCD      1200
    DCD      6
    DCD      221
    DCD      6
    DCD      112
    DCD      6
    DCD      57
    DCD      244
    DCD      57
    DCD      6
    DCD      68
    DCD      6
    DCD      261
    DCD      6
    DCD      92
    DCD      6
    DCD      225
    DCD      6
    DCD      1188
    DCD      10
    DCD      229
    DCD      10
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      236
    DCD      6
    DCD      57
    DCD      6
    DCD      68
    DCD      6
    DCD      261
    DCD      6
    DCD      92
    DCD      6
    DCD      229
    DCD      6
    DCD      1180
    DCD      10
    DCD      237
    DCD      10
    DCD      104
    DCD      6
    DCD      53
    DCD      6
    DCD      236
    DCD      6
    DCD      53
    DCD      6
    DCD      72
    DCD      6
    DCD      261
    DCD      6
    DCD      92
    DCD      6
    DCD      233
    DCD      6
    DCD      1172
    DCD      6
    DCD      105
    DCD      46
    DCD      105
    DCD      6
    DCD      100
    DCD      6
    DCD      57
    DCD      6
    DCD      228
    DCD      6
    DCD      57
    DCD      6
    DCD      72
    DCD      6
    DCD      261
    DCD      6
    DCD      92
    DCD      6
    DCD      237
    DCD      6
    DCD      1164
    DCD      6
    DCD      93
    DCD      6
    DCD      60
    DCD      6
    DCD      4
    DCD      10
    DCD      89
    DCD      6
    DCD      100
    DCD      57
    DCD      6
    DCD      228
    DCD      6
    DCD      57
    DCD      76
    DCD      6
    DCD      261
    DCD      6
    DCD      92
    DCD      6
    DCD      241
    DCD      6
    DCD      1156
    DCD      6
    DCD      85
    DCD      6
    DCD      88
    DCD      10
    DCD      85
    DCD      6
    DCD      96
    DCD      6
    DCD      57
    DCD      228
    DCD      6
    DCD      53
    DCD      6
    DCD      76
    DCD      6
    DCD      261
    DCD      6
    DCD      92
    DCD      6
    DCD      53
    DCD      98
    DCD      97
    DCD      6
    DCD      1148
    DCD      6
    DCD      81
    DCD      10
    DCD      104
    DCD      6
    DCD      81
    DCD      6
    DCD      92
    DCD      6
    DCD      57
    DCD      6
    DCD      220
    DCD      6
    DCD      57
    DCD      6
    DCD      76
    DCD      6
    DCD      53
    DCD      214
    DCD      92
    DCD      6
    DCD      53
    DCD      6
    DCD      100
    DCD      10
    DCD      85
    DCD      6
    DCD      1140
    DCD      6
    DCD      77
    DCD      10
    DCD      116
    DCD      10
    DCD      77
    DCD      6
    DCD      92
    DCD      6
    DCD      53
    DCD      6
    DCD      220
    DCD      6
    DCD      53
    DCD      6
    DCD      80
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      108
    DCD      10
    DCD      77
    DCD      6
    DCD      1136
    DCD      10
    DCD      69
    DCD      6
    DCD      136
    DCD      10
    DCD      69
    DCD      6
    DCD      92
    DCD      6
    DCD      57
    DCD      220
    DCD      57
    DCD      6
    DCD      80
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      116
    DCD      10
    DCD      73
    DCD      6
    DCD      1132
    DCD      6
    DCD      69
    DCD      6
    DCD      148
    DCD      6
    DCD      69
    DCD      6
    DCD      88
    DCD      6
    DCD      57
    DCD      6
    DCD      212
    DCD      6
    DCD      57
    DCD      6
    DCD      80
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      124
    DCD      6
    DCD      69
    DCD      6
    DCD      1128
    DCD      6
    DCD      69
    DCD      6
    DCD      156
    DCD      6
    DCD      69
    DCD      6
    DCD      88
    DCD      6
    DCD      53
    DCD      6
    DCD      212
    DCD      6
    DCD      53
    DCD      6
    DCD      84
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      128
    DCD      6
    DCD      69
    DCD      6
    DCD      1120
    DCD      6
    DCD      69
    DCD      6
    DCD      164
    DCD      6
    DCD      69
    DCD      6
    DCD      84
    DCD      6
    DCD      57
    DCD      6
    DCD      204
    DCD      6
    DCD      57
    DCD      6
    DCD      84
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      132
    DCD      6
    DCD      65
    DCD      6
    DCD      1120
    DCD      6
    DCD      65
    DCD      10
    DCD      168
    DCD      6
    DCD      65
    DCD      6
    DCD      88
    DCD      6
    DCD      53
    DCD      6
    DCD      204
    DCD      6
    DCD      53
    DCD      6
    DCD      88
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      136
    DCD      6
    DCD      61
    DCD      6
    DCD      1116
    DCD      6
    DCD      65
    DCD      6
    DCD      180
    DCD      6
    DCD      65
    DCD      6
    DCD      84
    DCD      6
    DCD      57
    DCD      204
    DCD      6
    DCD      53
    DCD      6
    DCD      88
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      140
    DCD      6
    DCD      61
    DCD      6
    DCD      1108
    DCD      6
    DCD      65
    DCD      6
    DCD      188
    DCD      6
    DCD      65
    DCD      84
    DCD      6
    DCD      57
    DCD      6
    DCD      196
    DCD      6
    DCD      57
    DCD      6
    DCD      88
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      140
    DCD      6
    DCD      61
    DCD      6
    DCD      1108
    DCD      6
    DCD      61
    DCD      6
    DCD      196
    DCD      6
    DCD      61
    DCD      6
    DCD      84
    DCD      6
    DCD      53
    DCD      6
    DCD      196
    DCD      6
    DCD      53
    DCD      6
    DCD      92
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      144
    DCD      6
    DCD      57
    DCD      6
    DCD      1104
    DCD      6
    DCD      65
    DCD      6
    DCD      196
    DCD      6
    DCD      65
    DCD      6
    DCD      80
    DCD      6
    DCD      57
    DCD      192
    DCD      6
    DCD      57
    DCD      6
    DCD      92
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      144
    DCD      6
    DCD      57
    DCD      6
    DCD      1104
    DCD      6
    DCD      61
    DCD      6
    DCD      204
    DCD      6
    DCD      61
    DCD      6
    DCD      84
    DCD      57
    DCD      6
    DCD      188
    DCD      6
    DCD      57
    DCD      96
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      144
    DCD      6
    DCD      61
    DCD      1100
    DCD      6
    DCD      61
    DCD      6
    DCD      212
    DCD      6
    DCD      61
    DCD      6
    DCD      80
    DCD      6
    DCD      53
    DCD      6
    DCD      188
    DCD      6
    DCD      53
    DCD      6
    DCD      96
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      148
    DCD      61
    DCD      6
    DCD      1096
    DCD      6
    DCD      61
    DCD      6
    DCD      212
    DCD      6
    DCD      61
    DCD      6
    DCD      80
    DCD      6
    DCD      57
    DCD      6
    DCD      180
    DCD      6
    DCD      57
    DCD      6
    DCD      96
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      148
    DCD      6
    DCD      57
    DCD      6
    DCD      1096
    DCD      61
    DCD      6
    DCD      220
    DCD      6
    DCD      61
    DCD      84
    DCD      6
    DCD      53
    DCD      6
    DCD      180
    DCD      6
    DCD      53
    DCD      6
    DCD      100
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      148
    DCD      6
    DCD      57
    DCD      6
    DCD      1092
    DCD      6
    DCD      61
    DCD      6
    DCD      220
    DCD      6
    DCD      61
    DCD      6
    DCD      80
    DCD      6
    DCD      57
    DCD      180
    DCD      6
    DCD      53
    DCD      6
    DCD      100
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      148
    DCD      6
    DCD      57
    DCD      6
    DCD      1092
    DCD      6
    DCD      57
    DCD      6
    DCD      228
    DCD      6
    DCD      57
    DCD      6
    DCD      80
    DCD      6
    DCD      57
    DCD      6
    DCD      172
    DCD      6
    DCD      57
    DCD      6
    DCD      100
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      148
    DCD      6
    DCD      57
    DCD      6
    DCD      1088
    DCD      6
    DCD      61
    DCD      6
    DCD      228
    DCD      6
    DCD      61
    DCD      6
    DCD      80
    DCD      6
    DCD      53
    DCD      6
    DCD      172
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      148
    DCD      6
    DCD      57
    DCD      6
    DCD      1088
    DCD      6
    DCD      61
    DCD      236
    DCD      61
    DCD      6
    DCD      80
    DCD      6
    DCD      57
    DCD      168
    DCD      6
    DCD      57
    DCD      6
    DCD      104
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      148
    DCD      6
    DCD      57
    DCD      6
    DCD      1088
    DCD      6
    DCD      57
    DCD      6
    DCD      236
    DCD      6
    DCD      57
    DCD      6
    DCD      84
    DCD      57
    DCD      6
    DCD      164
    DCD      6
    DCD      57
    DCD      108
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      148
    DCD      6
    DCD      57
    DCD      6
    DCD      1088
    DCD      61
    DCD      6
    DCD      236
    DCD      6
    DCD      61
    DCD      84
    DCD      6
    DCD      53
    DCD      6
    DCD      164
    DCD      6
    DCD      53
    DCD      6
    DCD      108
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      148
    DCD      6
    DCD      57
    DCD      6
    DCD      1084
    DCD      6
    DCD      61
    DCD      244
    DCD      61
    DCD      6
    DCD      80
    DCD      6
    DCD      57
    DCD      6
    DCD      156
    DCD      6
    DCD      57
    DCD      6
    DCD      108
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      148
    DCD      6
    DCD      57
    DCD      6
    DCD      1084
    DCD      6
    DCD      57
    DCD      6
    DCD      244
    DCD      6
    DCD      57
    DCD      6
    DCD      84
    DCD      6
    DCD      53
    DCD      6
    DCD      156
    DCD      6
    DCD      53
    DCD      6
    DCD      112
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      148
    DCD      6
    DCD      57
    DCD      6
    DCD      1084
    DCD      6
    DCD      57
    DCD      6
    DCD      244
    DCD      6
    DCD      57
    DCD      6
    DCD      84
    DCD      6
    DCD      57
    DCD      156
    DCD      6
    DCD      53
    DCD      6
    DCD      112
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      144
    DCD      6
    DCD      61
    DCD      1088
    DCD      61
    DCD      6
    DCD      244
    DCD      6
    DCD      61
    DCD      84
    DCD      6
    DCD      57
    DCD      6
    DCD      148
    DCD      6
    DCD      57
    DCD      6
    DCD      112
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      144
    DCD      6
    DCD      57
    DCD      6
    DCD      1084
    DCD      6
    DCD      61
    DCD      252
    DCD      61
    DCD      6
    DCD      84
    DCD      6
    DCD      53
    DCD      6
    DCD      148
    DCD      6
    DCD      53
    DCD      6
    DCD      116
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      144
    DCD      6
    DCD      57
    DCD      6
    DCD      1084
    DCD      6
    DCD      57
    DCD      6
    DCD      252
    DCD      6
    DCD      57
    DCD      6
    DCD      84
    DCD      6
    DCD      57
    DCD      144
    DCD      6
    DCD      57
    DCD      6
    DCD      116
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      140
    DCD      6
    DCD      61
    DCD      6
    DCD      1084
    DCD      6
    DCD      57
    DCD      6
    DCD      252
    DCD      6
    DCD      57
    DCD      6
    DCD      88
    DCD      6
    DCD      53
    DCD      6
    DCD      140
    DCD      6
    DCD      53
    DCD      6
    DCD      120
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      140
    DCD      6
    DCD      61
    DCD      6
    DCD      1084
    DCD      6
    DCD      57
    DCD      6
    DCD      252
    DCD      6
    DCD      57
    DCD      6
    DCD      88
    DCD      6
    DCD      53
    DCD      6
    DCD      140
    DCD      6
    DCD      53
    DCD      6
    DCD      120
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      136
    DCD      6
    DCD      61
    DCD      6
    DCD      1088
    DCD      6
    DCD      57
    DCD      6
    DCD      252
    DCD      6
    DCD      57
    DCD      6
    DCD      88
    DCD      6
    DCD      57
    DCD      6
    DCD      132
    DCD      6
    DCD      57
    DCD      6
    DCD      120
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      136
    DCD      6
    DCD      61
    DCD      6
    DCD      1088
    DCD      61
    DCD      260
    DCD      61
    DCD      92
    DCD      6
    DCD      53
    DCD      6
    DCD      132
    DCD      6
    DCD      53
    DCD      6
    DCD      124
    DCD      6
    DCD      53
    DCD      206
    DCD      100
    DCD      6
    DCD      53
    DCD      6
    DCD      132
    DCD      6
    DCD      65
    DCD      1092
    DCD      61
    DCD      260
    DCD      61
    DCD      92
    DCD      6
    DCD      57
    DCD      132
    DCD      6
    DCD      53
    DCD      6
    DCD      124
    DCD      6
    DCD      253
    DCD      6
    DCD      100
    DCD      6
    DCD      53
    DCD      6
    DCD      128
    DCD      6
    DCD      65
    DCD      6
    DCD      1088
    DCD      6
    DCD      57
    DCD      6
    DCD      260
    DCD      6
    DCD      57
    DCD      6
    DCD      92
    DCD      57
    DCD      6
    DCD      124
    DCD      6
    DCD      57
    DCD      6
    DCD      124
    DCD      6
    DCD      253
    DCD      6
    DCD      100
    DCD      6
    DCD      53
    DCD      6
    DCD      124
    DCD      6
    DCD      65
    DCD      10
    DCD      1088
    DCD      6
    DCD      57
    DCD      6
    DCD      260
    DCD      6
    DCD      57
    DCD      6
    DCD      92
    DCD      6
    DCD      53
    DCD      6
    DCD      124
    DCD      6
    DCD      53
    DCD      6
    DCD      128
    DCD      6
    DCD      253
    DCD      6
    DCD      100
    DCD      6
    DCD      53
    DCD      6
    DCD      116
    DCD      10
    DCD      69
    DCD      6
    DCD      1092
    DCD      6
    DCD      57
    DCD      6
    DCD      260
    DCD      6
    DCD      57
    DCD      6
    DCD      92
    DCD      6
    DCD      57
    DCD      6
    DCD      116
    DCD      6
    DCD      57
    DCD      6
    DCD      128
    DCD      6
    DCD      253
    DCD      6
    DCD      100
    DCD      6
    DCD      53
    DCD      6
    DCD      108
    DCD      10
    DCD      73
    DCD      6
    DCD      1096
    DCD      6
    DCD      57
    DCD      6
    DCD      260
    DCD      6
    DCD      57
    DCD      6
    DCD      96
    DCD      6
    DCD      53
    DCD      6
    DCD      116
    DCD      6
    DCD      53
    DCD      6
    DCD      132
    DCD      6
    DCD      253
    DCD      6
    DCD      100
    DCD      6
    DCD      53
    DCD      6
    DCD      96
    DCD      14
    DCD      77
    DCD      6
    DCD      1100
    DCD      6
    DCD      57
    DCD      6
    DCD      260
    DCD      6
    DCD      57
    DCD      6
    DCD      96
    DCD      6
    DCD      53
    DCD      6
    DCD      116
    DCD      6
    DCD      53
    DCD      6
    DCD      132
    DCD      6
    DCD      253
    DCD      6
    DCD      100
    DCD      6
    DCD      53
    DCD      94
    DCD      93
    DCD      10
    DCD      1100
    DCD      6
    DCD      57
    DCD      6
    DCD      260
    DCD      6
    DCD      57
    DCD      6
    DCD      96
    DCD      6
    DCD      57
    DCD      6
    DCD      108
    DCD      6
    DCD      57
    DCD      6
    DCD      132
    DCD      6
    DCD      253
    DCD      6
    DCD      100
    DCD      6
    DCD      233
    DCD      10
    DCD      1104
    DCD      6
    DCD      57
    DCD      6
    DCD      260
    DCD      6
    DCD      57
    DCD      6
    DCD      100
    DCD      6
    DCD      53
    DCD      6
    DCD      108
    DCD      6
    DCD      53
    DCD      6
    DCD      136
    DCD      6
    DCD      253
    DCD      6
    DCD      100
    DCD      6
    DCD      229
    DCD      6
    DCD      1112
    DCD      6
    DCD      57
    DCD      6
    DCD      260
    DCD      6
    DCD      57
    DCD      6
    DCD      100
    DCD      6
    DCD      57
    DCD      108
    DCD      6
    DCD      53
    DCD      6
    DCD      136
    DCD      6
    DCD      253
    DCD      6
    DCD      100
    DCD      6
    DCD      225
    DCD      6
    DCD      1116
    DCD      6
    DCD      57
    DCD      6
    DCD      260
    DCD      6
    DCD      57
    DCD      6
    DCD      104
    DCD      57
    DCD      6
    DCD      100
    DCD      6
    DCD      57
    DCD      140
    DCD      6
    DCD      253
    DCD      6
    DCD      100
    DCD      6
    DCD      217
    DCD      10
    DCD      1120
    DCD      6
    DCD      57
    DCD      6
    DCD      260
    DCD      6
    DCD      57
    DCD      6
    DCD      104
    DCD      6
    DCD      53
    DCD      6
    DCD      100
    DCD      6
    DCD      53
    DCD      6
    DCD      140
    DCD      6
    DCD      253
    DCD      6
    DCD      100
    DCD      6
    DCD      209
    DCD      6
    DCD      1132
    DCD      6
    DCD      57
    DCD      6
    DCD      260
    DCD      6
    DCD      57
    DCD      6
    DCD      104
    DCD      6
    DCD      57
    DCD      6
    DCD      92
    DCD      6
    DCD      57
    DCD      6
    DCD      140
    DCD      6
    DCD      53
    DCD      206
    DCD      100
    DCD      6
    DCD      197
    DCD      14
    DCD      1136
    DCD      6
    DCD      57
    DCD      6
    DCD      260
    DCD      6
    DCD      57
    DCD      6
    DCD      108
    DCD      6
    DCD      53
    DCD      6
    DCD      92
    DCD      6
    DCD      53
    DCD      6
    DCD      144
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      193
    DCD      10
    DCD      1144
    DCD      6
    DCD      57
    DCD      6
    DCD      260
    DCD      6
    DCD      57
    DCD      6
    DCD      108
    DCD      6
    DCD      53
    DCD      6
    DCD      92
    DCD      6
    DCD      53
    DCD      6
    DCD      144
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      201
    DCD      10
    DCD      1136
    DCD      6
    DCD      57
    DCD      6
    DCD      260
    DCD      6
    DCD      57
    DCD      6
    DCD      108
    DCD      6
    DCD      57
    DCD      6
    DCD      84
    DCD      6
    DCD      57
    DCD      6
    DCD      144
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      209
    DCD      6
    DCD      1132
    DCD      6
    DCD      57
    DCD      6
    DCD      260
    DCD      6
    DCD      57
    DCD      6
    DCD      112
    DCD      6
    DCD      53
    DCD      6
    DCD      84
    DCD      6
    DCD      53
    DCD      6
    DCD      148
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      213
    DCD      10
    DCD      1124
    DCD      6
    DCD      57
    DCD      6
    DCD      260
    DCD      6
    DCD      57
    DCD      6
    DCD      112
    DCD      6
    DCD      57
    DCD      84
    DCD      6
    DCD      53
    DCD      6
    DCD      148
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      221
    DCD      6
    DCD      1124
    DCD      61
    DCD      260
    DCD      61
    DCD      6
    DCD      116
    DCD      6
    DCD      53
    DCD      6
    DCD      76
    DCD      6
    DCD      57
    DCD      152
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      82
    DCD      4
    DCD      14
    DCD      77
    DCD      6
    DCD      1120
    DCD      61
    DCD      260
    DCD      61
    DCD      6
    DCD      116
    DCD      6
    DCD      53
    DCD      6
    DCD      76
    DCD      6
    DCD      53
    DCD      6
    DCD      152
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      92
    DCD      10
    DCD      73
    DCD      6
    DCD      1116
    DCD      6
    DCD      57
    DCD      6
    DCD      252
    DCD      6
    DCD      57
    DCD      6
    DCD      120
    DCD      6
    DCD      57
    DCD      6
    DCD      68
    DCD      6
    DCD      57
    DCD      6
    DCD      152
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      104
    DCD      6
    DCD      65
    DCD      10
    DCD      1112
    DCD      6
    DCD      57
    DCD      6
    DCD      252
    DCD      6
    DCD      57
    DCD      6
    DCD      124
    DCD      6
    DCD      53
    DCD      6
    DCD      68
    DCD      6
    DCD      53
    DCD      6
    DCD      156
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      108
    DCD      10
    DCD      61
    DCD      6
    DCD      1112
    DCD      6
    DCD      57
    DCD      6
    DCD      252
    DCD      6
    DCD      57
    DCD      6
    DCD      124
    DCD      6
    DCD      53
    DCD      6
    DCD      68
    DCD      6
    DCD      53
    DCD      6
    DCD      156
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      116
    DCD      6
    DCD      61
    DCD      6
    DCD      1108
    DCD      6
    DCD      57
    DCD      6
    DCD      252
    DCD      6
    DCD      57
    DCD      6
    DCD      128
    DCD      57
    DCD      6
    DCD      60
    DCD      6
    DCD      57
    DCD      6
    DCD      156
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      120
    DCD      6
    DCD      61
    DCD      6
    DCD      1104
    DCD      6
    DCD      61
    DCD      252
    DCD      61
    DCD      6
    DCD      128
    DCD      6
    DCD      53
    DCD      6
    DCD      60
    DCD      6
    DCD      53
    DCD      6
    DCD      160
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      124
    DCD      6
    DCD      57
    DCD      6
    DCD      1108
    DCD      61
    DCD      6
    DCD      244
    DCD      6
    DCD      61
    DCD      132
    DCD      6
    DCD      57
    DCD      60
    DCD      57
    DCD      6
    DCD      160
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      124
    DCD      6
    DCD      61
    DCD      6
    DCD      1104
    DCD      6
    DCD      57
    DCD      6
    DCD      244
    DCD      6
    DCD      57
    DCD      6
    DCD      136
    DCD      6
    DCD      53
    DCD      6
    DCD      52
    DCD      6
    DCD      53
    DCD      6
    DCD      164
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      128
    DCD      6
    DCD      61
    DCD      6
    DCD      1100
    DCD      6
    DCD      57
    DCD      6
    DCD      244
    DCD      6
    DCD      57
    DCD      6
    DCD      136
    DCD      6
    DCD      53
    DCD      6
    DCD      52
    DCD      6
    DCD      53
    DCD      6
    DCD      164
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      132
    DCD      6
    DCD      57
    DCD      6
    DCD      1100
    DCD      6
    DCD      61
    DCD      244
    DCD      61
    DCD      6
    DCD      136
    DCD      6
    DCD      57
    DCD      6
    DCD      44
    DCD      6
    DCD      57
    DCD      6
    DCD      164
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      136
    DCD      6
    DCD      57
    DCD      6
    DCD      1100
    DCD      61
    DCD      6
    DCD      236
    DCD      6
    DCD      61
    DCD      144
    DCD      6
    DCD      53
    DCD      6
    DCD      44
    DCD      6
    DCD      53
    DCD      6
    DCD      168
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      136
    DCD      6
    DCD      57
    DCD      6
    DCD      1100
    DCD      6
    DCD      57
    DCD      6
    DCD      236
    DCD      6
    DCD      57
    DCD      6
    DCD      144
    DCD      6
    DCD      53
    DCD      6
    DCD      44
    DCD      6
    DCD      53
    DCD      6
    DCD      168
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      140
    DCD      6
    DCD      57
    DCD      6
    DCD      1096
    DCD      6
    DCD      61
    DCD      236
    DCD      61
    DCD      6
    DCD      148
    DCD      57
    DCD      6
    DCD      36
    DCD      6
    DCD      57
    DCD      172
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      140
    DCD      6
    DCD      61
    DCD      1096
    DCD      6
    DCD      61
    DCD      6
    DCD      228
    DCD      6
    DCD      61
    DCD      6
    DCD      148
    DCD      6
    DCD      53
    DCD      6
    DCD      36
    DCD      6
    DCD      53
    DCD      6
    DCD      172
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      144
    DCD      6
    DCD      57
    DCD      6
    DCD      1096
    DCD      6
    DCD      57
    DCD      6
    DCD      228
    DCD      6
    DCD      57
    DCD      6
    DCD      152
    DCD      6
    DCD      57
    DCD      36
    DCD      57
    DCD      6
    DCD      172
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      144
    DCD      6
    DCD      61
    DCD      1096
    DCD      6
    DCD      61
    DCD      6
    DCD      220
    DCD      6
    DCD      61
    DCD      6
    DCD      156
    DCD      6
    DCD      53
    DCD      6
    DCD      28
    DCD      6
    DCD      53
    DCD      6
    DCD      176
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      148
    DCD      6
    DCD      57
    DCD      6
    DCD      1096
    DCD      61
    DCD      6
    DCD      220
    DCD      6
    DCD      57
    DCD      6
    DCD      160
    DCD      6
    DCD      53
    DCD      6
    DCD      28
    DCD      6
    DCD      53
    DCD      6
    DCD      176
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      148
    DCD      6
    DCD      61
    DCD      1096
    DCD      6
    DCD      61
    DCD      6
    DCD      212
    DCD      6
    DCD      61
    DCD      6
    DCD      160
    DCD      6
    DCD      57
    DCD      6
    DCD      20
    DCD      6
    DCD      57
    DCD      6
    DCD      176
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      152
    DCD      6
    DCD      57
    DCD      6
    DCD      1092
    DCD      6
    DCD      61
    DCD      6
    DCD      212
    DCD      6
    DCD      61
    DCD      6
    DCD      164
    DCD      6
    DCD      53
    DCD      6
    DCD      20
    DCD      6
    DCD      53
    DCD      6
    DCD      180
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      152
    DCD      6
    DCD      61
    DCD      1096
    DCD      6
    DCD      61
    DCD      6
    DCD      204
    DCD      6
    DCD      61
    DCD      6
    DCD      168
    DCD      6
    DCD      53
    DCD      6
    DCD      20
    DCD      6
    DCD      53
    DCD      6
    DCD      180
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      156
    DCD      6
    DCD      57
    DCD      6
    DCD      1092
    DCD      6
    DCD      65
    DCD      6
    DCD      196
    DCD      6
    DCD      65
    DCD      6
    DCD      172
    DCD      6
    DCD      53
    DCD      6
    DCD      12
    DCD      6
    DCD      57
    DCD      184
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      156
    DCD      6
    DCD      61
    DCD      6
    DCD      1092
    DCD      6
    DCD      61
    DCD      6
    DCD      192
    DCD      10
    DCD      61
    DCD      6
    DCD      176
    DCD      6
    DCD      53
    DCD      6
    DCD      12
    DCD      6
    DCD      53
    DCD      6
    DCD      184
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      160
    DCD      6
    DCD      57
    DCD      6
    DCD      1092
    DCD      6
    DCD      65
    DCD      6
    DCD      188
    DCD      6
    DCD      65
    DCD      6
    DCD      176
    DCD      6
    DCD      57
    DCD      12
    DCD      57
    DCD      6
    DCD      184
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      160
    DCD      6
    DCD      61
    DCD      6
    DCD      1092
    DCD      6
    DCD      65
    DCD      6
    DCD      180
    DCD      6
    DCD      65
    DCD      6
    DCD      184
    DCD      6
    DCD      53
    DCD      6
    DCD      4
    DCD      6
    DCD      53
    DCD      6
    DCD      188
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      164
    DCD      6
    DCD      57
    DCD      6
    DCD      1096
    DCD      6
    DCD      65
    DCD      6
    DCD      172
    DCD      6
    DCD      65
    DCD      6
    DCD      188
    DCD      6
    DCD      53
    DCD      6
    DCD      4
    DCD      6
    DCD      53
    DCD      6
    DCD      188
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      164
    DCD      6
    DCD      61
    DCD      6
    DCD      1092
    DCD      6
    DCD      69
    DCD      6
    DCD      164
    DCD      6
    DCD      69
    DCD      6
    DCD      192
    DCD      57
    DCD      6
    DCD      57
    DCD      6
    DCD      188
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      168
    DCD      6
    DCD      57
    DCD      6
    DCD      1096
    DCD      6
    DCD      69
    DCD      6
    DCD      156
    DCD      6
    DCD      69
    DCD      6
    DCD      196
    DCD      6
    DCD      53
    DCD      6
    DCD      53
    DCD      6
    DCD      192
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      168
    DCD      6
    DCD      61
    DCD      6
    DCD      1096
    DCD      6
    DCD      69
    DCD      6
    DCD      148
    DCD      6
    DCD      69
    DCD      6
    DCD      200
    DCD      6
    DCD      109
    DCD      6
    DCD      192
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      172
    DCD      6
    DCD      57
    DCD      6
    DCD      1096
    DCD      10
    DCD      69
    DCD      10
    DCD      132
    DCD      10
    DCD      69
    DCD      6
    DCD      208
    DCD      6
    DCD      101
    DCD      6
    DCD      196
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      172
    DCD      6
    DCD      61
    DCD      6
    DCD      1096
    DCD      6
    DCD      77
    DCD      10
    DCD      116
    DCD      10
    DCD      73
    DCD      10
    DCD      208
    DCD      6
    DCD      101
    DCD      6
    DCD      196
    DCD      6
    DCD      53
    DCD      6
    DCD      300
    DCD      6
    DCD      53
    DCD      6
    DCD      176
    DCD      6
    DCD      57
    DCD      6
    DCD      1100
    DCD      6
    DCD      81
    DCD      10
    DCD      100
    DCD      10
    DCD      81
    DCD      6
    DCD      212
    DCD      6
    DCD      101
    DCD      6
    DCD      196
    DCD      6
    DCD      53
    DCD      218
    DCD      88
    DCD      6
    DCD      53
    DCD      6
    DCD      176
    DCD      6
    DCD      61
    DCD      6
    DCD      1100
    DCD      6
    DCD      85
    DCD      10
    DCD      84
    DCD      10
    DCD      85
    DCD      6
    DCD      220
    DCD      6
    DCD      93
    DCD      6
    DCD      200
    DCD      6
    DCD      265
    DCD      6
    DCD      88
    DCD      6
    DCD      53
    DCD      6
    DCD      180
    DCD      6
    DCD      57
    DCD      6
    DCD      1104
    DCD      6
    DCD      93
    DCD      14
    DCD      52
    DCD      18
    DCD      89
    DCD      6
    DCD      224
    DCD      6
    DCD      93
    DCD      6
    DCD      200
    DCD      6
    DCD      265
    DCD      6
    DCD      88
    DCD      6
    DCD      53
    DCD      6
    DCD      180
    DCD      6
    DCD      61
    DCD      6
    DCD      1108
    DCD      105
    DCD      46
    DCD      105
    DCD      6
    DCD      232
    DCD      93
    DCD      6
    DCD      200
    DCD      6
    DCD      265
    DCD      6
    DCD      88
    DCD      6
    DCD      53
    DCD      6
    DCD      184
    DCD      6
    DCD      57
    DCD      6
    DCD      1108
    DCD      10
    DCD      237
    DCD      10
    DCD      236
    DCD      6
    DCD      85
    DCD      6
    DCD      204
    DCD      6
    DCD      265
    DCD      6
    DCD      88
    DCD      6
    DCD      53
    DCD      6
    DCD      188
    DCD      61
    DCD      6
    DCD      1108
    DCD      10
    DCD      229
    DCD      10
    DCD      240
    DCD      6
    DCD      85
    DCD      6
    DCD      204
    DCD      6
    DCD      265
    DCD      6
    DCD      88
    DCD      6
    DCD      53
    DCD      6
    DCD      188
    DCD      6
    DCD      57
    DCD      6
    DCD      1116
    DCD      6
    DCD      221
    DCD      6
    DCD      252
    DCD      6
    DCD      77
    DCD      6
    DCD      208
    DCD      6
    DCD      265
    DCD      6
    DCD      88
    DCD      6
    DCD      53
    DCD      6
    DCD      192
    DCD      61
    DCD      6
    DCD      1120
    DCD      6
    DCD      205
    DCD      6
    DCD      260
    DCD      6
    DCD      77
    DCD      6
    DCD      208
    DCD      6
    DCD      265
    DCD      6
    DCD      88
    DCD      6
    DCD      53
    DCD      6
    DCD      192
    DCD      6
    DCD      57
    DCD      6
    DCD      1124
    DCD      6
    DCD      197
    DCD      6
    DCD      264
    DCD      6
    DCD      77
    DCD      6
    DCD      208
    DCD      6
    DCD      265
    DCD      6
    DCD      88
    DCD      6
    DCD      53
    DCD      6
    DCD      196
    DCD      61
    DCD      6
    DCD      1124
    DCD      10
    DCD      181
    DCD      10
    DCD      272
    DCD      6
    DCD      69
    DCD      6
    DCD      212
    DCD      6
    DCD      265
    DCD      6
    DCD      88
    DCD      6
    DCD      53
    DCD      6
    DCD      196
    DCD      6
    DCD      57
    DCD      6
    DCD      1132
    DCD      10
    DCD      165
    DCD      10
    DCD      280
    DCD      6
    DCD      69
    DCD      6
    DCD      212
    DCD      6
    DCD      265
    DCD      6
    DCD      88
    DCD      6
    DCD      53
    DCD      6
    DCD      200
    DCD      61
    DCD      6
    DCD      1136
    DCD      14
    DCD      141
    DCD      14
    DCD      292
    DCD      6
    DCD      65
    DCD      216
    DCD      6
    DCD      265
    DCD      6
    DCD      88
    DCD      6
    DCD      53
    DCD      6
    DCD      200
    DCD      6
    DCD      57
    DCD      6
    DCD      1152
    DCD      10
    DCD      121
    DCD      6
    DCD      308
    DCD      6
    DCD      61
    DCD      6
    DCD      216
    DCD      6
    DCD      265
    DCD      6
    DCD      88
    DCD      6
    DCD      53
    DCD      6
    DCD      200
    DCD      6
    DCD      61
    DCD      6
    DCD      1156
    DCD      18
    DCD      89
    DCD      10
    DCD      604
    DCD      274
    DCD      88
    DCD      62
    DCD      204
    DCD      62
    DCD      1176
    DCD      6
    DCD      4
    DCD      26
    DCD      21
    DCD      26
    DCD      4
    DCD      6
    DCD      452384

;#############################################################################
;                               STACK BEGINS HERE

init_stack:
    ADR      sp, stack
    MOV      pc, lr
stack:
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
    DCD      0
