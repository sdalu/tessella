# frozen_string_literal: true

require_relative "test_lint"

# The ascii-art skill's gates for artlint.rb, ported: check-artlint.sh
# on tests/fixtures/lint (its --paranoid case dropped with the flag),
# and the lint half of check-fixtures.py on the eval fixtures -- the
# exact planted findings, the clean answer, the alphabet answers.
class TestLintSkillFixtures < Minitest::Test
    include LintHelper

    def clean?(name, **) = Tessella.lint(fixture(name), **).clean?

    def test_the_known_good_fixtures_lint_clean
        %w[clean-good.md ascii-only.md table-ok.md flag-in-label.md]
            .each { assert(clean?(it), it) }
    end

    def test_the_known_bad_fixtures_fail
        refute(clean?("mixed-bad.md"))
        refute(clean?("drift-bad.md"))
    end

    def test_ascii_passes_an_ascii_file_and_fails_a_unicode_one
        assert(clean?("ascii-only.md", ascii: true))
        refute(clean?("clean-good.md", ascii: true))
    end

    def test_alphabet_measures_without_linting
        assert_equal("ascii", Tessella.alphabet(fixture("ascii-only.md")))
        assert_match(/\Autf-8 .*box-drawing\(/,
                     Tessella.alphabet(fixture("clean-good.md")))
        assert_match(/\Autf-8 /, Tessella.alphabet(fixture("mixed-bad.md")))
        assert_equal("ascii", Tessella.alphabet("+--+\n"))
    end
end

# check-fixtures.py's lint checks on the ascii-art eval fixtures.
class TestLintEvalFixtures < Minitest::Test
    include LintHelper

    WEB = { web: true, width: 78 }.freeze

    def damaged = findings(fixture("evals/damaged-checkout.md"), **WEB)

    def test_the_damaged_fixture_reports_exactly_the_planted_defects
        assert_equal([10, 20], lines_of_damaged(/: tab/))
        assert_equal([22], lines_of_damaged(/: trailing/))
        assert_equal([24], lines_of_damaged(/: ASCII structure/))
        assert_equal([14], lines_of_damaged(/: vertical at column/))
        assert_equal([11], lines_of_damaged(/: emoji-capable U\+25B6/))
        assert_equal(6, damaged.size)
    end

    def lines_of_damaged(pattern) = damaged.grep(pattern).map(&:to_i)

    def test_the_reference_answer_and_the_clean_control_lint_clean
        %w[evals/answer-checkout.md evals/deploy.md].each do |name|
            assert_predicate(Tessella.lint(fixture(name), **WEB), :clean?,
                             name)
        end
    end

    def test_the_alphabet_answers
        assert_match(/\Autf-8 box-drawing/,
                     Tessella.alphabet(fixture("evals/deploy.md")))
        assert_equal("ascii", Tessella.alphabet(fixture("evals/packet.h")))
        assert_equal("ascii",
                     Tessella.alphabet(fixture("evals/pipeline.md")))
    end

    def test_alphabet_names_invalid_bytes_and_other_glyphs
        assert_equal("utf-8 invalid-utf-8(1) other(1: U+00E9 é)",
                     Tessella.alphabet("caf\xC3\xA9 \xFF".b))
    end
end
