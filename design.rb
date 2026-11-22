require_relative 'ornament'

art = Ornament.canvas(1408, 1056, seed: 2026, background: :paper) do
  palette paper: '#faf9f4', ink: '#272438', sun: '#eadca7',
          lavender: '#a497c5', berry: '#ab77a3',
          blush: '#bb918d', butter: '#e6d57e'

  motif :organism do
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

  stamp :organism, at: [305, 206], scale: 0.89, rotate: 0
  stamp :organism, at: [435, 640], scale: 0.94, rotate: 186
  stamp :organism, at: [930, 479], scale: 1.02, rotate: 0
end

File.write(ARGV.fetch(0, 'design.svg'), art.svg)