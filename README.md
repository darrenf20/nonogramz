# NonogramZ

This project uses [Zig](https://ziglang.org) and [raylib](https://www.raylib.com) to explore solutions to [nonograms](https://en.wikipedia.org/wiki/Nonogram). Nonograms are NP-complete problems. I aim to analyse and compare different algorithms with the hope to discover novel techniques with which to solve these puzzles.

### Features
- Reactive UI (accepts puzzles of different sizes and the application window can be resized)
- Drag-and-drop files containing puzzle data from [nonograms.org](https://www.nonograms.org/) (black & white puzzles only)
- Able to solve puzzles manually by filling or X'ing tiles; nonogram changes colour upon being solved

### Planned features
- Type in a puzzle ID or paste its URL for more convenient loading of puzzles
- Light and dark themes
- On-screen help information
- Implement puzzle-solving algorithms and display performance analytics