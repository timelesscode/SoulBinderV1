package sb

import rl "vendor:raylib"
import "core:fmt"
import "core:math"

PANEL_COLOR  :: rl.Color{20,  20,  35,  240}
ACCENT_COLOR :: rl.Color{80,  180, 255, 255}
TEXT_COLOR   :: rl.Color{220, 220, 220, 255}
WARN_COLOR   :: rl.Color{255, 80,  80,  255}
GOLD_COLOR   :: rl.Color{255, 200, 60,  255}
BIND_COLOR   :: rl.Color{180, 80,  255, 255}
DARK_BG      :: rl.Color{12,  12,  22,  255}
TALK_COLOR   :: rl.Color{80,  220, 180, 255}
WEAK_COLOR   :: rl.Color{255, 255, 60,  255}

// dynamic screen helpers
sw :: proc() -> i32 { return rl.GetScreenWidth()  }
sh :: proc() -> i32 { return rl.GetScreenHeight() }
swf :: proc() -> f32 { return f32(rl.GetScreenWidth())  }
shf :: proc() -> f32 { return f32(rl.GetScreenHeight()) }

// package-level assets
bg_rooms:      [3]rl.Texture2D
bg_explore:    rl.Texture2D
player_idle:   rl.Texture2D
player_atk:    rl.Texture2D
enemy_sheet:   rl.Texture2D
assets_loaded: bool

music_overworld: rl.Music
music_combat:    rl.Music
active_music:    ^rl.Music

load_assets :: proc() {
	bg_rooms[0]  = rl.LoadTexture("art/room1.jpg")
	bg_rooms[1]  = rl.LoadTexture("art/room2.jpg")
	bg_rooms[2]  = rl.LoadTexture("art/room3.jpg")
	bg_explore   = rl.LoadTexture("art/city_bg.jpg")
	player_idle  = rl.LoadTexture("art/player_Idle 48x48.png")
	player_atk   = rl.LoadTexture("art/player_katana run 48x48.png")
	enemy_sheet  = rl.LoadTexture("art/enemy_spritesheet.png")

	music_overworld = rl.LoadMusicStream("Medieval Traveler's Journey _ Medieval Music for Relaxation & Adventure [o4UC3UUvXBw].mp3")
	music_combat    = rl.LoadMusicStream("Dragon Ball Z - Sound Effects - Download!.mp3")
	music_overworld.looping = true
	music_combat.looping    = true

	assets_loaded = true
}

unload_assets :: proc() {
	if !assets_loaded do return
	for i in 0..<3 do rl.UnloadTexture(bg_rooms[i])
	rl.UnloadTexture(bg_explore)
	rl.UnloadTexture(player_idle)
	rl.UnloadTexture(player_atk)
	rl.UnloadTexture(enemy_sheet)
	rl.UnloadMusicStream(music_overworld)
	rl.UnloadMusicStream(music_combat)
}

play_music :: proc(m: ^rl.Music) {
	if active_music == m do return
	if active_music != nil do rl.StopMusicStream(active_music^)
	active_music = m
	rl.PlayMusicStream(active_music^)
}

tick_music :: proc() {
	if active_music != nil do rl.UpdateMusicStream(active_music^)
}

// ---- draw helpers ----

cstr :: proc(s: string) -> cstring {
	buf := make([]byte, len(s)+1, context.temp_allocator)
	copy(buf, s)
	buf[len(s)] = 0
	return cstring(raw_data(buf))
}

draw_panel :: proc(x, y, w, h: i32, col: rl.Color) {
	rl.DrawRectangle(x, y, w, h, col)
	rl.DrawRectangleLines(x, y, w, h, ACCENT_COLOR)
}

draw_text :: proc(text: string, x, y: i32, size: i32, col: rl.Color) {
	rl.DrawText(cstr(text), x, y, size, col)
}

draw_bar :: proc(x, y, w, h: i32, val, maxval: int, fill_col: rl.Color) {
	rl.DrawRectangle(x, y, w, h, {40, 40, 40, 255})
	if maxval > 0 {
		filled := i32(val) * w / i32(maxval)
		if filled > w do filled = w
		if filled < 0 do filled = 0
		rl.DrawRectangle(x, y, filled, h, fill_col)
	}
	rl.DrawRectangleLines(x, y, w, h, ACCENT_COLOR)
}

draw_bg :: proc(tex: rl.Texture2D, tint: rl.Color) {
	if tex.id > 0 {
		rl.DrawTexturePro(
			tex,
			{0, 0, f32(tex.width), f32(tex.height)},
			{0, 0, swf(), shf()},
			{0, 0}, 0, tint)
	} else {
		rl.ClearBackground(DARK_BG)
	}
}

