package sb

// ---- affinity helpers ----

affinity_make :: proc(weaks: []SpiritType, resists: []SpiritType, nulls: []SpiritType = nil, absorbs: []SpiritType = nil) -> SpiritAffinity {
	a: SpiritAffinity
	for t in weaks   { a[t] = .Weak }
	for t in resists { a[t] = .Resist }
	for t in nulls   { a[t] = .Null }
	for t in absorbs { a[t] = .Absorb }
	return a
}

// ---- Tier 1 wild spirits ----

spirit_pixie :: proc() -> Spirit {
	return Spirit{
		name = "Pixie", tier = 1, element = .Light,
		base_atk = 8, base_def = 6, base_spd = 8,
		level = 1, skill = .Mend,
		affinity = affinity_make({.Dark}, {.Light, .Nature}),
		evo_level = 5, evo_name = "Fairy Queen",
		active = true,
	}
}

spirit_wisp :: proc() -> Spirit {
	return Spirit{
		name = "Wisp", tier = 1, element = .Light,
		base_atk = 6, base_def = 8, base_spd = 7,
		level = 1, skill = .Ward,
		affinity = affinity_make({.Dark}, {.Light, .Nature}),
		evo_level = 5, evo_name = "Fairy Queen",
		active = true,
	}
}

spirit_imp :: proc() -> Spirit {
	return Spirit{
		name = "Imp", tier = 1, element = .Dark,
		base_atk = 12, base_def = 4, base_spd = 11,
		level = 1, skill = .Taunt,
		affinity = affinity_make({.Light, .Fire}, {.Dark, .Earth}),
		evo_level = 5, evo_name = "Demon Knight",
		active = true,
	}
}

spirit_ember_sprite :: proc() -> Spirit {
	return Spirit{
		name = "Ember Sprite", tier = 1, element = .Fire,
		base_atk = 10, base_def = 5, base_spd = 9,
		level = 1, skill = .Ignite,
		affinity = affinity_make({.Ice, .Water}, {.Fire, .Nature, .Earth}),
		evo_level = 5, evo_name = "Magma Drake",
		active = true,
	}
}

spirit_frost_moth :: proc() -> Spirit {
	return Spirit{
		name = "Frost Moth", tier = 1, element = .Ice,
		base_atk = 9, base_def = 6, base_spd = 10,
		level = 1, skill = .Chill,
		affinity = affinity_make({.Fire}, {.Ice, .Water}),
		evo_level = 5, evo_name = "Winter Wraith",
		active = true,
	}
}

spirit_vine_sprite :: proc() -> Spirit {
	return Spirit{
		name = "Vine Sprite", tier = 1, element = .Nature,
		base_atk = 7, base_def = 9, base_spd = 7,
		level = 1, skill = .Ensnare,
		affinity = affinity_make({.Fire, .Wind}, {.Water, .Earth, .Nature}),
		evo_level = 5, evo_name = "Grove Guardian",
		active = true,
	}
}

spirit_stone_gnome :: proc() -> Spirit {
	return Spirit{
		name = "Stone Gnome", tier = 1, element = .Earth,
		base_atk = 6, base_def = 14, base_spd = 4,
		level = 1, skill = .Fortify,
		affinity = affinity_make({.Wind, .Water}, {.Fire, .Earth}),
		evo_level = 5, evo_name = "Granite Titan",
		active = true,
	}
}

spirit_screech_bat :: proc() -> Spirit {
	return Spirit{
		name = "Screech Bat", tier = 1, element = .Dark,
		base_atk = 11, base_def = 5, base_spd = 13,
		level = 1, skill = .Blind,
		affinity = affinity_make({.Light, .Fire}, {.Dark, .Earth}),
		evo_level = 5, evo_name = "Shadow Drake",
		active = true,
	}
}

// ---- Tier 2 (evolution targets — via level-up) ----

