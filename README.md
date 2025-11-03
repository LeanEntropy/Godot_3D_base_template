# Godot 4.4 3D Game Template

A modular, configuration-driven 3D game template for Godot 4.4 featuring 7 different player control modes, an optional shooting system, and a clean component-based architecture.

Base code by civax (x: @civaxo, github: @LeanEntropy)

## Features

- **7 Controller Modes**: First-person, third-person, over-the-shoulder, tank, free camera, top-down, and isometric
- **Three-Camera Architecture**: Separate cameras for different control styles prevent conflicts
- **Scene Management**: Smooth fade transitions with optional animated loading bar
- **Optional Title Screen**: Configurable splash screen with PLAY button and customizable backgrounds
- **Optional Shooting System**: Easy-to-enable/disable modular weapon system
- **Config-Driven Design**: Modify game behavior through `game_config.cfg` without code changes
- **Component-Based**: Modular, reusable systems (WeaponComponent, ShootingComponent, AimingHelper)
- **AI-Friendly**: Clean architecture with comprehensive documentation for AI-assisted development

---

## Quick Start

1. **Open Project**: Open this folder in Godot 4.4 or later
2. **Run Game**: Press F5 or click the Play button
3. **Switch Modes**: Edit `game_config.cfg` → `[global]` → `controller_mode` to change control scheme
4. **Configure**: Adjust parameters in `game_config.cfg` for each mode

### Changing Controller Mode

Edit `game_config.cfg`:

```ini
[global]
controller_mode = "first_person"  # Change this value
```

Available modes: `first_person`, `third_person`, `over_the_shoulder`, `tank`, `free_camera`, `top_down`, `isometric`

---

## Controller Modes

### 1. First Person (FPS)
**Camera**: Attached to player head, first-person view
**Movement**: WASD + mouse look
**Best For**: FPS games, immersive exploration

**Controls**:
- `W/A/S/D` - Move forward/left/back/right
- `Mouse` - Look around (captured cursor)
- `Shift` - Sprint
- `Space` - Jump
- `Left Click` - Shoot (if shooting enabled)
- `P` or `Escape` - Pause

**Config Section**: `[first_person]`

---

### 2. Third Person
**Camera**: Behind and above player, follows from fixed distance
**Movement**: WASD + character rotates to face movement direction
**Best For**: Action-adventure games, character-focused gameplay

**Controls**:
- `W/A/S/D` - Move forward/left/back/right (character rotates to face direction)
- `Mouse` - Aim camera (captured cursor)
- `Shift` - Sprint
- `Space` - Jump
- `Left Click` - Shoot (if shooting enabled)
- `P` or `Escape` - Pause

**Config Section**: `[third_person]`

---

### 3. Over-the-Shoulder (OTS)
**Camera**: Offset to right side of player, shooter-style view
**Movement**: WASD + smooth character rotation toward camera direction
**Best For**: Third-person shooters, tactical games

**Controls**:
- `W/A/S/D` - Move forward/left/back/right (character faces camera direction)
- `Mouse` - Aim camera (captured cursor)
- `Shift` - Sprint
- `Space` - Jump
- `Left Click` - Shoot (if shooting enabled)
- `P` or `Escape` - Pause

**Config Section**: `[over_the_shoulder]`

---

### 4. Tank
**Camera**: Behind and above tank, third-person view
**Movement**: Tank-style controls with separate hull and turret rotation
**Best For**: Vehicle games, tank simulators

**Controls**:
- `W/S` - Move forward/backward
- `A/D` - Rotate hull left/right
- `Mouse` - Aim turret (captured cursor)
- `Left Click` - Fire main gun (if shooting enabled)
- `P` or `Escape` - Pause

**Config Section**: `[tank]`

**Special Features**:
- Independent turret rotation follows mouse
- Barrel elevation controlled by mouse Y
- Uses built-in turret mesh (no separate weapon model)

---

### 5. Free Camera
**Camera**: Orbiting camera controlled by mouse, player stays centered
**Movement**: WASD moves player, mouse orbits camera around player
**Best For**: Debug mode, cinematic camera control, twin-stick-style gameplay

**Controls**:
- `W/A/S/D` - Move player forward/left/back/right
- `Mouse Movement` - Orbit camera around player (visible cursor)
- `Mouse Wheel` - Zoom in/out
- `Shift` - Sprint
- `Left Click` - Shoot toward cursor (if shooting enabled)
- `P` or `Escape` - Pause