draw_sprite_frame :: proc(tex: rl.Texture2D, frame_w, frame_h: i32, frame_idx: int,
                          dst_x, dst_y, dst_w, dst_h: f32, flip: bool) {
	if tex.id == 0 do return
	cols := tex.width / frame_w
	col  := i32(frame_idx) % cols
	row  := i32(frame_idx) / cols
	src  := rl.Rectangle{f32(col * frame_w), f32(row * frame_h), f32(frame_w), f32(frame_h)}
	if flip do src.width = -src.width
	rl.DrawTexturePro(tex, src, {dst_x, dst_y, dst_w, dst_h}, {0, 0}, 0, rl.WHITE)
}

draw_alignment_chip :: proc(g: ^GameState, x, y: i32) {
	col := alignment_color(g.summoner.alignment)
	rl.DrawRectangle(x, y, 110, 24, {col[0]/4, col[1]/4, col[2]/4, 200})
	rl.DrawRectangleLines(x, y, 110, 24, {col[0], col[1], col[2], col[3]})
	label := fmt.tprintf("%-7s %+d", alignment_name(g.summoner.alignment), g.summoner.alignment_pts)
	draw_text(label, x+4, y+4, 16, {col[0], col[1], col[2], col[3]})
}

// ---- title screen ----

draw_title :: proc() {
	rl.ClearBackground(DARK_BG)
	rl.DrawRectangleGradientV(0, 0, sw(), sh(), {5, 5, 20, 255}, {30, 10, 60, 255})
	cx := sw() / 2
	draw_text("SOULBINDER",            cx - 200, 160, 80, ACCENT_COLOR)
	draw_text("v0.2 Demo",             cx - 60,  255, 28, TEXT_COLOR)
	draw_text("Press ENTER to begin",  cx - 160, 360, 26, GOLD_COLOR)
	draw_text("Bind spirits. Negotiate. Fuse. Become the vessel.",
	                                   cx - 310, 410, 22, {150, 150, 180, 255})
	draw_text("SMT-style negotiation + Pokemon-style evolution",
	                                   cx - 290, 445, 20, {120, 120, 160, 255})
	draw_text("[WASD/Arrows] Move  [E] Encounter  [F] Fuse  [B] Bind  [T] Talk",
	                                   cx - 310, 490, 18, {90, 90, 120, 255})
	draw_text("[Gamepad: A=Confirm  B=Back  X=Talk  Y=Bind  D-Pad=Navigate]",
	                                   cx - 330, 515, 18, {90, 90, 120, 255})
}

// ---- overworld screen ----

elem_color_ow :: proc(t: SpiritType) -> rl.Color {
	c := spirit_type_color(t)
	return {c[0], c[1], c[2], c[3]}
}

draw_spirit_glyph :: proc(cx, cy, size: i32, t: SpiritType, pulse: f32) {
	ec  := elem_color_ow(t)
	p   := math.sin(pulse)*0.5 + 0.5
	r   := f32(size / 2)
	dim := rl.Color{ec.r, ec.g, ec.b, 80}

	rl.DrawCircleLines(cx, cy, r + 3 + f32(int(p*4)), dim)
	rl.DrawCircleLines(cx, cy, r, ec)

	switch t {
	case .Fire:
		for i in 0..<6 {
			a := f32(i)*60*rl.DEG2RAD + pulse*0.5
			rl.DrawLineEx(
				{f32(cx)+math.cos(a)*r*0.3, f32(cy)+math.sin(a)*r*0.3},
				{f32(cx)+math.cos(a)*r*0.9, f32(cy)+math.sin(a)*r*0.9},
				2, ec)
		}
		rl.DrawCircle(cx, cy, r*0.2, ec)
	case .Ice, .Water:
		rl.DrawCircleLines(cx, cy, r*0.5, ec)
		rl.DrawCircleLines(cx, cy, r*0.3, ec)
	case .Earth:
		rl.DrawRectangleLinesEx({f32(cx)-r/2, f32(cy)-r/2, r, r}, 2, ec)
	case .Wind:
		for i in 0..<8 {
			a  := f32(i)*45*rl.DEG2RAD + pulse
			a2 := a + 0.5
			rl.DrawLineEx(
				{f32(cx)+math.cos(a)*r*0.2,  f32(cy)+math.sin(a)*r*0.2},
				{f32(cx)+math.cos(a2)*r*0.8, f32(cy)+math.sin(a2)*r*0.8},
				1.5, ec)
		}
	case .Dark, .Alien:
		for i in 0..<5 {
			a  := f32(i)*72*rl.DEG2RAD - 90*rl.DEG2RAD + pulse*0.3
			a2 := f32(i+2)*72*rl.DEG2RAD - 90*rl.DEG2RAD + pulse*0.3
			rl.DrawLineEx(
				{f32(cx)+math.cos(a)*r*0.8,  f32(cy)+math.sin(a)*r*0.8},
				{f32(cx)+math.cos(a2)*r*0.8, f32(cy)+math.sin(a2)*r*0.8},
				2, ec)
		}
	case .Light:
		rl.DrawLineEx({f32(cx), f32(cy) - r*0.8}, {f32(cx), f32(cy) + r*0.8}, 2, ec)
		rl.DrawLineEx({f32(cx) - r*0.8, f32(cy)}, {f32(cx) + r*0.8, f32(cy)}, 2, ec)
		rl.DrawCircleLines(cx, cy, r*0.4, ec)
	case .Nature:
		for i in -1..=1 {
			rl.DrawLineEx(
				{f32(cx + i32(i)*10) - r*0.4, f32(cy) - r*0.7},
				{f32(cx + i32(i)*10) + r*0.4, f32(cy) + r*0.7},
				2, ec)
		}
	}
}

