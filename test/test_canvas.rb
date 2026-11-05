# frozen_string_literal: true

require_relative "test_helper"

# Canvas: pixel mapping, clipping, colour-last-wins, annotation, and
# oracle parity with unicode_plot's canvases (DESIGN.md, Canvas).
#
# unicode_plot's ASCII canvas picks its glyph from a hand-curated
# lookup table that is itself the behaviour being approximated; there
# is no formula or standard (unlike braille dots or block quadrants)
# to re-derive it from, and DESIGN.md forbids copying code from the
# oracle. Inkchart::Canvas::Ascii therefore uses its own, independent
# shape rule, so only the oracle tests below that do not depend on the
# exact glyph (blank-cell agreement, ASCII-only output) cover :ascii;
# the glyph-for-glyph tests cover :braille, :block, :dot and :density,
# where the mapping is fixed by Unicode or by the brief itself.
class TestCanvas < Minitest::Test
    XLIM = [0.0, 10.0].freeze
    YLIM = [0.0, 10.0].freeze

    def build(type, **)
        Inkchart::Canvas.build(type, width: 10, height: 5,
                                     xlim: XLIM, ylim: YLIM, **)
    end

    def test_cell_dimensions
        c = build(:block)
        assert_equal(10, c.width)
        assert_equal(5, c.height)
    end

    def test_pixel_dimensions
        { braille: [20, 20], block: [20, 10], dot: [10, 10],
          ascii: [30, 15], density: [10, 10] }.each do |type, wh|
            c = build(type)
            assert_equal(wh, [c.pixel_width, c.pixel_height])
        end
    end

    def test_blank_canvas_is_space_never_braille_blank
        %i[braille block dot ascii density].each do |type|
            build(type).rows.flatten.each do |cell|
                assert_equal(Inkchart::Cell.blank, cell)
            end
        end
    end

    def test_point_sets_color
        c = build(:block)
        c.point(5.0, 5.0, color: :red)
        cell = c.rows[2][5]
        refute_equal(" ", cell.char)
        assert_equal(:red, cell.color)
    end

    def test_last_color_wins
        c = build(:block)
        c.point(5.0, 5.0, color: :red)
        c.point(5.0, 5.0, color: :blue)
        assert_equal(:blue, c.rows[2][5].color)
    end

    def test_point_outside_limits_is_clipped
        c = build(:block)
        c.point(50.0, 50.0, color: :red)
        assert(c.rows.flatten.all? { it.char == " " })
    end

    def test_line_outside_limits_is_clipped_not_raised
        c = build(:block)
        c.line(50.0, 50.0, 60.0, 60.0, color: :red)
        assert(c.rows.flatten.all? { it.char == " " })
    end

    def test_line_partially_outside_limits_does_not_raise
        c = build(:braille)
        c.line(-5.0, 5.0, 15.0, 5.0, color: :red)
        refute(c.rows.flatten.all? { it.char == " " })
    end

    def test_annotate_writes_text
        c = build(:ascii)
        c.annotate(2, 1, "hi", color: :green)
        row = c.rows[1]
        assert_equal("h", row[2].char)
        assert_equal("i", row[3].char)
        assert_equal(:green, row[2].color)
    end

    def test_annotate_clips_without_raising
        c = build(:ascii)
        c.annotate(8, 0, "hello")
        assert_equal(2, c.rows[0].count { it.char != " " })
    end

    def test_ascii_canvas_draws_only_ascii
        c = build(:ascii)
        c.line(0.0, 0.0, 10.0, 10.0)
        c.rows.flatten.each { |cell| assert(cell.char.ascii_only?) }
    end

    def test_density_ascii_option_uses_ascii_signs
        c = build(:density, ascii: true)
        c.line(0.0, 0.0, 10.0, 10.0)
        chars = c.rows.flatten.map(&:char).uniq
        assert_empty(chars - [" ", ".", ":", "+", "#"])
    end

    def test_unknown_type_raises_inkchart_error
        assert_raises(Inkchart::Error) { build(:nonsense) }
    end

    # D3: a caller forgetting a required keyword gets Ruby's own
    # phrasing immediately, not a NoMethodError deep in a subclass.
    def test_build_names_one_missing_keyword
        opts = { width: 10, height: 5, xlim: XLIM, ylim: YLIM }
        %i[width height xlim ylim].each do |key|
            rest = opts.reject { |k, _| k == key }
            err = assert_raises(ArgumentError) do
                Inkchart::Canvas.build(:block, **rest)
            end
            assert_equal("missing keyword: :#{key}", err.message)
        end
    end

    def test_build_names_several_missing_keywords
        err = assert_raises(ArgumentError) do
            Inkchart::Canvas.build(:block, width: 10, height: 5)
        end
        assert_equal("missing keywords: :xlim, :ylim", err.message)
    end
