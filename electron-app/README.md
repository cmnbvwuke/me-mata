# Operation Black Tide — instalador e launcher (Electron)

Empacota o jogo em instaladores para desktop:

| Plataforma | Arquivo gerado | O que faz |
|---|---|---|
| Windows x64 | `dist/OperationBlackTide-Setup-<versão>.exe` | Instalador NSIS: escolha da pasta, atalhos na Área de Trabalho e no Menu Iniciar, desinstalador |
| Linux x64 | `dist/OperationBlackTide-<versão>.AppImage` | Executável único, sem instalação (`chmod +x` e rodar) |

## Como funciona

O Electron fornece **o instalador e a janela do launcher** (JOGAR, tela cheia, modo
compatibilidade, controles). O jogo em si é o **executável nativo exportado pelo Godot**
(`resources/game/`), iniciado como processo filho. Assim o jogo roda com o renderizador
Forward+ e desempenho nativo, em vez de WebGL dentro do Chromium.

- Enquanto o jogo roda, o launcher fica oculto; ao fechar o jogo ele reaparece.
- **Fallback automático**: se o jogo fechar com erro nos primeiros segundos (placa ou
  driver sem Vulkan), o launcher reinicia sozinho em OpenGL (modo compatibilidade).
  O Godot 4.3 não faz esse fallback por conta própria.
- As opções do launcher ficam salvas; as configurações do jogo (sensibilidade, volume, FOV)
  ficam na pasta de dados do Godot do usuário.

```
electron-app/
├── main.js              # Processo principal: janela do launcher + inicia o jogo nativo
├── preload.js           # Ponte segura (contextBridge) entre launcher e processo principal
├── launcher/            # Interface do launcher (HTML/CSS/JS, com CSP restrita)
├── build/icon.png       # Ícone do app e do instalador
├── scripts/export-game.js  # Exporta o jogo Godot para game/win e game/linux
└── package.json         # Configuração do electron-builder (NSIS + AppImage)
```

## Gerar os instaladores

Pré-requisitos:
- Node.js 18+
- Godot **4.3** com os **export templates 4.3** instalados (Editor → Gerenciar modelos de exportação)
- Para gerar o `.exe` **a partir do Linux/macOS**: Wine, incluindo a parte de 32 bits
  (`dpkg --add-architecture i386 && apt install wine64 wine32:i386`). No Windows não precisa.

```bash
cd electron-app
npm install
export GODOT=/caminho/para/Godot_v4.3-stable   # ou deixe "godot" no PATH

npm run dist:win     # exporta o jogo para Windows + gera o instalador .exe
npm run dist:linux   # exporta o jogo para Linux + gera o AppImage
npm run dist         # os dois
```

Para testar sem empacotar: `node scripts/export-game.js` e depois `npm start`.

## Observações

- Os instaladores **não são assinados digitalmente**. No Windows, o SmartScreen pode mostrar
  "O Windows protegeu o computador": clique em **Mais informações → Executar assim mesmo**.
  Para distribuir publicamente, configure um certificado de assinatura de código
  (veja a seção `win` do electron-builder).
- macOS não está configurado (exigiria os templates do macOS, assinatura e notarização da Apple).
- `game/`, `dist/` e `node_modules/` são gerados e não são versionados.
