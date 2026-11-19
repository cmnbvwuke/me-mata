"""
Rastreamento ocular de verdade (sim, o "O Olho Que Tudo Vê" funciona).

Pipeline:
    webcam (OpenCV) -> MediaPipe FaceLandmarker (478 pontos + íris +
    blendshapes + matriz de pose da cabeça) -> métricas -> "está olhando?"

Métricas usadas para decidir se a pessoa olha para a tela:
    * yaw / pitch da cabeça (matriz de transformação facial do MediaPipe)
    * posição horizontal da íris dentro do olho (landmarks 468 e 473)
    * olhar para cima/baixo (blendshapes eyeLookUp / eyeLookDown)
    * olhos fechados (blendshape eyeBlink) — piscar rápido é tolerado pela
      janela de 1.5s da máquina de estados; dormir, não.

Tudo é comparado com uma CALIBRAÇÃO feita no início (a pessoa encara o
centro da tela por alguns segundos), porque a webcam quase nunca está
exatamente no centro do monitor.

Roda 100% offline depois que o modelo .task foi baixado.
"""

from __future__ import annotations

import math
import statistics
import threading
import time
from dataclasses import dataclass, replace

import cv2
import numpy as np
from PyQt6.QtCore import QObject, QThread, QTimer, pyqtSignal
from PyQt6.QtGui import QCursor, QGuiApplication, QImage

from . import config as C

# Índices de landmarks do MediaPipe Face Mesh (com refine/iris)
L_EYE_OUTER, L_EYE_INNER, L_IRIS = 33, 133, 468
R_EYE_INNER, R_EYE_OUTER, R_IRIS = 362, 263, 473
EYE_CONTOURS = [33, 160, 158, 133, 153, 144, 362, 385, 387, 263, 373, 380]


@dataclass(frozen=True)
class GazeMetrics:
    yaw: float = 0.0        # graus
    pitch: float = 0.0      # graus
    iris_h: float = 0.5     # 0 = canto esquerdo da imagem, 1 = canto direito
    eye_v: float = 0.0      # >0 olhando pra cima, <0 pra baixo (blendshapes)
    blink: float = 0.0      # 0 = aberto, 1 = fechado


@dataclass(frozen=True)
class GazeSample:
    looking: bool
    face_found: bool
    reason: str             # explicação cômica do veredito
    metrics: GazeMetrics | None
    timestamp: float


# ---------------------------------------------------------------------------
# Funções puras (testáveis sem câmera)
# ---------------------------------------------------------------------------
def _angle_diff(a: float, b: float) -> float:
    """Diferença angular em graus, tratando o 'pulo' de ±180."""
    d = (a - b + 180.0) % 360.0 - 180.0
    return d


def _projection_ratio(a: np.ndarray, b: np.ndarray, p: np.ndarray) -> float:
    """Posição de p projetado no segmento a->b (0 = a, 1 = b)."""
    ab = b - a
    denom = float(np.dot(ab, ab)) or 1e-9
    return float(np.dot(p - a, ab) / denom)


def extract_metrics(result) -> GazeMetrics | None:
    """Converte o resultado do FaceLandmarker em métricas de olhar."""
    if not result.face_landmarks:
        return None
    lm = result.face_landmarks[0]
    pts = np.array([[p.x, p.y] for p in lm], dtype=np.float64)
    if len(pts) < 478:  # modelo sem íris? Sem íris não há julgamento justo.
        return None

    iris_l = _projection_ratio(pts[L_EYE_OUTER], pts[L_EYE_INNER], pts[L_IRIS])
    iris_r = _projection_ratio(pts[R_EYE_INNER], pts[R_EYE_OUTER], pts[R_IRIS])
    iris_h = (iris_l + iris_r) / 2.0

    yaw = pitch = 0.0
    if result.facial_transformation_matrixes:
        m = np.asarray(result.facial_transformation_matrixes[0], dtype=np.float64)
        angles = cv2.RQDecomp3x3(m[:3, :3])[0]  # (pitch, yaw, roll) em graus
        pitch, yaw = float(angles[0]), float(angles[1])

    eye_v = blink = 0.0
    if result.face_blendshapes:
        bs = {c.category_name: c.score for c in result.face_blendshapes[0]}
        up = (bs.get("eyeLookUpLeft", 0) + bs.get("eyeLookUpRight", 0)) / 2
        down = (bs.get("eyeLookDownLeft", 0) + bs.get("eyeLookDownRight", 0)) / 2
        eye_v = up - down
        blink = (bs.get("eyeBlinkLeft", 0) + bs.get("eyeBlinkRight", 0)) / 2

    return GazeMetrics(yaw=yaw, pitch=pitch, iris_h=iris_h, eye_v=eye_v, blink=blink)


