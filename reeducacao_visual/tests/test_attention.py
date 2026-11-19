"""Testes da máquina de estados da atenção (rode com: python -m pytest)."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from rv.attention import AttentionMonitor, Event, State  # noqa: E402
from rv.stats import SessionStats, fmt_time  # noqa: E402


def feed(mon, looking, start, end, step=0.1):
    events = []
    t = start
    while t <= end + 1e-9:
        ev = mon.update(looking, t)
        if ev:
            events.append((round(t, 2), ev))
        t += step
    return events


def test_short_glance_away_is_forgiven():
    mon = AttentionMonitor(1.5, 2.0)
    assert feed(mon, False, 0.0, 1.4) == []
    assert mon.state is State.GRACE
    mon.update(True, 1.45)
    assert mon.state is State.WATCHING


def test_violation_after_tolerance():
    mon = AttentionMonitor(1.5, 2.0)
    events = feed(mon, False, 0.0, 2.0)
    assert [e for _, e in events] == [Event.VIOLATION]
    assert events[0][0] >= 1.5
    assert mon.is_punished


def test_resume_needs_two_consecutive_seconds():
    mon = AttentionMonitor(1.5, 2.0)
    feed(mon, False, 0.0, 2.0)
    # olha 1.5s, desvia (volta ao castigo, sem novo evento)
    assert feed(mon, True, 2.1, 3.6) == []
    assert mon.state is State.RECOVERING
    assert mon.update(False, 3.7) is None
    assert mon.state is State.PUNISHED
    # agora olha 2s seguidos
    events = feed(mon, True, 3.8, 6.0)
    assert [e for _, e in events] == [Event.RESUME]
    assert not mon.is_punished


def test_stats_and_verdict():
    s = SessionStats()
    s.tick(10, effective=True, punished=False)
    s.tick(5, effective=False, punished=True)
    s.tick(3, effective=True, punished=False)
    assert s.total_time == 18 and s.effective_time == 13
    assert s.punishment_time == 5 and s.longest_streak == 10
    assert s.verdict()[0] in {"S+", "A", "B", "C", "F"}
    assert fmt_time(3725) == "1:02:05" and fmt_time(65) == "01:05"
