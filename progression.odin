package main

//import "core:fmt"

// ── Player (Taz) Progression ──────────────────────────────────────────────

MAX_BOUND_SPIRITS  :: 10
MAX_LEARNABLE      :: 16

// Moves Taz unlocks as he levels — he starts with only slot 0 active
MoveUnlock :: struct {
	level:    int,
	tech_id:  int,
	slot:     int,  // which of the 4 move slots to fill
}

// The story's named Ten Spirits (indices into monster DB by name)
// These are the spirits Taz must collect across the world
TEN_SPIRIT_NAMES := [MAX_BOUND_SPIRITS]string{
	"Ignis",    // 1 – fire spirit,  Scorchlands
	"Aqua",     // 2 – water spirit, Shoreline
	"Verdant",  // 3 – nature spirit,Grasslands
	"Umbra",    // 4 – dark spirit,  Shadow Cavern
	"Lumen",    // 5 – psychic,      Grasslands inner
	"Gale",     // 6 – kinetic,      mountain pass
	"Magma",    // 7 – fire+dark,    deep volcanic
	"Abyssal",  // 8 – water+dark,   deep shore
	"Sylvan",   // 9 – nature+psych, ancient grove
	"Veyrath",  // 10– the dragon,   final dungeon (final boss)
}

PlayerProgression :: struct {
	level:          int,
	xp:             int,
	xp_to_next:     int,
	unlocked_moves: int,
	bound_spirits:  [MAX_BOUND_SPIRITS]int,
	bound_count:    int,
	ten_collected:  [MAX_BOUND_SPIRITS]bool,
	pending_move:   int,
	pending_slot:   int,
	just_leveled:   bool,
	// Per-spirit companion data
	spirit_levels:         [MAX_BOUND_SPIRITS]int,
	spirit_xp:             [MAX_BOUND_SPIRITS]int,
	spirit_moves_unlocked: [MAX_BOUND_SPIRITS]int,
	spirit_hp_cur:         [MAX_BOUND_SPIRITS]int, // -1 = full, 0 = fainted
	// Spirit level-up notification (-1 = none pending)
	pending_spirit_slot: int,
	pending_spirit_move: int,
}

g_prog: PlayerProgression

// XP table: xp required to reach each level
xp_table := [?]int{
	0,    // lv1
	30,   // lv2
	80,   // lv3
	160,  // lv4
	280,  // lv5
	450,  // lv6
	680,  // lv7
	980,  // lv8
	1360, // lv9
	1840, // lv10
	2430, // lv11
	3140, // lv12
	9999, // lv13+ cap
}

// Moves Taz learns at each level (tech_id references techniques.csv)
// Level 1: only slot 0 (Soul Punch – id 1)
// Level 3: slot 1 (Soulfire   – id 3)
// Level 5: slot 2 (Bind Pulse – id 5)
// Level 8: slot 3 (Resonance  – id 8)
taz_move_unlocks := [?]MoveUnlock{
	{level = 1, tech_id = 1, slot = 0},
	{level = 3, tech_id = 3, slot = 1},
	{level = 5, tech_id = 5, slot = 2},
	{level = 8, tech_id = 8, slot = 3},
}

init_player_progression :: proc() {
	g_prog = {}
	g_prog.level = 1
	g_prog.xp = 0
	g_prog.xp_to_next = xp_table[1]
	g_prog.unlocked_moves = 1
	g_prog.pending_spirit_slot = -1

	def := get_monster_def(g_player_id)
	if def != nil {
		def.moves[0] = taz_move_unlocks[0].tech_id
	}
}

award_xp :: proc(amount: int) {
	g_prog.xp += amount
	for g_prog.level < 12 && g_prog.xp >= g_prog.xp_to_next {
		level_up()
	}
}

level_up :: proc() {
	g_prog.level += 1
	g_prog.just_leveled = true

	// Set next threshold
	next := g_prog.level
	if next < len(xp_table) {
		g_prog.xp_to_next = xp_table[next]
	}

	// Check for new move unlocks
	for u in taz_move_unlocks {
		if u.level == g_prog.level {
			g_prog.pending_move = u.tech_id
			g_prog.pending_slot = u.slot
			g_prog.unlocked_moves = min(g_prog.unlocked_moves + 1, MOVE_SLOTS)

			// Apply to player monster def
			def := get_monster_def(g_player_id)
			if def != nil {
				def.moves[u.slot] = u.tech_id
			}
		}
	}

	// Scale player monster stats with level
	def := get_monster_def(g_player_id)
	if def != nil {
		bonus := g_prog.level - 1
		def.base_hp      = 60  + bonus * 8
		def.base_attack  = 18  + bonus * 3
		def.base_defense = 10  + bonus * 2
		def.soul_max     = 40  + bonus * 5
	}
}

