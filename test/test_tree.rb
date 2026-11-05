# frozen_string_literal: true

require "stringio"
require "tmpdir"

require_relative "test_helper"

# Tessella.tree (ported from the ascii-art skill's scripts/tree.rb):
# exact output on check-tree.sh's own cases, and every refusal Tree
# raises.
class TestTree < Minitest::Test
    UWB = <<~TXT
        uwb/
          ranging/
            twr.rb
            tdoa.rb
          frames/
            blink.rb
          README.md
    TXT

    def test_the_recipe_tree_byte_for_byte
        assert_equal(<<~TXT, Tessella.tree(UWB).to_s)
            uwb/
            ├── ranging/
            │   ├── twr.rb
            │   └── tdoa.rb
            ├── frames/
            │   └── blink.rb
            └── README.md
        TXT
    end

    def test_a_forest_under_root_byte_for_byte
        assert_equal(<<~TXT, Tessella.tree("a\nb\n  c\n", root: "top").to_s)
            top
            ├── a
            └── b
                └── c
        TXT
    end

    def test_a_forest_with_no_root_stays_flush_left
        assert_equal("a\nb\n└── c\n", Tessella.tree("a\nb\n  c\n").to_s)
    end

    ABC = "a\n  b\n  c\n"

    def test_light_is_the_default
        assert_equal("a\n├── b\n└── c\n", Tessella.tree(ABC).to_s)
    end

    def test_heavy_connectors
        assert_equal("a\n┣━━ b\n┗━━ c\n",
                     Tessella.tree(ABC, style: :heavy).to_s)
    end

    def test_rounded_turns_only_the_last_child
        assert_equal("a\n├── b\n╰── c\n",
                     Tessella.tree(ABC, style: :rounded).to_s)
    end

    def test_ascii_connectors
        assert_equal("a\n|-- b\n`-- c\n",
                     Tessella.tree(ABC, ascii: true).to_s)
    end

    def test_ascii_draws_no_non_ascii_byte
        assert(Tessella.tree(ABC, ascii: true).to_s.ascii_only?)
    end

    def test_no_tab_and_no_trailing_blank
        [Tessella.tree(UWB), Tessella.tree(ABC, ascii: true)].each do |block|
            text = block.to_s
            refute_includes(text, "\t")
            refute_match(/ $/, text)
        end
    end

    def test_annotations_share_one_comment_column
        outline = "src/  # sources\n  main.rb  # entry point\n  " \
                  "longname.rb\n"
        assert_equal(<<~TXT, Tessella.tree(outline).to_s)
            src/             # sources
            ├── main.rb      # entry point
            └── longname.rb
        TXT
    end

    def test_bullets_are_stripped
        assert_equal("a\n├── b\n└── c\n",
                     Tessella.tree("- a\n  - b\n  * c\n").to_s)
    end

    def test_cjk_labels_keep_the_frame_by_display_width
        tree = Tessella.tree("親  # note\n  子\n")
        assert_equal("親      # note\n└── 子\n", tree.to_s)
    end
end

