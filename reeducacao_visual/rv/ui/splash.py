"""
Tela de inicialização dramática. Música de órgão não incluída (imagine).
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

from PyQt6.QtCore import Qt, pyqtSignal
from PyQt6.QtGui import QFont
from PyQt6.QtWidgets import (
    QCheckBox,
    QFileDialog,
    QFrame,
    QHBoxLayout,
    QLabel,
    QListWidget,
    QPushButton,
    QVBoxLayout,
    QWidget,
)

from .. import config as C
from .widgets import fit_font, heavy_font

VIDEO_FILTER = "Vídeos (*.mp4 *.mkv *.webm *.avi *.mov *.m4v);;Todos os arquivos (*)"


@dataclass
class SessionOptions:
    videos: list[str] = field(default_factory=list)
    laranja_mode: bool = True
    voice: bool = True
    use_webcam: bool = True
    camera_index: int = C.CAMERA_INDEX


STYLE = f"""
QWidget#splash {{ background: {C.BLACK}; }}
QLabel {{ color: {C.BONE}; }}
QCheckBox {{ color: {C.BONE}; font-size: 15px; spacing: 10px; }}
QCheckBox::indicator {{ width: 20px; height: 20px; border: 2px solid {C.RED}; background: #000; }}
QCheckBox::indicator:checked {{ background: {C.RED}; }}
QListWidget {{ background: #140000; color: {C.BONE}; border: 2px solid {C.DARK_RED};
              font-size: 13px; }}
QPushButton#small {{ background: #1c0000; color: {C.BONE}; border: 2px solid {C.RED};
                    padding: 8px 14px; font-weight: bold; }}
QPushButton#small:hover {{ background: {C.DARK_RED}; }}
QPushButton#big {{ background: {C.RED}; color: {C.BLACK}; border: 5px solid {C.BONE};
                  padding: 18px; }}
