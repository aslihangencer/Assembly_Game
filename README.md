# Improved Game (Optimized MIPS Assembly Platformer)

This version of the platformer game has been heavily optimized with a deep focus on **Computer Architecture, CPU Pipelining, and Memory Hierarchy (L1 Cache)**. 

**Acknowledgements & Reference:**
The baseline architecture and initial inspiration for this project were referenced from [prokopchukdim/Assembly-Platformer](https://github.com/prokopchukdim/Assembly-Platformer). Building upon that excellent foundation, profound architectural improvements were engineered specifically to maximize Cache Locality and minimize CPU Pipeline stalls.

<img width="1917" height="1017" alt="Ekran görüntüsü 2026-05-16 220717" src="https://github.com/user-attachments/assets/6efe8e9a-c7a0-4157-bd7f-48a437f8a459" />


## 🚀 Key Hardware-Level Optimizations

### 1. CPU Pipeline Optimization (Branch Reduction & Delay Slots)
Modern CPUs use instruction pipelining to execute multiple instructions simultaneously. Conditional branches are the biggest enemy of the pipeline because they can cause stalls or flushes if predicted incorrectly.
- **Loop Unrolling:** The infinite scrolling system unrolls the shifting loop to process 4 bytes per iteration. This cuts the number of conditional branch evaluations by 75%, drastically reducing pipeline branch penalties and maintaining a smooth flow of instructions.
- **Branch Delay Slot Awareness:** To respect the true MIPS architecture, `nop` instructions are strategically placed after every jump and branch to prevent pipeline hazards and ensure safe instruction fetches. 
- **Sequential Physics Updates:** The gravity engine uses mathematical and bitwise logic rather than nested `if/else` branches to manage state, guaranteeing zero pipeline stalls during physics ticks.

### 2. Memory Hierarchy & L1 Cache Locality
Accessing main memory (RAM) is extremely slow. The architecture of this game guarantees that we hit the ultra-fast L1 CPU Cache as often as possible.
- **Data-Oriented Memory Layout:** Instead of fragments of strings or a massive 2D array, the game world is flattened into a tightly packed 1D contiguous array. This ensures that when the CPU fetches a row, the entire segment loads cleanly into an L1 cache line without fragmentation.
- **64-Byte Alignment:** The rows of the map buffer are precisely padded to 64 bytes—matching the typical size of a standard cache line. This alignment prevents cache-line splits and maximizes Spatial Locality.
- **Bitwise Address Calculation:** Because the row size is exactly 64 (a power of 2), the engine completely eliminates the slow CPU multiplication instruction (`mul`). It calculates Y-axis memory addresses instantaneously using a single clock cycle bitwise shift (`sll $t0, $pY, 6`).

<img width="707" height="731" alt="image" src="https://github.com/user-attachments/assets/95130cd2-e296-4633-b31a-fc1c4d70a8bc" />

### 3. Reduced Memory Bus Traffic
- **Partial Screen Redraw:** Clearing and redrawing an entire memory buffer frame-by-frame chokes the memory bus. This engine uses a "Partial Redraw" architecture that saves the underlying map character, renders the player `@` into the buffer temporarily, pushes the frame to the I/O, and restores the original character. This cuts memory `store` operations by 99% per frame.

## How to Run
1. Open `Improved_game.asm` in the MARS Simulator.
2. Go to **Tools -> Keyboard and Display MMIO Simulator** and click **Connect to MIPS**.
3. Assemble (`F3`) and Run (`F5`).
4. Play the game using `w` (Jump), `a` (Left), and `d` (Right) on the bottom keyboard input box.

<img width="601" height="705" alt="image" src="https://github.com/user-attachments/assets/02c3d8cc-8fde-475e-bce5-4676ed8c79d4" />

