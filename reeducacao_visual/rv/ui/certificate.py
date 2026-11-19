"""
Certificado de Sobrevivência — emoldure e pendure na parede da vergonha.
"""

from __future__ import annotations

import datetime as dt

from PyQt6.QtCore import QRectF, Qt
from PyQt6.QtGui import QColor, QFont, QPainter, QPen
from PyQt6.QtWidgets import QDialog, QFileDialog, QHBoxLayout, QPushButton, QVBoxLayout, QWidget

from .. import config as C
from ..stats import SessionStats, fmt_time
from .widgets import fit_font, heavy_font


class CertificateCanvas(QWidget):
    def __init__(self, stats: SessionStats, parent=None):
        super().__init__(parent)
        self.stats = stats
        self.setFixedSize(1000, 700)
        self.issued = dt.datetime.now()

    def paintEvent(self, _):
        s = self.stats
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        w, h = self.width(), self.height()

        p.fillRect(self.rect(), QColor(C.BONE))
        p.setPen(QPen(QColor(C.RED), 14))
        p.drawRect(QRectF(14, 14, w - 28, h - 28))
        p.setPen(QPen(QColor(C.BLACK), 3))
        p.drawRect(QRectF(32, 32, w - 64, h - 64))

        p.setPen(QColor(C.RED))
        title = "CERTIFICADO DE SOBREVIVÊNCIA" if not s.safeword_used else "CERTIFICADO DE DESISTÊNCIA HONROSA"
        p.setFont(fit_font(title, w - 120, 40, 18))
        p.drawText(QRectF(0, 50, w, 60), Qt.AlignmentFlag.AlignHCenter, title)

        p.setPen(QColor(C.BLACK))
        p.setFont(heavy_font(13, QFont.Weight.Bold))
        p.drawText(QRectF(0, 110, w, 24), Qt.AlignmentFlag.AlignHCenter,
                   f"{C.TITLE} — {C.SUBTITLE}")

        body = QFont("DejaVu Serif", 13)
        body.setItalic(True)
        p.setFont(body)
        intro = (
            "Certificamos, para os devidos fins e para a vergonha eterna, que o(a) portador(a)\n"
            + ("assistiu ao material educativo até o amargo fim." if s.completed
               else "NÃO concluiu o material educativo, mas sobreviveu para contar a história.")
        )
        p.drawText(QRectF(60, 145, w - 120, 60), Qt.AlignmentFlag.AlignHCenter, intro)

        rows = [
            ("Tempo total na cadeira", fmt_time(s.total_time)),
            ("Tempo efetivo (olhos na tela)", fmt_time(s.effective_time)),
            ("Taxa de comprometimento", f"{s.commitment * 100:.1f}%"),
            ("Desvios de olhar punidos", str(s.look_away_count)),
            ("Tempo total de punição", fmt_time(s.punishment_time)),
            ("Tentativas de atalho (ESC, Alt+F4...)", str(s.escape_key_attempts)),
            ("Fugas de janela (covardias)", str(s.window_escapes)),
            ("Cliques no botão de desistência", str(s.give_ups)),
            ("Maior sequência de atenção", fmt_time(s.longest_streak)),
            ("Volume máximo atingido", f"{s.max_volume * 100:.0f}%"),
            ("Piscadas (por minuto)", f"{s.blink_count} ({s.blinks_per_minute:.0f}/min)"),
            ("Retrocessos por piscada",
             f"{s.blink_rewinds} (−{fmt_time(s.blink_rewound_s)})" if s.blink_rewind_mode else "modo desligado"),
        ]
        p.setFont(QFont("DejaVu Sans Mono", 13))
        y = 230
        for label, value in rows:
            p.setPen(QColor(C.BLACK))
            p.drawText(QRectF(90, y, 470, 28), Qt.AlignmentFlag.AlignLeft, label)
            p.setPen(QPen(QColor(120, 100, 90), 1, Qt.PenStyle.DotLine))
            p.drawLine(100, int(y + 22), 640, int(y + 22))
            p.setPen(QColor(C.RED))
            p.drawText(QRectF(470, y, 170, 28), Qt.AlignmentFlag.AlignRight, value)
            y += 29

        # carimbo da nota
        grade, comment = s.verdict()
        p.save()
        p.translate(820, 360)
        p.rotate(-14)
        p.setPen(QPen(QColor(225, 6, 0, 220), 8))
        p.setBrush(Qt.BrushStyle.NoBrush)
        p.drawEllipse(QRectF(-110, -110, 220, 220))
        p.setPen(QPen(QColor(225, 6, 0, 220), 3))
        p.drawEllipse(QRectF(-92, -92, 184, 184))
        p.setFont(heavy_font(72))
        p.drawText(QRectF(-110, -70, 220, 110), Qt.AlignmentFlag.AlignCenter, grade)
        p.setFont(heavy_font(11))
        p.drawText(QRectF(-110, 35, 220, 30), Qt.AlignmentFlag.AlignCenter, "NOTA FINAL")
        # textinho circular "REEDUCADO" ao redor
        p.setFont(heavy_font(10))
        label = "★ APROVADO PELO COMITÊ DE OLHOS ABERTOS ★ "
        for i, ch in enumerate(label):
            ang = i * (360 / len(label))
            p.save()
            p.rotate(ang)
            p.drawText(QRectF(-8, -106, 16, 16), Qt.AlignmentFlag.AlignCenter, ch)
            p.restore()
        p.restore()

        p.setPen(QColor(C.BLACK))
        f = QFont("DejaVu Serif", 13)
        f.setItalic(True)
        p.setFont(f)
        p.drawText(QRectF(60, 590, w - 120, 30), Qt.AlignmentFlag.AlignHCenter, f"Parecer técnico: “{comment}”")

        p.setFont(QFont("DejaVu Sans", 10))
        p.drawText(QRectF(60, 630, 420, 20), Qt.AlignmentFlag.AlignLeft,
                   f"Emitido em {self.issued:%d/%m/%Y às %H:%M}")
        p.drawText(QRectF(w - 480, 630, 420, 20), Qt.AlignmentFlag.AlignRight,
                   "Assinado: Dr. Webcam, PhD em Julgamento Ocular")
        p.setPen(QColor(120, 0, 0))
        p.drawText(QRectF(0, 652, w, 18), Qt.AlignmentFlag.AlignHCenter,
                   "Documento humorístico. Não tem validade legal, médica, nem moral.")


class CertificateDialog(QDialog):
    def __init__(self, stats: SessionStats, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Certificado de Sobrevivência")
        self.setStyleSheet(f"QDialog{{background:{C.BLACK};}}")
        lay = QVBoxLayout(self)
        self.canvas = CertificateCanvas(stats)
        lay.addWidget(self.canvas)
        row = QHBoxLayout()
        btn_style = (
            f"QPushButton{{background:{C.RED};color:{C.BLACK};border:3px solid {C.BONE};"
            "padding:10px 18px;font-weight:900;font-size:15px;}"
        )
        save = QPushButton("Salvar certificado (PNG)")
        save.setStyleSheet(btn_style)
        save.clicked.connect(self._save)
        done = QPushButton("Sair (finalmente)")
        done.setStyleSheet(btn_style)
        done.clicked.connect(self.accept)
        row.addStretch()
        row.addWidget(save)
        row.addWidget(done)
        lay.addLayout(row)

    def _save(self):
        name = f"certificado_sobrevivencia_{self.canvas.issued:%Y%m%d_%H%M}.png"
        path, _ = QFileDialog.getSaveFileName(self, "Salvar prova do seu sofrimento", name, "PNG (*.png)")
        if path:
            self.canvas.grab().save(path, "PNG")
