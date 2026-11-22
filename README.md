# abstract_motifs

A dependency-free, Ruby-first generative SVG design language.

A **motif** describes a creature's visual grammar, while **styles** modify the geometry for the original's irregular, hand-drawn character. A **colony** creates related creatures at varying scales and orientations.

## Run

Requires Ruby and the standard library only.

```sh
ruby design.rb
ruby test/test_layout.rb
```

The demo writes `design.svg` (three creatures) and `colony.svg` (eight creatures). Paths can be overridden with `ruby design.rb output.svg colony.svg`.

## Source-image layout rules

The radial geometry is intentionally divided into non-overlapping bands and angular sectors.

- Inner ink arcs and center are separate from the lilac petal ring.
- Blush (brown) capsules occupy an inner concentric ring; butter (yellow) capsules occupy an outer concentric ring. They are **not** alternating within the same ring.
- Pale yellow rays occupy the opposite angular sector from the capsules, avoiding the block region.
- Berry dots between the outer lavender spokes use weighted gap densities, creating alternating **dense and sparse** bands while maintaining clearance from each spoke.
- The corresponding ranges and separated ring logic are covered by tests in `test/test_layout.rb`.

The layout remains deterministic for fixed seeds.

## DSL excerpt

```ruby
motif :organism, extent: 345, style: :hand_drawn do
  rays 28, from: 115..137, to: 185..248,
       sector: 104..256, width: 4..8, color: :sun
  capsules 7, radius: 164..169, sector: -73..73,
           length: 49..57, width: 26..32, color: :blush
  capsules 7, radius: 210..216, sector: -73..73,
           length: 55..64, width: 26..32, color: :butter
  confetti 72, radius: 244..294,
           between: { count: 5, sector: -76..76 },
           density: [2.0, 0.25, 1.8, 0.30],
           size: 3..6, color: :berry
  spokes 5, radius: 254..262, sector: -76..76,
         length: 45..67, width: 10..14, color: :lavender, tip: 17..22
end
```

See `design.rb` for the complete motif and `ornament.rb` for primitive implementations.

## Current limitations

`colony` uses best-effort placement, not guaranteed non-overlap between different creatures. Style deformation is sampled geometry, not a complete renderer-independent scene graph. Existing `examples/*.svg` are historical captures; regenerate them from the current demo when comparing the updated radial layout.
