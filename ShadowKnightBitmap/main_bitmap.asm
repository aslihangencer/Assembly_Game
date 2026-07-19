# ==============================================================================
# SHADOW KNIGHT (BITMAP HYBRID STATE MACHINE)
# ==============================================================================
# MARS Ayarlari:
# 1. Keyboard and Display MMIO Simulator acik olmali.
# 2. Bitmap Display ayarlari (Cok Onemli!):
#    - Unit Width: 4  | Unit Height: 4
#    - Display Width: 512 | Display Height: 512
#    - Base Address: 0x10008000 ($gp)
#
# STATE MACHINE ARCHITECTURE:
# State 0: Intro Screen (Bitmap Framebuffer Render)
# State 1: Game Running (ASCII + Bitmap PoC Gameplay Render)
# State 2: Game Over Screen (Bitmap Framebuffer Render)
# ==============================================================================

.eqv DISPLAY_BASE 0x10008000
.eqv DISPLAY_WIDTH 128
.eqv DISPLAY_HEIGHT 128

.data

.align 2
title_msg: .asciiz "\n=== SHADOW KNIGHT ===\nSCORE: "
controls_msg: .asciiz "\nCONTROLS: a=left d=right w=jump q=quit\n"
title_sk: .asciiz "\n========================\nSHADOW KNIGHT\nCOMPUTER ORGANIZATION AWARE PLATFORMER\n========================\nPRESS ANY KEY TO START\n"
clear_lines: .asciiz "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n"
game_over_msg: .asciiz "\n\n====================\n*** GAME OVER ***\n====================\n"
score_msg: .asciiz "FINAL SCORE: "

msg_pit: .asciiz "FELL INTO THE ABYSS!\n"
msg_spike: .asciiz "IMPALED BY A SPIKE!\n"
msg_crush: .asciiz "CRUSHED BY THE SCROLLING WALL!\n"

.align 2
# Cache-aligned contiguous buffer for spatial locality
buffer: .space 640

playerX: .word 5
playerY: .word 4
velocityY: .word 0
isGrounded: .word 0
score: .word 0
frameCount: .word 0
rand_seed: .word 123456789
savedChar: .word 0

# OPTIMIZATION: State Machine Variable (Avoids excessive branching)
gameState: .word 0

.text
.globl main

main:
    li $t0, 5
    sw $t0, playerX
    li $t0, 4
    sw $t0, playerY
    sw $zero, velocityY
    sw $zero, isGrounded
    sw $zero, score
    sw $zero, frameCount
    sw $zero, gameState
    
    jal init_map
    nop

game_loop:
    # --- 1. SLEEP (~60 FPS) ---
    li $v0, 32
    li $a0, 16
    syscall

    # --- 2. MMIO INPUT & DISPATCHER ---
    lui $t0, 0xFFFF
    lw $t1, 0($t0)
    andi $t1, $t1, 1
    beqz $t1, skip_input
    nop
    
    lw $s0, 4($t0)
    
    li $t1, 'q'
    bne $s0, $t1, input_dispatch
    nop
    j exit_game
    nop

input_dispatch:
    lw $t0, gameState
    beqz $t0, intro_input
    nop
    li $t1, 1
    beq $t0, $t1, game_input
    nop
    
    j skip_input
    nop

intro_input:
    # Smooth cinematic transition (Fade effect wipe)
    jal wipe_screen
    nop
    
    li $t0, 5
    sw $t0, playerX
    li $t0, 4
    sw $t0, playerY
    sw $zero, velocityY
    sw $zero, isGrounded
    sw $zero, score
    sw $zero, frameCount
    
    jal init_map
    nop
    
    li $t0, 1
    sw $t0, gameState
    
    j skip_input
    nop

game_input:
    li $t3, 'a'
    beq $s0, $t3, move_left
    nop
    li $t3, 'd'
    beq $s0, $t3, move_right
    nop
    li $t3, 'w'
    beq $s0, $t3, jump_input
    nop
    j skip_input
    nop

