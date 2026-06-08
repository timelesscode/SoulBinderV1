package main

import "core:fmt"
import "core:math/rand"
import rl "vendor:raylib"

MAX_ITEM_TYPES :: 8
MAX_LOG        :: 200

BattlePhase :: enum {
	Choose_Action,
	Choose_Move,
	Choose_Item,
	Choose_Spirit,  // pick a bound spirit to fight for you
	Show_Message,
	Enemy_Turn,
	Victory,
	Defeat,
	Fled,
	Bind_Attempt,
	Bind_Success,
}

BattleMonster :: struct {
	def_id:    int,
	name:      string,
	hp:        int,
	hp_max:    int,
	soul:      int,
	soul_max:  int,
	attack:    int,
	defense:   int,
	mon_type:  TechType,
	spirit_id: int,
	moves:     [MOVE_SLOTS]int,
}

make_battle_monster :: proc(def: ^MonsterDef) -> BattleMonster {
	lvl_bonus := g_prog.level - 1

	// Depth scaling: enemies in later levels hit harder
	depth_scale : f32 = 1.0
	if g_world.model_loaded && g_world.level_idx >= 0 {
		depth_scale = 1.0 + f32(g_world.level_idx) * 0.15
	}
	// Time scaling: the longer you linger, the fiercer enemies become
	time_scale := 1.0 + min(g_world.time_in_level, 300.0) / 750.0

	total := depth_scale * time_scale
	hp   := int(f32(def.base_hp   + lvl_bonus * 4) * total)
	atk  := int(f32(def.base_attack + lvl_bonus * 2) * total)
	def2 := int(f32(def.base_defense + lvl_bonus)   * total)

	return BattleMonster{
		def_id    = def.id,
		name      = def.name,
		hp        = hp,
		hp_max    = hp,
		soul      = def.soul_max,
		soul_max  = def.soul_max,
		attack    = atk,
		defense   = def2,
		mon_type  = def.mon_type,
		spirit_id = def.spirit_id,
		moves     = def.moves,
	}
}

// Returns the currently active fighter (spirit companion or Taz himself).
active_fighter :: proc() -> ^BattleMonster {
	if g_battle.active_is_spirit do return &g_battle.spirit_fighter
	return &g_battle.player
}

active_moves_unlocked :: proc() -> int {
	if g_battle.active_is_spirit {
		s := g_battle.active_spirit_slot
		if s >= 0 && s < g_prog.bound_count do return g_prog.spirit_moves_unlocked[s]
	}
	return g_prog.unlocked_moves
}

make_spirit_fighter :: proc(slot: int) -> BattleMonster {
	def := get_monster_def(g_prog.bound_spirits[slot])
	if def == nil do return {}
	hp_max := spirit_hp_max_at(slot)
	hp     := g_prog.spirit_hp_cur[slot]
	if hp < 0 || hp > hp_max do hp = hp_max
	return BattleMonster{
		def_id    = def.id,
		name      = def.name,
		hp        = hp,
		hp_max    = hp_max,
		soul      = spirit_soul_max_at(slot),
		soul_max  = spirit_soul_max_at(slot),
		attack    = spirit_attack_at(slot),
		defense   = spirit_defense_at(slot),
		mon_type  = def.mon_type,
		spirit_id = def.spirit_id,
		moves     = def.moves,
	}
}

do_summon_spirit :: proc(slot: int) {
	if slot < 0 || slot >= g_prog.bound_count do return
	if spirit_is_fainted(slot) {
		def := get_monster_def(g_prog.bound_spirits[slot])
		name := def.name if def != nil else "Spirit"
		show_message(fmt.tprintf("%s has fainted! Rest at the Hub first.", name), .Choose_Action)
		return
	}
	g_battle.spirit_fighter     = make_spirit_fighter(slot)
	g_battle.active_is_spirit   = true
	g_battle.active_spirit_slot = slot
	show_message(fmt.tprintf("Come forth, %s!", g_battle.spirit_fighter.name), .Enemy_Turn)
}

do_recall_spirit :: proc() {
	if !g_battle.active_is_spirit do return
	slot := g_battle.active_spirit_slot
	g_prog.spirit_hp_cur[slot] = g_battle.spirit_fighter.hp
	g_battle.active_is_spirit  = false
	show_message(fmt.tprintf("%s, stand down!", g_battle.spirit_fighter.name), .Choose_Action)
}

