# Willowmere

A cozy springtime village RPG built in Godot. Explore the town, talk with its residents, gather five spring crops for Mira, and earn the Garden Star. The title screen includes the controls and optional Gemini setup. The map, props, collisions, player, and villagers are authored as nodes in `World.tscn` rather than created by the game script.

## Editing the scene

Open `Main.tscn` to see the full scene tree, then open `World.tscn` to edit the map and its nodes in Godot's 2D editor. `Main.gd` handles gameplay and builds the runtime interface.

## Controls

- **Enter / Space** — Start from the title screen
- **WASD / Arrow keys** — Move
- **E** — Talk to nearby villagers or harvest a nearby crop
- **Esc** — Close dialogue or settings

Villager greetings and the garden quest work without an API key. For free-form Gemini-powered conversations, add a Google AI Studio API key through **Gemini settings** on the title screen or **Settings** in-game.