draw_player_sprite_ow :: proc(px, py, frame: i32) {
	col    := rl.Color{255, 220, 100, 255}
	staff  := rl.Color{180, 160, 80, 255}
	orb    := rl.Color{200, 80, 255, 255}
	rl.DrawRectangle(px-5, py-14, 10, 14, col)
	rl.DrawCircle(px, py-18, 6, col)
	rl.DrawLineEx({f32(px-8), f32(py-24)}, {f32(px-8), f32(py+2)}, 2, staff)
	rl.DrawCircle(px-8, py-26, 4, orb)
	if frame == 0 {
		rl.DrawRectangle(px-5, py,   4, 8, col)
		rl.DrawRectangle(px+1, py,   4, 8, col)
	} else {
		rl.DrawRectangle(px-5, py,   4, 10, col)
		rl.DrawRectangle(px+1, py-2, 4, 10, col)
	}
}

draw_overworld :: proc(g: ^GameState) {
	COL_GRASS  :: rl.Color{20,  50, 25, 255}
	COL_TREE   :: rl.Color{15,  35, 18, 255}
	COL_PATH   :: rl.Color{70,  60, 45, 255}
	COL_WATER  :: rl.Color{20,  50,100, 255}
	COL_RUIN   :: rl.Color{55,  45, 70, 255}
	COL_SPECIAL:: rl.Color{200,150,255, 255}
	COL_BG_OW  :: rl.Color{12,   8, 20, 255}

	rl.ClearBackground(COL_BG_OW)

	area := g.current_area
	pulse := f32(f32(rl.GetTime()))

	for ty in 0..<MAP_H {
		for tx in 0..<MAP_W {
			t  := AREA_MAPS[area][ty][tx]
			sx := i32(tx*TILE_SZ) - i32(g.cam_x)
			sy := i32(ty*TILE_SZ) - i32(g.cam_y)
			if sx > sw() || sy > sh() || sx+TILE_SZ < 0 || sy+TILE_SZ < 0 do continue

			col: rl.Color
			switch t {
			case 0: col = (area == .Ruins) ? COL_RUIN : COL_GRASS
			case 1: col = (area == .Ruins) ? rl.Color{40,30,55,255} : COL_TREE
			case 2: col = COL_PATH
			case 3: col = COL_WATER
			case 4: col = COL_SPECIAL
			case:   col = COL_BG_OW
			}
			rl.DrawRectangle(sx, sy, TILE_SZ, TILE_SZ, col)
			rl.DrawRectangleLinesEx({f32(sx), f32(sy), TILE_SZ, TILE_SZ}, 1, {0,0,0,40})

			if t == 4 {
				glow := f32(math.abs(math.sin(pulse*2)))
				rl.DrawRectangle(sx, sy, TILE_SZ, TILE_SZ,
					{COL_SPECIAL.r, COL_SPECIAL.g, COL_SPECIAL.b, u8(glow*80)})
				if g.boss_defeated[area] {
					rl.DrawText("+", sx+TILE_SZ/2-4, sy+TILE_SZ/2-6, 12, {255,240,100,255})
				}
			}
		}
	}

	// player
	px := i32(g.player_tx*TILE_SZ) - i32(g.cam_x) + TILE_SZ/2
	py := i32(g.player_ty*TILE_SZ) - i32(g.cam_y) + TILE_SZ - 6
	draw_player_sprite_ow(px, py, i32(g.anim_frame))

	// active spirits as small glyphs around player (up to 3 visible)
	count := 0
	for i in 0..<6 {
		s := g.summoner.spirits[i]
		if s == nil || !s.active do continue
		if count >= 3 do break
		ox := i32(count-1) * 28
		draw_spirit_glyph(px+ox, py-40, 18, s.element, f32(pulse)+f32(count))
		count += 1
	}

	// HUD — top left
	draw_panel(4, 4, 240, 58, PANEL_COLOR)
	draw_text(AREA_NAMES[area], 12, 8, 10, {120, 100, 160, 255})
	draw_text("HP", 12, 22, 10, TEXT_COLOR)
	draw_bar(32, 22, 150, 10, g.summoner.hp, g.summoner.max_hp, {80, 220, 120, 255})
	draw_text(fmt.tprintf("%d/%d", g.summoner.hp, g.summoner.max_hp), 188, 22, 9, {120,100,160,255})
	draw_text(fmt.tprintf("Lv.%d  Gold:%d  Spirits:%d/6",
		g.summoner.level, g.summoner.gold, filled_slots(g)), 12, 38, 9, {120,100,160,255})

	// area boss status — top right
	for area_i in Area {
		i := int(area_i)
		if g.boss_defeated[area_i] {
			names := [Area]string{.Village="Specter", .Forest="Thornlord", .Ruins="Revenant"}
			draw_text(fmt.tprintf("[%s SEALED]", names[area_i]),
				sw()-140, i32(sh()-18-i32(i)*13), 8, ACCENT_COLOR)
		}
	}

	// message bar
	if g.overworld_msg != "" {
		tw := rl.MeasureText(cstr(g.overworld_msg), 14)
		bw := tw + 24
		bx := (sw() - bw) / 2
		draw_panel(bx, sh()-50, bw, 36, PANEL_COLOR)
		draw_text(g.overworld_msg, bx+12, sh()-42, 14, TEXT_COLOR)
	}

	// controls hint
	draw_text("[WASD/Arrows] Move   [F] Fuse spirits", 4, sh()-14, 9, {80,70,110,255})
}

