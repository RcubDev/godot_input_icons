# Changelog

This change log is to help track when new version of the nuget package are published. If the commit updates the package version the change log should be updated. Optionally update the [Unreleased](#unreleased) section of the change log when you PR to make this easier to do!

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)

## [Unreleased]

### Added

- `InputIconRichTextLabel` a control node that renders input icons inline with text using `[action:NAME]` tokens
  - Supports multiple actions per label, mixed with regular BBCode
  - Optional per-token binding index (e.g. `[action:jump:1]` for the second binding)
  - Renders combined icons (modifier+key, controller overlays) inline
  - Flags unknown action tokens with a configuration warning in the editor
  - Automatically re-renders on device change when Input Helper integration is enabled
  - Originally proposed and contributed by [@omegaleo](https://github.com/omegaleo). Thank you!
- `push_warnings` parameter on `InputIconResolver.get_icon` to optionally silence resolver warnings (defaults to `true`)

### Changed

- The default icon maps now bake their atlas regions as inline sub-resources instead of referencing standalone `AtlasTexture` files, cutting the addon from ~140 small resource files down to the map files themselves

### Removed

- The standalone per-icon `AtlasTexture` `.tres` files under `assets/input_atlas_textures/`. **Breaking:** if you referenced one of these files directly (for example on a `TextureRect`), repoint it to an inline region or to the icon map. The bundled default maps and demo scene were updated automatically.

## [0.0.1] - 2025-04-30

### Added

- `InputIconTextureRect` a control node that dynamically changes textures based on the user registered action, the display device, and device index
- `InputIconResolver` a godot object for resolving input icons using a `InputIconMap` (resource)
- Input Helper Adapter / Integration a godot class to add support to `InputIconTextureRect` for updating texture when inputs change at runtime or different devices are used at runtime
