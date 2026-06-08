package main

import "core:fmt"
import "core:strings"
import "core:math"
import rl "vendor:raylib"

COL_BG      :: rl.Color{18, 14, 28, 255}
COL_PANEL   :: rl.Color{30, 22, 46, 255}
COL_PANEL_2 :: rl.Color{45, 32, 64, 255}
COL_BORDER  :: rl.Color{120, 100, 160, 255}
COL_HILITE  :: rl.Color{230, 200, 90, 255}
COL_HP      :: rl.Color{210, 60, 70, 255}
COL_HP_BG   :: rl.Color{70, 30, 35, 255}
COL_SOUL    :: rl.Color{80, 140, 230, 255}
COL_SOUL_BG :: rl.Color{30, 45, 70, 255}
COL_TEXT    :: rl.Color{235, 230, 245, 255}
COL_DIM     :: rl.Color{140, 130, 155, 255}
COL_BIND    :: rl.Color{80, 230, 140, 255}
COL_BIND_BG :: rl.Color{20, 70, 40, 255}

_cs :: proc(s: string) -> cstring {
	return strings.clone_to_cstring(s, context.temp_allocator)
}

draw_text_at :: proc(text: string, x, y, size: i32, color: rl.Color) {
	rl.DrawText(_cs(text), x, y, size, color)
}

type_color :: proc(t: TechType) -> rl.Color {
	switch t {
	case .Fire:    return rl.Color{220, 90, 50, 255}
	case .Water:   return rl.Color{70, 130, 220, 255}
	case .Nature:  return rl.Color{80, 180, 90, 255}
	case .Dark:    return rl.Color{110, 60, 150, 255}
	case .Psychic: return rl.Color{210, 90, 200, 255}
	case .Kinetic: return rl.Color{200, 175, 90, 255}
	}
	return rl.GRAY
}

draw_bar :: proc(x, y, w, h: i32, current, maximum: int, fill, back: rl.Color) {
	rl.DrawRectangle(x, y, w, h, back)
	if maximum > 0 && current > 0 {
		fw := i32(f32(w - 2) * f32(current) / f32(maximum))
		rl.DrawRectangle(x + 1, y + 1, fw, h - 2, fill)
	}
	rl.DrawRectangleLines(x, y, w, h, COL_BORDER)
}

draw_monster_panel :: proc(mon: ^BattleMonster, x, y, w: i32) {
	h: i32 = 70
	rl.DrawRectangle(x, y, w, h, COL_PANEL)
	rl.DrawRectangleLines(x, y, w, h, COL_BORDER)

	draw_text_at(mon.name, x + 10, y + 6, 20, COL_TEXT)
	tcol := type_color(mon.mon_type)
	rl.DrawRectangle(x + w - 96, y + 8, 82, 18, tcol)
	draw_text_at(type_name(mon.mon_type), x + w - 90, y + 10, 14, rl.BLACK)

	draw_text_at("HP",   x + 10, y + 30, 14, COL_DIM)
	draw_bar(x + 40, y + 30, w - 130, 14, mon.hp, mon.hp_max, COL_HP, COL_HP_BG)
	draw_text_at(fmt.tprintf("%d/%d", mon.hp, mon.hp_max), x + w - 82, y + 30, 14, COL_TEXT)

	draw_text_at("SOUL", x + 10, y + 49, 14, COL_DIM)
	draw_bar(x + 40, y + 49, w - 130, 12, mon.soul, mon.soul_max, COL_SOUL, COL_SOUL_BG)
	draw_text_at(fmt.tprintf("%d/%d", mon.soul, mon.soul_max), x + w - 82, y + 48, 14, COL_TEXT)
}