// ---- combat enemy creature ----

draw_combat_enemy :: proc(cx, cy: i32, g: ^GameState) {
	t    := g.enemy.spirit_template.element
	ec   := elem_color_ow(t)
	dim  := rl.Color{ec.r/3, ec.g/3, ec.b/3, 180}
	pulse := f32(rl.GetTime())
	hp_pct := f32(g.enemy.hp) / f32(g.enemy.max_hp)

	// hit flash — white tint when player just attacked
	base_col := ec
	if g.player_attack_timer > 0.55 {
		flash := u8((g.player_attack_timer - 0.55) / 0.15 * 255)
		base_col = {255, 255, 255, flash}
	}

	// shadow
	rl.DrawEllipse(cx, cy+70, 50, 12, {0,0,0,80})

	switch t {
	case .Fire:
		// flame body: stacked ovals + fire crown
		rl.DrawEllipse(cx, cy+20, 28, 42, dim)
		rl.DrawEllipse(cx, cy+20, 24, 38, base_col)
		for i in 0..<5 {
			a := f32(i)*72*rl.DEG2RAD + pulse*2
			fx := cx + i32(math.cos(a)*20)
			fy := cy - 20 + i32(math.sin(a)*10)
			rl.DrawCircle(fx, fy, 7+math.sin(pulse*3+f32(i))*3, {255,180,40,200})
		}
		rl.DrawCircle(cx-10, cy+10, 6, {20,20,20,255}) // left eye
		rl.DrawCircle(cx+10, cy+10, 6, {20,20,20,255}) // right eye
		rl.DrawCircle(cx-10, cy+10, 3, {255,80,0,255})
		rl.DrawCircle(cx+10, cy+10, 3, {255,80,0,255})

	case .Ice, .Water:
		// crystalline body
		rl.DrawPoly({f32(cx), f32(cy)}, 6, 50, pulse*10, dim)
		rl.DrawPoly({f32(cx), f32(cy)}, 6, 44, pulse*10, base_col)
		rl.DrawPolyLines({f32(cx), f32(cy)}, 6, 52, pulse*10, {255,255,255,120})
		// inner crystal shards
		for i in 0..<3 {
			a := f32(i)*120*rl.DEG2RAD + pulse*0.5
			rl.DrawLineEx(
				{f32(cx), f32(cy)},
				{f32(cx)+math.cos(a)*40, f32(cy)+math.sin(a)*40},
				3, {255,255,255,180})
		}
		rl.DrawCircle(cx, cy, 10, {220,240,255,255}) // core

	case .Earth, .Nature:
		// rocky turtle-like body
		rl.DrawEllipse(cx, cy+10, 45, 35, dim)
		rl.DrawEllipse(cx, cy+10, 40, 30, base_col)
		// shell plates
		for i in 0..<6 {
			a := f32(i)*60*rl.DEG2RAD
			px2 := cx + i32(math.cos(a)*22)
			py2 := cy+10 + i32(math.sin(a)*14)
			rl.DrawCircle(px2, py2, 8, dim)
			rl.DrawCircleLines(px2, py2, 8, {255,255,255,60})
		}
		// head
		rl.DrawCircle(cx, cy-32, 18, base_col)
		rl.DrawCircle(cx-6, cy-36, 4, {20,20,20,255})
		rl.DrawCircle(cx+6, cy-36, 4, {20,20,20,255})
		// arms
		rl.DrawEllipse(cx-52, cy+5, 12, 8, base_col)
		rl.DrawEllipse(cx+52, cy+5, 12, 8, base_col)

	case .Wind:
		// wispy serpent
		for i in 0..<8 {
			fi := f32(i)
			sx := cx + i32(math.sin(pulse+fi*0.8)*30)
			sy := cy - 40 + i32(fi*14)
			r  := f32(18 - i)
			if r < 4 do r = 4
			rl.DrawCircle(sx, sy, r, {base_col.r, base_col.g, base_col.b, u8(200 - i*20)})
		}
		// eyes on head segment
		rl.DrawCircle(cx + i32(math.sin(pulse)*30) - 6, cy-38, 4, {20,20,20,255})
		rl.DrawCircle(cx + i32(math.sin(pulse)*30) + 6, cy-38, 4, {20,20,20,255})

	case .Dark, .Alien:
		// shadowy wraith
		rl.DrawCircle(cx, cy-10, 40, dim)
		// tentacles
		for i in 0..<6 {
			a  := f32(i)*60*rl.DEG2RAD + pulse*0.4
			tx2 := cx + i32(math.cos(a)*(50+math.sin(pulse*2+f32(i))*15))
			ty2 := cy+30 + i32(math.sin(a)*(30+math.cos(pulse*2+f32(i))*10))
			rl.DrawLineEx({f32(cx), f32(cy+10)}, {f32(tx2), f32(ty2)}, 4, base_col)
			rl.DrawCircle(tx2, ty2, 6, base_col)
		}
		// glowing eyes
		rl.DrawCircle(cx-14, cy-16, 8, {255,255,255,220})
		rl.DrawCircle(cx+14, cy-16, 8, {255,255,255,220})
		rl.DrawCircle(cx-14, cy-16, 4, base_col)
		rl.DrawCircle(cx+14, cy-16, 4, base_col)

	case .Light:
		// angelic form — robes + halo
		rl.DrawEllipse(cx, cy+20, 26, 44, dim)
		rl.DrawEllipse(cx, cy+20, 22, 40, base_col)
		// halo
		rl.DrawRing({f32(cx), f32(cy-48)}, 22, 28, 0, 360, 32, {ec.r, ec.g, ec.b, 180})
		// wings
		rl.DrawEllipse(cx-50, cy, 28, 16, {base_col.r, base_col.g, base_col.b, 160})
		rl.DrawEllipse(cx+50, cy, 28, 16, {base_col.r, base_col.g, base_col.b, 160})
		// face
		rl.DrawCircle(cx, cy-14, 16, base_col)
		rl.DrawCircle(cx-5, cy-17, 3, {20,20,20,255})
		rl.DrawCircle(cx+5, cy-17, 3, {20,20,20,255})
	}

	// HP bar under creature
	bar_w := i32(120)
	bar_x := cx - bar_w/2
	bar_y := cy + 80
	rl.DrawRectangle(bar_x, bar_y, bar_w, 8, {40,40,40,200})
	fill_col := rl.Color{80,220,80,255}
	if hp_pct < 0.5 do fill_col = {220,180,40,255}
	if hp_pct < 0.25 do fill_col = {220,60,60,255}
	rl.DrawRectangle(bar_x, bar_y, i32(f32(bar_w)*hp_pct), 8, fill_col)
	rl.DrawRectangleLines(bar_x, bar_y, bar_w, 8, ec)

	// name tag
	name_cs := cstr(g.enemy.name)
	tw := rl.MeasureText(name_cs, 14)
	rl.DrawText(name_cs, cx - tw/2, bar_y + 12, 14, ec)
}