end

# Row-by-row glyph comparison against unicode_plot's canvases, skipped
# unless ORACLE= points at a GEM_PATH holding it (test/oracle.rb).
class TestCanvasOracle < Minitest::Test
    include Oracle::Test

    XLIM = TestCanvas::XLIM
    YLIM = TestCanvas::YLIM

    def test_oracle_braille_matches
        need_oracle
        assert_oracle_match(:braille)
    end

    def test_oracle_block_matches
        need_oracle
        assert_oracle_match(:block)
    end

    def test_oracle_dot_matches
        need_oracle
        assert_oracle_match(:dot)
    end

    def test_oracle_density_matches
        need_oracle
        assert_oracle_match(:density)
    end

    def test_oracle_ascii_blank_cells_match
        need_oracle
        o = oracle_glyphs(:ascii) { |c| draw_fixture_oracle(c) }
        m = mine_glyphs(:ascii) { |c| draw_fixture_mine(c) }
        assert_equal(blank_mask(o), blank_mask(m))
    end

    private

    def blank_mask(rows) = rows.map { |r| r.chars.map { it == " " } }

    def assert_oracle_match(type)
        o = oracle_glyphs(type) { |c| draw_fixture_oracle(c) }
        m = mine_glyphs(type) { |c| draw_fixture_mine(c) }
        assert_equal(o, m)
    end

    def draw_fixture_oracle(c)
        c.line!(0.0, 0.0, 10.0, 10.0, :normal)
        c.line!(0.0, 10.0, 10.0, 0.0, :normal)
        c.point!(5.0, 5.0, :normal)
    end

    def draw_fixture_mine(c)
        c.line(0.0, 0.0, 10.0, 10.0)
        c.line(0.0, 10.0, 10.0, 0.0)
        c.point(5.0, 5.0)
    end

    def mine_glyphs(type)
        c = Inkchart::Canvas.build(type, width: 10, height: 5,
                                         xlim: XLIM, ylim: YLIM)
        yield c
        c.rows.map { |row| row.map(&:char).join }
    end

    def oracle_glyphs(type)
        opts = { origin_x: XLIM[0], origin_y: YLIM[0],
                 plot_width: XLIM[1] - XLIM[0],
                 plot_height: YLIM[1] - YLIM[0] }
        c = UnicodePlot::Canvas.create(type, 10, 5, **opts)
        yield c
        (0...c.height).map { |y| oracle_row(c, type, y) }
    end

    def oracle_row(c, type, y)
        (0...c.width).map { |x| oracle_decode(c, type, c.char_at(x, y)) }
                     .join
    end

    def oracle_decode(c, type, value)
        glyph = oracle_glyph(c, type, value)
        glyph == "⠀" ? " " : glyph
    end

    def oracle_glyph(c, type, value)
        return value if type == :braille
        return c.lookup_decode(value) if c.respond_to?(:lookup_decode)
        density_decode(c, value)
    end

    def density_decode(c, value)
        return " " if value.zero?
        signs = [" ", "░", "▒", "▓", "█"]
        max = c.instance_variable_get(:@max_density)
        signs[(value * (signs.size - 1).fdiv(max)).round]
    end
end

