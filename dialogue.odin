package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

// ── Dialogue System ───────────────────────────────────────────────────────

MAX_DIALOGUE_LINES :: 32
MAX_LINE_LEN       :: 200

DialogueLine :: struct {
	speaker: string,
	text:    string,
}

Dialogue :: struct {
	lines:   [MAX_DIALOGUE_LINES]DialogueLine,
	count:   int,
	current: int,
	// Who to return to after dialogue ends
	return_state: GameState,
	// Optional callback index (0 = none, 2 = start Veyrath battle, 3 = start the current level's spirit battle)
	callback: int,
}

g_dlg: Dialogue

// Speaker portrait colours
speaker_color :: proc(name: string) -> rl.Color {
	switch name {
	case "Oracle":  return rl.Color{200, 160, 255, 255}
	case "Taz":     return rl.Color{120, 220, 180, 255}
	case "Veyrath": return rl.Color{255, 80, 60, 255}
	case "???":     return rl.Color{180, 180, 100, 255}
	}
	return COL_TEXT
}

set_dialogue :: proc(lines: []DialogueLine, return_to: GameState, cb: int = 0) {
	g_dlg = {}
	for i in 0 ..< min(len(lines), MAX_DIALOGUE_LINES) {
		g_dlg.lines[i] = lines[i]
	}
	g_dlg.count = min(len(lines), MAX_DIALOGUE_LINES)
	g_dlg.current = 0
	g_dlg.return_state = return_to
	g_dlg.callback = cb
}

start_intro_dialogue :: proc() {
	lines := []DialogueLine{
		{speaker = "Oracle", text = "Taz... you've finally awakened. I've been waiting a long time."},
		{speaker = "Taz",    text = "Where... am I? Who are you?"},
		{speaker = "Oracle", text = "I am the Oracle. This is the Spirit Realm — a world between worlds."},
		{speaker = "Oracle", text = "You are a Summoner, Taz. One of the few who can bind spirits to their soul."},
		{speaker = "Taz",    text = "Spirits? Bind them? I don't understand any of this."},
		{speaker = "Oracle", text = "Ten ancient spirits shattered the old world. They must be collected and brought to peace."},
		{speaker = "Oracle", text = "The tenth spirit — Veyrath, the Dragon — corrupted the others. He is the source of the chaos."},
		{speaker = "Taz",    text = "And I'm supposed to stop him? Just me?"},
		{speaker = "Oracle", text = "Not alone. You'll grow stronger with every spirit you bind. Their power becomes yours."},
		{speaker = "Oracle", text = "Come find me when you have spirits to fuse. I will help you combine their souls into something greater."},
		{speaker = "Oracle", text = "Now then — let me teach you the basics of combat, young summoner."},
		{speaker = "Oracle", text = "MOVEMENT: Use arrow keys or WASD to walk the world. Stepping into colored terrain triggers spirit encounters."},
		{speaker = "Oracle", text = "BATTLE: You have one move to start — Soul Punch. Press FIGHT to use it."},
		{speaker = "Oracle", text = "BINDING: When a spirit's HP drops below 25%, a BIND button appears. Use it to add them to your roster!"},
		{speaker = "Oracle", text = "FUSION: Bring two bound spirits to me and I'll fuse them into a stronger form. My shrine is the yellow tile."},
		{speaker = "Oracle", text = "Level up and you'll learn new moves. Collect all nine spirits... then face Veyrath."},
		{speaker = "Taz",    text = "Understood. I'll do whatever it takes."},
		{speaker = "Oracle", text = "Good luck, Taz. The spirits are waiting."},
	}
	set_dialogue(lines, .Hub, 0)
}

start_fusion_tutorial_dialogue :: proc() {
	lines := []DialogueLine{
		{speaker = "Oracle", text = "Welcome back, Taz. I sense bound spirits in your soul."},
		{speaker = "Oracle", text = "Fusion combines two spirits into one more powerful being."},
		{speaker = "Oracle", text = "The result inherits the stronger stats of both parents, and learns a new technique."},
		{speaker = "Oracle", text = "Choose wisely — the fused spirit replaces the two you offer."},
	}
	set_dialogue(lines, .FusionMenu, 0)
}

