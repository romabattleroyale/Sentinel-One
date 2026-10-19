extends Control

const BG := Color("#07111e")
const PANEL := Color("#122338")
const PANEL_2 := Color("#182d43")
const GOLD := Color("#e7bd4b")
const WHITE := Color("#f5f7fb")
const MUTED := Color("#a8b7c8")
const GREEN := Color("#53d6a2")

var club_name := "ASD Borgo Nuovo"
var town_name := "Borgo Nuovo"
var season := 1
var budget := 12000
var fans := 85
var points := 0
var played := 0
var wins := 0
var draws := 0
var losses := 0
var selected_formation := "4-4-2"
var selected_tactic := "Equilibrato"
var roster: Array[Dictionary] = []
var root_box: VBoxContainer

func _ready() -> void:
	show_start()

func _wipe() -> void:
	for child in get_children():
		child.queue_free()
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	root_box = VBoxContainer.new()
	root_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_box.add_theme_constant_override("separation", 16)
	scroll.add_child(root_box)

func _panel(parent: Control, color: Color = PANEL) -> VBoxContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("#2a4057")
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	card.add_theme_stylebox_override("panel", style)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	return box

func _label(parent: Control, value: String, size: int = 16, color: Color = WHITE) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _button(parent: Control, value: String, action: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = value
	b.custom_minimum_size = Vector2(0, 48)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", Color("#111827") if primary else WHITE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = GOLD if primary else PANEL_2
	normal.border_color = GOLD if primary else Color("#344b62")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(10)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	b.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color("#f3d77e") if primary else Color("#23405b")
	b.add_theme_stylebox_override("hover", hover)
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func _header(kicker: String, title: String, subtitle: String) -> void:
	var box := _panel(root_box, Color("#0e2033"))
	_label(box, kicker.to_upper(), 12, GOLD)
	_label(box, title, 30, WHITE)
	_label(box, subtitle, 14, MUTED)

func show_start() -> void:
	_wipe()
	_header("GESTIONALE CALCISTICO · ITALIA", "DAL PAESE ALLA SERIE A", "Fonda una squadra, conquista il paese e costruisci una storia che nessuno dimenticherà.")
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_box.add_child(columns)
	var left := _panel(columns)
	left.size_flags_stretch_ratio = 1.25
	_label(left, "01  ·  CREA IL TUO CLUB", 18, GOLD)
	_label(left, "Il tuo paese. I tuoi colori. La tua storia.", 20)
	_label(left, "Nome squadra", 13, MUTED)
	var name_edit := LineEdit.new()
	name_edit.text = club_name
	name_edit.placeholder_text = "Es. ASD Borgo Nuovo"
	name_edit.custom_minimum_size.y = 44
	left.add_child(name_edit)
	_label(left, "Nome del paese", 13, MUTED)
	var town_edit := LineEdit.new()
	town_edit.text = town_name
	town_edit.custom_minimum_size.y = 44
	left.add_child(town_edit)
	_button(left, "FONDA IL CLUB", func():
		club_name = name_edit.text.strip_edges()
		town_name = town_edit.text.strip_edges()
		if club_name.is_empty(): club_name = "ASD Nuovo Club"
		if town_name.is_empty(): town_name = "Il tuo paese"
		_create_roster()
		show_dashboard()
	, true)
	var continue_button := _button(left, "CONTINUA CARRIERA", load_game, false)
	continue_button.disabled = not FileAccess.file_exists("user://career_save.json")
	var right := _panel(columns, Color("#102a2c"))
	right.size_flags_stretch_ratio = 0.75
	_label(right, "LA TUA CARRIERA PARTE DA QUI", 15, GREEN)
	_label(right, "Dalla polvere dei campi locali alle notti di Serie A.", 23)
	_label(right, "• Rosa iniziale generata\n• Budget di partenza: € 12.000\n• Campionato locale da 8 squadre\n• Tattiche, mercato e gestione della rosa\n• Progressione di carriera in sviluppo", 15, MUTED)
	_label(right, "PROTOTIPO GIOCABILE · BLOCCO BASE", 11, GOLD)

func _create_roster() -> void:
	if not roster.is_empty(): return
	var names := ["Luca Bianchi", "Marco Rossi", "Andrea Conti", "Matteo Galli", "Simone Moretti", "Davide Ricci", "Paolo Costa", "Federico Romano", "Nicola Greco", "Stefano Bruno", "Alessio Marino", "Giorgio De Luca", "Fabio Rinaldi", "Michele Serra", "Enrico Villa", "Daniele Ferri"]
	var roles := ["POR", "TD", "DC", "DC", "TS", "CDC", "CC", "CC", "AD", "ATT", "AS"]
	for i in range(names.size()):
		roster.append({"name": names[i], "role": roles[i] if i < roles.size() else "R", "ovr": randi_range(42, 65), "morale": randi_range(58, 82), "wage": randi_range(120, 280)})

func show_dashboard() -> void:
	_wipe()
	_header("STAGIONE %d · CATEGORIA LOCALE" % season, club_name, "%s  ·  Il consiglio del paese è pronto a valutare la tua prima stagione." % town_name)
	var metrics := GridContainer.new()
	metrics.columns = 4
	metrics.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	metrics.add_theme_constant_override("h_separation", 12)
	metrics.add_theme_constant_override("v_separation", 12)
	root_box.add_child(metrics)
	_metric(metrics, "BUDGET", "€ %s" % str(budget), "Disponibilità", GOLD)
	_metric(metrics, "TIFOSI", str(fans), "Supporto locale", Color("#8dc7ff"))
	_metric(metrics, "PARTITE", "%d / 14" % played, "Stagione", GREEN)
	_metric(metrics, "PUNTI", str(points), "%dV · %dN · %dP" % [wins, draws, losses], Color("#c4b5fd"))
	var match := _panel(root_box, Color("#10273b"))
	_label(match, "PROSSIMA PARTITA", 12, GOLD)
	_label(match, "%s   VS   RIVALI DEL BORGO" % club_name.to_upper(), 23)
	_label(match, "Giornata %d · Campo comunale · Obiettivo: conquistare il paese." % (played + 1), 14, MUTED)
	_button(match, "▶  GIOCA LA PROSSIMA PARTITA", play_match, true)
	_label(root_box, "CENTRO DI GESTIONE", 13, GOLD)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	root_box.add_child(grid)
	_tile(grid, "ROSA", "Giocatori, ruoli e morale", show_roster)
	_tile(grid, "CLASSIFICA", "Punti e obiettivi", show_standings)
	_tile(grid, "TATTICHE", "Scegli l'approccio", show_tactics)
	_tile(grid, "MERCATO", "Svincolati in arrivo", show_market)
	_tile(grid, "DIRIGENZA", "Fiducia e obiettivi", show_board)
	_tile(grid, "SALVATAGGIO", "Salva la carriera", save_game)
	_button(root_box, "TORNA AL MENU CLUB", show_start)

func _metric(parent: Control, heading: String, value: String, sub: String, accent: Color) -> void:
	var box := _panel(parent)
	_label(box, heading, 12, accent)
	_label(box, value, 24, WHITE)
	_label(box, sub, 12, MUTED)

func _tile(parent: Control, heading: String, sub: String, action: Callable) -> void:
	var box := _panel(parent, PANEL_2)
	_label(box, heading, 18, GOLD)
	_label(box, sub, 13, MUTED)
	_button(box, "APRI", action)

func _subpage(title: String, subtitle: String) -> void:
	_wipe()
	_header("CENTRO CLUB", title, subtitle)
	_button(root_box, "←  TORNA AL CLUB", show_dashboard)

func show_roster() -> void:
	_subpage("LA ROSA", "Ogni giocatore ha un ruolo, una valutazione, un morale e un ingaggio.")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	root_box.add_child(grid)
	for p in roster:
		var box := _panel(grid)
		_label(box, "%s  ·  %s" % [p["name"], p["role"]], 17)
		_label(box, "VAL %d     MORALE %d/100" % [p["ovr"], p["morale"]], 13, GREEN if p["morale"] >= 65 else GOLD)
		_label(box, "Ingaggio: € %d / partita" % p["wage"], 12, MUTED)

func show_standings() -> void:
	_subpage("CLASSIFICA", "Campionato locale · aggiornato dopo ogni partita.")
	var box := _panel(root_box)
	var table := GridContainer.new()
	table.columns = 4
	box.add_child(table)
	for h in ["POS", "SQUADRA", "PT", "GIOCATE"]:
		_label(table, h, 12, GOLD)
	for row in [["1", club_name, str(points), str(played)], ["2", "ASD Valle Verde", "0", "0"], ["3", "Real Fontanile", "0", "0"], ["4", "Polisportiva Aurora", "0", "0"], ["5", "Atletico Collina", "0", "0"], ["6", "FC San Michele", "0", "0"], ["7", "Virtus Campagna", "0", "0"], ["8", "US Vecchio Ponte", "0", "0"]]:
		for cell in row: _label(table, cell, 14)

func show_tactics() -> void:
	_subpage("TATTICHE", "Scegli il piano gara prima della prossima partita.")
	var box := _panel(root_box)
	_label(box, "MODULO", 13, GOLD)
	_label(box, "Modulo attuale: " + selected_formation, 15, GREEN)
	for formation in ["4-4-2", "4-3-3", "3-5-2", "4-2-3-1"]:
		_button(box, formation + ("  ✓" if formation == selected_formation else ""), _select_formation.bind(formation))
	_label(box, "APPROCCIO", 13, GOLD)
	_label(box, "Approccio attuale: " + selected_tactic, 15, GREEN)
	for tactic in ["Difensivo", "Equilibrato", "Offensivo"]:
		_button(box, tactic + ("  ✓" if tactic == selected_tactic else ""), _select_tactic.bind(tactic))

func _select_formation(value: String) -> void:
	selected_formation = value
	show_tactics()

func _select_tactic(value: String) -> void:
	selected_tactic = value
	show_tactics()

func show_market() -> void:
	_subpage("MERCATO", "Svincolati disponibili · gli acquisti consumano il budget del club.")
	for i in range(3):
		var cost := 900 + i * 350
		var names := ["Pietro Neri", "Tommaso Sala", "Riccardo Riva"]
		var roles := ["POR", "CC", "ATT"]
		var labels := ["Portiere esperto", "Centrocampista instancabile", "Attaccante del territorio"]
		var box := _panel(root_box)
		_label(box, labels[i], 18)
		_label(box, "Valutazione %d · Premio € %d" % [48 + i * 4, cost], 13, MUTED)
		_button(box, "INGAGGIA", _sign_player.bind(i))

func _sign_player(index: int) -> void:
	var names := ["Pietro Neri", "Tommaso Sala", "Riccardo Riva"]
	var roles := ["POR", "CC", "ATT"]
	var cost := 900 + index * 350
	if budget < cost:
		_notice("Budget insufficiente.")
		return
	for player in roster:
		if str(player.get("name", "")) == names[index]:
			_notice("Questo giocatore è già nella tua rosa.")
			return
	budget -= cost
	roster.append({"name": names[index], "role": roles[index], "ovr": 48 + index * 4, "morale": 70, "wage": 160 + index * 30})
	show_market()

func show_board() -> void:
	_subpage("DIRIGENZA", "La società vuole vedere progressi: risultati, sostenibilità e identità.")
	var box := _panel(root_box)
	_label(box, "OBIETTIVO STAGIONALE", 13, GOLD)
	_label(box, "Chiudere nella metà alta della classifica.", 20)
	_label(box, "Fiducia della dirigenza: %d/100" % clampi(65 + points - losses * 3, 0, 100), 15, GREEN)
	_label(box, "La comunità sostiene il club quando giochi con continuità e mantieni i conti in ordine.", 14, MUTED)

func play_match() -> void:
	if played >= 14:
		season += 1
		played = 0
		points = 0
		wins = 0
		draws = 0
		losses = 0
	var strength := 0
	for p in roster: strength += int(p["ovr"])
	var edge := float(strength) / maxf(1.0, float(roster.size())) / 10.0
	var attack_bonus := 0.0
	var defense_bonus := 0.0
	match selected_tactic:
		"Difensivo":
			attack_bonus = -0.035
			defense_bonus = 0.075
		"Offensivo":
			attack_bonus = 0.085
			defense_bonus = -0.065
		match selected_formation:
			"4-3-3": attack_bonus += 0.025
			"3-5-2":
				attack_bonus += 0.015
				defense_bonus -= 0.01
			"4-2-3-1":
				attack_bonus += 0.015
				defense_bonus += 0.015
	var roll := randf() + (edge - 5.2) * 0.07
	var gf := 0
	var ga := 0
	for i in range(5):
		if randf() < clampf(0.18 + roll * 0.12 + attack_bonus, 0.08, 0.48): gf += 1
		if randf() < clampf(0.25 - (edge - 5.2) * 0.025 - defense_bonus, 0.08, 0.42): ga += 1
	played += 1
	budget -= roster.size() * 18
	if gf > ga:
		wins += 1
		points += 3
		fans += 12
		budget += 450
	elif gf == ga:
		draws += 1
		points += 1
		fans += 3
		budget += 180
	else:
		losses += 1
		fans = maxi(20, fans - 5)
		budget -= 100
	for p in roster:
		p["morale"] = clampi(int(p["morale"]) + (2 if gf >= ga else -3), 25, 98)
	_show_result(gf, ga)

func _show_result(gf: int, ga: int) -> void:
	_subpage("FISCHIO FINALE  ·  %d–%d" % [gf, ga], "La partita è finita. La storia del club continua.")
	var box := _panel(root_box, Color("#10273b"))
	_label(box, club_name, 24)
	_label(box, "%d     —     %d" % [gf, ga], 38, GOLD)
	_label(box, "PUNTI %d  ·  BILANCIO € %s  ·  TIFOSI %s" % [points, str(budget), str(fans)], 14, MUTED)
	_button(box, "TORNA AL CLUB", show_dashboard, true)

func load_game() -> void:
	var file := FileAccess.open("user://career_save.json", FileAccess.READ)
	if file == null:
		_notice("Nessun salvataggio disponibile.")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		_notice("Il salvataggio non è valido.")
		return
	var data: Dictionary = parsed
	club_name = str(data.get("club_name", "ASD Nuovo Club"))
	town_name = str(data.get("town_name", "Il tuo paese"))
	season = int(data.get("season", 1))
	budget = int(data.get("budget", 12000))
	fans = int(data.get("fans", 85))
	points = int(data.get("points", 0))
	played = int(data.get("played", 0))
	wins = int(data.get("wins", 0))
	draws = int(data.get("draws", 0))
	losses = int(data.get("losses", 0))
	selected_formation = str(data.get("selected_formation", "4-4-2"))
	selected_tactic = str(data.get("selected_tactic", "Equilibrato"))
	roster.clear()
	var saved_roster: Variant = data.get("roster", [])
	if saved_roster is Array:
		for player in saved_roster:
			if player is Dictionary:
				roster.append(player)
	if roster.is_empty():
		_create_roster()
	show_dashboard()

func save_game() -> void:
	var data := {"club_name": club_name, "town_name": town_name, "season": season, "budget": budget, "fans": fans, "points": points, "played": played, "wins": wins, "draws": draws, "losses": losses, "selected_formation": selected_formation, "selected_tactic": selected_tactic, "roster": roster}
	var file := FileAccess.open("user://career_save.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
	_notice("Carriera salvata sul dispositivo.")

func _notice(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()
