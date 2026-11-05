# inkchart -- charts for a monospace grid, in Unicode or pure ASCII.
# The targets follow the make skill: help first, check is preflight,
# tests is the suite, all is check plus build.

RUBY      ?= ruby
GEM       ?= gem
RUBOCOP   ?= rubocop
ORACLE    ?=

VERSION   != sed -n 's/.*VERSION = "\(.*\)"/\1/p' lib/inkchart/version.rb
GEMFILE    = inkchart-$(VERSION).gem
SOURCES   != find lib exe tools test -name '*.rb' -o -path 'exe/*' -type f

help:						## show this help (the default)
	@echo 'inkchart -- charts for a monospace grid, in Unicode or pure ASCII'
	@echo ''
	@echo 'Targets:'
	@awk -F':.*## ' '/^[a-z][a-z0-9-]*:.*## /{ \
	    pre = sprintf("  %-16s ", $$1); n = split($$2, w, / /); line = ""; \
	    for (i = 1; i <= n; i++) { \
	        cand = (line == "" ? w[i] : line " " w[i]); \
	        if (length(pre) + length(cand) > 80 && line != "") { \
	            print pre line; pre = "                   "; line = w[i]; \
	        } else line = cand; \
	    } \
	    if (line != "") print pre line; \
	}' Makefile
	@echo ''
	@echo 'Variables (current value):'
	@printf '  %-16s %s\n' \
	    RUBY     '$(RUBY)' \
	    RUBOCOP  '$(RUBOCOP)  (the gate: the ruby skill'"'"'s rules, .rubocop.yml)' \
	    ORACLE   '$(ORACLE)  (a GEM_PATH holding unicode_plot; empty: oracle tests skip)' \
	    VERSION  '$(VERSION)  (from lib/inkchart/version.rb)'
	@echo ''
	@echo 'There is no deploy target, and no publishing one: inkchart is not'
	@echo 'published (a gem push waits for an explicit decision; see README).'

all: check build				## check, then build the gem

check: check-syntax check-style		## preflight: every file parses and passes the house style

check-syntax:					## every Ruby file parses, with warnings on
	@for f in $(SOURCES); do $(RUBY) -wc "$$f" >/dev/null || exit 1; done

check-style:					## the ruby skill's RuboCop gate (.rubocop.yml)
	@$(RUBOCOP) --no-color -c .rubocop.yml lib exe tools test

build: $(GEMFILE)				## build the gem file

$(GEMFILE): inkchart.gemspec $(SOURCES)
	$(GEM) build inkchart.gemspec

bundle:					## write dist/inkchart.rb, the library as one file
	@mkdir -p dist && $(RUBY) tools/bundle.rb dist/inkchart.rb

tests:						## run the suite; ORACLE=path also runs the unicode_plot comparisons
	@INKCHART_ORACLE='$(ORACLE)' $(RUBY) -w test/run.rb

version:					## print the release, bare
	@echo '$(VERSION)'

install: build					## install the gem for this user (gem install --user-install)
	$(GEM) install --user-install --local $(GEMFILE)

uninstall:					## remove what install put down
	$(GEM) uninstall --user-install -x inkchart

clean:						## remove the built gem and dist/
	rm -rf $(GEMFILE) dist

.PHONY: help all check check-syntax check-style build bundle tests version \
	install uninstall clean