spirit_fairy_queen :: proc() -> Spirit {
	return Spirit{
		name = "Fairy Queen", tier = 2, element = .Light,
		base_atk = 16, base_def = 14, base_spd = 12,
		level = 1, skill = .Radiance,
		affinity = affinity_make({.Dark}, {.Light, .Nature}),
		active = true,
	}
}

spirit_demon_knight :: proc() -> Spirit {
	return Spirit{
		name = "Demon Knight", tier = 2, element = .Dark,
		base_atk = 20, base_def = 10, base_spd = 14,
		level = 1, skill = .DarkSlash,
		affinity = affinity_make({.Light}, {.Dark, .Earth}),
		active = true,
	}
}

spirit_magma_drake :: proc() -> Spirit {
	return Spirit{
		name = "Magma Drake", tier = 2, element = .Fire,
		base_atk = 22, base_def = 8, base_spd = 10,
		level = 1, skill = .MagmaBurst,
		affinity = affinity_make({.Ice, .Water}, {.Fire, .Earth}),
		active = true,
	}
}

spirit_winter_wraith :: proc() -> Spirit {
	return Spirit{
		name = "Winter Wraith", tier = 2, element = .Ice,
		base_atk = 18, base_def = 12, base_spd = 13,
		level = 1, skill = .Blizzard,
		affinity = affinity_make({.Fire}, {.Ice, .Water}),
		active = true,
	}
}

spirit_grove_guardian :: proc() -> Spirit {
	return Spirit{
		name = "Grove Guardian", tier = 2, element = .Nature,
		base_atk = 14, base_def = 20, base_spd = 6,
		level = 1, skill = .Overgrowth,
		affinity = affinity_make({.Fire, .Wind}, {.Water, .Earth, .Nature}),
		active = true,
	}
}

spirit_granite_titan :: proc() -> Spirit {
	return Spirit{
		name = "Granite Titan", tier = 2, element = .Earth,
		base_atk = 10, base_def = 26, base_spd = 3,
		level = 1, skill = .Quake,
		affinity = affinity_make({.Wind, .Water}, {.Fire, .Earth}),
		active = true,
	}
}

spirit_tide_spirit :: proc() -> Spirit {
	return Spirit{
		name = "Tide Spirit", tier = 2, element = .Water,
		base_atk = 14, base_def = 16, base_spd = 9,
		level = 1, skill = .TidalWave,
		affinity = affinity_make({.Wind, .Nature}, {.Water, .Fire, .Ice}),
		active = true,
	}
}

spirit_shadow_drake :: proc() -> Spirit {
	return Spirit{
		name = "Shadow Drake", tier = 2, element = .Dark,
		base_atk = 22, base_def = 10, base_spd = 16,
		level = 1, skill = .FearShriek,
		affinity = affinity_make({.Light}, {.Dark, .Earth}),
		active = true,
	}
}

// ---- Tier 2 (fusion-only) ----

spirit_sylph :: proc() -> Spirit {
	return Spirit{
		name = "Sylph", tier = 2, element = .Wind,
		base_atk = 14, base_def = 8, base_spd = 15,
		level = 1, skill = .Gust,
		affinity = affinity_make({.Earth}, {.Wind, .Nature}),
		active = true,
	}
}

spirit_ignis :: proc() -> Spirit {
	return Spirit{
		name = "Ignis", tier = 2, element = .Fire,
		base_atk = 18, base_def = 7, base_spd = 11,
		level = 1, skill = .Flare,
		affinity = affinity_make({.Ice, .Water}, {.Fire, .Earth}),
		active = true,
	}
}

spirit_thornwarden :: proc() -> Spirit {
	return Spirit{
		name = "Thornwarden", tier = 2, element = .Nature,
		base_atk = 10, base_def = 18, base_spd = 5,
		level = 1, skill = .Thorns,
		affinity = affinity_make({.Fire, .Wind}, {.Nature, .Water}),
		active = true,
	}
}

