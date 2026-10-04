// Inserts ModelSwap nodes into the Kitchen Counter scene so the detailed GLB
// models replace gray-box placeholders. Idempotent: re-running skips nodes
// that already exist. Run: node tools/wire_kitchen_models.mjs
import fs from 'node:fs';

const file = new URL('../scenes/maps/kitchen_counter/kitchen_counter.tscn', import.meta.url);
let tscn = fs.readFileSync(file, 'utf8');

const SWAP_ID = '20_swap';
if (!tscn.includes(`id="${SWAP_ID}"`)) {
  tscn = tscn.replace(
    /(\[ext_resource [^\n]*id="8_ctrl"\]\n)/,
    `$1[ext_resource type="Script" path="res://scripts/visual/model_swap.gd" id="${SWAP_ID}"]\n`,
  );
}

const M = 'res://assets/models';
const added = [];
function swap(name, parent, model, opts = {}) {
  const path = parent === '.' ? name : `${parent}/${name}`;
  if (tscn.includes(`[node name="${name}" type="Node3D" parent="${parent}"]`)) return;
  const lines = [
    `[node name="${name}" type="Node3D" parent="${parent}"]`,
  ];
  if (opts.transform) lines.push(`transform = ${opts.transform}`);
  lines.push(`script = ExtResource("${SWAP_ID}")`);
  lines.push(`model_path = "${M}/${model}"`);
  if (opts.placeholder) lines.push(`placeholder = NodePath("${opts.placeholder}")`);
  if (opts.size) lines.push(`target_size = ${opts.size}`);
  if (opts.rot) lines.push(`rotate_y_deg = ${opts.rot}`);
  if (opts.y) lines.push(`y_offset = ${opts.y}`);
  added.push(path);
  // Insert before the Spawns block so it stays readable
  tscn = tscn.replace('[node name="Spawns" type="Node3D" parent="."]', lines.join('\n') + '\n\n[node name="Spawns" type="Node3D" parent="."]');
}
const T = (x, y, z, ry = 0) => {
  const c = Math.cos(ry), s = Math.sin(ry);
  const f = (n) => Number(n.toFixed(5));
  return `Transform3D(${f(c)}, 0, ${f(s)}, 0, 1, 0, ${f(-s)}, 0, ${f(c)}, ${x}, ${y}, ${z})`;
};

// Cereal walls: each collider is 1.5 x 6 x 10 (local Z is the long axis).
// Line it with three tall cereal boxes. Wall origin is at mid-height (y=3), so base is y=-3.
for (const wall of ['CerealWallA', 'CerealWallB', 'CerealWallC']) {
  [-3.3, 0, 3.3].forEach((z, i) => {
    swap(`Box${i + 1}`, wall, `environment/kitchen/${i === 1 ? 'cereal_box_2' : 'cereal_box'}.glb`, {
      transform: T(0, -3, z, Math.PI / 2),
      size: 6,
      placeholder: i === 0 ? '../Mesh' : '',
    });
  });
}
// Remove empty placeholder lines created above
tscn = tscn.replace(/\nplaceholder = NodePath\(""\)/g, '');

swap('Model', 'Gate', 'environment/kitchen/kitchen_gate.glb', { placeholder: '../Mesh', size: 5, y: -2.5 });
swap('Model', 'PressurePlateA', 'environment/kitchen/pressure_plate.glb', { placeholder: '../PlateMesh', size: 2.2 });
swap('Model', 'PressurePlateB', 'environment/kitchen/pressure_plate.glb', { placeholder: '../PlateMesh', size: 2.2 });
for (const t of ['Token1', 'Token2', 'Token3']) {
  swap('Model', `Tokens/${t}`, 'items/friendship_token.glb', { placeholder: '../TokenMesh', size: 1.0, y: -0.4 });
}
swap('Model', 'Breadwise', 'environment/npcs/npc_breadwise.glb', { placeholder: '../NPCMesh', size: 1.4 });
swap('PortalModel', 'ExitZone', 'environment/kitchen/exit_portal.glb', { size: 3.5, y: -1 });

// Decorative kitchen props (visual only, giant scale — players are bug-sized)
const props = [
  ['SaltShaker', 'salt_shaker', -14, 0, -4, 7, 0.3],
  ['PepperShaker', 'pepper_shaker', -11, 0, -6, 7, -0.2],
  ['CoffeeMug', 'coffee_mug', 14, 0, -6, 6, 0.8],
  ['OilBottle', 'oil_bottle', 17, 0, 2, 10, 0],
  ['PaperTowels', 'paper_towels', -18, 0, 12, 9, 0],
  ['KnifeRack', 'knife_rack', 18, 0, -16, 9, -0.6],
  ['Faucet', 'faucet', -8, 0, -24, 9, 0],
  ['SpoonBridge', 'spoon_bridge', 10, 0, 16, 8, 1.2],
  ['Sponge', 'sponge_pad', -10, 0, 18, 4, 0.4],
];
for (const [name, model, x, y, z, size, ry] of props) {
  swap(name, 'Props', `environment/kitchen/${model}.glb`, { transform: T(x, y, z, ry), size });
}
if (!tscn.includes('[node name="Props" type="Node3D" parent="."]')) {
  tscn = tscn.replace('[node name="SaltShaker" type="Node3D" parent="Props"]', '[node name="Props" type="Node3D" parent="."]\n\n[node name="SaltShaker" type="Node3D" parent="Props"]');
}

// Counter surface model, stretched under the play area
swap('CounterModel', 'Counter', 'environment/kitchen/kitchen_counter_floor.glb', { transform: 'Transform3D(30, 0, 0, 0, 1, 0, 0, 0, 30, 0, 0.5, 0)', placeholder: '../Mesh' });

// Bump load_steps to cover the new resource
tscn = tscn.replace(/load_steps=(\d+)/, (_, n) => `load_steps=${Math.max(Number(n), 24)}`);
fs.writeFileSync(file, tscn);
console.log(`Inserted ${added.length} model nodes:\n- ${added.join('\n- ')}`);
