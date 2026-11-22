# frozen_string_literal: true
# A dependency-free, Ruby-first generative SVG grammar.
require 'cgi'

module Ornament
  class Motif
    attr_reader :instructions
    def initialize = (@instructions = [])
    %i[rays arcs center petals confetti capsules spokes].each do |operation|
      define_method(operation) do |*args, **options|
        @instructions << [operation, args, options]
      end
    end
  end

  class Canvas
    def initialize(width, height, seed:, background: nil)
      @width, @height, @seed, @background = width, height, seed, background
      @palette = {}
      @motifs = {}
      @stamps = []
    end

    def palette(**colors) = @palette.merge!(colors)

    def motif(name, &block)
      @motifs[name] = Motif.new.tap { |m| m.instance_eval(&block) }
    end

    def stamp(name, at:, scale: 1, rotate: 0, seed: nil)
      raise ArgumentError, "unknown motif #{name}" unless @motifs.key?(name)
      @stamps << [name, at, scale, rotate, seed]
    end

    def svg
      body = []
      body << %(<rect width="100%" height="100%" fill="#{color(@background)}"/>) if @background
      @stamps.each_with_index do |(name, at, scale, rotation, seed), index|
        random = Random.new(seed || (@seed + index * 100_003))
        body << %(<g transform="translate(#{at.join(' ')}) rotate(#{rotation}) scale(#{scale})">)
        @motifs.fetch(name).instructions.each do |operation, args, opts|
          send("draw_#{operation}", body, random, *args, **opts)
        end
        body << '</g>'
      end
      %(<svg xmlns="http://www.w3.org/2000/svg" width="#{@width}" height="#{@height}" viewBox="0 0 #{@width} #{@height}">\n#{body.join("\n")}\n</svg>\n)
    end

    private

    def color(name)
      @palette.fetch(name, name).to_s
    end

    def sample(random, value)
      value.is_a?(Range) ? random.rand(value) : value
    end

    def point(radius, degrees)
      angle = degrees * Math::PI / 180.0
      [radius * Math.cos(angle), radius * Math.sin(angle)]
    end

    def coords(x, y) = "#{x.round(2)} #{y.round(2)}"

    def line(body, x1, y1, x2, y2, ink, width)
      body << %(<path d="M #{coords(x1, y1)} L #{coords(x2, y2)}" fill="none" stroke="#{color(ink)}" stroke-width="#{width}" stroke-linecap="round"/>)
    end

    def circle(body, x, y, radius, ink)
      body << %(<circle cx="#{x.round(2)}" cy="#{y.round(2)}" r="#{radius.round(2)}" fill="#{color(ink)}"/>)
    end

    def arc(body, radius, first, last, ink, width)
      a = point(radius, first)
      b = point(radius, last)
      large = (last - first).abs > 180 ? 1 : 0
      body << %(<path d="M #{coords(*a)} A #{radius.round(2)} #{radius.round(2)} 0 #{large} 1 #{coords(*b)}" stroke="#{color(ink)}" stroke-width="#{width}" fill="none" stroke-linecap="round"/>)
    end

    def draw_center(body, _random, radius:, color:)
      circle(body, 0, 0, radius, color)
    end

    def draw_rays(body, random, count, from:, to:, sector:, width:, color:, jitter: 0)
      first, last = sector.minmax
      count.times do |i|
        angle = first + (last - first) * (i + 0.5) / count + random.rand(-jitter.to_f..jitter.to_f)
        near = sample(random, from)
        far = sample(random, to)
        line(body, *point(near, angle), *point(far, angle), color, sample(random, width))
      end
    end

    def draw_arcs(body, random, count, radius:, sector:, sweep:, width:, color:)
      count.times do
        start = sample(random, sector)
        extent = sample(random, sweep)
        arc(body, sample(random, radius), start, start + extent, color, sample(random, width))
      end
    end

    def draw_petals(body, random, count, radius:, sector:, length:, width:, color:)
      first, last = sector.minmax
      count.times do |i|
        angle = first + (last - first) * (i + 0.5) / count
        r = sample(random, radius)
        delta = sample(random, length)
        line(body, *point(r, angle), *point(r + delta, angle), color, sample(random, width))
      end
    end

    def draw_confetti(body, random, count, radius:, sector:, size:, color:)
      count.times do
        r = sample(random, radius)
        angle = sample(random, sector)
        circle(body, *point(r, angle), sample(random, size), color)
      end
    end

    def draw_capsules(body, random, count, radius:, sector:, length:, width:, colors:)
      count.times do |i|
        angle = sector.begin + (sector.end - sector.begin) * (i + 0.5) / count
        r = sample(random, radius)
        x, y = point(r, angle)
        long = sample(random, length)
        thick = sample(random, width)
        ink = colors[i % colors.length]
        # Capsule follows the tangent to its concentric orbit.
        body << %(<rect x="#{(-long / 2.0).round(2)}" y="#{(-thick / 2.0).round(2)}" width="#{long.round(2)}" height="#{thick.round(2)}" rx="#{(thick * 0.35).round(2)}" fill="#{color(ink)}" transform="translate(#{coords(x, y)}) rotate(#{angle + 90})"/>)
      end
    end

    def draw_spokes(body, random, count, radius:, sector:, length:, width:, color:, tip:)
      first, last = sector.minmax
      count.times do |i|
        angle = first + (last - first) * (i + 0.5) / count
        r = sample(random, radius)
        far = r + sample(random, length)
        x1, y1 = point(r, angle)
        x2, y2 = point(far, angle)
        line(body, x1, y1, x2, y2, color, sample(random, width))
        circle(body, x2, y2, sample(random, tip), color)
        circle(body, x2, y2, sample(random, tip) * 0.29, :paper) if @palette[:paper]
      end
    end
  end

  def self.canvas(width, height, seed: 1, background: nil, &block)
    Canvas.new(width, height, seed: seed, background: background).tap do |c|
      c.instance_eval(&block)
    end
  end
end