# frozen_string_literal: true

require "stringio"

require_relative "test_helper"

# Width targets: term (the default), cjk (ambiguous glyphs two columns,
# structure in ASCII, text free) and web (emoji-capable glyphs kept as
# text with U+FE0E), for a block of code, a fiber or the command line.
class TestTarget < Minitest::Test
    T = Tessella::Target

    def test_term_is_the_default
        assert_equal(:term, Tessella.target)
        assert_equal(3, Tessella::Width.of("é─x"))
    end

    def test_cjk_counts_ambiguous_glyphs_as_two
        T.with(:cjk) do
            assert_equal(5, Tessella::Width.of("é─x"))
            assert_equal(:A, Tessella::Width.class_of("─"))
        end
        assert_equal(:term, Tessella.target)
    end

    def test_cjk_draws_structure_in_ascii_and_keeps_text
        out = T.with(:cjk) { Tessella.table([%w[名前 é], %w[ab 2]]).to_s }
        assert_equal("+------+----+\n| 名前 | é |\n", out.lines.first(2).join)
    end

    # ascii: is only a default: given false, the structure is Unicode.
    def test_cjk_ascii_is_a_default
        assert(T.with(:cjk) { Tessella.tree("a\n  b").to_s }.ascii_only?)
        unicode = T.with(:cjk) { Tessella.tree("a\n  b", ascii: false).to_s }
        refute(unicode.ascii_only?)
    end

    def test_web_keeps_emoji_capable_glyphs_as_text
        out = T.with(:web) { Tessella::Compose.frame("go ▶").to_s }
        assert_includes(out, "▶\u{FE0E}")
        refute_includes(Tessella::Compose.frame("go ▶").to_s, "\u{FE0E}")
        assert_equal("▶\u{FE0F}", T.with(:web) { T.adapt("▶\u{FE0F}") })
    end

    def test_an_unknown_target_is_refused
        assert_raises(ArgumentError) { T.with(:mars) { nil } }
        assert_raises(ArgumentError) { Tessella.target = :mars }
    end

    def cli(argv, env: {}) = run_command(argv, "a\n  b\n", env: env)

    def test_the_command_line_takes_a_target
        assert_equal([0, "a\n`-- b\n", ""], cli(%w[--target cjk tree]))
        assert_equal([0, "a\n`-- b\n", ""], cli(%w[--target=cjk tree]))
        assert_equal([0, "a\n`-- b\n", ""],
                     cli(%w[tree], env: { "TESSELLA_TARGET" => "cjk" }))
        assert_equal("a\n└── b\n", cli(%w[tree])[1])
        status, _, err = cli(%w[--target mars tree])
        assert_equal(2, status)
        assert_includes(err, "unknown target")
    end

    def cjk_unicode_figures
        T.with(:cjk) do
            [Tessella::Compose.frame("é abc\n名前", title: "tï", ascii: false),
             Tessella.table([%w[名前 é], %w[ab 2]], ascii: false, title: "x"),
             Tessella.table([%w[a bc], [1, 2]], ascii: false, style: :double)]
        end
    end

    # Under cjk a Unicode box glyph takes two columns: frames and
    # tables asked for in Unicode keep every line one width there.
    def test_cjk_frames_and_tables_in_unicode_close
        cjk_unicode_figures.each do |figure|
            widths = T.with(:cjk) do
                figure.to_s.lines.map { Tessella::Width.of(it.chomp) }
            end
            assert_equal(1, widths.uniq.size, figure.to_s)
        end
    end

    # The command line's way to Unicode under cjk: --no-ascii, on
    # every drawing command; a --style alone names the default it
    # conflicts with.
    def test_no_ascii_asks_for_unicode_under_cjk
        io = { stdin: StringIO.new("a,b\n1,2\n"), stdout: StringIO.new,
               stderr: StringIO.new }
        Tessella::CLI.run(%w[--target cjk table --no-ascii], env: {}, **io)
        assert_includes(io[:stdout].string, "┌")
        status, _, err = cli(%w[--target cjk compose frame --style light -])
        assert_equal(2, status)
        assert_includes(err, "--style light needs --no-ascii under target cjk")
        assert_equal("┌───┐\n", cli(%w[--target cjk compose frame
                                       --no-ascii -])[1].lines.first)
    end

    # seq draws ► ◄, and ►► ◄◄ for async, in every target.
    def test_sequence_arrowheads_are_one_set
        text = "participant A\nparticipant B\nA -> B: go\nB ->> A: back\n"
        web = T.with(:web) { Tessella.seq(text).to_s }
        assert_equal(Tessella.seq(text).to_s, web)
        assert_includes(web, "─►│")
        assert_includes(web, "│◄◄─")
    end

    # An empty TESSELLA_TARGET is no target; a bad one is refused even
    # before --help; --target needs its value.
    def test_target_edge_cases
        out = StringIO.new
        Tessella::CLI.run(%w[rule --width 3], stdin: StringIO.new, stdout: out,
                                              stderr: StringIO.new,
                                              env: { "TESSELLA_TARGET" => "" })
        assert_equal("───\n", out.string)
        assert_equal(2, cli(%w[--target mars --help]).first)
        status, _, err = cli(%w[--target])
        assert_equal(2, status)
        assert_includes(err, "--target needs")
    end
end
