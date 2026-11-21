# Motion in Bukuresipi

Notes on how the app moves, and why each choice was made. Code references are clickable from the repo root.

## 1. Anchored mask reveal (the floating sheet)

**Where:** `showBaseSheet` → `_FloatingSheet` in `lib/core/widgets/base/sheets.dart`.

### The idea

A normal bottom sheet **slides**: the whole card starts below the screen and travels up. Every pixel moves.

An anchored mask reveal does not move the card. It **changes how much of the card you can see**:

```
 slide (Material default)            anchored mask reveal (ours)

  t=0     t=0.5    t=1               t=0      t=0.5    t=1
                  ┌─────┐                              ┌─────┐
                  │ A   │                              │ A   │
         ┌─────┐  │ B   │                     ┌─────┐  │ B   │
         │ A   │  │ C   │                     │ B   │  │ C   │
 ───────  │ B  │  └─────┘            ───────  │ C   │  └─────┘
 (below) ─┴─────┴─ (edge)            ═══════  └─────┘  ═══════  ← anchor line
                                     (nothing)
```

- **The anchor**: an invisible line 12 dp above the screen's bottom (above the home bar). The card's bottom edge is
  on that line from the first frame to the last. It never moves.
- **The mask**: the rounded card shape. Only its top edge (with the handle) moves, up on open and down on close.
- **The content** is pinned to the bottom of the mask, so as the mask grows, rows appear from the bottom up, like
  unrolling a blind upward. The last row is visible first; the title arrives last.

Other names you'll find for the same family: *clip reveal*, *wipe reveal*, *mask transition*, *grow from anchor*.
iOS's Dynamic Island, context menus and the App Store's card expansion all grow from a fixed point or edge instead
of flying in from the screen's edge.

### Why it feels good

1. **Nothing important moves.** Your eye was on the button you tapped near the bottom; the place it looks stays still.
2. **Less motion = calmer.** Only one edge travels, not the whole card, so the animation reads as "opening",
   not "arriving".
3. **It's reversible in the same shape.** Close = the same edge folding back down to the line. Drag the handle down
   and the edge follows your finger, so the gesture and the animation are the same thing.

### How it's built (Flutter)

The whole trick is `Align(heightFactor:)`:

```dart
Align(
  alignment: Alignment.bottomCenter, // content pinned to the bottom
  heightFactor: open * drag,         // 0..1: how much of its height the box takes
  child: content,
)
```

- `Align` with `heightFactor: 0.4` makes itself 40% as tall as its child. `bottomCenter` keeps the child's bottom on
  the box's bottom, so the child's top overflows out of the box.
- The parent `Material` (`clipBehavior: Clip.antiAlias`, radius 28) is the **mask**: it clips what overflows, and its
  rounded top corners travel with the edge.
- The whole card sits in `Align(bottomCenter)` with padding, so its **bottom is the anchor line**.
- `open` = the route's animation through `CurvedAnimation(easeOutCubic, reverse: easeInCubic)`: it opens fast and
  settles softly, and closes by accelerating away (things leaving should not linger).
- `drag` = a second controller for the finger: `drag.value -= dy / height`. Release past 30% or with a fling
  (> 700 px/s) → close; otherwise it springs back to 1.

The two are multiplied, so a drag and the route's own animation never fight each other.

### Things to study next