QPushButton#big:hover {{ background: #ff2a1a; }}
QPushButton#big:disabled {{ background: #3a0000; color: #6b4b4b; border-color: #3a0000; }}
QFrame#disclaimer {{ border: 3px dashed {C.RED}; background: #120000; }}
"""


class SplashWindow(QWidget):
    start_requested = pyqtSignal(object)  # SessionOptions

    def __init__(self, preset: SessionOptions):
        super().__init__()
        self.setObjectName("splash")
        self.setWindowTitle(f"{C.TITLE} — {C.SUBTITLE}")
        self.setStyleSheet(STYLE)
        self.resize(1000, 860)
        self._opts = preset

        root = QVBoxLayout(self)
        root.setContentsMargins(48, 32, 48, 32)
        root.setSpacing(14)

        eye = QLabel("◉ ◉")
        eye.setFont(heavy_font(40))
        eye.setStyleSheet(f"color:{C.RED};")
        eye.setAlignment(Qt.AlignmentFlag.AlignCenter)
        root.addWidget(eye)

        title = QLabel(C.TITLE.upper())
        title.setFont(fit_font(C.TITLE.upper(), 900, 42, 20))
        title.setStyleSheet(f"color:{C.RED}; letter-spacing: 2px;")
        title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        root.addWidget(title)

        sub = QLabel(f"– {C.SUBTITLE} –")
        sub.setFont(heavy_font(18, QFont.Weight.Bold))
        sub.setAlignment(Qt.AlignmentFlag.AlignCenter)
        root.addWidget(sub)

        box = QFrame(objectName="disclaimer")
        bl = QVBoxLayout(box)
        warn = QLabel("⚠ AVISO LEGAL (CÔMICO, MAS SÉRIO)")
        warn.setFont(heavy_font(14))
        warn.setStyleSheet(f"color:{C.RED};")
        txt = QLabel(
            f"{C.DISCLAIMER}<br><br>"
            f"<b>Palavra de segurança:</b> digite <b style='color:{C.RED}'>{C.SAFEWORD}</b> "
            "a qualquer momento durante a sessão para sair DE VERDADE, sem pegadinha.<br>"
            "O volume tem limite de segurança. Ninguém aqui quer te deixar surdo, só irritado."
        )
        txt.setWordWrap(True)
        txt.setTextFormat(Qt.TextFormat.RichText)
        txt.setStyleSheet("font-size: 14px;")
        txt.setMinimumHeight(110)
        bl.addWidget(warn)
        bl.addWidget(txt)
        root.addWidget(box)

        # --- material educativo (playlist) -----------------------------------
        lbl = QLabel("MATERIAL EDUCATIVO (o vídeo/playlist mais irritante que você tiver):")
        lbl.setFont(heavy_font(13, QFont.Weight.Bold))
        root.addWidget(lbl)
        self.list = QListWidget()
        self.list.setFixedHeight(96)
        root.addWidget(self.list)
        row = QHBoxLayout()
        add = QPushButton("+ Adicionar vídeos", objectName="small")
        add.clicked.connect(self._add_videos)
        clear = QPushButton("Limpar", objectName="small")
        clear.clicked.connect(self._clear_videos)
        row.addWidget(add)
        row.addWidget(clear)
        row.addStretch()
        root.addLayout(row)

        # --- opções ----------------------------------------------------------
        self.cb_laranja = QCheckBox("Modo Laranja Mecânica (cílios animados mantendo seus olhos abertos — só visual)")
        self.cb_laranja.setChecked(preset.laranja_mode)
        self.cb_voice = QCheckBox("Voz sintetizada passivo-agressiva")
        self.cb_voice.setChecked(preset.voice)
        self.cb_webcam = QCheckBox("Rastreamento ocular via webcam (desmarque = modo demo: o mouse finge ser seus olhos)")
        self.cb_webcam.setChecked(preset.use_webcam)
        self.cb_consent = QCheckBox("Eu consinto livremente com esta experiência ridícula e sei a palavra de segurança.")
        self.cb_consent.setStyleSheet(f"color:{C.RED}; font-weight:bold;")
        self.cb_consent.toggled.connect(self._refresh)
        for cb in (self.cb_laranja, self.cb_voice, self.cb_webcam, self.cb_consent):
            root.addWidget(cb)

        root.addStretch()
        self.go = QPushButton(objectName="big")
        self.go.setFont(heavy_font(28))
        self.go.setCursor(Qt.CursorShape.PointingHandCursor)
        self.go.clicked.connect(self._start)
        root.addWidget(self.go)

        for v in preset.videos:
            self.list.addItem(v)
        self._refresh()

    def _add_videos(self):
        files, _ = QFileDialog.getOpenFileNames(self, "Escolha o instrumento de tortura", "", VIDEO_FILTER)
        for f in files:
            self.list.addItem(f)
        self._refresh()

    def _clear_videos(self):
        self.list.clear()
        self._refresh()

    def _videos(self) -> list[str]:
        return [self.list.item(i).text() for i in range(self.list.count())]

    def _refresh(self):
        has_video = bool(self._videos())
        ok = has_video and self.cb_consent.isChecked()
        self.go.setEnabled(ok)
        if not has_video:
            self.go.setText("ESCOLHA O MATERIAL EDUCATIVO PRIMEIRO")
        elif not self.cb_consent.isChecked():
            self.go.setText("SEM CONSENTIMENTO, SEM TORTURA")
        else:
            self.go.setText("INICIAR SESSÃO DE TORTURA")

    def _start(self):
        missing = [v for v in self._videos() if not Path(v).exists()]
        if missing:
            self.go.setText("ARQUIVO SUMIU. ATÉ O VÍDEO FUGIU DE VOCÊ.")
            return
        self.start_requested.emit(
            SessionOptions(
                videos=self._videos(),
                laranja_mode=self.cb_laranja.isChecked(),
                voice=self.cb_voice.isChecked(),
                use_webcam=self.cb_webcam.isChecked(),
                camera_index=self._opts.camera_index,
            )
        )
