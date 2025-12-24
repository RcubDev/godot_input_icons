# Godot Input Icons - Issue Templates

Ready-to-create issues for the godot_input_icons repository.

---

## Bug Issues

### Issue 1: README Typos

**Title:** `Fix typos in README: 'Prject Settings' should be 'Project Settings'`

**Labels:** `bug`, `documentation`

**Body:**
```
## Description
The README.md contains a typo where "Project Settings" is misspelled as "Prject Settings" in multiple locations.

## Locations
- Line 43: `Project > Prject Settings > Plugins`
- Line 62: `Project > Prject Settings > General > Input Helper`
- Line 67: `Project > Prject Settings > General > Input Helper`

## Fix
Replace all instances of "Prject Settings" with "Project Settings".
```

---

### Issue 2: Missing invalid_button Property

**Title:** `Bug: ControllerIcons missing 'invalid_button' property referenced by resolver`

**Labels:** `bug`

**Body:**
```
## Description
The `InputIconResolver._get_joypad_button_icon()` method references `icon_map.invalid_button` for `JOY_BUTTON_INVALID`, but the `ControllerIcons` resource class doesn't define this property.

## Location
- **Reference:** `input_icon_resolver.gd:204-205`
- **Missing from:** `resources/controller_icons.gd`

## Expected Behavior
Either:
1. Add `@export var invalid_button: Texture2D` to `ControllerIcons`, or
2. Remove/handle the `JOY_BUTTON_INVALID` case differently in the resolver

## Steps to Reproduce
1. Set up an input action bound to an invalid joypad button
2. Attempt to display it with InputIconTextureRect
3. Error or unexpected behavior when accessing undefined property
```

---

### Issue 3: Incomplete Analog Stick Axis Support

**Title:** `Bug: Analog stick axis movements return null - no icon support`

**Labels:** `bug`, `enhancement`

**Body:**
```
## Description
The `_get_joypad_axis_icon()` function only handles trigger axes (left/right triggers). Analog stick axis movements return null, meaning there's no visual icon for analog stick directions when used as input actions.

## Location
`input_icon_resolver.gd:159-166`

## Current Behavior
```gdscript
func _get_joypad_axis_icon(icon_map: ControllerIcons, joypad_motion_event: InputEventJoypadMotion) -> Texture2D:
    match joypad_motion_event.axis:
        JoyAxis.JOY_AXIS_TRIGGER_LEFT:
            return icon_map.left_trigger
        JoyAxis.JOY_AXIS_TRIGGER_RIGHT:
            return icon_map.right_trigger
        _:
            return null  # <-- All stick movements return null
```

## Missing Axes
- `JOY_AXIS_LEFT_X` / `JOY_AXIS_LEFT_Y` (left stick)
- `JOY_AXIS_RIGHT_X` / `JOY_AXIS_RIGHT_Y` (right stick)

## Suggested Fix
1. Add stick direction icons to `ControllerIcons` (e.g., `left_stick_up`, `left_stick_down`, etc.)
2. Handle the axis value (positive/negative) to determine direction
3. Return appropriate directional icon
```

---

## Feature Issues

### Issue 5: Texture Caching for Combined Textures

**Title:** `Feature: Cache combined textures for modifier key combinations`

**Labels:** `enhancement`, `performance`

**Body:**
```
## Description
The `combine_textures_with_gap()` and `combine_textures_with_overlap()` functions create new `ImageTexture` objects each time they're called. For frequently used modifier combinations (Ctrl+C, Shift+A, etc.), this creates unnecessary overhead.

## Current Behavior
Every call to `_update_texture()` with modifier keys creates a new combined texture, even if the same combination was created before.

## Suggested Enhancement
Implement a texture cache (Dictionary) that stores previously combined textures keyed by the combination of source textures. Return cached version if available.

## Benefits
- Reduced memory allocations
- Improved performance for UIs with many modifier-key icons
- Faster texture updates when switching contexts
```

---

### Issue 6: Add Signal When Icon Texture Changes

**Title:** `Feature: Emit signal when InputIconTextureRect texture changes`

**Labels:** `enhancement`

**Body:**
```
## Description
Add a signal to `InputIconTextureRect` that emits when the displayed texture changes. This would be useful for:
- Triggering UI animations when icons update
- Syncing other UI elements
- Debugging/logging input changes

## Suggested Implementation
```gdscript
signal icon_changed(new_texture: Texture2D, old_texture: Texture2D)

func _update_texture() -> void:
    var old_texture = texture
    # ... existing logic ...
    if texture != old_texture:
        icon_changed.emit(texture, old_texture)
```

## Use Cases
- Fade/scale animation when player changes input device
- Audio feedback when remapping completes
- Analytics tracking of input method preferences
```

---

### Issue 7: Steam Deck Controller Support

**Title:** `Feature: Add Steam Deck controller icon support`

**Labels:** `enhancement`

