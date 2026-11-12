# Folha

Suíte de escritório para **Linux** baseada no LibreOffice, com foco em visual moderno e
compatibilidade com o MS Office. Plano completo: [PLANO-SUITE-OFFICE.md](PLANO-SUITE-OFFICE.md).

## Como funciona
O fork é uma **série de patches** sobre um branch de release do LibreOffice (definido em
`folha.conf`). O código do LibreOffice (cerca de 2 GB) não entra neste repositório.

```
folha/
├── folha.conf            # URL e branch do upstream
├── autogen/              # perfis de configuração: dev, ci, release
├── patches/              # mudanças do Folha (git format-patch)
├── docker/Dockerfile     # ambiente de build Ubuntu 24.04
├── scripts/
│   ├── install-deps.sh   # dependências de build (apt build-dep + Qt6/GTK)
│   ├── bootstrap.sh      # clona o upstream em folha/core e aplica os patches
│   ├── build.sh          # build dentro do container, com ccache persistente
│   ├── export-patches.sh # commits de folha/core → folha/patches/
│   └── sync-upstream.sh  # rebase sobre um release novo do upstream
└── core/                 # (gerado, ignorado pelo git)
```

## Começando
Requisitos: Linux x86_64, mais de 50 GB de disco livres, 16 GB de RAM ou mais (recomendado), Docker ou Ubuntu 24.04.

```bash
# Opção A: em container
folha/scripts/build.sh dev

# Opção B: direto no Ubuntu 24.04
sudo folha/scripts/install-deps.sh
folha/scripts/bootstrap.sh dev
cd folha/core && ./autogen.sh && make
instdir/program/soffice
```

## Fazendo mudanças
```bash
cd folha/core            # branch folha/main
# editar, compilar só o módulo (make sw), testar
git commit -am "folha: descrição"
../scripts/export-patches.sh
cd ../.. && git add folha/patches && git commit
```

## CI
`.github/workflows/folha-build.yml` compila a cada push em `folha/`. Por padrão usa o runner
hospedado `ubuntu-24.04`. O primeiro build demora horas e fica perto do limite de 6 h. Para um runner
próprio, crie a variável de repositório `FOLHA_RUNNER=self-hosted`.

## Licença
MPL-2.0, como o LibreOffice. O código-fonte dos arquivos modificados (os patches) é público. O nome do
produto **não** pode conter "LibreOffice", que é marca registrada da The Document Foundation.