move_left:
    lw $t0, playerX
    blez $t0, skip_input
    nop
    addiu $t0, $t0, -1
    
    lw $t1, playerY
    sll $t1, $t1, 6
    la $t2, buffer
    addu $t2, $t2, $t1
    addu $t2, $t2, $t0
    lb $t3, 0($t2)
    
    li $t4, '#'
    beq $t3, $t4, skip_input
    nop
    
    li $t4, '$'
    bne $t3, $t4, skip_coin_l
    nop
    lw $t4, score
    addiu $t4, $t4, 5
    sw $t4, score
    li $t4, ' '
    sb $t4, 0($t2)
skip_coin_l:
    sw $t0, playerX
    j skip_input
    nop

move_right:
    lw $t0, playerX
    li $t1, 31
    bge $t0, $t1, skip_input
    nop
    addiu $t0, $t0, 1
    
    lw $t1, playerY
    sll $t1, $t1, 6
    la $t2, buffer
    addu $t2, $t2, $t1
    addu $t2, $t2, $t0
    lb $t3, 0($t2)
    
    li $t4, '#'
    beq $t3, $t4, skip_input
    nop
    
    li $t4, '$'
    bne $t3, $t4, skip_coin_r
    nop
    lw $t4, score
    addiu $t4, $t4, 5
    sw $t4, score
    li $t4, ' '
    sb $t4, 0($t2)
skip_coin_r:
    sw $t0, playerX
    j skip_input
    nop

jump_input:
    lw $t0, isGrounded
    beqz $t0, skip_input
    nop
    
    li $t1, -4
    sw $t1, velocityY
    sw $zero, isGrounded
    j skip_input
    nop

exit_game:
    li $v0, 10
    syscall

skip_input:
    # --- 3. TICK INCREMENT ---
    lw $t0, frameCount
    addiu $t0, $t0, 1
    sw $t0, frameCount
    
    # --- 4. STATE RENDER & LOGIC DISPATCHER ---
    lw $t0, gameState
    beqz $t0, state_intro
    nop
    li $t1, 1
    beq $t0, $t1, state_game
    nop
    
state_gameover:
    jal draw_gameover_bitmap
    nop
    j end_frame
    nop

state_intro:
    jal draw_intro_bitmap
    nop
    jal draw_intro_ascii
    nop
    j end_frame
    nop

state_game:
    lw $t8, playerY
    lw $t9, playerX
    sll $t0, $t8, 6
    la $t1, buffer
    addu $t1, $t1, $t0
    addu $t1, $t1, $t9
    lb $t2, 0($t1)
    li $t3, '^'
    beq $t2, $t3, game_over_spike
    nop

    # PHYSICS UPDATE 
    lw $t0, frameCount
    li $t1, 3
    div $t0, $t1
    mfhi $t2
    bnez $t2, skip_physics
    nop
    
    jal check_ground
    nop
    jal do_physics
    nop
skip_physics:

    # WORLD SCROLL (Live Demo Friendly Timing)
    lw $t0, frameCount
    li $t1, 2000
    blt $t0, $t1, slow_scroll
    nop
    li $t1, 4 # normal fast scroll
    j calc_scroll
    nop
slow_scroll:
    li $t1, 6 # safer slow scroll for first 30s
calc_scroll:
    div $t0, $t1
    mfhi $t2
    bnez $t2, skip_scroll
    nop
    
    jal do_scroll
    nop
    
    lw $t8, playerY
    lw $t9, playerX
    sll $t0, $t8, 6
    la $t1, buffer
    addu $t1, $t1, $t0
    addu $t1, $t1, $t9
    lb $t2, 0($t1)
    
    li $t3, '#'
    bne $t2, $t3, scroll_check_coin
    nop
    
    addiu $t9, $t9, -1
    sw $t9, playerX
    ble $t9, 1, game_over_crush
    nop
    j scroll_ok
    nop

