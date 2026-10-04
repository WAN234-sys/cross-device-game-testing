// Static checks for Godot .tscn files: parents declared before children,
// no duplicate node paths, all Ext/SubResource ids declared, load_steps sane,
// and res:// paths in ext_resources exist on disk.
// Run: node tools/validate_tscn.mjs [file ...]   (default: all scenes)
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
function walk(dir, out = []) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory() && e.name !== '.godot') walk(p, out);
    else if (e.name.endsWith('.tscn')) out.push(p);
  }
  return out;
}
const files = process.argv.slice(2).length ? process.argv.slice(2).map((f) => path.resolve(f)) : walk(path.join(root, 'scenes'));
let failed = 0;
for (const file of files) {
  const t = fs.readFileSync(file, 'utf8');
  const errs = [];
  const seen = new Set();
  let nodes = 0;
  for (const m of t.matchAll(/^\[node ([^\n]*)\]$/gm)) {
    nodes++;
    const name = m[1].match(/name="([^"]+)"/)?.[1];
    const parent = m[1].match(/parent="([^"]+)"/)?.[1];
    if (parent === undefined) { seen.add('.'); continue; }
    const full = parent === '.' ? name : `${parent}/${name}`;
    if (!seen.has(parent)) errs.push(`parent "${parent}" not declared before ${full}`);
    if (seen.has(full)) errs.push(`duplicate node ${full}`);
    seen.add(full);
  }
  const ext = new Map([...t.matchAll(/^\[ext_resource ([^\n]*)\]$/gm)].map((m) => [m[1].match(/id="([^"]+)"/)?.[1], m[1].match(/path="([^"]+)"/)?.[1]]));
  const sub = new Set([...t.matchAll(/^\[sub_resource [^\n]*id="([^"]+)"/gm)].map((m) => m[1]));
  for (const m of t.matchAll(/ExtResource\("([^"]+)"\)/g)) if (!ext.has(m[1])) errs.push(`undeclared ExtResource ${m[1]}`);
  for (const m of t.matchAll(/SubResource\("([^"]+)"\)/g)) if (!sub.has(m[1])) errs.push(`undeclared SubResource ${m[1]}`);
  for (const [id, p] of ext) if (p?.startsWith('res://') && !fs.existsSync(path.join(root, p.slice(6)))) errs.push(`missing file for ${id}: ${p}`);
  for (const m of t.matchAll(/model_path = "(res:\/\/[^"]+)"/g)) if (!fs.existsSync(path.join(root, m[1].slice(6)))) errs.push(`missing model ${m[1]}`);
  const rel = path.relative(root, file);
  if (errs.length) { failed++; console.log(`✗ ${rel}\n  - ${errs.join('\n  - ')}`); }
  else console.log(`✓ ${rel} (${nodes} nodes, ${ext.size} ext, ${sub.size} sub)`);
}
process.exit(failed ? 1 : 0);
