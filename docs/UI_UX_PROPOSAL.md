# Buddy Maze — UI/UX Enhancement Proposal

**For:** design, art, engineering, QA, and community teams
**Status:** v1 implemented in the prototype · open for team feedback
**Plain-language note:** this document avoids engine jargon. Where a technical term is unavoidable, it's explained in brackets.

---

## Why this matters

Friendslop games (PEAK, R.E.P.O., Big Walk, Lethal Company) live or die on **how easy it is to play with friends and how funny it looks when you do**. Every screen should answer three questions in under 3 seconds:

1. *What can I do right now?*
2. *Where are my buddies and what do they need?*
3. *How do I bring a friend in?*

Our guiding principles:

| Principle | What it means in practice |
|---|---|
| **Show, don't tell** | Pings, emotes, and glowing plates over long text |
| **Never punish waiting** | Solo players can explore freely; the clock pauses until a buddy joins |
| **One action, every device** | The same "Use" works on keyboard (E), controller (X), and phone (USE button) |
| **Accessible by default** | Big text, no-motion mode, colorblind filters, hold-or-toggle controls |
| **Celebrate the team** | Results screens reward the group, not a single winner |

---

## 1. UI/UX Improvements

### 1.1 Context prompts (what can I do?)
A short hint appears under the crosshair based on what you're looking at:

- Looking at a buddy → **"[H] High-five Sam"**
- Looking at a crate → **"[F] Grab"**
- Holding something → **"[E] Throw  [F] Drop"**
- Looking at Breadwise → **"[E] Talk to Breadwise"**

The key shown **changes automatically** to match the device you're using (keyboard key, controller button, or phone button name).

> *Status: ✅ built* — `player_controller.gd → _update_look_prompt()`

### 1.2 Pings — talk without talking
Press **Q** (or middle-click, or the 📍 phone button) to drop a marker where you're looking. Everyone sees it, in **your color**, with an icon:

| Pointing at | Icon & label |
|---|---|
| Anything | 👀 "Look here" |
| A Friendship Token | 🪙 "Token!" |
| A pressure plate | ⬇ "Stand here" |
| An NPC | 💬 "Talk" |

If the ping is off-screen, it **sticks to the screen edge** pointing the right way. Pings fade after 6 seconds; a new ping replaces your old one (no clutter).

**Why:** many players don't use voice chat (shy, noisy home, hearing differences). Pings make co-op possible for everyone.

> *Status: ✅ built*

### 1.3 Emote wheel — be expressive
Hold **G** (or tap 😀 on phone) to open a ring of 8 emotes:
👋 Wave · 😂 Laugh · ❤️ Heart · 🆘 Help · 👍 Yes · 👎 No · 👉 Follow · ✋ Wait

The emoji pops up **above your buddy's head** for everyone to see, and your bean does a little squash-and-stretch hop. Release over an emote to send it — fast enough to use mid-chaos.

> *Status: ✅ built* · **Ideas for the team:** seasonal emotes, emote combos (two buddies wave at once → confetti), a "dance" emote that syncs nearby buddies.

### 1.4 Buddy roster
Top-right list of everyone in the maze with a **color dot** matching their bean and a ✅ when they've reached the exit. No more "where's Alex?"

> *Status: ✅ built*

### 1.5 Co-op status banner
- **Alone:** "🧭 Solo explore — gates need a buddy. Invite code: K7QX"
- **Friend arrives:** "🤝 Buddies here! Puzzles are live." (fades after 3 s)
- Join toast: "Sam joined the maze!"

> *Status: ✅ built*

### 1.6 Results screen
Replaces the old 3-second text popup. Shows team time, tokens, high-fives, buddy count, friendship %, and **what you unlocked** ("✨ New hat: Chef Hat").

> *Status: ✅ built* · **Ideas:** a group photo of all beans in their hats; "funniest moment" (most pratfalls).