start_veyrath_dialogue :: proc() {
	lines := []DialogueLine{
		{speaker = "???",     text = "So... the little summoner has come this far."},
		{speaker = "Taz",     text = "Veyrath. I've collected the nine spirits. This ends today."},
		{speaker = "Veyrath", text = "Collected? You STOLE them from me. They were mine to corrupt, mine to devour!"},
		{speaker = "Oracle",  text = "Taz, be careful — Veyrath has absorbed the fragments of the shattered world."},
		{speaker = "Taz",     text = "Then I'll take them back. Every. Single. One."},
		{speaker = "Veyrath", text = "FOOL. You'll burn with the rest of this realm!"},
	}
	set_dialogue(lines, .Battle, 2)
}

start_bind_dialogue :: proc(spirit_name: string) {
	lines := []DialogueLine{
		{speaker = "Oracle", text = fmt.tprintf("Taz! %s is weakened — now is the moment!", spirit_name)},
		{speaker = "Oracle", text = "Focus your soul and pull their essence inward. BIND them!"},
	}
	set_dialogue(lines, .Battle, 0)
}

start_victory_dialogue :: proc(spirit_name: string) {
	lines := []DialogueLine{
		{speaker = "Oracle", text = fmt.tprintf("%s has been bound to your soul, Taz!", spirit_name)},
		{speaker = "Oracle", text = "Their power flows through you. You grow stronger still."},
	}
	set_dialogue(lines, .Exploring, 0)
}

update_dialogue :: proc(dt: f32) {
	if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.Z) ||
	   rl.IsKeyPressed(.SPACE) || rl.IsMouseButtonPressed(.LEFT) {
		g_dlg.current += 1
		if g_dlg.current >= g_dlg.count {
			// Done — trigger callback, return to state
			cb := g_dlg.callback
			g_game_state = g_dlg.return_state

			// Returning into the fusion menu always needs a fresh selection state
			if g_dlg.return_state == .FusionMenu {
				init_fusion()
			}

			// Handle callbacks
			if cb == 2 {
				// Veyrath fight
				veyrath_id := 0
				for i in 0 ..< g_db.monster_count {
					if g_db.monsters[i].name == "Veyrath" {
						veyrath_id = g_db.monsters[i].id
						break
					}
				}
				if veyrath_id != 0 {
					init_battle(g_player_id, veyrath_id)
					g_game_state = .Battle
				}
			} else if cb == 3 {
				// Start a battle against the current level's named spirit
				// (the dialogue we just finished was its story introduction)
				level := current_level_def()
				if level != nil {
					spirit_id := level_spirit_monster_id(level)
					if spirit_id != 0 {
						init_battle(g_player_id, spirit_id)
						g_game_state = .Battle
					}
				}
			}
		}
	}
}

draw_dialogue :: proc() {
	if g_dlg.current >= g_dlg.count do return

	line := g_dlg.lines[g_dlg.current]

	// Darken background
	rl.DrawRectangle(0, 0, SCREEN_W, SCREEN_H, rl.Color{0, 0, 0, 160})

	// Portrait box (left side)
	portrait_x: i32 = 40
	portrait_y: i32 = SCREEN_H - 260
	portrait_w: i32 = 160
	portrait_h: i32 = 160
	pcol := speaker_color(line.speaker)
	rl.DrawRectangle(portrait_x, portrait_y, portrait_w, portrait_h, rl.Color{pcol.r/3, pcol.g/3, pcol.b/3, 255})
	rl.DrawRectangleLines(portrait_x, portrait_y, portrait_w, portrait_h, pcol)

	// Draw chibi programmer art for Oracle / Taz
	draw_dialogue_portrait(line.speaker, portrait_x, portrait_y, portrait_w, portrait_h)

	// Dialogue box
	box_x: i32 = 220
	box_y: i32 = SCREEN_H - 270
	box_w: i32 = SCREEN_W - 260
	box_h: i32 = 180
	rl.DrawRectangle(box_x, box_y, box_w, box_h, COL_PANEL)
	rl.DrawRectangleLines(box_x, box_y, box_w, box_h, pcol)
	// Double border highlight
	rl.DrawRectangleLines(box_x + 2, box_y + 2, box_w - 4, box_h - 4, rl.Color{pcol.r, pcol.g, pcol.b, 80})

	// Speaker name
	draw_text_at(line.speaker, box_x + 16, box_y + 12, 22, pcol)

	// Dialogue text — word wrapped manually at ~60 chars
	draw_wrapped_text(line.text, box_x + 16, box_y + 44, box_w - 32, 18)

	// Progress indicator
	prog_str := fmt.tprintf("%d / %d", g_dlg.current + 1, g_dlg.count)
	pw := rl.MeasureText(_cs(prog_str), 14)
	draw_text_at(prog_str, box_x + box_w - pw - 12, box_y + box_h - 24, 14, COL_DIM)
	draw_text_at("Press SPACE / Enter", box_x + 16, box_y + box_h - 24, 14, COL_DIM)
}

