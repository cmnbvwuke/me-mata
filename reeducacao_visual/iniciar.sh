#!/usr/bin/env bash
# Sistema de Reeducação Visual v1.0 — É UMA BRINCADEIRA. Palavra de segurança: LARANJA
set -e
cd "$(dirname "$0")"
PY=$(command -v python3 || command -v python) || { echo "Instale o Python 3.10+."; exit 1; }
if [ ! -d .venv ]; then
  echo "Primeira execução: preparando o ambiente da sua reeducação..."
  "$PY" -m venv .venv
  .venv/bin/python -m pip install --upgrade pip
  .venv/bin/python -m pip install -r requirements.txt
fi
.venv/bin/python -m rv.model
exec .venv/bin/python main.py "$@"
