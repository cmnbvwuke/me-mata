// Operation Black Tide — launcher Electron.
// O Electron fornece o instalador e uma janela de entrada; o jogo em si é o
// executável nativo exportado pelo Godot (renderizador Forward+), empacotado
// em resources/game e iniciado como processo filho.

const { app, BrowserWindow, ipcMain, shell } = require('electron');
const { spawn } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const BINARIES = {
  win32: 'OperationBlackTide.exe',
  linux: 'OperationBlackTide.x86_64',
};
const PLATFORM_DIR = { win32: 'win', linux: 'linux' };

let launcher = null;
let game = null;

/** Caminho do executável do jogo (empacotado ou em desenvolvimento). */
function gameBinaryPath() {
  const binary = BINARIES[process.platform];
  if (!binary) return null;
  const packaged = path.join(process.resourcesPath, 'game', binary);
  if (app.isPackaged) return packaged;
  return path.join(__dirname, 'game', PLATFORM_DIR[process.platform], binary);
}

function createLauncher() {
  launcher = new BrowserWindow({
    width: 980,
    height: 600,
    resizable: false,
    maximizable: false,
    backgroundColor: '#05070a',
    title: 'Operation Black Tide',
    icon: path.join(__dirname, 'build', 'icon.png'),
    autoHideMenuBar: true,
    show: false,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      sandbox: true,
      nodeIntegration: false,
    },
  });
  launcher.removeMenu();
  launcher.on('closed', () => { launcher = null; });
  launcher.once('ready-to-show', () => launcher.show());
  launcher.loadFile(path.join(__dirname, 'launcher', 'index.html'));
  // Links externos abrem no navegador padrão, nunca dentro do launcher
  launcher.webContents.setWindowOpenHandler(({ url }) => {
    shell.openExternal(url);
    return { action: 'deny' };
  });
}

ipcMain.handle('launcher:info', () => ({
  version: require('./package.json').version,
  platform: process.platform,
  gameFound: (() => {
    const p = gameBinaryPath();
    return Boolean(p && fs.existsSync(p));
  })(),
}));

/** Argumentos de linha de comando do Godot a partir das opções do launcher. */
function gameArgs(options) {
  const args = [];
  if (options.fullscreen) args.push('--fullscreen');
  if (options.compatibility) args.push('--rendering-driver', 'opengl3', '--rendering-method', 'gl_compatibility');
  return args;
}

/**
 * Inicia o jogo. Se ele fechar com erro logo no início sem o modo
 * compatibilidade (ex.: placa/driver sem Vulkan), tenta de novo uma vez
 * com OpenGL — o Godot 4.3 não faz esse fallback sozinho.
 */
function startGame(binary, options) {
  const startedAt = Date.now();
  game = spawn(binary, gameArgs(options), { cwd: path.dirname(binary), stdio: 'ignore' });
  game.once('error', (err) => {
    game = null;
    if (!launcher) return app.quit();
    launcher.show();
    launcher.webContents.send('launcher:game-exit', { code: -1, error: String(err.message || err) });
  });
  game.once('exit', (code) => {
    game = null;
    const quickCrash = code !== 0 && Date.now() - startedAt < 12000;
    if (quickCrash && !options.compatibility) {
      if (launcher) launcher.webContents.send('launcher:status', 'Vulkan indisponível — iniciando em modo compatibilidade (OpenGL)...');
      startGame(binary, { ...options, compatibility: true });
      return;
    }
    if (!launcher) return app.quit();
    launcher.show();
    launcher.focus();
    launcher.webContents.send('launcher:game-exit', { code, usedCompatibility: Boolean(options.compatibility) });
  });
}

ipcMain.handle('launcher:play', (_event, options = {}) => {
  if (game) return { ok: false, error: 'O jogo já está em execução.' };
  const binary = gameBinaryPath();
  if (!binary || !fs.existsSync(binary)) {
    return { ok: false, error: `Executável do jogo não encontrado para ${process.platform}.` };
  }
  try {
    startGame(binary, options);
  } catch (err) {
    game = null;
    return { ok: false, error: String(err.message || err) };
  }
  // Esconde o launcher enquanto o jogo roda
  setTimeout(() => { if (game && launcher) launcher.hide(); }, 1500);
  return { ok: true };
});

ipcMain.handle('launcher:quit', () => app.quit());

app.whenReady().then(createLauncher);
app.on('window-all-closed', () => {
  if (!game) app.quit();
});
