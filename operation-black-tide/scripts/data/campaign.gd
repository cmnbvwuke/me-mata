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
			{"id": "m1_recon", "title": "Olhos no Horizonte", "scene": "",
				"brief": "Reconhecimento e interdição marítima. Monitorar rotas de lanchas rápidas " \
				+ "que partem do Porto de San Lázaro e marcar embarcações suspeitas."},
			{"id": "m1_boarding", "title": "Maré Baixa", "scene": "",
				"brief": "Abordagem (VBSS) de um cargueiro de bandeira falsa. Assumir a ponte de " \
				+ "comando e neutralizar a tripulação armada."},
			{"id": "m1_intel", "title": "Pacote Silencioso", "scene": "",
				"brief": "Coletar inteligência no cargueiro: manifestos, telefones e o HD do capitão."},
		],
	},
	{
		"id": "phase_2",
		"title": "FASE 2 — BLOQUEIO E PRESSÃO",
		"missions": [
			{"id": "m2_blockade", "title": "Linha Vermelha", "scene": "",
				"brief": "Bloqueio naval. Escoltar o grupo de interdição e conter a fuga de embarcações."},
			{"id": "m2_sabotage", "title": "Céu Cego", "scene": "",
				"brief": "Sabotar o radar costeiro de Punta Herrera e a subestação que o alimenta."},
			{"id": "m2_defector", "title": "Voz de Dentro", "scene": "",
				"brief": "Extrair o Coronel Ibarra, desertor que conhece a rotina do General."},
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
			{"id": "m4_remnants", "title": "Brasas", "scene": "",
				"brief": "Combate a remanescentes da Guarda Negra e células do Cartel del Mar " \
				+ "que tentam preencher o vácuo de poder."},
		],
	},
]


static func get_mission(mission_id: String) -> Dictionary:
	for phase in PHASES:
		for mission in phase["missions"]:
			if mission["id"] == mission_id:
				return mission
	return {}
