// Validates all 5 map layouts in map_content.gd. Writes results to
// tools/last_map_check.txt (so output survives any shell quirks).
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const src = fs.readFileSync(path.join(root, 'scripts/maps/map_content.gd'), 'utf8').replace(/\r\n/g, '\n');
const out = [];
const log = (s) => { out.push(s); console.log(s); };

// Split by top-level map keys:   \t"map_id": {
const keyRe = /^\t"(\w+)": \{$/gm;
const keys = [...src.matchAll(keyRe)];
let bad = 0;
keys.forEach((k, i) => {
  const id = k[1];
  const body = src.slice(k.index, i + 1 < keys.length ? keys[i + 1].index : src.length);
  const lm = body.match(/"layout": """\n([\s\S]*?)\n"""/);
  if (!lm) { log(`FAIL ${id}: no layout`); bad++; return; }
  const L = lm[1].trim().split('\n');
  const W = L[0].length, H = L.length;
  const errs = [];
  L.forEach((r, z) => r.length !== W && errs.push(`row ${z} width ${r.length} != ${W}`));
  const cells = (ch) => { const o = []; L.forEach((r, z) => [...r].forEach((c, x) => c === ch && o.push([x, z]))); return o; };
  const S = cells('S');
  if (S.length !== 1) errs.push(`need exactly 1 S (got ${S.length})`);
  const walk = (c) => c !== undefined && c !== '#';
  const bfs = (gateOpen) => {
    const seen = new Set([S[0].join()]); const q = [S[0]];
    while (q.length) {
      const [x, z] = q.shift();
      for (const [dx, dz] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
        const nx = x + dx, nz = z + dz, c = L[nz]?.[nx];
        if (!walk(c) || (c === 'G' && !gateOpen) || seen.has(`${nx},${nz}`)) continue;
        seen.add(`${nx},${nz}`); q.push([nx, nz]);
      }
    }
    return seen;
  };
  if (S.length === 1) {
    const closed = bfs(false), open = bfs(true);
    for (const p of [...cells('A'), ...cells('B')]) if (!closed.has(p.join())) errs.push(`plate ${p} unreachable before gate`);
    for (const p of cells('E')) {
      if (closed.has(p.join())) errs.push('exit reachable WITHOUT the gate');
      if (!open.has(p.join())) errs.push('exit unreachable');
    }
    for (const p of cells('T')) if (!open.has(p.join())) errs.push(`token ${p} unreachable`);
    L.forEach((r, z) => { for (let x = 0; x < r.length; x++) if (r[x] === 'N' && /\d/.test(r[x + 1] || '') && !open.has(`${x},${z}`)) errs.push(`NPC N${r[x + 1]} unreachable`); });
    const [A] = cells('A'), [B] = cells('B');
    if (!A || !B) errs.push('missing plate A or B');
    else if (Math.abs(A[0] - B[0]) + Math.abs(A[1] - B[1]) < 6) errs.push('plates too close');
    if (cells('G').length !== 1) errs.push(`need exactly 1 G (got ${cells('G').length})`);
    for (const m of body.matchAll(/"cell": \[(\d+), (\d+)\]/g)) { const x = +m[1], z = +m[2]; if (!walk(L[z]?.[x])) errs.push(`cell ${x},${z} is wall/out of bounds`); }
    for (const m of body.matchAll(/"points": \[((?:\[\d+, \d+\],? ?)+)\]/g)) for (const p of m[1].matchAll(/\[(\d+), (\d+)\]/g)) { const x = +p[1], z = +p[2]; if (!walk(L[z]?.[x])) errs.push(`patrol point ${x},${z} in wall`); }
    for (const m of body.matchAll(/"cell": "(N\d)"/g)) if (!L.some((r) => r.includes(m[1]))) errs.push(`${m[1]} not in layout`);
    const qn = (body.match(/"title":/g) || []).length;
    if (qn !== 6) errs.push(`expected 6 quests, got ${qn}`);
    const nn = (body.match(/"id": "/g) || []).length;
    if (nn < 3) errs.push(`expected 3+ NPCs, got ${nn}`);
  }
  if (errs.length) bad++;
  log(`${errs.length ? 'FAIL' : 'OK  '} ${id} ${W}x${H}${errs.length ? '\n   - ' + errs.join('\n   - ') : ''}`);
});
log(`${keys.length} maps checked, ${bad} with problems`);
fs.writeFileSync(path.join(root, 'tools', 'last_map_check.txt'), out.join('\n') + '\n');
process.exit(bad ? 1 : 0);
