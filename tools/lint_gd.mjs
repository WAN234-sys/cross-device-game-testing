// Lightweight GDScript sanity checks (no Godot binary needed):
// - tabs/spaces not mixed in indentation
// - %UniqueName refs exist as unique_name_in_owner nodes in the matching scene
// - references to autoload singletons are declared in project.godot
// - preload/load("res://...") targets exist
// - class_name references resolve to a script in the project
// Run: node tools/lint_gd.mjs
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const walk = (d, ext, out = []) => {
  for (const e of fs.readdirSync(d, { withFileTypes: true })) {
    const p = path.join(d, e.name);
    if (e.isDirectory() && !['.godot', 'node_modules', '.git'].includes(e.name)) walk(p, ext, out);
    else if (e.name.endsWith(ext)) out.push(p);
  }
  return out;
};
const scripts = walk(root, '.gd');
const scenes = walk(root, '.tscn');
const project = fs.readFileSync(path.join(root, 'project.godot'), 'utf8');
const autoloads = new Set([...project.matchAll(/^(\w+)="\*res:\/\//gm)].map((m) => m[1]));
const classNames = new Set();
for (const s of scripts) {
  const m = fs.readFileSync(s, 'utf8').match(/^class_name (\w+)/m);
  if (m) classNames.add(m[1]);
}
// Map script -> scenes that use it, to verify %UniqueName nodes
const sceneUnique = new Map();
for (const sc of scenes) {
  const t = fs.readFileSync(sc, 'utf8');
  const uniques = new Set();
  for (const m of t.matchAll(/\[node name="([^"]+)"[^\]]*\]\n(?:(?!\[)[^\n]*\n)*?unique_name_in_owner = true/g)) uniques.add(m[1]);
  for (const m of t.matchAll(/path="(res:\/\/scripts\/[^"]+\.gd)"/g)) {
    const key = m[1];
    if (!sceneUnique.has(key)) sceneUnique.set(key, []);
    sceneUnique.get(key).push({ scene: path.relative(root, sc), uniques });
  }
}
const builtinGlobals = new Set(['Engine', 'OS', 'Input', 'InputMap', 'DisplayServer', 'AudioServer', 'ProjectSettings', 'ResourceLoader', 'Time', 'JSON', 'FileAccess', 'TextServer', 'PhysicsRayQueryParameters3D', 'TranslationServer']);
let problems = 0;
for (const s of scripts) {
  const rel = 'res://' + path.relative(root, s).replaceAll('\\', '/');
  const t = fs.readFileSync(s, 'utf8');
  const errs = [];
  t.split('\n').forEach((line, i) => {
    const ind = line.match(/^[\t ]*/)[0];
    if (ind.includes(' ') && ind.includes('\t')) errs.push(`line ${i + 1}: mixed tabs/spaces`);
    if (/^ +\S/.test(line) && !line.trim().startsWith('#')) errs.push(`line ${i + 1}: space indentation (project uses tabs)`);
  });
  for (const m of t.matchAll(/(?:preload|load)\("(res:\/\/[^"]+)"\)/g)) {
    if (!fs.existsSync(path.join(root, m[1].slice(6)))) errs.push(`missing resource ${m[1]}`);
  }
  for (const m of t.matchAll(/\b([A-Z][A-Za-z]+Manager)\b/g)) {
    if (!autoloads.has(m[1]) && !classNames.has(m[1])) errs.push(`unknown singleton ${m[1]}`);
  }
  for (const m of t.matchAll(/\b(BuddyPlayer|ModelSwap|PressurePlate|PuzzleGate|FriendshipToken|FriendNPC|TugRope|SignalChain|MapBase|MultiPlateController)\b/g)) {
    if (!classNames.has(m[1])) errs.push(`unknown class ${m[1]}`);
  }
  const uses = [...t.matchAll(/%(\w+)/g)].map((m) => m[1]).filter((n) => !/^\d|^d$|^s$|^f$/.test(n));
  if (uses.length && sceneUnique.has(rel)) {
    for (const { scene, uniques } of sceneUnique.get(rel)) {
      for (const u of new Set(uses)) if (!uniques.has(u)) errs.push(`%${u} not marked unique in ${scene}`);
    }
  }
  if (errs.length) { problems++; console.log(`✗ ${rel}\n  - ${[...new Set(errs)].join('\n  - ')}`); }
}
console.log(problems ? `\n${problems} script(s) with problems` : `✓ ${scripts.length} scripts passed lint`);
process.exit(problems ? 1 : 0);
