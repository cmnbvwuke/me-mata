"""Download (uma única vez) do modelo FaceLandmarker do MediaPipe."""

from __future__ import annotations

import sys
import urllib.request
from pathlib import Path

from . import config as C


def ensure_model(path: Path = C.MODEL_PATH, url: str = C.MODEL_URL, quiet: bool = False) -> bool:
    """Garante que o modelo existe localmente. Depois disso, tudo roda offline."""
    if path.exists() and path.stat().st_size > 1_000_000:
        return True
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".part")
    try:
        if not quiet:
            print(f"Baixando o modelo de rastreamento facial (~3.7 MB) de:\n  {url}")
        urllib.request.urlretrieve(url, tmp)
        tmp.replace(path)
        if not quiet:
            print(f"Modelo salvo em {path}. Daqui pra frente, funciona offline.")
        return True
    except Exception as exc:  # sem internet, proxy, etc.
        if tmp.exists():
            tmp.unlink()
        print(f"Falha ao baixar o modelo: {exc}", file=sys.stderr)
        return False


if __name__ == "__main__":
    sys.exit(0 if ensure_model() else 1)