spirit_dusk_shade :: proc() -> Spirit {
	return Spirit{
		name = "Dusk Shade", tier = 2, element = .Dark,
		base_atk = 16, base_def = 8, base_spd = 14,
		level = 1, skill = .SoulDrain,
		affinity = affinity_make({.Light}, {.Dark}),
		active = true,
	}
}

spirit_undine :: proc() -> Spirit {
	return Spirit{
		name = "Undine", tier = 2, element = .Water,
		base_atk = 12, base_def = 12, base_spd = 10,
		level = 1, skill = .Cleanse,
		affinity = affinity_make({.Wind, .Nature}, {.Water, .Fire, .Ice}),
		active = true,
	}
}

spirit_seraph_fledge :: proc() -> Spirit {
	return Spirit{
		name = "Seraph Fledge", tier = 2, element = .Light,
		base_atk = 15, base_def = 12, base_spd = 12,
		level = 1, skill = .Smite,
		affinity = affinity_make({.Dark}, {.Light, .Nature}),
		active = true,
	}
}

// ---- Tier 3 (boss, bind-only) ----

spirit_vexor :: proc() -> Spirit {
	return Spirit{
		name = "Vexor", tier = 3, element = .Alien,
		base_atk = 28, base_def = 20, base_spd = 8,
		level = 12, skill = .PsiBlast,
		affinity = affinity_make({.Light}, {.Ice, .Nature, .Dark}, {.Earth, .Wind, .Water}),
		bind_bonus_atk = 25,
		active = true,
	}
}

// ---- spirit lookup by name (for evolution) ----

spirit_by_name :: proc(name: string) -> Spirit {
	switch name {
	case "Fairy Queen":   return spirit_fairy_queen()
	case "Demon Knight":  return spirit_demon_knight()
	case "Magma Drake":   return spirit_magma_drake()
	case "Winter Wraith": return spirit_winter_wraith()
	case "Grove Guardian":return spirit_grove_guardian()
	case "Granite Titan": return spirit_granite_titan()
	case "Tide Spirit":   return spirit_tide_spirit()
	case "Shadow Drake":  return spirit_shadow_drake()
	}
	return {}
}

// ---- enemy templates ----

enemy_pixie_wild :: proc() -> Enemy {
	return Enemy{
		name = "Wild Pixie",
		hp = 30, max_hp = 30, atk = 6, def = 4, spd = 8,
		level = 1, xp_reward = 20, gold_reward = 5,
		spirit_template = spirit_pixie(),
		talk_mood = .Law,
	}
}

enemy_imp_wild :: proc() -> Enemy {
	return Enemy{
		name = "Wild Imp",
		hp = 40, max_hp = 40, atk = 10, def = 3, spd = 11,
		level = 2, xp_reward = 30, gold_reward = 8,
		spirit_template = spirit_imp(),
		talk_mood = .Chaos,
	}
}

enemy_ember_sprite_wild :: proc() -> Enemy {
	return Enemy{
		name = "Wild Ember Sprite",
		hp = 35, max_hp = 35, atk = 8, def = 3, spd = 9,
		level = 2, xp_reward = 25, gold_reward = 6,
		spirit_template = spirit_ember_sprite(),
		talk_mood = .Chaos,
	}
}

enemy_stone_gnome_wild :: proc() -> Enemy {
	return Enemy{
		name = "Wild Stone Gnome",
		hp = 50, max_hp = 50, atk = 5, def = 10, spd = 4,
		level = 3, xp_reward = 35, gold_reward = 10,
		spirit_template = spirit_stone_gnome(),
		talk_mood = .Neutral,
	}
}

enemy_frost_moth_wild :: proc() -> Enemy {
	return Enemy{
		name = "Wild Frost Moth",
		hp = 38, max_hp = 38, atk = 7, def = 5, spd = 10,
		level = 2, xp_reward = 28, gold_reward = 7,
		spirit_template = spirit_frost_moth(),
		talk_mood = .Neutral,
	}
}

