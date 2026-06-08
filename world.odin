package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

// ── 3D Level Walker ───────────────────────────────────────────────────────
// Each level is a `.glb` scene explored in third person: a billboarded 2D
// sprite (always facing the camera, courtesy of raylib's DrawBillboard*)
// wanders a circular play area in front of a 3D background. Geometry varies
// wildly between the nine scenes, so the camera distance, movement speed,
// and play radius are all derived from each model's bounding box rather
// than hand-tuned per level — load it, measure it, and go.

CAM_LERP        :: 0.10
PLAYER_SPEED    :: 0.55
PROXIMITY_RANGE :: 0.10
WANDER_COUNT    :: 3
WANDER_SPEED    :: 0.12
MAX_WORLD_ITEMS :: 5

WanderNPC :: struct {
	monster_id: int,
	pos:        rl.Vector3,
	target:     rl.Vector3,
}

WorldItem :: struct {
	item_id: int,
	pos:     rl.Vector3,
	active:  bool,
}

World :: struct {
	level_idx:    int,
	model:        rl.Model,
	model_loaded: bool,

	center:      rl.Vector3, // model bounding-box center
	play_radius: f32,        // how far from center the player can roam
	ground_y:    f32,        // y the player/billboards walk at
	cam_offset:  rl.Vector3, // camera position relative to the player (lerp target)

	camera:     rl.Camera3D,
	player_pos: rl.Vector3,
	bob_timer:  f32,

	wanderers:   [WANDER_COUNT]WanderNPC,
	spirit_pos:  rl.Vector3,
	portal_pos:  rl.Vector3,
	world_items: [MAX_WORLD_ITEMS]WorldItem,
	time_in_level: f32, // seconds spent in this level; drives escalating difficulty

	spirit_intro_shown: [len(LEVELS)]bool,
}

g_world: World

// Set once the player has spoken to the Oracle for the first time — the
// Hub uses this to decide whether to play the fusion tutorial dialogue
// or jump straight into the fusion menu.
g_oracle_opened: bool

// HUD message (shows briefly over the level)
HudMsg :: struct {
	text:  string,
	timer: f32,
}
g_hud_msg: HudMsg

set_hud_message :: proc(msg: string) {
	g_hud_msg.text = msg
	g_hud_msg.timer = 3.0
}

// ── Level lifecycle ───────────────────────────────────────────────────────
// Only one level's model is resident at a time — some of these scenes are
// 10+ MB, so we load on entry and unload on exit rather than holding all
// nine in memory for the whole session.

enter_level :: proc(idx: int) {
	if idx < 0 || idx >= len(LEVELS) do return
	if g_world.model_loaded do exit_level()

	level := &LEVELS[idx]
	g_world.level_idx = idx
	g_world.model = rl.LoadModel(_cs(level.glb_path))
	g_world.model_loaded = true

	bbox := rl.GetModelBoundingBox(g_world.model)
	size := bbox.max - bbox.min
	extent := max(size.x, size.z)
	if extent <= 0 do extent = 10

	g_world.center = (bbox.min + bbox.max) * 0.5
	g_world.play_radius = extent * 0.35
	g_world.ground_y = bbox.min.y + size.y * 0.05

	g_world.player_pos = rl.Vector3{g_world.center.x, g_world.ground_y, g_world.center.z}
	g_world.bob_timer = 0

	g_world.cam_offset = rl.Vector3{0, extent * 0.20, extent * 0.32}
	g_world.camera = rl.Camera3D{
		position   = g_world.player_pos + g_world.cam_offset,
		target     = g_world.player_pos,
		up         = {0, 1, 0},
		fovy       = 45,
		projection = .PERSPECTIVE,
	}

	g_world.time_in_level = 0

	for i in 0 ..< WANDER_COUNT {
		g_world.wanderers[i] = WanderNPC{
			monster_id = level.wander_pool[i % len(level.wander_pool)],
			pos        = random_point_in_radius(),
			target     = random_point_in_radius(),
		}
	}

	// Scatter collectible items across the level
	item_pool := []int{1, 1, 1, 2, 2, 3} // Blood Vial most common
	for i in 0 ..< MAX_WORLD_ITEMS {
		g_world.world_items[i] = WorldItem{
			item_id = item_pool[rand.int_max(len(item_pool))],
			pos     = random_point_in_radius(),
			active  = true,
		}
	}

	ang := f32(idx) * 0.9
	g_world.spirit_pos = ground_point(ang, g_world.play_radius * 0.6)
	g_world.portal_pos = ground_point(ang + math.PI, g_world.play_radius * 0.6)
}

