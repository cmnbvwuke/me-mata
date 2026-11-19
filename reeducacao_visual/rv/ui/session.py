"""
A Sessão de Tortura em si: player inescapável + rastreamento ocular + punições.

Regras do jogo:
  * Sem play/pause/seek. O único que aperta play aqui é o sistema.
  * Desviou o olhar por > 1.5s -> pausa, overlay vermelho, volume +10%.
  * Só volta depois de 2s seguidos olhando para a tela.
  * Minimizar/trocar de janela -> pausa e "Covarde detectado".
  * Atalhos (ESC, Alt+F4, Ctrl+W, espaço, setas...) viram broncas.
  * Botão de desistência escondido -> reinicia o vídeo do zero.
  * Piscadas são contadas; no Modo Pálpebra Proibida cada uma volta o vídeo 10s.
  * Palavra de segurança (config.SAFEWORD) -> sai DE VERDADE. Sempre.

O que este programa NÃO faz (de propósito): não instala hooks de teclado no
sistema operacional, não bloqueia Ctrl+Alt+Del, não impede o gerenciador de
tarefas. É uma brincadeira, não um malware.
"""

from __future__ import annotations

import random
import time

from PyQt6.QtCore import QEvent, QObject, Qt, QTimer, QUrl, pyqtSignal
from PyQt6.QtGui import QKeyEvent
from PyQt6.QtMultimedia import QAudioOutput, QMediaPlayer, QVideoSink
from PyQt6.QtWidgets import (
    QApplication,
    QHBoxLayout,
    QLabel,
    QMessageBox,
    QProgressBar,
    QPushButton,
    QVBoxLayout,
    QWidget,
)

from .. import config as C
from ..attention import AttentionMonitor, Event, State
from ..gaze import GazeSample, GazeTracker, MouseGazeTracker
from ..stats import SessionStats, fmt_time
from ..voice import Voice
from .splash import SessionOptions
from .widgets import (
    CalibrationOverlay,
    CameraBadge,
    LashesOverlay,
    PunishOverlay,
    Toast,
    VideoSurface,
    heavy_font,
)

# Teclas que alguém poderia usar para fugir/controlar o vídeo.
CONTROL_KEYS = {
    Qt.Key.Key_Escape, Qt.Key.Key_Space, Qt.Key.Key_Left, Qt.Key.Key_Right,
    Qt.Key.Key_Up, Qt.Key.Key_Down, Qt.Key.Key_F11, Qt.Key.Key_F4,
    Qt.Key.Key_MediaPlay, Qt.Key.Key_MediaPause, Qt.Key.Key_MediaTogglePlayPause,
    Qt.Key.Key_MediaNext, Qt.Key.Key_MediaStop, Qt.Key.Key_PageDown, Qt.Key.Key_PageUp,
    Qt.Key.Key_Home, Qt.Key.Key_End, Qt.Key.Key_Tab, Qt.Key.Key_K, Qt.Key.Key_J, Qt.Key.Key_L,
}


class _Phase:
    CALIBRATING = "calibrating"
    RUNNING = "running"
    FINISHED = "finished"