# Every refusal Tessella.tree raises: bad input (ArgumentError naming
# the source line), an unknown style, a style conflicting with ascii:
# true, and non-ASCII content under ascii: true.
class TestTreeRefusals < Minitest::Test
    ABC = TestTree::ABC

    def test_a_tab_is_bad_input_naming_the_line
        error = assert_raises(ArgumentError) { Tessella.tree("a\n\tb\n") }
        assert_equal("line 2: a tab in the indentation", error.message)
    end

    def test_a_skipped_level_is_bad_input_naming_the_line
        error = assert_raises(ArgumentError) do
            Tessella.tree("a\n  b\n      c\n")
        end
        assert_equal("line 3: skips a level", error.message)
    end

    def test_indentation_not_a_multiple_of_the_unit
        error = assert_raises(ArgumentError) do
            Tessella.tree("a\n  b\n   c\n")
        end
        assert_equal("line 3: indentation is not a multiple of 2",
                     error.message)
    end

    def test_an_empty_node_label_is_bad_input
        error = assert_raises(ArgumentError) { Tessella.tree("a\n  - \n") }
        assert_equal("line 2: an empty node label", error.message)
    end

    def test_no_nodes_in_the_input
        ["", "\n\n  \n"].each do |blank|
            error = assert_raises(ArgumentError) { Tessella.tree(blank) }
            assert_equal("line 0: no nodes in the input", error.message)
        end
    end

    def test_an_unknown_style_names_it
        error = assert_raises(ArgumentError) do
            Tessella.tree(ABC, style: :triangle)
        end
        assert_equal("unknown style: :triangle", error.message)
    end

    def test_a_style_other_than_the_default_conflicts_with_ascii
        error = assert_raises(ArgumentError) do
            Tessella.tree(ABC, style: :heavy, ascii: true)
        end
        assert_equal("style heavy conflicts with ascii: true", error.message)
    end

    def test_non_ascii_content_is_refused_under_ascii_true
        error = assert_raises(ArgumentError) do
            Tessella.tree("a\n  é\n", ascii: true)
        end
        assert_equal("line 2: is non-ASCII under ascii: true", error.message)
    end

    def test_non_ascii_root_is_refused_under_ascii_true
        error = assert_raises(ArgumentError) do
            Tessella.tree(ABC, root: "é", ascii: true)
        end
        assert_equal("line 0: --root is non-ASCII under ascii: true",
                     error.message)
    end
end

class TestTreeCLI < Minitest::Test
    def run_cli(*argv, stdin: "")
        out = StringIO.new
        err = StringIO.new
        status = Tessella::CLI.run(["tree", *argv],
                                   stdin: StringIO.new(stdin),
                                   stdout: out, stderr: err)
        [status, out.string, err.string]
    end

    def test_drawing_from_stdin
        status, out, = run_cli(stdin: "a\n  b\n")
        assert_equal([0, "a\n└── b\n"], [status, out])
    end

    def test_drawing_from_a_file_argument
        Dir.mktmpdir do |dir|
            path = File.join(dir, "in.txt")
            File.write(path, "a\n  b\n")
            status, out, = run_cli(path)
            assert_equal([0, "a\n└── b\n"], [status, out])
        end
    end

    def test_style_and_root_and_ascii_options
        status, out, = run_cli("--style", "heavy", "--root", "top",
                               stdin: "a\n")
        assert_equal(0, status)
        assert_equal("top\n┗━━ a\n", out)
    end

    def test_a_style_given_with_ascii_is_ignored_like_the_script
        status, out, = run_cli("--style", "heavy", "--ascii", stdin: "a\n  b\n")
        assert_equal(0, status)
        assert_equal("a\n`-- b\n", out)
    end

    def test_max_width_refuses_a_wider_render_naming_the_source_line
        wide = "a\n  a much much much longer child label than ten columns\n"
        status, _, err = run_cli("--max-width", "10", stdin: wide)
        assert_equal(1, status)
        assert_equal("tessella tree: line 2: is 56 columns, over " \
                     "--max-width 10\n", err)
    end

    def test_bad_input_exits_one_with_the_prefixed_message
        status, _, err = run_cli(stdin: "a\n\tb\n")
        assert_equal(1, status)
        assert_equal("tessella tree: line 2: a tab in the indentation\n",
                     err)
    end

    def test_a_missing_file_is_bad_input
        status, _, err = run_cli("/no/such/file/at/all.txt")
        assert_equal(1, status)
        assert_includes(err, "tessella tree: ")
    end

    def test_too_many_file_arguments_exits_two
        status, = run_cli("a.txt", "b.txt", stdin: "a\n")
        assert_equal(2, status)
    end

    def test_an_unknown_style_value_is_a_usage_error
        status, _, err = run_cli("--style", "bogus", stdin: "a\n")
        assert_equal(2, status)
        assert_includes(err, "tessella tree: ")
    end

    def test_an_unknown_option_is_a_usage_error
        status, = run_cli("--bogus", stdin: "a\n")
        assert_equal(2, status)
    end

    def test_help_exits_zero_and_prints_something
        status, out, = run_cli("--help")
        assert_equal(0, status)
        refute_empty(out)
    end
end
