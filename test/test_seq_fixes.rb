# frozen_string_literal: true

require_relative "test_helper"

# Sequence-diagram regressions from the blind bug hunt: a spaceless
# reply, ASCII labels, CJK names under the cjk target, a note over one
# name given twice.
class TestSeqFixes < Minitest::Test
    def test_a_spaceless_reply_is_a_reply
        out = Tessella.seq("A -> B: x\nA-->B: y\n").to_s
        refute_includes(out, "A-")
        assert_includes(out, "┄")
        assert_raises(ArgumentError) { Tessella.seq("A-->>B: x\n") }
    end

    def test_a_non_ascii_label_under_ascii_is_refused
        assert_raises(ArgumentError) do
            Tessella.seq("A -> B: héllo\n", ascii: true)
        end
        assert_raises(ArgumentError) do
            Tessella.seq("A -> B: x\nnote over A: ünï\n", ascii: true)
        end
    end

    def test_a_cjk_name_under_target_cjk_draws
        out = Tessella::Target.with(:cjk) { Tessella.seq("C -> 服务器: GET\n").to_s }
        assert_includes(out, "服务器")
        assert_includes(out, "+")
    end

    def test_a_note_over_one_name_twice
        out = Tessella.seq("A -> B: hi\nnote over A,A: x\n").to_s
        assert_includes(out, "│ x │")
    end
end
