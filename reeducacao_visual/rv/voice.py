"""
Voz sintetizada passivo-agressiva (opcional).

Tenta, em ordem: QtTextToSpeech (vem com o PyQt6) -> pyttsx3 -> silêncio.
Se nada funcionar, o sistema continua passivo-agressivo, só que por escrito.
"""

from __future__ import annotations

import queue
import threading


class Voice:
    def __init__(self, enabled: bool = True):
        self._engine = None
        self._kind = None
        if not enabled:
            return
        if self._try_qt():
            return
        self._try_pyttsx3()

    @property
    def available(self) -> bool:
        return self._kind is not None

    def _try_qt(self) -> bool:
        try:
            from PyQt6.QtCore import QLocale
            from PyQt6.QtTextToSpeech import QTextToSpeech

            if not QTextToSpeech.availableEngines():
                return False
            tts = QTextToSpeech()
            # Preferimos uma voz em português; se não houver, vai a que tiver.
            for loc in tts.availableLocales():
                if loc.language() == QLocale.Language.Portuguese:
                    tts.setLocale(loc)
                    break
            tts.setRate(-0.05)   # um pouquinho mais lento = mais condescendente
            tts.setPitch(-0.2)   # e mais grave = mais ameaçador
            self._engine, self._kind = tts, "qt"
            return True
        except Exception:
            return False

    def _try_pyttsx3(self) -> None:
        try:
            import pyttsx3  # noqa: F401
        except Exception:
            return
        # pyttsx3 bloqueia; roda numa thread própria com fila.
        self._q: queue.Queue[str] = queue.Queue()
        self._kind = "pyttsx3"
        threading.Thread(target=self._pyttsx3_loop, daemon=True).start()

    def _pyttsx3_loop(self) -> None:
        import pyttsx3

        try:
            eng = pyttsx3.init()
            for v in eng.getProperty("voices"):
                langs = " ".join(str(x) for x in (getattr(v, "languages", []) or []))
                if "pt" in (v.id or "").lower() or "pt" in langs.lower():
                    eng.setProperty("voice", v.id)
                    break
            eng.setProperty("rate", 165)
        except Exception:
            self._kind = None
            return
        while True:
            text = self._q.get()
            try:
                eng.say(text)
                eng.runAndWait()
            except Exception:
                pass

    def say(self, text: str) -> None:
        if self._kind == "qt":
            self._engine.stop()
            self._engine.say(text)
        elif self._kind == "pyttsx3":
            # Não acumula fila infinita de broncas: só a mais recente importa.
            while not self._q.empty():
                try:
                    self._q.get_nowait()
                except queue.Empty:
                    break
            self._q.put(text)