**Body:**
```
## Description
Add support for Steam Deck controller icons as a new device type. The Steam Deck has become a popular gaming platform and has a unique button layout that users may want specific icons for.

## Suggested Implementation
1. Add `SteamDeck` to `InputTypes` enum in `input_icon_constants.gd`
2. Create `steam_deck_default_map.tres` with appropriate icons
3. Update `InputHelperAdapter.input_helper_device_to_icon_helper_device()` to recognize Steam Deck

## Controller Characteristics
- Has back grip buttons (L4, L5, R4, R5)
- Trackpads in addition to sticks
- Unique button styling

## Resources
- Kenney's input prompts include Steam Deck icons
- Community icon packs available
```

---

### Issue 8: Multiple Binding Display Option

**Title:** `Feature: Display multiple bindings for same action (e.g., "A / B")`

**Labels:** `enhancement`

**Body:**
```
## Description
Currently `InputIconTextureRect` shows only one binding at a time (controlled by `action_index`). Add an option to display multiple bindings in a combined format like "Space / W" for actions with alternate keys.

## Use Cases
- Tutorial screens showing all available keys for an action
- Settings menus displaying primary and alternate bindings
- "Press X or Y to continue" prompts

## Suggested Implementation
Add new properties:
```gdscript
@export var show_all_bindings: bool = false
@export var binding_separator_texture: Texture2D  # Optional "/" or "OR" icon
@export var max_bindings_shown: int = 2
```

## Visual Example
Instead of just showing [Space], show [Space] / [W] for actions with multiple keyboard bindings.
```

---

### Issue 9: Vertical Texture Combining

**Title:** `Feature: Add vertical texture combining option`

**Labels:** `enhancement`

**Body:**
```
## Description
Currently `combine_textures_with_gap()` only arranges textures horizontally. Add a vertical combining option for alternative layout needs.

## Use Cases
- Vertical UI layouts
- Compact control displays
- D-pad directional combinations (up+right shown vertically)

## Suggested Implementation
```gdscript
enum CombineDirection { HORIZONTAL, VERTICAL }

static func combine_textures_with_gap(
    textures: Array[Texture2D],
    gap: int = 2,
    direction: CombineDirection = CombineDirection.HORIZONTAL
) -> Texture2D:
```

Or add a separate function:
```gdscript
static func combine_textures_vertical(textures: Array[Texture2D], gap: int = 2) -> Texture2D
```
```

---

### Issue 10: Localization Support for Keyboard Keys

**Title:** `Feature: Support for localized keyboard key labels`

**Labels:** `enhancement`, `i18n`

**Body:**
```
## Description
On non-US keyboard layouts, keys may have different labels or positions:
- QWERTZ (German) vs QWERTY
- AZERTY (French)
- Physical key location vs logical key name

## Current Behavior
Uses `OS.get_keycode_string(input_event.physical_keycode)` which returns English key names.

## Suggested Enhancement
1. Add option to use `keycode` vs `physical_keycode`
2. Consider supporting custom key label overrides
3. Document behavior for international users

## Consideration
This may require:
- Alternative icon sets for different layouts
- User preference for "show physical key" vs "show logical key"
- Integration with OS keyboard layout detection
```

---

### Issue 11: Add "Any Key" Placeholder Icon

**Title:** `Feature: Add "Any Key" or generic placeholder icon support`

**Labels:** `enhancement`

**Body:**
```
## Description
Add support for displaying a generic "Any Key" or "Press any button" icon for prompts that don't require a specific input.

## Use Cases
- "Press any key to continue" screens
- Loading screen skip prompts
- Generic input prompts before device detection

## Suggested Implementation
1. Add `any_key` texture to `KeyboardIcons`
2. Add `any_button` texture to `ControllerIcons`
3. Add special action name constant like `"--any--"` that displays these

## Alternative Approach
Could also add an `icon_mode` property:
```gdscript
enum IconMode { ACTION, ANY_KEY, CUSTOM }
@export var icon_mode: IconMode = IconMode.ACTION
```
```

---

### Issue 12: Editor Dock for Icon Database Setup

**Title:** `Feature: Add editor dock for visual icon database setup`

**Labels:** `enhancement`, `editor`