class SessionWindow(QWidget):
    finished = pyqtSignal(object)  # SessionStats

    def __init__(self, opts: SessionOptions):
        super().__init__()
        self.opts = opts
        self.setWindowTitle(f"{C.TITLE} — sessão em andamento")
        self.setWindowFlag(Qt.WindowType.WindowStaysOnTopHint, True)
        self.setObjectName("session")
        self.setStyleSheet(f"QWidget#session{{background:{C.BLACK};}} QLabel{{background:transparent;}}")
        self.setFocusPolicy(Qt.FocusPolicy.StrongFocus)

        self.stats = SessionStats(blink_rewind_mode=opts.blink_rewind)
        self._last_blink_voice = 0.0
        self.monitor = AttentionMonitor(C.LOOK_AWAY_TOLERANCE_S, C.LOOK_BACK_REQUIRED_S)
        self.voice = Voice(opts.voice)
        self.phase = _Phase.CALIBRATING
        self.escape_paused = False      # janela perdeu o foco
        self.allow_close = False
        self.volume = C.VOLUME_START
        self.playlist = list(opts.videos)
        self.index = 0
        self.video_effective = 0.0      # tempo efetivo no vídeo atual (p/ barra)
        self.video_duration = 0.0
        self._last_tick = time.monotonic()
        self._last_key_toast = 0.0
        self._typed = ""
        self._last_sample: GazeSample | None = None
        self._calib_t0: float | None = None  # definido quando a calibração começa

        self._build_ui()
        self._build_player()
        self._build_tracker()

        # Filtro global de teclado (só dentro deste app — nada de hooks no SO).
        QApplication.instance().installEventFilter(self)
        QApplication.instance().applicationStateChanged.connect(self._on_app_state)
        QApplication.instance().aboutToQuit.connect(self._shutdown)

        self._ticker = QTimer(self)
        self._ticker.timeout.connect(self._tick)
        self._ticker.start(100)

    # ------------------------------------------------------------------ UI --
    def _build_ui(self):
        self.surface = VideoSurface(self)
        lay = QVBoxLayout(self)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.setSpacing(0)
        lay.addWidget(self.surface, 1)
        lay.addWidget(self._build_hud())

        self.lashes = LashesOverlay(self.surface) if self.opts.laranja_mode else None
        self.camera = CameraBadge(self)
        self.grace = QLabel(self)
        self.grace.setFont(heavy_font(20))
        self.grace.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.grace.setStyleSheet(
            "background: rgba(255,200,0,230); color:#000; padding: 10px 20px; border: 4px solid #000;"
        )
        self.grace.hide()
        self.punish = PunishOverlay(self)
        self.calib = CalibrationOverlay(self)
        self.toast = Toast(self)

        # O famoso botão de desistência escondido: quase invisível, canto inferior esquerdo.
        self.give_up_btn = QPushButton("desistir", self)
        self.give_up_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self.give_up_btn.setStyleSheet(
            "QPushButton{background:transparent;color:rgba(242,232,213,14);border:none;"
            "font-size:11px;padding:2px 6px;}"
            "QPushButton:hover{color:rgba(242,232,213,120);}"
        )
        self.give_up_btn.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        self.give_up_btn.clicked.connect(self._on_give_up)

    def _build_hud(self) -> QWidget:
        hud = QWidget(objectName="hud")
        hud.setAttribute(Qt.WidgetAttribute.WA_StyledBackground)
        hud.setStyleSheet(f"QWidget#hud{{background:{C.BLACK}; border-top: 4px solid {C.RED};}}")
        v = QVBoxLayout(hud)
        v.setContentsMargins(24, 10, 24, 12)
        v.setSpacing(6)

        self.progress = QProgressBar()
        self.progress.setRange(0, 1000)
        self.progress.setTextVisible(True)
        self.progress.setFormat("PROGRESSO EFETIVO DA REEDUCAÇÃO: %p%")
        self.progress.setFixedHeight(26)
        self.progress.setStyleSheet(
            f"QProgressBar{{background:#1a0000;border:2px solid {C.RED};color:{C.BONE};"
            "font-weight:900;font-size:13px;text-align:center;}"
            f"QProgressBar::chunk{{background:qlineargradient(x1:0,y1:0,x2:1,y2:0,"
            f"stop:0 {C.DARK_RED}, stop:1 {C.RED});}}"
        )
        v.addWidget(self.progress)

        row = QHBoxLayout()
        self.lbl_eye = QLabel()
        self.lbl_eye.setFont(heavy_font(16))
        self.lbl_info = QLabel()
        self.lbl_info.setStyleSheet(f"color:{C.BONE}; font-size:14px; font-weight:bold;")
        self.lbl_info.setTextFormat(Qt.TextFormat.RichText)
        self.lbl_volume = QLabel()
        self.lbl_volume.setFont(heavy_font(14))
        self.lbl_volume.setStyleSheet(f"color:{C.RED};")
        row.addWidget(self.lbl_eye)
        row.addSpacing(30)
        row.addWidget(self.lbl_info, 1)
        row.addWidget(self.lbl_volume)
        v.addLayout(row)
        return hud

    def resizeEvent(self, e):
        super().resizeEvent(e)
        r = self.rect()
        self.punish.setGeometry(r)
        self.calib.setGeometry(r)
        if self.lashes:
            self.lashes.setGeometry(self.surface.rect())
        self.camera.move(r.width() - self.camera.width() - 20, 40)
        self.give_up_btn.adjustSize()
        self.give_up_btn.move(4, self.surface.height() - self.give_up_btn.height() - 2)
        self.grace.adjustSize()
        self.grace.move((r.width() - self.grace.width()) // 2, self.surface.height() - 120)

    # -------------------------------------------------------------- player --
    def _build_player(self):
        self.player = QMediaPlayer(self)
        self.audio = QAudioOutput(self)
        self.audio.setVolume(self.volume)
        self.stats.max_volume = self.volume
        self.player.setAudioOutput(self.audio)
        self.sink = QVideoSink(self)
        self.sink.videoFrameChanged.connect(self.surface.set_frame)
        self.player.setVideoSink(self.sink)
        self.player.mediaStatusChanged.connect(self._on_media_status)
        self.player.durationChanged.connect(lambda d: setattr(self, "video_duration", d / 1000))
        self.player.errorOccurred.connect(self._on_player_error)

    def _load_current(self):
        self.video_effective = 0.0
        self.video_duration = 0.0
        self.surface.clear()
        self.player.setSource(QUrl.fromLocalFile(self.playlist[self.index]))

    def _apply_playback(self):
        """Único lugar que decide se o vídeo roda. Controles do usuário: zero."""
        should_play = (
            self.phase == _Phase.RUNNING
            and not self.monitor.is_punished
            and not self.escape_paused
            and QApplication.activeModalWidget() is None
        )
        state = self.player.playbackState()
        if should_play and state != QMediaPlayer.PlaybackState.PlayingState:
            self.player.play()
        elif not should_play and state == QMediaPlayer.PlaybackState.PlayingState:
            self.player.pause()

    def _on_media_status(self, status):
        if status == QMediaPlayer.MediaStatus.EndOfMedia and self.phase == _Phase.RUNNING:
            self.index += 1
            if self.index < len(self.playlist):
                self.toast.pop(f"Episódio {self.index + 1}/{len(self.playlist)}. Achou que tinha acabado? Que fofo.")
                self._load_current()
                self._apply_playback()
            else:
                self.stats.completed = True
                self._finish()

    def _on_player_error(self, _err, msg):
        self.toast.pop(f"O vídeo se recusou a tocar ({msg}). Até ele tem limites. Pulando...", 4000)
        self._on_media_status(QMediaPlayer.MediaStatus.EndOfMedia)

    # ------------------------------------------------------------- tracker --
    def _build_tracker(self):
        cls = GazeTracker if self.opts.use_webcam else MouseGazeTracker
        self.tracker = cls(self.opts.camera_index)
        self.tracker.sample.connect(self._on_sample)
        self.tracker.preview.connect(self.camera.set_image)
        self.tracker.failed.connect(self._on_tracker_failed)
        self.tracker.blink.connect(self._on_blink)
        if not self.opts.use_webcam:
            self.camera.view.setText("MODO DEMO\no mouse é\nseus olhos")

    def start(self):
        self.showFullScreen()
        self.raise_()
        self.activateWindow()
        self.tracker.start()
        QTimer.singleShot(400, self._start_calibration)

    def _start_calibration(self):
        self.phase = _Phase.CALIBRATING
        self.calib.setGeometry(self.rect())
        self.calib.set_state(0.0, C.CALIBRATION_TEXT)
        self.calib.raise_()
        self.calib.show()
        self.tracker.begin_calibration()
        self._calib_t0 = time.monotonic()

    def _calibration_tick(self):
        if self._calib_t0 is None:
            return
        elapsed = time.monotonic() - self._calib_t0
        self.calib.set_state(min(1.0, elapsed / C.CALIBRATION_S))
        if elapsed < C.CALIBRATION_S:
            return
        if not self.tracker.end_calibration():
            self.calib.set_state(0.0, "CALIBRAÇÃO FALHOU\n\n" + C.NO_FACE_MESSAGE + "\nDe novo. Encare o alvo.")
            self.tracker.begin_calibration()
            self._calib_t0 = time.monotonic() + 1.5  # pausinha dramática
            return
        self.calib.hide()
        self.phase = _Phase.RUNNING
        self.monitor.reset()
        self._load_current()
        self._apply_playback()
        self.toast.pop("Calibração concluída. Agora seus olhos me pertencem.", 3000)
        self.voice.say(random.choice(C.VOICE_LINES_ON_START))

    def _on_tracker_failed(self, msg: str):
        QMessageBox.critical(self, "O Olho Que Tudo Vê ficou cego", msg)
        self.allow_close = True
        self.stats.safeword_used = True  # saída forçada, sem culpa
        self._finish()

    def _on_sample(self, s: GazeSample):
        self._last_sample = s
        if self.phase != _Phase.RUNNING:
            return
        now = time.monotonic()
        ev = self.monitor.update(s.looking, now)
        if ev is Event.VIOLATION:
            self._punish()
        elif ev is Event.RESUME:
            self._forgive()
        if self.monitor.is_punished and not self.escape_paused:
            self.punish.set_recovery(self.monitor.recovery_progress(now))
        if self.lashes:
            self.lashes.set_distracted(not s.looking)

    # ------------------------------------------------------------ punições --
    def _punish(self):
        self.stats.look_away_count += 1
        self.volume = min(C.VOLUME_SAFETY_CAP, self.volume + C.VOLUME_STEP)
        self.audio.setVolume(self.volume)
        self.stats.max_volume = max(self.stats.max_volume, self.volume)
        msg = random.choice(C.LOOK_AWAY_MESSAGES).format(n=self.stats.look_away_count)
        if not self.escape_paused:
            self.punish.show_alert(
                "PUNIÇÃO EM ANDAMENTO", msg,
                f"Olhe para a tela por {C.LOOK_BACK_REQUIRED_S:.0f} segundos seguidos para continuar.  "
                f"Volume agora: {self.volume * 100:.0f}%"
                + ("  (limite de segurança — sorte sua)" if self.volume >= C.VOLUME_SAFETY_CAP else ""),
            )
        self.voice.say(msg)
        self._apply_playback()

    def _forgive(self):
        if not self.escape_paused:
            self.punish.dismiss()
        self.toast.pop(random.choice(C.RESUME_MESSAGES))
        self._apply_playback()

    def _on_blink(self):
        """Uma piscada completa. Sempre conta; no Modo Pálpebra Proibida, rebobina."""
        if self.phase != _Phase.RUNNING:
            return
        self.stats.blink_count += 1
        if not self.opts.blink_rewind or self.monitor.is_punished or self.escape_paused:
            return  # vídeo já está pausado: castigo em dobro seria crueldade (de verdade)
        pos = self.player.position()
        back_ms = min(pos, int(C.BLINK_REWIND_S * 1000))
        self.player.setPosition(pos - back_ms)
        back = back_ms / 1000
        self.video_effective = max(0.0, self.video_effective - back)
        self.stats.blink_rewinds += 1
        self.stats.blink_rewound_s += back
        msg = random.choice(C.BLINK_REWIND_MESSAGES).format(s=C.BLINK_REWIND_S)
        self.toast.pop(f"⏪ {msg}", 1800)
        now = time.monotonic()
        if now - self._last_blink_voice > 6:  # a voz não acompanha o ritmo das suas pálpebras
            self._last_blink_voice = now
            self.voice.say(msg)

    def _on_give_up(self):
        if self.phase != _Phase.RUNNING:
            return
        self.stats.give_ups += 1
        self.player.setPosition(0)
        self.video_effective = 0.0
        self.toast.pop(C.GIVE_UP_MESSAGE, 3500)
        self.voice.say(C.GIVE_UP_MESSAGE)

    def _on_app_state(self, state):
        if self.phase == _Phase.FINISHED:
            return
        active = state == Qt.ApplicationState.ApplicationActive
        if not active and not self.escape_paused:
            self.escape_paused = True
            self.stats.window_escapes += 1
            self.punish.show_alert("COVARDE DETECTADO", C.WINDOW_ESCAPE_MESSAGE,
                                   "Volte para a janela. A terapia espera.", show_bar=False)
            self.voice.say(C.WINDOW_ESCAPE_MESSAGE)
            self._apply_playback()
            QTimer.singleShot(600, self._reclaim_window)
        elif active and self.escape_paused:
            self.escape_paused = False
            if self.monitor.is_punished:
                self.punish.show_alert("PUNIÇÃO EM ANDAMENTO", "Voltou, mas os olhos ainda estão devendo.",
                                       f"Olhe para a tela por {C.LOOK_BACK_REQUIRED_S:.0f} segundos.")
            else:
                self.punish.dismiss()
            self.toast.pop("Voltou rápido. Sabia que não ia aguentar ficar longe.")
            self._apply_playback()

    def _reclaim_window(self):
        """Tenta trazer a janela de volta (funciona na maioria dos WMs; no Wayland, nem sempre)."""
        if self.phase == _Phase.FINISHED:
            return
        self.setWindowState(Qt.WindowState.WindowFullScreen | Qt.WindowState.WindowActive)
        self.showFullScreen()
        self.raise_()
        self.activateWindow()

    def changeEvent(self, e):
        # Minimizar = fuga. Desfazemos com carinho.
        if e.type() == QEvent.Type.WindowStateChange and self.isMinimized() and self.phase != _Phase.FINISHED:
            QTimer.singleShot(300, self._reclaim_window)
        super().changeEvent(e)

    # -------------------------------------------------------------- teclado --
    def eventFilter(self, obj: QObject, e: QEvent) -> bool:
        if self.phase == _Phase.FINISHED or QApplication.activeModalWidget() is not None:
            return False
        # modo demo: botão direito do mouse = piscar
        if (not self.opts.use_webcam and e.type() == QEvent.Type.MouseButtonPress
                and e.button() == Qt.MouseButton.RightButton):
            self.tracker.blink.emit()
            return True
        if e.type() == QEvent.Type.ShortcutOverride:
            e.accept()      # nenhum atalho global do Qt dispara durante a sessão
            return True
        if e.type() == QEvent.Type.KeyPress:
            self._handle_key(e)
            return True
        if e.type() == QEvent.Type.KeyRelease:
            return True
        return False

    def _handle_key(self, e: QKeyEvent):
        # 1) palavra de segurança: SEMPRE tem prioridade
        ch = e.text().upper()
        if ch.isalpha():
            self._typed = (self._typed + ch)[-len(C.SAFEWORD):]
            if self._typed == C.SAFEWORD:
                self._typed = ""
                self._safeword()
                return
        if e.isAutoRepeat():
            return
        mods = e.modifiers()
        key = Qt.Key(e.key())
        ctrl_alt = mods & (Qt.KeyboardModifier.ControlModifier | Qt.KeyboardModifier.AltModifier)
        if key in CONTROL_KEYS or (ctrl_alt and key not in (Qt.Key.Key_Control, Qt.Key.Key_Alt)):
            self.stats.escape_key_attempts += 1
            now = time.monotonic()
            if now - self._last_key_toast > 0.6:
                self._last_key_toast = now
                if key == Qt.Key.Key_F4 and mods & Qt.KeyboardModifier.AltModifier:
                    msg = "Alt+F4 é coisa de quem não tem compromisso."
                elif key == Qt.Key.Key_W and mods & Qt.KeyboardModifier.ControlModifier:
                    msg = "Ctrl+W? W de 'Wow, que covardia'."
                else:
                    msg = random.choice(C.ESCAPE_KEY_MESSAGES)
                self.toast.pop(msg)

    def closeEvent(self, e):
        if self.allow_close:
            e.accept()
            return
        e.ignore()
        self.stats.escape_key_attempts += 1
        self.toast.pop("Fechar? Que gracinha. Não.")

    def _safeword(self):
        """A saída de verdade. Sem pegadinha (só uma confirmação, pra não ser acidente)."""
        self.player.pause()
        box = QMessageBox(self)
        box.setWindowTitle("Palavra de segurança")
        box.setText(
            "Palavra de segurança reconhecida.\n\n"
            "Quer encerrar a sessão? Pode. De verdade. Sem pegadinha."
        )
        yes = box.addButton("Sim, me tira daqui", QMessageBox.ButtonRole.AcceptRole)
        box.addButton("Não, eu aguento", QMessageBox.ButtonRole.RejectRole)
        box.setDefaultButton(yes)
        box.exec()
        if box.clickedButton() is yes:
            self.stats.safeword_used = True
            self._finish()
        else:
            self.toast.pop("Corajoso. Ou teimoso. Continuando...")
            self._apply_playback()

    # ---------------------------------------------------------------- tick --
    def _tick(self):
        now = time.monotonic()
        dt = now - self._last_tick
        self._last_tick = now

        if self.phase == _Phase.CALIBRATING:
            self._calibration_tick()
            return
        if self.phase != _Phase.RUNNING:
            return

        playing = self.player.playbackState() == QMediaPlayer.PlaybackState.PlayingState
        # "Efetivo" = vídeo rodando E olhos na tela (o período de tolerância não conta).
        effective = playing and self.monitor.state is State.WATCHING
        punished = self.monitor.is_punished or self.escape_paused
        self.stats.tick(dt, effective=effective, punished=punished)
        if effective:
            self.video_effective += dt

        # aviso amarelo durante a tolerância
        if self.monitor.state is State.GRACE and not self.escape_paused:
            left = max(0.0, C.LOOK_AWAY_TOLERANCE_S * (1 - self.monitor.grace_progress(now)))
            self.grace.setText(f"⚠ DESVIO DETECTADO — punição em {left:.1f}s")
            self.grace.adjustSize()
            self.grace.move((self.width() - self.grace.width()) // 2, self.surface.height() - 120)
            self.grace.raise_()
            self.grace.show()
        else:
            self.grace.hide()

        self._update_hud()
        self._apply_playback()  # garante que nada (nem um dialog) deixou o player no estado errado

    def _update_hud(self):
        s = self.stats
        dur = self.video_duration
        frac = min(1.0, self.video_effective / dur) if dur > 0 else 0.0
        self.progress.setValue(int(frac * 1000))

        sample = self._last_sample
        if self.monitor.is_punished or self.escape_paused:
            self.lbl_eye.setText("✖ CASTIGO")
            self.lbl_eye.setStyleSheet(f"color:{C.RED};")
        elif sample and sample.looking:
            self.lbl_eye.setText("◉ OLHANDO")
            self.lbl_eye.setStyleSheet(f"color:{C.GREEN};")
        else:
            self.lbl_eye.setText("◌ DESVIANDO")
            self.lbl_eye.setStyleSheet("color:#ffc800;")

        reason = sample.reason if sample else "aguardando seus olhos..."
        ep = f"Episódio {self.index + 1}/{len(self.playlist)} · " if len(self.playlist) > 1 else ""
        self.lbl_info.setText(
            f"{ep}Efetivo <span style='color:{C.RED}'>{fmt_time(self.video_effective)}</span>"
            f" / {fmt_time(dur)} · Total na cadeira {fmt_time(s.total_time)}"
            f" · Desvios <span style='color:{C.RED}'>{s.look_away_count}</span>"
            f" · Piscadas <span style='color:{C.RED}'>{s.blink_count}</span>"
            + (f" (⏪ −{fmt_time(s.blink_rewound_s)})" if self.opts.blink_rewind else "")
            + f" · Punição {fmt_time(s.punishment_time)}"
            f" · <i style='color:#a08a80'>veredito: {reason}</i>"
        )
        self.lbl_volume.setText(f"VOLUME {self.volume * 100:.0f}%")

    # ---------------------------------------------------------------- fim --
    def _shutdown(self):
        """Para câmera e player (idempotente). Sem isso o Qt pode travar ao sair."""
        self._ticker.stop()
        self.player.stop()
        self.player.setSource(QUrl())
        self.tracker.stop()

    def _finish(self):
        if self.phase == _Phase.FINISHED:
            return
        self.phase = _Phase.FINISHED
        self.allow_close = True
        self._shutdown()
        QApplication.instance().removeEventFilter(self)
        self.punish.dismiss()
        self.calib.hide()
        self.hide()  # sai da frente (é "sempre no topo") antes do certificado aparecer
        self.finished.emit(self.stats)
        self.close()
