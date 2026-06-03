package sb

import rl "vendor:raylib"
import "core:fmt"
import "core:strings"

// ---- gamepad helpers ----

pad_ok :: proc() -> bool { return rl.IsGamepadAvailable(0) }

key_confirm :: proc() -> bool {
	return rl.IsKeyPressed(.ENTER) ||
	       (pad_ok() && rl.IsGamepadButtonPressed(0, .RIGHT_FACE_DOWN))
}
key_cancel :: proc() -> bool {
	return rl.IsKeyPressed(.ESCAPE) ||
	       (pad_ok() && rl.IsGamepadButtonPressed(0, .RIGHT_FACE_RIGHT))
}
key_up :: proc() -> bool {
	return rl.IsKeyPressed(.UP) ||
	       (pad_ok() && (rl.IsGamepadButtonPressed(0, .LEFT_FACE_UP) ||
	                     rl.GetGamepadAxisMovement(0, .LEFT_Y) < -0.5))
}
key_down :: proc() -> bool {
	return rl.IsKeyPressed(.DOWN) ||
	       (pad_ok() && (rl.IsGamepadButtonPressed(0, .LEFT_FACE_DOWN) ||
	                     rl.GetGamepadAxisMovement(0, .LEFT_Y) > 0.5))
}
key_skill :: proc(idx: int) -> bool {
	keys := [6]rl.KeyboardKey{.ONE, .TWO, .THREE, .FOUR, .FIVE, .SIX}
	if idx < 0 || idx > 5 do return false
	return rl.IsKeyPressed(keys[idx])
}

// ---- init / cleanup ----

init_game :: proc() -> GameState {
	g: GameState

	g.screen = .Title

	g.summoner.hp            = 100
	g.summoner.max_hp        = 100
	g.summoner.level         = 1
	g.summoner.gold          = 30
	g.summoner.alignment     = .Neutral
	g.summoner.alignment_pts = 0

	p := new(Spirit)
	p^ = spirit_pixie()
	g.summoner.spirits[0] = p

	imp := new(Spirit)
	imp^ = spirit_imp()
	g.summoner.spirits[1] = imp

	g.fuse_idx_a = -1
	g.fuse_idx_b = -1
	g.run_step   = 0
	g.total_runs = 6

	g.combat_log.lines = make([dynamic]string)
	g.spirit_pool       = make([dynamic]Spirit)
	g.particles         = make([dynamic]Particle)
	g.float_texts       = make([dynamic]FloatText)

	// overworld start position
	g.player_tx      = 6
	g.player_ty      = 8
	g.current_area   = .Village
	g.encounter_cooldown = 2.0
	g.cam_x          = f32(g.player_tx * TILE_SZ)
	g.cam_y          = f32(g.player_ty * TILE_SZ)

	return g
}

free_all_spirits :: proc(g: ^GameState) {
	for i in 0..<6 {
		if g.summoner.spirits[i] != nil {
			free(g.summoner.spirits[i])
			g.summoner.spirits[i] = nil
		}
	}
}

// ---- fusion resolver ----

resolve_fuse :: proc(g: ^GameState) -> (result: Spirit, ok: bool) {
	if g.fuse_idx_a < 0 || g.fuse_idx_b < 0         do return {}, false
	if g.fuse_idx_a == g.fuse_idx_b                  do return {}, false
	sa  := g.summoner.spirits[g.fuse_idx_a]
	sb_ := g.summoner.spirits[g.fuse_idx_b]
	if sa == nil || sb_ == nil                       do return {}, false

	na := sa.name
	nb := sb_.name

	has :: proc(a, b, x, y: string) -> bool {
		return (strings.contains(a, x) && strings.contains(b, y)) ||
		       (strings.contains(a, y) && strings.contains(b, x))
	}

	if has(na, nb, "Pixie",        "Wisp")         do return spirit_sylph(),       true
	if has(na, nb, "Ember Sprite", "Frost Moth")   do return spirit_ignis(),       true
	if has(na, nb, "Vine Sprite",  "Stone Gnome")  do return spirit_thornwarden(), true
	if has(na, nb, "Imp",          "Screech Bat")  do return spirit_dusk_shade(),  true
	if has(na, nb, "Wisp",         "Vine Sprite")  do return spirit_undine(),      true
	if has(na, nb, "Pixie",        "Ember Sprite") do return spirit_seraph_fledge(), true

	return {}, false
}

// ---- input handlers ----

handle_input_title :: proc(g: ^GameState) {
	if key_confirm() || rl.IsKeyPressed(.ENTER) {
		g.screen = .Overworld
	}
}