enemy_screech_bat_wild :: proc() -> Enemy {
	return Enemy{
		name = "Wild Screech Bat",
		hp = 36, max_hp = 36, atk = 9, def = 4, spd = 13,
		level = 2, xp_reward = 26, gold_reward = 7,
		spirit_template = spirit_screech_bat(),
		talk_mood = .Chaos,
	}
}

enemy_vexor :: proc() -> Enemy {
	return Enemy{
		name = "Vexor",
		hp = 380, max_hp = 380, atk = 28, def = 20, spd = 8,
		level = 12, xp_reward = 500, gold_reward = 100,
		spirit_template = spirit_vexor(),
		talk_mood = .Neutral,
	}
}

// ---- skill metadata ----

skill_name :: proc(s: SkillID) -> string {
	switch s {
	case .Mend:      return "Mend"
	case .Ward:      return "Ward"
	case .Taunt:     return "Taunt"
	case .Ignite:    return "Ignite"
	case .Chill:     return "Chill"
	case .Ensnare:   return "Ensnare"
	case .Fortify:   return "Fortify"
	case .Blind:     return "Blind"
	case .Gust:      return "Gust"
	case .Flare:     return "Flare"
	case .Cleanse:   return "Cleanse"
	case .SoulDrain: return "Soul Drain"
	case .Thorns:    return "Thorns"
	case .StoneSkin: return "Stone Skin"
	case .Smite:     return "Smite"
	case .PsiBlast:  return "Psi Blast"
	case .Radiance:  return "Radiance"
	case .DarkSlash: return "Dark Slash"
	case .MagmaBurst:return "Magma Burst"
	case .Blizzard:  return "Blizzard"
	case .Overgrowth:return "Overgrowth"
	case .Quake:     return "Quake"
	case .TidalWave: return "Tidal Wave"
	case .FearShriek:return "Fear Shriek"
	case .None:      return "---"
	}
	return "???"
}

skill_description :: proc(s: SkillID) -> string {
	switch s {
	case .Mend:      return "Heal 15% max HP"
	case .Ward:      return "Reduce incoming dmg by 5"
	case .Taunt:     return "Draw focus, ATK+2"
	case .Ignite:    return "Fire dmg +4"
	case .Chill:     return "Ice dmg, slows enemy"
	case .Ensnare:   return "Nature dmg, binds enemy"
	case .Fortify:   return "DEF +20% for 3 turns"
	case .Blind:     return "Dark dmg, reduces ACC"
	case .Gust:      return "Wind dmg +6"
	case .Flare:     return "Heavy Fire dmg +10"
	case .Cleanse:   return "Remove all debuffs"
	case .SoulDrain: return "Dark dmg +5, steal HP"
	case .Thorns:    return "Reflect 15% dmg taken"
	case .StoneSkin: return "Absorb next 1 hit"
	case .Smite:     return "Light dmg +8, stun chance"
	case .PsiBlast:  return "Alien dmg +15, stun chance"
	case .Radiance:  return "Light AoE +9, stun chance"
	case .DarkSlash: return "Dark dmg +8, armor shred"
	case .MagmaBurst:return "Fire dmg +12, burn DoT"
	case .Blizzard:  return "Ice AoE +8, freeze"
	case .Overgrowth:return "Nature dmg +4, entangle"
	case .Quake:     return "Earth AoE +10, DEF break"
	case .TidalWave: return "Water AoE +7"
	case .FearShriek:return "Dark dmg +6, ATK -3 debuff"
	case .None:      return "No skill"
	}
	return "???"
}