exit_level :: proc() {
	if g_world.model_loaded {
		rl.UnloadModel(g_world.model)
		g_world.model_loaded = false
	}
	g_world.level_idx = -1
}

ground_point :: proc(angle, radius: f32) -> rl.Vector3 {
	return rl.Vector3{
		g_world.center.x + math.cos(angle) * radius,
		g_world.ground_y,
		g_world.center.z + math.sin(angle) * radius,
	}
}

random_point_in_radius :: proc() -> rl.Vector3 {
	return ground_point(rand.float32() * math.TAU, rand.float32() * g_world.play_radius)
}

current_level_def :: proc() -> ^LevelDef {
	if !g_world.model_loaded do return nil
	if g_world.level_idx < 0 || g_world.level_idx >= len(LEVELS) do return nil
	return &LEVELS[g_world.level_idx]
}

// Horizontal (XZ-plane) distance — entities all share the same ground_y, so
// the vertical component would only add noise to proximity checks.
dist_xz :: proc(a, b: rl.Vector3) -> f32 {
	dx := a.x - b.x
	dz := a.z - b.z
	return math.sqrt(dx*dx + dz*dz)
}

clamp_to_play_radius :: proc(p: rl.Vector3) -> rl.Vector3 {
	dx := p.x - g_world.center.x
	dz := p.z - g_world.center.z
	d := math.sqrt(dx*dx + dz*dz)
	if d <= g_world.play_radius do return p
	scale := g_world.play_radius / d
	return rl.Vector3{g_world.center.x + dx*scale, p.y, g_world.center.z + dz*scale}
}

// ── Update ────────────────────────────────────────────────────────────────

update_world :: proc(dt: f32) {
	if !g_world.model_loaded do return
	level := current_level_def()
	if level == nil do return

	move := rl.Vector3{}
	if rl.IsKeyDown(.LEFT)  || rl.IsKeyDown(.A) do move.x -= 1
	if rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D) do move.x += 1
	if rl.IsKeyDown(.UP)    || rl.IsKeyDown(.W) do move.z -= 1
	if rl.IsKeyDown(.DOWN)  || rl.IsKeyDown(.S) do move.z += 1

	if move.x != 0 || move.z != 0 {
		mlen := math.sqrt(move.x*move.x + move.z*move.z)
		speed := g_world.play_radius * PLAYER_SPEED
		g_world.player_pos.x += move.x / mlen * speed * dt
		g_world.player_pos.z += move.z / mlen * speed * dt
		g_world.player_pos = clamp_to_play_radius(g_world.player_pos)
		g_world.bob_timer += dt * 6.0
	}

	g_world.time_in_level += dt

	// Encounter chance scales up the longer the player lingers (capped at 2×)
	time_factor := min(f32(2.0), 1.0 + g_world.time_in_level / 120.0)

	prox_range   := g_world.play_radius * PROXIMITY_RANGE
	item_range   := g_world.play_radius * 0.08
	wander_speed := g_world.play_radius * WANDER_SPEED

	// Item pickups
	for i in 0 ..< MAX_WORLD_ITEMS {
		wi := &g_world.world_items[i]
		if !wi.active do continue
		if dist_xz(g_world.player_pos, wi.pos) < item_range {
			wi.active = false
			if wi.item_id > 0 && wi.item_id <= MAX_ITEM_TYPES {
				g_battle.item_qty[wi.item_id - 1] += 1
			}
			idef := get_item_def(wi.item_id)
			if idef != nil do set_hud_message(fmt.tprintf("Found: %s!", idef.name))
		}
	}

	for i in 0 ..< WANDER_COUNT {
		npc := &g_world.wanderers[i]

		to_target := rl.Vector3{npc.target.x - npc.pos.x, 0, npc.target.z - npc.pos.z}
		tlen := math.sqrt(to_target.x*to_target.x + to_target.z*to_target.z)
		if tlen < g_world.play_radius * 0.05 {
			npc.target = random_point_in_radius()
		} else {
			npc.pos.x += to_target.x / tlen * wander_speed * dt
			npc.pos.z += to_target.z / tlen * wander_speed * dt
		}

		if dist_xz(g_world.player_pos, npc.pos) < prox_range {
			if rand.float32() < level.encounter_chance * time_factor * dt {
				npc.pos    = random_point_in_radius()
				npc.target = random_point_in_radius()
				init_battle(g_player_id, npc.monster_id)
				g_game_state = .Battle
				return
			}
		}
	}

	if !g_prog.ten_collected[g_world.level_idx] && dist_xz(g_world.player_pos, g_world.spirit_pos) < prox_range {
		idx := g_world.level_idx
		if !g_world.spirit_intro_shown[idx] {
			g_world.spirit_intro_shown[idx] = true
			set_dialogue(level.intro, .Battle, 3)
			g_game_state = .Dialogue
		} else {
			init_battle(g_player_id, level_spirit_monster_id(level))
			g_game_state = .Battle
		}
		return
	}

	if dist_xz(g_world.player_pos, g_world.portal_pos) < prox_range {
		exit_level()
		g_game_state = .Hub
		return
	}

	if g_hud_msg.timer > 0 do g_hud_msg.timer -= dt

	// Lerped third-person follow camera
	target_cam_pos := g_world.player_pos + g_world.cam_offset
	g_world.camera.position += (target_cam_pos - g_world.camera.position) * CAM_LERP
	g_world.camera.target   += (g_world.player_pos - g_world.camera.target) * CAM_LERP
}

