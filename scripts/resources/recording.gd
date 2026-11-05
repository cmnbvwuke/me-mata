class_name Recording extends Resource
## Um áudio do Arquivo Wellington. Transcrições são sempre fictícias.

@export var week := 1
@export var day := 1
@export_range(1, 5) var severity := 1     ## constrangimento, nunca crime
@export var transcript_key := ""          ## chave do catálogo cômico
@export var mentions: Array[StringName] = []