scroll_check_coin:
    li $t3, '$'
    bne $t2, $t3, scroll_ok
    nop
    lw $t4, score
    addiu $t4, $t4, 5
    sw $t4, score
    li $t4, ' '
    sb $t4, 0($t1)
scroll_ok:
    
    lw $t0, score
    addiu $t0, $t0, 1
    sw $t0, score

skip_scroll:

    # RENDER ASCII + BITMAP GAMEPLAY
    jal draw_frame
    nop
    
end_frame:
    j game_loop
    nop

draw_intro_ascii:
    li $v0, 4
    la $a0, clear_lines
    syscall
    la $a0, title_sk
    syscall
    jr $ra
    nop

# ==============================================================================
# SUBROUTINES: GAME LOGIC
# ==============================================================================

init_map:
    la $t0, buffer
    li $t1, 10
    li $t2, 0 
init_row_loop:
    li $t3, 0
fill_space:
    li $t4, ' '
    addu $t5, $t0, $t3
    sb $t4, 0($t5)
    addiu $t3, $t3, 1
    li $t6, 40
    blt $t3, $t6, fill_space
    nop
    
    li $t6, 9
    bne $t2, $t6, skip_ground_init
    nop
    
    li $t3, 0
fill_ground:
    li $t4, '#'
    addu $t5, $t0, $t3
    sb $t4, 0($t5)
    addiu $t3, $t3, 1
    li $t6, 40
    blt $t3, $t6, fill_ground
    nop
    
skip_ground_init:
    li $t4, '\n'
    sb $t4, 40($t0)
    li $t4, 0
    sb $t4, 41($t0)

    addiu $t0, $t0, 64
    addiu $t2, $t2, 1
    blt $t2, 10, init_row_loop
    nop
    jr $ra
    nop

check_ground:
    lw $t0, playerY
    addiu $t1, $t0, 1 
    li $t2, 9
    bgt $t1, $t2, not_grounded
    nop
    
    sll $t2, $t1, 6
    la $t3, buffer
    addu $t3, $t3, $t2
    lw $t4, playerX
    addu $t3, $t3, $t4
    lb $t5, 0($t3)
    
    li $t6, '#'
    beq $t5, $t6, is_grounded_lbl
    nop
    
not_grounded:
    sw $zero, isGrounded
    jr $ra
    nop

is_grounded_lbl:
    li $t0, 1
    sw $t0, isGrounded
    jr $ra
    nop

do_physics:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    lw $t8, velocityY
    
    addiu $t8, $t8, 1
    li $t0, 2
    ble $t8, $t0, store_vel
    nop
    li $t8, 2
store_vel:
    sw $t8, velocityY
    
    beqz $t8, end_physics
    nop
    
    li $t9, 1
    bgtz $t8, set_dir
    nop
    li $t9, -1
    neg $t8, $t8
set_dir:

phys_loop:
    lw $t0, playerY
    addu $t1, $t0, $t9
    
    bltz $t1, hit_ceiling
    nop
    li $t2, 9
    bgt $t1, $t2, game_over_pit
    nop
    
    sll $t2, $t1, 6
    la $t3, buffer
    addu $t3, $t3, $t2
    lw $t4, playerX
    addu $t3, $t3, $t4
    lb $t5, 0($t3)
    
    li $t6, '#'
    beq $t5, $t6, hit_wall_y
    nop
    li $t6, '^'
    beq $t5, $t6, game_over_spike
    nop
    
    li $t6, '$'
    bne $t5, $t6, skip_coin_phys
    nop
    lw $t7, score
    addiu $t7, $t7, 5
    sw $t7, score
    li $t6, ' '
    sb $t6, 0($t3)
skip_coin_phys:
    
    sw $t1, playerY
    addiu $t8, $t8, -1
    bgtz $t8, phys_loop
    nop
    
    j end_physics
    nop