**Config Section**: `[free_camera]`

**Special Features**:
- Weapon rotates to face cursor
- Camera freely orbits independent of movement
- Useful for showcasing models or debugging

---

### 6. Top-Down
**Camera**: Directly overhead, looking straight down
**Movement**: Click-to-move or WASD, character faces movement direction
**Best For**: RTS games, strategy games, classic RPGs

**Controls**:
- `W/A/S/D` - Move in cardinal directions
- `Left Click` - Move to clicked location
- `Mouse` - Visible cursor for targeting
- `Left Click` - Shoot at cursor (if shooting enabled)
- `P` or `Escape` - Pause

**Config Section**: `[top_down]`

**Special Features**:
- Weapon rotates to face cursor
- Camera height adjustable in config
- Click-to-move pathfinding

---

### 7. Isometric
**Camera**: 45-degree angle, isometric perspective
**Movement**: Click-to-move or WASD, character faces movement direction
**Best For**: Isometric RPGs, strategy games, classic adventure games

**Controls**:
- `W/A/S/D` - Move in screen-relative directions
- `Left Click` - Move to clicked location
- `Mouse` - Visible cursor for targeting
- `Left Click` - Shoot at cursor (if shooting enabled)
- `Mouse Wheel` - Zoom in/out
- `P` or `Escape` - Pause

**Config Section**: `[isometric]`

**Special Features**:
- Weapon rotates to face cursor
- Adjustable camera angle and distance
- WASD movement rotated to match camera angle

---

## Shooting System

The shooting system is **optional** and **modular**. It can be easily enabled or disabled without breaking the project.

### Current Status: ENABLED ✅

The shooting system is currently active in this project.

### How to Disable Shooting

If you want to remove the shooting functionality:

1. **Delete the ShootingComponent from Player**:
   - Open `main.tscn`
   - Select the `Player` node
   - Find the `ShootingComponent` child node
   - Delete it

2. **Delete Shooting Files** (optional, for clean project):
   ```
   code/components/shooting_component.gd
   code/components/weapon_component.gd
   code/components/aiming_helper.gd
   code/tank_projectile.gd
   assets/tank_projectile.tscn
   assets/projectile_hit_effect.tscn
   assets/weapons/ (entire folder)
   ```

3. **Remove Input Action** (optional):
   - Open Project Settings → Input Map
   - Remove the `shoot` action

### How to Enable Shooting

If shooting has been disabled and you want to re-enable it:

1. **Add ShootingComponent to Player**:
   - Open `main.tscn`
   - Select the `Player` node
   - Click "Instantiate Child Scene" (chain link icon)
   - Navigate to `code/components/shooting_component.gd` (or add as script to new Node)
   - Attach as child of Player

2. **Ensure Required Files Exist**:
   - `code/components/shooting_component.gd` - Core shooting logic
   - `code/components/weapon_component.gd` - Weapon model management
   - `code/components/aiming_helper.gd` - Aim calculation utilities
   - `code/tank_projectile.gd` - Projectile behavior
   - `assets/tank_projectile.tscn` - Projectile scene
   - `assets/weapons/*.tscn` - Weapon models (optional, visual only)

3. **Add Input Action** (if removed):
   - Open Project Settings → Input Map
   - Add action: `shoot`
   - Bind to: Mouse Button Left

### Shooting Configuration

Edit `game_config.cfg` to customize shooting behavior:

```ini
[shooting]
fire_rate_fps = 0.15              # Seconds between shots for FPS/TPS modes
fire_rate_tank = 0.5              # Seconds between shots for tank mode
projectile_speed_fps = 50.0       # Speed for FPS/TPS projectiles
projectile_speed_tank = 40.0      # Speed for tank projectiles
projectile_gravity_scale = 0.15   # Gravity effect (0.0 = straight, 1.0 = full gravity)
aim_ray_length = 1000.0           # Max distance for aim raycasting
tank_launch_angle = 0.1           # Upward angle for tank shots

[projectile]
mesh_radius = 0.2                 # Size of projectile sphere
mesh_color = "000000"             # Hex color (e.g., "FF0000" for red, "000000" for black)
emission_energy = 2.0             # Glow intensity
light_enabled = true              # Enable point light on projectile
light_color = "FF8800"            # Light color (orange)
light_energy = 4.0                # Light brightness
light_range = 5.0                 # Light radius
lifetime = 8.0                    # Seconds before projectile despawns
damage = 25                       # Damage dealt on hit

[weapons]
show_weapon_first_person = true   # Show weapon model in first-person
show_weapon_third_person = true   # Show weapon model in third-person
show_weapon_over_the_shoulder = true
show_weapon_tank = false          # Tank uses built-in turret
show_weapon_free_camera = true
show_weapon_top_down = true
show_weapon_isometric = true
weapon_model_first_person = "res://assets/weapons/fps_pistol.tscn"
weapon_model_third_person = "res://assets/weapons/tps_rifle.tscn"
weapon_model_over_the_shoulder = "res://assets/weapons/tps_rifle.tscn"
weapon_model_free_camera = "res://assets/weapons/tps_rifle.tscn"
weapon_model_top_down = "res://assets/weapons/topdown_gun.tscn"
weapon_model_isometric = "res://assets/weapons/topdown_gun.tscn"
```

