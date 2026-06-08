package main

import "core:fmt"
import rl "vendor:raylib"

SCREEN_W :: 1280
SCREEN_H :: 720

g_atlas:         rl.Texture2D
g_taz_billboard: rl.Texture2D // baked-once billboard sprite of the player (see bake_taz_billboard)

// Virtual-resolution render target — everything draws at a fixed 1280x720
// and gets scaled+letterboxed to whatever the real (resizable/fullscreen)
// window size is. Keeps every existing 2D draw call (which assumes
// SCREEN_W/SCREEN_H) correct while supporting fullscreen & resizing.
g_target: rl.RenderTexture2D

GameState :: enum {
	Dialogue,   // Oracle tutorial / story cutscenes
	Hub,        // Rest area / level-select home base
	Exploring,  // Walking a 3D level
	Battle,		// Gotta Catch em all
	FusionMenu, // Oracle fusion screen
	LevelUp,    // Level-up move learning screen
}

g_game_state:      GameState
g_player_id:       int
g_prev_game_state: GameState // for returning from fusion

main :: proc() {
	rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE})
	rl.InitWindow(SCREEN_W, SCREEN_H, "SoulBinder or SoulBender?")
	rl.SetTargetFPS(60)
	defer rl.CloseWindow()

	g_target = rl.LoadRenderTexture(SCREEN_W, SCREEN_H)
	rl.SetTextureFilter(g_target.texture, .POINT) // crisp scaling, no blur
	defer rl.UnloadRenderTexture(g_target)

	if !load_all_data() {
		fmt.println("Could not load game data. Aborting.")
		return
	}
	if g_db.monster_count < 2 {
		fmt.println("Need at least 2 monsters defined.")
		return
	}

	g_atlas = rl.LoadTexture("spirit atlas.png")
	defer if g_atlas.id != 0 do rl.UnloadTexture(g_atlas)
	defer unload_all_monster_art()

	g_player_id = g_db.monsters[0].id
	g_taz_billboard = bake_taz_billboard()
	defer if g_taz_billboard.id != 0 do rl.UnloadTexture(g_taz_billboard)
	load_hub_backgrounds()
	defer unload_hub_backgrounds()

	init_player_progression()
	start_intro_dialogue()
	g_game_state = .Dialogue

	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()

		if rl.IsKeyPressed(.F11) {
			rl.ToggleBorderlessWindowed()
		}

		switch g_game_state {
		case .Dialogue:    update_dialogue(dt)
		case .Hub:         update_hub(dt)
		case .Exploring:   update_world(dt)
		case .Battle:      update_battle(dt)
		case .FusionMenu:  update_fusion(dt)
		case .LevelUp:     update_level_up(dt)
		}

		// Draw the whole game at a fixed virtual resolution...
		rl.BeginTextureMode(g_target)
		rl.ClearBackground(COL_BG)
		switch g_game_state {
		case .Dialogue:    draw_dialogue()
		case .Hub:         draw_hub()
		case .Exploring:   draw_world()
		case .Battle:      draw_battle()
		case .FusionMenu:  draw_fusion()
		case .LevelUp:     draw_level_up()
		}
		rl.EndTextureMode()

		// ...then scale+letterbox it to fill the real (resizable/fullscreen) window
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		draw_virtual_screen()
		rl.EndDrawing()

		free_all(context.temp_allocator)
	}
}

// Blits g_target (the 1280x720 virtual screen) onto the real window, scaled
// to the largest size that fits while preserving aspect ratio (letterboxed).
draw_virtual_screen :: proc() {
	sw := f32(rl.GetScreenWidth())
	sh := f32(rl.GetScreenHeight())

	scale := min(sw / SCREEN_W, sh / SCREEN_H)
	dst_w := f32(SCREEN_W) * scale
	dst_h := f32(SCREEN_H) * scale
	dst_x := (sw - dst_w) * 0.5
	dst_y := (sh - dst_h) * 0.5

	// Render-texture contents are stored flipped vertically — flip the source rect back
	src := rl.Rectangle{0, 0, f32(SCREEN_W), -f32(SCREEN_H)}
	dst := rl.Rectangle{dst_x, dst_y, dst_w, dst_h}
	rl.DrawTexturePro(g_target.texture, src, dst, {0, 0}, 0, rl.WHITE)
}
