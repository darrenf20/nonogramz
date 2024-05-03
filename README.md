# NonogramZ
### Reactive GUI for exploring and analysing nonogram solver algorithms

This project is built with [Zig](https://ziglang.org) and [raylib](https://www.raylib.com) to explore solutions to [nonograms](https://en.wikipedia.org/wiki/Nonogram). Nonograms are NP-complete problems. I aim to analyse and compare different algorithms with the hope to discover novel techniques with which to solve these puzzles.

### Installation
- Make sure to install [Zig](https://ziglang.org/download/) and the [dependencies for raylib](https://github.com/raysan5/raylib/wiki/Working-on-GNU-Linux)
- Clone this repo into your desired directory
- Type `zig build run`

### Usage
Some example files are provided in `puzzles/`. Drag and drop these onto the window. Left-click on a tile to fill it, or right-click a tile to insert a cross (empty square). The tiles change colour when the puzzle is solved.

### Features
- Reactive UI (accepts puzzles of different sizes and the application window can be resized)
- Drag-and-drop files containing puzzle data from [nonograms.org](https://www.nonograms.org/) (black & white puzzles only)
- Able to solve puzzles manually by filling or X'ing tiles; nonogram changes colour upon being solved

### Planned features
- Type in a puzzle ID or paste its URL for more convenient loading of puzzles
- Cosmetic options: light and dark themes, different colours and fonts
- On-screen help information
- Implement puzzle-solving algorithms and display performance analytics
