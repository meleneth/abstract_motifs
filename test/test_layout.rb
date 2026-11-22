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
    rays = [104, 256]
    bricks = [-73, 73]
    refute (rays.first..rays.last).cover?(bricks.last)
    assert_operator rays.first - bricks.last, :>=, 25
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