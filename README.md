# abstract_motifs

A dependency-free, Ruby-first generative design language for SVG artwork.

Define a **creature** as a reusable motif composed of visual primitives, then place individual instances or generate a **colony** with independent scales, orientations, and seeds. Composable style modifiers add an irregular, hand-drawn character without introducing separate “wobbly capsule” or “personal arc” primitives.

## Quick start

Requires Ruby (standard library only).

```sh
ruby design.rb
```

This generates **two SVGs** in the current directory:

- `design.svg`: a three-creature composition.
- `colony.svg`: a denser eight-creature composition.

You can override their paths:

```sh
ruby design.rb custom_design.svg custom_colony.svg
```

Committed reference renders are in `examples/design.svg` and `examples/colony.svg`. `examples/abstract_motifs.svg` is a vector tracing of the original inspiration.

## DSL

```ruby
require_relative 'ornament'

art = Ornament.canvas(800, 600, seed: 42, background: :paper) do
  palette paper: '#faf9f4', ink: '#272438', sun: '#eadca7'

  style :hand_drawn do
    asymmetry amount: 0.07
    wobble amplitude: 3.8, wavelength: 30
    roughness amplitude: 0.9, wavelength: 6
    pressure amount: 0.22, wavelength: 11
    echo dx: 1.4, dy: 1.9, opacity: 0.12
  end

  motif :creature, extent: 200, style: :hand_drawn do
    rays 24, from: 90..110, to: 145..180,
         sector: 0..360, width: 5..9, color: :sun
    arcs 4, radius: 35..70, sector: 0..320,
         sweep: 50..120, width: 10..15, color: :ink
    center radius: 18, color: :ink
  end

  colony :creature, count: 6,
         region: [40, 40, 760, 560],
         scale: 0.5..0.8,
         rotate: -180..180,
         spacing: 100,
         seed: 88
end

File.write('creatures.svg', art.svg)
```

### Vocabulary

- `motif` declares a reusable group of semantic primitives.
- `stamp` draws one motif at a position, scale, rotation and optional seed.
- `colony` generates multiple motif instances within a region, varying scale and rotation.
- `style` declares reusable geometric modifiers, optionally extending other styles with `extends:`.
- Modifiers: `wobble`, `roughness`, `asymmetry`, `pressure`, `echo`.
- Primitives: `center`, `arcs`, `rays`, `petals`, `confetti`, `capsules`, `spokes`.

## Architecture

The primitives generate sampled geometry; the modifier pipeline deforms paths before SVG output. `colony` performs seeded, best-effort clustered placement. This is still an early proof of concept: it does **not** provide strict non-overlap guarantees, a general-purpose scene graph, or true continuously expanded variable-width stroke outlines.

The aim is to make aesthetic characteristics composable independently of primitive types and to keep designs short enough to express in a few dozen lines of Ruby.
