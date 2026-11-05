# frozen_string_literal: true

module Tessella
    # ISO 8601 dates and times for `chart --xdate` (DESIGN.md, "Command
    # line"): 2026-11-05, 2026-11-05T14:30, 2026-11-05 14:30:15.5, with
    # Z or +hh:mm (UTC when absent). Plain Ruby, so the command line
    # needs no require "time".
    module IsoTime
        FORM = /\A(\d{4})-(\d\d)-(\d\d)
                (?:[T\ ](\d\d):(\d\d)(?::(\d\d(?:\.\d+)?))?)?
                \s*(Z|[+-]\d\d:?\d\d)?\z/x

        # The Time, or nil when text is not one of the forms above.
        def self.parse(text)
            m = FORM.match(text.strip) or return nil
            date = m[1..5].map(&:to_i) + [m[6].to_f]
            Time.new(*date, offset(m[7]))
        rescue ArgumentError
            nil
        end

        def self.offset(zone)
            return "+00:00" if zone.nil? || zone == "Z"

            zone.include?(":") ? zone : "#{zone[0, 3]}:#{zone[3, 2]}"
        end
    end
end