handle_input_combat :: proc(g: ^GameState) {
	if g.combat_over {
		if key_confirm() { handle_input_combat_return(g) }
		return
	}
	if !g.player_turn do return

	// navigate skills
	if key_up() {
		g.selected_skill_idx -= 1
		if g.selected_skill_idx < 0 do g.selected_skill_idx = 5
	}
	if key_down() {
		g.selected_skill_idx += 1
		if g.selected_skill_idx > 5 do g.selected_skill_idx = 0
	}

	// skill use
	used_idx  := g.selected_skill_idx
	skill_used := false
	for i in 0..<6 {
		if key_skill(i) {
			used_idx   = i
			skill_used = true
			break
		}
	}
	if key_confirm() do skill_used = true

	if skill_used {
		g.player_attack_timer = 0.7
		fx_mp_used(g)

		enemy_hp_before  := g.enemy.hp
		player_hp_before := g.summoner.hp

		msg, weakness := player_use_skill(g, used_idx)
		combat_log_add(&g.combat_log, msg)

		// spawn hit effects
		enemy_dmg  := enemy_hp_before  - g.enemy.hp
		player_self := player_hp_before - g.summoner.hp  // reflect damage
		if enemy_dmg > 0  do fx_damage_enemy(g, enemy_dmg, weakness)
		if enemy_dmg < 0  do fx_absorb(g, -enemy_dmg)
		if player_self > 0 do fx_damage_player(g, player_self)
		heal_amt := g.summoner.hp - player_hp_before
		if heal_amt > 0 do fx_heal_player(g, heal_amt)

		if g.enemy.hp <= 0 {
			award_combat_xp(g, &g.enemy)
			combat_log_add(&g.combat_log,
				fmt.tprintf("Victory! +%d XP, +%d Gold.", g.enemy.xp_reward, g.enemy.gold_reward))
			g.combat_over = true
			g.combat_won  = true
			g.run_step   += 1
			if g.run_step >= g.total_runs { g.run_step = g.total_runs }
			return
		}

		if weakness && !g.bonus_action_used {
			fx_weakness(g)
			g.bonus_action      = true
			g.bonus_action_used = true
			combat_log_add(&g.combat_log, "WEAKNESS hit! You gain an extra action!")
			return
		}
		g.bonus_action = false

		phb2 := g.summoner.hp
		emsg := enemy_attack(g)
		if emsg != "" do combat_log_add(&g.combat_log, emsg)
		if g.summoner.hp < phb2 do fx_damage_player(g, phb2 - g.summoner.hp)

		if g.summoner.hp <= 0 {
			combat_log_add(&g.combat_log, "You have been defeated...")
			g.combat_over = true
			g.combat_won  = false
			g.screen      = .GameOver
			return
		}
		tick_cooldowns(g)
	}

	// bind
	if rl.IsKeyPressed(.B) || (pad_ok() && rl.IsGamepadButtonPressed(0, .RIGHT_FACE_UP)) {
		g.player_attack_timer = 0.7
		fx_mp_used(g)
		phb_bind := g.summoner.hp
		success, bmsg := attempt_bind(g)
		combat_log_add(&g.combat_log, bmsg)
		if success {
			slot := bind_to_slot(g, g.enemy.spirit_template)
			if slot == -1 {
				combat_log_add(&g.combat_log, "Soul slots full! Released slot 5.")
				release_spirit(g, 5)
				slot = bind_to_slot(g, g.enemy.spirit_template)
			}
			combat_log_add(&g.combat_log,
				fmt.tprintf("%s now in soul slot %d!", g.enemy.spirit_template.name, slot+1))
			g.summoner.alignment_pts += 3
			update_alignment(g)
			if g.enemy.spirit_template.tier == 3 {
				g.screen = .Victory
				return
			}
			g.combat_over = true
			g.combat_won  = true
			g.bind_success = true
			g.run_step    += 1
		} else {
			emsg := enemy_attack(g)
			if emsg != "" do combat_log_add(&g.combat_log, emsg)
			if g.summoner.hp < phb_bind do fx_damage_player(g, phb_bind - g.summoner.hp)
			if g.summoner.hp <= 0 {
				g.combat_over = true
				g.combat_won  = false
				g.screen      = .GameOver
			}
		}
	}

	// talk / negotiate
	if (rl.IsKeyPressed(.T) || (pad_ok() && rl.IsGamepadButtonPressed(0, .RIGHT_FACE_LEFT))) &&
	   g.talk_available && !g.negotiate_done {
		g.negotiate_option = 0
		g.negotiate_result = ""
		g.negotiate_done   = false
		g.screen           = .Negotiate
	}

	// flee
	if rl.IsKeyPressed(.F) || (pad_ok() && rl.IsGamepadButtonPressed(0, .MIDDLE_LEFT)) {
		combat_log_add(&g.combat_log, "You fled from combat.")
		g.summoner.alignment_pts -= 2
		update_alignment(g)
		g.screen = .Overworld
	}
}