// ---- combat screen ----

draw_combat :: proc(g: ^GameState) {
	// background
	bg_idx := g.run_step % 3
	draw_bg(bg_rooms[bg_idx], {160, 160, 180, 255})
	rl.DrawRectangle(0, 0, sw(), sh(), {8, 8, 20, 170})

	pulse := f32(rl.GetTime())
	bob   := math.sin(pulse*2) * 6

	// player sprite — idle or attack animation
	py_sprite := f32(sh()) - 240
	if g.player_attack_timer > 0 {
		atk_frames := 8
		t          := 0.7 - g.player_attack_timer          // elapsed
		frame      := int(t / 0.7 * f32(atk_frames)) % atk_frames
		draw_sprite_frame(player_atk, 48, 48, frame, 60, py_sprite, 144, 144, false)
	} else {
		draw_sprite_frame(player_idle, 48, 48, g.combat_idle_frame, 60, py_sprite, 144, 144, false)
	}

	// enemy — always programmer art creature
	ecx := sw() - 240
	ecy := i32(f32(sh())/2 - 80 + bob)
	draw_combat_enemy(ecx, ecy, g)

	// enemy panel
	draw_panel(20, 20, 580, 150, PANEL_COLOR)
	col4 := spirit_type_color(g.enemy.spirit_template.element)
	rl.DrawRectangleLines(20, 20, 580, 150, {col4[0], col4[1], col4[2], col4[3]})
	draw_text(g.enemy.name, 30, 28, 30, WARN_COLOR)
	draw_text(fmt.tprintf("Lv.%d   ATK:%d   DEF:%d   SPD:%d   %v",
		g.enemy.level, g.enemy.atk, g.enemy.def, g.enemy.spd,
		g.enemy.spirit_template.element),
		30, 64, 18, TEXT_COLOR)
	draw_bar(30, 92, 540, 22, g.enemy.hp, g.enemy.max_hp, {220, 60, 60, 255})
	draw_text(fmt.tprintf("HP: %d / %d", g.enemy.hp, g.enemy.max_hp), 30, 120, 18, TEXT_COLOR)
	if g.enemy_enraged {
		draw_text("ENRAGED!", 500, 28, 20, WARN_COLOR)
	}

	// bind / talk badges
	badge_y := i32(20)
	if g.bind_available {
		draw_panel(608, badge_y, 310, 36, {50, 20, 80, 255})
		draw_text("** BIND READY — [B] **", 616, badge_y+8, 20, BIND_COLOR)
		badge_y += 42
	}
	if g.talk_available && !g.negotiate_done {
		draw_panel(608, badge_y, 310, 36, {20, 60, 50, 255})
		draw_text("** TALK OPEN — [T] **", 616, badge_y+8, 20, TALK_COLOR)
		badge_y += 42
	}
	// press-turn bonus flash
	if g.bonus_action && !g.bonus_action_used {
		draw_panel(608, badge_y, 310, 36, {80, 80, 0, 255})
		draw_text("WEAKNESS! EXTRA ACTION!", 616, badge_y+8, 20, WEAK_COLOR)
		badge_y += 42
	}

	// summoner panel
	draw_panel(608, 100, 654, 72, PANEL_COLOR)
	draw_text(fmt.tprintf("Summoner  Lv.%d", g.summoner.level), 618, 106, 22, ACCENT_COLOR)
	draw_bar(618, 130, 620, 20, g.summoner.hp, g.summoner.max_hp, {60, 200, 60, 255})
	draw_text(fmt.tprintf("HP: %d / %d", g.summoner.hp, g.summoner.max_hp), 618, 154, 16, TEXT_COLOR)
	draw_alignment_chip(g, 1118, 106)

	// skill menu
	draw_panel(20, 182, 580, 320, PANEL_COLOR)
	draw_text("SKILLS  (1-6 or arrow+ENTER)", 30, 190, 17, ACCENT_COLOR)
	for i in 0..<6 {
		s  := g.summoner.spirits[i]
		sy := i32(214 + i * 46)
		if s != nil && s.active {
			col := spirit_type_color(s.element)
			bg  := rl.Color{col[0]/6, col[1]/6, col[2]/6, 200}
			brd := rl.Color{col[0], col[1], col[2], col[3]}
			if i == g.selected_skill_idx {
				bg  = {60, 80, 120, 255}
				brd = GOLD_COLOR
			}
			rl.DrawRectangle(28, sy, 562, 42, bg)
			rl.DrawRectangleLines(28, sy, 562, 42, brd)
			cd_str := ""
			if s.cooldown > 0 do cd_str = fmt.tprintf(" [CD:%d]", s.cooldown)
			// show type weakness/resist vs enemy
			aff := g.enemy.spirit_template.affinity[s.element]
			eff := affinity_tag(aff)
			draw_text(fmt.tprintf("%d. %s — %s  (%s)%s%s",
				i+1, s.name, skill_name(s.skill), skill_description(s.skill), cd_str, eff),
				36, sy+6, 15, TEXT_COLOR)
			spd_str := fmt.tprintf("SPD:%d", spirit_spd(s))
			draw_text(spd_str, 548, sy+6, 13, {130, 130, 160, 255})
		} else {
			rl.DrawRectangle(28, sy, 562, 42, {25, 25, 40, 180})
			rl.DrawRectangleLines(28, sy, 562, 42, {50, 50, 70, 255})
			draw_text(fmt.tprintf("%d. [empty slot]", i+1), 36, sy+14, 16, {70, 70, 90, 255})
		}
	}

	// combat log
	draw_panel(608, 182, 654, 320, PANEL_COLOR)
	draw_text("COMBAT LOG", 618, 190, 17, ACCENT_COLOR)
	for line, i in g.combat_log.lines {
		col := TEXT_COLOR
		if i == len(g.combat_log.lines) - 1 do col = {240, 240, 160, 255}
		draw_text(line, 618, i32(214 + i * 40), 14, col)
	}

	// particles & floating numbers
	draw_effects(g)

	// controls bar
	draw_panel(20, sh()-56, sw()-40, 46, PANEL_COLOR)
	draw_text("[1-6] Skill   [B] Bind   [T] Talk   [F] Flee   [↑↓] Navigate   [A/ENTER] Confirm",
		30, sh()-44, 16, TEXT_COLOR)

	// victory / defeat overlay
	if g.combat_over {
		rl.DrawRectangle(0, 0, sw(), sh(), {0, 0, 0, 160})
		cx := sw() / 2
		cy := sh() / 2
		if g.combat_won {
			if g.bind_success {
				draw_text("SPIRIT BOUND!", cx - 160, cy - 50, 54, BIND_COLOR)
			} else {
				draw_text("VICTORY!", cx - 110, cy - 50, 54, GOLD_COLOR)
			}
		} else {
			draw_text("DEFEATED...", cx - 140, cy - 50, 54, WARN_COLOR)
		}
		draw_text("Press ENTER to continue", cx - 170, cy + 30, 26, TEXT_COLOR)
	}
}