draw_monster_sprite :: proc(mon: ^BattleMonster, cx, cy, size: i32) {
	x := cx - size / 2
	y := cy - size / 2
	if sheet, ok := get_monster_art(mon.name); ok {
		t := f32(rl.GetTime())
		src  := sheet_frame_rect(sheet, t, get_monster_art_fps(mon.name))
		dest := rl.Rectangle{f32(x), f32(y), f32(size), f32(size)}
		rl.DrawTexturePro(sheet.tex, src, dest, {0, 0}, 0, rl.WHITE)
	} else if g_atlas.id != 0 && mon.spirit_id >= 0 && mon.spirit_id < len(SpiritID) {
		src  := spirit_rects[SpiritID(mon.spirit_id)]
		dest := rl.Rectangle{f32(x), f32(y), f32(size), f32(size)}
		rl.DrawTexturePro(g_atlas, src, dest, {0, 0}, 0, rl.WHITE)
	} else {
		// Programmer art fallback
		col := type_color(mon.mon_type)
		rl.DrawRectangleRounded(rl.Rectangle{f32(x), f32(y), f32(size), f32(size)}, 0.2, 8, col)
		rl.DrawRectangleRoundedLines(rl.Rectangle{f32(x), f32(y), f32(size), f32(size)}, 0.2, 8, rl.WHITE)
		// Face
		face_r := size / 3
		rl.DrawCircle(cx, cy, f32(face_r), rl.Color{230, 200, 170, 255})
		// Eyes
		rl.DrawCircle(cx - face_r/3, cy - face_r/4, f32(face_r/5), rl.Color{30, 30, 30, 255})
		rl.DrawCircle(cx + face_r/3, cy - face_r/4, f32(face_r/5), rl.Color{30, 30, 30, 255})
		// Name label
		tw := rl.MeasureText(_cs(mon.name), 16)
		draw_text_at(mon.name, x + (size - tw)/2, y + size - 22, 16, rl.BLACK)
	}
}

draw_button :: proc(x, y, w, h: i32, label: string, selected, enabled: bool, accent: rl.Color = COL_BORDER) {
	bg := COL_PANEL_2 if selected else COL_PANEL
	border := COL_HILITE if selected else accent
	txt_col := COL_TEXT if enabled else COL_DIM

	rl.DrawRectangle(x, y, w, h, bg)
	rl.DrawRectangleLines(x, y, w, h, border)
	if selected {
		rl.DrawRectangleLines(x + 1, y + 1, w - 2, h - 2, border)
	}

	cstr := _cs(label)
	tw := rl.MeasureText(cstr, 20)
	rl.DrawText(cstr, x + (w - tw)/2, y + (h - 20)/2, 20, txt_col)
}

draw_log_box :: proc(x, y, w, h: i32) {
	rl.DrawRectangle(x, y, w, h, COL_PANEL)
	rl.DrawRectangleLines(x, y, w, h, COL_BORDER)
	draw_wrapped_text(get_log(), x + 14, y + h/2 - 14, w - 28, 20)
}

draw_action_menu :: proc(x, y, w, h: i32) {
	n := action_count()
	bw := (w - 20 - i32(n - 1)*10) / i32(n)
	for i in 0 ..< n {
		bx := x + 10 + i32(i) * (bw + 10)
		lbl := action_label(i)
		accent := COL_BIND if lbl == "BIND" else COL_BORDER
		// Flash green if bind is newly available
		if lbl == "BIND" && g_battle.can_bind {
			t := f32(rl.GetTime())
			flash := u8(160 + int(math.sin(t * 6.0) * 80.0))
			accent = rl.Color{80, flash, 100, 255}
		}
		draw_button(bx, y + 10, bw, h - 30, lbl, g_battle.action_cursor == i, true, accent)
	}
	draw_text_at("←→ select   Z/Enter confirm", x + 12, y + h - 20, 14, COL_DIM)
}