handle_input_negotiate :: proc(g: ^GameState) {
	if g.negotiate_done {
		if key_confirm() {
			g.screen = .Combat
			// if negotiation succeeded, the enemy was already added to slots
		}
		return
	}

	if key_cancel() {
		g.screen = .Combat
		return
	}

	if key_up() {
		g.negotiate_option -= 1
		if g.negotiate_option < 0 do g.negotiate_option = 3
	}
	if key_down() {
		g.negotiate_option += 1
		if g.negotiate_option > 3 do g.negotiate_option = 0
	}
	for i in 0..<4 {
		if key_skill(i) do g.negotiate_option = i
	}

	if key_confirm() {
		opt := NegotiateOption(g.negotiate_option)
		success, msg := attempt_negotiate(g, opt)
		g.negotiate_result = msg
		g.negotiate_done   = true
		g.talk_available   = false // one attempt per combat

		if success {
			slot := bind_to_slot(g, g.enemy.spirit_template)
			if slot == -1 {
				release_spirit(g, 5)
				slot = bind_to_slot(g, g.enemy.spirit_template)
			}
			combat_log_add(&g.combat_log,
				fmt.tprintf("Negotiated! %s joins slot %d.", g.enemy.spirit_template.name, slot+1))
			if g.enemy.spirit_template.tier == 3 {
				g.screen = .Victory
				return
			}
			g.combat_over = true
			g.combat_won  = true
			g.run_step   += 1
		} else {
			// enemy becomes enraged on failed negotiation
			g.enemy_enraged = true
			combat_log_add(&g.combat_log, fmt.tprintf("%s is ENRAGED!", g.enemy.name))
		}
	}
}

handle_input_fuse :: proc(g: ^GameState) {
	if key_cancel() { g.screen = .Overworld; return }

	@(static) picking_a := true
	if rl.IsKeyPressed(.A) do picking_a = true
	if rl.IsKeyPressed(.B) do picking_a = false

	for i in 0..<6 {
		if key_skill(i) {
			if picking_a { g.fuse_idx_a = i } else { g.fuse_idx_b = i }
		}
	}

	if rl.IsKeyPressed(.F) {
		fused, ok := resolve_fuse(g)
		if ok {
			a := g.fuse_idx_a
			b := g.fuse_idx_b
			release_spirit(g, a)
			release_spirit(g, b)
			slot := bind_to_slot(g, fused)
			if slot == -1 {
				s  := new(Spirit)
				s^ = fused
				g.summoner.spirits[a] = s
			}
			g.fuse_idx_a = -1
			g.fuse_idx_b = -1
		}
	}
}

handle_input_gameover :: proc(g: ^GameState) {
	if key_confirm() {
		free_all_spirits(g)
		delete(g.combat_log.lines)
		delete(g.spirit_pool)
		g^ = init_game()
	}
}

handle_input_victory :: proc(g: ^GameState) {
	if key_confirm() { g.screen = .Overworld }
}

// ---- main ----

main :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(1280, 720, "SoulBinder v0.2 — Bind | Negotiate | Evolve")
	rl.MaximizeWindow()
	rl.SetTargetFPS(60)
	rl.InitAudioDevice()
	load_assets()

	g := init_game()

	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()

		// Alt+Enter toggles fullscreen
		if (rl.IsKeyDown(.LEFT_ALT) || rl.IsKeyDown(.RIGHT_ALT)) && rl.IsKeyPressed(.ENTER) {
			rl.ToggleFullscreen()
		}

		update_effects(&g, dt)

		// combat animation ticks
		if g.player_attack_timer > 0 {
			g.player_attack_timer -= dt
			if g.player_attack_timer < 0 do g.player_attack_timer = 0
		}
		g.combat_idle_timer += dt
		if g.combat_idle_timer >= 0.1 {
			g.combat_idle_timer = 0
			g.combat_idle_frame = (g.combat_idle_frame + 1) % 10
		}

		// music routing
		switch g.screen {
		case .Overworld, .Title, .Fuse, .Victory:
			play_music(&music_overworld)
		case .Combat, .Negotiate:
			play_music(&music_combat)
		case .GameOver:
			if active_music != nil { rl.StopMusicStream(active_music^); active_music = nil }
		}
		tick_music()

		switch g.screen {
		case .Title:     handle_input_title(&g)
		case .Overworld:
			handle_input_overworld(&g)
			update_overworld(&g, dt)
		case .Combat:    handle_input_combat(&g)
		case .Negotiate: handle_input_negotiate(&g)
		case .Fuse:      handle_input_fuse(&g)
		case .GameOver:  handle_input_gameover(&g)
		case .Victory:   handle_input_victory(&g)
		}

		rl.BeginDrawing()
		switch g.screen {
		case .Title:     draw_title()
		case .Overworld: draw_overworld(&g)
		case .Combat:    draw_combat(&g)
		case .Negotiate: draw_negotiate(&g)
		case .Fuse:      draw_fuse(&g)
		case .GameOver:  draw_game_over(&g)
		case .Victory:   draw_victory(&g)
		}
		rl.EndDrawing()

		free_all(context.temp_allocator)
	}

	unload_assets()
	free_all_spirits(&g)
	delete(g.combat_log.lines)
	delete(g.spirit_pool)
	delete(g.particles)
	delete(g.float_texts)
	rl.CloseAudioDevice()
	rl.CloseWindow()
}
