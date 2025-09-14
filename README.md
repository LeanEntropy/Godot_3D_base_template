# Godot 3D base template
Godot 4.4 Base Template for 3D games
Base code by civax (x: @civaxo, github: @LeanEntropy)

A comprehensive, modular 3D game template for Godot that supports multiple control schemes and can be easily customized for any 3D game project.

<img width="1280" height="720" alt="image" src="https://github.com/user-attachments/assets/76e1b6d8-41ca-41f4-97af-4f96a5d80af7" />


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


## Contributing

This template is designed to be extended and improved. Feel free to extend it.