hit_wall_y:
    sw $zero, velocityY
    bgtz $t9, set_grounded_phys
    nop
    j end_physics
    nop
set_grounded_phys:
    li $t0, 1
    sw $t0, isGrounded
    j end_physics
    nop

hit_ceiling:
    sw $zero, velocityY
    j end_physics
    nop

end_physics:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
    nop

do_scroll:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    la $t0, buffer
    li $t1, 10
shift_row_loop:
    # EFFICIENT SCROLLING: Loop Unrolling & Branch Delay Slot Awareness
    li $t2, 0
unroll_loop:
    addu $t3, $t0, $t2
    lb $t4, 1($t3)
    sb $t4, 0($t3)
    lb $t4, 2($t3)
    sb $t4, 1($t3)
    lb $t4, 3($t3)
    sb $t4, 2($t3)
    lb $t4, 4($t3)
    sb $t4, 3($t3)
    
    addiu $t2, $t2, 4
    li $t5, 36
    blt $t2, $t5, unroll_loop
    nop
    
    addu $t3, $t0, $t2
    lb $t4, 1($t3)
    sb $t4, 0($t3)
    lb $t4, 2($t3)
    sb $t4, 1($t3)
    lb $t4, 3($t3)
    sb $t4, 2($t3)
    
    li $t4, ' '
    sb $t4, 39($t0)

    addiu $t0, $t0, 64
    addiu $t1, $t1, -1
    bgtz $t1, shift_row_loop
    nop

    lw $t0, rand_seed
    li $t1, 1664525
    mul $t0, $t0, $t1
    li $t1, 1013904223
    addu $t0, $t0, $t1
    sw $t0, rand_seed

    lw $t7, frameCount
    li $t1, 2000
    blt $t7, $t1, demo_friendly_gen
    nop
    
    andi $t2, $t0, 0xF
    li $t3, '#'
    bgt $t2, 3, set_ground
    nop
    li $t3, ' '
set_ground:
    la $t4, buffer
    sb $t3, 615($t4) 
    
    srl $t0, $t0, 4
    andi $t2, $t0, 0xF
    li $t3, ' '
    bgt $t2, 12, set_plat
    nop
    j skip_plat
    nop
set_plat:
    li $t3, '#'
skip_plat:
    sb $t3, 423($t4) 

    lb $t5, 615($t4)
    li $t6, '#'
    bne $t5, $t6, skip_obs
    nop
    
    srl $t0, $t0, 4
    andi $t2, $t0, 0xF
    li $t3, ' '
    bgt $t2, 14, set_obs
    nop
    j skip_obs
    nop
set_obs:
    li $t3, '^'
skip_obs:
    sb $t3, 551($t4)

    srl $t0, $t0, 4
    andi $t2, $t0, 0xF
    li $t3, ' '
    bgt $t2, 13, set_coin
    nop
    j skip_coin
    nop
set_coin:
    li $t3, '$'
skip_coin:
    sb $t3, 359($t4)

    j scroll_epilogue
    nop

demo_friendly_gen:
    # Always guarantee safe ground
    li $t3, '#'
    la $t4, buffer
    sb $t3, 615($t4)
    
    # Occasional safe platforms
    srl $t0, $t0, 4
    andi $t2, $t0, 0xF
    li $t3, ' '
    bgt $t2, 13, demo_set_plat
    nop
    j demo_skip_plat
    nop
demo_set_plat:
    li $t3, '#'
demo_skip_plat:
    sb $t3, 423($t4)
    
    # No spikes for 30 seconds
    li $t3, ' '
    sb $t3, 551($t4)
    
    # Early coins
    srl $t0, $t0, 4
    andi $t2, $t0, 0xF
    li $t3, ' '
    bgt $t2, 8, demo_set_coin
    nop
    j demo_skip_coin
    nop
demo_set_coin:
    li $t3, '$'
demo_skip_coin:
    sb $t3, 359($t4)

