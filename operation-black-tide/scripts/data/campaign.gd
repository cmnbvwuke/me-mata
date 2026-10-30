class_name Campaign
extends RefCounted
## Dados da campanha "Operation Black Tide".
## Para adicionar uma missão jogável basta preencher o campo "scene".

const SETTING := "República de Valderrama — um país caribenho governado há mais de uma década pelo " \
	+ "General Rodrigo Salcedo, acusado de transformar a nação em um hub do narcotráfico e de " \
	+ "reprimir violentamente a oposição. Você integra a Força-Tarefa TRIDENT, uma unidade " \
	+ "multinacional de operações especiais encarregada de capturar o ditador com vida."

const PHASES := [
	{
		"id": "phase_1",
		"title": "FASE 1 — SOMBRA NO CARIBE",
		"missions": [
			{"id": "m1_recon", "title": "Olhos no Horizonte", "scene": "res://scenes/levels/missions/m1_recon.tscn",
				"brief": "Reconhecimento e interdição marítima ao entardecer. Infiltre-se pela costa, " \
				+ "marque com laser as lanchas do cartel na baía para a Marinha, derrube o repetidor " \
				+ "de rádio e extraia pela enseada.\n\nFOCO: furtividade e vegetação."},
			{"id": "m1_boarding", "title": "Maré Baixa", "scene": "res://scenes/levels/missions/m1_boarding.tscn",
				"brief": "Abordagem (VBSS) noturna ao cargueiro \"Estrella del Sur\". Limpe o convés " \
				+ "entre os contêineres, tome a ponte de comando, corte as máquinas e segure a proa " \
				+ "até a lancha da Marinha.\n\nFOCO: combate a curta distância."},
			{"id": "m1_intel", "title": "Pacote Silencioso", "scene": "res://scenes/levels/missions/m1_intel.tscn",
				"brief": "Infiltração no porto de San Lázaro: colete manifestos, celulares e o HD do " \
				+ "capitão, fixe um rastreador GPS no cargueiro e exfiltre pela lancha.\n\n" \
				+ "FOCO: furtividade — sem alarme, sem reforços."},
		],
	},
	{
		"id": "phase_2",
		"title": "FASE 2 — BLOQUEIO E PRESSÃO",
		"missions": [
			{"id": "m2_blockade", "title": "Linha Vermelha", "scene": "res://scenes/levels/missions/m2_blockade.tscn",
				"brief": "Bloqueio naval de Puerto Cardón. Retome o posto de interdição no píer, segure-o " \
				+ "contra ondas vindas por terra e por mar, sabote as lanchas de fuga e limpe o porto.\n\n" \
				+ "FOCO: defesa de posição e apoio aéreo."},
			{"id": "m2_sabotage", "title": "Céu Cego", "scene": "res://scenes/levels/missions/m2_sabotage.tscn",
				"brief": "Sabotagem noturna em Punta Herrera. Exploda os transformadores da subestação " \
				+ "(a base fica às escuras), desligue o radar na sala de controle e fuja.\n\n" \
				+ "FOCO: sabotagem e visão noturna."},
			{"id": "m2_defector", "title": "Voz de Dentro", "scene": "res://scenes/levels/missions/m2_defector.tscn",
				"brief": "Extraia o Coronel Ibarra, desertor que conhece a rotina do General, de um " \
				+ "esconderijo em San Isidro e escolte-o até o carro sob emboscada.\n\n" \
				+ "REGRA: Ibarra não pode morrer."},
		],
	},
	{
		"id": "phase_3",
		"title": "FASE 3 — ABSOLUTE RESOLVE",
		"missions": [
			{"id": "absolute_resolve", "title": "Absolute Resolve",
				"scene": "res://scenes/levels/absolute_resolve.tscn",
				"brief": "Operação noturna de captura. Infiltração com helicópteros voando baixo " \
				+ "até a Hacienda El Mirador, complexo residencial fortificado do General Salcedo.\n\n" \
				+ "OBJETIVOS\n" \
				+ "• Infiltrar o complexo (evite os holofotes das torres)\n" \
				+ "• Eliminar a resistência no pátio\n" \
				+ "• Capturar o HVT VIVO na sala segura\n" \
				+ "• Escoltar o HVT até o helicóptero de extração\n\n" \
				+ "APOIO: Viper 2-1 (helicóptero de ataque) disponível após a infiltração.\n" \
				+ "REGRAS DE ENGAJAMENTO: O HVT não pode morrer."},
		],
	},
	{
		"id": "phase_4",
		"title": "FASE 4 — CONSEQUÊNCIAS",
		"missions": [
			{"id": "m4_remnants", "title": "Brasas", "scene": "res://scenes/levels/missions/m4_remnants.tscn",
				"brief": "O Cartel del Mar tenta ocupar o vácuo de poder. Destrua os laboratórios de " \
				+ "Las Cenizas, elimine o chefe \"El Tiburón\" e segure a zona de pouso.\n\n" \
				+ "FOCO: assalto e defesa."},
		],
	},
]


static func get_mission(mission_id: String) -> Dictionary:
	for phase in PHASES:
		for mission in phase["missions"]:
			if mission["id"] == mission_id:
				return mission
	return {}
