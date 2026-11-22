# abstract_motifs

A Ruby-first generative visual design language for creating families of abstract SVG artwork.

Rather than manually composing SVG paths, define reusable **motifs** using semantic visual primitives (rays, arcs, petals, capsules, confetti, spokes), then stamp them into compositions with seeded variation.

## Run

Requires Ruby with its standard library. No gems required.

```sh
ruby design.rb
```

This writes `design.svg` in the current directory.

## Files

- `ornament.rb` - dependency-free DSL and SVG rendering engine
- `design.rb` - runnable, approximately 30-line design definition
- `examples/generated_organisms.svg` - example output
- `examples/abstract_motifs.svg` - vector tracing of the original reference artwork

## DSL example

```ruby
require_relative 'ornament'

art = Ornament.canvas(800, 600, seed: 42, background: :paper) do
  palette paper: '#faf9f4', ink: '#272438', sun: '#eadca7'

  motif :sunburst do
    rays 24, from: 90..110, to: 145..180,
         sector: 0..360, width: 5..9, color: :sun
    arcs 4, radius: 35..70, sector: 0..320,
         sweep: 50..120, width: 10..15, color: :ink
    center radius: 18, color: :ink
  end

  stamp :sunburst, at: [400, 300]
end

File.write('sunburst.svg', art.svg)
```

## Design direction

This is an initial proof of concept, not a complete scene-graph architecture. The next steps are spatial constraints and relationships, configurable sampling distributions, and a deterministic intermediate scene graph so multiple renderers and an editor can share the same composition model.
