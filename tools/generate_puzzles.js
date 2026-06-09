// Sudoku puzzle generator for Gravity Sudoku
// Usage: node tools/generate_puzzles.js
const fs = require('fs');
const path = require('path');

// ── helpers ──────────────────────────────────────────────────────────────────

function shuffle(arr, rng) {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

// Simple seeded LCG random number generator
function makeLCG(seed) {
  let s = seed >>> 0;
  return () => {
    s = (Math.imul(1664525, s) + 1013904223) >>> 0;
    return s / 0xFFFFFFFF;
  };
}

// ── Base grid generation ──────────────────────────────────────────────────────

/** Generate a valid base Sudoku solution for given size (n), subRows, subCols */
function generateBase(n, subRows, subCols) {
  const grid = [];
  for (let r = 0; r < n; r++) {
    const row = [];
    for (let c = 0; c < n; c++) {
      const val = ((r * subCols + Math.floor(r / subRows) + c) % n) + 1;
      row.push(val);
    }
    grid.push(row);
  }
  return grid;
}

/** Apply a symbol permutation to a grid */
function permuteSymbols(grid, mapping) {
  return grid.map(row => row.map(v => mapping[v - 1]));
}

/** Swap two rows within the same band */
function swapRows(grid, r1, r2) {
  const g = grid.map(r => [...r]);
  [g[r1], g[r2]] = [g[r2], g[r1]];
  return g;
}

/** Swap two cols within the same stack */
function swapCols(grid, c1, c2) {
  return grid.map(row => {
    const r = [...row];
    [r[c1], r[c2]] = [r[c2], r[c1]];
    return r;
  });
}

/** Swap two bands (groups of subRows rows) */
function swapBands(grid, b1, b2, subRows) {
  const g = grid.map(r => [...r]);
  for (let i = 0; i < subRows; i++) {
    [g[b1 * subRows + i], g[b2 * subRows + i]] =
      [g[b2 * subRows + i], g[b1 * subRows + i]];
  }
  return g;
}

/** Swap two stacks (groups of subCols cols) */
function swapStacks(grid, s1, s2, subCols) {
  return grid.map(row => {
    const r = [...row];
    for (let i = 0; i < subCols; i++) {
      [r[s1 * subCols + i], r[s2 * subCols + i]] =
        [r[s2 * subCols + i], r[s1 * subCols + i]];
    }
    return r;
  });
}

/** Transpose the grid */
function transpose(grid) {
  const n = grid.length;
  return Array.from({ length: n }, (_, r) =>
    Array.from({ length: n }, (_, c) => grid[c][r])
  );
}

/**
 * Generate a varied solution from a base grid using random transformations.
 */
function randomizeSolution(base, subRows, subCols, rng) {
  const n = base.length;
  let g = base.map(r => [...r]);

  // Symbol permutation
  const symbols = Array.from({ length: n }, (_, i) => i + 1);
  shuffle(symbols, rng);
  g = permuteSymbols(g, symbols);

  // Random row swaps within each band
  const numBands = n / subRows;
  for (let b = 0; b < numBands; b++) {
    const rows = Array.from({ length: subRows }, (_, i) => b * subRows + i);
    for (let _ = 0; _ < subRows; _++) {
      const i = Math.floor(rng() * subRows);
      const j = Math.floor(rng() * subRows);
      if (i !== j) g = swapRows(g, rows[i], rows[j]);
    }
  }

  // Random col swaps within each stack
  const numStacks = n / subCols;
  for (let s = 0; s < numStacks; s++) {
    const cols = Array.from({ length: subCols }, (_, i) => s * subCols + i);
    for (let _ = 0; _ < subCols; _++) {
      const i = Math.floor(rng() * subCols);
      const j = Math.floor(rng() * subCols);
      if (i !== j) g = swapCols(g, cols[i], cols[j]);
    }
  }

  // Random band swaps (limit to 3 times to avoid too many collisions for big grids)
  if (numBands <= 4) {
    for (let _ = 0; _ < 2; _++) {
      const b1 = Math.floor(rng() * numBands);
      const b2 = Math.floor(rng() * numBands);
      if (b1 !== b2) g = swapBands(g, b1, b2, subRows);
    }
  }

  // Random stack swaps
  if (numStacks <= 4) {
    for (let _ = 0; _ < 2; _++) {
      const s1 = Math.floor(rng() * numStacks);
      const s2 = Math.floor(rng() * numStacks);
      if (s1 !== s2) g = swapStacks(g, s1, s2, subCols);
    }
  }

  // Optionally transpose (only for square subgrids)
  if (subRows === subCols && rng() > 0.5) g = transpose(g);

  return g;
}

// ── Puzzle creation (remove clues) ────────────────────────────────────────────

/**
 * Create a puzzle from a solution by removing cells.
 * Returns { initial, solution, fixed_positions, ice_blocks }.
 * For bigger boards we just use a ratio rather than uniqueness checking.
 */
function createPuzzle(solution, n, clueFraction, iceBlockCount, rng) {
  const positions = [];
  for (let r = 0; r < n; r++)
    for (let c = 0; c < n; c++)
      positions.push([r, c]);
  shuffle(positions, rng);

  const totalCells = n * n;
  const targetClues = Math.round(totalCells * clueFraction);

  // Pick ice block positions (only from cells that will NOT be given clues)
  const iceSet = new Set();
  const icePositions = [];
  if (iceBlockCount > 0) {
    // Use bottom portion of shuffled positions for ice
    let iceIdx = totalCells - 1;
    while (icePositions.length < iceBlockCount && iceIdx >= targetClues) {
      const pos = positions[iceIdx];
      iceSet.add(`${pos[0]},${pos[1]}`);
      icePositions.push(pos);
      iceIdx--;
    }
  }

  // Build initial grid
  const initial = Array.from({ length: n }, () => Array(n).fill(0));
  const fixedPositions = [];
  let cluesPlaced = 0;
  for (let i = 0; i < positions.length && cluesPlaced < targetClues; i++) {
    const [r, c] = positions[i];
    if (!iceSet.has(`${r},${c}`)) {
      initial[r][c] = solution[r][c];
      fixedPositions.push([r, c]);
      cluesPlaced++;
    }
  }

  // Mark ice blocks in initial grid with -1
  for (const [r, c] of icePositions) {
    initial[r][c] = -1;
  }

  return { initial, solution, fixed_positions: fixedPositions, ice_blocks: icePositions };
}

// ── Puzzle generation per difficulty ─────────────────────────────────────────

function generateDifficulty({ name, n, subRows, subCols, count, clueFraction, iceBlocks, startId }) {
  const base = generateBase(n, subRows, subCols);
  const puzzles = [];

  for (let i = 0; i < count; i++) {
    const rng = makeLCG((startId + i) * 2654435761 + 1234567);
    const solution = randomizeSolution(base, subRows, subCols, rng);
    const iceCount = iceBlocks === 0 ? 0
      : iceBlocks[0] + Math.floor(rng() * (iceBlocks[1] - iceBlocks[0] + 1));
    const puzzle = createPuzzle(solution, n, clueFraction, iceCount, rng);

    puzzles.push({
      id: startId + i,
      size: n,
      difficulty: name,
      ...puzzle,
    });
  }
  return puzzles;
}

// ── Main ──────────────────────────────────────────────────────────────────────

const difficulties = [
  {
    name: 'easy',
    n: 4, subRows: 2, subCols: 2,
    count: 100,
    clueFraction: 0.65,   // ~10 clues of 16
    iceBlocks: 0,
    startId: 1000,
    file: 'easy_4x4.json',
  },
  {
    name: 'normal',
    n: 9, subRows: 3, subCols: 3,
    count: 200,
    clueFraction: 0.47,   // ~38 clues of 81
    iceBlocks: [2, 4],
    startId: 2000,
    file: 'normal_9x9.json',
  },
  {
    name: 'hard',
    n: 12, subRows: 3, subCols: 4,
    count: 200,
    clueFraction: 0.42,   // ~60 clues of 144
    iceBlocks: [4, 8],
    startId: 4000,
    file: 'hard_12x12.json',
  },
  {
    name: 'expert',
    n: 16, subRows: 4, subCols: 4,
    count: 150,
    clueFraction: 0.40,   // ~100 clues of 256
    iceBlocks: [8, 14],
    startId: 6000,
    file: 'expert_16x16.json',
  },
  {
    name: 'extreme',
    n: 32, subRows: 4, subCols: 8,
    count: 60,
    clueFraction: 0.60,   // ~600 clues of 1024
    iceBlocks: [10, 20],
    startId: 8000,
    file: 'extreme_32x32.json',
  },
];

// Keep tutorial puzzles as-is, regenerate the rest
const tutorialPuzzles = JSON.parse(
  fs.readFileSync(path.join(__dirname, '../assets/puzzles/tutorial_4x4.json'), 'utf8')
).puzzles;

const outDir = path.join(__dirname, '../assets/puzzles');

// Write tutorial unchanged
fs.writeFileSync(
  path.join(outDir, 'tutorial_4x4.json'),
  JSON.stringify({ puzzles: tutorialPuzzles }, null, 2)
);
console.log(`tutorial_4x4.json: ${tutorialPuzzles.length} puzzles (unchanged)`);

for (const cfg of difficulties) {
  console.log(`Generating ${cfg.count} ${cfg.name} puzzles (${cfg.n}x${cfg.n})…`);
  const puzzles = generateDifficulty(cfg);
  fs.writeFileSync(
    path.join(outDir, cfg.file),
    JSON.stringify({ puzzles }, null, 2)
  );
  console.log(`  → ${cfg.file} written (${puzzles.length} puzzles, IDs ${puzzles[0].id}–${puzzles[puzzles.length-1].id})`);
}

console.log('\nDone!');
