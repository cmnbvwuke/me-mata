"""
Widgets da sessão: tudo que é vermelho, pisca e julga você.
"""

from __future__ import annotations

import math
import random

from PyQt6.QtCore import QPointF, QRectF, Qt, QTimer
from PyQt6.QtGui import (
    QBrush,
    QColor,
    QFont,
    QFontMetrics,
    QImage,
    QLinearGradient,
    QPainter,
    QPainterPath,
    QPen,
    QPixmap,
)
from PyQt6.QtMultimedia import QVideoFrame
from PyQt6.QtWidgets import QLabel, QProgressBar, QVBoxLayout, QWidget

from .. import config as C


def heavy_font(size: int, weight: QFont.Weight = QFont.Weight.Black) -> QFont:
    f = QFont()
    f.setFamilies(["Impact", "Anton", "Arial Black", "DejaVu Sans"])
    f.setPointSize(size)
    f.setWeight(weight)
    return f


def fit_font(text: str, max_width: int, start: int, minimum: int = 10) -> QFont:
    """Maior fonte pesada (<= start) em que o texto cabe em max_width pixels."""
    size = start
    while size > minimum:
        f = heavy_font(size)
        if QFontMetrics(f).horizontalAdvance(text) <= max_width:
            return f
        size -= 2
    return heavy_font(minimum)


# ---------------------------------------------------------------------------
# Vídeo
# ---------------------------------------------------------------------------
class VideoSurface(QWidget):
    """
    Pinta os quadros vindos de um QVideoSink. Usamos isso em vez do
    QVideoWidget porque o QVideoWidget é uma janela nativa e os overlays
    (punição, cílios...) não conseguem ficar por cima dele de forma confiável.
    """

    def __init__(self, parent=None):
        super().__init__(parent)
        self._image: QImage | None = None
        self.setAttribute(Qt.WidgetAttribute.WA_OpaquePaintEvent)

    def set_frame(self, frame: QVideoFrame) -> None:
        if frame.isValid():
            img = frame.toImage()
            if not img.isNull():
                self._image = img
                self.update()

    def clear(self) -> None:
        self._image = None
        self.update()

    def paintEvent(self, _):
        p = QPainter(self)
        p.fillRect(self.rect(), QColor(C.BLACK))
        if self._image is None:
            p.setPen(QColor(C.DARK_RED))
            p.setFont(heavy_font(28))
            p.drawText(self.rect(), Qt.AlignmentFlag.AlignCenter, "CARREGANDO SEU SOFRIMENTO...")
            return
        p.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform)
        size = self._image.size().scaled(self.size(), Qt.AspectRatioMode.KeepAspectRatio)
        x = (self.width() - size.width()) // 2
        y = (self.height() - size.height()) // 2
        p.drawImage(QRectF(x, y, size.width(), size.height()), self._image)


# ---------------------------------------------------------------------------
# Overlay vermelho de punição
# ---------------------------------------------------------------------------
class PunishOverlay(QWidget):
    """Tela vermelha pulsante com mensagem humilhante e barra de redenção."""

    def __init__(self, parent=None):
        super().__init__(parent)
        self._phase = 0.0
        self._recovery = 0.0
        self._timer = QTimer(self)
        self._timer.timeout.connect(self._tick)

        lay = QVBoxLayout(self)
        lay.setContentsMargins(80, 80, 80, 80)
        lay.addStretch(2)
        self.title = QLabel("PUNIÇÃO EM ANDAMENTO")
        self.title.setFont(heavy_font(64))
        self.title.setStyleSheet(f"color: {C.BONE}; letter-spacing: 4px;")
        self.title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.msg = QLabel()
        self.msg.setFont(heavy_font(34, QFont.Weight.Bold))
        self.msg.setStyleSheet("color: white;")
        self.msg.setWordWrap(True)
        self.msg.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.hint = QLabel()
        self.hint.setFont(heavy_font(18, QFont.Weight.Bold))
        self.hint.setStyleSheet(f"color: {C.BONE};")
        self.hint.setWordWrap(True)
        self.hint.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.bar = QProgressBar()
        self.bar.setRange(0, 1000)
        self.bar.setTextVisible(False)
        self.bar.setFixedHeight(18)
        self.bar.setStyleSheet(
            "QProgressBar{background:rgba(0,0,0,150);border:2px solid #f2e8d5;}"
            f"QProgressBar::chunk{{background:{C.GREEN};}}"
        )
        for w in (self.title, self.msg, self.hint):
            w.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
            lay.addWidget(w)
        lay.addSpacing(20)
        lay.addWidget(self.bar)
        lay.addStretch(3)
        self.hide()

    def show_alert(self, title: str, message: str, hint: str, show_bar: bool = True) -> None:
        self.setGeometry(self.parentWidget().rect())
        self.title.setText(title)
        self.title.setFont(fit_font(title, self.width() - 200, 64, 24))
        self.msg.setText(message)
        self.hint.setText(hint)
        self.bar.setVisible(show_bar)
        self.set_recovery(0.0)
        self.raise_()
        self.show()
        self._timer.start(40)

    def dismiss(self) -> None:
        self._timer.stop()
        self.hide()

    def set_recovery(self, value: float) -> None:
        self._recovery = value
        self.bar.setValue(int(value * 1000))

    def _tick(self):
        self._phase += 0.12
        # tremidinha no título, porque sutileza não é o nosso forte
        self.title.setContentsMargins(random.randint(-3, 3), 0, 0, 0)
        self.update()

    def paintEvent(self, _):
        p = QPainter(self)
        alpha = int(170 + 50 * math.sin(self._phase))
        p.fillRect(self.rect(), QColor(170, 0, 0, alpha))
        # scanlines de filme de terror barato
        p.setPen(QColor(0, 0, 0, 60))
        for y in range(0, self.height(), 4):
            p.drawLine(0, y, self.width(), y)
        # bordas mais escuras (vinheta)
        g = QLinearGradient(0, 0, 0, self.height())
        g.setColorAt(0, QColor(0, 0, 0, 160))
        g.setColorAt(0.25, QColor(0, 0, 0, 0))
        g.setColorAt(0.75, QColor(0, 0, 0, 0))
        g.setColorAt(1, QColor(0, 0, 0, 160))
        p.fillRect(self.rect(), QBrush(g))


