# Chaos Island Prototype 0.3

A Godot 4.x mobile-first physics playground prototype.

## What's new
- Larger 44x44 island with stepped chunky coastline
- Hills made from simple primitive meshes
- Separate `Trees` node with individual `Tree_XX` nodes
- Each tree has trunk, multiple leaf balls, and trunk collision
- Separate `Lake` node with water, dock and posts
- Separate `Cemetery` node with graves and fences
- Separate `Props` and `BuildZone` nodes
- Colored crates, barrels, benches, fire pit and building materials
- Player rebuilt from primitive parts:
  - capsule body
  - sphere head
  - tiny eyes and beak
  - thin cylinder arms and legs
  - hands and feet
- Procedural walking animation for arms and legs
- Existing mouse-lock, movement, grab/drop/throw and tsunami controls retained
- Godot Compatibility renderer

## Controls
WASD / Arrow Keys = Move
Mouse = Look
Space = Jump
Hold E = Grab / carry
Release E = Drop
R = Throw
F = Tsunami
Esc = Release mouse
Left click = Capture mouse

## Next recommended milestone
Ragdoll character, real water/wave interaction, shelter objectives, then mobile touch controls and multiplayer.