// ── Draw ──────────────────────────────────────────────────────────────────

draw_world :: proc() {
	if !g_world.model_loaded do return
	level := current_level_def()
	if level == nil do return

	cam := g_world.camera
	bound := g_prog.ten_collected[g_world.level_idx]
	bb_h := g_world.play_radius * 0.16

	rl.BeginMode3D(cam)
	rl.DrawModel(g_world.model, {0, 0, 0}, 1.0, rl.WHITE)
	draw_portal_marker(g_world.portal_pos, g_world.play_radius * 0.05)
	draw_world_items()
	draw_world_billboards(level, cam, bound, bb_h)
	rl.EndMode3D()

	draw_world_hud(level)
}

// Gathers every sprite-billboard in the scene (wanderers, the named spirit,
// the player) and draws them back-to-front by distance from the camera so
// overlapping translucent sprites blend in the right order.
draw_world_billboards :: proc(level: ^LevelDef, cam: rl.Camera3D, spirit_bound: bool, bb_h: f32) {
	MAX_BB :: WANDER_COUNT + 2
	positions: [MAX_BB]rl.Vector3
	monster_names: [MAX_BB]string
	is_player: [MAX_BB]bool
	count := 0

	for npc in g_world.wanderers {
		def := get_monster_def(npc.monster_id)
		if def == nil do continue
		positions[count]      = npc.pos
		monster_names[count]  = def.name
		count += 1
	}
	if !spirit_bound {
		positions[count]     = g_world.spirit_pos
		monster_names[count] = level.spirit_name
		count += 1
	}
	positions[count] = g_world.player_pos
	is_player[count] = true
	count += 1

	// Selection sort by squared distance to camera, farthest-first
	order: [MAX_BB]int
	for i in 0 ..< count do order[i] = i
	sq_dist :: proc(p, c: rl.Vector3) -> f32 {
		d := p - c
		return d.x*d.x + d.y*d.y + d.z*d.z
	}
	for i in 0 ..< count {
		far := i
		for j in i+1 ..< count {
			if sq_dist(positions[order[j]], cam.position) > sq_dist(positions[order[far]], cam.position) {
				far = j
			}
		}
		order[i], order[far] = order[far], order[i]
	}

	for oi in 0 ..< count {
		idx := order[oi]
		bb_pos := positions[idx] + rl.Vector3{0, bb_h * 0.5, 0}
		if is_player[idx] {
			src := rl.Rectangle{0, 0, f32(g_taz_billboard.width), f32(g_taz_billboard.height)}
			rl.DrawBillboardRec(cam, g_taz_billboard, src, bb_pos, rl.Vector2{bb_h * 0.7, bb_h}, rl.WHITE)
		} else if sheet, ok := get_monster_art(monster_names[idx]); ok {
			src := sheet_frame_rect(sheet, f32(rl.GetTime()), get_monster_art_fps(monster_names[idx]))
			rl.DrawBillboardRec(cam, sheet.tex, src, bb_pos, rl.Vector2{bb_h, bb_h}, rl.WHITE)
		}
	}
}