roll_item_drop :: proc() {
	g_battle.item_drop_rolled = true
	if rand.float32() > 0.40 || g_db.item_count == 0 do return
	// Weighted: lower item id = more common drop
	total_weight := 0
	for i in 0 ..< g_db.item_count {
		total_weight += max(1, g_db.item_count - i + 1)
	}
	roll := rand.int_max(total_weight)
	cumulative := 0
	for i in 0 ..< g_db.item_count {
		cumulative += max(1, g_db.item_count - i + 1)
		if roll < cumulative {
			g_battle.item_drop_id = g_db.items[i].id
			return
		}
	}
}

Battle :: struct {
	player:        BattleMonster,
	enemy:         BattleMonster,
	phase:         BattlePhase,
	next_phase:    BattlePhase,
	action_cursor: int,
	move_cursor:   int,
	item_cursor:   int,
	spirit_cursor: int,
	item_qty:      [MAX_ITEM_TYPES]int,
	log:           [MAX_LOG]byte,
	log_len:       int,
	can_bind:      bool,
	already_bound: bool,
	bind_flash:    f32,
	xp_earned:     int,
	gold_earned:   int,
	// Spirit companion
	active_is_spirit:   bool,
	active_spirit_slot: int,          // -1 = no spirit summoned this battle
	spirit_fighter:     BattleMonster,
	// Item drop on victory
	item_drop_id:      int,
	item_drop_rolled:  bool,
}

g_battle: Battle

set_log_str :: proc(msg: string) {
	n := min(len(msg), MAX_LOG - 1)
	copy(g_battle.log[:], msg[:n])
	g_battle.log_len = n
}

get_log :: proc() -> string {
	return string(g_battle.log[:g_battle.log_len])
}

show_message :: proc(msg: string, next: BattlePhase) {
	set_log_str(msg)
	g_battle.next_phase = next
	g_battle.phase = .Show_Message
}

type_multiplier :: proc(attack, defend: TechType) -> int {
	if attack == defend do return 10
	switch attack {
	case .Fire:
		if defend == .Nature do return 15
		if defend == .Water  do return 7
	case .Water:
		if defend == .Fire   do return 15
		if defend == .Nature do return 7
	case .Nature:
		if defend == .Water  do return 15
		if defend == .Fire   do return 7
	case .Dark:
		if defend == .Psychic do return 15
	case .Psychic:
		if defend == .Dark   do return 7
	case .Kinetic:
	}
	return 10
}

calc_damage :: proc(attacker: ^BattleMonster, tech: ^TechniqueDef, defender: ^BattleMonster) -> int {
	base := attacker.attack * tech.power / 40
	base -= defender.defense / 6
	if base < 1 do base = 1
	mult := type_multiplier(tech.tech_type, defender.mon_type)
	dmg := base * mult / 10
	if dmg < 1 do dmg = 1
	return dmg
}

random_enemy_id :: proc(exclude: int) -> int {
	for tries := 0; tries < 16; tries += 1 {
		idx := rand.int_max(g_db.monster_count)
		id  := g_db.monsters[idx].id
		if id != exclude && g_db.monsters[idx].name != "Veyrath" do return id
	}
	return g_db.monsters[0].id
}

init_battle :: proc(player_def_id: int, enemy_def_id: int) {
	// Remember where we came from so Victory/Bind/Flee can return us there
	// (Exploring for normal encounters, Hub for the Veyrath challenge, etc.)
	if g_game_state != .Battle do g_prev_game_state = g_game_state

	player_def := get_monster_def(player_def_id)
	enemy_def  := get_monster_def(enemy_def_id)
	if player_def == nil || enemy_def == nil do return

	keep_inventory := g_battle.item_qty
	had_inventory := false
	for q in keep_inventory {
		if q > 0 do had_inventory = true
	}

	g_battle = {}
	g_battle.player             = make_battle_monster(player_def)
	g_battle.enemy              = make_battle_monster(enemy_def)
	g_battle.phase              = .Choose_Action
	g_battle.active_spirit_slot = -1

	if had_inventory {
		g_battle.item_qty = keep_inventory
	} else {
		g_battle.item_qty[0] = 3 // Blood Vial
		g_battle.item_qty[1] = 2 // Soul Shard
		g_battle.item_qty[2] = 1 // Elixir
	}

	// XP scales with enemy level proxy (enemy base HP)
	g_battle.xp_earned   = enemy_def.base_hp / 4 + 5
	g_battle.gold_earned = rand.int_max(20) + 5

	// Check if this enemy was already bound
	for i in 0 ..< g_prog.bound_count {
		if g_prog.bound_spirits[i] == enemy_def_id {
			g_battle.already_bound = true
		}
	}

	set_log_str(fmt.tprintf("A wild %s appears!", g_battle.enemy.name))
}

