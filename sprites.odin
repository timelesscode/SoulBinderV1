package main

import rl "vendor:raylib"

// ── Generic Spritesheet Animator ──────────────────────────────────────────
// Every enemy spritesheet in art/ happens to be a horizontal strip of square
// frames (frame size == sheet height). That means a single loader + animator
// can drive all of them without any hand-written per-asset frame metadata —
// just point it at a PNG and it figures out the rest.

SpriteSheet :: struct {
	tex:         rl.Texture2D,
	frame_size:  i32,
	frame_count: i32,
}

load_spritesheet :: proc(path: string) -> SpriteSheet {
	tex := rl.LoadTexture(_cs(path))
	size := tex.height
	count: i32 = 1
	if size > 0 {
		count = max(i32(1), tex.width / size)
	}
	return SpriteSheet{tex = tex, frame_size = size, frame_count = count}
}

unload_spritesheet :: proc(s: ^SpriteSheet) {
	if s.tex.id != 0 do rl.UnloadTexture(s.tex)
	s^ = {}
}

// Source rectangle for the frame that should be showing at time `t` (seconds),
// cycling at `fps` frames per second.
sheet_frame_rect :: proc(s: SpriteSheet, t: f32, fps: f32) -> rl.Rectangle {
	if s.frame_count <= 0 || s.frame_size <= 0 do return {}
	idx := i32(t * fps) % s.frame_count
	return rl.Rectangle{f32(idx * s.frame_size), 0, f32(s.frame_size), f32(s.frame_size)}
}

// ── Monster → Art Mapping ─────────────────────────────────────────────────
// Maps each monster (by name, stable across CSV row reordering) to one of the
// real spritesheets bundled in art/, giving every creature its own distinct
// look instead of a generic programmer-art fallback shape. Picked for variety
// and, where it lined up naturally, thematic fit with the monster's element.

MonsterArtInfo :: struct {
	path: string,
	fps:  f32,
}

monster_art_info :: proc(name: string) -> (info: MonsterArtInfo, ok: bool) {
	switch name {
	// Generic wandering pool (monsters.csv rows 1-8)
	case "Flamox":     return {"art/Fire-Skull-Files/Spritesheets/fire-skull.png", 8}, true
	case "Aquirin":    return {"art/meerman/Spritesheet.png", 4}, true
	case "Leafang":    return {"art/mutant-toad/Spritesheets/mutant-toad-idle.png", 6}, true
	case "Voidwraith": return {"art/enemy-ghost/Spritesheets/no-particles.png", 8}, true
	case "Cinderpaw":  return {"art/Hell-Hound-Files/Spritesheets/hell-hound-idle.png", 10}, true
	case "Frostmaw":   return {"art/WereWolf/Spritesheets/werewolf-idle.png", 6}, true
	case "Thornback":  return {"art/wolf-runing-cycle/spritesheets/wolf-runing-cycle-skin.png", 8}, true
	case "Shadefiend": return {"art/Ghost-Files/Spritesheets/ghost-Idle.png", 6}, true

	// The Ten Spirits — named, story-significant, one per level
	case "Ignis":   return {"art/Ogre/Spritesheets/ogre-idle.png", 6}, true
	case "Aqua":    return {"art/flying-eye-demon/Spritesheet.png", 8}, true
	case "Verdant": return {"art/flying-bird/spritesheets/flying-creature-cycle-skin.png", 10}, true
	case "Umbra":   return {"art/Nightmare-Files/Spritesheets/idle.png", 6}, true
	case "Lumen":   return {"art/Terrible Knight/Spritesheets/player-Idle.png", 5}, true
	case "Gale":    return {"art/crow/Spritesheets/crow-idle.png", 8}, true
	case "Magma":   return {"art/Hell-Beast-Files/Idle/Spritesheet.png", 5}, true
	case "Abyssal": return {"art/death/Spritesheets/death-walk.png", 6}, true
	case "Sylvan":  return {"art/demon-Files/Spritesheets/demon-idle.png", 6}, true
	case "Veyrath": return {"art/Grotto-escape-2-boss-dragon/spritesheets/idle.png", 10}, true
	}
	return {}, false
}

// ── Lazy-loaded, cached sheets ────────────────────────────────────────────
// Battle portraits and 3D billboards both want the same sheet for a given
// monster — load each one once on first use and keep it for the rest of the
// session (there are only 18 monsters; the whole set comfortably fits in VRAM).

MAX_MONSTER_ART :: 32
_monster_art_cache: [MAX_MONSTER_ART]struct{ name: string, sheet: SpriteSheet }
_monster_art_count: int

get_monster_art :: proc(name: string) -> (sheet: SpriteSheet, ok: bool) {
	for i in 0 ..< _monster_art_count {
		if _monster_art_cache[i].name == name {
			return _monster_art_cache[i].sheet, true
		}
	}
	info := monster_art_info(name) or_return
	if _monster_art_count >= MAX_MONSTER_ART do return {}, false

	loaded := load_spritesheet(info.path)
	if loaded.tex.id == 0 do return {}, false

	_monster_art_cache[_monster_art_count] = {name = name, sheet = loaded}
	_monster_art_count += 1
	return loaded, true
}

get_monster_art_fps :: proc(name: string) -> f32 {
	info, ok := monster_art_info(name)
	if !ok do return 6
	return info.fps
}

unload_all_monster_art :: proc() {
	for i in 0 ..< _monster_art_count {
		unload_spritesheet(&_monster_art_cache[i].sheet)
	}
	_monster_art_count = 0
}
