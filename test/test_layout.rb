# frozen_string_literal: true
require 'minitest/autorun'
require_relative '../ornament'

class LayoutTest < Minitest::Test
  def setup
    @canvas = Ornament::Canvas.new(1000, 1000, seed: 42, background: :paper)
    @canvas.palette(paper: '#faf9f4', blush: '#bb918d', butter: '#e6d57e', berry: '#ab77a3')
    @random = Random.new(42)
  end

  def test_spoke_gaps_match_evenly_spaced_spoke_angles
    angles = @canvas.send(:gap_angles, count: 5, sector: -76..76)
    assert_equal 5, angles.length
    assert_in_delta(-60.8, angles.first, 0.001)
    assert_in_delta(60.8, angles.last, 0.001)
    assert angles.each_cons(2).all? { |a, b| (b - a) > 30 }
  end

  def test_confetti_respects_spoke_clearance_and_gap_weights
    spokes = @canvas.send(:gap_angles, count: 5, sector: -76..76)
    dots = @canvas.send(:confetti_angles, @random, count: 500,
                       between: { count: 5, sector: -76..76 },
                       density: [2.0, 0.25, 1.8, 0.30], clearance: 8)
    counts = [0, 0, 0, 0]
    dots.each do |angle|
      gap = spokes.each_cons(2).find_index { |a, b| angle > a && angle < b }
      refute_nil gap
      counts[gap] += 1
      assert_operator(angle, :>=, spokes[gap] + 8)
      assert_operator(angle, :<=, spokes[gap + 1] - 8)
    end
    assert_operator counts[0], :>, counts[1] * 3
    assert_operator counts[2], :>, counts[3] * 3
  end

  def test_capsule_rings_have_disjoint_radial_bands
    brown_radius, brown_width = [164, 169], [26, 32]
    yellow_radius, yellow_width = [210, 216], [26, 32]
    brown_outer = brown_radius.last + brown_width.last / 2.0
    yellow_inner = yellow_radius.first - yellow_width.last / 2.0
    assert_operator yellow_inner - brown_outer, :>, 6
  end

  def test_rays_and_bricks_have_disjoint_angular_sectors
    rays = [99, 261]
    bricks = [-73, 73]
    refute (rays.first..rays.last).cover?(bricks.last)
    assert_operator rays.first - bricks.last, :>=, 20
  end

  def test_staggered_bricks_and_spokes_share_a_lattice
    lattice = { count: 7, sector: -73..73 }
    brown = @canvas.send(:lattice_angles, **lattice)
    yellow = @canvas.send(:lattice_angles, **lattice, depth: 1)
    spokes = @canvas.send(:lattice_angles, **lattice, depth: 2)

    assert_equal [7, 6, 5], [brown.length, yellow.length, spokes.length]
    yellow.each_with_index do |angle, i|
      assert_in_delta((brown[i] + brown[i + 1]) / 2.0, angle, 1e-10)
    end
    spokes.each_with_index do |angle, i|
      assert_in_delta((yellow[i] + yellow[i + 1]) / 2.0, angle, 1e-10)
    end
    assert_equal yellow, @canvas.send(:arranged_angles, count: 6,
                                       between: lattice.merge(depth: 1))
    assert_equal spokes, @canvas.send(:arranged_angles, count: 5,
                                       between: lattice.merge(depth: 2))
  end

  def test_confetti_uses_actual_spoke_lattice
    lattice = { count: 7, sector: -73..73, depth: 2 }
    spokes = @canvas.send(:lattice_angles, **lattice)
    angles = @canvas.send(:confetti_angles, @random, count: 250,
                          between: lattice,
                          density: [3.0, 0.25, 2.0, 0.25], clearance: 4)
    counts = Array.new(4, 0)
    angles.each do |angle|
      i = spokes.each_cons(2).find_index { |a, b| angle > a && angle < b }
      refute_nil i
      counts[i] += 1
      assert_operator angle, :>=, spokes[i] + 4
      assert_operator angle, :<=, spokes[i + 1] - 4
    end
    assert_operator counts[0], :>, counts[1] * 3
    assert_operator counts[2], :>, counts[3] * 3
  end

  def test_invalid_lattice_depth_is_rejected
    assert_raises(ArgumentError) do
      @canvas.send(:lattice_angles, count: 2, sector: -30..30, depth: 2)
    end
  end

  def test_named_layers_inherit_defaults_and_allow_overrides
    motif = Ornament::Motif.new
    motif.layer :ink_contours, color: :ink, sector: 0..360 do
      arcs 3, radius: 40..84, sweep: 290..334, width: 9..11
      center radius: 19, color: :override
    end
    assert_equal [:arcs, :center], motif.instructions.map(&:first)
    assert_equal :ink, motif.instructions[0][2][:color]
    assert_equal(0..360, motif.instructions[0][2][:sector])
    assert_equal :override, motif.instructions[1][2][:color]
    assert_equal 2, motif.layers[:ink_contours][:finish]
    assert_raises(ArgumentError) { motif.layer(:ink_contours) { center radius: 10 } }
  end

  def test_ink_ring_coverage_has_small_interruptions
    ring_count = 3
    sweeps = 290..334
    radii = 39..84
    assert_operator sweeps.min, :>=, 280
    assert_operator 360 - sweeps.max, :>=, 10
    assert_operator (radii.max - radii.min).to_f / ring_count, :>, 11
  end

  def test_seeded_output_is_repeatable
    render = lambda do
      Ornament.canvas(400, 400, seed: 10) do
        palette blush: '#bb918d', butter: '#e6d57e'
        motif :sample do
          capsules 5, radius: 130..140, sector: -70..70,
                   length: 40..50, width: 20..24, color: :blush
          capsules 5, radius: 200..210, sector: -70..70,
                   length: 40..50, width: 20..24, color: :butter
        end
        stamp :sample, at: [200, 200]
      end.svg
    end
    assert_equal render.call, render.call
  end

  def test_confetti_rejects_impossible_clearance
    assert_raises(ArgumentError) do
      @canvas.send(:confetti_angles, @random, count: 1,
                   between: { count: 5, sector: -40..40 },
                   density: [1, 1, 1, 1], clearance: 15)
    end
  end
end