# D1: the density canvas's hit counting against the oracle's, over
# 20+ random multi-segment lines at varied sizes, with a fixed seed
# so the run is reproducible. unicode_plot's DensityCanvas clamps
# width/height to a minimum of 5 (MIN_WIDTH/MIN_HEIGHT);
# Inkchart::Canvas::Density does not (DESIGN.md gives no minimum),
# so sizes are kept >= 5 here -- that is the oracle's own domain,
# not a dodge around the difference.
class TestCanvasDensityFuzz < Minitest::Test
    include Oracle::Test

    def test_oracle_density_random_lines_match
        need_oracle
        rng = Random.new(20_261_105)
        20.times { |i| assert_fixture_matches(rng, i) }
    end

    private

    def assert_fixture_matches(rng, i)
        dims, lims, points = random_fixture(rng)
        assert_equal(oracle_rows(dims, lims, points),
                     mine_rows(dims, lims, points), "fixture ##{i}")
    end

    def random_fixture(rng)
        dims = [rng.rand(5..35), rng.rand(5..12)]
        lims = [[rng.rand(-10.0..0.0), rng.rand(1.0..16.0)],
                [rng.rand(-10.0..0.0), rng.rand(1.0..16.0)]]
        [dims, lims, random_points(rng, lims)]
    end

    def random_points(rng, lims)
        xlim, ylim = lims
        n = rng.rand(3..20)
        xs = Array.new(n) { rng.rand((xlim[0] - 2)..(xlim[1] + 2)) }
        ys = Array.new(n) { rng.rand((ylim[0] - 2)..(ylim[1] + 2)) }
        [xs, ys]
    end

    def mine_rows(dims, lims, points)
        width, height = dims
        xlim, ylim = lims
        c = Inkchart::Canvas.build(:density, width: width, height: height,
                                             xlim: xlim, ylim: ylim)
        c.lines(*points)
        c.rows.map { |row| row.map(&:char).join }
    end

    def oracle_rows(dims, lims, points)
        width, height = dims
        xlim, ylim = lims
        opts = { origin_x: xlim[0], origin_y: ylim[0],
                 plot_width: xlim[1] - xlim[0],
                 plot_height: ylim[1] - ylim[0] }
        c = UnicodePlot::Canvas.create(:density, width, height, **opts)
        c.lines!(*points, :normal)
        density_rows(c, dims)
    end

    def density_rows(c, dims)
        width, height = dims
        signs = [" ", "░", "▒", "▓", "█"]
        scale = (signs.size - 1).fdiv(c.instance_variable_get(:@max_density))
        (0...height).map do |y|
            (0...width).map { |x| signs[(c.char_at(x, y) * scale).round] }
                       .join
        end
    end
end

# D2: Inkchart::Canvas::Ascii's shape rule, by pattern -- the data
# plus the small function that reads it, exercised directly rather
# than through drawn points and lines (no oracle involved: the
# ascii glyph is deliberately not oracle-derived, see test_canvas.rb
# above and ascii.rb).
class TestCanvasAsciiGlyph < Minitest::Test
    def ascii
        @ascii ||= Inkchart::Canvas.build(:ascii, width: 1, height: 1,
                                                  xlim: [0.0, 1.0],
                                                  ylim: [0.0, 1.0])
    end

    def glyph_for(pairs)
        code = pairs.reduce(0) { |c, (sx, sy)| c | (1 << ((sy * 3) + sx)) }
        ascii.send(:decode, code)
    end

    def test_top_row_left_is_backtick
        assert_equal("`", glyph_for([[0, 0]]))
    end

    def test_top_row_centre_or_right_is_apostrophe
        assert_equal("'", glyph_for([[1, 0]]))
        assert_equal("'", glyph_for([[2, 0]]))
    end

    def test_top_row_two_or_more_is_double_quote
        assert_equal("\"", glyph_for([[0, 0], [1, 0]]))
    end

    def test_bottom_row_one_is_period
        assert_equal(".", glyph_for([[1, 2]]))
    end

    def test_bottom_row_two_or_more_is_underscore
        assert_equal("_", glyph_for([[0, 2], [2, 2]]))
    end

    def test_only_middle_row_is_dash
        assert_equal("-", glyph_for([[1, 1]]))
        assert_equal("-", glyph_for([[0, 1], [1, 1], [2, 1]]))
    end

    def test_full_middle_row_plus_elsewhere_is_dash_unless_a_column_full
        assert_equal("-", glyph_for([[0, 1], [1, 1], [2, 1], [0, 0]]))
    end

    def test_full_or_near_full_column_alone_is_pipe
        assert_equal("|", glyph_for([[1, 0], [1, 1], [1, 2]]))
        assert_equal("|", glyph_for([[0, 0], [0, 1]]))
    end

    def test_dominant_diagonals_are_slash_and_backslash
        assert_equal("/", glyph_for([[0, 2], [1, 1], [2, 0]]))
        assert_equal("\\", glyph_for([[0, 0], [1, 1], [2, 2]]))
    end

    def test_crossing_is_plus
        assert_equal("+", glyph_for([[0, 0], [1, 1], [2, 2], [0, 2], [2, 0]]))
        full_row_and_column = [[0, 1], [1, 1], [2, 1], [1, 0], [1, 2]]
        assert_equal("+", glyph_for(full_row_and_column))
    end

    def test_dense_is_hash_even_though_it_also_crosses
        dense = [[0, 0], [1, 0], [2, 0], [0, 1], [1, 1], [2, 1], [0, 2]]
        assert_equal("#", glyph_for(dense))
    end

    def test_clean_plus_sign_is_not_dense
        middle_row_and_column = [[0, 1], [1, 1], [2, 1], [1, 0], [1, 2]]
        assert_equal("+", glyph_for(middle_row_and_column))
        assert_equal(5, middle_row_and_column.size)
    end
end
