# Material recebido

Arquivos enviados para o jogo. Os que já foram integrados ficam dentro do
projeto (`operation-black-tide/assets/`); aqui ficam só os ainda pendentes.

| Arquivo | Origem | Situação |
|---|---|---|
| General Salcedo (Tripo AI → rig e animações Meshy AI, 44 ossos) | enviado pelo usuário | **Integrado** em `operation-black-tide/assets/characters/general_salcedo.fbx`. Animações usadas: ajoelhado com as mãos na cabeça (escondido) e andando algemado (seguindo o jogador). Também contém Walking/Running (não usadas). |
| Soldado raso (Mixamo: Shoot Rifle, Rifle Walk, Dying, Turn Left 45, Turning Right 45) | enviado pelo usuário | **Integrado** em `operation-black-tide/assets/characters/soldier.fbx` (malha + caminhada) e `soldier_anims.res` (todas as animações, processadas para ficarem no lugar). Usado por todos os inimigos (elite e milícia com tom diferente). |
| Soldado de elite (Blender FBX, 50 mil triângulos, 4 texturas PBR) | enviado pelo usuário | **Integrado** em `operation-black-tide/assets/characters/elite*` (5 animações Mixamo + texturas PBR). Histórico: o Mixamo recusou o FBX original (escala ×100 em centímetros e 28 MB de texturas 4K). Convertido para `elite/elite_soldier_mixamo.zip` (OBJ de 1,80 m + cor 2K) para o rig. Texturas originais (cor, normal, rugosidade, metal; 2K) guardadas em `elite/` para reaplicar no modelo animado. |
| Miliciano de bandana vermelha e óculos escuros (Tripo AI → Blender 4.2 FBX, 50 mil triângulos, 4 texturas PBR 4K, sem esqueleto, pose em T) | enviado pelo usuário | **Aguardando rig no Mixamo.** FBX original com o mesmo problema do elite (malha de ~1 cm com escala ×100 no nó, 26 MB de texturas 4K). Convertido para `miliciano/miliciano_mixamo.zip` (OBJ de 1,80 m, pés em y=0, frente +Z, cor 2K JPG). Texturas originais (cor, normal, rugosidade, metal; 2K PNG) guardadas em `miliciano/` para reaplicar no modelo animado. |