// ---- negotiate screen ----

draw_negotiate :: proc(g: ^GameState) {
	rl.ClearBackground(DARK_BG)
	rl.DrawRectangleGradientV(0, 0, sw(), sh(), {10, 30, 30, 255}, {5, 15, 25, 255})

	// header
	draw_panel(200, 80, 880, 70, {20, 50, 45, 255})
	draw_text(fmt.tprintf("NEGOTIATION — %s", g.enemy.name), 220, 88, 28, TALK_COLOR)
	col4 := alignment_color(g.enemy.talk_mood)
	draw_text(fmt.tprintf("Mood: %s", alignment_name(g.enemy.talk_mood)),
		750, 96, 20, {col4[0], col4[1], col4[2], 255})

	// enemy speech bubble
	draw_panel(200, 170, 880, 60, {15, 40, 35, 255})
	draw_text(fmt.tprintf("\"%s\"", enemy_talk_line(g.enemy.talk_mood)), 218, 186, 20, {180, 255, 220, 255})

	if !g.negotiate_done {
		// options
		option_labels := [NegotiateOption]string{
			.Beg       = "Beg  (appeal to mercy — works on Chaos, low-level player)",
			.Flatter   = "Flatter  (appeal to ego — works on Law spirits)",
			.Threaten  = "Threaten  (works if you are Chaos aligned)",
			.Offer_Gold = "---",
		}
		// build gold option dynamically
		gold_cost := 50 * g.enemy.spirit_template.tier

		option_strs := [4]string{
			"Beg  (appeal to mercy — works on Chaos, low-level player)",
			"Flatter  (appeal to ego — works on Law spirits)",
			"Threaten  (works if you are Chaos aligned)",
			fmt.tprintf("Offer Gold  (cost: %d g | you have: %d g)", gold_cost, g.summoner.gold),
		}

		for i in 0..<4 {
			oy := i32(260 + i * 64)
			bg := rl.Color{20, 40, 35, 200}
			brd := TALK_COLOR
			if i == g.negotiate_option {
				bg  = {40, 80, 70, 255}
				brd = GOLD_COLOR
			}
			rl.DrawRectangle(200, oy, 880, 54, bg)
			rl.DrawRectangleLines(200, oy, 880, 54, brd)
			prefix := "  "
			if i == g.negotiate_option do prefix = "> "
			draw_text(fmt.tprintf("%s%d. %s", prefix, i+1, option_strs[i]), 218, oy+16, 20, TEXT_COLOR)
		}

		// controls
		draw_panel(200, 530, 880, 50, PANEL_COLOR)
		draw_text("[1-4] or [↑↓] Select   [ENTER/A] Confirm   [ESC/B] Cancel", 220, 544, 18, TEXT_COLOR)

		// alignment indicator
		draw_panel(200, 596, 880, 46, PANEL_COLOR)
		draw_text(fmt.tprintf("Your alignment: %s (%+d pts)  |  Enemy mood: %s",
			alignment_name(g.summoner.alignment), g.summoner.alignment_pts,
			alignment_name(g.enemy.talk_mood)), 220, 610, 16, TEXT_COLOR)
	} else {
		// result panel
		draw_panel(200, 260, 880, 100, {15, 40, 35, 255})
		result_col := GOLD_COLOR
		if len(g.negotiate_result) > 0 && g.negotiate_result[0] == 'N' do result_col = WARN_COLOR
		draw_text(g.negotiate_result, 220, 290, 22, result_col)

		draw_panel(200, 380, 880, 50, PANEL_COLOR)
		draw_text("Press ENTER to return to combat", 320, 394, 20, TEXT_COLOR)
	}
}

