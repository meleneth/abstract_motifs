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

    motif :organism, extent: 290, style: :hand_drawn do
      rays 26, from: 118..140, to: 175..260, sector: 93..263,
           width: 5..9, color: :sun, jitter: 3
      arcs 5, radius: 42..87, sector: 0..320, sweep: 50..135,
           width: 10..15, color: :ink
      center radius: 20, color: :ink
      petals 22, radius: 93..100, sector: -88..100,
             length: 14..28, width: 11..17, color: :lavender
      confetti 65, radius: 109..239, sector: -79..102,
               size: 4..8, color: :berry
      capsules 10, radius: 164..185, sector: -75..110,
               length: 62..96, width: 33..50, colors: %i[blush butter]
      spokes 5, radius: 221..242, sector: -76..111,
             length: 55..96, width: 13..18, color: :lavender, tip: 24..31
    end

    instance_eval(&placement)
  end
end

hero_scene = build_scene do
  colony :organism,
         count: 3,
         region: [150, 120, 1160, 850],
         scale: 0.86..1.06,
         rotate: -15..210,
         seed: 2_101,
         spacing: 235,
         drift: 0.20
end

colony_scene = build_scene(seed: 2037) do
  colony :organism,
         count: 8,
         region: [90, 90, 1310, 930],
         scale: 0.54..0.92,
         rotate: -20..235,
         seed: 7_107,
         spacing: 145,
         drift: 0.28
end

hero_path = ARGV.fetch(0, 'design.svg')
colony_path = ARGV.fetch(1, 'colony.svg')

File.write(hero_path, hero_scene.svg)
File.write(colony_path, colony_scene.svg)
puts "wrote #{hero_path}"
puts "wrote #{colony_path}"