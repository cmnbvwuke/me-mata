# Folha Office (fork do LibreOffice, só Linux)

## Como o fork é organizado
- O código do LibreOffice **não** fica neste repositório. `folha/scripts/bootstrap.sh` clona o
  upstream (branch em `folha/folha.conf`) em `folha/core/` (ignorado pelo git), cria `folha/main`
  e aplica `folha/patches/*.patch`.
- Mudanças no código: commit em `folha/core` (branch `folha/main`), depois
  `folha/scripts/export-patches.sh` e commit dos `.patch` gerados neste repositório.
- Atualizar o upstream: `folha/scripts/sync-upstream.sh [libreoffice-XX-Y]`.
- Alvo: **apenas Linux** (Qt6 e GTK3; pacotes deb, rpm, Flatpak e AppImage). Não mexer em `vcl/win`, `vcl/osx`
  nem em código de instalador MSI/DMG.

## Regras
- Mudanças mínimas e localizadas. Não reformatar código existente (ver solenv/clang-format/excludelist).
- Toda correção de filtro precisa de: arquivo de teste mínimo + teste CppUnit + harness compat sem regressão.
- Mudanças só de marca e visual ficam em branding/, icon-themes/folha/, *.xcu e *.ui. Evitar mexer em C++ para isso.
- Nunca rodar `make` completo à toa: compilar só o módulo (`make sw`, `make sc`, `make oox`).
- Nunca usar "LibreOffice" no nome do produto (marca registrada da TDF).

## Comandos
- Dependências (Ubuntu 24.04): sudo folha/scripts/install-deps.sh
- Preparar árvore: folha/scripts/bootstrap.sh dev   (perfis: dev | ci | release)
- Build em container: folha/scripts/build.sh dev [alvo]
- Build completo: cd folha/core && ./autogen.sh && make
- Módulo: make sw  |  Teste: make CppunitTest_sw_ooxmlexport2
- Rodar só um teste: make CppunitTest_sw_ooxmlexport2 CPPUNIT_TEST_NAME="testTdf123456"
- Executar: instdir/program/soffice  |  Headless: instdir/program/soffice --headless --convert-to pdf arquivo.docx
- Harness: python3 compat/run.py --format docx --compare

## Mapa
- DOCX: sw/source/writerfilter (import), sw/source/filter/ww8/docx* (export)
- XLSX: sc/source/filter/oox (import), sc/source/filter/excel/xe* (export)
- PPTX: oox/source/ppt (import), sd/source/filter/eppt (export)
- Visual: icon-themes/, */uiconfig/, officecfg/registry/data/, vcl/qt6, vcl/unx/gtk3, vcl/skia