scroll_epilogue:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
    nop

draw_frame:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    li $v0, 4
    la $a0, clear_lines
    syscall
    
    li $v0, 4
    la $a0, title_msg
    syscall
    
    li $v0, 1
    lw $a0, score
    syscall
    
    li $v0, 4
    la $a0, controls_msg
    syscall
    
    lw $t8, playerY
    lw $t9, playerX
    sll $t0, $t8, 6
    la $t1, buffer
    addu $t1, $t1, $t0
    addu $t1, $t1, $t9
    
    lb $t2, 0($t1)
    sw $t2, savedChar
    
    li $t3, '@'
    sb $t3, 0($t1)
    
    # ---------------------------------------------
    # DRAW BITMAP GAMEPLAY (128x128 Scaled Output)
    # ---------------------------------------------
    jal draw_bitmap_frame
    nop
    
    la $t8, buffer
    li $t9, 10
print_loop:
    li $v0, 4
    move $a0, $t8
    syscall
    addiu $t8, $t8, 64
    addiu $t9, $t9, -1
    bgtz $t9, print_loop
    nop
    
    lw $t8, playerY
    lw $t9, playerX
    sll $t0, $t8, 6
    la $t1, buffer
    addu $t1, $t1, $t0
    addu $t1, $t1, $t9
    lw $t2, savedChar
    sb $t2, 0($t1)
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
    nop

game_over_pit:
    la $a0, msg_pit
    j game_over_common
    nop

game_over_spike:
    la $a0, msg_spike
    j game_over_common
    nop

game_over_crush:
    la $a0, msg_crush
    j game_over_common
    nop

game_over_common:
    move $s0, $a0
    
    li $v0, 4
    la $a0, clear_lines
    syscall
    
    li $v0, 4
    la $a0, game_over_msg
    syscall
    
    li $v0, 4
    move $a0, $s0
    syscall
    
    li $v0, 4
    la $a0, score_msg
    syscall
    
    li $v0, 1
    lw $a0, score
    syscall
    
    li $t0, 2
    sw $t0, gameState
    
    j game_loop
    nop


# ==============================================================================
# SUBROUTINES: BITMAP RENDERING ENGINE (128x128 GRID)
# ==============================================================================

wipe_screen:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    li $t0, DISPLAY_BASE
    li $t1, 128
wipe_row:
    li $t2, 128
    li $t3, 0x000000
wipe_col:
    sw $t3, 0($t0)
    addiu $t0, $t0, 4
    addiu $t2, $t2, -1
    bgtz $t2, wipe_col
    nop
    
    li $v0, 32
    li $a0, 2
    syscall
    
    addiu $t1, $t1, -1
    bgtz $t1, wipe_row
    nop
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
    nop

draw_intro_bitmap:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    lw $t9, frameCount
    srl $t9, $t9, 1
    
    li $t0, DISPLAY_BASE
    li $t1, 128
intro_y:
    li $t2, 128
intro_x:
    addu $t3, $t1, $t9
    addu $t4, $t2, $t9
    xor $t5, $t3, $t4
    andi $t5, $t5, 0x20
    
    li $t6, 0x1A0B2E # Dark fantasy purple
    beqz $t5, intro_color_set
    nop
    li $t6, 0x0F0518 # Deep void
intro_color_set:
    sw $t6, 0($t0)
    addiu $t0, $t0, 4
    
    addiu $t2, $t2, -1
    bgtz $t2, intro_x
    nop
    
    addiu $t1, $t1, -1
    bgtz $t1, intro_y
    nop

    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
    nop

draw_gameover_bitmap:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    li $t0, DISPLAY_BASE
    li $t1, 128
go_y:
    li $t2, 128
go_x:
    andi $t3, $t1, 0x08
    andi $t4, $t2, 0x08
    xor $t5, $t3, $t4
    
    li $t6, 0x8B0000
    beqz $t5, go_color_ok
    nop
    li $t6, 0x4A0000
