# How the Voxel Block System Works

> A plain-English walkthrough of the architecture behind the demo — no prior engine knowledge required.

---

## 1. The Core Problem

Imagine you want to place 10,000 wooden crates in a warehouse. You could hire 10,000 workers to each hold one crate — but that's massively wasteful. Most of them are just standing there doing nothing.

That's what happens when you create a game node for every single block. Godot's scene tree is powerful, but each node carries overhead. At thousands of blocks, it becomes a serious performance problem.

> **The Insight:** Instead of 10,000 workers, you hire one very efficient foreman who can paint all 10,000 crates in one pass — and keep a clipboard tracking which ones are damaged.

---

## 2. Two Separate Jobs

The system deliberately splits block management into two independent concerns, handled by different tools:

| Job | Tool | Responsibility |
|-----|------|---------------|
| Drawing the blocks | `MultiMeshInstance3D` | A single Godot node that renders thousands of identical shapes in one efficient GPU draw call |
| Remembering their state | `Dictionary` | A lookup table that maps each block's grid position to a small data record |

Neither job knows much about the other. The renderer doesn't care about hit counts; the data store doesn't care about triangles.

---

## 3. The Grid Coordinate System

Every block lives at a position described by three whole numbers — its X, Y, and Z position on an invisible integer grid. In code this is a `Vector3i`, the "i" standing for integer.

This coordinate is used as the key into the dictionary. Want to know if there's a block at position (4, 0, 7)? Ask the dictionary. Want to hit it? Pass that coordinate to `hit_block()`.

> **Why not just use floating point?** Real-world positions in 3D space are floating point numbers (e.g. `4.0000001`). Two numbers that look the same might not be exactly equal due to tiny rounding errors, which would silently break dictionary lookups. Integer coordinates are exact, always.

---

## 4. The BlockState Record

For each block that exists, the dictionary holds a tiny `BlockState` object. It tracks:

- `hits` — how many times the block has been struck
- `instance_index` — its slot in the renderer

The `instance_index` is the link between the data world and the visual world. It tells the renderer: "when this block changes, update slot number 42 in the MultiMesh buffer."

Adding new things to track — block type, owner, temperature, moisture — is as simple as adding a new variable to `BlockState`. The rest of the system doesn't need to change.

---

## 5. What Happens When You Hit a Block

```
Mouse click
    │  A ray is fired from the camera into the 3D scene.
    │  Godot's physics engine detects which collider it strikes first.
    ▼
Coordinate lookup
    │  The collider has a metadata tag with its grid coordinate.
    │  That coordinate is passed to hit_block().
    ▼
State update
    │  The dictionary is queried with that coordinate.
    │  The BlockState record's hits counter is incremented by one.
    ▼
Visual refresh
    │  The block's colour is updated in the MultiMesh buffer
    │  to reflect its new damage state.
    ▼
Destruction (if max hits reached)
       The MultiMesh instance is scaled to zero (invisible),
       the dictionary entry is erased, and the collider node
       is freed from the scene tree.
```

### Damage States

| Hits | Colour | State |
|------|--------|-------|
| 0 | 🟢 Green | Healthy |
| 1 | 🟡 Yellow | Damaged |
| 2 | 🟠 Orange | Critical |
| 3 | — | Destroyed |

---

## 6. The Collider Compromise

There is one place where we do use individual nodes per block: collision shapes. This is necessary because Godot's physics raycasting only works against actual scene nodes.

For a 16×16 demo grid that's 256 colliders — totally fine. In a larger game you'd only activate colliders for blocks near the player, swapping them in and out as the player moves. The rendering cost remains flat regardless.

> **The Rule of Thumb:** Nodes are for things that need the engine's attention every frame — physics, animations, sounds. Blocks that just sit there don't need to be nodes. They're data.

---

## 7. Why This Scales

Because the renderer and the data store are decoupled, you can grow either side independently. Doubling the number of blocks costs almost nothing in rendering terms — the GPU is already doing one draw call, and one draw call with 2,000 instances is no slower than one with 1,000.

The dictionary lookup for any block is also constant time — it doesn't matter if there are 100 blocks or 100,000, finding a specific one takes the same amount of work.

---

## File Structure

```
res://
├── main.tscn          # Scene root — camera, light, world environment
├── main.gd            # Camera orbit, mouse input, raycasting
└── block_manager.gd   # MultiMesh setup, block state, colliders
```

## Controls

| Input | Action |
|-------|--------|
| Left click | Hit a block |
| Right click | Place a block on the clicked face |
| Middle mouse drag | Orbit camera |
| Scroll wheel | Zoom in / out |