---

## Title Screen System

The template includes an **optional title screen** that displays when the game starts, pauses gameplay, and shows a PLAY button to begin the game.

### Current Status: DISABLED ⚪

The title screen is currently disabled in `game_config.cfg`. Set `show_title_screen = true` to enable it.

### Features

- **Three Background Modes**:
  - **Transparent**: Shows game scene through the title screen
  - **Image**: Custom background image (place at specified path)
  - **Solid Color**: Configurable color with adjustable opacity

- **Customizable Appearance**:
  - Button colors (normal, hover, pressed states)
  - Text colors
  - Background colors with alpha/opacity control

- **Title Image Support**:
  - Display custom game title image (`res://assets/UI/GameTitle.png`)
  - Automatic fallback to text if image is missing

### How to Enable

1. **Edit `game_config.cfg`**:
   ```ini
   [title_screen]
   show_title_screen = true
   ```

2. **Run the game** - Title screen will display automatically

3. **Click PLAY** - Game begins with proper mouse mode for active controller

### How to Disable

Set in `game_config.cfg`:
```ini
[title_screen]
show_title_screen = false
```

### Configuration Options

Edit the `[title_screen]` section in `game_config.cfg`:

```ini
[title_screen]
show_title_screen = true               # Enable/disable title screen
have_background = true                 # false = transparent, true = image or color

# Background Image (optional - takes priority over solid color)
background_image = ""                  # Path to image, e.g., "res://assets/UI/background.png"

# Solid Color Background (used if no image specified)
background_color = "1A1A2E"            # Hex color (6 digits, no #)
background_color_opacity = 1.0         # 0.0 (invisible) to 1.0 (solid)

# Button Appearance
button_color = "16213E"                # Normal button color
button_hover_color = "0F3460"          # Button color on mouse hover
button_text_color = "FFFFFF"           # Button text color
```

### Background Modes

**1. Transparent Background** (Show game scene behind title)
```ini
have_background = false
```
- Title screen overlays the game scene
- Game is visible but paused in the background
- Clean, minimal look

**2. Image Background** (Custom splash screen)
```ini
have_background = true
background_image = "res://assets/UI/my_background.png"
```
- Full-screen background image
- Automatically scales to fit screen
- Create image at any resolution (1920x1080 recommended)

