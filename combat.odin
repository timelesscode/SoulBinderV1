package sb

import "core:fmt"
import "core:math/rand"
import "core:strings"

combat_log_add :: proc(log: ^CombatLog, msg: string) {
	if len(log.lines) >= 7 {
		ordered_remove(&log.lines, 0)
	}
	append(&log.lines, strings.clone(msg))
}

// ---- type effectiveness ----

affinity_result :: proc(aff: Affinity) -> (multiplier_pct: int, is_weakness: bool) {
	switch aff {
	case .Weak:    return 150, true
	case .Resist:  return 50,  false
	case .Null:    return 0,   false
	case .Absorb:  return -50, false // heals target
	case .Reflect: return -75, false // hurts attacker
	case .Normal:  return 100, false
	}
	return 100, false
}

affinity_tag :: proc(aff: Affinity) -> string {
	switch aff {
	case .Weak:    return " [WEAK!]"
	case .Resist:  return " [Resist]"
	case .Null:    return " [NULL]"
	case .Absorb:  return " [ABSORB]"
	case .Reflect: return " [REFLECT]"
	case .Normal:  return ""
	}
	return ""
}

// ---- SPD helpers ----

get_player_avg_spd :: proc(g: ^GameState) -> int {
	total, count := 0, 0
	for i in 0..<6 {
		s := g.summoner.spirits[i]
		if s != nil && s.active {
			total += spirit_spd(s)
			count += 1
		}
	}
	if count == 0 do return 0
	return total / count
}

// ---- combat start ----

start_combat :: proc(g: ^GameState, e: Enemy) {
	g.enemy           = e
	g.in_combat       = true
	g.bind_available  = false
	g.talk_available  = true
	g.player_turn     = true
	g.combat_over     = false
	g.combat_won      = false
	g.bind_success    = false
	g.bonus_action    = false
	g.bonus_action_used = false
	g.enemy_enraged   = false
	g.negotiate_done  = false
	g.negotiate_result = ""
	g.selected_skill_idx = 0
	clear(&g.combat_log.lines)

	player_spd := get_player_avg_spd(g)
	if e.spd > player_spd {
		combat_log_add(&g.combat_log,
			fmt.tprintf("%s strikes first! (SPD %d > %d)", e.name, e.spd, player_spd))
		emsg := enemy_attack(g)
		if emsg != "" do combat_log_add(&g.combat_log, emsg)
	} else if player_spd > e.spd {
		combat_log_add(&g.combat_log,
			fmt.tprintf("You move first! (SPD %d > %d) A %s appeared!", player_spd, e.spd, e.name))
	} else {
		combat_log_add(&g.combat_log, fmt.tprintf("A wild %s appeared!", e.name))
	}
}

// ---- player skill use ----

calc_damage :: proc(atk: int, def: int, base: int) -> int {
	raw := atk + base - def
	if raw < 1 do return 1
	return raw
}

mark_bind_threshold :: proc(g: ^GameState) {
	if g.enemy.hp > 0 && g.enemy.hp <= g.enemy.max_hp * 25 / 100 {
		g.bind_available = true
	}
}