// Floating glowing orbs for items the player can walk over and collect.
draw_world_items :: proc() {
	t := f32(rl.GetTime())
	r := g_world.play_radius * 0.024
	for wi in g_world.world_items {
		if !wi.active do continue
		idef := get_item_def(wi.item_id)
		col : rl.Color = {200, 220, 100, 210}
		if idef != nil {
			if idef.heal_hp > 0 && idef.restore_souls == 0 {
				col = rl.Color{220, 70, 80, 220}
			} else if idef.restore_souls > 0 && idef.heal_hp == 0 {
				col = rl.Color{80, 130, 230, 220}
			} else if idef.heal_hp >= 900 {
				col = rl.Color{240, 220, 80, 220}
			}
		}
		bob   := math.sin(t * 2.2 + wi.pos.x + wi.pos.z) * g_world.play_radius * 0.02
		pos   := rl.Vector3{wi.pos.x, wi.pos.y + g_world.play_radius * 0.06 + bob, wi.pos.z}
		pulse := u8(150 + int(math.sin(t * 3.5 + wi.pos.z) * 80.0))
		rl.DrawSphere(pos, r, rl.Color{col.r, col.g, col.b, pulse})
		rl.DrawCircle3D(wi.pos, r * 1.8, rl.Vector3{1, 0, 0}, 90, rl.Color{col.r, col.g, col.b, pulse / 3})
	}
}

draw_portal_marker :: proc(pos: rl.Vector3, radius: f32) {
	t := f32(rl.GetTime())
	pulse := u8(140 + int(math.sin(t * 2.5) * 80.0))
	col := rl.Color{120, 200, 255, pulse}
	rl.DrawCircle3D(pos, radius, rl.Vector3{1, 0, 0}, 90, col)
	rl.DrawCircle3D(pos, radius * 0.6, rl.Vector3{1, 0, 0}, 90, rl.Color{210, 235, 255, pulse})
	rl.DrawCylinderWires(pos, radius, radius * 0.3, radius * 2.2, 16, col)
}

draw_world_hud :: proc(level: ^LevelDef) {
	rl.DrawRectangle(0, 0, SCREEN_W, 58, COL_PANEL)
	rl.DrawRectangleLines(0, 0, SCREEN_W, 58, COL_BORDER)

	draw_text_at(level.name, 16, 6, 22, COL_TEXT)
	draw_text_at(level.flavor, 16, 32, 14, COL_DIM)

	lv_str := fmt.tprintf("Taz  Lv%d", g_prog.level)
	xp_str := fmt.tprintf("XP %d/%d", g_prog.xp, g_prog.xp_to_next)
	draw_text_at(lv_str, SCREEN_W - 310, 6, 20, COL_HILITE)
	draw_text_at(xp_str, SCREEN_W - 310, 30, 14, COL_DIM)
	draw_bar(SCREEN_W - 180, 32, 160, 12, int(xp_bar_pct() * 100), 100,
		rl.Color{100, 220, 120, 255}, rl.Color{30, 60, 35, 255})

	spirit_str := fmt.tprintf("Spirits: %d/%d", g_prog.bound_count, MAX_BOUND_SPIRITS)
	draw_text_at(spirit_str, SCREEN_W - 310, 44, 13, COL_DIM)

	ten_str := "Story: "
	for i in 0 ..< 9 {
		if g_prog.ten_collected[i] {
			ten_str = fmt.tprintf("%s*", ten_str)
		} else {
			ten_str = fmt.tprintf("%s.", ten_str)
		}
	}
	draw_text_at(ten_str, SCREEN_W - 180, 6, 13, rl.Color{200, 180, 100, 255})

	hint := "WASD/Arrows: move   Approach spirits & the glowing portal"
	hw := rl.MeasureText(_cs(hint), 13)
	draw_text_at(hint, SCREEN_W - hw - 8, SCREEN_H - 20, 13, COL_DIM)

	if g_hud_msg.timer > 0 {
		alpha := u8(min(255, int(g_hud_msg.timer * 255)))
		col := rl.Color{235, 230, 100, alpha}
		mw := rl.MeasureText(_cs(g_hud_msg.text), 18)
		mx := (SCREEN_W - mw) / 2
		rl.DrawRectangle(mx - 12, SCREEN_H/2 - 16, mw + 24, 34, rl.Color{0, 0, 0, alpha/2})
		draw_text_at(g_hud_msg.text, mx, SCREEN_H/2 - 12, 18, col)
	}
}

