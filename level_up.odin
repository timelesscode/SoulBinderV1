package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

// ── Level-Up Screen ───────────────────────────────────────────────────────

LevelUpScreen :: struct {
	timer:       f32,
	move_name:   string,
	showed_move: bool,
}

g_lvl_screen: LevelUpScreen

update_level_up :: proc(dt: f32) {
	g_lvl_screen.timer += dt
	if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.Z) || rl.IsKeyPressed(.SPACE) {
		// Return to wherever the battle that triggered this level-up began
		// (a level walk, or the Hub for the Veyrath challenge).
		g_game_state = g_prev_game_state
	}
}

draw_level_up :: proc() {
	rl.DrawRectangle(0, 0, SCREEN_W, SCREEN_H, rl.Color{0, 0, 0, 200})

	t := g_lvl_screen.timer
	pulse := u8(180 + int(math.sin(t * 4.0) * 60.0))
	cx : i32 = SCREEN_W / 2
	cy : i32 = SCREEN_H / 2 - 40

	// Pulsing glow rings
	for r := i32(80); r > 0; r -= 20 {
		alpha := u8(int(pulse) * int(r) / 80)
		rl.DrawCircle(cx, cy, f32(r), rl.Color{100, 220, 120, alpha})
	}

	// LEVEL UP text
	lv_str := fmt.tprintf("LEVEL %d!", g_prog.level)
	lw := rl.MeasureText(_cs(lv_str), 52)
	draw_text_at(lv_str, (SCREEN_W - lw)/2, cy - 30, 52, rl.Color{100, 255, 140, 255})

	// Taz chibi
	draw_taz_world(cx - 16, cy + 40, 1, t * 10)

	// Stats summary
	def := get_monster_def(g_player_id)
	if def != nil {
		stat_str := fmt.tprintf("HP %d   ATK %d   DEF %d   SOUL %d",
			def.base_hp, def.base_attack, def.base_defense, def.soul_max)
		sw := rl.MeasureText(_cs(stat_str), 18)
		draw_text_at(stat_str, (SCREEN_W - sw)/2, cy + 100, 18, COL_TEXT)
	}

	// New move learned?
	if g_prog.pending_move != 0 {
		mv := get_technique_def(g_prog.pending_move)
		if mv != nil {
			mv_str := fmt.tprintf("New move learned: %s!", mv.name)
			mw := rl.MeasureText(_cs(mv_str), 22)
			draw_text_at(mv_str, (SCREEN_W - mw)/2, cy + 130, 22, COL_SOUL)
			type_desc := fmt.tprintf("Type: %s   Power: %d   Soul: %d",
				type_name(mv.tech_type), mv.power, mv.soul_cost)
			td := rl.MeasureText(_cs(type_desc), 16)
			draw_text_at(type_desc, (SCREEN_W - td)/2, cy + 158, 16, type_color(mv.tech_type))
		}
		g_prog.pending_move = 0
	}

	hint := "Press SPACE / Enter to continue"
	hw := rl.MeasureText(_cs(hint), 16)
	draw_text_at(hint, (SCREEN_W - hw)/2, SCREEN_H - 40, 16, COL_DIM)
}
