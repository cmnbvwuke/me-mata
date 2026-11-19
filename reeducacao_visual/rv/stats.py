"""
Estatísticas da sessão — o prontuário que vai parar no Certificado.
"""

from __future__ import annotations

from dataclasses import dataclass


def fmt_time(seconds: float) -> str:
    seconds = max(0, int(seconds))
    h, rem = divmod(seconds, 3600)
    m, s = divmod(rem, 60)
    return f"{h:d}:{m:02d}:{s:02d}" if h else f"{m:02d}:{s:02d}"


@dataclass
class SessionStats:
    total_time: float = 0.0          # tempo de relógio desde o início da sessão
    effective_time: float = 0.0      # só conta com olhos na tela e vídeo rodando
    punishment_time: float = 0.0     # tempo pausado por desvio de olhar/fuga
    look_away_count: int = 0         # desvios que viraram punição
    escape_key_attempts: int = 0     # ESC, Alt+F4, Ctrl+W, espaço...
    window_escapes: int = 0          # minimizar / trocar de janela
    give_ups: int = 0                # cliques no botão de desistência escondido
    max_volume: float = 0.0
    longest_streak: float = 0.0      # maior sequência contínua olhando
    blink_count: int = 0             # piscadas detectadas durante o vídeo
    blink_rewinds: int = 0           # vezes que o vídeo voltou por piscada
    blink_rewound_s: float = 0.0     # segundos de vídeo perdidos piscando
    blink_rewind_mode: bool = False
    _streak: float = 0.0
    completed: bool = False
    safeword_used: bool = False

    def tick(self, dt: float, *, effective: bool, punished: bool) -> None:
        self.total_time += dt
        if effective:
            self.effective_time += dt
            self._streak += dt
            self.longest_streak = max(self.longest_streak, self._streak)
        else:
            self._streak = 0.0
        if punished:
            self.punishment_time += dt

    @property
    def blinks_per_minute(self) -> float:
        return self.blink_count / (self.total_time / 60) if self.total_time > 1 else 0.0

    @property
    def commitment(self) -> float:
        """Taxa de comprometimento: tempo efetivo / tempo total."""
        return self.effective_time / self.total_time if self.total_time else 0.0

    def verdict(self) -> tuple[str, str]:
        """(nota, comentário) — a avaliação final, absolutamente científica."""
        if self.safeword_used:
            return ("D", "Usou a palavra de segurança. Fez certo. Mas a gente vai lembrar.")
        sins = self.look_away_count + self.window_escapes + self.give_ups * 2
        c = self.commitment
        if sins == 0 and c > 0.95:
            return ("S+", "Cidadão exemplar. Assustadoramente obediente. Procure ajuda.")
        if sins <= 2 and c > 0.85:
            return ("A", "Quase reeducado. Torajo aprova com ressalvas.")
        if sins <= 6 and c > 0.65:
            return ("B", "Mediano. Como seu gosto para vídeos.")
        if sins <= 12:
            return ("C", "Muitas fugas, pouca fibra moral.")
        return ("F", "Caso perdido. Recomenda-se nova sessão. E outra. E outra.")
