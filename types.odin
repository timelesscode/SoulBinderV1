package sb

SpiritType :: enum {
	Light, Dark, Fire, Ice, Nature, Earth, Wind, Water, Alien,
}

Alignment :: enum { Law, Neutral, Chaos }

Affinity :: enum u8 { Normal, Weak, Resist, Null, Absorb, Reflect }

SpiritAffinity :: [SpiritType]Affinity

SkillID :: enum {
	None,
	// Tier 1
	Mend, Ward, Taunt, Ignite, Chill, Ensnare, Fortify, Blind,
	// Tier 2 (fusion)
	Gust, Flare, Cleanse, SoulDrain, Thorns, StoneSkin, Smite, PsiBlast,
	// Tier 2 (evolution)
	Radiance, DarkSlash, MagmaBurst, Blizzard, Overgrowth, Quake, TidalWave, FearShriek,
}

NegotiateOption :: enum { Beg, Flatter, Threaten, Offer_Gold }

Spirit :: struct {
	name:           string,
	tier:           int,
	element:        SpiritType,
	base_atk:       int,
	base_def:       int,
	base_spd:       int,
	level:          int,
	xp:             int,
	skill:          SkillID,
	affinity:       SpiritAffinity,
	bind_bonus_atk: int,
	bind_bonus_def: int,
	cooldown:       int,
	active:         bool,
	evo_level:      int,
	evo_name:       string,
}

Summoner :: struct {
	hp:               int,
	max_hp:           int,
	level:            int,
	xp:               int,
	gold:             int,
	spirits:          [6]^Spirit,
	soul_pulse_ready: bool,
	alignment:        Alignment,
	alignment_pts:    int,
}

Enemy :: struct {
	name:            string,
	hp:              int,
	max_hp:          int,
	atk:             int,
	def:             int,
	spd:             int,
	level:           int,
	xp_reward:       int,
	gold_reward:     int,
	spirit_template: Spirit,
	talk_mood:       Alignment,
}

CombatLog :: struct {
	lines: [dynamic]string,
}

GameScreen :: enum {
	Title, Overworld, Combat, Negotiate, Fuse, GameOver, Victory,
}

// ---- particle / float text ----

Particle :: struct {
	x, y:   f32,
	vx, vy: f32,
	life:   f32,   // 1.0 → 0.0
	size:   f32,
	col:    [4]u8,
}

FloatText :: struct {
	x, y:  f32,
	vy:    f32,
	life:  f32,    // seconds remaining
	buf:   [24]byte,
	blen:  int,
	col:   [4]u8,
	sz:    i32,
}

// ---- overworld tile constants ----

Area :: enum { Village, Forest, Ruins }

MAP_W    :: 25
MAP_H    :: 18
TILE_SZ  :: 32

// 0=floor/grass  1=wall/tree  2=path  3=water  4=boss/shrine
AREA_MAPS := [Area][MAP_H][MAP_W]int{
	.Village = {
		{1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
		{1,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
		{1,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
		{1,0,0,1,1,0,0,0,0,0,1,0,0,1,1,1,0,0,0,0,0,1,1,0,1},
		{1,0,0,1,1,0,0,0,0,0,1,0,0,1,1,1,0,0,0,0,0,1,1,0,1},
		{1,0,0,0,0,0,2,2,2,2,2,2,2,0,0,0,0,0,0,0,0,0,0,0,1},
		{1,0,0,0,0,0,2,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,1},
		{1,0,0,0,0,0,2,0,4,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,1},
		{1,0,0,0,0,0,2,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,1},
		{1,0,0,0,0,0,2,2,2,2,2,2,2,0,0,0,0,0,0,0,0,0,0,0,1},
		{1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
		{1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
		{1,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,1},
		{1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
		{1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,3,3,0,0,0,0,1},
		{1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,3,3,0,0,0,0,1},
		{1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
		{1,1,1,1,1,1,1,1,1,1,1,1,2,2,1,1,1,1,1,1,1,1,1,1,1},
	},
	.Forest = {
		{1,1,1,1,1,1,2,2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
		{1,0,0,0,0,1,0,0,1,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1},
		{1,0,1,1,0,1,0,0,1,0,1,0,1,0,1,1,0,0,1,1,0,0,0,0,1},
		{1,0,1,1,0,0,0,0,0,0,1,0,0,0,1,1,0,0,1,1,0,0,0,0,1},
		{1,0,0,0,0,1,0,0,1,0,0,0,1,0,0,0,0,0,0,0,0,1,0,0,1},
		{1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1},
		{1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
		{1,0,1,0,0,1,0,1,0,0,1,0,0,1,0,0,0,1,0,0,1,0,0,1,1},
		{1,0,0,0,3,3,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
		{1,0,0,0,3,3,3,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1},
		{1,0,1,0,0,0,0,0,0,0,1,1,0,0,0,0,0,1,0,0,0,0,1,0,1},
		{1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
		{1,0,0,1,1,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,4,0,1},
		{1,0,0,1,1,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,1},
		{1,0,0,0,0,0,0,0,1,0,0,1,0,0,1,0,0,0,0,0,0,0,0,0,1},
		{1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
		{1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
		{1,1,1,1,1,1,1,1,1,1,1,1,2,2,1,1,1,1,1,1,1,1,1,1,1},
	},
	.Ruins = {
		{1,1,1,1,1,1,2,2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
		{1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
		{1,0,1,1,1,0,0,0,0,0,1,1,0,0,0,0,0,0,1,0,0,0,0,0,1},
		{1,0,1,0,1,0,0,0,0,0,1,1,0,0,0,0,0,0,1,0,0,0,0,0,1},
		{1,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
		{1,0,0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0,0,0,1,0,0,0,1},
		{1,0,0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0,0,0,1,0,0,0,1},
		{1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
		{1,0,0,1,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,1},
		{1,0,0,1,0,0,0,0,0,0,1,4,1,0,0,0,0,0,0,0,0,0,0,0,1},
		{1,0,0,1,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,1},
		{1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
		{1,0,0,0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1},
		{1,0,0,0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1},
		{1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
		{1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
		{1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
		{1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
	},
}

AREA_NAMES := [Area]string{
	.Village = "Ashenveil Village",
	.Forest  = "Thornwood Forest",
	.Ruins   = "Ruins of Kethara",
}

// ---- game state ----

GameState :: struct {
	screen:             GameScreen,
	summoner:           Summoner,
	enemy:              Enemy,
	in_combat:          bool,
	bind_available:     bool,
	talk_available:     bool,
	combat_log:         CombatLog,
	selected_skill_idx: int,
	player_turn:        bool,
	combat_over:        bool,
	combat_won:         bool,
	bind_success:       bool,
	bonus_action:       bool,
	bonus_action_used:  bool,
	enemy_enraged:      bool,
	negotiate_option:   int,
	negotiate_result:   string,
	negotiate_done:     bool,
	spirit_pool:        [dynamic]Spirit,
	fuse_idx_a:         int,
	fuse_idx_b:         int,
	run_step:           int,
	total_runs:         int,
	// combat animation
	player_attack_timer: f32,
	combat_idle_timer:   f32,
	combat_idle_frame:   int,
	// particles & float text
	particles:   [dynamic]Particle,
	float_texts: [dynamic]FloatText,
	// overworld
	player_tx:          int,
	player_ty:          int,
	cam_x:              f32,
	cam_y:              f32,
	current_area:       Area,
	encounter_cooldown: f32,
	anim_timer:         f32,
	anim_frame:         int,
	boss_defeated:      [Area]bool,
	step_count:         int,
	overworld_msg:      string,
	msg_timer:          f32,
}