# ---------------------------------------------------------------------------
# Calibração
# ---------------------------------------------------------------------------
class CalibrationOverlay(QWidget):
    """Alvo no centro da tela para a pessoa encarar durante a calibração."""

    def __init__(self, parent=None):
        super().__init__(parent)
        self._progress = 0.0
        self._text = C.CALIBRATION_TEXT
        self.hide()

    def set_state(self, progress: float, text: str | None = None) -> None:
        self._progress = progress
        if text is not None:
            self._text = text
        self.update()

    def paintEvent(self, _):
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        p.fillRect(self.rect(), QColor(10, 0, 0, 235))
        c = QPointF(self.width() / 2, self.height() / 2)
        # alvo
        for i, r in enumerate((90, 60, 30)):
            p.setPen(QPen(QColor(C.RED), 6 if i == 0 else 4))
            p.setBrush(Qt.BrushStyle.NoBrush)
            p.drawEllipse(c, r, r)
        p.setBrush(QColor(C.RED))
        p.drawEllipse(c, 8, 8)
        # anel de progresso
        p.setPen(QPen(QColor(C.BONE), 10, cap=Qt.PenCapStyle.RoundCap))
        rect = QRectF(c.x() - 120, c.y() - 120, 240, 240)
        p.drawArc(rect, 90 * 16, -int(360 * 16 * self._progress))
        p.setPen(QColor(C.BONE))
        p.setFont(heavy_font(26))
        p.drawText(QRectF(0, c.y() + 150, self.width(), 220),
                   Qt.AlignmentFlag.AlignHCenter | Qt.AlignmentFlag.AlignTop, self._text)


