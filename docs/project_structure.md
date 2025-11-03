# Project Structure - Technical Architecture Documentation

## Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [Core Design Patterns](#core-design-patterns)
3. [Three-Camera System](#three-camera-system)
4. [Component Architecture](#component-architecture)
5. [Controller System](#controller-system)
6. [Shooting System](#shooting-system)
7. [Configuration System](#configuration-system)
8. [File Reference](#file-reference)
9. [Data Flow](#data-flow)
10. [Extending the System](#extending-the-system)

---

## Architecture Overview

This is a **modular, component-based 3D game template** built on three architectural pillars:

1. **State Machine Controller Pattern**: Interchangeable player control implementations
2. **Three-Camera Architecture**: Separate cameras prevent mode conflicts
3. **Component-Based Systems**: Optional, modular gameplay features

### Key Principles

- **Separation of Concerns**: Controllers, components, and systems are independent
- **Configuration-Driven**: Runtime behavior controlled via `game_config.cfg`
- **Hot-Swappable**: Change control modes without code modification
- **Optional Modularity**: Enable/disable features without breaking the project

---

## Core Design Patterns

### 1. State Machine Pattern (Controllers)

The player controller uses a **Strategy Pattern** / **State Machine** hybrid:

```
PlayerController (Dispatcher)
├─> Loads controller based on config
├─> Routes input/physics to active controller
└─> Controllers are stateless between switches

Each Controller:
├─> initialize(player_node) - Setup phase
├─> handle_input(event) - Input processing
└─> handle_physics(delta) - Physics update
```

**Benefits**:
- Add new control modes without modifying existing code
- Each mode is self-contained and testable
- No coupling between different control implementations

### 2. Component Pattern (Gameplay Features)

Optional gameplay features use a **Component Pattern**:

```
Player (CharacterBody3D)
├─> WeaponComponent (manages weapon models)
├─> ShootingComponent (handles firing logic)
└─> [Future components...]
```

**Benefits**:
- Features can be added/removed by adding/removing child nodes
- Components communicate via signals and method calls
- No central "God object" managing everything

### 3. Singleton Pattern (Global Systems)

Core systems use **Autoload Singletons**:

```
GameConfig (Autoload)
├─> Loads game_config.cfg on startup
├─> Provides global access to configuration
└─> Emits signals when config changes

Logger (Autoload)
├─> Centralized logging with levels (info/warning/error)
├─> Performance timing utilities
└─> Console output formatting
```

---

## Three-Camera System

**Critical Design Decision**: This template uses **three separate cameras** to prevent conflicts between controller modes.

### Why Three Cameras?

Different control modes have fundamentally incompatible camera requirements:
- **First-person modes**: Camera attached to player head, moves/rotates with player
- **Top-down modes**: Camera fixed or independent, never rotates
- **Tank mode**: Camera follows hull, not affected by turret rotation

A single camera cannot satisfy all these requirements simultaneously.

### Camera Architecture

```
Main Scene
├─> Player (CharacterBody3D)
│   ├─> Head (Node3D)
│   │   └─> PlayerCamera (Camera3D)  ← Camera 1
│   ├─> CameraArm (SpringArm3D)
│   │   └─> (PlayerCamera attached here for TPS/OTS)
│   └─> [Controllers reference PlayerCamera]
│
├─> ObserverCamera (Camera3D)  ← Camera 2
│   └─> Used by: top_down, isometric, free_camera
│
└─> Tank (Node3D, child of Player when active)
    └─> TankCamera (Camera3D)  ← Camera 3
        └─> Used exclusively by tank mode
```

### Camera Assignment

| Controller Mode | Camera Used | Attachment Point | Rotation Behavior |
|----------------|-------------|------------------|-------------------|
| `first_person` | PlayerCamera | Player/Head | Rotates with mouse |
| `third_person` | PlayerCamera | Player/CameraArm | Orbits behind player |
| `over_the_shoulder` | PlayerCamera | Player/CameraArm | Offset right, follows aim |
| `top_down` | ObserverCamera | Independent | Fixed overhead |
| `isometric` | ObserverCamera | Independent | Fixed 45° angle |
| `free_camera` | ObserverCamera | Independent | Mouse-controlled orbit |
| `tank` | TankCamera | Tank hull | Follows hull, not turret |

### Camera Switching

Each controller calls `camera.make_current()` in its `initialize()` function:

```gdscript
func initialize(player_node: CharacterBody3D) -> void:
    player = player_node
    _camera = player.get_node("Head/PlayerCamera")
    _camera.make_current()  # Activate this camera
```

**Only one camera can be active** at any time. Godot automatically handles rendering from the current camera.

---

## Component Architecture

### WeaponComponent

**Location**: `code/components/weapon_component.gd`
**Purpose**: Manages weapon model visibility, positioning, and rotation for all controller modes

**Responsibilities**:
- Load weapon models from config (`[weapons]` section)
- Position weapons appropriately for each mode
- Rotate weapons toward aim target (for top-down/isometric/free_camera)
- Provide muzzle position for projectile spawning

**Key Methods**:
```gdscript
func get_muzzle_position() -> Vector3
    # Returns world position where projectiles spawn

func get_target_position() -> Vector3
    # Returns world position where player is aiming

func get_fire_direction() -> Vector3
    # Returns normalized direction from muzzle to target
```

**Mode-Specific Behavior**:
- **FPS**: Weapon attached to camera, positioned in bottom-right
- **TPS/OTS**: Weapon attached to player body, center mass
- **Top-down/Isometric**: Weapon rotates to face cursor
- **Free Camera**: Weapon rotates to face cursor, orbits with camera
- **Tank**: Uses built-in turret barrel, no separate weapon model

### ShootingComponent

**Location**: `code/components/shooting_component.gd`
**Purpose**: Handles shooting input, rate limiting, and projectile spawning

**Responsibilities**:
- Detect shoot input (mouse click)
- Apply fire rate limiting
- Spawn projectiles at muzzle position
- Set projectile direction using AimingHelper
- Play effects (muzzle flash, screen shake, sound - if enabled)

**Key Methods**:
```gdscript
func _handle_shooting(delta: float) -> void
    # Check fire rate and spawn projectile

func _spawn_projectile() -> void
    # Instantiate and configure projectile
```

**Configuration**:
```ini
[shooting]
fire_rate_fps = 0.15      # Cooldown between shots
projectile_speed_fps = 50.0
```

### AimingHelper

**Location**: `code/components/aiming_helper.gd`
**Purpose**: Utility class with static methods for aim calculation in different modes

**Static Methods**:
```gdscript
static func get_screen_center_target(camera, max_distance, exclude) -> Vector3
    # Raycast from screen center (FPS/TPS/OTS/Tank)

static func get_mouse_ground_target(camera, mouse_pos, ground_y, exclude) -> Vector3
    # Raycast from mouse to ground (Top-down/Isometric)

static func get_forward_target(camera, distance) -> Vector3
    # Simple forward direction (Free camera)

static func calculate_fire_direction(muzzle_pos, target_pos) -> Vector3
    # Normalized direction vector

static func get_target_for_mode(mode, camera, player, max_distance) -> Vector3
    # Convenience function that routes to appropriate method
```

**Architecture Note**: This is a **static utility class** with no state. All methods are pure functions.

---

## Controller System

### Player Controller (Dispatcher)

**Location**: `code/player_controller.gd`
**Purpose**: Main orchestrator that loads and manages controller instances

**Lifecycle**:
```
_ready()
├─> Load GameConfig
├─> Detect controller mode from config
├─> Load appropriate controller script
├─> Call controller.initialize(self)
└─> Store reference to current_controller

_unhandled_input(event)
└─> current_controller.handle_input(event)

_physics_process(delta)
└─> current_controller.handle_physics(delta)
```

**Controller Loading**:
```gdscript
func initialize_controller() -> void:
    var mode = GameConfig.get_value("global", "controller_mode", "first_person")

    match mode:
        "first_person":
            current_controller = load("res://code/player_controllers/first_person_controller.gd").new()
        "tank":
            current_controller = load("res://code/player_controllers/tank_controller.gd").new()
        # ... etc

    add_child(current_controller)
    current_controller.initialize(self)
```

### Controller Interface Contract

All controllers must implement this interface:

```gdscript
extends Node

var player: CharacterBody3D  # Reference to player node
var _camera: Camera3D        # Reference to appropriate camera

func initialize(player_node: CharacterBody3D) -> void:
    """
    Called once when controller is loaded
    - Store player reference
    - Find and activate appropriate camera
    - Set up any mode-specific nodes
    - Configure initial state
    """
    pass

func handle_input(event: InputEvent) -> void:
    """
    Called every input event
    - Process keyboard/mouse input
    - Update camera rotation (if applicable)
    - Handle mode-specific controls
    """
    pass

func handle_physics(delta: float) -> void:
    """
    Called every physics frame (default 60fps)
    - Calculate movement velocity
    - Apply gravity (if applicable)
    - Call player.move_and_slide()
    - Update camera position
    """
    pass
```

### Controller-Specific Details

#### First Person Controller
- **Camera**: PlayerCamera attached to Head node
- **Movement**: WASD relative to camera direction
- **Rotation**: Mouse controls camera pitch/yaw
- **Special**: Supports head bob, sprinting, jumping

#### Third Person Controller
- **Camera**: PlayerCamera on CameraArm SpringArm3D
- **Movement**: WASD moves player, character rotates to movement direction
- **Rotation**: Camera orbits behind player
- **Special**: Camera distance/height configurable

#### Over-the-Shoulder Controller
- **Camera**: PlayerCamera on CameraArm, offset to right
- **Movement**: WASD moves player, character faces camera direction
- **Rotation**: Smooth rotation toward movement
- **Special**: Ideal for third-person shooters

#### Tank Controller
- **Camera**: TankCamera follows hull
- **Movement**: W/S forward/back, A/D rotate hull
- **Turret**: Mouse controls independent turret rotation
- **Special**: Barrel pitch controlled by mouse Y

#### Free Camera Controller
- **Camera**: ObserverCamera, orbits around player
- **Movement**: WASD moves player on ground plane
- **Rotation**: Mouse orbits camera, player rotation locked
- **Special**: Weapon rotates to face cursor

#### Top-Down Controller
- **Camera**: ObserverCamera directly overhead
- **Movement**: WASD or click-to-move
- **Rotation**: Player faces movement direction
- **Special**: Fixed camera height, click-to-move pathfinding

#### Isometric Controller
- **Camera**: ObserverCamera at 45° angle
- **Movement**: WASD (rotated to match camera) or click-to-move
- **Rotation**: Player faces movement direction
- **Special**: Adjustable zoom with mouse wheel

---

## Shooting System

### Architecture Diagram

```
User Input (Mouse Click)
    │
    ↓
ShootingComponent._handle_shooting()
├─> Check fire rate cooldown
├─> Call WeaponComponent.get_muzzle_position()
├─> Call WeaponComponent.get_fire_direction()
├─> Spawn TankProjectile instance
├─> Set projectile.direction and speed
└─> Add to scene tree

TankProjectile._ready()
├─> Apply color from config
├─> Set velocity = direction * speed
├─> Start lifetime timer
└─> Wait for collision

TankProjectile._on_body_entered(body)
├─> Stop motion immediately
├─> Spawn hit effect
├─> Deal damage (if body has take_damage method)
└─> Destroy projectile
```

### Projectile System

**Location**: `code/tank_projectile.gd`
**Type**: `RigidBody3D` with physics simulation

**Properties**:
```gdscript
@export var speed: float = 30.0
@export var lifetime: float = 8.0
@export var damage: int = 25
var direction: Vector3 = Vector3.FORWARD
```

**Color Application**:
```gdscript
func _apply_projectile_color() -> void:
    var color_hex: String = GameConfig.get_value("projectile", "mesh_color", "FF6B35")
    var color: Color = Color(color_hex)
    # Recursively find all MeshInstance3D children and apply color
```

### Aim System per Mode

| Mode | Aim Method | Target Calculation |
|------|-----------|-------------------|
| FPS/TPS/OTS | Screen center raycast | `get_screen_center_target()` |
| Tank | Screen center raycast | `get_screen_center_target()` |
| Top-down | Mouse position raycast to ground | `get_mouse_ground_target()` |
| Isometric | Mouse position raycast to ground | `get_mouse_ground_target()` |
| Free Camera | Mouse position raycast to ground | `get_mouse_ground_target()` |

---

## Title Screen System

### Architecture Overview

The title screen is an **optional UI overlay** that appears on game start, pauses gameplay, and requires the player to click PLAY before beginning.

**Key Design Decision**: The title screen uses `PROCESS_MODE_ALWAYS` to remain interactive while the game tree is paused.

### TitleScreen Component

**Location**: `code/UI/title_screen.gd`
**Type**: CanvasLayer (UI layer)
**Purpose**: Displays splash screen with PLAY button and manages game start transition

**Key Properties**:
```gdscript
signal play_pressed  # Emitted when PLAY button clicked

@onready var background_image: TextureRect
@onready var background_color: ColorRect
@onready var play_button: Button
@onready var title_image: TextureRect
```

**Lifecycle**:
```gdscript
func _ready() -> void:
    # CRITICAL: Allow UI to process while game tree is paused
    process_mode = Node.PROCESS_MODE_ALWAYS

    # Make mouse visible for clicking button
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

    # Connect button signal
    play_button.pressed.connect(_on_play_pressed)

    # Apply config-driven styling
    _apply_background()
    _apply_button_colors()
    _check_title_image()

func _on_play_pressed() -> void:
    # Emit signal to main scene
    play_pressed.emit()

    # Fade out with tween animation
    # Auto-destroy when fade completes
```

**Background Modes**:

1. **Transparent** (`have_background = false`):
   - Both background_image and background_color hidden
   - Game scene visible through title screen
   - Game is paused but visually present

2. **Image** (`have_background = true`, `background_image` set):
   - Full-screen background image
   - Scales to fit using TextureRect stretch modes
   - Takes priority over solid color

3. **Solid Color** (`have_background = true`, `background_image = ""`):
   - ColorRect with configurable color and opacity
   - Uses hex color format: "RRGGBB"
   - Alpha/opacity range: 0.0 (invisible) to 1.0 (solid)

**Button Styling**:
- Creates StyleBoxFlat instances dynamically
- Applies colors from config for normal/hover/pressed states
- Rounded corners (10px radius)
- Border highlighting

### Main Scene Integration

**Location**: `code/main.gd`
**Purpose**: Orchestrates title screen and gameplay state transitions

**Architecture**:
```gdscript
extends Node3D

@onready var title_screen: CanvasLayer = $TitleScreen
@onready var ui_layer: CanvasLayer = $UILayer
@onready var player: CharacterBody3D = $Player

func _ready() -> void:
    # Wait for GameConfig to load
    if not GameConfig.is_loaded:
        await GameConfig.config_loaded

    # Check if title screen should be shown
    var show_title: bool = GameConfig.get_value("title_screen", "show_title_screen", false)

    if show_title and title_screen:
        # TITLE SCREEN PATH
        title_screen.show_title_screen()
        title_screen.play_pressed.connect(_on_play_pressed)

        # Pause game tree (freezes gameplay but not UI)
        get_tree().paused = true

        # Hide game UI during title screen
        ui_layer.visible = false

        # Disable player input and physics
        player.set_process_input(false)
        player.set_physics_process(false)

        # Make mouse visible for clicking PLAY
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    else:
        # NO TITLE SCREEN PATH
        title_screen.visible = false

        # CRITICAL: Set mouse mode for active controller
        _set_mouse_mode_for_controller()

        _start_game()

func _on_play_pressed() -> void:
    # Unpause game tree
    get_tree().paused = false

    # Show game UI
    ui_layer.visible = true

    # Enable player controls
    player.set_process_input(true)
    player.set_physics_process(true)

    # Set appropriate mouse mode for controller
    _set_mouse_mode_for_controller()

    _start_game()
```

### Process Modes Explained

**Problem**: When `get_tree().paused = true`, by default all nodes stop processing input and physics.

**Solution**: Set `process_mode = Node.PROCESS_MODE_ALWAYS` on TitleScreen.

**Process Mode Options**:
| Mode | Behavior When Tree Paused |
|------|---------------------------|
| `PROCESS_MODE_INHERIT` | Inherits from parent (default) |
| `PROCESS_MODE_PAUSABLE` | Stops processing when paused |
| `PROCESS_MODE_ALWAYS` | **Continues processing** |
| `PROCESS_MODE_WHEN_PAUSED` | Only processes when paused |
| `PROCESS_MODE_DISABLED` | Never processes |

**TitleScreen Usage**:
```gdscript
process_mode = Node.PROCESS_MODE_ALWAYS
```
This allows the PLAY button to receive input events and call its callback even while `get_tree().paused = true`.

### Mouse Mode Management

**Design Principle**: Different controllers require different mouse modes.

| Controller Mode | Mouse Mode | Reason |
|----------------|-----------|---------|
| `first_person`, `third_person`, `over_the_shoulder`, `tank` | `MOUSE_MODE_CAPTURED` | FPS controls need hidden, locked cursor |
| `top_down`, `isometric`, `free_camera` | `MOUSE_MODE_VISIBLE` | Point-and-click requires visible cursor |

**Implementation** (code/main.gd:79-98):
```gdscript
func _set_mouse_mode_for_controller() -> void:
    var control_mode = GameConfig.get_value("global", "controller_mode", "first_person")

    var captured_modes = ["first_person", "third_person", "over_the_shoulder", "tank"]
    var visible_modes = ["isometric", "free_camera", "top_down"]

    if control_mode in captured_modes:
        Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    elif control_mode in visible_modes:
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    else:
        Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)  # Default
```

**Critical Call Sites**:
1. When starting game **without** title screen (line 47)
2. After PLAY button clicked (line 74)

This ensures the mouse is always in the correct state for the active controller.

### Configuration

**Section**: `[title_screen]` in `game_config.cfg`

```ini
[title_screen]
show_title_screen = false              # Master enable/disable
have_background = false                # Transparent vs. image/color
background_image = ""                  # Path to background PNG (optional)
background_color = "1A1A2E"            # Hex color (6 digits, no #)
background_color_opacity = 1.0         # 0.0-1.0 alpha value
button_color = "16213E"                # Normal state
button_hover_color = "0F3460"          # Hover state
button_text_color = "FFFFFF"           # Text color
```

**Configuration Flow**:
```
GameConfig loads game_config.cfg
    ↓
main.gd reads [title_screen] section
    ↓
If show_title_screen = true:
    title_screen.gd reads [title_screen] for styling
    Applies background mode
    Applies button colors
    Loads GameTitle.png if exists
```

### Title Image System

**Expected Path**: `res://assets/UI/GameTitle.png`
**Recommended Size**: 600x200 pixels (width x height)
**Format**: PNG with transparency support

**Load Behavior**:
```gdscript
func _check_title_image() -> void:
    var image_path = "res://assets/UI/GameTitle.png"

    if ResourceLoader.exists(image_path):
        var texture = load(image_path)
        title_image.texture = texture
    else:
        _show_fallback_title()  # Creates Label with "GAME TEMPLATE" text
```

**Fallback Behavior**:
- If GameTitle.png missing, creates Label dynamically
- Text: "GAME TEMPLATE"
- Font size: 72
- Shadow effect for visibility

### Signal Flow Diagram

```
Game Start
    ↓
main.gd._ready()
├─> Check show_title_screen config
│
├─> IF TRUE:
│   ├─> title_screen.show_title_screen()
│   ├─> get_tree().paused = true
│   ├─> Hide UILayer
│   ├─> Disable player input/physics
│   └─> Connect play_pressed signal
│       │
│       └─> User Clicks PLAY
│           ├─> title_screen._on_play_pressed()
│           ├─> Emit play_pressed signal
│           ├─> Fade out animation
│           └─> main._on_play_pressed()
│               ├─> get_tree().paused = false
│               ├─> Show UILayer
│               ├─> Enable player input/physics
│               ├─> Set mouse mode for controller
│               └─> Start game
│
└─> IF FALSE:
    ├─> Hide title_screen
    ├─> Set mouse mode for controller
    └─> Start game immediately
```

### Design Patterns Used

1. **Signal-Based Communication**:
   - TitleScreen emits `play_pressed` signal
   - Main scene connects to signal and handles transition
   - Loose coupling between UI and game logic

2. **Config-Driven Styling**:
   - All visual parameters in game_config.cfg
   - No hardcoded colors or dimensions
   - Easy customization without code changes

3. **Process Mode Architecture**:
   - UI continues processing during pause
   - Game logic frozen during title screen
   - Clean separation of concerns

4. **Tween Animation**:
   - Smooth fade-out effect on PLAY click
   - Auto-cleanup with `queue_free()`
   - Professional transition feel

---

## Scene Management System

### Architecture Overview

The scene management system provides simple scene loading with fade transitions and an optional animated loading bar using a single autoload singleton.

**Design Philosophy**: Minimal, essential functionality appropriate for a template. No async loading, no complex loading screens—just smooth transitions.

### SceneManager (Autoload)

**Location**: `code/scene_manager.gd`
**Type**: Autoload singleton
**Purpose**: Centralized scene changing with fade transitions and loading bar

**Key Components**:
- Scene path registry (from GameConfig `[scenes]` section)
- Fade overlay (internal ColorRect)
- Loading bar (internal ProgressBar) - optional
- Transition state management
- Signal-based communication

**Public API**:
```gdscript
# Scene changing
func change_scene(scene_key: String) -> void
func change_scene_instant(scene_key: String) -> void
func reload_current_scene() -> void

# Utilities
func get_scene_path(scene_key: String) -> String
func is_transitioning() -> bool
```

**Signals**:
```gdscript
signal scene_changing(from_scene: String, to_scene: String)
signal scene_changed(scene_name: String)
```

### Internal Architecture

**Fade Overlay**:
- ColorRect child of SceneManager
- Full screen, black, z_index=1000
- Tween animations for smooth fade
- Duration configurable via `fade_duration`

**Loading Bar**:
- ProgressBar inside CenterContainer
- Centered on screen, z_index=1001 (above fade)
- Animates 0→70% during scene load, 70→100% after
- Styled with config-driven color and size
- Can be disabled via `show_loading_bar = false`

**Loading Bar Styling**:
- Background: Dark gray with border
- Fill: Configurable color (default: blue #4A90E2)
- Rounded corners for polish
- Custom size via width/height config

### Transition Flow

```
User calls: SceneManager.change_scene("level_1")
    ↓
Validate scene key exists in config
    ↓
Emit scene_changing signal
    ↓
Fade out (0.5s tween to black)
    ↓
Show loading bar (if enabled)
    ↓
Animate loading bar 0→70% (0.35s)
    ↓
Call get_tree().change_scene_to_file(path)
    ↓
Wait one frame for scene to load
    ↓
Animate loading bar 70→100% (0.15s)
    ↓
Hide loading bar
    ↓
Fade in (0.5s tween to transparent)
    ↓
Emit scene_changed signal
```

### Configuration

**Section**: `[scene_manager]` and `[scenes]` in `game_config.cfg`

```ini
[scene_manager]
fade_duration = 0.5                # Fade in/out duration
show_loading_bar = true            # Show animated progress bar
loading_bar_color = "4A90E2"       # Hex color for bar
loading_bar_width = 400            # Bar width in pixels
loading_bar_height = 20            # Bar height in pixels

[scenes]
main_game = "res://main.tscn"
main_menu = "res://assets/UI/main_menu.tscn"
level_1 = "res://assets/levels/level_1.tscn"
```

**Naming Convention**: Use descriptive keys (`main_menu`, `level_1`) not filenames.

### Usage Examples

**Basic scene change**:
```gdscript
func _on_play_button_pressed() -> void:
    SceneManager.change_scene("level_1")
```

**Instant scene change (no fade)**:
```gdscript
func _on_quick_restart_pressed() -> void:
    SceneManager.change_scene_instant("level_1")
```

**Reload current scene**:
```gdscript
func _on_restart_button_pressed() -> void:
    SceneManager.reload_current_scene()
```

**Listen for scene changes**:
```gdscript
func _ready() -> void:
    SceneManager.scene_changing.connect(_on_scene_changing)
    SceneManager.scene_changed.connect(_on_scene_changed)

func _on_scene_changing(from: String, to: String) -> void:
    # Save player data before transition
    PlayerData.save_state()

func _on_scene_changed(scene_name: String) -> void:
    # Initialize new scene
    Logger.info("Entered scene: " + scene_name)
```

### Integration with Existing Systems

**GameConfig**: Reads scene paths from `[scenes]` section, loads settings from `[scene_manager]`
**Logger**: Logs all transitions with timing information using start/end_timer
**Controllers**: Reinitialize automatically in new scenes, cameras work correctly
**Title Screen**: Compatible with existing pause/unpause logic, no conflicts

### Error Handling

**Graceful Failures**:
- Scene key not in config → Log error, stay in current scene
- Scene file doesn't exist → Log error, stay in current scene
- Already transitioning → Log warning, ignore duplicate request
- Scene load fails → Log error, attempt to recover

### Extending the System

This is intentionally minimal for template use. Users can extend with:
- **Async loading**: Replace `change_scene_to_file()` with `ResourceLoader.load_threaded_*`
- **Complex loading screens**: Create separate scene with tips, animations
- **Multiple transitions**: Add slide, zoom, custom effects
- **Scene history**: Track previous scenes for back buttons
- **Scene caching**: Preload frequently-used scenes

But they don't pay the complexity cost until needed.

---

## Configuration System

### GameConfig Singleton

**Location**: `code/game_config.gd`
**Type**: Autoload singleton
**Config File**: `game_config.cfg`

**Purpose**:
- Load configuration on game startup
- Provide global access to config values
- Emit signals when config changes (future feature)

**Usage**:
```gdscript
# Get value with default fallback
var speed = GameConfig.get_value("first_person", "movement_speed", 5.0)

# Get controller mode
var mode = GameConfig.get_value("global", "controller_mode", "first_person")
```

### Configuration Structure

```ini
[global]
controller_mode = "first_person"  # Which controller to load
capture_mouse_on_start = true     # Initial mouse mode

[first_person]  # Per-controller sections
movement_speed = 5.0
mouse_sensitivity = 0.002
fov = 75.0

[shooting]  # Optional component configuration
fire_rate_fps = 0.15
projectile_speed_fps = 50.0

[projectile]  # Projectile appearance
mesh_color = "000000"
light_enabled = true

[weapons]  # Weapon models per mode
show_weapon_first_person = true
weapon_model_first_person = "res://assets/weapons/fps_pistol.tscn"

[ui]  # UI settings
show_crosshair = true

[title_screen]  # Title screen configuration
show_title_screen = false
have_background = false
background_image = ""
background_color = "1A1A2E"
background_color_opacity = 1.0
button_color = "16213E"
button_hover_color = "0F3460"
button_text_color = "FFFFFF"

[scene_manager]  # Scene management configuration
fade_duration = 0.5
show_loading_bar = true
loading_bar_color = "4A90E2"
loading_bar_width = 400
loading_bar_height = 20

[scenes]  # Scene path registry
main_game = "res://main.tscn"
main_menu = "res://assets/UI/main_menu.tscn"
level_1 = "res://assets/levels/level_1.tscn"
```

---

## File Reference

### Core Systems

| File | Type | Purpose |
|------|------|---------|
| `code/game_config.gd` | Autoload | Global configuration access |
| `code/logger.gd` | Autoload | Logging and performance monitoring |
| `code/scene_manager.gd` | Autoload | Scene loading with fade transitions |
| `code/player_controller.gd` | Script | Controller dispatcher and orchestrator |
| `main.tscn` | Scene | Main game scene with Player and cameras |
| `game_config.cfg` | Config | Runtime configuration file |

### Controllers

| File | Camera Used | Control Style |
|------|------------|---------------|
| `code/player_controllers/first_person_controller.gd` | PlayerCamera | FPS mouse look |
| `code/player_controllers/third_person_controller.gd` | PlayerCamera | Behind player |
| `code/player_controllers/over_the_shoulder_controller.gd` | PlayerCamera | OTS shooter |
| `code/player_controllers/tank_controller.gd` | TankCamera | Tank controls |
| `code/player_controllers/free_camera_controller.gd` | ObserverCamera | Orbit camera |
| `code/player_controllers/top_down_controller.gd` | ObserverCamera | Overhead view |
| `code/player_controllers/isometric_controller.gd` | ObserverCamera | Isometric 45° |

### Components

| File | Purpose | Optional? |
|------|---------|-----------|
| `code/components/weapon_component.gd` | Weapon model management | Yes (shooting system) |
| `code/components/shooting_component.gd` | Shooting logic | Yes (shooting system) |
| `code/components/aiming_helper.gd` | Static aim utilities | Yes (shooting system) |
| `code/tank_projectile.gd` | Projectile behavior | Yes (shooting system) |

### Assets

| File | Type | Purpose |
|------|------|---------|
| `assets/tank_projectile.tscn` | Scene | Projectile with mesh and collision |
| `assets/projectile_hit_effect.tscn` | Scene | Hit particle effect |
| `assets/weapons/fps_pistol.tscn` | Scene | First-person weapon model |
| `assets/weapons/tps_rifle.tscn` | Scene | Third-person weapon model |
| `assets/weapons/topdown_gun.tscn` | Scene | Top-down weapon model |

### UI

| File | Purpose |
|------|---------|
| `code/UI/ui_layer.gd` | UI management, pause menu, mouse mode switching |
| `assets/UI/ui_layer.tscn` | UI scene with crosshair, pause label, buttons |
| `code/UI/title_screen.gd` | Title screen controller with PLAY button |
| `assets/UI/title_screen.tscn` | Title screen scene with button and background |
| `assets/UI/GameTitle.png` | Optional title image (600x200 recommended) |

### Main Scene Controller

| File | Purpose |
|------|---------|
| `code/main.gd` | Main scene orchestrator, manages title screen and game state transitions |

---

## Data Flow

### Initialization Flow

```
Game Start
    │
    ↓
GameConfig._ready()
├─> Load game_config.cfg
└─> Emit config_loaded signal
    │
    ↓
Player._ready()
├─> Initialize PlayerController
│   └─> PlayerController._ready()
│       ├─> Read controller_mode from GameConfig
│       ├─> Load appropriate controller script
│       └─> Call controller.initialize(player)
│           ├─> Find and activate camera
│           ├─> Set up mode-specific nodes
│           └─> Configure initial state
│
├─> Initialize WeaponComponent (if exists)
│   ├─> Detect controller mode
│   ├─> Load weapon model from config
│   ├─> Position weapon for mode
│   └─> Find/create muzzle marker
│
└─> Initialize ShootingComponent (if exists)
    ├─> Find WeaponComponent
    └─> Set up shooting state
```

### Input Flow

```
User Input (Keyboard/Mouse)
    │
    ↓
Godot Input System
    │
    ├─> UILayer._unhandled_input()  (if pause key)
    │   └─> Toggle pause, change mouse mode
    │
    └─> PlayerController._unhandled_input()
        └─> current_controller.handle_input(event)
            ├─> Update camera rotation (if applicable)
            ├─> Process movement input
            └─> Handle mode-specific controls
```

### Physics Flow (Every Frame)

```
_physics_process(delta) called at 60fps
    │
    ↓
PlayerController._physics_process(delta)
└─> current_controller.handle_physics(delta)
    ├─> Read input state (W/A/S/D)
    ├─> Calculate velocity based on mode logic
    ├─> Apply gravity (if applicable)
    ├─> Call player.move_and_slide()
    └─> Update camera position
        │
        ↓
WeaponComponent._process(delta)  (if top-down/isometric/free)
└─> Update weapon rotation to face cursor
    │
    ↓
ShootingComponent._process(delta)  (if shooting enabled)
├─> Update fire rate cooldown
└─> Check for shoot input
    └─> Spawn projectile if ready
```

### Shooting Flow

```
User Clicks Mouse
    │
    ↓
ShootingComponent detects input
├─> Check fire rate cooldown
├─> Get muzzle_position from WeaponComponent
├─> Get fire_direction from WeaponComponent
│   └─> WeaponComponent.get_fire_direction()
│       ├─> Get muzzle_position
│       ├─> Get target_position
│       │   └─> AimingHelper.get_target_for_mode()
│       │       ├─> FPS/TPS/OTS/Tank: Raycast from screen center
│       │       └─> Top-down/Iso/Free: Raycast from mouse to ground
│       └─> Return normalized direction
│
├─> Instantiate TankProjectile
├─> Set projectile.direction and speed
└─> Add projectile to scene tree
    │
    ↓
TankProjectile moves through space
    │
    ↓
Collision detected
    │
    ↓
TankProjectile._on_body_entered(body)
├─> Stop motion
├─> Spawn hit effect
├─> Deal damage
└─> Destroy self
```

---

## Extending the System

### Adding a New Controller Mode

1. **Create Controller Script**

Create `code/player_controllers/my_mode_controller.gd`:

```gdscript
extends Node

var player: CharacterBody3D
var _camera: Camera3D

func initialize(player_node: CharacterBody3D) -> void:
    player = player_node

    # Choose appropriate camera
    _camera = player.get_node("Head/PlayerCamera")  # or ObserverCamera
    _camera.make_current()

    Logger.info("MyMode initialized")

func handle_input(event: InputEvent) -> void:
    # Process input events
    if event is InputEventMouseMotion:
        # Handle mouse movement
        pass

func handle_physics(delta: float) -> void:
    # Calculate velocity
    var velocity = Vector3.ZERO

    # Apply movement logic
    if Input.is_action_pressed("move_forward"):
        velocity.z -= 1.0

    # Set player velocity and move
    player.velocity = velocity * movement_speed
    player.move_and_slide()
```

2. **Register in PlayerController**

Edit `code/player_controller.gd`, add to `initialize_controller()`:

```gdscript
"my_mode":
    current_controller = load("res://code/player_controllers/my_mode_controller.gd").new()
```

3. **Add Configuration Section**

Edit `game_config.cfg`:

```ini
[my_mode]
movement_speed = 5.0
camera_distance = 10.0
# Add mode-specific parameters
```

4. **Set as Active Mode**

Edit `game_config.cfg`:

```ini
[global]
controller_mode = "my_mode"
```

### Adding a New Component

1. **Create Component Script**

Create `code/components/my_component.gd`:

```gdscript
extends Node

var _player: CharacterBody3D
var _config_value: float

func _ready() -> void:
    _player = get_parent() as CharacterBody3D
    if not _player:
        Logger.error("MyComponent must be child of Player")
        queue_free()
        return

    # Load config
    _config_value = GameConfig.get_value("my_component", "some_value", 10.0)

    Logger.info("MyComponent initialized")

func _process(delta: float) -> void:
    # Component logic
    pass
```

2. **Add to Player Node**

Open `main.tscn`, select Player node, click "Attach Script" or "Instantiate Child Scene", add your component.

3. **Add Configuration**

Edit `game_config.cfg`:

```ini
[my_component]
some_value = 10.0
enabled = true
```

### Adding a New Weapon Model

1. **Create Weapon Scene**

Create `assets/weapons/my_weapon.tscn`:
- Root: Node3D
- Children: MeshInstance3D(s) for visual
- Child: Marker3D named "Muzzle" (positioned at barrel tip)

2. **Configure in game_config.cfg**

```ini
[weapons]
weapon_model_first_person = "res://assets/weapons/my_weapon.tscn"
weapon_model_third_person = "res://assets/weapons/my_weapon.tscn"
# etc for each mode
```

3. **Test**

WeaponComponent will automatically load and position the weapon based on the active controller mode.

---

## Summary

This template uses three core architectural patterns:

1. **State Machine** for controllers - Hot-swappable control modes
2. **Component System** for features - Modular, optional gameplay systems
3. **Three-Camera Architecture** - Prevents conflicts between incompatible modes

The design prioritizes:
- **Modularity**: Add/remove features without breaking existing code
- **Configuration**: Change behavior without coding
- **Clarity**: Each system has a single, well-defined purpose
- **Extensibility**: Clear patterns for adding new modes/components

For AI-assisted development, this architecture provides:
- Clear separation of concerns
- Predictable file locations
- Consistent interfaces
- Well-documented data flow
