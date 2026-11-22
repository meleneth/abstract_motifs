# frozen_string_literal: true
require_relative 'ornament'

PALETTE = {
  paper: '#faf9f4',
  ink: '#272438',
  sun: '#eadca7',
  lavender: '#a497c5',
  berry: '#ab77a3',
  blush: '#bb918d',
  butter: '#e6d57e'
}.freeze

def build_scene(seed: 2026, &placement)
  Ornament.canvas(1408, 1056, seed: seed, background: :paper) do
    palette(**PALETTE)

    style :hand_drawn do
      asymmetry amount: 0.07
      wobble amplitude: 3.8, wavelength: 30
      roughness amplitude: 0.9, wavelength: 6
      pressure amount: 0.22, wavelength: 11
      echo dx: 1.4, dy: 1.9, opacity: 0.12, width_scale: 0.46
    end

    # Layer names describe the visual grammar; each layer owns its shapes.
    # Brick rings occupy the inner 2/3 of the motif radius; the sunburst
    # lives in the outer 1/3. Both brick rings retain their shared lattice.
    motif :organism, extent: 345, style: :hand_drawn do
      radial_zones outer: 345, bricks: 2, fringe: 1

      layer :sunburst, color: :sun, sector: 98..262 do
        rays 27, from: radial(:fringe, 0.02..0.14),
             to: radial(:fringe, 0.85..1.0),
             width: 5..8, jitter: 2.4
      end
      layer :ink_contours, color: :ink do
        arcs 3, radius: 39..84, separated: true, sector: 0..360,
             sweep: 290..334, width: 9..11
        center radius: 19
      end
      layer :petal_fringe, color: :lavender, sector: -76..76 do
        petals 24, radius: 88..99, length: 13..24, width: 10..15
      end
      layer :inner_dots, color: :berry do
        confetti 30, radius: 119..129, sector: -73..73, size: 3..5
      end
      layer :inner_bricks, color: :blush do
        capsules 7, radius: radial(:bricks, 0.71..0.74), sector: -73..73,
                 length: 49..57, width: 26..32
      end
      layer :outer_bricks, color: :butter do
        capsules 6, radius: radial(:bricks, 0.91..0.94),
                 between: { count: 7, sector: -73..73, depth: 1 },
                 length: 55..64, width: 26..32
      end
      layer :outer_dots, color: :berry do
        confetti 72, radius: 244..294,
                 between: { count: 7, sector: -73..73, depth: 2 },
                 density: [2.0, 0.25, 1.8, 0.30], clearance: 4,
                 size: 3..6
      end
      layer :antennae, color: :lavender do
        spokes 5, radius: 206..214,
               between: { count: 7, sector: -73..73, depth: 2 },
               length: 88..124, width: 11..16, tip: 18..24
      end
    end

    instance_eval(&placement)
  end
end

hero_scene = build_scene do
  colony :organism,
         count: 3,
         region: [140, 140, 1250, 910],
         scale: 0.73..0.85,
         rotate: -15..210,
         seed: 2_101,
         spacing: 410,
         drift: 0.20
end

colony_scene = build_scene(seed: 2037) do
  colony :organism,
         count: 8,
         region: [90, 90, 1310, 930],
         scale: 0.40..0.61,
         rotate: -20..235,
         seed: 7_107,
         spacing: 290,
         drift: 0.28
end

hero_path = ARGV.fetch(0, 'design.svg')
colony_path = ARGV.fetch(1, 'colony.svg')

File.write(hero_path, hero_scene.svg)
File.write(colony_path, colony_scene.svg)
puts "wrote #{hero_path}"
puts "wrote #{colony_path}"