check_bind_availability :: proc() {
	enemy := &g_battle.enemy
	if g_battle.already_bound do return
	if g_battle.can_bind do return
	threshold := enemy.hp_max / 4
	if enemy.hp <= threshold && enemy.hp > 0 {
		g_battle.can_bind = true
		set_hud_message(fmt.tprintf("%s is weakened! BIND it now!", enemy.name))
	}
}

action_count :: proc() -> int {
	n := 3 // FIGHT, ITEM, RUN
	if g_prog.bound_count > 0          do n += 1 // SPIRIT / RECALL
	if g_battle.can_bind && !g_battle.already_bound do n += 1 // BIND
	return n
}

// Layout: FIGHT | ITEM | [SPIRIT/RECALL] | [BIND] | RUN
action_label :: proc(i: int) -> string {
	has_spirit := g_prog.bound_count > 0
	has_bind   := g_battle.can_bind && !g_battle.already_bound
	switch i {
	case 0: return "FIGHT"
	case 1: return "ITEM"
	case 2:
		if has_spirit do return "RECALL" if g_battle.active_is_spirit else "SPIRIT"
		if has_bind   do return "BIND"
		return "RUN"
	case 3:
		if has_spirit && has_bind do return "BIND"
		return "RUN"
	case 4: return "RUN"
	}
	return "?"
}

inventory_item_id_at :: proc(slot: int) -> int {
	count := 0
	for id := 1; id <= MAX_ITEM_TYPES; id += 1 {
		if g_battle.item_qty[id - 1] > 0 {
			if count == slot do return id
			count += 1
		}
	}
	return 0
}

inventory_count :: proc() -> int {
	count := 0
	for q in g_battle.item_qty {
		if q > 0 do count += 1
	}
	return count
}

do_player_attack :: proc(move_idx: int) {
	fighter := active_fighter()
	enemy   := &g_battle.enemy

	tech_id := fighter.moves[move_idx]
	tech := get_technique_def(tech_id)
	if tech == nil || fighter.soul < tech.soul_cost do return

	dmg := calc_damage(fighter, tech, enemy)
	fighter.soul -= tech.soul_cost
	enemy.hp = max(enemy.hp - dmg, 0)

	// Persist spirit soul changes between moves
	if g_battle.active_is_spirit {
		g_prog.spirit_hp_cur[g_battle.active_spirit_slot] = fighter.hp
	}

	mult := type_multiplier(tech.tech_type, enemy.mon_type)
	suffix := ""
	if mult > 10 do suffix = " Super effective!"
	if mult < 10 do suffix = " Not very effective..."

	msg := fmt.tprintf("%s used %s! %d dmg!%s", fighter.name, tech.name, dmg, suffix)
	check_bind_availability()

	next := BattlePhase.Enemy_Turn
	if enemy.hp <= 0 do next = .Victory
	show_message(msg, next)
}

do_bind_attempt :: proc() {
	enemy := &g_battle.enemy
	if !g_battle.can_bind || g_battle.already_bound do return

	// Bind chance: 50% + bonus if HP very low
	hp_ratio := f32(enemy.hp) / f32(enemy.hp_max)
	chance := 0.5 + (0.25 - hp_ratio) * 2.0
	if chance > 0.95 do chance = 0.95

	if rand.float32() < chance {
		ok := try_bind_spirit(enemy.def_id)
		if ok {
			g_battle.bind_flash = 1.2
			g_battle.already_bound = true
			msg := fmt.tprintf("%s has been bound to your soul!", enemy.name)
			show_message(msg, .Bind_Success)
		} else {
			show_message("Your soul is at capacity! Release a spirit first.", .Choose_Action)
		}
	} else {
		show_message(fmt.tprintf("%s resisted the binding!", enemy.name), .Enemy_Turn)
	}
}

do_player_use_item :: proc(slot: int) {
	id := inventory_item_id_at(slot)
	if id == 0 do return
	item := get_item_def(id)
	if item == nil do return

	player := &g_battle.player
	g_battle.item_qty[id - 1] -= 1
	player.hp   = min(player.hp   + item.heal_hp,       player.hp_max)
	player.soul = min(player.soul + item.restore_souls,  player.soul_max)

	show_message(fmt.tprintf("%s used %s!", player.name, item.name), .Enemy_Turn)
}

