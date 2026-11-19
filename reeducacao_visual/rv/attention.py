"""
Máquina de estados da atenção — o "juiz" da sessão.

Recebe a cada amostra se o usuário está olhando ou não, e decide quando
punir (pausar) e quando perdoar (retomar). Não sabe nada de Qt nem de
câmera, o que facilita testar.

Estados:
    WATCHING    olhando para a tela; vídeo rodando.
    GRACE       desviou o olhar há menos de LOOK_AWAY_TOLERANCE_S; ainda roda.
    PUNISHED    desviou demais; vídeo pausado, overlay vermelho.
    RECOVERING  voltou a olhar, mas ainda não completou LOOK_BACK_REQUIRED_S.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum, auto


class State(Enum):
    WATCHING = auto()
    GRACE = auto()
    PUNISHED = auto()
    RECOVERING = auto()


class Event(Enum):
    VIOLATION = auto()   # entrou em PUNISHED -> pausar e punir
    RESUME = auto()      # saiu de PUNISHED/RECOVERING -> retomar


@dataclass
class AttentionMonitor:
    away_tolerance: float = 1.5
    back_required: float = 2.0
    state: State = State.WATCHING
    _since: float | None = field(default=None, repr=False)

    def reset(self) -> None:
        self.state = State.WATCHING
        self._since = None

    @property
    def is_punished(self) -> bool:
        """True quando o vídeo deve ficar pausado por falta de atenção."""
        return self.state in (State.PUNISHED, State.RECOVERING)

    def recovery_progress(self, now: float) -> float:
        """0..1 de quanto falta para o perdão (para a barrinha do overlay)."""
        if self.state is not State.RECOVERING or self._since is None:
            return 0.0
        return min(1.0, (now - self._since) / self.back_required)

    def grace_progress(self, now: float) -> float:
        """0..1 de quanto falta para a punição (para o aviso amarelo)."""
        if self.state is not State.GRACE or self._since is None:
            return 0.0
        return min(1.0, (now - self._since) / self.away_tolerance)

    def update(self, looking: bool, now: float) -> Event | None:
        """Alimenta uma amostra. Retorna um evento quando há transição relevante."""
        s = self.state

        if s is State.WATCHING:
            if not looking:
                self.state, self._since = State.GRACE, now
            return None

        if s is State.GRACE:
            if looking:
                self.state, self._since = State.WATCHING, None
                return None
            if now - self._since >= self.away_tolerance:
                self.state, self._since = State.PUNISHED, now
                return Event.VIOLATION
            return None

        if s is State.PUNISHED:
            if looking:
                self.state, self._since = State.RECOVERING, now
            return None

        # RECOVERING
        if not looking:
            # Olhou, desistiu de olhar. Volta pro castigo, sem novo evento
            # (já está pausado; não é justo aumentar o volume duas vezes... ou é?).
            self.state, self._since = State.PUNISHED, now
            return None
        if now - self._since >= self.back_required:
            self.state, self._since = State.WATCHING, None
            return Event.RESUME
        return None