draw_move_menu :: proc(x, y, w, h: i32) {
	fighter  := active_fighter()
	unlocked := active_moves_unlocked()
	bw := (w - 30) / 2
	bh := (h - 30) / 2
	for i in 0 ..< MOVE_SLOTS {
		row := i / 2
		col := i % 2
		bx := x + 10 + i32(col) * (bw + 10)
		by := y + 10 + i32(row) * (bh + 10)

		tid  := fighter.moves[i]
		tech := get_technique_def(tid)
		selected := g_battle.move_cursor == i
		locked   := i >= unlocked

		if tech == nil || locked {
			label := "---" if tech == nil else fmt.tprintf("Lv%d needed", taz_move_unlocks[i].level)
			draw_button(bx, by, bw, bh, label, selected, false)
			continue
		}
		can_afford := fighter.soul >= tech.soul_cost
		bg     := COL_PANEL_2 if selected else COL_PANEL
		border := COL_HILITE  if selected else COL_BORDER
		rl.DrawRectangle(bx, by, bw, bh, bg)
		rl.DrawRectangleLines(bx, by, bw, bh, border)

		txt_col := COL_TEXT if can_afford else COL_DIM
		draw_text_at(tech.name, bx + 12, by + 8, 18, txt_col)

		tcol := type_color(tech.tech_type)
		rl.DrawRectangle(bx + 12, by + bh - 30, 64, 16, tcol)
		draw_text_at(type_name(tech.tech_type), bx + 16, by + bh - 28, 12, rl.BLACK)

		info := fmt.tprintf("PWR %d  SOUL %d", tech.power, tech.soul_cost)
		draw_text_at(info, bx + bw - 160, by + bh - 28, 14, txt_col)
	}
	draw_text_at("Z/Enter use   X/Esc back", x + 12, y + h - 20, 14, COL_DIM)
}

draw_spirit_menu :: proc(x, y, w, h: i32) {
	rl.DrawRectangle(x, y, w, h, COL_PANEL)
	rl.DrawRectangleLines(x, y, w, h, COL_BORDER)
	draw_text_at("Choose Spirit", x + 12, y + 8, 18, COL_HILITE)

	row_h : i32 = 34
	for i in 0 ..< g_prog.bound_count {
		def := get_monster_def(g_prog.bound_spirits[i])
		if def == nil do continue
		iy       := y + 34 + i32(i) * row_h
		selected := g_battle.spirit_cursor == i
		fainted  := spirit_is_fainted(i)
		if selected {
			rl.DrawRectangle(x + 6, iy - 2, w - 12, row_h, COL_PANEL_2)
		}
		col := COL_DIM if fainted else (COL_HILITE if selected else COL_TEXT)
		lv_str := fmt.tprintf("Lv%d", g_prog.spirit_levels[i])
		draw_text_at(fmt.tprintf("%s  %s", def.name, lv_str), x + 16, iy + 6, 17, col)

		// Type badge
		tcol := type_color(def.mon_type)
		tw   := rl.MeasureText(_cs(type_name(def.mon_type)), 12)
		rl.DrawRectangle(x + 160, iy + 8, tw + 8, 14, tcol)
		draw_text_at(type_name(def.mon_type), x + 164, iy + 9, 12, rl.BLACK)

		// HP bar or FAINTED tag
		if fainted {
			draw_text_at("FAINTED", x + w - 90, iy + 6, 14, COL_HP)
		} else {
			hp_max := spirit_hp_max_at(i)
			hp_cur := g_prog.spirit_hp_cur[i]
			if hp_cur < 0 do hp_cur = hp_max
			draw_bar(x + w - 114, iy + 8, 100, 12, hp_cur, hp_max, COL_HP, COL_HP_BG)
		}
	}
	if g_prog.bound_count == 0 {
		draw_text_at("No spirits bound yet.", x + 16, y + 34, 16, COL_DIM)
	}
	draw_text_at("Up/Down: select   Z/Enter: summon   X/Esc: back", x + 12, y + h - 20, 14, COL_DIM)
}

// ── Procedural item icons ─────────────────────────────────────────────────
// Items have no spritesheet art of their own, so each one gets a small
// distinct silhouette + color keyed off what it actually does: a vial for
// HP-only restoratives, a faceted shard for soul-only ones, a vial-with-
// gem for items that do both, and a radiant starburst for full restores.

