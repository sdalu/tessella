# frozen_string_literal: true

require_relative "test_helper"

# Inkchart.line / .scatter / .stairs / .density and their Chart
# subclasses (DESIGN.md, "Chart and kinds"): construction, add, and
# stairs' style. Oracle parity lives in the *Oracle classes below.
class TestLine < Minitest::Test
    def test_line_builds_a_line_chart_with_one_series
        chart = Inkchart.line([1, 2, 3])
        assert_kind_of(Inkchart::Line, chart)
        assert_includes(chart.to_s, "1")
    end

    def test_scatter_builds_a_scatter_chart
        assert_kind_of(Inkchart::Scatter, Inkchart.scatter([1, 2], [3, 4]))
    end

    def test_density_builds_a_density_chart
        assert_kind_of(Inkchart::Density, Inkchart.density([1, 2], [3, 4]))
    end

    def test_stairs_builds_a_stairs_chart
        assert_kind_of(Inkchart::Stairs, Inkchart.stairs([1, 2], [3, 4]))
    end

    def test_stairs_defaults_to_post_style
        post = Inkchart.stairs([1, 2, 4], [1, 3, 4]).to_s
        explicit = Inkchart.stairs([1, 2, 4], [1, 3, 4], style: :post).to_s
        assert_equal(explicit, post)
    end

    def test_stairs_post_and_pre_differ
        post = Inkchart.stairs([1, 2, 4], [1, 3, 4], style: :post).to_s
        pre = Inkchart.stairs([1, 2, 4], [1, 3, 4], style: :pre).to_s
        refute_equal(post, pre)
    end

    def test_stairs_unknown_style_raises_naming_it
        error = assert_raises(ArgumentError) do
            Inkchart.stairs([1, 2], [1, 2], style: :bogus)
        end
        assert_match(/bogus/, error.message)
    end

    def test_add_grows_the_series_and_the_legend
        chart = Inkchart.line([1, 2], [3, 4])
        chart.add([5, 6], [7, 8], name: "second")
        assert_includes(chart.to_s, "second")
    end

    def test_a_chart_can_be_built_without_x
        chart = Inkchart.line([10, 20, 30])
        assert_includes(chart.to_s, "1") # the default, 1-based, x
        assert_includes(chart.to_s, "3")
    end

    def test_density_always_uses_the_density_canvas
        out = Inkchart.density([1, 2, 3], [3, 1, 2], canvas: :braille).to_s
        refute_match(/[⠀-⣿]/, out) # the override is ignored
    end

    def test_density_ascii_true_is_pure_ascii
        out = Inkchart.density([1, 2, 3], [3, 1, 2], ascii: true).to_s
        refute_match(/[^\x00-\x7f]/, out)
    end

    def test_unknown_option_raises_through_the_factory_function
        assert_raises(ArgumentError) { Inkchart.line([1, 2], bogus: true) }
    end
end

# Shared datasets and comparison helpers for the four *Oracle classes
# below: at least four data sets per kind (integers, floats, negatives,
# two named series), text equality after reading U+2800 as a space and
# stripping trailing blanks, and -- for canvas :ascii -- equality of
# everything but the body cells' glyphs (DESIGN.md's oracle note).
module GridParity
    SAMPLES = {
        integers: [[1, 2, 3, 4, 5], [2, 4, 1, 5, 3]],
        floats: [[0.5, 1.5, 2.5, 3.5, 4.5], [1.1, 3.3, 0.2, 2.8, 1.6]],
        negatives: [[-4, -2, 0, 2, 4], [-3, 2, -1, 4, -2]]
    }.freeze

    # Within SAMPLES[:integers]'s own range, so a second series never
    # widens the axes: unicode_plot's bang methods (lineplot!, etc.)
    # draw onto the canvas the first series' GridPlot.new already
    # sized and labelled, without re-widening it for a later series.
    SECOND_SERIES = [[2, 3, 4], [3, 2, 4]].freeze

    WIDTH = 20
    HEIGHT = 8

    def normalize(text)
        text.tr("⠀", " ").split("\n", -1).map(&:rstrip).join("\n")
    end

    def assert_parity(mine, theirs)
        assert_equal(normalize(theirs), normalize(mine))
    end

    # Frame, labels, title and legend only -- never the body cells.
    # Used where a canvas's glyphs are exempt by design (:ascii) or,
    # for Line, where they are exempt by a Canvas finding: see
    # TestLineOracle's comment above.
    def assert_structure_parity(mine, theirs)
        mine_lines = normalize(mine).split("\n")
        their_lines = normalize(theirs).split("\n")
        assert_equal(their_lines.size, mine_lines.size)
        left = their_lines[0].index("┌")
        their_lines.each_index do |i|
            assert_row(mine_lines[i], their_lines[i], left, body_row?(i))
        end
    end

    def body_row?(index) = index.between?(1, HEIGHT)

    def assert_row(mine, theirs, left, body)
        return assert_equal(theirs, mine) unless body

        right = left + 1 + WIDTH
        assert_equal(theirs[0..left], mine[0..left])
        assert_equal(theirs[right..], mine[right..])
    end
