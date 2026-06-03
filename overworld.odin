package sb

import rl "vendor:raylib"
import "core:math/rand"
import "core:fmt"

is_walkable :: proc(area: Area, tx, ty: int) -> bool {
	if tx < 0 || ty < 0 || tx >= MAP_W || ty >= MAP_H do return false
	t := AREA_MAPS[area][ty][tx]
	return t == 0 || t == 2 || t == 4
}

area_boss_enemy :: proc(area: Area) -> Enemy {
	switch area {
	case .Village:
		return Enemy{
			name = "ELDER SPECTER",
			hp = 120, max_hp = 120, atk = 18, def = 10, spd = 7,
			level = 8, xp_reward = 120, gold_reward = 40,
			spirit_template = spirit_wisp(),
			talk_mood = .Law,
		}
	case .Forest:
		return Enemy{
			name = "GREAT THORNLORD",
			hp = 200, max_hp = 200, atk = 24, def = 14, spd = 6,
			level = 14, xp_reward = 200, gold_reward = 70,
			spirit_template = spirit_vine_sprite(),
			talk_mood = .Neutral,
		}
	case .Ruins:
		return Enemy{
			name = "KETHARA REVENANT",
			hp = 320, max_hp = 320, atk = 30, def = 18, spd = 9,
			level = 20, xp_reward = 400, gold_reward = 120,
			spirit_template = spirit_vexor(),
			talk_mood = .Chaos,
		}
	}
	return enemy_vexor()
}

scale_enemy :: proc(e: Enemy, lvl_add: int, hp_m, atk_m, def_m: f32) -> Enemy {
	e2 := e
	e2.level     += lvl_add
	e2.hp         = max(1, int(f32(e.hp)  * hp_m))
	e2.max_hp     = e2.hp
	e2.atk        = max(1, int(f32(e.atk) * atk_m))
	e2.def        = max(0, int(f32(e.def) * def_m))
	e2.xp_reward  = int(f32(e.xp_reward)  * (1 + f32(lvl_add)*0.15))
	e2.gold_reward= int(f32(e.gold_reward) * (1 + f32(lvl_add)*0.10))
	return e2
}

area_random_enemy :: proc(area: Area) -> Enemy {
	pool_v := [5]Enemy{
		enemy_pixie_wild(), enemy_imp_wild(), enemy_ember_sprite_wild(),
		enemy_stone_gnome_wild(), enemy_frost_moth_wild(),
	}
	pool_f := [5]Enemy{
		enemy_imp_wild(), enemy_ember_sprite_wild(), enemy_stone_gnome_wild(),
		enemy_frost_moth_wild(), enemy_screech_bat_wild(),
	}
	pool_r := [5]Enemy{
		enemy_stone_gnome_wild(), enemy_frost_moth_wild(), enemy_screech_bat_wild(),
		enemy_ember_sprite_wild(), enemy_imp_wild(),
	}
	switch area {
	case .Village:
		return pool_v[rand.int_max(5)]
	case .Forest:
		return scale_enemy(pool_f[rand.int_max(5)], 5, 2.0, 1.7, 1.4)
	case .Ruins:
		return scale_enemy(pool_r[rand.int_max(5)], 12, 3.8, 2.8, 2.2)
	}
	return pool_v[0]
}

update_overworld :: proc(g: ^GameState, dt: f32) {
	// message timer
	if g.msg_timer > 0 {
		g.msg_timer -= dt
		if g.msg_timer <= 0 do g.overworld_msg = ""
	}

	// encounter cooldown
	if g.encounter_cooldown > 0 do g.encounter_cooldown -= dt

	// walk animation
	g.anim_timer += dt
	if g.anim_timer > 0.18 {
		g.anim_timer = 0
		g.anim_frame ~= 1
	}

	// smooth camera
	sw := f32(rl.GetScreenWidth())
	sh := f32(rl.GetScreenHeight())
	target_x := f32(g.player_tx * TILE_SZ) - sw/2 + TILE_SZ/2
	target_y := f32(g.player_ty * TILE_SZ) - sh/2 + TILE_SZ/2
	g.cam_x += (target_x - g.cam_x) * dt * 8
	g.cam_y += (target_y - g.cam_y) * dt * 8
	max_cx := f32(MAP_W * TILE_SZ) - sw
	max_cy := f32(MAP_H * TILE_SZ) - sh
	if g.cam_x < 0       do g.cam_x = 0
	if g.cam_y < 0       do g.cam_y = 0
	if max_cx > 0 && g.cam_x > max_cx do g.cam_x = max_cx
	if max_cy > 0 && g.cam_y > max_cy do g.cam_y = max_cy
}