draw_vial_icon :: proc(cx, cy, size: i32, fill: rl.Color) {
	w := f32(size) * 0.5
	h := f32(size) * 0.62
	x := f32(cx) - w/2
	y := f32(cy) - h/2 + f32(size)*0.05

	neck_w := w * 0.34
	neck_h := f32(size) * 0.16
	rl.DrawRectangle(i32(f32(cx) - neck_w/2), i32(y - neck_h), i32(neck_w), i32(neck_h)+2, rl.Color{205, 200, 220, 255})
	rl.DrawRectangle(i32(f32(cx) - neck_w/2 - 2), i32(y - neck_h - 4), i32(neck_w)+4, 4, rl.Color{120, 110, 90, 255})

	body := rl.Rectangle{x, y, w, h}
	rl.DrawRectangleRounded(body, 0.45, 6, rl.Color{235, 230, 245, 235})
	fill_h := h * 0.58
	rl.DrawRectangleRounded(rl.Rectangle{x + 3, y + (h - fill_h), w - 6, fill_h - 3}, 0.4, 6, fill)
	rl.DrawRectangleRoundedLines(body, 0.45, 6, rl.Color{40, 36, 56, 255})
	// Glass highlight
	rl.DrawLineEx(rl.Vector2{x + w*0.28, y + h*0.18}, rl.Vector2{x + w*0.28, y + h*0.82}, 2, rl.Color{255, 255, 255, 90})
}

draw_shard_icon :: proc(cx, cy, size: i32, fill: rl.Color) {
	r := f32(size) * 0.42
	top    := rl.Vector2{f32(cx), f32(cy) - r}
	right  := rl.Vector2{f32(cx) + r*0.7, f32(cy) - r*0.05}
	bottom := rl.Vector2{f32(cx), f32(cy) + r}
	left   := rl.Vector2{f32(cx) - r*0.7, f32(cy) - r*0.05}
	dim    := rl.Color{fill.r/2, fill.g/2, fill.b/2, fill.a}
	rl.DrawTriangle(left, top, right, fill)
	rl.DrawTriangle(left, right, bottom, dim)
	rl.DrawLineEx(top, bottom, 1.5, rl.Color{255, 255, 255, 130})
	rl.DrawTriangleLines(left, top, right, rl.Color{20, 24, 40, 255})
	rl.DrawTriangleLines(left, right, bottom, rl.Color{20, 24, 40, 255})
}

draw_starburst_icon :: proc(cx, cy, size: i32) {
	r := f32(size) * 0.46
	for i in 0 ..< 8 {
		ang  := f32(i) * (f32(math.TAU) / 8)
		tip  := rl.Vector2{f32(cx) + math.cos(ang) * r, f32(cy) + math.sin(ang) * r}
		spread : f32 = f32(math.TAU) / 22
		base1 := rl.Vector2{f32(cx) + math.cos(ang+spread) * r * 0.32, f32(cy) + math.sin(ang+spread) * r * 0.32}
		base2 := rl.Vector2{f32(cx) + math.cos(ang-spread) * r * 0.32, f32(cy) + math.sin(ang-spread) * r * 0.32}
		col := rl.Color{255, 215, 110, 255} if i % 2 == 0 else rl.Color{255, 245, 215, 255}
		rl.DrawTriangle(base1, tip, base2, col)
	}
	rl.DrawCircle(cx, cy, r * 0.3, rl.Color{255, 250, 220, 255})
	rl.DrawCircleLines(cx, cy, r * 0.3, rl.Color{200, 150, 60, 255})
}

draw_item_icon :: proc(item: ^ItemDef, cx, cy, size: i32) {
	full_restore := item.heal_hp >= 900 && item.restore_souls >= 900
	has_hp   := item.heal_hp > 0
	has_soul := item.restore_souls > 0

	switch {
	case full_restore:
		draw_starburst_icon(cx, cy, size)
	case has_hp && has_soul:
		draw_vial_icon(cx, cy, size, rl.Color{220, 80, 95, 255})
		rl.DrawCircle(cx, cy + i32(f32(size)*0.12), f32(size)*0.15, rl.Color{90, 165, 255, 235})
		rl.DrawCircleLines(cx, cy + i32(f32(size)*0.12), f32(size)*0.15, rl.Color{30, 60, 110, 255})
	case has_soul:
		draw_shard_icon(cx, cy, size, COL_SOUL)
	case:
		draw_vial_icon(cx, cy, size, rl.Color{220, 70, 80, 255})
	}
}

