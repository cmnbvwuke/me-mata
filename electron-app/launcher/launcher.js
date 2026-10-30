// Lógica da janela do launcher (sem acesso ao Node: usa window.launcher do preload).
const playButton = document.getElementById('play');
const statusEl = document.getElementById('status');
const fullscreen = document.getElementById('fullscreen');
const compat = document.getElementById('compat');

function loadOptions() {
  try {
    const saved = JSON.parse(localStorage.getItem('obt-options') || '{}');
    fullscreen.checked = Boolean(saved.fullscreen);
    compat.checked = Boolean(saved.compatibility);
  } catch { /* opções padrão */ }
}

function saveOptions() {
  try {
    localStorage.setItem('obt-options', JSON.stringify({
      fullscreen: fullscreen.checked,
      compatibility: compat.checked,
    }));
  } catch { /* armazenamento indisponível */ }
}

function setStatus(text, isError = false) {
  statusEl.textContent = text;
  statusEl.classList.toggle('error', isError);
}

async function init() {
  loadOptions();
  const info = await window.launcher.info();
  document.getElementById('version').textContent = `v${info.version}`;
  if (!info.gameFound) {
    playButton.disabled = true;
    setStatus('Arquivos do jogo não encontrados nesta instalação.', true);
  }
}

playButton.addEventListener('click', async () => {
  saveOptions();
  playButton.disabled = true;
  setStatus('Iniciando operação...');
  const result = await window.launcher.play({ fullscreen: fullscreen.checked, compatibility: compat.checked });
  if (!result.ok) {
    playButton.disabled = false;
    setStatus(result.error, true);
  }
});

fullscreen.addEventListener('change', saveOptions);
compat.addEventListener('change', saveOptions);
document.getElementById('quit').addEventListener('click', () => window.launcher.quit());

window.launcher.onStatus((text) => setStatus(text));

window.launcher.onGameExit(({ code, error, usedCompatibility }) => {
  playButton.disabled = false;
  if (error) {
    setStatus(`Não foi possível iniciar o jogo: ${error}`, true);
  } else if (code && code !== 0) {
    setStatus(usedCompatibility
      ? 'O jogo fechou com erro. Atualize o driver da placa de vídeo e tente novamente.'
      : 'O jogo fechou com erro. Tente o "Modo compatibilidade".', true);
  } else {
    setStatus('');
  }
});

init();
