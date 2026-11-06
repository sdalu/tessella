# frozen_string_literal: true

module Tessella
    # Reading a command's input (DESIGN.md, "Command line"): a file or
    # stdin, as UTF-8, an unreadable file or a bad byte named as bad
    # input. Kept apart so CLI's own class body stays under budget.
    class CLI
        # The 1-based number of the first line of text that is not
        # valid UTF-8, or nil: the readers name it as bad input.
        def self.invalid_line(text)
            return nil if text.valid_encoding?

            text.each_line.find_index { !it.valid_encoding? } + 1
        end

        # text, or error (a command's DataError) naming the first line
        # that is not valid UTF-8: bad input, not a crash.
        def self.utf8!(text, error, where = "line ")
            text = text.dup.force_encoding(Encoding::UTF_8) unless
                text.encoding == Encoding::UTF_8
            bad = invalid_line(text)
            raise error, "#{where}#{bad}: invalid UTF-8" if bad

            text
        end

        # A command's input: the file at path, or stdin when path is
        # nil, as UTF-8 text; an unreadable file or invalid UTF-8 is
        # error (the command's DataError), the bad line named after
        # where.
        def self.read_text(path, stdin, error, where = "line ")
            utf8!(path ? File.read(path) : stdin.read, error, where)
        rescue SystemCallError => e
            raise error, cannot_read(path, e)
        end

        # "cannot read PATH: reason" for a file a command cannot open,
        # the reason in the system's own words (ENOENT's "No such file
        # or directory"), not Ruby's "... @ rb_sysopen - PATH".
        def self.cannot_read(path, error)
            "cannot read #{path || "stdin"}: #{error.class.new(nil).message}"
        end
    end
end