# ---------------------------------------------------------------------------
# Modo Laranja Mecânica: cílios animados que "mantêm seus olhos abertos"
# ---------------------------------------------------------------------------
class LashesOverlay(QWidget):
    """
    Pálpebras gigantes nas bordas da tela, presas por grampos metálicos,
    com cílios que tremem. 100% visual — ninguém encosta no seu olho de verdade.
    Quando você desvia o olhar, as pálpebras começam a "fechar" (cair).
    """

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setAttribute(Qt.WidgetAttribute.WA_TransparentForMouseEvents)
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
        self._t = 0.0
        self._droop = 0.0        # 0 = arreganhado, 1 = caindo
        self._target_droop = 0.0
        self._seed = [random.uniform(0.7, 1.3) for _ in range(80)]
        self._timer = QTimer(self)
        self._timer.timeout.connect(self._tick)
        self._timer.start(33)

    def set_distracted(self, distracted: bool) -> None:
        self._target_droop = 1.0 if distracted else 0.0

    def _tick(self):
        self._t += 0.033
        self._droop += (self._target_droop - self._droop) * 0.08
        self.update()

    def _lid(self, p: QPainter, top: bool):
        w, h = self.width(), self.height()
        depth = h * (0.07 + 0.10 * self._droop)
        sign = 1 if top else -1
        y0 = 0 if top else h
        # pálpebra (arco de pele avermelhada)
        path = QPainterPath()
        path.moveTo(0, y0)
        path.lineTo(0, y0 + sign * depth * 0.5)
        path.quadTo(w / 2, y0 + sign * depth * 1.9, w, y0 + sign * depth * 0.5)
        path.lineTo(w, y0)
        path.closeSubpath()
        g = QLinearGradient(0, y0, 0, y0 + sign * depth * 1.6)
        g.setColorAt(0, QColor(60, 15, 15, 255))
        g.setColorAt(1, QColor(150, 60, 55, 235))
        p.fillPath(path, QBrush(g))
        p.setPen(QPen(QColor(20, 0, 0), 5))
        p.drawPath(path)

        # cílios ao longo da borda da pálpebra
        n = 34 if top else 26
        length_base = (85 if top else 45) * (1 - 0.3 * self._droop)
        for i in range(n):
            t = (i + 0.5) / n
            # posição na curva quadrática da borda: B(t) = P0 + (P1-P0)·2t(1-t)
            x = w * t
            edge = y0 + sign * (depth * 0.5 + (depth * 1.9 - depth * 0.5) * 2 * t * (1 - t))
            wobble = math.sin(self._t * 9 + i * 1.7) * 6 * self._seed[i]
            ln = length_base * self._seed[i]
            # curvados "pra fora" do olho — mantidos abertos à força
            ctrl = QPointF(x + wobble + (t - 0.5) * 40, edge + sign * ln * 0.55)
            tip = QPointF(x + (t - 0.5) * 90 + wobble * 2, edge + sign * ln * (0.35 + 0.6 * self._droop))
            lash = QPainterPath(QPointF(x, edge))
            lash.quadTo(ctrl, tip)
            p.setPen(QPen(QColor(5, 5, 5), 5 if top else 4, cap=Qt.PenCapStyle.RoundCap))
            p.drawPath(lash)

    def _clamp(self, p: QPainter, x: float, top: bool):
        """Grampo metálico de 'retrator de pálpebra'. Puro cosplay."""
        h = self.height()
        depth = h * (0.07 + 0.10 * self._droop)
        y_edge = (depth * 1.25) if top else h - depth * 1.25
        y_anchor = -10 if top else h + 10
        jitter = math.sin(self._t * 3 + x) * 3
        metal = QPen(QColor(190, 195, 205), 9, cap=Qt.PenCapStyle.RoundCap)
        p.setPen(metal)
        path = QPainterPath(QPointF(x - 40, y_anchor))
        path.lineTo(QPointF(x + jitter, y_edge))
        hook = 26 if top else -26
        path.quadTo(QPointF(x + 30 + jitter, y_edge + hook), QPointF(x + 18 + jitter, y_edge + hook * 1.6))
        p.drawPath(path)
        p.setPen(QPen(QColor(255, 255, 255, 150), 3))
        p.drawPath(path)

    def paintEvent(self, _):
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        self._lid(p, top=True)
        self._lid(p, top=False)
        w = self.width()
        for x in (w * 0.22, w * 0.78):
            self._clamp(p, x, top=True)
            self._clamp(p, x, top=False)
        p.setPen(QColor(C.BONE))
        p.setFont(heavy_font(12, QFont.Weight.Bold))
        p.drawText(QRectF(0, 6, w, 24), Qt.AlignmentFlag.AlignHCenter,
                   "MODO LARANJA MECÂNICA ATIVO — PÁLPEBRAS SOB CUSTÓDIA")


# ---------------------------------------------------------------------------
# Toast sarcástico
# ---------------------------------------------------------------------------
class Toast(QLabel):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.setWordWrap(True)
        self.setFont(heavy_font(22, QFont.Weight.Bold))
        self.setStyleSheet(
            f"background: rgba(10,10,10,225); color: {C.BONE};"
            f"border: 4px solid {C.RED}; padding: 14px 26px;"
        )
        self._timer = QTimer(self)
        self._timer.setSingleShot(True)
        self._timer.timeout.connect(self.hide)
        self.hide()

    def pop(self, text: str, ms: int = 2400) -> None:
        self.setText(text)
        pw = self.parentWidget().width()
        self.setFixedWidth(min(900, int(pw * 0.7)))
        self.adjustSize()
        self.move((pw - self.width()) // 2, 290)  # abaixo da miniatura da câmera
        self.raise_()
        self.show()
        self._timer.start(ms)


# ---------------------------------------------------------------------------
# Miniatura da câmera
# ---------------------------------------------------------------------------
class CameraBadge(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setFixedSize(250, 222)
        lay = QVBoxLayout(self)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.setSpacing(0)
        title = QLabel("O OLHO QUE TUDO VÊ")
        title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        title.setFont(heavy_font(12))
        title.setStyleSheet(f"background:{C.RED}; color:{C.BLACK}; padding:3px;")
        self.view = QLabel("sem sinal\n(suspeito)")
        self.view.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.view.setStyleSheet(f"background:{C.BLACK}; color:{C.RED}; border:3px solid {C.RED};")
        self.view.setFixedSize(250, 188)
        lay.addWidget(title)
        lay.addWidget(self.view)

    def set_image(self, img: QImage) -> None:
        self.view.setPixmap(
            QPixmap.fromImage(img).scaled(
                244, 182, Qt.AspectRatioMode.KeepAspectRatio,
                Qt.TransformationMode.SmoothTransformation,
            )
        )