end

# Inkchart::Line against unicode_plot's lineplot (DESIGN.md's oracle
# note): grid lines at x = 0 / y = 0 and a legend from named series.
#
# Body pixels match exactly on braille, block and dot: the canvas walks
# a line by a running sum, as unicode_plot does (lib/inkchart/canvas.rb,
# step_line). Only :ascii is compared without its body glyphs, which
# differ by design (DESIGN.md).
class TestLineOracle < Minitest::Test
    include Oracle::Test
    include GridParity

    def test_matches_unicode_plot_on_four_datasets
        need_oracle
        SAMPLES.each_value do |x, y|
            assert_equal(normalize(theirs(:braille, x, y)),
                         normalize(mine(:braille, x, y)))
        end
    end

    def test_matches_unicode_plot_on_block_and_dot_too
        need_oracle
        x, y = SAMPLES[:integers]
        %i[block dot].each do |c|
            assert_equal(normalize(theirs(c, x, y)), normalize(mine(c, x, y)))
        end
    end

    def test_two_named_series_match_unicode_plot
        need_oracle
        x1, y1 = SAMPLES[:integers]
        x2, y2 = SECOND_SERIES
        chart = Inkchart::Line.new(width: WIDTH, height: HEIGHT)
        chart.add(x1, y1, name: "alpha").add(x2, y2, name: "beta")
        plot = UnicodePlot.lineplot(
            x1, y1, name: "alpha", width: WIDTH, height: HEIGHT
        )
        UnicodePlot.lineplot!(plot, x2, y2, name: "beta")
        assert_equal(normalize(Oracle.render(plot)), normalize(chart.to_s))
    end

    def test_ascii_canvas_matches_except_body_glyphs
        need_oracle
        x, y = SAMPLES[:integers]
        assert_canvas_structure(:ascii, x, y)
    end

    private

    def assert_canvas_structure(canvas, x, y)
        assert_structure_parity(mine(canvas, x, y), theirs(canvas, x, y))
    end

    def mine(canvas, x, y)
        Inkchart::Line.new(width: WIDTH, height: HEIGHT,
                           canvas: canvas).add(x, y).to_s
    end

    def theirs(canvas, x, y)
        opts = { width: WIDTH, height: HEIGHT, canvas: canvas }
        Oracle.render(UnicodePlot.lineplot(x, y, **opts))
    end
end

# Inkchart::Scatter against unicode_plot's scatterplot: as Line above,
# but points only, never connected.
class TestScatterOracle < Minitest::Test
    include Oracle::Test
    include GridParity

    def test_matches_unicode_plot_on_four_datasets
        need_oracle
        SAMPLES.each_value do |x, y|
            assert_parity(mine(:braille, x, y), theirs(:braille, x, y))
        end
    end

    def test_matches_unicode_plot_on_block_and_dot_too
        need_oracle
        x, y = SAMPLES[:integers]
        %i[block dot].each { |c| assert_parity(mine(c, x, y), theirs(c, x, y)) }
    end

    def test_two_named_series_match_unicode_plot
        need_oracle
        x1, y1 = SAMPLES[:integers]
        x2, y2 = SECOND_SERIES
        chart = Inkchart::Scatter.new(width: WIDTH, height: HEIGHT)
        chart.add(x1, y1, name: "alpha").add(x2, y2, name: "beta")
        plot = UnicodePlot.scatterplot(
            x1, y1, name: "alpha", width: WIDTH, height: HEIGHT
        )
        UnicodePlot.scatterplot!(plot, x2, y2, name: "beta")
        assert_parity(chart.to_s, Oracle.render(plot))
    end

    def test_ascii_canvas_matches_except_body_glyphs
        need_oracle
        x, y = SAMPLES[:integers]
        assert_structure_parity(mine(:ascii, x, y), theirs(:ascii, x, y))
    end

    private

    def mine(canvas, x, y)
        Inkchart::Scatter.new(width: WIDTH, height: HEIGHT,
                              canvas: canvas).add(x, y).to_s
    end

    def theirs(canvas, x, y)
        opts = { width: WIDTH, height: HEIGHT, canvas: canvas }
        Oracle.render(UnicodePlot.scatterplot(x, y, **opts))
    end