player_use_skill :: proc(g: ^GameState, spirit_idx: int) -> (msg: string, weakness_hit: bool) {
	s := g.summoner.spirits[spirit_idx]
	if s == nil || !s.active   do return "No spirit in that slot!", false
	if s.cooldown > 0          do return fmt.tprintf("%s on cooldown (%d turns)", s.name, s.cooldown), false

	skill := s.skill

	// --- support / buff skills: no type effectiveness ---
	#partial switch skill {
	case .Mend:
		heal := g.summoner.max_hp * 15 / 100
		g.summoner.hp = min(g.summoner.hp + heal, g.summoner.max_hp)
		s.cooldown = skill_cooldown_val(skill)
		spirit_add_xp(s, 15)
		mark_bind_threshold(g)
		return fmt.tprintf("%s casts Mend! Healed %d HP.", s.name, heal), false
	case .Ward:
		s.cooldown = skill_cooldown_val(skill)
		spirit_add_xp(s, 15)
		mark_bind_threshold(g)
		return fmt.tprintf("%s casts Ward! Damage reduced next hit.", s.name), false
	case .Fortify:
		s.cooldown = skill_cooldown_val(skill)
		spirit_add_xp(s, 15)
		mark_bind_threshold(g)
		return fmt.tprintf("%s fortifies! DEF +20%% for 3 turns.", s.name), false
	case .Cleanse:
		s.cooldown = skill_cooldown_val(skill)
		spirit_add_xp(s, 15)
		mark_bind_threshold(g)
		return fmt.tprintf("%s cleanses all debuffs!", s.name), false
	case .Thorns:
		s.cooldown = skill_cooldown_val(skill)
		spirit_add_xp(s, 15)
		mark_bind_threshold(g)
		return fmt.tprintf("%s activates Thorns! 15%% dmg reflected.", s.name), false
	case .StoneSkin:
		s.cooldown = skill_cooldown_val(skill)
		spirit_add_xp(s, 15)
		mark_bind_threshold(g)
		return fmt.tprintf("%s activates Stone Skin! Next hit absorbed.", s.name), false
	case .None:
		return "That spirit has no skill.", false
	}

	// --- offensive skills: apply type effectiveness ---
	base_bonus := skill_base_damage_bonus(skill)
	raw_dmg    := calc_damage(spirit_atk(s), g.enemy.def, base_bonus)

	aff     := g.enemy.spirit_template.affinity[s.element]
	mult, wh := affinity_result(aff)
	tag      := affinity_tag(aff)

	switch aff {
	case .Null:
		s.cooldown = skill_cooldown_val(skill)
		spirit_add_xp(s, 5)
		mark_bind_threshold(g)
		return fmt.tprintf("%s uses %s — NULLED! No effect.", s.name, skill_name(skill)), false

	case .Absorb:
		heal := raw_dmg / 2
		g.enemy.hp = min(g.enemy.hp + heal, g.enemy.max_hp)
		s.cooldown = skill_cooldown_val(skill)
		spirit_add_xp(s, 5)
		mark_bind_threshold(g)
		return fmt.tprintf("%s uses %s — ABSORBED! Enemy heals %d HP!", s.name, skill_name(skill), heal), false

	case .Reflect:
		self_dmg := raw_dmg * 3 / 4
		g.summoner.hp -= self_dmg
		if g.summoner.hp < 0 do g.summoner.hp = 0
		s.cooldown = skill_cooldown_val(skill)
		spirit_add_xp(s, 5)
		mark_bind_threshold(g)
		return fmt.tprintf("%s uses %s — REFLECTED! You take %d dmg!", s.name, skill_name(skill), self_dmg), false

	case .Weak, .Resist, .Normal:
		final_dmg := raw_dmg * mult / 100
		if final_dmg < 1 do final_dmg = 1
		g.enemy.hp -= final_dmg
		if g.enemy.hp < 0 do g.enemy.hp = 0
		s.cooldown = skill_cooldown_val(skill)
		spirit_add_xp(s, 15)
		mark_bind_threshold(g)

		// SoulDrain heals summoner
		if skill == .SoulDrain {
			steal := final_dmg / 2
			g.summoner.hp = min(g.summoner.hp + steal, g.summoner.max_hp)
			return fmt.tprintf("%s uses %s! %d dmg, steal %d HP.%s",
				s.name, skill_name(skill), final_dmg, steal, tag), wh
		}
		// FearShriek debuffs enemy ATK (reflected in enraged flag as negative)
		if skill == .FearShriek && g.enemy.atk > 3 {
			g.enemy.atk -= 3
		}

		return fmt.tprintf("%s uses %s! %d damage.%s",
			s.name, skill_name(skill), final_dmg, tag), wh
	}

	return "Skill error.", false
}

// ---- enemy attack ----

enemy_attack :: proc(g: ^GameState) -> string {
	if g.enemy.hp <= 0 do return ""
	bonus := 0
	if g.enemy_enraged do bonus = 5
	dmg := calc_damage(g.enemy.atk + bonus, 5, rand.int_max(5))
	g.summoner.hp -= dmg
	if g.summoner.hp < 0 do g.summoner.hp = 0
	if g.enemy_enraged {
		return fmt.tprintf("%s attacks ENRAGED for %d damage!", g.enemy.name, dmg)
	}
	return fmt.tprintf("%s attacks for %d damage!", g.enemy.name, dmg)
}

// ---- bind ----

attempt_bind :: proc(g: ^GameState) -> (success: bool, msg: string) {
	if !g.bind_available {
		return false, "Enemy is not weak enough to bind! (<25% HP)"
	}
	light_bonus := 0
	for i in 0..<6 {
		s := g.summoner.spirits[i]
		if s != nil && s.active && s.element == .Light {
			light_bonus += spirit_atk(s) / 4
		}
	}
	base_rate := 40 + (g.summoner.level + light_bonus - g.enemy.level) * 5
	base_rate  = clamp(base_rate, 10, 95)
	roll := rand.int_max(100)
	if roll < base_rate {
		g.summoner.alignment_pts += 2
		update_alignment(g)
		return true, fmt.tprintf("BIND SUCCEEDS! (%d%%) %s absorbed into your soul!", base_rate, g.enemy.name)
	}
	return false, fmt.tprintf("Bind failed! (%d%% chance, rolled %d) — enemy fights on.", base_rate, roll)
}

// ---- negotiation ----

enemy_talk_line :: proc(mood: Alignment) -> string {
	switch mood {
	case .Law:     return "Prove your worth before making demands of me."
	case .Chaos:   return "Ha! You want something from ME? Make it interesting!"
	case .Neutral: return "What do you want, mortal? Speak quickly."
	}
	return "..."
}

