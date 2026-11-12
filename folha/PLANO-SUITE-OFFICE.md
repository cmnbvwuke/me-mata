# Plano: suíte de escritório para Linux baseada no LibreOffice, mais bonita e mais compatível com o MS Office

> Plano feito para o **Claude Code** executar em fases. Cada fase tem objetivo, tarefas,
> arquivos e diretórios do código do LibreOffice, e um critério de "pronto".
> **Plataforma alvo: somente Linux** (x86_64; aarch64 depois). Windows e macOS estão fora do escopo.
> Nome provisório do produto: **"Folha"**. Troque à vontade, mas **não** use "LibreOffice"
> no nome, porque é marca registrada da The Document Foundation.

---

## 0. Expectativas e estratégia

- O LibreOffice tem cerca de 10 milhões de linhas de C++. Reescrever não é viável. A estratégia é um
  **fork leve**: manter o código o mais próximo possível do upstream e concentrar as
  mudanças em três camadas:
  1. **Marca e visual**: tema, ícones, fontes, layout padrão, tela inicial.
  2. **Configuração padrão**: salvar em DOCX/XLSX/PPTX, fontes substitutas, opções de compatibilidade.
  3. **Filtros OOXML**: correções de importação e exportação. **Sempre que possível, envie essas correções
     para o upstream** (gerrit.libreoffice.org). Assim o fork não vira um peso para manter.
- Licença: MPL-2.0 (com partes em LGPLv3). Pode fazer fork e distribuir, mas o código-fonte dos arquivos
  modificados tem que ser publicado.
- Referências de quem já faz isso: Collabora Office/Online (fork comercial com foco em
  OOXML) e o próprio projeto de UI "Notebookbar".
- Hardware: compilar o LibreOffice pede **mais de 50 GB de disco, 16 GB de RAM ou mais e várias horas** no
  primeiro build. Use uma máquina dedicada ou um runner de CI com `ccache`. O container
  efêmero do Claude Code na web provavelmente **não aguenta** o build completo.

---

## Fase 1: infraestrutura do fork (1–2 semanas)

**Objetivo:** compilar e rodar o LibreOffice sem mudanças, de forma reprodutível.

Tarefas para o Claude Code:
1. Fork como **série de patches** sobre o upstream (implementado em `folha/`):
   ```bash
   folha/scripts/bootstrap.sh dev   # clona libreoffice-25-8 em folha/core, cria folha/main, aplica folha/patches/
   # ...commits em folha/core...
   folha/scripts/export-patches.sh  # grava os commits do fork em folha/patches/*.patch
   ```
   O branch do upstream fica em `folha/folha.conf`. Se mais tarde quiser um repositório `folha-office` com a árvore
   inteira, basta fazer push de `folha/main` para ele.
2. Criar `autogen.input` para desenvolvimento:
   ```
   --enable-dbgutil
   --without-java
   --without-help
   --without-myspell-dicts
   --enable-ccache
   --enable-skia
   --enable-qt6
   --enable-gtk3
   ```
   (Perfis prontos em `folha/autogen/{dev,ci,release}.input`.)
   (Para release: trocar `--enable-dbgutil` por `--enable-release-build` e incluir as opções de branding da Fase 2.)
3. Dockerfile de build (Ubuntu 24.04 + `apt build-dep libreoffice`, em `folha/docker/`) e workflow de CI
   (`.github/workflows/folha-build.yml`; runner hospedado ou self-hosted via variável `FOLHA_RUNNER`) com cache de `ccache`.
4. Criar o `CLAUDE.md` do repositório (`folha/CLAUDE.md`, modelo na seção 7).
5. Script `folha/scripts/sync-upstream.sh` para rebase periódico sobre o branch de release do upstream.

**Pronto quando:** `./autogen.sh && make` passa, `instdir/program/soffice` abre e o CI
compila a cada push.

---

## Fase 2: identidade visual, "mais bonito" (4–8 semanas)

Ganho rápido sem mexer no motor. Ordem sugerida:

