package main

import "core:fmt"
import "core:math/rand"
import rl "vendor:raylib"

// ── Fusion Menu ───────────────────────────────────────────────────────────
// The Oracle fuses two bound spirits into a stronger one.
// Result: higher stats from each parent, new combined name, random strong tech.

Fusion :: struct {
	cursor_a: int, // index into bound_spirits for first choice
	cursor_b: int, // index for second choice
	selecting: int, // 0 = choosing A, 1 = choosing B, 2 = confirm screen
	result_name: string,
	result_hp:   int,
	result_atk:  int,
	result_def:  int,
	result_type: TechType,
	result_move: int, // tech_id
}

g_fusion: Fusion

init_fusion :: proc() {
	g_fusion = {}
	g_fusion.cursor_a = 0
	g_fusion.cursor_b = min(1, g_prog.bound_count - 1)
	g_fusion.selecting = 0
}

// Compute preview of what fusion would produce
compute_fusion_preview :: proc() {
	if g_prog.bound_count < 2 do return

	a := g_prog.bound_spirits[g_fusion.cursor_a]
	b := g_prog.bound_spirits[g_fusion.cursor_b]
	def_a := get_monster_def(a)
	def_b := get_monster_def(b)
	if def_a == nil || def_b == nil do return

	// Combine names: first half of A + second half of B
	na := def_a.name
	nb := def_b.name
	half_a := len(na) / 2
	half_b := len(nb) / 2
	if half_a < 1 do half_a = 1
	if half_b < 1 do half_b = 1
	g_fusion.result_name = fmt.tprintf("%s%s", na[:half_a], nb[half_b:])

	// Stats: max of each + small bonus
	g_fusion.result_hp  = max(def_a.base_hp, def_b.base_hp) + 10
	g_fusion.result_atk = max(def_a.base_attack, def_b.base_attack) + 3
	g_fusion.result_def = max(def_a.base_defense, def_b.base_defense) + 2

	// Type: inherit from the stronger attacker
	if def_a.base_attack >= def_b.base_attack {
		g_fusion.result_type = def_a.mon_type
	} else {
		g_fusion.result_type = def_b.mon_type
	}

	// Pick a random "power" technique from the DB that matches result type
	candidates: [MAX_TECHNIQUES_DB]int
	count := 0
	for i in 0 ..< g_db.technique_count {
		t := &g_db.techniques[i]
		if t.tech_type == g_fusion.result_type && t.power > 30 {
			candidates[count] = t.id
			count += 1
		}
	}
	if count > 0 {
		g_fusion.result_move = candidates[rand.int_max(count)]
	} else if g_db.technique_count > 0 {
		g_fusion.result_move = g_db.techniques[rand.int_max(g_db.technique_count)].id
	}
}

perform_fusion :: proc() {
	if g_prog.bound_count < 2 do return
	a_idx := g_fusion.cursor_a
	b_idx := g_fusion.cursor_b

	lo := a_idx
	hi := b_idx
	if lo > hi { lo, hi = hi, lo }
	remove_bound_spirit_at(hi)
	remove_bound_spirit_at(lo)

	// Create a new monster def for the fused spirit
	// Re-use a DB slot that isn't in use (use DB entry at monster_count)
	if g_db.monster_count < MAX_MONSTERS_DB {
		new_id := 1000 + rand.int_max(8999) // unique-ish ID
		i := g_db.monster_count
		g_db.monsters[i].id = new_id
		g_db.monsters[i].name = g_fusion.result_name
		g_db.monsters[i].base_hp = g_fusion.result_hp
		g_db.monsters[i].base_attack = g_fusion.result_atk
		g_db.monsters[i].base_defense = g_fusion.result_def
		g_db.monsters[i].soul_max = 50
		g_db.monsters[i].mon_type = g_fusion.result_type
		g_db.monsters[i].spirit_id = 0 // no sprite
		g_db.monsters[i].moves[0] = g_fusion.result_move
		g_db.monster_count += 1

		slot := g_prog.bound_count
		g_prog.bound_spirits[slot]         = new_id
		g_prog.spirit_levels[slot]         = 1
		g_prog.spirit_xp[slot]             = 0
		g_prog.spirit_moves_unlocked[slot] = 1
		g_prog.spirit_hp_cur[slot]         = -1
		g_prog.bound_count += 1
	}
}