draw_item_menu :: proc(x, y, w, h: i32) {
	rl.DrawRectangle(x, y, w, h, COL_PANEL)
	rl.DrawRectangleLines(x, y, w, h, COL_BORDER)

	row_h: i32 = 28
	slot := 0
	yy := y + 10
	for id := 1; id <= MAX_ITEM_TYPES; id += 1 {
		qty := g_battle.item_qty[id - 1]
		if qty <= 0 do continue
		item := get_item_def(id)
		if item == nil do continue

		selected := g_battle.item_cursor == slot
		if selected {
			rl.DrawRectangle(x + 6, yy - 2, w - 12, row_h, COL_PANEL_2)
		}
		col := COL_TEXT if selected else COL_DIM
		draw_item_icon(item, x + 34, yy + row_h/2 - 2, 26)
		draw_text_at(fmt.tprintf("%s  x%d", item.name, qty), x + 56, yy, 18, col)
		draw_text_at(item.description, x + w/2, yy + 2, 13, COL_DIM)
		slot += 1
		yy += row_h
	}
	if slot == 0 {
		draw_text_at("Bag is empty.", x + 16, y + 14, 18, COL_DIM)
	}
	draw_text_at("Z/Enter use   X/Esc back", x + 12, y + h - 20, 14, COL_DIM)
}

draw_message_prompt :: proc(x, y, w, h: i32) {
	rl.DrawRectangle(x, y, w, h, COL_PANEL)
	rl.DrawRectangleLines(x, y, w, h, COL_BORDER)
	draw_text_at("Press Z / Enter to continue...", x + w - 280, y + h - 20, 14, COL_DIM)
}

draw_result_screen :: proc(title: string, subtitle: string, color: rl.Color) {
	rl.DrawRectangle(0, 0, SCREEN_W, SCREEN_H, rl.Color{0, 0, 0, 180})
	tw := rl.MeasureText(_cs(title), 52)
	draw_text_at(title, (SCREEN_W - tw)/2, SCREEN_H/2 - 60, 52, color)
	sw := rl.MeasureText(_cs(subtitle), 20)
	draw_text_at(subtitle, (SCREEN_W - sw)/2, SCREEN_H/2 + 10, 20, COL_TEXT)

	// XP earned
	xp_str := fmt.tprintf("+%d XP", g_battle.xp_earned)
	xw := rl.MeasureText(_cs(xp_str), 22)
	draw_text_at(xp_str, (SCREEN_W - xw)/2, SCREEN_H/2 + 40, 22, rl.Color{100, 255, 130, 255})

	hint := "Press Z / Enter to continue"
	hw := rl.MeasureText(_cs(hint), 16)
	draw_text_at(hint, (SCREEN_W - hw)/2, SCREEN_H/2 + 76, 16, COL_DIM)
}

draw_bind_flash :: proc() {
	if g_battle.bind_flash <= 0 do return
	alpha := u8(min(255, int(g_battle.bind_flash * 200.0)))
	rl.DrawRectangle(0, 0, SCREEN_W, SCREEN_H, rl.Color{80, 230, 140, alpha / 3})

	t := fmt.tprintf("SPIRIT BOUND!")
	tw := rl.MeasureText(_cs(t), 52)
	draw_text_at(t, (SCREEN_W - tw)/2, SCREEN_H/2 - 30, 52, rl.Color{80, 230, 140, alpha})
}