draw_dialogue_portrait :: proc(speaker: string, x, y, w, h: i32) {
	cx := x + w/2
	cy := y + h/2
	col := speaker_color(speaker)

	switch speaker {
	case "Oracle":
		// Robed figure with star crown — programmer art
		// Body (robe)
		rl.DrawRectangle(cx - 28, cy - 10, 56, 60, rl.Color{80, 40, 120, 255})
		// Hood
		rl.DrawTriangle(
			rl.Vector2{f32(cx - 32), f32(cy - 10)},
			rl.Vector2{f32(cx + 32), f32(cy - 10)},
			rl.Vector2{f32(cx), f32(cy - 55)},
			rl.Color{60, 20, 100, 255},
		)
		// Face
		rl.DrawCircle(cx, cy - 20, 22, rl.Color{230, 200, 170, 255})
		// Eyes (glowing)
		rl.DrawCircle(cx - 8, cy - 22, 4, col)
		rl.DrawCircle(cx + 8, cy - 22, 4, col)
		// Star crown
		for i in 0 ..< 5 {
			angle := f32(i) * 72.0 * 3.14159 / 180.0 - 3.14159/2.0
			sx := cx + i32(22.0 * math.cos(angle))
			sy := (cy - 42) + i32(10.0 * math.sin(angle))
			rl.DrawCircle(sx, sy, 3, COL_HILITE)
		}
		// Staff hint
		rl.DrawRectangle(cx + 30, cy - 60, 4, 80, rl.Color{160, 130, 80, 255})
		rl.DrawCircle(cx + 32, cy - 62, 7, col)

	case "Taz":
		// Small chibi boy — gets taller as he levels up (scale with level)
		scale : f32 = 1.0 + f32(g_prog.level - 1) * 0.05
		bh := i32(f32(50) * scale)
		// Body
		rl.DrawRectangle(cx - 18, cy + 5, 36, bh, rl.Color{60, 120, 200, 255})
		// Head (big chibi head)
		rl.DrawCircle(cx, cy - 10, f32(i32(f32(26) * scale)), rl.Color{230, 200, 170, 255})
		// Hair (spiky)
		rl.DrawTriangle(
			rl.Vector2{f32(cx - 20), f32(cy - 30)},
			rl.Vector2{f32(cx), f32(cy - 52)},
			rl.Vector2{f32(cx - 8), f32(cy - 28)},
			rl.Color{40, 40, 40, 255},
		)
		rl.DrawTriangle(
			rl.Vector2{f32(cx), f32(cy - 52)},
			rl.Vector2{f32(cx + 20), f32(cy - 30)},
			rl.Vector2{f32(cx + 8), f32(cy - 28)},
			rl.Color{40, 40, 40, 255},
		)
		rl.DrawTriangle(
			rl.Vector2{f32(cx - 10), f32(cy - 48)},
			rl.Vector2{f32(cx + 10), f32(cy - 48)},
			rl.Vector2{f32(cx), f32(cy - 62)},
			rl.Color{40, 40, 40, 255},
		)
		// Eyes
		rl.DrawCircle(cx - 8, cy - 12, 5, rl.Color{30, 30, 30, 255})
		rl.DrawCircle(cx + 8, cy - 12, 5, rl.Color{30, 30, 30, 255})
		rl.DrawCircle(cx - 7, cy - 13, 2, rl.WHITE)
		rl.DrawCircle(cx + 9, cy - 13, 2, rl.WHITE)
		// Level badge
		lv_str := fmt.tprintf("Lv%d", g_prog.level)
		draw_text_at(lv_str, x + 4, y + h - 22, 14, COL_HILITE)

	case "Veyrath":
		// Dragon silhouette — red/black
		// Body
		rl.DrawCircle(cx, cy, 35, rl.Color{120, 20, 20, 255})
		// Horns
		rl.DrawTriangle(
			rl.Vector2{f32(cx - 20), f32(cy - 30)},
			rl.Vector2{f32(cx - 10), f32(cy - 60)},
			rl.Vector2{f32(cx - 5), f32(cy - 28)},
			rl.Color{180, 40, 20, 255},
		)
		rl.DrawTriangle(
			rl.Vector2{f32(cx + 5), f32(cy - 28)},
			rl.Vector2{f32(cx + 10), f32(cy - 60)},
			rl.Vector2{f32(cx + 20), f32(cy - 30)},
			rl.Color{180, 40, 20, 255},
		)
		// Eyes (menacing)
		rl.DrawCircle(cx - 10, cy - 5, 6, rl.Color{255, 200, 0, 255})
		rl.DrawCircle(cx + 10, cy - 5, 6, rl.Color{255, 200, 0, 255})
		rl.DrawRectangle(cx - 12, cy - 7, 4, 8, rl.Color{40, 0, 0, 255})
		rl.DrawRectangle(cx + 8, cy - 7, 4, 8, rl.Color{40, 0, 0, 255})
		// Flame breath hint
		rl.DrawCircle(cx + 30, cy + 10, 8, rl.Color{255, 120, 20, 200})
		rl.DrawCircle(cx + 40, cy + 6, 6, rl.Color{255, 80, 0, 160})
		rl.DrawCircle(cx + 48, cy + 2, 4, rl.Color{200, 50, 0, 120})

	case:
		// Generic unknown
		rl.DrawRectangle(cx - 25, cy - 50, 50, 70, COL_DIM)
		rl.DrawCircle(cx, cy - 55, 20, COL_DIM)
		draw_text_at("???", cx - 12, cy - 62, 16, COL_BG)
	}
}