update_fusion :: proc(dt: f32) {
	if g_prog.bound_count < 2 {
		set_hud_message("You need at least 2 bound spirits to fuse!")
		g_game_state = .Hub
		return
	}

	switch g_fusion.selecting {
	case 0: // picking first spirit
		n := g_prog.bound_count
		if rl.IsKeyPressed(.UP) || rl.IsKeyPressed(.W) {
			g_fusion.cursor_a = (g_fusion.cursor_a + n - 1) % n
			compute_fusion_preview()
		}
		if rl.IsKeyPressed(.DOWN) || rl.IsKeyPressed(.S) {
			g_fusion.cursor_a = (g_fusion.cursor_a + 1) % n
			compute_fusion_preview()
		}
		if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.Z) || rl.IsKeyPressed(.SPACE) {
			g_fusion.selecting = 1
			// Make sure B is different from A
			g_fusion.cursor_b = (g_fusion.cursor_a + 1) % n
			compute_fusion_preview()
		}
		if rl.IsKeyPressed(.ESCAPE) || rl.IsKeyPressed(.X) {
			g_game_state = .Hub
		}

	case 1: // picking second spirit
		n := g_prog.bound_count
		if rl.IsKeyPressed(.UP) || rl.IsKeyPressed(.W) {
			next := (g_fusion.cursor_b + n - 1) % n
			if next == g_fusion.cursor_a do next = (next + n - 1) % n
			g_fusion.cursor_b = next
			compute_fusion_preview()
		}
		if rl.IsKeyPressed(.DOWN) || rl.IsKeyPressed(.S) {
			next := (g_fusion.cursor_b + 1) % n
			if next == g_fusion.cursor_a do next = (next + 1) % n
			g_fusion.cursor_b = next
			compute_fusion_preview()
		}
		if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.Z) || rl.IsKeyPressed(.SPACE) {
			if g_fusion.cursor_a != g_fusion.cursor_b {
				g_fusion.selecting = 2
				compute_fusion_preview()
			}
		}
		if rl.IsKeyPressed(.ESCAPE) || rl.IsKeyPressed(.X) {
			g_fusion.selecting = 0
		}

	case 2: // confirm
		if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.Z) || rl.IsKeyPressed(.SPACE) {
			perform_fusion()
			set_hud_message(fmt.tprintf("Fusion complete! %s has been born!", g_fusion.result_name))
			g_game_state = .Hub
		}
		if rl.IsKeyPressed(.ESCAPE) || rl.IsKeyPressed(.X) {
			g_fusion.selecting = 1
		}
	}
}