skill_base_damage_bonus :: proc(sk: SkillID) -> int {
	#partial switch sk {
	case .Taunt:     return 2
	case .Ignite:    return 4
	case .Ensnare:   return 0
	case .Blind:     return 0
	case .Chill:     return 0
	case .Gust:      return 6
	case .Flare:     return 10
	case .SoulDrain: return 5
	case .Smite:     return 8
	case .PsiBlast:  return 15
	case .Radiance:  return 9
	case .DarkSlash: return 8
	case .MagmaBurst:return 12
	case .Blizzard:  return 8
	case .Overgrowth:return 4
	case .Quake:     return 10
	case .TidalWave: return 7
	case .FearShriek:return 6
	}
	return 0
}

skill_cooldown_val :: proc(sk: SkillID) -> int {
	#partial switch sk {
	case .Taunt, .Blind, .FearShriek:
		return 1
	case .Mend, .Ward, .Ignite, .Gust, .SoulDrain, .Smite, .Cleanse, .Radiance, .DarkSlash:
		return 2
	case .Chill, .Ensnare, .Fortify, .Flare, .Thorns, .StoneSkin, .PsiBlast,
	     .MagmaBurst, .Blizzard, .Overgrowth, .Quake, .TidalWave:
		return 3
	}
	return 2
}

skill_is_offensive :: proc(sk: SkillID) -> bool {
	#partial switch sk {
	case .Mend, .Ward, .Fortify, .Cleanse, .Thorns, .StoneSkin, .None:
		return false
	}
	return true
}

// ---- stat helpers ----

spirit_atk :: proc(s: ^Spirit) -> int { return s.base_atk + (s.level - 1) * 2 }
spirit_def :: proc(s: ^Spirit) -> int { return s.base_def + (s.level - 1) * 2 }
spirit_spd :: proc(s: ^Spirit) -> int { return s.base_spd + (s.level - 1) }

xp_to_level :: proc(level: int) -> int { return level * 30 }

spirit_add_xp :: proc(s: ^Spirit, amount: int) -> bool {
	if s == nil || !s.active do return false
	s.xp += amount
	threshold := xp_to_level(s.level)
	if s.xp >= threshold {
		s.xp -= threshold
		s.level += 1
		return true
	}
	return false
}

summoner_xp_threshold :: proc(level: int) -> int { return level * 50 }

summoner_add_xp :: proc(g: ^GameState, amount: int) -> bool {
	g.summoner.xp += amount
	threshold := summoner_xp_threshold(g.summoner.level)
	if g.summoner.xp >= threshold {
		g.summoner.xp -= threshold
		g.summoner.level += 1
		g.summoner.max_hp += 8
		g.summoner.hp = min(g.summoner.hp + 8, g.summoner.max_hp)
		return true
	}
	return false
}

summoner_total_atk :: proc(g: ^GameState) -> int {
	total := 0
	for i in 0..<6 {
		s := g.summoner.spirits[i]
		if s != nil && s.active do total += spirit_atk(s)
	}
	return total
}

spirit_type_color :: proc(t: SpiritType) -> [4]u8 {
	switch t {
	case .Light:  return {255, 255, 180, 255}
	case .Dark:   return {180, 100, 220, 255}
	case .Fire:   return {255, 120,  40, 255}
	case .Ice:    return {140, 200, 255, 255}
	case .Nature: return { 80, 200,  80, 255}
	case .Earth:  return {180, 140,  80, 255}
	case .Wind:   return {180, 255, 220, 255}
	case .Water:  return { 80, 160, 255, 255}
	case .Alien:  return {200,  80, 255, 255}
	}
	return {200, 200, 200, 255}
}

alignment_color :: proc(a: Alignment) -> [4]u8 {
	switch a {
	case .Law:     return {100, 180, 255, 255}
	case .Neutral: return {200, 200, 200, 255}
	case .Chaos:   return {255,  80,  80, 255}
	}
	return {200, 200, 200, 255}
}

alignment_name :: proc(a: Alignment) -> string {
	switch a {
	case .Law:     return "LAW"
	case .Neutral: return "NEUTRAL"
	case .Chaos:   return "CHAOS"
	}
	return "???"
}
