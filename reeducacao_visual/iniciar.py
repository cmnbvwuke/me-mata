#!/usr/bin/env python3
"""
Iniciador do Sistema de Reeducação Visual v1.0 (É UMA BRINCADEIRA — palavra de segurança: LARANJA).

Faz o mesmo que iniciar.bat / iniciar.sh, mas em Python puro, para funcionar
quando o Windows (Controle Inteligente de Aplicativos / SmartScreen) bloqueia
arquivos .bat baixados da internet.

Uso (no Prompt de Comando ou PowerShell, dentro desta pasta):
    python iniciar.py
    python iniciar.py --piscou-voltou
No Windows também dá para usar:  py iniciar.py
"""

import os
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
VENV = HERE / ".venv"
VENV_PY = VENV / ("Scripts/python.exe" if os.name == "nt" else "bin/python")


def run(*cmd):
    print("»", " ".join(str(c) for c in cmd), flush=True)
    subprocess.check_call([str(c) for c in cmd], cwd=HERE)


def main() -> int:
    if sys.version_info < (3, 10):
        print("Precisa do Python 3.10 ou mais novo. Baixe em https://www.python.org/downloads/")
        return 1
    try:
        if not VENV_PY.exists():
            print("Primeira execução: preparando o ambiente da sua reeducação (alguns minutos)...")
            run(sys.executable, "-m", "venv", VENV)
            run(VENV_PY, "-m", "pip", "install", "--upgrade", "pip")
            run(VENV_PY, "-m", "pip", "install", "-r", HERE / "requirements.txt")
        run(VENV_PY, "-m", "rv.model")
        return subprocess.call([str(VENV_PY), str(HERE / "main.py"), *sys.argv[1:]], cwd=HERE)
    except subprocess.CalledProcessError as exc:
        print(f"\nAlgo deu errado ({exc}). Se foi na instalação, apague a pasta .venv e tente de novo.")
        if os.name == "nt":
            input("Aperte Enter para fechar...")
        return 1


if __name__ == "__main__":
    sys.exit(main())