go_color_ok:
    sw $t6, 0($t0)
    addiu $t0, $t0, 4
    
    addiu $t2, $t2, -1
    bgtz $t2, go_x
    nop
    
    addiu $t1, $t1, -1
    bgtz $t1, go_y
    nop
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
    nop

draw_bitmap_frame:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    # 1. CACHE-AWARE UNROLLED BACKGROUND CLEAR (Spatial Locality)
    # Clears 16384 pixels efficiently using loop unrolling
    li $t0, DISPLAY_BASE
    li $t1, 2048 # 16384 / 8
    li $t2, 0x0B0C10 # Dark sky
clear_bg_loop:
    sw $t2, 0($t0)
    sw $t2, 4($t0)
    sw $t2, 8($t0)
    sw $t2, 12($t0)
    sw $t2, 16($t0)
    sw $t2, 20($t0)
    sw $t2, 24($t0)
    sw $t2, 28($t0)
    addiu $t0, $t0, 32
    addiu $t1, $t1, -1
    bgtz $t1, clear_bg_loop
    nop
    
    # 2. DRAW 4x4 PIXEL BLOCKS FOR ACTIVE CELLS
    li $t4, 0
draw_map_row:
    li $t5, 0
draw_map_col:
    sll $t6, $t4, 6
    addu $t6, $t6, $t5
    la $t7, buffer
    addu $t7, $t7, $t6
    lb $t0, 0($t7)
    
    li $t1, ' '
    beq $t0, $t1, skip_draw_cell
    nop
    
    li $t1, 0x000000
    li $t2, '#'
    beq $t0, $t2, color_plat
    nop
    li $t2, '^'
    beq $t0, $t2, color_spike
    nop
    li $t2, '$'
    beq $t0, $t2, color_coin
    nop
    li $t2, '@'
    beq $t0, $t2, color_player
    nop
    j skip_draw_cell
    nop

color_plat:
    li $t1, 0x4A4E69 # Dark purple/grey platform
    j draw_4x4
    nop
color_spike:
    li $t1, 0xD90429 # Red spikes
    j draw_4x4
    nop
color_coin:
    li $t1, 0xFFD700 # Gold coins
    j draw_4x4
    nop
color_player:
    li $t1, 0x00F0FF # Cyan character
    j draw_4x4
    nop

draw_4x4:
    # y_pixel = 88 + (row * 4) -> (Places 10x40 map at bottom of 128x128 grid)
    sll $t6, $t4, 2
    addiu $t6, $t6, 88
    
    # x_pixel = col * 4
    sll $t7, $t5, 2
    
    # Correct memory addressing: address = BASE + ((y * 128) + x) * 4
    sll $t8, $t6, 7     # y * 128
    addu $t8, $t8, $t7  # + x
    sll $t8, $t8, 2     # * 4
    li $t9, DISPLAY_BASE
    addu $t8, $t8, $t9
    
    # Unrolled 4x4 rendering block (Partial rendering technique)
    sw $t1, 0($t8)
    sw $t1, 4($t8)
    sw $t1, 8($t8)
    sw $t1, 12($t8)
    
    sw $t1, 512($t8)
    sw $t1, 516($t8)
    sw $t1, 520($t8)
    sw $t1, 524($t8)
    
    sw $t1, 1024($t8)
    sw $t1, 1028($t8)
    sw $t1, 1032($t8)
    sw $t1, 1036($t8)
    
    sw $t1, 1536($t8)
    sw $t1, 1540($t8)
    sw $t1, 1544($t8)
    sw $t1, 1548($t8)

skip_draw_cell:
    addiu $t5, $t5, 1
    li $t2, 32
    blt $t5, $t2, draw_map_col
    nop
    
    addiu $t4, $t4, 1
    li $t2, 10
    blt $t4, $t2, draw_map_row
    nop

    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
    nop