def smooth(prev: GazeMetrics | None, cur: GazeMetrics, alpha: float) -> GazeMetrics:
    """Média móvel exponencial para o veredito não tremer a cada frame."""
    if prev is None:
        return cur
    k = 1.0 - alpha

    def mix(a, b):
        return a + k * (b - a)

    return GazeMetrics(
        yaw=prev.yaw + k * _angle_diff(cur.yaw, prev.yaw),
        pitch=prev.pitch + k * _angle_diff(cur.pitch, prev.pitch),
        iris_h=mix(prev.iris_h, cur.iris_h),
        eye_v=mix(prev.eye_v, cur.eye_v),
        blink=mix(prev.blink, cur.blink),
    )


def classify(m: GazeMetrics | None, base: GazeMetrics) -> tuple[bool, str]:
    """Decide se a pessoa está olhando para a tela, relativo à calibração."""
    if m is None:
        return False, "rosto desaparecido"
    if m.blink > max(C.BLINK_CLOSED, base.blink + 0.30):
        return False, "olhos fechados (dormindo na aula?)"
    if abs(_angle_diff(m.yaw, base.yaw)) > C.MAX_YAW_DEG:
        return False, "cabeça virada pro lado"
    if abs(_angle_diff(m.pitch, base.pitch)) > C.MAX_PITCH_DEG:
        return False, "cabeça pra cima/baixo (celular?)"
    if abs(m.iris_h - base.iris_h) > C.MAX_IRIS_H_OFFSET:
        return False, "olhar de canto de olho"
    if abs(m.eye_v - base.eye_v) > C.MAX_EYE_V_OFFSET:
        return False, "olhos fugindo pra cima/baixo"
    return True, "olhando (bom menino)"


def baseline_from(samples: list[GazeMetrics]) -> GazeMetrics:
    """Mediana das amostras de calibração (robusta a piscadas)."""
    med = statistics.median
    return GazeMetrics(
        yaw=med(s.yaw for s in samples),
        pitch=med(s.pitch for s in samples),
        iris_h=med(s.iris_h for s in samples),
        eye_v=med(s.eye_v for s in samples),
        blink=med(s.blink for s in samples),
    )


