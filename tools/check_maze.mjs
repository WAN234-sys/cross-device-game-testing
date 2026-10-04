// Checks the maze layout in maze_builder.gd:
// - all rows same width
// - every important cell is reachable from S with the gate CLOSED, except things behind G
// - with the gate OPEN, the exit E and every token T are reachable
// - plates A and B are reachable before the gate (so the puzzle is solvable)
// - A and B are far apart (one player can't press both)
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const src = fs.readFileSync(path.join(root, 'scripts/maps/maze_builder.gd'), 'utf8');
const layout = src.match(/var layout: String = """\n([\s\S]*?)\n"""/)[1].trim().split('\n');
const H = layout.length, W = layout[0].length;
const errs = [];
layout.forEach((r, i) => { if (r.length !== W) errs.push(`row ${i} width ${r.length} != ${W}`); });
const find = (ch) => { const out = []; layout.forEach((r, z) => [...r].forEach((c, x) => c === ch && out.push([x, z]))); return out; };
const [S] = find('S');
function bfs(gateOpen) {
  const seen = new Set([S.join()]);
  const q = [S];
  while (q.length) {
    const [x, z] = q.shift();
    for (const [dx, dz] of [[1,0],[-1,0],[0,1],[0,-1]]) {
      const nx = x + dx, nz = z + dz;
      const c = layout[nz]?.[nx];
      if (!c || c === '#' || (c === 'G' && !gateOpen) || seen.has(`${nx},${nz}`)) continue;
      seen.add(`${nx},${nz}`); q.push([nx, nz]);
    }
  }
  return seen;
}
const closed = bfs(false), open = bfs(true);
const has = (set, p) => set.has(p.join());
for (const p of [...find('A'), ...find('B')]) if (!has(closed, p)) errs.push(`plate at ${p} unreachable before gate`);
for (const p of find('N')) if (!has(closed, p)) errs.push(`NPC at ${p} unreachable`);
for (const p of find('E')) {
  if (has(closed, p)) errs.push(`exit reachable WITHOUT opening gate (puzzle bypass)`);
  if (!has(open, p)) errs.push(`exit unreachable even with gate open`);
}
for (const p of find('T')) if (!has(open, p)) errs.push(`token at ${p} unreachable`);
const [A] = find('A'), [B] = find('B');
const dist = Math.abs(A[0] - B[0]) + Math.abs(A[1] - B[1]);
if (dist < 6) errs.push(`plates too close (${dist} cells) — one player might cover both`);
console.log(`maze ${W}x${H}, S=${S}, plates A=${A} B=${B} (distance ${dist}), tokens=${find('T').length}, gates=${find('G').length}`);
if (errs.length) { console.log('✗ ' + errs.join('\n✗ ')); process.exit(1); }
console.log('✓ maze is solvable and requires the gate puzzle');