do_player_run :: proc() {
	if rand.int_max(2) == 0 {
		show_message("Got away safely!", .Fled)
	} else {
		show_message("Couldn't escape!", .Enemy_Turn)
	}
}

do_enemy_turn :: proc() {
	enemy         := &g_battle.enemy
	target        := active_fighter()
	is_spirit_out := g_battle.active_is_spirit
	spirit_name   := target.name if is_spirit_out else ""

	affordable: [MOVE_SLOTS]int
	count := 0
	for i in 0 ..< MOVE_SLOTS {
		tid := enemy.moves[i]
		if tid == 0 do continue
		tech := get_technique_def(tid)
		if tech != nil && enemy.soul >= tech.soul_cost {
			affordable[count] = i
			count += 1
		}
	}

	msg: string
	if count == 0 {
		dmg := max(enemy.attack / 2, 1)
		target.hp = max(target.hp - dmg, 0)
		msg = fmt.tprintf("%s struggles! %d dmg!", enemy.name, dmg)
	} else {
		move_idx := affordable[rand.int_max(count)]
		tech := get_technique_def(enemy.moves[move_idx])
		dmg := calc_damage(enemy, tech, target)
		enemy.soul -= tech.soul_cost
		target.hp = max(target.hp - dmg, 0)

		mult := type_multiplier(tech.tech_type, target.mon_type)
		suffix := ""
		if mult > 10 do suffix = " Super effective!"
		if mult < 10 do suffix = " Not very effective..."
		msg = fmt.tprintf("%s used %s! %d dmg!%s", enemy.name, tech.name, dmg, suffix)
	}

	next := BattlePhase.Choose_Action
	if target.hp <= 0 {
		if is_spirit_out {
			// Spirit fainted — save 0 HP and recall it, player takes over
			g_prog.spirit_hp_cur[g_battle.active_spirit_slot] = 0
			g_battle.active_is_spirit = false
			msg = fmt.tprintf("%s  %s has fallen!", msg, spirit_name)
			if g_battle.player.hp <= 0 do next = .Defeat
		} else {
			next = .Defeat
		}
	} else if is_spirit_out {
		g_prog.spirit_hp_cur[g_battle.active_spirit_slot] = target.hp
	}
	show_message(msg, next)
}

finalize_victory :: proc() {
	award_xp(g_battle.xp_earned)

	// Spirit that participated earns half XP and may level up
	if g_battle.active_spirit_slot >= 0 {
		award_spirit_xp(g_battle.active_spirit_slot, g_battle.xp_earned / 2)
		// Notify player of spirit level-up / new move via HUD
		if g_prog.pending_spirit_slot >= 0 {
			def := get_monster_def(g_prog.bound_spirits[g_prog.pending_spirit_slot])
			mv  := get_technique_def(g_prog.pending_spirit_move)
			if def != nil && mv != nil {
				set_hud_message(fmt.tprintf("%s learned %s!", def.name, mv.name))
			} else if def != nil {
				set_hud_message(fmt.tprintf("%s grew stronger!", def.name))
			}
			g_prog.pending_spirit_slot = -1
			g_prog.pending_spirit_move = 0
		}
	}

	// Hand dropped item to player inventory
	if g_battle.item_drop_id > 0 {
		idx := g_battle.item_drop_id - 1
		if idx >= 0 && idx < MAX_ITEM_TYPES {
			g_battle.item_qty[idx] += 1
		}
	}

	if g_prog.just_leveled {
		g_prog.just_leveled = false
		g_game_state = .LevelUp
	} else {
		g_game_state = g_prev_game_state
	}
}