### 2.1 Branding
- Diretório `branding/folha/` com `about.svg`, `flat_logo.svg`, `intro.png` e afins.
  Usar `--with-branding=branding/folha` e `--with-vendor="Folha"` no configure.
- Nome do produto: ajustar `AC_INIT` em `configure.ac` (veja como o Collabora faz).
- Ícones dos apps, arquivos `.desktop`, MIME types e AppStream metainfo: `sysui/desktop/`.

### 2.2 Interface em abas (Ribbon) como padrão
- Ativar a **Notebookbar "Tabbed"** por padrão em Writer, Calc e Impress:
  `officecfg/registry/data/org/openoffice/Office/UI/ToolbarMode.xcu`
  (e `.../Office/Common.xcu`, chave `Misc/ExperimentalMode` se precisar).
- Redesenhar os arquivos `.ui` da notebookbar para ficarem mais próximos do layout que quem vem do Office
  já conhece: `sw/uiconfig/swriter/ui/notebookbar.ui`, `sc/uiconfig/scalc/ui/notebookbar.ui`,
  `sd/uiconfig/simpress/ui/notebookbar.ui`.
- Revisar os menus de contexto e a barra lateral (`sfx2/uiconfig/`, `svx/uiconfig/`).

### 2.3 Tema e cores
- Usar o sistema de temas e "Application Colors" (`officecfg/.../Office/UI.xcu`,
  `svtools/source/config/colorcfg.cxx`) para definir um tema claro e um escuro próprios, com
  paleta, bordas e espaçamentos consistentes.
- Backends gráficos: **Qt6** (`vcl/qt6`, padrão no KDE e afins) e **GTK3** (`vcl/unx/gtk3`, padrão no GNOME),
  com **Skia** ligado (`vcl/skia`) para antialiasing e desempenho. GTK4 e KF6 ficam para quando estiverem
  estáveis no upstream e nas distros-alvo.
- Integração com o desktop Linux: seguir o tema claro/escuro do sistema (portal `org.freedesktop.appearance`),
  escala fracionária em Wayland e diálogos nativos de arquivo (portal).

### 2.4 Ícones
- Criar o tema `icon-themes/folha/` (SVG, baseado no Colibre ou no Sifr para herdar todos os
  nomes de arquivo) e defini-lo como padrão.
- Gerar a lista de ícones que faltam comparando com `icon-themes/colibre/`.

### 2.5 Tela inicial (Start Center)
- `sfx2/source/dialog/backingwindow.cxx` e `sfx2/uiconfig/ui/startcenter.ui`: miniaturas
  maiores, modelos em destaque, busca de arquivos recentes.

### 2.6 Modelos e estilos padrão
- Estilos padrão do Writer parecidos com o "Normal" do Word (fonte, espaçamento de 1,08 e 8 pt
  depois do parágrafo): `sw/source/core/doc/DocumentStylePoolManager.cxx`.
- Novos modelos de documento, planilha e apresentação em `extras/source/templates/`.

**Pronto quando:** há capturas de tela antes e depois aprovadas, nenhum ícone aparece faltando
(o script de checagem passa) e a UI funciona em claro, escuro, HiDPI e RTL, em GNOME (GTK3) e KDE (Qt6),
X11 e Wayland.

---

## Fase 3: padrões voltados ao Office (2–3 semanas)

1. **Formato padrão de salvamento: DOCX, XLSX e PPTX**
   `officecfg/registry/data/org/openoffice/Setup.xcu`, chave `ooSetupFactoryDefaultFilter` de cada módulo
   (`MS Word 2007 XML`, `Calc MS Excel 2007 XML`, `Impress MS PowerPoint 2007 XML`).
   Desligar o aviso "manter formato" (`Office/Common.xcu`, `Save/Document/WarnAlienFormat`).
