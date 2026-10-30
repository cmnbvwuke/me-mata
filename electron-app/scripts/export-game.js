// Exporta o jogo Godot nativo para ./game/<plataforma>.
//   node scripts/export-game.js            -> Windows e Linux
//   node scripts/export-game.js win        -> só Windows
// Variável GODOT: caminho do executável do Godot 4.3+ (com export templates 4.3).
const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const godot = process.env.GODOT || 'godot';
const project = path.resolve(__dirname, '..', '..', 'operation-black-tide');
const targets = {
  win: { preset: 'Windows Desktop', file: 'OperationBlackTide.exe' },
  linux: { preset: 'Linux', file: 'OperationBlackTide.x86_64' },
};
const wanted = process.argv.slice(2).length ? process.argv.slice(2) : Object.keys(targets);

const run = (args) => execFileSync(godot, ['--headless', '--path', project, ...args], { stdio: 'inherit' });
run(['--import']);
for (const key of wanted) {
  const target = targets[key];
  if (!target) throw new Error(`Plataforma desconhecida: ${key}`);
  const outDir = path.resolve(__dirname, '..', 'game', key);
  fs.rmSync(outDir, { recursive: true, force: true });
  fs.mkdirSync(outDir, { recursive: true });
  const out = path.join(outDir, target.file);
  run(['--export-release', target.preset, out]);
  if (!fs.existsSync(out)) throw new Error(`Exportação falhou: ${out}`);
  console.log(`[${key}] exportado em ${out}`);
}