update_battle :: proc(dt: f32) {
	if g_battle.bind_flash > 0 do g_battle.bind_flash -= dt

	#partial switch g_battle.phase {
	case .Choose_Action:
		n := action_count()
		if rl.IsKeyPressed(.LEFT) || rl.IsKeyPressed(.A) {
			g_battle.action_cursor = (g_battle.action_cursor + n - 1) % n
		}
		if rl.IsKeyPressed(.RIGHT) || rl.IsKeyPressed(.D) {
			g_battle.action_cursor = (g_battle.action_cursor + 1) % n
		}
		if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.Z) || rl.IsKeyPressed(.SPACE) {
			lbl := action_label(g_battle.action_cursor)
			switch lbl {
			case "FIGHT":
				g_battle.move_cursor = 0
				g_battle.phase = .Choose_Move
			case "ITEM":
				if inventory_count() > 0 {
					g_battle.item_cursor = 0
					g_battle.phase = .Choose_Item
				} else {
					show_message("No items left!", .Choose_Action)
				}
			case "SPIRIT":
				g_battle.spirit_cursor = 0
				g_battle.phase = .Choose_Spirit
			case "RECALL":
				do_recall_spirit()
			case "BIND":
				do_bind_attempt()
			case "RUN":
				do_player_run()
			}
		}

	case .Choose_Spirit:
		n := g_prog.bound_count
		if n == 0 {
			g_battle.phase = .Choose_Action
		} else {
			if rl.IsKeyPressed(.UP) || rl.IsKeyPressed(.W) {
				g_battle.spirit_cursor = (g_battle.spirit_cursor + n - 1) % n
			}
			if rl.IsKeyPressed(.DOWN) || rl.IsKeyPressed(.S) {
				g_battle.spirit_cursor = (g_battle.spirit_cursor + 1) % n
			}
			if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.Z) || rl.IsKeyPressed(.SPACE) {
				do_summon_spirit(g_battle.spirit_cursor)
			}
			if rl.IsKeyPressed(.ESCAPE) || rl.IsKeyPressed(.X) || rl.IsKeyPressed(.BACKSPACE) {
				g_battle.phase = .Choose_Action
			}
		}

	case .Choose_Move:
		row := g_battle.move_cursor / 2
		col := g_battle.move_cursor % 2
		if rl.IsKeyPressed(.LEFT)  || rl.IsKeyPressed(.A) do col = (col + 1) % 2
		if rl.IsKeyPressed(.RIGHT) || rl.IsKeyPressed(.D) do col = (col + 1) % 2
		if rl.IsKeyPressed(.UP)    || rl.IsKeyPressed(.W) do row = (row + 1) % 2
		if rl.IsKeyPressed(.DOWN)  || rl.IsKeyPressed(.S) do row = (row + 1) % 2
		g_battle.move_cursor = row * 2 + col

		if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.Z) || rl.IsKeyPressed(.SPACE) {
			fighter := active_fighter()
			unlocked := active_moves_unlocked()
			if g_battle.move_cursor < unlocked {
				tid  := fighter.moves[g_battle.move_cursor]
				tech := get_technique_def(tid)
				if tech != nil && fighter.soul >= tech.soul_cost {
					do_player_attack(g_battle.move_cursor)
				} else if tech != nil {
					show_message("Not enough soul!", .Choose_Move)
				}
			} else {
				show_message("Move not yet learned. Level up!", .Choose_Move)
			}
		}
		if rl.IsKeyPressed(.ESCAPE) || rl.IsKeyPressed(.X) || rl.IsKeyPressed(.BACKSPACE) {
			g_battle.phase = .Choose_Action
		}

	case .Choose_Item:
		n := inventory_count()
		if n > 0 {
			if rl.IsKeyPressed(.UP)   || rl.IsKeyPressed(.W) {
				g_battle.item_cursor = (g_battle.item_cursor + n - 1) % n
			}
			if rl.IsKeyPressed(.DOWN) || rl.IsKeyPressed(.S) {
				g_battle.item_cursor = (g_battle.item_cursor + 1) % n
			}
			if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.Z) || rl.IsKeyPressed(.SPACE) {
				do_player_use_item(g_battle.item_cursor)
			}
		}
		if rl.IsKeyPressed(.ESCAPE) || rl.IsKeyPressed(.X) || rl.IsKeyPressed(.BACKSPACE) {
			g_battle.phase = .Choose_Action
		}

	case .Show_Message:
		if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.Z) || rl.IsKeyPressed(.SPACE) {
			g_battle.phase = g_battle.next_phase
		}

	case .Enemy_Turn:
		do_enemy_turn()

	case .Bind_Success:
		if !g_battle.item_drop_rolled do roll_item_drop()
		if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.Z) || rl.IsKeyPressed(.SPACE) {
			finalize_victory()
		}

	case .Victory:
		if !g_battle.item_drop_rolled do roll_item_drop()
		if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.Z) || rl.IsKeyPressed(.SPACE) {
			finalize_victory()
		}

	case .Defeat:
		if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.Z) || rl.IsKeyPressed(.SPACE) {
			// Wake back at the rest area — battles always start at full HP
			exit_level()
			g_game_state = .Hub
		}

	case .Fled:
		if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.Z) || rl.IsKeyPressed(.SPACE) {
			g_game_state = g_prev_game_state
		}
	}
}
