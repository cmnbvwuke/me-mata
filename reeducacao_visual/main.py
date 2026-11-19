#!/usr/bin/env python3
"""
Sistema de Reeducação Visual v1.0 — Inspirado em Laranja Mecânica (versão light)

╔══════════════════════════════════════════════════════════════════════════╗
║  ISTO É UMA BRINCADEIRA. Software de humor para pessoas que CONSENTEM.   ║
║  Palavra de segurança durante a sessão: LARANJA (sai de verdade).        ║
║  Se você está usando isso de verdade em alguém sem consentimento,        ║
║  você é o vilão da história.                                             ║
╚══════════════════════════════════════════════════════════════════════════╝

Uso:
    python main.py                         # abre a tela de inicialização
    python main.py --video chato.mp4       # já pré-seleciona o vídeo
    python main.py --video a.mp4 b.mp4     # playlist
    python main.py --sem-webcam            # modo demo: o mouse finge ser seus olhos
    python main.py --camera 1              # outra webcam
    python main.py --piscou-voltou         # cada piscada volta o vídeo 10 segundos
    python main.py --direto --video x.mp4  # pula a tela inicial (consentimento implícito: você digitou o comando)
"""

from __future__ import annotations

import argparse
import sys

from PyQt6.QtWidgets import QApplication, QMessageBox

from rv import config as C
from rv.model import ensure_model
from rv.ui.certificate import CertificateDialog
from rv.ui.session import SessionWindow
from rv.ui.splash import SessionOptions, SplashWindow


def parse_args(argv=None):
    ap = argparse.ArgumentParser(description=f"{C.TITLE} — {C.SUBTITLE} (é humor!)")
    ap.add_argument("--video", nargs="+", default=[], help="vídeo(s) do material educativo")
    ap.add_argument("--sem-webcam", action="store_true", help="modo demo, sem câmera (mouse = olhos)")
    ap.add_argument("--camera", type=int, default=C.CAMERA_INDEX, help="índice da webcam (padrão 0)")
    ap.add_argument("--sem-voz", action="store_true", help="desliga a voz passivo-agressiva")
    ap.add_argument("--sem-laranja", action="store_true", help="desliga o overlay de cílios")
    ap.add_argument("--piscou-voltou", action="store_true",
                    help=f"Modo Pálpebra Proibida: cada piscada volta o vídeo {C.BLINK_REWIND_S:.0f}s")
    ap.add_argument("--direto", action="store_true", help="pula a tela inicial (exige --video)")
    return ap.parse_args(argv)


def main(argv=None) -> int:
    args = parse_args(argv)
    app = QApplication(sys.argv[:1])
    app.setApplicationName("Reeducação Visual")

    preset = SessionOptions(
        videos=args.video,
        laranja_mode=not args.sem_laranja,
        voice=not args.sem_voz,
        use_webcam=not args.sem_webcam,
        camera_index=args.camera,
        blink_rewind=args.piscou_voltou,
    )
    windows = {}

    def show_certificate(stats):
        dlg = CertificateDialog(stats)
        dlg.exec()
        app.quit()

    def start(opts: SessionOptions):
        if opts.use_webcam and not ensure_model():
            QMessageBox.critical(
                windows.get("splash"), "Modelo ausente",
                "Não consegui baixar o modelo de rastreamento facial.\n"
                "Rode 'python -m rv.model' com internet uma vez (depois funciona offline),\n"
                "ou use o modo demo sem webcam.",
            )
            return
        if "splash" in windows:
            windows["splash"].hide()
        session = SessionWindow(opts)
        session.finished.connect(show_certificate)
        windows["session"] = session
        session.start()

    if args.direto:
        if not args.video:
            print("--direto exige --video. Até a tortura precisa de material.", file=sys.stderr)
            return 2
        start(preset)
    else:
        splash = SplashWindow(preset)
        splash.start_requested.connect(start)
        windows["splash"] = splash
        splash.show()

    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