**Body:**
```
## Description
Add an editor dock panel that provides a user-friendly interface for configuring input icon mappings, replacing the need to manually edit `.tres` resource files.

## Storage
- Stores reference to the icons resource in project settings under `addons/input_icons`
- Integrates with existing `InputIconMap` resource system

## Two Views

### 1. List View
- Table/list of all input mappings
- Columns: Input Name | Icon Texture
- Drag-and-drop or picker for assigning textures
- Filter/search by input name
- Highlight unmapped inputs

### 2. Controller/Keyboard Preview View
- Visual representation of controller layout (Xbox, PlayStation, Switch, Generic)
- Visual representation of keyboard layout
- Icons displayed in their physical positions on the device
- At-a-glance verification that all inputs are mapped correctly
- Switch between device types via tabs or dropdown

## Mockup Concept

```
┌─ Input Icons ─────────────────────────────────────┐
│ [List View] [Preview View]     Device: [Xbox ▼]  │
├──────────────────────────────────────────────────┤
│                                                   │
│            ┌─────┐         ┌─────┐               │
│            │ LB  │         │ RB  │               │
│            └─────┘         └─────┘               │
│         ┌─────┐               ┌─────┐            │
│         │ LT  │               │ RT  │            │
│         └─────┘               └─────┘            │
│                                                   │
│      ┌───┐                         ┌───┐         │
│      │ ↑ │                         │ Y │         │
│   ┌──┼───┼──┐                   ┌──┼───┼──┐      │
│   │← │   │ →│                   │X │   │ B│      │
│   └──┼───┼──┘                   └──┼───┼──┘      │
│      │ ↓ │                         │ A │         │
│      └───┘                         └───┘         │
│                                                   │
│         [Back]              [Start]               │
│                                                   │
└──────────────────────────────────────────────────┘
```

## Implementation Notes
- Extends `EditorPlugin` with `add_control_to_dock()`
- Preview layouts could be simple `Control` scenes with positioned `TextureRect` slots
- List view using `Tree` or `ItemList` control
- Device switching updates preview to show relevant controller shape

## Future Enhancements (out of scope for initial implementation)
- Auto-import from icon pack folders
- Keyboard heat map showing which keys are mapped
- Export/share icon configurations
```

---

### Issue 13: Built-in Input Helper Alternative

**Title:** `Feature: Add built-in input helper as alternative to external dependency`

**Labels:** `enhancement`

**Body:**
```
## Description
Add a lightweight built-in input helper implementation as an alternative to requiring Nathan Hoad's godot_input_helper plugin. Users can choose which to use based on their preference.

## Motivation
- **Simpler setup**: Single plugin install for users who don't already use Input Helper
- **Self-contained**: Remap demo works out of the box
- **No version coupling**: Avoid breaking changes from upstream dependency

While keeping the existing Input Helper integration for users who:
- Already use Nathan Hoad's plugin in their project
- Prefer the full feature set of the established plugin

## Scope for Built-in Implementation
Minimal feature set focused on what Input Icons needs:

### Device Detection
- Detect active input device (keyboard vs controller)
- Identify controller type (Xbox, PlayStation, Switch, Generic)
- Signal when device changes

### Input Remapping
- `replace_keyboard_input_at_index(action, index, event)`
- `replace_joypad_input_at_index(action, index, event)`
- Signals when inputs are remapped

### Controller Connection
- Detect joypad connect/disconnect
- Signal on connection changes

## Implementation Notes
- New autoload: `InputIconHelper` (optional, user enables if needed)
- Project setting to choose: `None`, `Built-in`, `Nathan Hoad's Input Helper`
- Keep existing `InputHelperAdapter` for external plugin support
- Build on Godot's native APIs:
  - `Input.get_connected_joypads()`
  - `Input.get_joy_name()`
  - `InputMap.action_add_event()` / `action_erase_event()`

## User Choice
```
Project Settings > Input Icons > Input Helper Mode
  ○ None (manual control only)
  ○ Built-in (lightweight, no dependencies)
  ○ External - Nathan Hoad's Input Helper (full-featured)
```
```

---

## Enhancement Issues

### Bonus: Rename action_index to binding_index

**Title:** `Enhancement: Rename 'action_index' to 'binding_index' for clarity`

**Labels:** `enhancement`, `breaking-change`

**Body:**
```
## Description
The property `action_index` is confusingly named. It doesn't index actions - it indexes **bindings within an action** after filtering by device type.

## Current Behavior
If "jump" has bindings [Space, W, A-button]:
- `action_index=0` with keyboard → Space
- `action_index=1` with keyboard → W
- `action_index=0` with Xbox → A-button

## Suggested Change
Rename to `binding_index` or `input_binding_index` which better describes its function.

## Affected Files
- `input_icon_texture_rect.gd` - property and setter
- `input_icon_resolver.gd` - parameter names in functions
- `remap_example.gd` - usage
- README.md - documentation

## Migration
Consider keeping `action_index` as a deprecated alias for backwards compatibility.
```

---

## Summary

| # | Type | Title |
|---|------|-------|
| 1 | Bug | README typos ("Prject Settings") |
| 2 | Bug | Missing `invalid_button` property |
| 3 | Bug | Incomplete analog stick axis support |
| 5 | Feature | Texture caching for combined textures |
| 6 | Feature | Signal when icon texture changes |
| 7 | Feature | Steam Deck controller support |
| 8 | Feature | Multiple binding display option |
| 9 | Feature | Vertical texture combining |
| 10 | Feature | Localization support for keyboard keys |
| 11 | Feature | "Any Key" placeholder icon |
| 12 | Feature | Editor dock for icon database setup |
| 13 | Feature | Built-in input helper alternative |
| Bonus | Enhancement | Rename `action_index` to `binding_index` |