end

# Inkchart::Stairs against unicode_plot's stairs: both style: :post
# (default) and style: :pre, over the same datasets and canvases.
class TestStairsOracle < Minitest::Test
    include Oracle::Test
    include GridParity

    def test_matches_unicode_plot_on_four_datasets_and_both_styles
        need_oracle
        SAMPLES.each_value do |x, y|
            %i[post pre].each do |s|
                assert_parity(mine(s, x, y), theirs(s, x, y))
            end
        end
    end

    def test_two_named_series_match_unicode_plot
        need_oracle
        x1, y1 = SAMPLES[:integers]
        x2, y2 = SECOND_SERIES
        chart = Inkchart::Stairs.new(style: :post, width: WIDTH, height: HEIGHT)
        chart.add(x1, y1, name: "alpha").add(x2, y2, name: "beta")
        plot = UnicodePlot.stairs(
            x1, y1, style: :post, name: "alpha", width: WIDTH, height: HEIGHT
        )
        UnicodePlot.stairs!(plot, x2, y2, style: :post, name: "beta")
        assert_parity(chart.to_s, Oracle.render(plot))
    end

    def test_ascii_canvas_matches_except_body_glyphs
        need_oracle
        x, y = SAMPLES[:integers]
        assert_structure_parity(mine(:post, x, y, :ascii),
                                theirs(:post, x, y, :ascii))
    end

    private

    def mine(style, x, y, canvas = :braille)
        Inkchart::Stairs.new(style: style, width: WIDTH, height: HEIGHT,
                             canvas: canvas).add(x, y).to_s
    end

    def theirs(style, x, y, canvas = :braille)
        opts = { style: style, width: WIDTH, height: HEIGHT, canvas: canvas }
        Oracle.render(UnicodePlot.stairs(x, y, **opts))
    end
end

# Inkchart::Density against unicode_plot's densityplot: always the
# :density canvas, no x = 0 / y = 0 lines (densityplot's own default is
# grid: false, unlike line/scatter/stairs). No :ascii comparison here:
# unicode_plot's density canvas has no ASCII mode to compare against;
# TestLine#test_density_ascii_true_is_pure_ascii covers that invariant
# directly.
class TestDensityOracle < Minitest::Test
    include Oracle::Test
    include GridParity

    def test_matches_unicode_plot_on_four_datasets
        need_oracle
        SAMPLES.each_value { |x, y| assert_parity(mine(x, y), theirs(x, y)) }
    end

    def test_two_named_series_match_unicode_plot
        need_oracle
        x1, y1 = SAMPLES[:integers]
        x2, y2 = SECOND_SERIES
        chart = Inkchart::Density.new(width: WIDTH, height: HEIGHT)
        chart.add(x1, y1, name: "alpha").add(x2, y2, name: "beta")
        plot = UnicodePlot.densityplot(
            x1, y1, name: "alpha", width: WIDTH, height: HEIGHT
        )
        UnicodePlot.densityplot!(plot, x2, y2, name: "beta")
        assert_parity(chart.to_s, Oracle.render(plot))
    end

    private

    def mine(x, y)
        Inkchart::Density.new(width: WIDTH, height: HEIGHT).add(x, y).to_s
    end

    def theirs(x, y)
        opts = { width: WIDTH, height: HEIGHT }
        Oracle.render(UnicodePlot.densityplot(x, y, **opts))
    end
end

# The module functions name their first series (name:), as add names
# the others, so a legend can list every series.
class TestLineFirstName < Minitest::Test
    def test_first_series_named
        %i[line scatter stairs density].each do |kind|
            text = Inkchart.public_send(kind, [1, 2, 3], name: "first").to_s
            assert_includes text, "first", kind.to_s
        end
    end
end
