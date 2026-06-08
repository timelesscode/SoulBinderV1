package main

import "core:fmt"
import "core:math/rand"
import rl "vendor:raylib"

// ── Hub / Rest Area ───────────────────────────────────────────────────────
// The home base between expeditions: pick a level to explore, rest up,
// or visit the Oracle to fuse bound spirits. Backed by one of the
// farmtown/farmcity scene paintings, chosen at random each visit so the
// rest area doesn't feel static across a long playthrough.

HUB_BG_PATHS := [?]string{
	"art/farmtown_0 - Copy.jpeg",
	"art/farmtown_1 - Copy.jpeg",
	"art/farmtown_2 - Copy.jpeg",
	"art/farmtown_3 - Copy.jpeg",
	"art/farmtown_4 - Copy.jpeg",
	"art/farmtown_5 - Copy.jpeg",
	"art/farmtown_6 - Copy.jpeg",
	"art/farmtown_7 - Copy.jpeg",
	"art/farmtown_8 - Copy.jpeg",
	"art/farmtown_9 - Copy.jpeg",
	"art/farmcity_0 - Copy.jpeg",
	"art/farmcity_1 - Copy.jpeg",
	"art/farmcity_2 - Copy.jpeg",
	"art/farmcity_3 - Copy.jpeg",
	"art/farmcity_4 - Copy.jpeg",
}

g_hub_bgs: [len(HUB_BG_PATHS)]rl.Texture2D

load_hub_backgrounds :: proc() {
	for path, i in HUB_BG_PATHS {
		g_hub_bgs[i] = rl.LoadTexture(_cs(path))
	}
}

unload_hub_backgrounds :: proc() {
	for tex in g_hub_bgs {
		if tex.id != 0 do rl.UnloadTexture(tex)
	}
}

HUB_LEVEL_COUNT :: len(LEVELS)

Hub :: struct {
	cursor: int,
	bg_idx: int,
	active: bool, // true once a backdrop has been rolled for this visit
}

g_hub: Hub

hub_item_count :: proc() -> int {
	n := HUB_LEVEL_COUNT + 2 // levels, then Rest & Heal, then Speak to the Oracle
	if ten_spirits_complete() do n += 1 // Confront Veyrath, once unlocked
	return n
}

hub_item_label :: proc(i: int) -> string {
	if i < HUB_LEVEL_COUNT {
		level := &LEVELS[i]
		mark := "[      ]"
		if g_prog.ten_collected[i] do mark = "[BOUND]"
		return fmt.tprintf("%s  %s", mark, level.name)
	}
	switch i - HUB_LEVEL_COUNT {
	case 0: return "Rest & Heal"
	case 1: return "Speak to the Oracle"
	case 2: return "Confront Veyrath"
	}
	return "?"
}

select_hub_item :: proc(item: int) {
	if item < HUB_LEVEL_COUNT {
		enter_level(item)
		g_game_state = .Exploring
		return
	}

	switch item - HUB_LEVEL_COUNT {
	case 0: // Rest & Heal — top up consumables and restore spirits
		g_battle.item_qty[0] = max(g_battle.item_qty[0], 3) // Blood Vial
		g_battle.item_qty[1] = max(g_battle.item_qty[1], 2) // Soul Shard
		g_battle.item_qty[2] = max(g_battle.item_qty[2], 1) // Elixir
		heal_all_spirits()
		set_hud_message("You rest. Supplies restocked and spirits recovered!")

	case 1: // Speak to the Oracle — fusion access
		if !g_oracle_opened {
			g_oracle_opened = true
			start_fusion_tutorial_dialogue()
			g_game_state = .Dialogue
		} else if g_prog.bound_count >= 2 {
			init_fusion()
			g_game_state = .FusionMenu
		} else {
			set_hud_message("The Oracle needs at least two bound spirits to fuse.")
		}

	case 2: // Confront Veyrath — final boss, unlocked once all nine are bound
		if ten_spirits_complete() {
			start_veyrath_dialogue()
			g_game_state = .Dialogue
		}
	}
}

update_hub :: proc(dt: f32) {
	if !g_hub.active {
		g_hub.active = true
		if len(g_hub_bgs) > 0 do g_hub.bg_idx = rand.int_max(len(g_hub_bgs))
		if g_hub.cursor >= hub_item_count() do g_hub.cursor = 0
	}

	n := hub_item_count()
	if rl.IsKeyPressed(.UP) || rl.IsKeyPressed(.W) {
		g_hub.cursor = (g_hub.cursor + n - 1) % n
	}
	if rl.IsKeyPressed(.DOWN) || rl.IsKeyPressed(.S) {
		g_hub.cursor = (g_hub.cursor + 1) % n
	}
	if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.Z) || rl.IsKeyPressed(.SPACE) {
		select_hub_item(g_hub.cursor)
	}

	if g_hud_msg.timer > 0 do g_hud_msg.timer -= dt

	// Leaving — make sure the next visit rolls a fresh backdrop
	if g_game_state != .Hub {
		g_hub.active = false
	}
}