# ---------------------------------------------------------------------------
# Thread da câmera
# ---------------------------------------------------------------------------
class GazeTracker(QThread):
    """Lê a webcam numa thread separada e emite um GazeSample por frame."""

    sample = pyqtSignal(object)    # GazeSample
    preview = pyqtSignal(QImage)   # miniatura com os olhos marcados
    failed = pyqtSignal(str)

    def __init__(self, camera_index: int = C.CAMERA_INDEX, model_path=C.MODEL_PATH):
        super().__init__()
        self._camera_index = camera_index
        self._model_path = str(model_path)
        self._running = True
        self._lock = threading.Lock()
        self._baseline = GazeMetrics()
        self._calib: list[GazeMetrics] | None = None

    # -- calibração ---------------------------------------------------------
    def begin_calibration(self) -> None:
        with self._lock:
            self._calib = []

    def end_calibration(self) -> bool:
        """Fecha a calibração. False se não houve amostras suficientes."""
        with self._lock:
            samples, self._calib = self._calib or [], None
            if len(samples) < 10:
                return False
            self._baseline = baseline_from(samples)
            return True

    def stop(self) -> None:
        self._running = False
        self.wait(2000)

    # -- loop principal -----------------------------------------------------
    def run(self) -> None:  # noqa: C901 - é um loop de câmera, é assim mesmo
        try:
            from mediapipe import Image, ImageFormat
            from mediapipe.tasks.python import BaseOptions, vision
        except Exception as exc:  # pragma: no cover
            self.failed.emit(f"MediaPipe não pôde ser carregado: {exc}")
            return

        cap = cv2.VideoCapture(self._camera_index)
        if not cap.isOpened():
            self.failed.emit(
                "Nenhuma webcam encontrada. Você cobriu a câmera com fita? "
                "Esperto. Use --sem-webcam para o modo de demonstração."
            )
            return
        cap.set(cv2.CAP_PROP_FPS, C.CAMERA_FPS)

        try:
            options = vision.FaceLandmarkerOptions(
                base_options=BaseOptions(model_asset_path=self._model_path),
                running_mode=vision.RunningMode.VIDEO,
                num_faces=1,
                output_face_blendshapes=True,
                output_facial_transformation_matrixes=True,
            )
            landmarker = vision.FaceLandmarker.create_from_options(options)
        except Exception as exc:
            cap.release()
            self.failed.emit(f"Falha ao carregar o modelo de rosto: {exc}")
            return

        t0 = time.monotonic()
        last_ts = -1
        smoothed: GazeMetrics | None = None
        frame_no = 0
        try:
            while self._running:
                ok, frame = cap.read()
                if not ok:
                    time.sleep(0.02)
                    continue
                frame = cv2.flip(frame, 1)  # espelho: fica mais natural no preview
                rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

                ts = int((time.monotonic() - t0) * 1000)
                if ts <= last_ts:  # MediaPipe exige timestamps crescentes
                    ts = last_ts + 1
                last_ts = ts

                result = landmarker.detect_for_video(
                    Image(image_format=ImageFormat.SRGB, data=rgb), ts
                )
                raw = extract_metrics(result)
                if raw is None:
                    smoothed = None
                else:
                    smoothed = smooth(smoothed, raw, C.SMOOTHING)

                with self._lock:
                    if self._calib is not None and raw is not None:
                        self._calib.append(raw)
                    base = self._baseline

                looking, reason = classify(smoothed, base)
                self.sample.emit(
                    GazeSample(looking, smoothed is not None, reason, smoothed, time.monotonic())
                )

                frame_no += 1
                if frame_no % 2 == 0:
                    self.preview.emit(self._make_preview(frame, result, looking))
        finally:
            landmarker.close()
            cap.release()

    @staticmethod
    def _make_preview(frame: np.ndarray, result, looking: bool) -> QImage:
        h, w = frame.shape[:2]
        color = (74, 217, 43) if looking else (0, 6, 225)  # BGR
        if result.face_landmarks:
            lm = result.face_landmarks[0]
            for idx in EYE_CONTOURS:
                p = lm[idx]
                cv2.circle(frame, (int(p.x * w), int(p.y * h)), 2, color, -1)
            for idx in (L_IRIS, R_IRIS):
                if idx < len(lm):
                    p = lm[idx]
                    cv2.circle(frame, (int(p.x * w), int(p.y * h)), 5, color, 2)
        small = cv2.resize(frame, (320, int(320 * h / w)))
        rgb = cv2.cvtColor(small, cv2.COLOR_BGR2RGB)
        qimg = QImage(rgb.data, rgb.shape[1], rgb.shape[0], rgb.strides[0],
                      QImage.Format.Format_RGB888)
        return qimg.copy()  # copy(): o buffer numpy morre ao fim da função


# ---------------------------------------------------------------------------
# Modo demonstração (sem webcam): o cursor do mouse finge ser seus olhos
# ---------------------------------------------------------------------------
class MouseGazeTracker(QObject):
    """
    Substituto para quem não tem webcam (ou quer testar a interface).
    "Olhando" = cursor do mouse dentro da região central da tela.
    Mesma interface de sinais do GazeTracker.
    """

    sample = pyqtSignal(object)
    preview = pyqtSignal(QImage)
    failed = pyqtSignal(str)

    def __init__(self, *_, **__):
        super().__init__()
        self._timer = QTimer(self)
        self._timer.setInterval(33)
        self._timer.timeout.connect(self._poll)

    def start(self) -> None:
        self._timer.start()

    def stop(self) -> None:
        self._timer.stop()

    def begin_calibration(self) -> None:
        pass

    def end_calibration(self) -> bool:
        return True

    def _poll(self) -> None:
        screen = QGuiApplication.primaryScreen()
        if screen is None:
            return
        g = screen.geometry()
        pos = QCursor.pos()
        cx, cy = g.center().x(), g.center().y()
        dx = abs(pos.x() - cx) / (g.width() / 2)
        dy = abs(pos.y() - cy) / (g.height() / 2)
        looking = dx < 0.6 and dy < 0.6
        reason = "cursor no centro (finge que é olho)" if looking else "cursor fugiu do centro"
        m = GazeMetrics(yaw=math.degrees(dx), pitch=math.degrees(dy))
        self.sample.emit(GazeSample(looking, True, reason, replace(m), time.monotonic()))