### 1.7 Pause menu
Esc / ⏸ opens Resume · Settings · Leave maze, and shows the invite code. In multiplayer the world **keeps running** (you can't freeze your friends) — only your own controls pause.

> *Status: ✅ built*

### 1.8 Proposed next (not yet built)
| Idea | Effort | Owner suggestion |
|---|---|---|
| First-time tutorial room (teaches grab, crouch-boost, high-five) | Medium | Design + Eng |
| NPC speech bubbles with voice "gibberish" + subtitles | Medium | Audio + Eng |
| Off-screen arrows pointing to buddies | Small | Eng |
| Photo mode (freeze, hide HUD, pose beans) | Medium | Eng + Art |
| Proximity voice chat | Large | Eng (needs networking review) |

---

## 2. Multiplayer: enter alone, finish together

**The rule:** *Anyone can start alone. Nobody can finish alone.*

### How it works for the player
1. On the main menu, tap **▶ Play Solo (friends can drop in)**.
2. You land in the Kitchen Counter immediately. A banner shows your **invite code**.
3. While alone:
   - You can walk, explore, grab things, talk to NPCs, find tokens.
   - Pressure plates **light up** when you step on them (so you learn they matter)…
   - …but **gates stay shut** and the **exit won't accept you**.
   - The **timer is paused** (⏸ shown next to it). No pressure while you wait.
4. A friend joins using your code / IP → they **drop straight into the same run**, spawn next to the others, and the banner flips to "🤝 Buddies here!". Timer starts.
5. Friends can also **leave mid-run** without crashing the game; their bean disappears and the roster updates.

### Lobby path (for planned sessions)
- **Host Game** → lobby with **buddy cards** (color stripe, hat, ✅/⏳ ready state).
- Everyone can tap **✋ I'm ready**.
- Host picks a map; each map shows a one-line description and recommended player count.
- With only 1 player, the button says **"Start anyway (explore until a buddy joins)"** — honest about the rule.

### Why this design
- Removes the #1 drop-off point in co-op games: *waiting in an empty lobby*.
- Keeps the core promise ("Nobody escapes alone") intact.
- Lets a solo player scout the map and teach friends later — a natural social hook.

### Under the hood (for engineers)
- `GameManager.is_coop_ready()` = 2+ players. Gates (`MultiPlateController`) and exit (`player_reached_exit`) check it.
- `NetworkManager.start_solo()` starts as a host so others can join at any time.
- Host sends `sync_running_game` to late joiners; `MapBase` spawns/despawns players on join/leave.
- Player profiles now use the **real network sender ID** (prevents one player overwriting another's name/hat).

> *Status: ✅ built* · **Known limits:** joining needs the host's IP address (same Wi-Fi, port-forward, or a free LAN tool like Tailscale). A proper **room-code server** (type "K7QX", no IP) is the top networking follow-up.

---

## 3. Cross-device: laptop, phone, controller

### Automatic device detection
The game detects phone vs. computer at startup, and **switches live** if you pick up a controller or touch the screen. All prompts and button sizes follow.

### Phone & tablet controls
| Area | Control |
|---|---|
| Left 40% of screen | **Floating joystick** — appears wherever your thumb lands |
| Right side | **Drag to look around** |
| Thumb buttons (bottom-right) | JUMP · GRAB · USE · DUCK · 🙌 high-five · 📍 ping · 😀 emotes |
| Top-right | ⏸ pause |

- Buttons are **at least 96 px** (scaled up on phones) — comfortably above the 44–48 px minimum touch target recommended by Apple/Google.
- Buttons send the **same actions as the keyboard**, so every feature works on phones without special code.
- UI text auto-scales **1.4×** on phones.

### Controller
Left stick moves, right stick looks, face buttons map to jump/use/grab/high-five. Prompts show button icons (Ⓐ Ⓧ Ⓨ ⓑ).

### Build targets (already set up)
| Platform | File | How |
|---|---|---|
| Windows | `.exe` | GitHub Actions, automatic |
| Linux | `.x86_64` | GitHub Actions |
| Android | `.apk` | GitHub Actions (debug-signed for testing) |
| Web / itch.io | `index.html` | GitHub Actions |

### Cross-play
Phones and laptops can be in the **same game** today when on the same network, because every platform uses the same connection type (except web).

> *Status: ✅ built (touch + gamepad + detection)* · **Gaps to plan:**
> - **Web builds can't host or join** the current connection type. Needs a WebRTC/relay upgrade — required for browser play on itch.io.
> - **iOS** needs an Apple developer account and a Mac to build.
> - **Performance tiers:** propose a "Phone" graphics preset (lower shadows, simpler models) — 30 fps target on mid-range phones.

---

## 4. Settings

Available from the **main menu** and **in-game pause**. Changes apply **instantly** and are **saved automatically**.

| Tab | Option | Why |
|---|---|---|
| 🔊 **Sound** | Master, Music, Sound effects, Voice chat volume | Independent control — mute music, keep the squeaks |
| 🖥 **Display** | Fullscreen, VSync, **Field of view (60–110°)**, FPS counter | Wide FOV reduces motion sickness for many players |
| 🎮 **Controls** | Look sensitivity, Invert up/down, **Crouch: toggle or hold** | Holding keys is hard for some players; toggle is default |
| ♿ **Accessibility** | Screen shake on/off, **Reduce motion**, **Large text**, Subtitles, **Colorblind filter** (3 types) | See below |

### Accessibility details
- **Reduce motion:** turns off camera wobble, idle jiggle, bouncy pop-ins, and spinning previews.
- **Large text:** +25% on all HUD and menu text (stacks with phone scaling).
- **Colorblind filters:** full-screen correction for red-green (deuteranopia, protanopia) and blue-yellow (tritanopia). We also **never rely on color alone** — plates show numbers (1/2), pings show icons, the roster shows ✅.
- **No time pressure alone:** the timer pauses in solo mode.

> *Status: ✅ built* · **Proposed next:** key rebinding screen, one-handed control preset, text-to-speech for NPC dialogue, a "chill mode" with no timer at all.

---

## 5. Character customization

### The customize screen
- **Live 3D preview** of your bean that slowly spins; **drag to rotate** it yourself.
- **12 colors** — 6 starters, 6 more unlocked by winning. Locked swatches show 🔒 with a hint.
- **9 hats** (+ "No Hat"). Locked hats are visible but greyed, with **how to earn them**:

| Hat | How to unlock |
|---|---|
| Traffic Cone | Starter |
| Chef Hat | Win in the Kitchen Counter |
| Royal Crown | Win any map with 4+ buddies |
| Party Hat | Give 10 high-fives total |
| Top Hat | Win 5 games |
| Propeller, Bucket, Viking, Fez | Random surprise reward on a win |

- **5 faces:** 😊 happy · 😮 surprised · 😤 determined · 😜 silly · 😴 sleepy
- **Chunkiness slider** — make your bean rounder or slimmer (visual only; hitbox stays the same for fairness).
- **🎲 Surprise me** — random outfit from what you own.

### How others see you
Your **color, hat, face, and size** are sent to every buddy. Your name tag shows your face emoji and is tinted in your color, so you're recognizable across the maze.

> *Status: ✅ built*

### Ideas for art & design (open for input)
| Category | Ideas |
|---|---|
| **Accessories beyond hats** | Glasses, mustaches, scarves, backpacks, capes, tiny pets that follow you |
| **Body patterns** | Stripes, spots, gradients, "melted ice cream" drip |
| **Map-themed sets** | Kitchen (oven mitt + apron), Attic (cobweb shawl), Garden (leaf crown) |
| **Shared cosmetics** | "Matching outfit" bonus when 2+ buddies wear the same hat |
| **Creative tools** | Paint-your-own-hat sticker editor; share outfit codes |
| **Fun reactions** | Hats fall off on pratfalls; propeller spins when jumping |

Art notes: keep new models **under ~5,000 triangles** and test on the phone preset. Hats should look good from behind — that's how teammates see you most of the time.

---

## 6. How the team can contribute

| Team | Where to start | Files |
|---|---|---|
| **Design** | Tutorial room, map blurbs, unlock goals | `lobby.gd` (MAP_BLURB), `cosmetic_manager.gd` (HAT_UNLOCK_HINTS) |
| **Art** | Accessories, patterns, ping/emote icons | `assets/models/items/`, `ModelSwap` component |
| **Audio** | Emote sounds, ping sound, NPC gibberish | `audio_manager.gd` (placeholder functions ready) |
| **Engineering** | Room-code server, WebRTC, key rebinding | `network_manager.gd`, `settings_panel.gd` |
| **QA** | Phone controls, drop-in/out, colorblind modes | Test plan below |
| **Community** | Name the emotes, vote on next hats | — |

### Quick test plan
1. **Solo → drop-in:** Play Solo, confirm gate stays shut and timer shows ⏸. Join from a 2nd instance; gate should now open with both on plates.
2. **Drop-out:** close the 2nd instance mid-run → bean disappears, roster updates, no crash.
3. **Phone:** export Android, confirm joystick, look-drag, every button.
4. **Settings persist:** change FOV + colorblind mode, restart → still applied.
5. **Unlocks:** win Kitchen Counter → Chef Hat appears unlocked in Customize.
6. **Reduce motion:** no camera shake, no bouncing emotes.

---

## 7. Open questions for the team

1. Should solo players be able to **collect tokens** before a buddy joins, or should tokens also wait? (Current: they can collect.)
2. Do we want a **"chill mode"** with no timer at all?
3. What's our minimum supported phone? This decides graphics presets.
4. Should emotes have **sounds** by default, or only visuals (quieter for streaming)?
5. Which accessory category should art tackle first?

*Every section above is a starting point — please add comments, sketches, and counter-proposals.*
