// Ponte segura entre a página do launcher e o processo principal.
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('launcher', {
  info: () => ipcRenderer.invoke('launcher:info'),
  play: (options) => ipcRenderer.invoke('launcher:play', options),
  quit: () => ipcRenderer.invoke('launcher:quit'),
  onStatus: (callback) => ipcRenderer.on('launcher:status', (_event, text) => callback(text)),
  onGameExit: (callback) => ipcRenderer.on('launcher:game-exit', (_event, data) => callback(data)),
});
