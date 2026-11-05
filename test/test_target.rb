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

    def cli(argv, env: {})
        out = StringIO.new
        err = StringIO.new
        status = Tessella::CLI.run(argv, stdin: StringIO.new("a\n  b\n"),
                                         stdout: out, stderr: err, env: env)
        [status, out.string, err.string]
    end

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
end
