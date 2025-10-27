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
```

---

## File Reference

### Core Systems

| File | Type | Purpose |
|------|------|---------|
| `code/game_config.gd` | Autoload | Global configuration access |
| `code/logger.gd` | Autoload | Logging and performance monitoring |
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