2. **Fontes**
   - Incluir fontes métricamente compatíveis: Carlito (Calibri), Caladea (Cambria) e Liberation
     (Arial, Times New Roman, Courier New), além de Noto e Selawik (Segoe UI). No Linux, declarar como
     dependência dos pacotes (`fonts-crosextra-carlito`, `fonts-crosextra-caladea`, `fonts-liberation`)
     e embutir no Flatpak e no AppImage. Complementar com regras do fontconfig (`/etc/fonts/conf.d`).
   - Tabela de substituição em `officecfg/registry/data/org/openoffice/VCL.xcu`: mapear
     Calibri, Cambria, Aptos, Segoe UI e outras para as equivalentes de métrica mais próxima.
   - Incentivar a incorporação de fontes ao salvar e respeitar fontes já incorporadas no DOCX.
3. **Opções de compatibilidade** ligadas por padrão para documentos novos, para imitar o layout do Word
   (`sw/source/core/doc/DocumentSettingManager.cxx`).

**Pronto quando:** um documento novo salva como DOCX, abre no Word sem aviso e mantém
as quebras de página iguais (testado numa instalação Linux limpa, só com as fontes empacotadas).

---

## Fase 4: compatibilidade OOXML (contínua, é o trabalho principal)

### 4.1 Medir antes de corrigir: harness de compatibilidade
Construir `compat/` no repositório:
- **Corpus**: arquivos .docx, .xlsx e .pptx reais (o script `bin/get-bugzilla-attachments-by-mimetype` baixa
  anexos do Bugzilla da TDF), mais documentos próprios. Para cada um, um **PDF de referência
  gerado pelo MS Office**, feito uma vez numa máquina Windows ou Mac à parte (é o único uso de Windows/Mac no projeto).
- **Pipeline** (`compat/run.py`):
  1. `soffice --headless --convert-to pdf` → comparar com a referência: número de páginas,
     texto (`pdftotext`) e diferença visual por página (`pdftoppm` + SSIM/pixel diff).
  2. **Round-trip**: abrir, salvar como OOXML, reabrir e comparar o XML normalizado e o PDF.
  3. Registrar crashes e timeouts.
- **Painel de resultados** por formato e por categoria. Toda mudança no filtro roda o harness, e regressão bloqueia o merge.

### 4.2 Onde fica cada coisa no código
| Formato | Importação | Exportação | Testes |
|---|---|---|---|
| DOCX | `sw/source/writerfilter/` (antes `writerfilter/`), `oox/` | `sw/source/filter/ww8/docx*.cxx` | `sw/qa/extras/ooxmlimport`, `ooxmlexport` |
| XLSX | `sc/source/filter/oox/` | `sc/source/filter/excel/xe*.cxx` | `sc/qa/unit/subsequent_*` |
| PPTX | `oox/source/ppt/`, `oox/source/drawingml/` | `sd/source/filter/eppt/pptx-*.cxx`, `oox/source/export/` | `sd/qa/unit/import-tests*`, `export-tests-ooxml*` |
| Comum | `oox/` (DrawingML, VML, temas, gráficos) | `oox/source/export/` | `oox/qa/` |

### 4.3 Áreas prioritárias (problemas mais frequentes)
- **DOCX:** posicionamento e quebra de texto em volta de imagens e formas, tabelas aninhadas e
  larguras, listas e numeração, seções, cabeçalhos e rodapés, campos (TOC, REF), controle de alterações,
  comentários, content controls (SDT), cores de tema, SmartArt (no mínimo o fallback).
- **XLSX:** formatação condicional, tabelas dinâmicas, matrizes dinâmicas e funções novas
  (XLOOKUP, FILTER, SORT, UNIQUE, LET, LAMBDA), sparklines, segmentações (slicers),
  validação de dados, gráficos.
- **PPTX:** autoajuste de texto, gradientes, sombras e efeitos, animações e transições,
  SmartArt, layouts e masters, tabelas.

### 4.4 Ciclo de trabalho do Claude Code (um bug por vez)
1. Escolher o pior item do painel do harness ou um bug do Bugzilla da TDF (palavras-chave
   `filter:docx`, `filter:xlsx`, `filter:pptx`).
