# frozen_string_literal: true
# A dependency-free, Ruby-first generative SVG grammar with composable
# hand-drawn modifiers and clustered composition helpers.
require 'cgi'

module Ornament
  class Style
    attr_reader :name, :parents, :directives

    def initialize(name, parents: [])
      @name = name
      @parents = Array(parents).compact
      @directives = []
    end

    %i[wobble roughness asymmetry pressure echo].each do |operation|
      define_method(operation) do |**options|
        @directives << [operation, options]
      end
    end
  end

  class Motif
    attr_reader :instructions, :style_names, :extent, :layers

    def initialize(style_names: [], extent: nil)
      @instructions = []
      @style_names = Array(style_names).compact
      @extent = extent
      @layers = {}
      @layer_defaults = {}
    end

    # Group semantic visual layers with shared options such as color or sector.
    # Layers keep declarations short without introducing bespoke shape types.
    def layer(name, **defaults, &block)
      raise ArgumentError, "duplicate layer #{name}" if @layers.key?(name)
      raise ArgumentError, 'layer requires a block' unless block
      @layers[name] = { defaults: defaults, start: @instructions.length }
      previous_defaults = @layer_defaults
      @layer_defaults = previous_defaults.merge(defaults)
      instance_eval(&block)
      @layers[name][:finish] = @instructions.length
    ensure
      @layer_defaults = previous_defaults if defined?(previous_defaults)
    end

    %i[rays arcs center petals confetti capsules spokes].each do |operation|
      define_method(operation) do |*args, **options|
        @instructions << [operation, args, @layer_defaults.merge(options)]
      end
    end
  end

  class Canvas
    def initialize(width, height, seed:, background: nil)
      @width, @height, @seed, @background = width, height, seed, background
      @palette = {}
      @motifs = {}
      @styles = {}
      @stamps = []
    end

    def palette(**colors) = @palette.merge!(colors)

    def style(name, extends: nil, &block)
      @styles[name] = Style.new(name, parents: Array(extends)).tap { |s| s.instance_eval(&block) }
    end

    def motif(name, extent: nil, style: nil, &block)
      @motifs[name] = Motif.new(style_names: Array(style), extent: extent).tap { |m| m.instance_eval(&block) }
    end

    def stamp(name, at:, scale: 1, rotate: 0, seed: nil, style: nil)
      raise ArgumentError, "unknown motif #{name}" unless @motifs.key?(name)
      @stamps << {
        name: name,
        at: at,
        scale: scale,
        rotate: rotate,
        seed: seed,
        style: Array(style).compact
      }
    end

    # Generate a clustered composition of related motif instances.
    # region: [x1, y1, x2, y2]
    def colony(name, count:, region:, scale:, rotate: 0, seed: nil, style: nil,
               spacing: nil, drift: 0.22, margin: 28)
      raise ArgumentError, "unknown motif #{name}" unless @motifs.key?(name)

      random = Random.new(seed || (@seed + 7771 + @stamps.length * 17))
      x1, y1, x2, y2 = region
      cx = (x1 + x2) / 2.0
      cy = (y1 + y2) / 2.0
      width = x2 - x1
      height = y2 - y1
      extent = @motifs.fetch(name).extent || 240
      placed = []

      count.times do |index|
        instance_scale = sample(random, scale)
        approximate_radius = extent * instance_scale * 0.52
        desired_gap = spacing || approximate_radius * 1.05
        picked = nil

        150.times do |attempt|
          bias = [1.0 - attempt / 175.0, 0.25].max
          x_pad = margin + approximate_radius * 0.58
          y_pad = margin + approximate_radius * 0.58
          px = clamp(cx + gaussian(random, width * drift * bias), x1 + x_pad, x2 - x_pad)
          py = clamp(cy + gaussian(random, height * drift * bias), y1 + y_pad, y2 - y_pad)

          clear = placed.all? do |existing|
            dx = px - existing[:x]
            dy = py - existing[:y]
            distance = Math.sqrt(dx * dx + dy * dy)
            distance >= (desired_gap + existing[:radius]) * 0.58
          end
          next unless clear

          picked = [px, py]
          break
        end

        picked ||= begin
          x_pad = margin + approximate_radius * 0.58
          y_pad = margin + approximate_radius * 0.58
          [
            random.rand((x1 + x_pad)..(x2 - x_pad)),
            random.rand((y1 + y_pad)..(y2 - y_pad))
          ]
        end

        placed << { x: picked[0], y: picked[1], radius: approximate_radius }
        stamp(name,
              at: [picked[0].round(2), picked[1].round(2)],
              scale: instance_scale,
              rotate: sample(random, rotate),
              seed: (seed || @seed) + index * 997,
              style: style)
      end
    end

    def svg
      body = []
      body << %(<rect width="100%" height="100%" fill="#{color(@background)}"/>) if @background
      @stamps.each_with_index do |stamp_data, index|
        motif = @motifs.fetch(stamp_data[:name])
        random = Random.new(stamp_data[:seed] || (@seed + index * 100_003))
        style_directives = resolve_style_chain(*(motif.style_names + stamp_data[:style]))
        body << %(<g transform="translate(#{stamp_data[:at].join(' ')}) rotate(#{stamp_data[:rotate]}) scale(#{stamp_data[:scale]})">)
        motif.instructions.each do |operation, args, opts|
          send("draw_#{operation}", body, random, style_directives, *args, **opts)
        end
        body << '</g>'
      end
      %(<svg xmlns="http://www.w3.org/2000/svg" width="#{@width}" height="#{@height}" viewBox="0 0 #{@width} #{@height}">\n#{body.join("\n")}\n</svg>\n)
    end

    private

    def resolve_style_chain(*names, seen: {})
      names.compact.flat_map do |name|
        next [] if seen[name]
        seen[name] = true
        style = @styles.fetch(name) { raise ArgumentError, "unknown style #{name}" }
        resolve_style_chain(*style.parents, seen: seen) + style.directives
      end
    end

    def color(name)
      @palette.fetch(name, name).to_s
    end

    def sample(random, value)
      case value
      when Range then random.rand(value)
      when Array then value.sample(random: random)
      else value
      end
    end

    def gaussian(random, sigma)
      return 0.0 if sigma.to_f.zero?
      u1 = [random.rand, 1e-9].max
      u2 = random.rand
      sigma * Math.sqrt(-2.0 * Math.log(u1)) * Math.cos(2.0 * Math::PI * u2)
    end

    def clamp(value, low, high)
      [[value, low].max, high].min
    end

    def point(radius, degrees)
      angle = degrees * Math::PI / 180.0
      [radius * Math.cos(angle), radius * Math.sin(angle)]
    end

    def coords(x, y) = "#{x.round(2)} #{y.round(2)}"

    def centroid(points)
      x = points.sum { |px, _| px } / points.length.to_f
      y = points.sum { |_, py| py } / points.length.to_f
      [x, y]
    end

    def polyline(start_point, finish_point, steps: 9)
      Array.new(steps) do |i|
        t = steps == 1 ? 0.0 : i.to_f / (steps - 1)
        [
          lerp(start_point[0], finish_point[0], t),
          lerp(start_point[1], finish_point[1], t)
        ]
      end
    end

    def arc_points(radius, first, last)
      sweep = last - first
      steps = [[(sweep.abs / 10.0).ceil + 2, 10].max, 42].min
      Array.new(steps) do |i|
        t = steps == 1 ? 0.0 : i.to_f / (steps - 1)
        point(radius, first + sweep * t)
      end
    end

    def blob_points(cx, cy, radius, steps: 18)
      Array.new(steps) do |i|
        angle = 360.0 * i / steps
        x, y = point(radius, angle)
        [cx + x, cy + y]
      end
    end

    def capsule_points(length, width, steps: 12)
      radius = width / 2.0
      left_x = -length / 2.0 + radius
      right_x = length / 2.0 - radius
      points = []
      steps.times do |i|
        angle = -90.0 + 180.0 * i / (steps - 1).to_f
        x, y = point(radius, angle)
        points << [right_x + x, y]
      end
      steps.times do |i|
        angle = 90.0 + 180.0 * i / (steps - 1).to_f
        x, y = point(radius, angle)
        points << [left_x + x, y]
      end
      points
    end

    def rotate_and_translate(points, degrees, tx, ty)
      radians = degrees * Math::PI / 180.0
      c = Math.cos(radians)
      s = Math.sin(radians)
      points.map do |x, y|
        [(x * c - y * s) + tx, (x * s + y * c) + ty]
      end
    end

    def noise1d(value, seed)
      i0 = value.floor
      i1 = i0 + 1
      f = value - i0
      v0 = hash_noise(i0, seed)
      v1 = hash_noise(i1, seed)
      lerp(v0, v1, smoothstep(f))
    end

    def hash_noise(index, seed)
      n = index.to_i * 374_761_393 + seed.to_i * 668_265_263
      n = (n ^ (n >> 13)) * 1_274_126_177
      (((n ^ (n >> 16)) & 0xffff) / 32_767.5) - 1.0
    end

    def smoothstep(t)
      t * t * (3.0 - 2.0 * t)
    end

    def lerp(a, b, t)
      a + (b - a) * t
    end

    def pressure_width(style_directives, index:, random:, base_width:)
      pressure = style_directives.select { |name, _| name == :pressure }
      return base_width if pressure.empty?

      factor = 1.0
      pressure.each_with_index do |(_, opts), k|
        amount = opts.fetch(:amount, 0.12)
        wavelength = [opts.fetch(:wavelength, 32).to_f, 1.0].max
        sample = noise1d(index / wavelength, random_seed(random) + 1900 + k * 31)
        factor *= (1.0 + sample * amount)
      end
      [base_width * factor, 0.75].max
    end

    def random_seed(random)
      random.rand(1..1_000_000_000)
    end

    def apply_asymmetry(points, amount:, seed:)
      angle = ((seed % 3600) / 10.0) * Math::PI / 180.0
      c = Math.cos(angle)
      s = Math.sin(angle)
      sx = 1.0 + amount
      sy = 1.0 - amount * 0.6
      shear = amount * 0.35
      cx, cy = centroid(points)
      points.map do |x, y|
        dx = x - cx
        dy = y - cy
        xr = dx * c - dy * s
        yr = dx * s + dy * c
        xr = xr * sx + yr * shear
        yr = yr * sy
        xx = xr * c + yr * s
        yy = -xr * s + yr * c
        [cx + xx, cy + yy]
      end
    end

    def apply_modifiers(points, style_directives, random:, closed: false)
      transformed = points.map(&:dup)
      return transformed if style_directives.empty?

      style_directives.each_with_index do |(name, opts), idx|
        case name
        when :asymmetry
          transformed = apply_asymmetry(transformed,
                                        amount: opts.fetch(:amount, 0.05),
                                        seed: random_seed(random) + idx * 17)
        when :wobble, :roughness
          amplitude = opts.fetch(:amplitude, name == :wobble ? 3.0 : 0.7).to_f
          wavelength = [opts.fetch(:wavelength, name == :wobble ? 26 : 6).to_f, 1.0].max
          phase = opts.fetch(:phase, 0.0).to_f
          seed = random_seed(random) + idx * 101
          transformed = displace_along_path(transformed, amplitude: amplitude,
                                                          wavelength: wavelength,
                                                          seed: seed,
                                                          phase: phase,
                                                          closed: closed)
        end
      end
      transformed
    end

    def displace_along_path(points, amplitude:, wavelength:, seed:, phase:, closed: false)
      displaced = []
      lengths = cumulative_lengths(points, closed: closed)
      points.each_with_index do |(x, y), index|
        prev_index = index.zero? ? (closed ? points.length - 1 : 0) : index - 1
        next_index = index == points.length - 1 ? (closed ? 0 : points.length - 1) : index + 1
        px, py = points[prev_index]
        nx, ny = points[next_index]
        tx = nx - px
        ty = ny - py
        length = Math.sqrt(tx * tx + ty * ty)
        if length.zero?
          displaced << [x, y]
          next
        end
        normal = [-ty / length, tx / length]
        sample = noise1d(lengths[index] / wavelength + phase, seed)
        displaced << [x + normal[0] * sample * amplitude, y + normal[1] * sample * amplitude]
      end
      displaced
    end

    def cumulative_lengths(points, closed: false)
      lengths = [0.0]
      limit = closed ? points.length : points.length - 1
      1.upto(limit) do |i|
        from = points[i - 1]
        to = points[i % points.length]
        dx = to[0] - from[0]
        dy = to[1] - from[1]
        lengths << lengths.last + Math.sqrt(dx * dx + dy * dy)
      end
      lengths = lengths[0, points.length]
      lengths << lengths.last if lengths.length < points.length
      lengths
    end

    def path_d(points, closed: false)
      commands = ["M #{coords(*points.first)}"]
      points.drop(1).each { |x, y| commands << "L #{coords(x, y)}" }
      commands << 'Z' if closed
      commands.join(' ')
    end

    def echo_directives(style_directives)
      style_directives.select { |name, _| name == :echo }
    end

    def render_stroke(body, points, ink:, width:, style_directives:, random:, closed: false)
      modified = apply_modifiers(points, style_directives, random: random, closed: closed)
      segments = modified.each_cons(2).to_a
      if segments.empty?
        body << %(<path d="#{path_d(modified, closed: closed)}" fill="none" stroke="#{color(ink)}" stroke-width="#{width.round(2)}" stroke-linecap="round" stroke-linejoin="round"/>)
      else
        segments.each_with_index do |(a, b), idx|
          segment_width = pressure_width(style_directives, index: idx, random: random, base_width: width)
          body << %(<path d="M #{coords(*a)} L #{coords(*b)}" fill="none" stroke="#{color(ink)}" stroke-width="#{segment_width.round(2)}" stroke-linecap="round" stroke-linejoin="round"/>)
        end
      end

      echo_directives(style_directives).each do |_, opts|
        dx = opts.fetch(:dx, 1.4)
        dy = opts.fetch(:dy, 1.8)
        opacity = opts.fetch(:opacity, 0.18)
        echo_width = width * opts.fetch(:width_scale, 0.42)
        echo_points = modified.map { |x, y| [x + dx, y + dy] }
        body << %(<path d="#{path_d(echo_points, closed: closed)}" fill="none" stroke="#{color(ink)}" stroke-width="#{echo_width.round(2)}" stroke-linecap="round" stroke-linejoin="round" opacity="#{opacity}"/>)
      end
    end

    def render_fill(body, points, fill:, style_directives:, random:, closed: true)
      modified = apply_modifiers(points, style_directives, random: random, closed: closed)
      body << %(<path d="#{path_d(modified, closed: closed)}" fill="#{color(fill)}" stroke="none"/>)
      echo_directives(style_directives).each do |_, opts|
        next unless opts.fetch(:fill, true)
        dx = opts.fetch(:dx, 1.2)
        dy = opts.fetch(:dy, 1.4)
        opacity = opts.fetch(:opacity, 0.10)
        echo_points = modified.map { |x, y| [x + dx, y + dy] }
        body << %(<path d="#{path_d(echo_points, closed: closed)}" fill="#{color(fill)}" stroke="none" opacity="#{opacity}"/>)
      end
    end

    def draw_center(body, random, style_directives, radius:, color:)
      render_fill(body, blob_points(0, 0, radius, steps: 20), fill: color,
                  style_directives: style_directives, random: random)
    end

    def draw_rays(body, random, style_directives, count, from:, to:, sector:, width:, color:, jitter: 0)
      first, last = sector.minmax
      count.times do |i|
        angle = first + (last - first) * (i + 0.5) / count + random.rand(-jitter.to_f..jitter.to_f)
        near = sample(random, from)
        far = sample(random, to)
        points = polyline(point(near, angle), point(far, angle), steps: 8)
        render_stroke(body, points, ink: color, width: sample(random, width),
                      style_directives: style_directives, random: random)
      end
    end

    def draw_arcs(body, random, style_directives, count, radius:, sector:, sweep:, width:, color:, separated: false)
      count.times do |index|
        start = sample(random, sector)
        extent = sample(random, sweep)
        ring_radius = if separated && radius.is_a?(Range)
                        radius.begin + (radius.end - radius.begin) * (index + 0.5) / count
                      else
                        sample(random, radius)
                      end
        points = arc_points(ring_radius, start, start + extent)
        render_stroke(body, points, ink: color, width: sample(random, width),
                      style_directives: style_directives, random: random)
      end
    end

    def draw_petals(body, random, style_directives, count, radius:, sector:, length:, width:, color:)
      first, last = sector.minmax
      count.times do |i|
        angle = first + (last - first) * (i + 0.5) / count + random.rand(-2.0..2.0)
        r = sample(random, radius)
        delta = sample(random, length)
        points = polyline(point(r, angle), point(r + delta, angle), steps: 6)
        render_stroke(body, points, ink: color, width: sample(random, width),
                      style_directives: style_directives, random: random)
      end
    end

    # Angular gaps are zones between evenly spaced spoke directions.
    # Density weights make selected gaps busy and others quiet.
    def gap_angles(count:, sector:)
      first, last = sector.minmax
      raise ArgumentError, 'spoke count must be at least two' if count < 2
      Array.new(count) { |i| first + (last - first) * (i + 0.5) / count.to_f }
    end

    # Midpoints between ring members. Reuse this lattice for a staggered ring
    # and for spokes, so their alignment survives count/sector changes.
    def lattice_angles(count:, sector:, depth: 0)
      angles = gap_angles(count: count, sector: sector)
      depth.times { angles = angles.each_cons(2).map { |a, b| (a + b) / 2.0 } }
      raise ArgumentError, 'lattice depth exceeds count' if angles.empty?
      angles
    end

    def arranged_angles(count:, sector: nil, between: nil)
      raise ArgumentError, 'specify sector or between, not both' if sector && between
      angles = between ? lattice_angles(**between) : gap_angles(count: count, sector: sector)
      raise ArgumentError, 'count must match lattice slot count' unless angles.length == count
      angles
    end

    def confetti_angles(random, count:, between:, density:, clearance:)
      spokes = lattice_angles(**between)
      weights = density || Array.new(spokes.length - 1, 1.0)
      raise ArgumentError, 'density must have one weight per spoke gap' unless weights.length == spokes.length - 1
      raise ArgumentError, 'density weights must be nonnegative with a positive sum' unless weights.all? { |w| w >= 0 } && weights.sum.positive?

      Array.new(count) do
        choice = random.rand * weights.sum
        gap = weights.index { |w| (choice -= w) <= 0 } || weights.length - 1
        low = spokes[gap] + clearance
        high = spokes[gap + 1] - clearance
        raise ArgumentError, 'spoke clearance leaves no room for dots' unless high > low
        random.rand(low..high)
      end
    end

    def draw_confetti(body, random, style_directives, count, radius:, size:, color:,
                      sector: nil, between: nil, density: nil, clearance: 7)
      raise ArgumentError, 'specify sector or between, not both' if sector && between
      raise ArgumentError, 'specify either sector or between' unless sector || between
      angles = if between
                 confetti_angles(random, count: count, between: between,
                                density: density, clearance: clearance)
               else
                 Array.new(count) { sample(random, sector) }
               end
      angles.each do |angle|
        r = sample(random, radius)
        x, y = point(r, angle)
        render_fill(body, blob_points(x, y, sample(random, size), steps: 14), fill: color,
                    style_directives: style_directives, random: random)
      end
    end

    # Rings can share a reference lattice: 'between:' places bricks or spokes
    # at the interstices of another ring rather than merely applying an offset.
    def draw_capsules(body, random, style_directives, count, radius:, length:, width:,
                      sector: nil, between: nil, color: nil, colors: nil, jitter: 1.5)
      palette = Array(color || colors)
      raise ArgumentError, 'capsules need a color' if palette.empty?
      angles = arranged_angles(count: count, sector: sector, between: between)
      angles.each_with_index do |base_angle, i|
        angle = base_angle + random.rand(-jitter.to_f..jitter.to_f)
        r = sample(random, radius)
        x, y = point(r, angle)
        long = sample(random, length)
        thick = sample(random, width)
        ink = palette[i % palette.length]
        points = rotate_and_translate(capsule_points(long, thick), angle + 90, x, y)
        render_fill(body, points, fill: ink, style_directives: style_directives, random: random)
      end
    end

    def draw_spokes(body, random, style_directives, count, radius:, length:, width:, color:, tip:,
                    sector: nil, between: nil, jitter: 0)
      angles = arranged_angles(count: count, sector: sector, between: between)
      angles.each do |base_angle|
        angle = base_angle + random.rand(-jitter.to_f..jitter.to_f)
        r = sample(random, radius)
        far = r + sample(random, length)
        x1, y1 = point(r, angle)
        x2, y2 = point(far, angle)
        line_points = polyline([x1, y1], [x2, y2], steps: 8)
        render_stroke(body, line_points, ink: color, width: sample(random, width),
                      style_directives: style_directives, random: random)
        outer = sample(random, tip)
        render_fill(body, blob_points(x2, y2, outer, steps: 18), fill: color,
                    style_directives: style_directives, random: random)
        next unless @palette[:paper]

        inner_style = style_directives.reject { |name, _| name == :echo }
        render_fill(body, blob_points(x2, y2, outer * 0.3, steps: 16), fill: :paper,
                    style_directives: inner_style, random: random)
      end
    end
  end

  def self.canvas(width, height, seed: 1, background: nil, &block)
    Canvas.new(width, height, seed: seed, background: background).tap do |canvas|
      canvas.instance_eval(&block)
    end
  end
end