draw_hub :: proc() {
	if g_hub.bg_idx >= 0 && g_hub.bg_idx < len(g_hub_bgs) && g_hub_bgs[g_hub.bg_idx].id != 0 {
		tex := g_hub_bgs[g_hub.bg_idx]
		src := rl.Rectangle{0, 0, f32(tex.width), f32(tex.height)}
		dst := rl.Rectangle{0, 0, f32(SCREEN_W), f32(SCREEN_H)}
		rl.DrawTexturePro(tex, src, dst, {0, 0}, 0, rl.WHITE)
	} else {
		rl.DrawRectangle(0, 0, SCREEN_W, SCREEN_H, rl.Color{40, 50, 30, 255})
	}
	rl.DrawRectangle(0, 0, SCREEN_W, SCREEN_H, rl.Color{10, 8, 16, 130})

	draw_text_at("Rest Area", 40, 26, 34, COL_HILITE)
	draw_text_at("A quiet place between worlds. Recover, fuse bound spirits, or set out again.", 40, 68, 16, COL_TEXT)
	status := fmt.tprintf("Taz  Lv%d   Spirits bound: %d/%d", g_prog.level, g_prog.bound_count, MAX_BOUND_SPIRITS)
	draw_text_at(status, 40, 96, 16, COL_DIM)

	panel_x : i32 = 40
	panel_y : i32 = 136
	panel_w : i32 = 460
	panel_h : i32 = SCREEN_H - panel_y - 50
	rl.DrawRectangle(panel_x, panel_y, panel_w, panel_h, rl.Color{20, 16, 30, 210})
	rl.DrawRectangleLines(panel_x, panel_y, panel_w, panel_h, COL_BORDER)

	row_h : i32 = 32
	visible_rows := int(panel_h - 16) / int(row_h)
	n := hub_item_count()
	scroll := 0
	if g_hub.cursor >= visible_rows do scroll = g_hub.cursor - visible_rows + 1

	for i in 0 ..< visible_rows {
		item := i + scroll
		if item >= n do break
		ry := panel_y + 8 + i32(i) * row_h
		selected := item == g_hub.cursor
		if selected {
			rl.DrawRectangle(panel_x + 6, ry - 2, panel_w - 12, row_h - 4, COL_PANEL_2)
		}
		col := COL_HILITE if selected else COL_TEXT
		if item >= HUB_LEVEL_COUNT + 2 { // Confront Veyrath — always stands out
			col = rl.Color{255, 110, 90, 255}
		}
		draw_text_at(hub_item_label(item), panel_x + 16, ry + 4, 17, col)
	}

	detail_x := panel_x + panel_w + 30
	detail_w := SCREEN_W - detail_x - 40
	rl.DrawRectangle(detail_x, panel_y, detail_w, panel_h, rl.Color{20, 16, 30, 210})
	rl.DrawRectangleLines(detail_x, panel_y, detail_w, panel_h, COL_BORDER)
	draw_hub_detail(detail_x + 22, panel_y + 22, detail_w - 44, g_hub.cursor)

	draw_text_at("Up/Down: select   Enter: confirm", panel_x, SCREEN_H - 30, 14, COL_DIM)

	if g_hud_msg.timer > 0 {
		alpha := u8(min(255, int(g_hud_msg.timer * 255)))
		col := rl.Color{235, 230, 100, alpha}
		mw := rl.MeasureText(_cs(g_hud_msg.text), 18)
		mx := (SCREEN_W - mw) / 2
		rl.DrawRectangle(mx - 12, SCREEN_H - 96, mw + 24, 34, rl.Color{0, 0, 0, alpha/2})
		draw_text_at(g_hud_msg.text, mx, SCREEN_H - 92, 18, col)
	}
}

draw_hub_detail :: proc(x, y, w: i32, item: int) {
	if item < HUB_LEVEL_COUNT {
		level := &LEVELS[item]
		draw_text_at(level.name, x, y, 24, COL_HILITE)
		draw_wrapped_text(level.flavor, x, y + 38, w, 16)

		bound_str := "Not yet bound"
		col := COL_DIM
		if g_prog.ten_collected[item] {
			bound_str = "Bound to your soul"
			col = COL_BIND
		}
		draw_text_at(fmt.tprintf("Spirit: %s  (%s)", level.spirit_name, bound_str), x, y + 96, 16, col)
		draw_text_at("Walk this scene, weaken its spirit in battle, then BIND it.", x, y + 122, 14, COL_DIM)
		return
	}

	switch item - HUB_LEVEL_COUNT {
	case 0:
		draw_text_at("Rest & Heal", x, y, 24, COL_HILITE)
		draw_wrapped_text("Take a moment to recover. Restocks your Blood Vials, Soul Shards, and Elixirs to a comfortable minimum — free of charge.", x, y + 38, w, 16)
	case 1:
		draw_text_at("Speak to the Oracle", x, y, 24, COL_HILITE)
		draw_wrapped_text("The Oracle can fuse two bound spirits into one greater being. You'll need at least two spirits bound before it can help.", x, y + 38, w, 16)
	case 2:
		draw_text_at("Confront Veyrath", x, y, 24, rl.Color{255, 110, 90, 255})
		draw_wrapped_text("All nine spirits are bound. Veyrath the Dragon awaits in the final confrontation — there's no turning back once you begin.", x, y + 38, w, 16)
	}
}