2. Reproduzir com `soffice --headless --convert-to` e salvar um **arquivo mínimo** em `*/qa/.../data/`.
3. Escrever o **teste CppUnit que falha** primeiro.
4. Corrigir. Rodar só o alvo: `make CppunitTest_sw_ooxmlexport2` (ou o equivalente).
5. Rodar o harness, confirmar que não há regressão e fazer o commit.
6. Se a correção for genérica, preparar o patch para o upstream (Gerrit).

**Pronto (por trimestre):** metas numéricas no painel, por exemplo "85 % dos DOCX com número de páginas
igual ao do Word" e "0 crashes no corpus".

---

## Fase 5 (opcional e ambiciosa): interface nova sobre o LibreOfficeKit

Se a Fase 2 não chegar ao nível visual desejado, dá para trocar a interface inteira:
- Usar o **LibreOfficeKit** (`include/LibreOfficeKit/`, `desktop/source/lib/init.cxx`):
  o core vira um motor que renderiza em *tiles* e recebe comandos `.uno:`.
- Frontend em **Qt Quick/QML** (nativo) ou **Tauri/Electron + web** (é a abordagem do
  Collabora Online).
- Custo alto: menus, diálogos e barra lateral precisam ser refeitos ou expostos via JSON (LOK já
  tem "JSDialog" para isso). Vale só depois que as Fases 1 a 4 estiverem maduras.

---

## 6. Distribuição (Linux)
- Pacotes **deb** e **rpm**: `make` com `--enable-release-build --with-package-format="deb rpm"` gera os pacotes em
  `workdir/installation/`. Publicar via repositório APT e RPM próprio, com chave GPG.
- **Flatpak** (Flathub): manifesto próprio, baseado no `org.libreoffice.LibreOffice` do Flathub.
  É o canal principal para chegar a qualquer distro e já resolve atualização automática.
- **AppImage** para quem quer um arquivo único, sem instalar nada.
- **Snap** opcional (Ubuntu).
- Relatório de crash: crashreporter do próprio LibreOffice (`--enable-crashdump`) apontando para servidor próprio.
- Publicar o código-fonte (exigência da MPL): a série de patches de `folha/patches/` mais o branch do upstream.

---

## 7. `CLAUDE.md` do fork
O arquivo está em `folha/CLAUDE.md` (inclui as regras de "só Linux" e o fluxo de patches).

---

## 8. Como usar este plano com o Claude Code
- Rodar **uma fase por vez** e, dentro dela, **uma tarefa por sessão**. O código é grande demais
  para tarefas vagas como "melhore a compatibilidade".
- Dar sempre ao Claude Code: o arquivo de teste, o diretório do módulo e o comando de teste.
- Usar subagentes para investigação ("onde o import de DOCX trata `w:tblpPr`?") e
  manter a edição na sessão principal.
- Usar hooks para rodar `clang-format` nos arquivos novos e o teste do módulo antes de cada commit.
- Exemplo de prompt para a Fase 4:
  > "Bug: o DOCX `compat/corpus/docx/0042.docx` tem 3 páginas no Word e 4 no Folha.
  > Crie um arquivo mínimo que reproduza o problema, escreva um teste em sw/qa/extras/ooxmlimport que falhe,
  > corrija em sw/source/writerfilter e rode `make CppunitTest_sw_ooxmlimport` e o harness."

## Cronograma resumido
| Fase | Duração estimada | Entrega |
|---|---|---|
| 1. Infra | 1–2 sem | Build e CI reprodutíveis (Linux) |
| 2. Visual | 4–8 sem | Marca, ribbon, tema, ícones, tela inicial (GTK3 e Qt6) |
| 3. Padrões Office | 2–3 sem | OOXML como padrão, fontes compatíveis |
| 4. Compatibilidade | contínua | Harness, painel, correções com testes |
| 5. UI nova (opcional) | 6+ meses | Frontend próprio via LibreOfficeKit |
