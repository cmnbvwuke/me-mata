# Plano: suíte de escritório baseada no LibreOffice, mais bonita e mais compatível com o MS Office

> Plano feito para o **Claude Code** executar em fases. Cada fase tem objetivo, tarefas,
> arquivos e diretórios do código do LibreOffice, e um critério de "pronto".
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
1. Criar um repositório novo (ex.: `folha-office`) com o core como base:
   ```bash
   git clone https://git.libreoffice.org/core folha-office   # ou o mirror github.com/LibreOffice/core
   cd folha-office
   git checkout -b folha/main origin/libreoffice-25-8   # partir de um branch de release estável
   git remote rename origin upstream
   ```
2. Criar `autogen.input` para desenvolvimento:
   ```
   --enable-dbgutil
   --without-java
   --without-help
   --without-myspell-dicts
   --enable-ccache
   --with-parallelism=16
   ```
   (Para release: trocar `--enable-dbgutil` por `--enable-release-build` e incluir as opções de branding da Fase 2.)
3. Dockerfile de build (Ubuntu 24.04 + `apt build-dep libreoffice`) e workflow de CI
   (GitHub Actions self-hosted ou runner grande) com cache de `ccache`.
4. Criar o `CLAUDE.md` do repositório (modelo na seção 7).
5. Script `scripts/sync-upstream.sh` para rebase periódico sobre o branch de release do upstream.

**Pronto quando:** `./autogen.sh && make` passa, `instdir/program/soffice` abre e o CI
compila a cada push.

---

## Fase 2: identidade visual, "mais bonito" (4–8 semanas)

Ganho rápido sem mexer no motor. Ordem sugerida:

### 2.1 Branding
- Diretório `branding/folha/` com `about.svg`, `flat_logo.svg`, `intro.png` e afins.
  Usar `--with-branding=branding/folha` e `--with-vendor="Folha"` no configure.
- Nome do produto: ajustar `AC_INIT` em `configure.ac` (veja como o Collabora faz).
- Ícones dos apps e associação de arquivos: `sysui/desktop/`.

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
- Backend gráfico padrão no Linux: **Qt6/KF6** ou **GTK4** (`vcl/qt6`, `vcl/unx/gtk4`), com
  **Skia** ligado (`vcl/skia`) para antialiasing e desempenho.
- Windows: modernizar o visual (cantos arredondados, cores do Fluent) em `vcl/win/`.

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
(o script de checagem passa) e a UI funciona em claro, escuro, HiDPI e RTL.

---

## Fase 3: padrões voltados ao Office (2–3 semanas)

1. **Formato padrão de salvamento: DOCX, XLSX e PPTX**
   `officecfg/registry/data/org/openoffice/Setup.xcu`, chave `ooSetupFactoryDefaultFilter` de cada módulo
   (`MS Word 2007 XML`, `Calc MS Excel 2007 XML`, `Impress MS PowerPoint 2007 XML`).
   Desligar o aviso "manter formato" (`Office/Common.xcu`, `Save/Document/WarnAlienFormat`).
2. **Fontes**
   - Incluir fontes métricamente compatíveis: Carlito (Calibri), Caladea (Cambria) e Liberation
     (Arial, Times New Roman, Courier New), além de Noto e Selawik (Segoe UI).
   - Tabela de substituição em `officecfg/registry/data/org/openoffice/VCL.xcu`: mapear
     Calibri, Cambria, Aptos, Segoe UI e outras para as equivalentes de métrica mais próxima.
   - Incentivar a incorporação de fontes ao salvar e respeitar fontes já incorporadas no DOCX.
3. **Opções de compatibilidade** ligadas por padrão para documentos novos, para imitar o layout do Word
   (`sw/source/core/doc/DocumentSettingManager.cxx`).

**Pronto quando:** um documento novo salva como DOCX, abre no Word sem aviso e mantém
as quebras de página iguais.

---

## Fase 4: compatibilidade OOXML (contínua, é o trabalho principal)

### 4.1 Medir antes de corrigir: harness de compatibilidade
Construir `compat/` no repositório:
- **Corpus**: arquivos .docx, .xlsx e .pptx reais (o script `bin/get-bugzilla-attachments-by-mimetype` baixa
  anexos do Bugzilla da TDF), mais documentos próprios. Para cada um, um **PDF de referência
  gerado pelo MS Office**, feito numa máquina Windows ou Mac à parte.
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

## 6. Distribuição
- Instaladores: `make` com `--enable-release-build` gera os pacotes em `workdir/installation/`
  (MSI no Windows, DMG no macOS, deb/rpm no Linux). Também dá para fazer Flatpak e AppImage.
- Assinatura de código (Windows e macOS), atualização automática e relatório de crash.
- Publicar o código-fonte (exigência da MPL).

---

## 7. Modelo de `CLAUDE.md` para o repositório do fork

```markdown
# Folha Office (fork do LibreOffice)

## Regras
- Mudanças mínimas e localizadas. Não reformatar código existente (ver solenv/clang-format/excludelist).
- Toda correção de filtro precisa de: arquivo de teste mínimo + teste CppUnit + harness compat sem regressão.
- Mudanças só de marca e visual ficam em branding/, icon-themes/folha/, *.xcu e *.ui. Evitar mexer em C++ para isso.
- Nunca rodar `make` completo à toa: compilar só o módulo (`make sw`, `make sc`, `make oox`).

## Comandos
- Build completo: ./autogen.sh && make
- Módulo: make sw  |  Teste: make CppunitTest_sw_ooxmlexport2
- Rodar só um teste: make CppunitTest_sw_ooxmlexport2 CPPUNIT_TEST_NAME="testTdf123456"
- Executar: instdir/program/soffice  |  Headless: instdir/program/soffice --headless --convert-to pdf arquivo.docx
- Harness: python3 compat/run.py --format docx --compare

## Mapa
- DOCX: sw/source/writerfilter (import), sw/source/filter/ww8/docx* (export)
- XLSX: sc/source/filter/oox (import), sc/source/filter/excel/xe* (export)
- PPTX: oox/source/ppt (import), sd/source/filter/eppt (export)
- Visual: icon-themes/, */uiconfig/, officecfg/registry/data/, vcl/
```

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
| 1. Infra | 1–2 sem | Build e CI reprodutíveis |
| 2. Visual | 4–8 sem | Marca, ribbon, tema, ícones, tela inicial |
| 3. Padrões Office | 2–3 sem | OOXML como padrão, fontes compatíveis |
| 4. Compatibilidade | contínua | Harness, painel, correções com testes |
| 5. UI nova (opcional) | 6+ meses | Frontend próprio via LibreOfficeKit |