// Simple word-wrap text renderer
draw_wrapped_text :: proc(text: string, x, y, max_w, size: i32) {
	line_buf: [256]byte
	line_len := 0
	line_y := y
	word_start := 0

	flush_line :: proc(buf: ^[256]byte, n: int, lx, ly, sz: i32) {
		if n <= 0 do return
		s := string(buf[:n])
		draw_text_at(s, lx, ly, sz, COL_TEXT)
	}

	for i := 0; i <= len(text); i += 1 {
		ch: byte = 0
		if i < len(text) do ch = text[i]

		if ch == ' ' || ch == 0 {
			word := text[word_start:i]
			test_len := line_len + len(word) + (1 if line_len > 0 else 0)
			test_str: [256]byte
			copy(test_str[:], line_buf[:line_len])
			if line_len > 0 { test_str[line_len] = ' ' }
			copy(test_str[line_len + (1 if line_len > 0 else 0):], word)

			tw := rl.MeasureText(_cs(string(test_str[:test_len])), size)
			if tw > max_w && line_len > 0 {
				flush_line(&line_buf, line_len, x, line_y, size)
				line_y += size + 4
				line_len = 0
				copy(line_buf[:], word)
				line_len = len(word)
			} else {
				if line_len > 0 { line_buf[line_len] = ' '; line_len += 1 }
				copy(line_buf[line_len:], word)
				line_len += len(word)
			}
			word_start = i + 1
		}
	}
	flush_line(&line_buf, line_len, x, line_y, size)
}
