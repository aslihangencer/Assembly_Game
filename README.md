# Shadow Knight - MIPS Assembly Platformer

A Computer Organization-Aware scrolling platformer game written entirely in **MIPS32 Assembly**. This project was designed to demonstrate advanced low-level programming concepts, memory optimizations, and a hybrid rendering architecture.

## Features & Optimizations
- **Hybrid State Machine Renderer:** 
  - Uses the **MARS Bitmap Display** for the Intro and Game Over states.
  - Switches to an ultra-fast **ASCII Console Renderer** for the main gameplay loop to guarantee zero pipeline stalls during physics and array shifting.
- **Data-Oriented Design & Loop Unrolling:** The terrain memory is managed as a 1D contiguous array and shifted via unrolled loops, significantly cutting down branch predictions and preserving L1 cache locality.
- **Antigravity Physics & Procedural Generation:** Features a gravity physics engine with terminal velocity and jump impulse, alongside a Linear Congruential Generator (LCG) for procedural obstacle, platform, and coin spawning.

## How to Play

### Prerequisites
- Download and install the [MARS MIPS Simulator](http://courses.missouristate.edu/kenvollmar/mars/).

### Setup Instructions
1. Open `ShadowKnightBitmap/main_bitmap.asm` in MARS.
2. Go to **Tools -> Bitmap Display**. Apply the exact following settings to prevent memory wrapping issues:
   - **Unit Width in Pixels:** `2`
   - **Unit Height in Pixels:** `2`
   - **Display Width in Pixels:** `128`
   - **Display Height in Pixels:** `256`
   - **Base Address for Display:** `0x10008000 ($gp)`
3. Click **Connect to MIPS** on the Bitmap Display.
4. Go to **Tools -> Keyboard and Display MMIO Simulator** and click **Connect to MIPS**.
5. Assemble (`F3`) and Run (`F5`) the game. 

### Controls
Use the bottom text box in the **Keyboard and Display MMIO Simulator** to input commands:
- `w` : Jump
- `a` : Move Left
- `d` : Move Right
- `q` : Quit Game
*(Press any key to start from the Bitmap Intro Screen)*

## Architecture

This project deliberately avoids nested branching and complex camera offsets, opting instead to physically shift the entire world buffer leftwards while maintaining the player's memory pointer. Memory alignment is strictly padded to 64 bytes (cache line friendly), allowing ALU multiplication to be entirely replaced by single-cycle bitwise shifts (`sll`). 
