# Godot 3D Base Template

A comprehensive, modular 3D game template for Godot that supports multiple control schemes and can be easily customized for any 3D game project.

Base code by civax.
https://github.com/LeanEntropy/Godot_3D_base_template


## Purpose

This template is designed to be the perfect starting point for 3D games in Godot. It provides:

- **Multiple Control Modes**: Switch between first-person, third-person, tank controls, and more with a single config change
- **Modular Architecture**: Clean, maintainable code that's easy to extend and modify
- **Easy Cleanup**: Remove unused control modes to create a focused, single-purpose game
- **Production Ready**: Includes logging, configuration management, and best practices

## Architecture Overview

### Core Design Pattern: State Machine for Controls

The template uses a **State Machine pattern** for player controls, making it incredibly flexible:

- **Single Configuration**: All control modes are managed through `game_config.cfg`
- **Modular Controllers**: Each control mode is a self-contained script
- **Easy Switching**: Change control modes without touching code
- **Clean Separation**: No mixing of different control logic

## Project Structure

```
Godot_3D_base_template/
├── 📁 assets/                    # Reusable game assets
│   ├── destination_marker.tscn   # Animated destination marker
│   ├── red_box.tscn             # Physics-enabled red box
│   ├── tank_model.tscn          # Complete tank model with turret
│   └── 📁 UI/
│       └── ui_layer.tscn        # Game UI layer
├── 📁 code/                      # All GDScript files
│   ├── game_config.gd           # Configuration manager (Autoload)
│   ├── logger.gd                # Logging system (Autoload)
│   ├── player_controller.gd     # Main player controller
│   ├── player_visuals_manager.gd # Visual effects manager
│   ├── 📁 player_controllers/   # Individual control modes
│   │   ├── first_person_controller.gd
│   │   ├── third_person_controller.gd
│   │   ├── over_the_shoulder_controller.gd
│   │   ├── top_down_controller.gd
│   │   ├── isometric_controller.gd
│   │   ├── free_camera_controller.gd
│   │   └── tank_controller.gd
│   └── 📁 UI/
│       └── ui_layer.gd          # UI management
├── 📁 docs/                      # Documentation
│   ├── project_mapping.json     # AI-readable project structure
│   └── project_structure.md     # This file
├── main.tscn                    # Main game scene
├── game_config.cfg              # Game configuration
├── default_env.tres             # Environment settings
└── project.godot               # Godot project file
```

## Available Control Modes

- `first_person` - Classic FPS controls. Best for: First-person shooters, exploration games
- `third_person_follow` - Camera follows behind player. Best for: Action-adventure games, RPGs
- `over_the_shoulder` - Camera positioned over shoulder. Best for: Third-person shooters, action games
- `top_down` - Bird's eye view. Best for: Strategy games, top-down shooters
- `isometric` - Fixed isometric angle. Best for: Isometric RPGs, strategy games
- `free_camera` - Unrestricted camera movement. Best for: Level editors, debug tools
- `fixed_camera` - Static camera position. Best for: Cinematic sequences, puzzle games
- `tank` - Tank-style movement with turret. Best for: Vehicle games, military simulations

## Configuration System

### Game Configuration (`game_config.cfg`)

The heart of the template - change one value to switch control modes:

```ini
[camera]
control_mode = "first_person"  # Change this to switch modes

[controls]
pause_key_primary = "P"
pause_key_secondary = "Escape"

[physics]
speed = 5.0
gravity = 9.8
mouse_sensitivity = 0.002
```

### Global Access

Configuration is available everywhere through the `GameConfig` singleton:

```gdscript
# Access any config value
var player_speed = GameConfig.get_value("physics", "speed")
var control_mode = GameConfig.get_value("camera", "control_mode")
```

## Quick Start Guide

### 1. Choose Your Control Mode

Open `game_config.cfg` and set your desired control mode:

```ini
[camera]
control_mode = "third_person_follow"  # or any other mode
```

### 2. Customize Settings

Adjust physics, camera, and control parameters in the same file:

```ini
[physics]
speed = 8.0                    # Player movement speed
mouse_sensitivity = 0.003      # Camera sensitivity
gravity = 12.0                 # Gravity strength
```

### 3. Run and Test

Press F5 to run the game and test your chosen control mode!

## Common Tasks

### Switching Control Modes

1. Open `game_config.cfg`
2. Change `control_mode` to your desired mode
3. Save and run the game

**Available modes**: `first_person`, `third_person_follow`, `over_the_shoulder`, `top_down`, `isometric`, `free_camera`, `fixed_camera`, `tank`

### Adding a New Control Mode

1. **Create the controller script** in `code/player_controllers/`:
   ```gdscript
   # new_mode_controller.gd
   extends Node
   
   func initialize(player_node):
       # Setup code here
       pass
   
   func handle_input(event):
       # Input handling here
       pass
   
   func handle_physics(delta):
       # Physics update here
       pass
   ```

2. **Register the controller** in `code/player_controller.gd`:
   ```gdscript
   match control_mode:
       "new_mode":
           current_controller = load("res://code/player_controllers/new_mode_controller.gd").new()
   ```

3. **Add to config** in `game_config.cfg`:
   ```ini
   ; Available modes: first_person, third_person_follow, ..., new_mode
   ```

### Modifying Visuals

Each controller manages its own visuals:

1. **Add visual nodes** to the Player in `main.tscn`
2. **Update all controllers** to reference the new visual
3. **Show/hide appropriately** in each controller's `initialize()` function

### Adding New Assets

1. **Place assets** in the `assets/` directory
2. **Create scenes** (`.tscn` files) for reusable components
3. **Instance in main scene** or other scenes as needed

## Cleaning Up for Production

### Remove Unused Control Modes

1. **Delete controller scripts** you don't need from `code/player_controllers/`
2. **Remove from player_controller.gd** - delete the corresponding `match` case
3. **Update game_config.cfg** - remove from the available modes comment
4. **Clean up visuals** - remove unused visual nodes from `main.tscn`

### Focus on Single Control Mode

For a production game with one control mode:

1. **Keep only your chosen controller**
2. **Simplify player_controller.gd** - remove the state machine
3. **Remove game_config.cfg** - hardcode your settings
4. **Clean up unused assets**

## Advanced Features

### Logging System

Built-in logging for debugging and monitoring:

```gdscript
Logger.info("Player moved to position: " + str(position))
Logger.warning("Low health detected!")
Logger.error("Failed to load asset: " + asset_path)

# Performance monitoring
Logger.start_performance_check("update_physics")
# ... your code ...
Logger.end_performance_check("update_physics")
```

### Visual Effects Manager

Centralized visual effects management:

```gdscript
# Access from any script
PlayerVisualsManager.show_selection_ring()
PlayerVisualsManager.hide_tank_model()
```

## Contributing

This template is designed to be extended and improved. Feel free to extend it.