draw_battle :: proc() {
	// Field background — big sky/floor split
	rl.DrawRectangle(0, 0, SCREEN_W, 380, rl.Color{22, 16, 36, 255})
	// Ground gradient
	rl.DrawRectangle(0, 300, SCREEN_W, 80, rl.Color{40, 30, 60, 255})
	rl.DrawRectangle(0, 296, SCREEN_W, 6, rl.Color{80, 60, 100, 255})

	// Elemental tint in background (reflect the enemy's nature)
	tcol := type_color(g_battle.enemy.mon_type)
	rl.DrawRectangle(0, 0, SCREEN_W, 300, rl.Color{tcol.r/5, tcol.g/5, tcol.b/5, 255})

	// Enemy (top-right area) — bigger sprite
	draw_monster_sprite(&g_battle.enemy, 860, 170, 240)
	draw_monster_panel(&g_battle.enemy, 20, 20, 440)

	// Bind indicator on enemy
	if g_battle.can_bind && !g_battle.already_bound {
		t := f32(rl.GetTime())
		flash := u8(180 + int(math.sin(t * 6.0) * 70.0))
		rl.DrawCircle(860, 80, 20, rl.Color{80, 230, 140, flash})
		bw := rl.MeasureText("BIND!", 16)
		draw_text_at("BIND!", 860 - bw/2, 68, 16, rl.Color{30, 30, 30, 255})
	}

	// Active fighter (bottom-left) — spirit companion or Taz himself
	if g_battle.active_is_spirit {
		draw_monster_sprite(&g_battle.spirit_fighter, 280, 280, 160)
		draw_monster_panel(&g_battle.spirit_fighter, 560, 300, 440)
		// Small Taz standing behind his spirit
		draw_taz_world(60, 310, 1, 0)
		draw_text_at("TAZ", 44, 340, 12, COL_DIM)
	} else {
		draw_battle_taz(280, 280)
		draw_monster_panel(&g_battle.player, 560, 300, 440)
	}

	// HP warning glow on player
	if g_battle.player.hp * 4 < g_battle.player.hp_max {
		t := f32(rl.GetTime())
		pulse := u8(80 + int(math.sin(t * 5.0) * 60.0))
		rl.DrawRectangle(0, 290, SCREEN_W, 10, rl.Color{200, 40, 40, pulse})
	}

	// Bottom UI panel
	panel_y: i32 = 386
	log_h: i32 = 64
	draw_log_box(10, panel_y, SCREEN_W - 20, log_h)

	action_y := panel_y + log_h + 8
	action_h := SCREEN_H - action_y - 10

	switch g_battle.phase {
	case .Choose_Action:
		draw_action_menu(10, action_y, SCREEN_W - 20, action_h)
	case .Choose_Move:
		draw_move_menu(10, action_y, SCREEN_W - 20, action_h)
	case .Choose_Item:
		draw_item_menu(10, action_y, SCREEN_W - 20, action_h)
	case .Choose_Spirit:
		draw_spirit_menu(10, action_y, SCREEN_W - 20, action_h)
	case .Show_Message, .Enemy_Turn, .Bind_Attempt:
		draw_message_prompt(10, action_y, SCREEN_W - 20, action_h)
	case .Bind_Success:
		draw_message_prompt(10, action_y, SCREEN_W - 20, action_h)
		draw_bind_flash()
	case .Victory:
		draw_action_menu(10, action_y, SCREEN_W - 20, action_h)
		drop_line := ""
		if g_battle.item_drop_id > 0 {
			idef := get_item_def(g_battle.item_drop_id)
			if idef != nil do drop_line = fmt.tprintf("  Dropped: %s!", idef.name)
		}
		draw_result_screen("VICTORY!",
			fmt.tprintf("%s defeated!%s", g_battle.enemy.name, drop_line),
			rl.Color{255, 215, 90, 255})
	case .Defeat:
		draw_action_menu(10, action_y, SCREEN_W - 20, action_h)
		draw_result_screen("DEFEATED...", fmt.tprintf("%s has fainted!", g_battle.player.name), rl.Color{220, 80, 90, 255})
		draw_text_at("You'll be returned to the Oracle Shrine.", SCREEN_W/2 - 190, SCREEN_H/2 + 100, 16, COL_DIM)
	case .Fled:
		draw_action_menu(10, action_y, SCREEN_W - 20, action_h)
		draw_result_screen("GOT AWAY", "You fled the encounter.", rl.Color{160, 200, 255, 255})
	}

	// Bind flash overlay (always drawn on top)
	draw_bind_flash()

	// HUD — level, spirit count, active spirit indicator
	spirit_tag := ""
	if g_battle.active_is_spirit {
		spirit_tag = fmt.tprintf("  ◆ %s", g_battle.spirit_fighter.name)
	}
	hud := fmt.tprintf("Taz Lv%d  |  %d spirits%s", g_prog.level, g_prog.bound_count, spirit_tag)
	hw := rl.MeasureText(_cs(hud), 15)
	rl.DrawRectangle(SCREEN_W - hw - 20, 0, hw + 20, 24, rl.Color{0, 0, 0, 120})
	draw_text_at(hud, SCREEN_W - hw - 8, 4, 15, COL_DIM)
}

