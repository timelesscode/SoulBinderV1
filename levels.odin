package main

// ── Level Definitions ─────────────────────────────────────────────────────
// Each of the nine 3D scenes (.glb backgrounds) is home to one of the Ten
// Spirits — a story beat, a wandering monster pool, and a named boss to
// weaken and bind. Index `i` here lines up 1:1 with `TEN_SPIRIT_NAMES[i]`,
// which keeps the Hub's "story progress" markers and `g_prog.ten_collected`
// trivially in sync with the level list.

LevelDef :: struct {
	name:             string,
	glb_path:         string,
	flavor:           string,
	intro:            []DialogueLine, // one-shot story beat shown on first meeting the spirit
	spirit_name:      string,         // matches a row in monsters.csv and TEN_SPIRIT_NAMES
	wander_pool:      []int,          // monster ids that roam this level
	encounter_chance: f32,            // probability-per-second of a fight while near a wanderer
}

LEVELS := [9]LevelDef{
	{
		name = "The Scorched Reaches", glb_path = "volcano_island.glb",
		flavor = "Ash drifts over cooling rivers of lava.",
		spirit_name = "Ignis", wander_pool = []int{1, 5, 8}, encounter_chance = 0.35,
		intro = []DialogueLine{
			{speaker = "Oracle", text = "This is the Scorched Reaches, Taz — where Ignis, the spirit of fire, has slept for centuries."},
			{speaker = "Taz",    text = "The air shimmers like the rocks themselves are breathing."},
			{speaker = "Oracle", text = "Ignis does not sleep peacefully. Its fury has bled into the stone. Be ready."},
			{speaker = "Taz",    text = "Then let's wake it up — on my terms."},
		},
	},
	{
		name = "Tideglass Village", glb_path = "village.glb",
		flavor = "The tide rolled in generations ago and never left.",
		spirit_name = "Aqua", wander_pool = []int{2, 6, 3}, encounter_chance = 0.35,
		intro = []DialogueLine{
			{speaker = "Oracle", text = "Tideglass Village once thrived on the shore. Now the tide never leaves."},
			{speaker = "Taz",    text = "The whole village is underwater... but it's still standing."},
			{speaker = "Oracle", text = "Aqua keeps it that way. The spirit grieves for what this place lost."},
			{speaker = "Taz",    text = "Maybe binding it isn't the only thing it needs from me."},
		},
	},
	{
		name = "The Whispering Temple", glb_path = "shaolin_temple.glb",
		flavor = "Wind chimes ring in halls no one has swept in years.",
		spirit_name = "Verdant", wander_pool = []int{3, 7, 6}, encounter_chance = 0.35,
		intro = []DialogueLine{
			{speaker = "Oracle", text = "The Whispering Temple has stood since before the Shattering. Verdant still tends its gardens."},
			{speaker = "Taz",    text = "It's beautiful here. Peaceful, almost."},
			{speaker = "Oracle", text = "Almost. Verdant guards this place fiercely — it won't yield its bond easily."},
			{speaker = "Taz",    text = "I'm not here to take. I'm here to ask."},
		},
	},
	{
		name = "The Forgotten Tomb", glb_path = "tomb.glb",
		flavor = "Cold air. Older silence. Something else breathing.",
		spirit_name = "Umbra", wander_pool = []int{4, 8, 6}, encounter_chance = 0.4,
		intro = []DialogueLine{
			{speaker = "Oracle", text = "Few who enter the Forgotten Tomb leave with their courage intact."},
			{speaker = "Taz",    text = "It's freezing in here. And... I don't think we're alone."},
			{speaker = "Oracle", text = "Umbra dwells in the dark between heartbeats. It will test your resolve before your strength."},
			{speaker = "Taz",    text = "Then I won't blink first."},
		},
	},
	{
		name = "The Sunken Archive", glb_path = "library1.glb",
		flavor = "Endless shelves of books no living eye has read.",
		spirit_name = "Lumen", wander_pool = []int{4, 8, 3}, encounter_chance = 0.3,
		intro = []DialogueLine{
			{speaker = "Oracle", text = "The Sunken Archive holds Lumen, the spirit of thought and memory."},
			{speaker = "Taz",    text = "Thousands of books, swallowed by silence."},
			{speaker = "Oracle", text = "Lumen knows every secret ever written here — including yours, summoner."},
			{speaker = "Taz",    text = "Let's see if it's willing to share."},
		},
	},
	{
		name = "The Skybound Spire", glb_path = "tower.glb",
		flavor = "The wind never stops, and neither does the drop.",
		spirit_name = "Gale", wander_pool = []int{1, 4, 7}, encounter_chance = 0.35,
		intro = []DialogueLine{
			{speaker = "Oracle", text = "The Skybound Spire pierces the clouds themselves. Gale calls its halls home."},
			{speaker = "Taz",    text = "I can barely keep my footing up here — the wind never lets up."},
			{speaker = "Oracle", text = "Gale is restless, swift, impossible to pin down. You'll need to be faster."},
			{speaker = "Taz",    text = "Then I'll just have to catch lightning."},
		},
	},
	{
		name = "The Cinderfall Coliseum", glb_path = "colseuem.glb",
		flavor = "Champions once fought here for glory. Now it's empty.",
		spirit_name = "Magma", wander_pool = []int{1, 5, 7}, encounter_chance = 0.4,
		intro = []DialogueLine{
			{speaker = "Oracle", text = "Long ago, champions fought here for glory. Now only Magma remains to claim it."},
			{speaker = "Taz",    text = "This place still smells like smoke and old steel."},
			{speaker = "Oracle", text = "Magma respects only strength. Show it yours, and it may finally rest."},
			{speaker = "Taz",    text = "Then let's give the old arena one last show."},
		},
	},
	{
		name = "The Drowned Metro", glb_path = "metro.glb",
		flavor = "Flooded tunnels swallow every sound but your own steps.",
		spirit_name = "Abyssal", wander_pool = []int{2, 4, 8}, encounter_chance = 0.4,
		intro = []DialogueLine{
			{speaker = "Oracle", text = "The Drowned Metro sank generations ago. Abyssal has ruled its flooded tunnels ever since."},
			{speaker = "Taz",    text = "It's so dark down here... something is watching from the tracks."},
			{speaker = "Oracle", text = "Abyssal feeds on fear, Taz. Don't give it the satisfaction."},
			{speaker = "Taz",    text = "Then it'll only taste my fists."},
		},
	},
	{
		name = "Hollowgrove College", glb_path = "college.glb",
		flavor = "Empty halls and overgrown courtyards, waiting.",
		spirit_name = "Sylvan", wander_pool = []int{3, 7, 4}, encounter_chance = 0.3,
		intro = []DialogueLine{
			{speaker = "Oracle", text = "Hollowgrove College once taught summoners like you. Sylvan was its final student — and its last guardian."},
			{speaker = "Taz",    text = "It's like the whole place is waiting for someone to come back."},
			{speaker = "Oracle", text = "Perhaps it's been waiting for you. Sylvan blends nature and mind in equal measure — expect both."},
			{speaker = "Taz",    text = "Then I'll meet it with both, too."},
		},
	},
}

// Looks up a level's named spirit in the monster DB by name (matches the
// pattern already used for the Veyrath fight in dialogue.odin).
level_spirit_monster_id :: proc(level: ^LevelDef) -> int {
	for i in 0 ..< g_db.monster_count {
		if g_db.monsters[i].name == level.spirit_name {
			return g_db.monsters[i].id
		}
	}
	return 0
}
