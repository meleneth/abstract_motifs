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

    # Disjoint angular sectors and concentric radial bands:
    # rays opposite bricks, separated brown/yellow rings, dots in spoke gaps.
    motif :organism, extent: 345, style: :hand_drawn do
      rays 28, from: 115..137, to: 185..248, sector: 104..256,
           width: 4..8, color: :sun, jitter: 2
      arcs 4, radius: 40..83, separated: true, sector: 120..305,
           sweep: 65..145, width: 9..12, color: :ink
      center radius: 19, color: :ink
      petals 24, radius: 88..99, sector: -76..76,
             length: 13..24, width: 10..15, color: :lavender
      confetti 30, radius: 119..129, sector: -73..73,
               size: 3..5, color: :berry
      capsules 7, radius: 164..169, sector: -73..73,
               length: 49..57, width: 26..32, color: :blush
      capsules 7, radius: 210..216, sector: -73..73,
               length: 55..64, width: 26..32, color: :butter
      confetti 72, radius: 244..294,
               between: { count: 5, sector: -76..76 },
               density: [2.0, 0.25, 1.8, 0.30], clearance: 8,
               size: 3..6, color: :berry
      spokes 5, radius: 254..262, sector: -76..76,
             length: 45..67, width: 10..14, color: :lavender, tip: 17..22
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