// Programmer-art Taz in battle (larger, facing right toward enemy)
draw_battle_taz :: proc(cx, cy: i32) {
	scale := f32(1.0) + f32(g_prog.level - 1) * 0.04
	bw := i32(f32(24) * scale)
	bh := i32(f32(40) * scale)
	hw := i32(f32(28) * scale)

	// Legs
	rl.DrawRectangle(cx - bw/2, cy + bh/2, bw/3, i32(f32(16)*scale), rl.Color{40, 80, 160, 255})
	rl.DrawRectangle(cx + bw/6, cy + bh/2, bw/3, i32(f32(16)*scale), rl.Color{40, 80, 160, 255})

	// Body
	rl.DrawRectangle(cx - bw/2, cy - bh/2, bw, bh, rl.Color{60, 120, 200, 255})

	// Arm reaching toward enemy
	rl.DrawRectangle(cx + bw/2, cy - bh/4, i32(f32(20)*scale), bw/2, rl.Color{230, 200, 170, 255})

	// Head
	rl.DrawCircle(cx, cy - bh/2 - hw/2, f32(hw), rl.Color{230, 200, 170, 255})

	// Hair (spiky)
	rl.DrawTriangle(
		rl.Vector2{f32(cx - hw), f32(cy - bh/2 - hw)},
		rl.Vector2{f32(cx), f32(cy - bh/2 - hw*2)},
		rl.Vector2{f32(cx - hw/2), f32(cy - bh/2 - hw/2)},
		rl.Color{30, 30, 30, 255},
	)
	rl.DrawTriangle(
		rl.Vector2{f32(cx - hw/4), f32(cy - bh/2 - hw*2)},
		rl.Vector2{f32(cx + hw/4), f32(cy - bh/2 - hw*2)},
		rl.Vector2{f32(cx), f32(cy - bh/2 - hw*2 - hw/2)},
		rl.Color{30, 30, 30, 255},
	)
	rl.DrawTriangle(
		rl.Vector2{f32(cx + hw/2), f32(cy - bh/2 - hw/2)},
		rl.Vector2{f32(cx), f32(cy - bh/2 - hw*2)},
		rl.Vector2{f32(cx + hw), f32(cy - bh/2 - hw)},
		rl.Color{30, 30, 30, 255},
	)

	// Eyes (looking right)
	rl.DrawCircle(cx + hw/4, cy - bh/2 - hw/2 - 2, f32(i32(f32(4)*scale)), rl.Color{30, 30, 30, 255})
	rl.DrawCircle(cx + hw/4 + i32(f32(9)*scale), cy - bh/2 - hw/2 - 2, f32(i32(f32(4)*scale)), rl.Color{30, 30, 30, 255})

	// Soul aura (scales with level)
	aura_r := i32(f32(40 + g_prog.level * 3) * scale)
	t := f32(rl.GetTime())
	aura_a := u8(30 + int(math.sin(t*2.0)*15.0))
	rl.DrawCircle(cx, cy, f32(aura_r), rl.Color{100, 140, 255, aura_a})
}
