@echo off
REM Sistema de Reeducacao Visual v1.0 - E UMA BRINCADEIRA. Palavra de seguranca: LARANJA
cd /d "%~dp0"
where python >nul 2>nul || (echo Instale o Python 3.10+ em https://www.python.org/downloads/ e marque "Add to PATH". & pause & exit /b 1)
if not exist .venv (
  echo Primeira execucao: preparando o ambiente da sua reeducacao...
  python -m venv .venv || (pause & exit /b 1)
  .venv\Scripts\python -m pip install --upgrade pip
  .venv\Scripts\python -m pip install -r requirements.txt || (pause & exit /b 1)
)
.venv\Scripts\python -m rv.model || (pause & exit /b 1)
.venv\Scripts\python main.py %*
