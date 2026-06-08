package main

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"

MOVE_SLOTS        :: 4
MAX_MONSTERS_DB   :: 64
MAX_TECHNIQUES_DB :: 64
MAX_ITEMS_DB      :: 32

TechType :: enum u8 {
	Kinetic,
	Psychic,
	Dark,
	Fire,
	Water,
	Nature,
}

MonsterDef :: struct {
	id:           int,
	name:         string,
	base_hp:      int,
	base_attack:  int,
	base_defense: int,
	soul_max:     int,
	spirit_id:    int,
	mon_type:     TechType,
	moves:        [MOVE_SLOTS]int,
}

TechniqueDef :: struct {
	id:        int,
	name:      string,
	power:     int,
	soul_cost: int,
	tech_type: TechType,
}

ItemDef :: struct {
	id:            int,
	name:          string,
	heal_hp:       int,
	restore_souls: int,
	description:   string,
}

Database :: struct {
	monsters:        [MAX_MONSTERS_DB]MonsterDef,
	monster_count:   int,
	techniques:      [MAX_TECHNIQUES_DB]TechniqueDef,
	technique_count: int,
	items:           [MAX_ITEMS_DB]ItemDef,
	item_count:      int,
}

g_db: Database

get_monster_def :: proc(id: int) -> ^MonsterDef {
	for i in 0 ..< g_db.monster_count {
		if g_db.monsters[i].id == id do return &g_db.monsters[i]
	}
	return nil
}

get_technique_def :: proc(id: int) -> ^TechniqueDef {
	for i in 0 ..< g_db.technique_count {
		if g_db.techniques[i].id == id do return &g_db.techniques[i]
	}
	return nil
}

get_item_def :: proc(id: int) -> ^ItemDef {
	for i in 0 ..< g_db.item_count {
		if g_db.items[i].id == id do return &g_db.items[i]
	}
	return nil
}

parse_tech_type :: proc(s: string) -> TechType {
	switch s {
	case "Psychic": return .Psychic
	case "Dark":    return .Dark
	case "Fire":    return .Fire
	case "Water":   return .Water
	case "Nature":  return .Nature
	}
	return .Kinetic
}

type_name :: proc(t: TechType) -> string {
	switch t {
	case .Kinetic: return "Kinetic"
	case .Psychic: return "Psychic"
	case .Dark:    return "Dark"
	case .Fire:    return "Fire"
	case .Water:   return "Water"
	case .Nature:  return "Nature"
	}
	return "?"
}

_atoi :: proc(s: string) -> int {
	v, _ := strconv.parse_int(s)
	return v
}

_next_line :: proc(text: ^string) -> (line: string, ok: bool) {
	if len(text^) == 0 do return {}, false
	i := strings.index_byte(text^, '\n')
	if i < 0 {
		line = text^
		text^ = ""
	} else {
		line = text^[:i]
		text^ = text^[i + 1:]
	}
	return strings.trim_right(line, " \t\r"), true
}

_next_field :: proc(line: ^string) -> (field: string, more: bool) {
	i := strings.index_byte(line^, ',')
	if i < 0 {
		field = line^
		line^ = ""
		more = false
	} else {
		field = line^[:i]
		line^ = line^[i + 1:]
		more = true
	}
	return strings.trim_space(field), more
}

_split_row :: proc(line: string, out: []string) -> int {
	row := line
	n := 0
	for n < len(out) {
		more: bool
		out[n], more = _next_field(&row)
		n += 1
		if !more do break
	}
	return n
}

load_monsters :: proc(path: string) -> bool {
	data, read_err := os.read_entire_file(path, context.allocator)
	if read_err != nil do return false
	defer delete(data)
	text := string(data)
	skip_header := true
	fields: [16]string
	for {
		line := _next_line(&text) or_break
		if len(line) == 0 do continue
		if skip_header { skip_header = false; continue }
		n := _split_row(line, fields[:])
		if n < 12 do continue
		i := g_db.monster_count
		if i >= MAX_MONSTERS_DB do break
		g_db.monsters[i].id = _atoi(fields[0])
		g_db.monsters[i].name = strings.clone(fields[1])
		g_db.monsters[i].base_hp = _atoi(fields[2])
		g_db.monsters[i].base_attack = _atoi(fields[3])
		g_db.monsters[i].base_defense = _atoi(fields[4])
		g_db.monsters[i].soul_max = _atoi(fields[5])
		g_db.monsters[i].spirit_id = _atoi(fields[6])
		g_db.monsters[i].mon_type = parse_tech_type(fields[7])
		for m in 0 ..< MOVE_SLOTS {
			g_db.monsters[i].moves[m] = _atoi(fields[8 + m])
		}
		g_db.monster_count += 1
	}
	return true
}

load_techniques :: proc(path: string) -> bool {
	data, read_err := os.read_entire_file(path, context.allocator)
	if read_err != nil do return false
	defer delete(data)
	text := string(data)
	skip_header := true
	fields: [8]string
	for {
		line := _next_line(&text) or_break
		if len(line) == 0 do continue
		if skip_header { skip_header = false; continue }
		n := _split_row(line, fields[:])
		if n < 5 do continue
		i := g_db.technique_count
		if i >= MAX_TECHNIQUES_DB do break
		g_db.techniques[i].id = _atoi(fields[0])
		g_db.techniques[i].name = strings.clone(fields[1])
		g_db.techniques[i].power = _atoi(fields[2])
		g_db.techniques[i].soul_cost = _atoi(fields[3])
		g_db.techniques[i].tech_type = parse_tech_type(fields[4])
		g_db.technique_count += 1
	}
	return true
}

load_items :: proc(path: string) -> bool {
	data, read_err := os.read_entire_file(path, context.allocator)
	if read_err != nil do return false
	defer delete(data)
	text := string(data)
	skip_header := true
	fields: [8]string
	for {
		line := _next_line(&text) or_break
		if len(line) == 0 do continue
		if skip_header { skip_header = false; continue }
		n := _split_row(line, fields[:])
		if n < 5 do continue
		i := g_db.item_count
		if i >= MAX_ITEMS_DB do break
		g_db.items[i].id = _atoi(fields[0])
		g_db.items[i].name = strings.clone(fields[1])
		g_db.items[i].heal_hp = _atoi(fields[2])
		g_db.items[i].restore_souls = _atoi(fields[3])
		g_db.items[i].description = strings.clone(fields[4])
		g_db.item_count += 1
	}
	return true
}

load_all_data :: proc() -> bool {
	if !load_monsters("monsters.csv") {
		fmt.println("Failed to load monsters.csv")
		return false
	}
	if !load_techniques("techniques.csv") {
		fmt.println("Failed to load techniques.csv")
		return false
	}
	if !load_items("items.csv") {
		fmt.println("Failed to load items.csv")
		return false
	}
	fmt.printf("Loaded %d monsters, %d techniques, %d items\n",
		g_db.monster_count, g_db.technique_count, g_db.item_count)
	return true
}
