# Custom Shape Collider

A Godot 4 addon that helps make adjustable 3D collision shapes. It's good for stuff like sidewalks, curbs, pavement corners, platforms, and other pieces that don't fit a plain box.
You can set the shape in the Inspector or drag the handles directly in the viewport. Corners can be straight cuts or curved, with up to 16 segments per corner.
The addon builds convex collision shapes for both regular and inward-cut corners.

This release was developed while working on my game in Godot 4.8. 

## Features

- Four independently adjustable sides: left, right, front (-Z), and back (+Z).
- Top and bottom height handles at the center of the collider.
- Corners can be cut into up to 16 segments.
- Convex 3D collision shapes. Concave outlines are split into multiple convex pieces automatically.

## Installation

1. Download the latest version from the [Releases](https://github.com/SlimeOnGit/custom_shape_collider/releases/latest) page.
2. Extract the ZIP file and place the `custom_shape_collider` folder inside your Godot project's `addons/` directory.
3. Open **Project → Project Settings → Plugins** and enable **Custom Shape Collider**.
4. Add a `StaticBody3D`, `RigidBody3D`, `CharacterBody3D`, or `Area3D` to your scene, then add `CustomShape3D` as a direct child.
5. Select `CustomShape3D` to edit it in the Inspector or directly in the 3D viewport.

Example scene tree:

```text
StaticBody3D
└── CustomShape3D
```

## Editing the shape

### Dimensions

The shape uses the collision node's local coordinates. `left_extent`, `right_extent`, `front_extent`, and `back_extent` control its horizontal bounds. `height` and `vertical_offset` control its vertical bounds. You can drag the handles around in the Viewport, or use the Inspector. 

### Corner Faces

Each corner has a face count:

| Value | Result |
|---|---|
| `0` | No cut, just an ordinary square corner |
| `1` | A straight diagonal cut, with two cut endpoints |
| `2`–`16` | A curved corner with draggable points between the cut endpoints |

Change a corner from `0` to `1` and its cut starts at **(0.1, 0.1)**. The endpoints then appear as handles, and you can drag them as you see fit. Return the face count to `0` to remove the cut and reset its dimensions.

### Collision Preview

Enable **Show Collision Preview** in the inspector to draw a transparent green surface in the editor.

## How collision works

For a convex shape, one `ConvexPolygonShape3D` is enough, but an inward curve may make the shape concave, and Godot can't represent that as a single convex solid without filling in the cut. And so the addon uses `Geometry2D.decompose_polygon_in_convex()` to build a set of solid convex prisms instead.

All convex pieces share the main collision node's shape owner, so Godot handles their transform and enabled/disabled state together. The additional physics shapes don't create extra scene nodes or get saved as separate scene objects. The addon supports StaticBody3D, AnimatableBody3D, RigidBody3D, CharacterBody3D, and Area3D. It's designed primarily for static geometry, but can also be used with other collision objects. Physics behavior may vary depending on the body type.

More faces and strongly inward curves can produce more collision pieces. Use the lowest face count that follows your visible geometry well enough.