// ── Taz — kept exactly as before ──────────────────────────────────────────
// Used both for the level-up screen's chibi portrait (still 2D) and as the
// recipe baked into g_taz_billboard for the 3D scenes.

draw_taz_world :: proc(x, y: i32, facing_x: int, bob: f32) {
	px := x
	py := y
	bob_off := i32(math.sin(bob * 0.8) * 2.0)

	scale := f32(1.0) + f32(g_prog.level - 1) * 0.02
	bw := i32(f32(12) * scale)
	bh := i32(f32(14) * scale)
	hw := i32(f32(10) * scale)

	rl.DrawRectangle(px + 10 - bw, py + 14 + bob_off, bw*2, bh, rl.Color{60, 120, 200, 255})
	rl.DrawCircle(px + 10, py + 12 + bob_off, f32(hw), rl.Color{230, 200, 170, 255})
	rl.DrawTriangle(
		rl.Vector2{f32(px + 10 - hw), f32(py + 6 + bob_off)},
		rl.Vector2{f32(px + 10), f32(py - 2 + bob_off)},
		rl.Vector2{f32(px + 10 + hw), f32(py + 6 + bob_off)},
		rl.Color{30, 30, 30, 255},
	)
	eye_x := px + 10 + i32(facing_x) * 3
	rl.DrawCircle(eye_x, py + 12 + bob_off, 2.0, rl.Color{30, 30, 30, 255})

	rl.DrawRectangleLines(px, py, 32, 32, rl.Color{255, 255, 255, 60})
}

// Bakes Taz's chibi look (the same body/head/hair/eye shapes as
// draw_taz_world, minus the tile-highlight border) into a standalone
// transparent texture once at startup, so it can be billboarded in 3D —
// "keep the main character" without rewriting his look from scratch.
bake_taz_billboard :: proc() -> rl.Texture2D {
	w : i32 = 64
	h : i32 = 80
	rt := rl.LoadRenderTexture(w, h)

	rl.BeginTextureMode(rt)
	rl.ClearBackground(rl.BLANK)

	cx := w / 2
	rl.DrawRectangle(cx - 12, 38, 24, 28, rl.Color{60, 120, 200, 255})  // body
	rl.DrawCircle(cx, 26, 18, rl.Color{230, 200, 170, 255})             // head
	rl.DrawTriangle(                                                     // hair
		rl.Vector2{f32(cx - 18), 18},
		rl.Vector2{f32(cx), 6},
		rl.Vector2{f32(cx + 18), 18},
		rl.Color{30, 30, 30, 255},
	)
	rl.DrawCircle(cx + 6, 26, 3, rl.Color{30, 30, 30, 255})             // eye, facing right

	rl.EndTextureMode()

	img := rl.LoadImageFromTexture(rt.texture)
	rl.ImageFlipVertical(&img)
	tex := rl.LoadTextureFromImage(img)
	rl.UnloadImage(img)
	rl.UnloadRenderTexture(rt)
	return tex
}