**3. Solid Color Background** (Simple colored backdrop)
```ini
have_background = true
background_image = ""
background_color = "1A1A2E"
background_color_opacity = 0.95
```
- Solid color fills the screen
- Adjustable opacity for semi-transparent effect
- Use hex color format: "RRGGBB" (no # prefix)

### Adding a Custom Title Image

1. **Create your title image** (PNG format recommended)
   - Recommended size: 600x200 pixels
   - Use transparency for non-rectangular logos

2. **Save as**: `assets/UI/GameTitle.png`

3. **Automatic Detection**: The title screen will automatically load this image

4. **Fallback**: If image is missing, displays "GAME TEMPLATE" as text

### Color Format

All colors use **6-digit hex format without the # prefix**:
- `"FFFFFF"` = White
- `"000000"` = Black
- `"FF0000"` = Red
- `"00FF00"` = Green
- `"0000FF"` = Blue
- `"1A1A2E"` = Dark blue-gray (default background)

Use any color picker tool and copy the hex value (without the #).

### How It Works

When enabled:
1. Game starts with title screen visible and gameplay paused
2. Mouse cursor is visible for clicking the PLAY button
3. Player input and physics are disabled
4. Clicking PLAY:
   - Unpauses the game
   - Hides title screen with fade animation
   - Shows game UI
   - Enables player controls
   - Sets appropriate mouse mode for active controller (captured for FPS/tank, visible for top-down)

---

## Scene Management

The template includes a simple scene management system for loading scenes with smooth fade transitions and an optional animated loading bar.

### Features

- **Config-Driven**: Define scene paths in `game_config.cfg`
- **Fade Transitions**: Smooth black fade between scenes (0.5s default)
- **Animated Loading Bar**: Optional progress bar during transitions
- **Error Handling**: Graceful handling of missing scenes
- **Signal-Based**: Listen for scene change events
- **Logger Integration**: Automatic logging and timing

### Quick Start

**1. Define scenes in `game_config.cfg`:**
```ini
[scenes]
main_menu = "res://assets/UI/main_menu.tscn"
level_1 = "res://assets/levels/level_1.tscn"
level_2 = "res://assets/levels/level_2.tscn"
```

**2. Change scenes in your code:**
```gdscript
# With fade transition and loading bar
SceneManager.change_scene("level_1")

# Without fade (instant)
SceneManager.change_scene_instant("main_menu")

# Reload current scene
SceneManager.reload_current_scene()
```

### Configuration

Customize the appearance in `game_config.cfg`:

```ini
[scene_manager]
fade_duration = 0.5                # Fade in/out duration in seconds
show_loading_bar = true            # Show animated progress bar
loading_bar_color = "4A90E2"       # Hex color (blue by default)
loading_bar_width = 400            # Bar width in pixels
loading_bar_height = 20            # Bar height in pixels
```

### Common Use Cases

**Main menu → Game**:
```gdscript
func _on_play_button_pressed() -> void:
    SceneManager.change_scene("level_1")
```

**Level complete → Next level**:
```gdscript
func _on_level_exit_reached() -> void:
    SceneManager.change_scene("level_2")
```

**Player death → Restart**:
```gdscript
func _on_player_died() -> void:
    SceneManager.reload_current_scene()
```

**Quit to menu**:
```gdscript
func _on_quit_to_menu_pressed() -> void:
    get_tree().paused = false  # Unpause if paused
    SceneManager.change_scene("main_menu")
```

**Save before scene change**:
```gdscript
func _ready() -> void:
    SceneManager.scene_changing.connect(_on_scene_changing)

func _on_scene_changing(from: String, to: String) -> void:
    PlayerData.save_state()  # Save player progress
```

See `docs/project_structure.md` for detailed documentation and architecture.

---

## Configuration

All game behavior is controlled through `game_config.cfg`. Changes take effect immediately when you restart the scene.

### Structure

The config file uses sections for each controller mode:

```ini
[global]
controller_mode = "first_person"
capture_mouse_on_start = true

[first_person]
movement_speed = 5.0
sprint_multiplier = 1.5
jump_velocity = 4.5
gravity = 9.8
mouse_sensitivity = 0.002
fov = 75.0

[third_person]
movement_speed = 5.0
camera_distance = 5.0
camera_height = 2.0
...
```

### Common Parameters

**Movement**:
- `movement_speed` - Base movement speed
- `sprint_multiplier` - Speed multiplier when sprinting
- `jump_velocity` - Jump force (where applicable)
- `gravity` - Gravity strength (where applicable)

**Camera**:
- `mouse_sensitivity` - Mouse look sensitivity
- `fov` - Field of view in degrees
- `camera_distance` - Distance from player (third-person modes)
- `camera_height` - Height offset (third-person modes)

**UI**:
```ini
[ui]
show_crosshair = true
crosshair_color = "FFFFFF"
show_fps = false
show_debug_info = false
```

---

## Project Structure

```
Godot_3D_base_template/
├── assets/                      # All scene files (.tscn)
│   ├── UI/                     # User interface scenes
│   │   ├── ui_layer.tscn            # Main UI and pause menu
│   │   ├── title_screen.tscn        # Title screen with PLAY button
│   │   └── GameTitle.png            # Title image (optional)
│   ├── weapons/                # Weapon model scenes
│   ├── tank_projectile.tscn    # Projectile scene
│   └── projectile_hit_effect.tscn
│
├── code/                        # All scripts (.gd)
│   ├── components/             # Modular game systems
│   │   ├── weapon_component.gd      # Weapon model management
│   │   ├── shooting_component.gd    # Shooting logic
│   │   └── aiming_helper.gd         # Aim calculation utilities
│   │
│   ├── player_controllers/     # Controller implementations
│   │   ├── first_person_controller.gd
│   │   ├── third_person_controller.gd
│   │   ├── over_the_shoulder_controller.gd
│   │   ├── tank_controller.gd
│   │   ├── free_camera_controller.gd
│   │   ├── top_down_controller.gd
│   │   └── isometric_controller.gd
│   │
│   ├── UI/                     # UI controllers
│   │   ├── ui_layer.gd              # Main UI and pause menu
│   │   └── title_screen.gd          # Title screen with PLAY button
│   │
│   ├── player_controller.gd    # Main controller dispatcher
│   ├── main.gd                 # Main scene controller
│   ├── game_config.gd          # Config system (autoload)
│   ├── logger.gd               # Logging system (autoload)
│   └── tank_projectile.gd      # Projectile script
│
├── docs/                        # Additional documentation
│   └── project_structure.md    # Technical architecture docs
│
├── main.tscn                    # Main game scene
├── game_config.cfg              # Runtime configuration
├── project.godot                # Godot project file
├── README.md                    # This file
├── CLAUDE.md                    # AI development guide
└── .clauderules                 # AI assistant rules
```

---

## Three-Camera System

This template uses a **three-camera architecture** to prevent conflicts between different control modes:

1. **PlayerCamera**: Used by first_person, third_person, over_the_shoulder
   - Attached to player or camera arm
   - Controlled by player input directly

2. **ObserverCamera**: Used by top_down, isometric, free_camera
   - Separate camera node independent of player
   - Mouse-controlled or fixed position

3. **TankCamera**: Used exclusively by tank mode
   - Follows tank hull
   - Separate from player cameras to avoid rotation issues

Each controller calls `camera.make_current()` to activate its designated camera when the mode switches.

---

## Extending the Template

### Adding a New Controller Mode

1. Create `code/player_controllers/my_mode_controller.gd`:
```gdscript
extends Node

var player: CharacterBody3D

func initialize(player_node: CharacterBody3D) -> void:
    player = player_node
    Logger.info("MyMode initialized")

func handle_input(event: InputEvent) -> void:
    # Handle input events
    pass

func handle_physics(delta: float) -> void:
    # Update physics every frame
    pass
```

2. Add config section in `game_config.cfg`:
```ini
[my_mode]
movement_speed = 5.0
# Add your parameters
```

3. Set controller mode:
```ini
[global]
controller_mode = "my_mode"
```

### Adding New Components

1. Create script in `code/components/`
2. Attach to Player node in `main.tscn`
3. Access other components via `get_node()` or signals
4. Use `GameConfig` for configuration values

---

## Troubleshooting

### Projectiles are the wrong color
- Check `[projectile]` → `mesh_color` in `game_config.cfg`
- Use 6-digit hex format: `"FF0000"` (red), `"000000"` (black)
- Check console for "Projectile color from config" log

### Weapon not visible in isometric/top-down
- Check `[weapons]` → `show_weapon_isometric` or `show_weapon_top_down` = `true`
- Ensure weapon model path is correct in config
- Check console for "WeaponComponent initialized" logs

### Weapon pointing wrong direction
- Free camera/isometric: Weapon should rotate toward cursor
- Check console for rotation logs
- Verify mouse cursor is visible in these modes

### Camera not switching between modes
- Each controller must call `camera.make_current()`
- Check that correct camera exists in scene (PlayerCamera, ObserverCamera, TankCamera)
- See console for "Camera activated" logs

### Tank turret not moving
- Ensure mouse is captured (should be in tank mode)
- Check `[tank]` → `turret_rotation_speed` and `mouse_sensitivity`
- Verify TankCamera exists in scene

### Player can't move
- Check that controller mode is set correctly in `[global]` → `controller_mode`
- Verify input actions are defined in Project Settings → Input Map
- Check collision layers (player should be on layer 1, environment on layer 2)

### Mouse cursor issues
- First-person/third-person/OTS/tank: Cursor should be CAPTURED
- Top-down/isometric/free camera: Cursor should be VISIBLE
- Toggle pause (P or Escape) to release cursor

---

## Version Info

- **Godot Version**: 4.4.1
- **Template Version**: 1.0
- **Last Updated**: October 2025

---

## Additional Documentation

- **CLAUDE.md**: AI development guide with architecture patterns
- **docs/project_structure.md**: Technical architecture documentation
- **.clauderules**: Rules for AI assistants working on this project

---

## License

This template is provided as-is for use in your projects. Modify and extend as needed.