handle_input_overworld :: proc(g: ^GameState) {
	if rl.IsKeyPressed(.F) || (pad_ok() && rl.IsGamepadButtonPressed(0, .RIGHT_FACE_LEFT)) {
		g.fuse_idx_a = -1
		g.fuse_idx_b = -1
		g.screen = .Fuse
		return
	}

	dx, dy := 0, 0
	if rl.IsKeyPressed(.LEFT)  || rl.IsKeyPressed(.A) { dx = -1 }
	if rl.IsKeyPressed(.RIGHT) || rl.IsKeyPressed(.D) { dx =  1 }
	if rl.IsKeyPressed(.UP)    || rl.IsKeyPressed(.W) { dy = -1 }
	if rl.IsKeyPressed(.DOWN)  || rl.IsKeyPressed(.S) { dy =  1 }

	if dx == 0 && dy == 0 do return

	nx := g.player_tx + dx
	ny := g.player_ty + dy
	if !is_walkable(g.current_area, nx, ny) do return

	g.player_tx = nx
	g.player_ty = ny
	g.step_count += 1

	// MP regen every 5 steps
	if g.step_count % 5 == 0 && g.summoner.hp < g.summoner.max_hp {
		g.summoner.hp = min(g.summoner.hp + 2, g.summoner.max_hp)
	}

	tile := AREA_MAPS[g.current_area][ny][nx]

	// area transitions — bottom exit
	if ny >= MAP_H-2 && nx >= 11 && nx <= 14 {
		switch g.current_area {
		case .Village:
			if !g.boss_defeated[.Village] {
				g.overworld_msg = "The forest path is sealed. Defeat the Elder Specter first."
				g.msg_timer = 3.0
				g.player_ty = ny - 1
			} else {
				g.current_area = .Forest
				g.player_tx = 12; g.player_ty = 1
				g.overworld_msg = "You enter Thornwood Forest."
				g.msg_timer = 2.5
			}
		case .Forest:
			if !g.boss_defeated[.Forest] {
				g.overworld_msg = "The ruin gate is sealed. Defeat the Great Thornlord first."
				g.msg_timer = 3.0
				g.player_ty = ny - 1
			} else {
				g.current_area = .Ruins
				g.player_tx = 7; g.player_ty = 1
				g.overworld_msg = "You enter the Ruins of Kethara."
				g.msg_timer = 2.5
			}
		case .Ruins:
			// no further area
		}
		return
	}

	// area transitions — top exit
	if ny <= 0 && nx >= 6 && nx <= 8 {
		switch g.current_area {
		case .Forest:
			g.current_area = .Village
			g.player_tx = 12; g.player_ty = MAP_H - 3
			g.overworld_msg = "You return to Ashenveil Village."
			g.msg_timer = 2.5
		case .Ruins:
			g.current_area = .Forest
			g.player_tx = 7; g.player_ty = MAP_H - 3
			g.overworld_msg = "You return to Thornwood Forest."
			g.msg_timer = 2.5
		case .Village:
			// nothing north of village
		}
		return
	}

	// special tile — boss or shrine
	if tile == 4 {
		if !g.boss_defeated[g.current_area] {
			boss := area_boss_enemy(g.current_area)
			g.overworld_msg = fmt.tprintf("A powerful spirit stirs! %s appears!", boss.name)
			g.msg_timer = 0 // message shows in combat log
			start_combat(g, boss)
			g.screen = .Combat
		} else {
			// shrine: restore HP
			g.summoner.hp = g.summoner.max_hp
			g.overworld_msg = "Sacred shrine! HP fully restored."
			g.msg_timer = 2.5
		}
		return
	}

	// random encounter on open floor
	if tile == 0 && g.encounter_cooldown <= 0 {
		rate := 10
		if g.current_area == .Forest do rate = 7
		if g.current_area == .Ruins  do rate = 5
		if rand.int_max(rate) == 0 {
			g.encounter_cooldown = 3.0
			enc := area_random_enemy(g.current_area)
			start_combat(g, enc)
			g.screen = .Combat
		}
	}
}

handle_input_combat_return :: proc(g: ^GameState) {
	// called after combat ends — mark boss defeated if it was a boss
	if g.combat_won {
		for area in Area {
			boss := area_boss_enemy(area)
			if g.enemy.name == boss.name {
				g.boss_defeated[area] = true
				break
			}
		}
		// final victory: all bosses defeated
		if g.boss_defeated[.Village] && g.boss_defeated[.Forest] && g.boss_defeated[.Ruins] {
			g.screen = .Victory
			return
		}
	}
	g.screen = .Overworld
}
