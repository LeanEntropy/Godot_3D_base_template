# Godot 3D Template: AI Agent Documentation

## 1. Core Architecture: State Machine

This project uses a **State Machine** pattern for player controls. All logic is driven by a single configuration value in `game_config.cfg`.

- **`player_controller.gd`**: The central controller. It reads `game_config.cfg` and loads the appropriate control script. **It contains no direct movement or camera logic.**
- **`/code/player_controllers/`**: This directory contains individual, self-contained scripts for each control mode (e.g., `first_person_controller.gd`). Each script is a "state" and is responsible for its own camera setup, input handling, and visuals.

This design is highly modular. To add or remove a control mode, you only need to add or delete a script in the `player_controllers` directory and update one line in `player_controller.gd`.

## 2. Key Files & Directories

- **`game_config.cfg`**: **Primary control file.**
  - `[camera] control_mode`: Change this value to switch player control modes (e.g., "tank", "isometric").
  - `[physics]`: Contains all global movement and camera parameters (speed, sensitivity, etc.).
  - `[controls]`: Defines universal keys (e.g., `pause_key_primary`).

- **`main.tscn`**: The main game scene.
  - Contains the environment, UI, and the `Player` node.
  - The `Player` node (`CharacterBody3D`) runs `player_controller.gd`.
  - All visual models (the player capsule, the tank model) are children of the `Player` node.

- **`/code/`**: All GDScript files.
  - **`game_config.gd` (Autoload)**: Loads `game_config.cfg` into a global singleton named `GameConfig` for easy access from any script.
  - **`logger.gd` (Autoload)**: A global logger. Use `Logger.info("message")`, `Logger.warning("message")`, `Logger.error("message")`. For performance, use `Logger.start_performance_check("my_func")` and `Logger.end_performance_check("my_func")`.
  - **`/player_controllers/`**: The individual controller scripts.

- **`/assets/`**: All `.tscn` and `.tres` resource files. Reusable components like `red_box.tscn` are here.

## 3. How to Perform Common Tasks

### How to Change Player Control Mode

1.  Open `game_config.cfg`.
2.  Set `control_mode` to a valid option (e.g., `control_mode = "first_person"`). The available modes are listed in the file's comments.

### How to Add a New Control Mode

1.  Create a new script (e.g., `new_mode_controller.gd`) in `/code/player_controllers/`.
2.  Use an existing controller as a template. It **must** have:
    - An `initialize(player_node)` function for setup.
    - A `handle_input(event)` function.
    - A `handle_physics(delta)` function.
3.  Open `code/player_controller.gd`.
4.  Add a new entry to the `match` statement in `initialize_controller()`:
    ```gdscript
    "new_mode":
        current_controller = load("res://code/player_controllers/new_mode_controller.gd").new()
    ```
5.  Add `"new_mode"` to the comments in `game_config.cfg`.

### How to Modify Visuals

- **The active controller script is responsible for managing visuals.**
- Each controller's `initialize()` function gets references to all visual nodes (e.g., `player_mesh`, `tank_hull`) and calls `.show()` or `.hide()` on them as needed for that mode.
- To add a new visual model, add it as a child of `Player` in `main.tscn`, then update the `initialize()` function in **every** controller script to get a reference to it and set its visibility.