draw_fusion :: proc() {
	// Background
	rl.DrawRectangle(0, 0, SCREEN_W, SCREEN_H, rl.Color{10, 8, 20, 255})

	// Title
	draw_text_at("Oracle Fusion Chamber", SCREEN_W/2 - 180, 20, 32, rl.Color{200, 160, 255, 255})
	draw_text_at("Combine two spirits into a greater being", SCREEN_W/2 - 220, 60, 18, COL_DIM)

	if g_prog.bound_count < 2 {
		draw_text_at("You need at least 2 bound spirits!", SCREEN_W/2 - 180, SCREEN_H/2, 22, COL_HP)
		draw_text_at("Press ESC to return", SCREEN_W/2 - 100, SCREEN_H/2 + 40, 18, COL_DIM)
		return
	}

	// Left panel — spirit list (A)
	panel_w: i32 = 280
	panel_h: i32 = 380
	ax: i32 = 40
	ay: i32 = 100
	rl.DrawRectangle(ax, ay, panel_w, panel_h, COL_PANEL)
	rl.DrawRectangleLines(ax, ay, panel_w, panel_h, COL_BORDER)
	label_a := "Spirit A  (confirm: Enter)"
	if g_fusion.selecting == 1 do label_a = "Spirit A  ✓"
	draw_text_at(label_a, ax + 10, ay + 8, 16, rl.Color{200, 160, 255, 255})

	for i in 0 ..< g_prog.bound_count {
		def := get_monster_def(g_prog.bound_spirits[i])
		if def == nil do continue
		iy := ay + 36 + i32(i) * 30
		selected_a := g_fusion.selecting <= 1 && g_fusion.cursor_a == i
		col := COL_HILITE if selected_a else COL_DIM
		if selected_a {
			rl.DrawRectangle(ax + 6, iy - 2, panel_w - 12, 26, COL_PANEL_2)
		}
		draw_text_at(def.name, ax + 16, iy + 2, 18, col)
		type_str := type_name(def.mon_type)
		tw := rl.MeasureText(_cs(type_str), 13)
		draw_text_at(type_str, ax + panel_w - tw - 12, iy + 5, 13, type_color(def.mon_type))
	}

	// Right panel — spirit list (B)
	bx := SCREEN_W - 40 - panel_w
	by := ay
	rl.DrawRectangle(bx, by, panel_w, panel_h, COL_PANEL)
	rl.DrawRectangleLines(bx, by, panel_w, panel_h, COL_BORDER)
	label_b := "Spirit B  (pick after A)"
	if g_fusion.selecting == 1 do label_b = "Spirit B  (confirm: Enter)"
	if g_fusion.selecting == 2 do label_b = "Spirit B  ✓"
	draw_text_at(label_b, bx + 10, by + 8, 16, rl.Color{200, 160, 255, 255})

	for i in 0 ..< g_prog.bound_count {
		if i == g_fusion.cursor_a && g_fusion.selecting >= 1 {
			continue // skip the A choice
		}
		def := get_monster_def(g_prog.bound_spirits[i])
		if def == nil do continue
		iy := by + 36 + i32(i) * 30
		selected_b := g_fusion.selecting >= 1 && g_fusion.cursor_b == i
		col := rl.Color{100, 220, 255, 255} if selected_b else COL_DIM
		if selected_b {
			rl.DrawRectangle(bx + 6, iy - 2, panel_w - 12, 26, COL_PANEL_2)
		}
		draw_text_at(def.name, bx + 16, iy + 2, 18, col)
	}

	// Center arrow
	draw_text_at("+", SCREEN_W/2 - 10, SCREEN_H/2 - 20, 40, rl.Color{200, 160, 255, 255})

	// Result preview (shown when both selected)
	if g_fusion.selecting >= 1 && g_fusion.result_name != "" {
		rx : i32 = SCREEN_W/2 - 150
		ry : i32 = 500
		rw: i32 = 300
		rh: i32 = 160
		rl.DrawRectangle(rx, ry, rw, rh, rl.Color{40, 20, 60, 255})
		rl.DrawRectangleLines(rx, ry, rw, rh, rl.Color{200, 160, 255, 255})
		draw_text_at("RESULT", rx + rw/2 - 36, ry + 8, 18, rl.Color{200, 160, 255, 255})
		draw_text_at(g_fusion.result_name, rx + 16, ry + 34, 22, COL_HILITE)
		draw_text_at(fmt.tprintf("HP %d  ATK %d  DEF %d", g_fusion.result_hp, g_fusion.result_atk, g_fusion.result_def),
			rx + 16, ry + 62, 15, COL_TEXT)
		draw_text_at(fmt.tprintf("Type: %s", type_name(g_fusion.result_type)), rx + 16, ry + 84, 15, type_color(g_fusion.result_type))
		mv := get_technique_def(g_fusion.result_move)
		if mv != nil {
			draw_text_at(fmt.tprintf("Learns: %s", mv.name), rx + 16, ry + 104, 15, COL_SOUL)
		}
		if g_fusion.selecting == 2 {
			draw_text_at("Enter = FUSE!   Esc = back", rx + 16, ry + 128, 14, COL_DIM)
		}
	}

	draw_text_at("Esc: back   Up/Down: select", 40, SCREEN_H - 28, 14, COL_DIM)
}