// ---- fuse screen ----

draw_fuse :: proc(g: ^GameState) {
	rl.ClearBackground(DARK_BG)
	draw_panel(0, 0, sw(), 60, PANEL_COLOR)
	draw_text("GLYPH SHRINE — FUSION", 20, 14, 28, ACCENT_COLOR)
	draw_text("Two spirits consumed permanently to forge one stronger.", 310, 20, 17, WARN_COLOR)

	draw_panel(20, 78, 580, 576, PANEL_COLOR)
	draw_text("SOUL SLOTS", 30, 86, 20, ACCENT_COLOR)

	for i in 0..<6 {
		sy       := i32(116 + i * 74)
		s        := g.summoner.spirits[i]
		selected := (i == g.fuse_idx_a || i == g.fuse_idx_b)
		if s != nil {
			col := spirit_type_color(s.element)
			bg  := rl.Color{col[0]/5, col[1]/5, col[2]/5, 200}
			brd := rl.Color{col[0], col[1], col[2], col[3]}
			if selected { bg = {80, 60, 20, 255}; brd = GOLD_COLOR }
			rl.DrawRectangle(30, sy, 560, 66, bg)
			rl.DrawRectangleLines(30, sy, 560, 66, brd)
			label := ""
			if i == g.fuse_idx_a do label = " [A]"
			if i == g.fuse_idx_b do label = " [B]"
			draw_text(fmt.tprintf("[%d]%s %s  T%d  %v  Lv.%d  ATK:%d DEF:%d SPD:%d",
				i+1, label, s.name, s.tier, s.element,
				s.level, spirit_atk(s), spirit_def(s), spirit_spd(s)),
				38, sy+6, 17, TEXT_COLOR)
			draw_text(fmt.tprintf("    %s — %s", skill_name(s.skill), skill_description(s.skill)),
				38, sy+30, 15, {180, 180, 220, 255})
			if s.evo_level > 0 && s.level < s.evo_level {
				draw_text(fmt.tprintf("    [evolves @ Lv.%d → %s]", s.evo_level, s.evo_name),
					38, sy+50, 13, {120, 220, 120, 255})
			}
		} else {
			rl.DrawRectangle(30, sy, 560, 66, {25, 25, 40, 180})
			rl.DrawRectangleLines(30, sy, 560, 66, {50, 50, 70, 255})
			draw_text(fmt.tprintf("[%d] --- empty ---", i+1), 38, sy+24, 18, {70, 70, 90, 255})
		}
	}

	// recipes panel
	draw_panel(618, 78, 644, 420, PANEL_COLOR)
	draw_text("FUSION RECIPES (Tier 1 → Tier 2)", 628, 86, 18, ACCENT_COLOR)
	recipes := [7]string{
		"Pixie + Wisp         → Sylph",
		"Ember Sprite + Frost Moth → Ignis",
		"Vine Sprite + Stone Gnome → Thornwarden",
		"Imp + Screech Bat    → Dusk Shade",
		"Wisp + Vine Sprite   → Undine",
		"Pixie + Ember Sprite → Seraph Fledge",
		"(Vexor: Bind only)",
	}
	for r, i in recipes {
		draw_text(r, 628, i32(114 + i * 38), 16, {180, 220, 255, 255})
	}
	draw_text("EVOLUTION (level-up, single spirit):", 628, 382, 16, {120, 220, 120, 255})
	evos := [4]string{
		"Pixie/Wisp  Lv.5 → Fairy Queen",
		"Imp         Lv.5 → Demon Knight",
		"Ember       Lv.5 → Magma Drake",
		"Stone Gnome Lv.5 → Granite Titan",
	}
	for e, i in evos {
		draw_text(e, 628, i32(400 + i * 22), 14, {150, 210, 150, 255})
	}

	// controls
	draw_panel(618, 516, 644, 138, PANEL_COLOR)
	draw_text("CONTROLS", 628, 524, 17, ACCENT_COLOR)
	draw_text("[A] Select A slot    [B] Select B slot", 628, 548, 16, TEXT_COLOR)
	draw_text("[1-6] Pick slot      [F] Perform Fusion", 628, 570, 16, TEXT_COLOR)
	draw_text("[ESC] Back to explore", 628, 592, 16, TEXT_COLOR)
	if g.fuse_idx_a >= 0 && g.fuse_idx_b >= 0 && g.fuse_idx_a != g.fuse_idx_b {
		sa  := g.summoner.spirits[g.fuse_idx_a]
		sb_ := g.summoner.spirits[g.fuse_idx_b]
		if sa != nil && sb_ != nil {
			draw_text(fmt.tprintf("Fuse: %s + %s", sa.name, sb_.name),
				628, 620, 18, GOLD_COLOR)
		}
	}
}

