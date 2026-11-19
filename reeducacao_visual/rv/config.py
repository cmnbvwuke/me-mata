"""
Configurações e textos do Sistema de Reeducação Visual.

Tudo que é "ajustável" mora aqui: tempos, limites de volume, limiares do
rastreamento ocular e — o mais importante — as mensagens passivo-agressivas.

LEMBRETE: é humor. A palavra de segurança SEMPRE funciona.
"""

from pathlib import Path

# ---------------------------------------------------------------------------
# Caminhos
# ---------------------------------------------------------------------------
BASE_DIR = Path(__file__).resolve().parent.parent
MODEL_PATH = BASE_DIR / "models" / "face_landmarker.task"
MODEL_URL = (
    "https://storage.googleapis.com/mediapipe-models/face_landmarker/"
    "face_landmarker/float16/1/face_landmarker.task"
)

# ---------------------------------------------------------------------------
# Regras da "terapia"
# ---------------------------------------------------------------------------
LOOK_AWAY_TOLERANCE_S = 1.5   # quanto tempo pode desviar antes da punição
LOOK_BACK_REQUIRED_S = 2.0    # quanto tempo precisa olhar de volta para retomar
CALIBRATION_S = 3.0           # duração da calibração inicial

# Volume (0.0 a 1.0). O limite de segurança existe porque queremos
# irritar, não causar dano auditivo. Não remova o limite. Sério.
VOLUME_START = 0.35
VOLUME_STEP = 0.10
VOLUME_SAFETY_CAP = 0.80

# A saída REAL. Digite isso a qualquer momento durante a sessão.
SAFEWORD = "LARANJA"

# ---------------------------------------------------------------------------
# Limiares do rastreamento ocular (relativos à calibração)
# ---------------------------------------------------------------------------
MAX_YAW_DEG = 22.0         # rotação da cabeça para os lados
MAX_PITCH_DEG = 18.0       # cabeça para cima/baixo
MAX_IRIS_H_OFFSET = 0.13   # deslocamento horizontal da íris (0..1 do olho)
MAX_EYE_V_OFFSET = 0.40    # olhar para cima/baixo (blendshapes)
BLINK_CLOSED = 0.55        # acima disso, consideramos olho fechado
SMOOTHING = 0.35

# Piscadas (detector separado: fecha e abre rápido = piscada;
# fechado por muito tempo = cochilo, quem pune é a máquina de atenção)
BLINK_EVENT_CLOSE = 0.45     # nota de "olho fechado" que caracteriza a piscada
BLINK_HYSTERESIS = 0.15      # precisa cair até CLOSE - isto para contar como reaberto
BLINK_MAX_DURATION_S = 0.6   # mais que isso não é piscada
BLINK_REWIND_S = 10.0        # Modo Pálpebra Proibida: quanto o vídeo volta por piscada           # EMA: 0 = sem suavização, 1 = congelado
CAMERA_INDEX = 0
CAMERA_FPS = 30

# ---------------------------------------------------------------------------
# Visual
# ---------------------------------------------------------------------------
RED = "#e10600"
DARK_RED = "#5a0000"
BLACK = "#0a0a0a"
BONE = "#f2e8d5"
GREEN = "#2bd94a"
HEAVY_FONT = "Impact, 'Anton', 'Arial Black', 'Bebas Neue', sans-serif"

# ---------------------------------------------------------------------------
# Textos
# ---------------------------------------------------------------------------
TITLE = "Sistema de Reeducação Visual v1.0"
SUBTITLE = "Inspirado em Laranja Mecânica (versão light)"
DISCLAIMER = (
    "Este software é uma brincadeira. Se você está usando isso de verdade em "
    "alguém sem consentimento, você é o vilão da história."
)

LOOK_AWAY_MESSAGES = [
    "Olhos desviados. Falta de comprometimento detectada.",
    "Você acha que eu não estou vendo?",
    "Torajo está decepcionado com você.",
    "Seus olhos foram dar uma voltinha. Eles voltam ou eu vou buscar?",
    "O conteúdo está AQUI. Na tela. Onde você deveria estar olhando.",
    "Interessante essa parede, né? Mais interessante que a sua reeducação?",
    "Registrado no seu prontuário permanente.",
    "Isso vai doer mais em mim do que em você. Mentira.",
    "Sua mãe ficaria triste. Eu fico só irritado.",
    "Desvio ocular nº {n}. A ciência está anotando tudo.",
    "Webcam diz: você é fraco.",
    "Nem o Alex DeLarge desviava tanto.",
]

ESCAPE_KEY_MESSAGES = [
    "ESC? Isso aqui não é um menu de pausa, querido.",
    "Bela tentativa. Anotado.",
    "Atalhos de teclado foram confiscados para sua própria evolução.",
    "Esse botão está de férias. Permanentes.",
    "Alt+F4 é coisa de quem não tem compromisso.",
    "Ctrl+W? W de 'Wow, que covardia'.",
    "Acelerar? A reeducação tem o tempo dela.",
    "Pausar é para os fortes. Você não é forte.",
    "Clique, aperte, chore. O vídeo continua.",
]

WINDOW_ESCAPE_MESSAGE = "Covarde detectado. Voltando à terapia..."

GIVE_UP_MESSAGE = "Fraqueza detectada. Reiniciando o vídeo do zero."

RESUME_MESSAGES = [
    "Muito bem. Continue assim e talvez ganhe um biscoito.",
    "Bem-vindo de volta. Ninguém sentiu sua falta.",
    "Olhos na tela. Era tão difícil?",
    "Retomando a sessão. Tente não decepcionar de novo.",
]

VOICE_LINES_ON_START = [
    "Bem-vindo à sua reeducação. Fique confortável. Mas não muito.",
]

CALIBRATION_TEXT = (
    "CALIBRAÇÃO\n\nEncare o centro da tela.\nNão pisque. Sim, é sério."
)

BLINK_REWIND_MESSAGES = [
    "Piscou. Volta {s:.0f} segundos. Regras são regras.",
    "Pálpebra não autorizada detectada. Rebobinando.",
    "Você piscou. O Torajo viu. Volta tudo.",
    "Piscar é um privilégio. Você não tem privilégios.",
    "Mais uma piscada, mais {s:.0f} segundos de reeducação. Obrigado pela preferência.",
    "Seus olhos fecharam por 0,2 s e isso custou {s:.0f} s. Vale a pena?",
    "Rebobinando... porque você não aguenta 1 minuto sem piscar.",
]

NO_FACE_MESSAGE = "Rosto não encontrado. Você se escondeu embaixo da mesa?"