// Try to bind a spirit after battle (called when enemy HP < 25%)
try_bind_spirit :: proc(enemy_monster_id: int) -> bool {
	if g_prog.bound_count >= MAX_BOUND_SPIRITS do return false
	for i in 0 ..< g_prog.bound_count {
		if g_prog.bound_spirits[i] == enemy_monster_id do return false
	}
	slot := g_prog.bound_count
	g_prog.bound_spirits[slot]         = enemy_monster_id
	g_prog.spirit_levels[slot]         = 1
	g_prog.spirit_xp[slot]             = 0
	g_prog.spirit_moves_unlocked[slot] = 1
	g_prog.spirit_hp_cur[slot]         = -1 // -1 = full HP
	g_prog.bound_count += 1

	def := get_monster_def(enemy_monster_id)
	if def != nil {
		for i in 0 ..< MAX_BOUND_SPIRITS {
			if def.name == TEN_SPIRIT_NAMES[i] {
				g_prog.ten_collected[i] = true
				break
			}
		}
	}
	return true
}

// ── Spirit stat helpers ───────────────────────────────────────────────────

spirit_hp_max_at :: proc(slot: int) -> int {
	if slot < 0 || slot >= g_prog.bound_count do return 1
	def := get_monster_def(g_prog.bound_spirits[slot])
	if def == nil do return 1
	return def.base_hp + (g_prog.spirit_levels[slot] - 1) * 5
}

spirit_attack_at :: proc(slot: int) -> int {
	if slot < 0 || slot >= g_prog.bound_count do return 1
	def := get_monster_def(g_prog.bound_spirits[slot])
	if def == nil do return 1
	return def.base_attack + (g_prog.spirit_levels[slot] - 1) * 2
}

spirit_defense_at :: proc(slot: int) -> int {
	if slot < 0 || slot >= g_prog.bound_count do return 0
	def := get_monster_def(g_prog.bound_spirits[slot])
	if def == nil do return 0
	return def.base_defense + (g_prog.spirit_levels[slot] - 1)
}

spirit_soul_max_at :: proc(slot: int) -> int {
	if slot < 0 || slot >= g_prog.bound_count do return 1
	def := get_monster_def(g_prog.bound_spirits[slot])
	if def == nil do return 1
	return def.soul_max + (g_prog.spirit_levels[slot] - 1) * 2
}

spirit_is_fainted :: proc(slot: int) -> bool {
	if slot < 0 || slot >= g_prog.bound_count do return true
	return g_prog.spirit_hp_cur[slot] == 0
}

award_spirit_xp :: proc(slot: int, amount: int) {
	if slot < 0 || slot >= g_prog.bound_count do return
	g_prog.spirit_xp[slot] += amount
	for g_prog.spirit_levels[slot] < 12 && g_prog.spirit_xp[slot] >= xp_table[g_prog.spirit_levels[slot]] {
		spirit_level_up(slot)
	}
}

spirit_level_up :: proc(slot: int) {
	g_prog.spirit_levels[slot] += 1
	lv := g_prog.spirit_levels[slot]

	unlock_slot := -1
	switch lv {
	case 3: unlock_slot = 1
	case 5: unlock_slot = 2
	case 8: unlock_slot = 3
	}
	if unlock_slot > 0 && g_prog.spirit_moves_unlocked[slot] < unlock_slot + 1 {
		g_prog.spirit_moves_unlocked[slot] = unlock_slot + 1
		def := get_monster_def(g_prog.bound_spirits[slot])
		if def != nil {
			g_prog.pending_spirit_slot = slot
			g_prog.pending_spirit_move = def.moves[unlock_slot]
		}
	}
}

// Removes a spirit slot and shifts all parallel arrays down to keep them in sync.
// Used by fusion and any other system that removes bound spirits.
remove_bound_spirit_at :: proc(idx: int) {
	if idx < 0 || idx >= g_prog.bound_count do return
	for i := idx; i < g_prog.bound_count - 1; i += 1 {
		g_prog.bound_spirits[i]         = g_prog.bound_spirits[i + 1]
		g_prog.spirit_levels[i]         = g_prog.spirit_levels[i + 1]
		g_prog.spirit_xp[i]             = g_prog.spirit_xp[i + 1]
		g_prog.spirit_moves_unlocked[i] = g_prog.spirit_moves_unlocked[i + 1]
		g_prog.spirit_hp_cur[i]         = g_prog.spirit_hp_cur[i + 1]
	}
	last := g_prog.bound_count - 1
	g_prog.bound_spirits[last]         = 0
	g_prog.spirit_levels[last]         = 0
	g_prog.spirit_xp[last]             = 0
	g_prog.spirit_moves_unlocked[last] = 0
	g_prog.spirit_hp_cur[last]         = 0
	g_prog.bound_count -= 1
}

// Restore all spirits to full HP (called by Hub's Rest & Heal).
heal_all_spirits :: proc() {
	for i in 0 ..< g_prog.bound_count {
		g_prog.spirit_hp_cur[i] = -1
	}
}

ten_spirits_complete :: proc() -> bool {
	// All ten collected means we face Veyrath
	for i in 0 ..< 9 { // first 9; Veyrath is the boss itself
		if !g_prog.ten_collected[i] do return false
	}
	return true
}

xp_bar_pct :: proc() -> f32 {
	lvl := g_prog.level
	if lvl >= 12 do return 1.0
	prev := xp_table[lvl - 1]
	next := xp_table[lvl]
	span := next - prev
	if span <= 0 do return 1.0
	return f32(g_prog.xp - prev) / f32(span)
}