attempt_negotiate :: proc(g: ^GameState, opt: NegotiateOption) -> (success: bool, msg: string) {
	switch opt {
	case .Offer_Gold:
		cost := 50 * g.enemy.spirit_template.tier
		if g.summoner.gold >= cost {
			g.summoner.gold -= cost
			g.summoner.alignment_pts -= 5
			update_alignment(g)
			return true, fmt.tprintf("Offered %d gold — %s agrees to join!", cost, g.enemy.name)
		}
		return false, fmt.tprintf("Need %d gold to recruit %s. (have %d)", cost, g.enemy.name, g.summoner.gold)

	case .Beg:
		base := 40
		if g.summoner.level < g.enemy.level  do base += 15
		if g.enemy.talk_mood == .Chaos        do base += 10
		base = clamp(base, 5, 90)
		if rand.int_max(100) < base {
			g.summoner.alignment_pts -= 3
			update_alignment(g)
			return true, fmt.tprintf("You beg pathetically. %s finds it amusing. (%d%%)", g.enemy.name, base)
		}
		return false, fmt.tprintf("Begging failed (%d%%) — %s is disgusted.", base, g.enemy.name)

	case .Flatter:
		base := 45
		if g.enemy.talk_mood == .Law   do base += 20
		if g.enemy.talk_mood == .Chaos do base -= 10
		base = clamp(base, 5, 90)
		if rand.int_max(100) < base {
			g.summoner.alignment_pts += 2
			update_alignment(g)
			return true, fmt.tprintf("Your flattery pleases %s. (%d%%)", g.enemy.name, base)
		}
		return false, fmt.tprintf("Flattery failed (%d%%) — %s sees through you.", base, g.enemy.name)

	case .Threaten:
		base := 30
		if g.summoner.alignment == .Chaos  do base += 30
		if g.enemy.talk_mood == .Law       do base -= 20
		if g.summoner.level > g.enemy.level do base += 10
		base = clamp(base, 5, 85)
		if rand.int_max(100) < base {
			g.summoner.alignment_pts -= 5
			update_alignment(g)
			return true, fmt.tprintf("You threaten %s into submission! (%d%%)", g.enemy.name, base)
		}
		return false, fmt.tprintf("Threat failed (%d%%) — %s is angered!", base, g.enemy.name)
	}
	return false, "Unknown option."
}

// ---- alignment ----

update_alignment :: proc(g: ^GameState) {
	g.summoner.alignment_pts = clamp(g.summoner.alignment_pts, -100, 100)
	pts := g.summoner.alignment_pts
	if pts > 33 {
		g.summoner.alignment = .Law
	} else if pts < -33 {
		g.summoner.alignment = .Chaos
	} else {
		g.summoner.alignment = .Neutral
	}
}

// ---- evolution ----

check_and_evolve :: proc(g: ^GameState) -> string {
	for i in 0..<6 {
		s := g.summoner.spirits[i]
		if s == nil || !s.active          do continue
		if s.evo_level <= 0               do continue
		if s.level < s.evo_level          do continue
		evo := spirit_by_name(s.evo_name)
		if evo.name == ""                 do continue
		old_name := s.name
		saved_level := s.level
		saved_xp    := s.xp
		s^      = evo
		s.level = saved_level
		s.xp    = saved_xp
		return fmt.tprintf("*** %s evolved into %s! ***", old_name, s.name)
	}
	return ""
}

// ---- end-of-round ----

tick_cooldowns :: proc(g: ^GameState) {
	for i in 0..<6 {
		s := g.summoner.spirits[i]
		if s != nil && s.cooldown > 0 do s.cooldown -= 1
	}
	g.bonus_action_used = false
}

award_combat_xp :: proc(g: ^GameState, e: ^Enemy) {
	for i in 0..<6 {
		s := g.summoner.spirits[i]
		if s != nil && s.active do spirit_add_xp(s, e.xp_reward / 3)
	}
	summoner_add_xp(g, e.xp_reward)
	g.summoner.gold += e.gold_reward
	// check for evolutions
	evo_msg := check_and_evolve(g)
	if evo_msg != "" do combat_log_add(&g.combat_log, evo_msg)
}

// ---- spirit slot management ----

bind_to_slot :: proc(g: ^GameState, tmpl: Spirit) -> int {
	for i in 0..<6 {
		if g.summoner.spirits[i] == nil {
			s  := new(Spirit)
			s^ = tmpl
			g.summoner.spirits[i] = s
			return i
		}
	}
	return -1
}

filled_slots :: proc(g: ^GameState) -> int {
	count := 0
	for i in 0..<6 {
		if g.summoner.spirits[i] != nil do count += 1
	}
	return count
}

release_spirit :: proc(g: ^GameState, idx: int) {
	if g.summoner.spirits[idx] != nil {
		free(g.summoner.spirits[idx])
		g.summoner.spirits[idx] = nil
	}
}

// ---- encounter pool ----

get_encounter :: proc(run: int) -> Enemy {
	if run >= 5 do return enemy_vexor()
	pool := [6]Enemy{
		enemy_pixie_wild(),
		enemy_imp_wild(),
		enemy_ember_sprite_wild(),
		enemy_stone_gnome_wild(),
		enemy_frost_moth_wild(),
		enemy_screech_bat_wild(),
	}
	return pool[run % 6]
}
