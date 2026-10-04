extends Node
class_name MapContent
## Static data for every map: layout, obstacles, NPC definitions, quest list.
## Called by each map's _ready to populate its MazeBuilder and place everything.
## Adding a new map? Add an entry to MAPS.

const MAPS := {
	# ---------- MAP 1: KITCHEN COUNTER ----------
	"kitchen_counter": {
		"display": "🍳 Kitchen Counter",
		"blurb": "Cereal-box walls, giant utensils, and a crouton who lies. ~15 min.",
		"layout": """
#######################
#...........#.........#
#....S......#....T....#
#...........#.........#
#.....N1....####.######
#.....................#
#....#.########..###..#
#....#.#......#....#..#
#.A..#.#..T...#....#..#
#....#.#......#..B.#..#
#....#.#......#....#..#
######.#..#...######..#
#......#..#...........#
#..T...#..#####G#######
#......########.......#
#......########....E..#
#######################
""",
		"obstacles": [
			{"type": "push", "cell": [10, 1], "dir": [0, 0, 1], "force": 7},
			{"type": "push", "cell": [10, 2], "dir": [0, 0, 1], "force": 7},
			{"type": "timed", "cell": [6, 6], "on": 2, "off": 4, "offset": 0},
			{"type": "timed", "cell": [12, 8], "on": 2.5, "off": 3.5, "offset": 1.5},
			{"type": "patrol", "points": [[3, 5], [18, 5]], "speed": 3.5, "knock": 10},
			{"type": "timed", "cell": [4, 12], "on": 1.5, "off": 5, "offset": 0.8},
		],
		"npcs": [
			{"id": "breadwise", "model": "npc_breadwise", "name": "Breadwise", "cell": "N1",
			 "lines": ["Ah, you want to cross the Great Sink?", "Just... hmm... have you tried NOT falling in?", "I'm a crouton. I don't have hands."]},
			{"id": "spatula", "model": "npc_general", "name": "Chef Spatula", "cell": [1, 11], "quest": 4,
			 "lines": ["I wrote the recipe but I can't find where I left it!", "It's a secret code. I hid it somewhere in the northeast room."]},
			{"id": "spilly", "model": "npc_dusty", "name": "Spilly", "cell": [18, 2], "quest": 3,
			 "lines": ["I'm a milk drop and I'm lost!", "Can someone bring me the sugar cube?"]},
		],
		"quests": [
			{"title": "Salt Run", "type": "fetch", "item": "salt", "npc": "breadwise",
			 "intro": ["Breadwise: I need the salt shaker. It's somewhere in the south corridor.", "Grab it and bring it back to me!"]},
			{"title": "Hot Plates", "type": "plates", "group": "plates", "npc": "breadwise",
			 "intro": ["Breadwise: See those yellow plates? Stand on BOTH at once.", "You'll need a friend for this. That's the whole point."]},
			{"title": "Hidden Recipe", "type": "reach", "marker": "recipe_spot", "npc": "spatula",
			 "intro": ["Chef Spatula: My secret recipe note is hidden behind a cereal box.", "It's in the northeast maze. Look on the floor!"]},
			{"title": "Sugar Delivery", "type": "fetch", "item": "sugar", "npc": "spilly",
			 "intro": ["Spilly: I need a sugar cube to sweeten up.", "There's one near the exit door. Bring it here!"]},
			{"title": "Spatula's Code", "type": "talk", "talk_to": "spatula", "npc": "breadwise",
			 "intro": ["Breadwise: Chef Spatula has a code I need.", "Go talk to him, then come back and tell me."]},
			{"title": "Faucet Flood", "type": "survive", "marker": "flood_zone", "count": 20, "npc": "breadwise",
			 "intro": ["Breadwise: The faucet is about to burst!", "Both of you stand in the flood zone and survive 20 seconds. Together!"]},
		],
	},

	# ---------- MAP 2: TOY CHEST ----------
	"toy_chest": {
		"display": "🧸 Toy Chest",
		"blurb": "Building blocks, a marching soldier, and a teddy who judges you. ~18 min.",
		"layout": """
#########################
#...........#...........#
#....S......#.....T.....#
#...........#...........#
#.....N1....#####.#######
#.......................#
#..####.#########.####..#
#..#....#.......#....#..#
#..#.A..#...T...#....#..#
#..#....#.......#.B..#..#
#..#....#.......#....#..#
#..######...#...######..#
#...........#...........#
#.....T.....#####G#######
#...........#######.....#
#..N2.......#######..E..#
#...........#######.N3..#
#########################
""",
		"obstacles": [
			{"type": "patrol", "points": [[3, 6], [20, 6]], "speed": 4, "knock": 12},
			{"type": "patrol", "points": [[10, 11], [10, 3]], "speed": 3, "knock": 10},
			{"type": "push", "cell": [5, 8], "dir": [1, 0, 0], "force": 6},
			{"type": "push", "cell": [17, 8], "dir": [-1, 0, 0], "force": 6},
			{"type": "timed", "cell": [12, 13], "on": 3, "off": 3, "offset": 0},
			{"type": "timed", "cell": [8, 6], "on": 2, "off": 4.5, "offset": 2},
			{"type": "timed", "cell": [16, 4], "on": 2, "off": 5, "offset": 1},
			{"type": "patrol", "points": [[2, 14], [2, 16], [8, 16], [8, 14]], "speed": 3.5, "knock": 10},
		],
		"npcs": [
			{"id": "general", "model": "npc_general", "name": "General Blockhead", "cell": "N1",
			 "lines": ["LISTEN UP RECRUIT!", "The exit is... *checks notes* ...somewhere.", "CHARGE!"]},
			{"id": "teddy", "model": "npc_breadwise", "name": "Teddy", "cell": "N2",
			 "lines": ["I've been in this chest since 2003.", "Nobody plays with me anymore.", "At least you're here now. That's nice."]},
			{"id": "jack", "model": "npc_stubby", "name": "Jack", "cell": "N3",
			 "lines": ["*BOING*", "Sorry, I do that sometimes.", "It's a spring thing."]},
		],
		"quests": [
			{"title": "Block Tower", "type": "reach", "marker": "tower_top", "npc": "general",
			 "intro": ["General: BUILD ME A TOWER!", "Reach the marker at the top of the block stack!"]},
			{"title": "March Together", "type": "plates", "group": "plates", "npc": "general",
			 "intro": ["General: FORMATION!", "Both of you on the drill pads. NOW!"]},
			{"title": "Teddy's Button", "type": "fetch", "item": "button", "npc": "teddy",
			 "intro": ["Teddy: My button eye fell off somewhere.", "It's small and shiny. Probably near the blocks."]},
			{"title": "Jack's Spring", "type": "fetch", "item": "spring", "npc": "jack",
			 "intro": ["Jack: My spring is loose!", "Find the spare spring and bring it back!"]},
			{"title": "General's Orders", "type": "talk", "talk_to": "general", "npc": "teddy",
			 "intro": ["Teddy: The General has a message for me.", "Go ask him, then come tell me what he said."]},
			{"title": "Soldier Dodge", "type": "survive", "marker": "dodge_zone", "count": 25, "npc": "general",
			 "intro": ["General: SURVIVAL DRILL!", "Stay in the training zone for 25 seconds!", "The wind-up soldiers don't stop. GOOD LUCK!"]},
		],
	},

	# ---------- MAP 3: GRANDMA'S ATTIC ----------
	"grandmas_attic": {
		"display": "🕸 Grandma's Attic",
		"blurb": "Cobwebs slow you, cat paws swat you, and the moth is scared of everything. ~20 min.",
		"layout": """
#########################
#.............#.........#
#....S........#....T....#
#.............#.........#
#......N1.....####.######
#.......................#
####.##########.####.####
#......#......#.........#
#..A...#..T...#......B..#
#......#......#.........#
#......#......#.........#
#......#......#.........#
#######...#...###########
#.........#.............#
#....T....######G########
#.........##########.N3.#
#...N2....##########..E.#
#########################
""",
		"obstacles": [
			{"type": "slow", "cell": [3, 1], "factor": 0.35},
			{"type": "slow", "cell": [4, 1], "factor": 0.35},
			{"type": "slow", "cell": [3, 2], "factor": 0.35},
			{"type": "slow", "cell": [10, 7], "factor": 0.3},
			{"type": "slow", "cell": [11, 7], "factor": 0.3},
			{"type": "patrol", "points": [[2, 6], [20, 6]], "speed": 5, "knock": 14},
			{"type": "patrol", "points": [[18, 1], [18, 5], [22, 5], [22, 1]], "speed": 4, "knock": 12},
			{"type": "dark", "cell": [2, 13], "radius": 6},
			{"type": "timed", "cell": [8, 10], "on": 2, "off": 4, "offset": 0},
			{"type": "timed", "cell": [14, 3], "on": 3, "off": 3, "offset": 1.5},
		],
		"npcs": [
			{"id": "dusty", "model": "npc_dusty", "name": "Dusty", "cell": "N1",
			 "lines": ["*flutters nervously*", "Is that a... a LIGHT?!", "Oh it's just you. PHEW."]},
			{"id": "granny", "model": "npc_breadwise", "name": "Granny's Ghost", "cell": "N2",
			 "lines": ["Back in my day, mazes had REAL monsters.", "You kids have it easy.", "Now find my knitting needles!"]},
			{"id": "yarnball", "model": "npc_dr_spots", "name": "Yarn Ball", "cell": "N3",
			 "lines": ["I'm tangled.", "So tangled.", "Can you untangle me? Just kidding, I like it."]},
		],
		"quests": [
			{"title": "Photo Hunt", "type": "collect", "item": "photo", "count": 3, "npc": "dusty",
			 "intro": ["Dusty: Granny dropped 3 photos!", "Find them scattered around the attic."]},
			{"title": "Web Walk", "type": "plates", "group": "plates", "npc": "dusty",
			 "intro": ["Dusty: The cobweb switches!", "Both buddies step on them... carefully!"]},
			{"title": "Needle Fetch", "type": "fetch", "item": "needle", "npc": "granny",
			 "intro": ["Granny's Ghost: My knitting needle is in the dark room!", "Be brave. Or bring a friend."]},
			{"title": "Yarn Delivery", "type": "fetch", "item": "yarn", "npc": "yarnball",
			 "intro": ["Yarn Ball: I need more yarn! There's a ball in the southeast.", "Roll it over here. Carefully."]},
			{"title": "Granny's Message", "type": "talk", "talk_to": "granny", "npc": "dusty",
			 "intro": ["Dusty: Granny has something to tell you.", "Go listen, then come back and tell me."]},
			{"title": "Cat Dodge", "type": "survive", "marker": "cat_zone", "count": 30, "npc": "granny",
			 "intro": ["Granny's Ghost: The cat is angry today!", "Survive in the open area for 30 seconds!", "Both of you. Together. She hates loners."]},
		],
	},

	# ---------- MAP 4: GARDEN SHED ----------
	"garden_shed": {
		"display": "🌱 Garden Shed",
		"blurb": "Sprinklers flood, vines grow, and the ladybug therapist wants to talk. ~20 min.",
		"layout": """
###########################
#.............#...........#
#.....S.......#.....T.....#
#.............#...........#
#.....N1......#####.#######
#.........................#
#.#####.###########.####..#
#.#.....#.........#....#..#
#.#..A..#....T....#....#..#
#.#.....#.........#.B..#..#
#.#.....#.........#....#..#
#.#######....#....######..#
#............#............#
#.....T......######G#######
#............########.....#
#...N2.......########..E..#
#...N3.......########.....#
###########################
""",
		"obstacles": [
			{"type": "push", "cell": [6, 1], "dir": [0, 0, 1], "force": 5},
			{"type": "push", "cell": [7, 1], "dir": [0, 0, 1], "force": 5},
			{"type": "push", "cell": [6, 2], "dir": [0, 0, 1], "force": 5},
			{"type": "slow", "cell": [14, 8], "factor": 0.4},
			{"type": "slow", "cell": [15, 8], "factor": 0.4},
			{"type": "slow", "cell": [14, 9], "factor": 0.4},
			{"type": "patrol", "points": [[3, 5], [22, 5]], "speed": 3.5, "knock": 11},
			{"type": "patrol", "points": [[3, 12], [3, 16], [10, 16], [10, 12]], "speed": 3, "knock": 9},
			{"type": "timed", "cell": [10, 6], "on": 3, "off": 4, "offset": 0},
			{"type": "timed", "cell": [18, 10], "on": 2, "off": 3.5, "offset": 2},
			{"type": "timed", "cell": [20, 3], "on": 2.5, "off": 4, "offset": 1},
		],
		"npcs": [
			{"id": "drspots", "model": "npc_dr_spots", "name": "Dr. Spots", "cell": "N1",
			 "lines": ["Welcome, friend.", "Tell me how the maze makes you FEEL.", "Mm-hmm. Interesting."]},
			{"id": "wormy", "model": "npc_stubby", "name": "Wormy", "cell": "N2",
			 "lines": ["I'm a worm.", "I live in the dirt.", "It's a good life."]},
			{"id": "petal", "model": "npc_dusty", "name": "Petal", "cell": "N3",
			 "lines": ["*sways in the breeze*", "Water me? No? Okay.", "I photosynthesize my own happiness."]},
		],
		"quests": [
			{"title": "Seed Collection", "type": "collect", "item": "seed", "count": 4, "npc": "drspots",
			 "intro": ["Dr. Spots: Collect 4 seeds scattered around.", "They're good for the soul. And the garden."]},
			{"title": "Sprinkler Dance", "type": "plates", "group": "plates", "npc": "drspots",
			 "intro": ["Dr. Spots: The sprinkler controls need TWO.", "Stand on both valves. Together. Like friends do."]},
			{"title": "Wormy's Snack", "type": "fetch", "item": "apple_core", "npc": "wormy",
			 "intro": ["Wormy: I smell an apple core!", "Find it and bring it here. I'm hungry."]},
			{"title": "Petal's Water", "type": "fetch", "item": "water_drop", "npc": "petal",
			 "intro": ["Petal: I'm thirsty!", "There's a water drop near the sprinkler. Bring it!"]},
			{"title": "Therapy Session", "type": "talk", "talk_to": "drspots", "npc": "wormy",
			 "intro": ["Wormy: Dr. Spots wants to talk to you.", "Go listen. Come back. Tell me what she said."]},
			{"title": "Flood Survival", "type": "survive", "marker": "flood_zone", "count": 25, "npc": "drspots",
			 "intro": ["Dr. Spots: The sprinklers are going haywire!", "Stay in the flood zone for 25 seconds!", "Breathe. Stay calm. Stay together."]},
		],
	},

	# ---------- MAP 5: SCHOOL BACKPACK ----------
	"school_backpack": {
		"display": "🎒 School Backpack",
		"blurb": "Pencil traps, eraser zones, zipper walls, and a broken philosopher. Hard mode. ~22 min.",
		"layout": """
###########################
#.............#...........#
#......S......#.....T.....#
#.............#...........#
#......N1.....#####.#######
#.........................#
##.#####.##########.####.##
#..#.....#.........#...#..#
#..#..A..#....T....#...#..#
#..#.....#.........#.B.#..#
#..#.....#.........#...#..#
#..#######....#....#####..#
#.............#...........#
#......T......#####G#######
#.............#########...#
#..N2.........#########.E.#
#.............#########.N3#
###########################
""",
		"obstacles": [
			{"type": "timed", "cell": [4, 1], "on": 1.5, "off": 2.5, "offset": 0},
			{"type": "timed", "cell": [8, 3], "on": 2, "off": 3, "offset": 1},
			{"type": "timed", "cell": [16, 5], "on": 2, "off": 2.5, "offset": 0.5},
			{"type": "timed", "cell": [20, 7], "on": 1.8, "off": 3, "offset": 2},
			{"type": "timed", "cell": [10, 11], "on": 3, "off": 2, "offset": 0},
			{"type": "patrol", "points": [[3, 5], [22, 5]], "speed": 5, "knock": 14},
			{"type": "patrol", "points": [[3, 12], [22, 12]], "speed": 4.5, "knock": 12},
			{"type": "slow", "cell": [12, 8], "factor": 0.3},
			{"type": "slow", "cell": [13, 8], "factor": 0.3},
			{"type": "push", "cell": [18, 2], "dir": [-1, 0, 0], "force": 9},
			{"type": "push", "cell": [19, 2], "dir": [-1, 0, 0], "force": 9},
		],
		"npcs": [
			{"id": "stubby", "model": "npc_stubby", "name": "Stubby", "cell": "N1",
			 "lines": ["The unexamined backpack is not worth exploring.", "But here you are. So explore.", "I'm broken. But aren't we all?"]},
			{"id": "ruler", "model": "npc_general", "name": "Ruler Rick", "cell": "N2",
			 "lines": ["I measure things.", "You are approximately 0.02 rulers tall.", "Impressive. Or not. I can't tell."]},
			{"id": "glue", "model": "npc_dr_spots", "name": "Glue Gal", "cell": "N3",
			 "lines": ["I stick things together!", "Including friendships.", "Get it? Because I'm glue?"]},
		],
		"quests": [
			{"title": "Eraser Hunt", "type": "collect", "item": "eraser_piece", "count": 5, "npc": "stubby",
			 "intro": ["Stubby: My eraser crumbled into 5 pieces.", "Find them all. They're pink and small."]},
			{"title": "Calculator Code", "type": "plates", "group": "plates", "npc": "stubby",
			 "intro": ["Stubby: The calculator buttons are pressure plates.", "Both of you, on the right numbers. NOW."]},
			{"title": "Ruler's Tape", "type": "fetch", "item": "tape", "npc": "ruler",
			 "intro": ["Ruler Rick: I need measuring tape!", "It's rolled up somewhere in the south."]},
			{"title": "Glue Cap", "type": "fetch", "item": "glue_cap", "npc": "glue",
			 "intro": ["Glue Gal: My cap fell off!", "Without it I dry out. Find it! Please!"]},
			{"title": "Stubby's Wisdom", "type": "talk", "talk_to": "stubby", "npc": "ruler",
			 "intro": ["Ruler Rick: Stubby has a philosophical riddle for you.", "Go listen, come back."]},
			{"title": "Pencil Gauntlet", "type": "survive", "marker": "gauntlet_zone", "count": 30, "npc": "stubby",
			 "intro": ["Stubby: The pencil launchers are active!", "Survive in the training zone for 30 seconds!", "Both of you. Philosophers together."]},
		],
	},
}

## Returns map data or null.
static func get_map(map_id: String) -> Dictionary:
	return MAPS.get(map_id, {})

## Returns all map IDs in intended play order.
static func map_ids() -> Array[String]:
	return ["kitchen_counter", "toy_chest", "grandmas_attic", "garden_shed", "school_backpack"]
