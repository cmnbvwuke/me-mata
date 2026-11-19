"""Testes das funções puras do rastreamento ocular (sem câmera)."""

import sys
from pathlib import Path
from types import SimpleNamespace as NS

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from rv.gaze import GazeMetrics, baseline_from, classify, extract_metrics, smooth  # noqa: E402


def _rot(axis, deg):
    t = np.radians(deg)
    c, s = np.cos(t), np.sin(t)
    m = np.eye(4)
    m[:3, :3] = {"y": [[c, 0, s], [0, 1, 0], [-s, 0, c]], "x": [[1, 0, 0], [0, c, -s], [0, s, c]]}[axis]
    return m


def _result(matrix=None, iris_shift=0.0, blink=0.0):
    pts = [NS(x=0.5, y=0.5, z=0.0) for _ in range(478)]
    pts[33], pts[133] = NS(x=0.30, y=0.4, z=0), NS(x=0.40, y=0.4, z=0)
    pts[362], pts[263] = NS(x=0.60, y=0.4, z=0), NS(x=0.70, y=0.4, z=0)
    pts[468] = NS(x=0.35 + iris_shift, y=0.4, z=0)
    pts[473] = NS(x=0.65 + iris_shift, y=0.4, z=0)
    bs = [NS(category_name="eyeBlinkLeft", score=blink), NS(category_name="eyeBlinkRight", score=blink)]
    return NS(face_landmarks=[pts], facial_transformation_matrixes=[matrix if matrix is not None else np.eye(4)],
              face_blendshapes=[bs])


def test_frontal_is_looking():
    base = extract_metrics(_result())
    assert abs(base.iris_h - 0.5) < 1e-9
    assert classify(base, base) == (True, "olhando (bom menino)")


def test_head_turn_and_tilt_detected():
    base = extract_metrics(_result())
    for axis, deg in [("y", 30), ("y", -30), ("x", 25)]:
        m = extract_metrics(_result(_rot(axis, deg)))
        assert not classify(m, base)[0]
    assert classify(extract_metrics(_result(_rot("y", 10))), base)[0]


def test_iris_side_glance_and_closed_eyes():
    base = extract_metrics(_result())
    assert not classify(extract_metrics(_result(iris_shift=0.025)), base)[0]   # 25% do olho
    assert classify(extract_metrics(_result(iris_shift=0.005)), base)[0]
    assert classify(extract_metrics(_result(blink=0.9)), base)[1].startswith("olhos fechados")


def test_no_face_and_helpers():
    assert extract_metrics(NS(face_landmarks=[], facial_transformation_matrixes=[], face_blendshapes=[])) is None
    assert classify(None, GazeMetrics()) == (False, "rosto desaparecido")
    b = baseline_from([GazeMetrics(yaw=v) for v in (1, 2, 100)])
    assert b.yaw == 2
    s = smooth(GazeMetrics(yaw=179), GazeMetrics(yaw=-179), 0.5)  # atravessa ±180 sem pular
    assert abs(abs(s.yaw) - 180) < 1.5