- `ClipPath` with a custom path: the same reveal with any shape (a circle growing from a button = *circular reveal*,
  Android's `ViewAnimationUtils.createCircularReveal`).
- `SizeTransition(axisAlignment: 1)`: Flutter's built-in version of the same `heightFactor` idea.
- Spring physics (`SpringSimulation`) instead of curves: see the nav bar below.

## 2. Hero flights (a photo flying between pages)

**Where:** `lib/core/widgets/hero_motion.dart` (the shared path), used by `CoverAppBar` (a Home card → the recipe's
or saved place's header; the route fades instead of flipping, `_flightPage` in `app_router.dart`) and `PhotoHero` /
`showPhotoDialog` (thumbnail → full photo).

A `Hero` is two widgets with the same `tag` on two pages. On push, Flutter hides both, puts a copy (the *shuttle*) in
the overlay, and moves it from the first one's rect to the second's along the route's animation.

What we change from Flutter's default:

| | Flutter default | Ours | Why |
|---|---|---|---|
| Path | `MaterialRectArcTween`: curves in an arc | straight line | a photo going to the top of the screen should go there, not swing out |
| Pace | linear with the route | `easeInOutCubic` | it lifts off gently and lands gently; linear looks mechanical |
| Corners | whatever the shuttle has | morph in step (`heroPace`) | the card's 11 dp corners (or an avatar's circle) round off into the page's square edge |
| Length | the route's (was 380 ms) | 480 ms push / 420 ms back; viewer 420 / 360 | under ~400 ms an eased flight reads as a jump |

**Both ends must pass the same `createRectTween`.** A push uses the destination's, a pop the source's: give only one
side and the flight differs each way.

### The first-open stutter, and its fix

While a flight is in the air, Flutter does **not build** the destination Hero's child: it shows an empty box of its
size. The real child (the screen-wide header, the full-size photo) is built only when the flight lands. A photo seen
for the first time then has to be decoded at that size *at the moment of landing*: a blank frame or two, then the
photo pops in. Afterwards it's in the image cache, so only the first open stutters.

So we decode ahead:

- **Recipe header**: `ShareFill.warm(context, photo)` (`share_image.dart`) runs `precacheImage` with the exact provider
  `Image.memory(cacheWidth:)` builds (`ResizeImage(MemoryImage(bytes), width:)`), when the page is first built, which
  is the first frame of the flight. The decode happens during the 480 ms flight.
- **Photo viewer**: `showPhotoDialog` awaits `precacheImage` for both the shuttle's `MemoryImage` and the viewer's
  `ExtendedMemoryImageProvider` (different classes = different cache keys) *before* pushing. It costs a few
  milliseconds before the flight starts, and the flight itself is never blank.
- The shuttle always shows the **card's** already-decoded picture (`CoverAppBar.cardShuttle`), never a fresh one.

Rule of thumb: *anything a flight lands on must already be decoded.*

## 3. The nav bar shrink (spring)

**Where:** `FloatingNav` in `lib/features/home/presentation/widgets/floating_nav.dart`, driven by `HomePage._onScroll`.

- Shrinks to 88% after 24 dp of scrolling in either direction (a jitter does nothing).
- Comes back 0.5 s after the scroll *stops*, not on scroll-up or at the top.
- Moves with a `SpringSimulation` (`stiffness 220`, damping ratio `0.82`: a touch under critical, so it settles with no
  visible bounce) instead of a curve. A spring keeps the current **velocity** when the target changes mid-way, so
  shrink → grow → shrink never jerks. That's the main reason iOS motion feels "smooth": springs, not durations.

## 4. The map sheet becomes the page (full)

**Where:** `MapSheet` in `lib/features/places/presentation/widgets/map_sheet.dart`.

Over the last 10% of the screen height before full, three things follow the sheet (and the finger), all from one
value (`_header`, 0 -> 1):
- The map behind the floating back button and search bar fades to the sheet's paper colour (a band from the screen
  top to the sheet's top at full, under its round corners too; it never takes a tap).
- The sheet's top corners go from 20 to square.
- Its shadow fades out.

At full, the bar and the sheet read as one page, the bar floating on paper with `spaceM` above the sheet's handle
(the map page passes `top: belowBar - 12 + spaceM`). No timer and no curve: it is tied to the sheet's height, so a
drag back down undoes it at the same pace. On a wide screen the side panel becomes a flat paper column to the top.

## Reduce motion

With the system's "remove animations" on (`MediaQuery.disableAnimations`), the floating sheet and the nav bar jump
to their end state and the book page flip is skipped. The hero flights and the photo viewer still animate (not done
yet).