// ---- game over / victory ----

draw_game_over :: proc(g: ^GameState) {
	rl.ClearBackground(DARK_BG)
	rl.DrawRectangleGradientV(0, 0, sw(), sh(), {40, 5, 5, 255}, {10, 0, 0, 255})
	cx := sw() / 2; cy := sh() / 2
	draw_text("GAME OVER",                  cx - 190, cy - 90, 76, WARN_COLOR)
	draw_text("Your soul has been extinguished.", cx - 240, cy + 10, 28, TEXT_COLOR)
	draw_text(fmt.tprintf("Alignment reached: %s", alignment_name(g.summoner.alignment)),
	                                         cx - 150, cy + 55, 22, {160, 160, 200, 255})
	draw_text("Press ENTER to return to title", cx - 210, cy + 90, 24, {150, 150, 180, 255})
}

draw_victory :: proc(g: ^GameState) {
	rl.ClearBackground(DARK_BG)
	rl.DrawRectangleGradientV(0, 0, sw(), sh(), {30, 0, 60, 255}, {10, 0, 30, 255})
	cx := sw() / 2
	draw_text("ALL REALMS SEALED!",         cx - 260, 140, 72, BIND_COLOR)
	draw_spirit_glyph(cx, 300, 100, .Alien, f32(rl.GetTime()))
	draw_text("The ancient spirits are bound. Peace reigns.", cx - 300, 380, 28, GOLD_COLOR)
	draw_text(fmt.tprintf("Summoner Lv.%d  |  Gold: %d  |  Alignment: %s",
		g.summoner.level, g.summoner.gold, alignment_name(g.summoner.alignment)),
		cx - 260, 430, 24, TEXT_COLOR)
	draw_text("Press ENTER to continue.", cx - 160, 490, 24, TEXT_COLOR)
}
