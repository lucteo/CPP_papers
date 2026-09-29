WG21_MAKEFILE := wg21/Makefile

PAPERS := $(basename $(notdir $(wildcard P*.md)))

P4215_IMAGE_DIR := images/P4215
P4215_D2 := $(wildcard $(P4215_IMAGE_DIR)/*.d2)
P4215_SVG := $(P4215_D2:.d2=.svg)

.PHONY: help
help:
	@printf '%s\n' \
	  'Targets:' \
	  '  make update                 Update wg21 references.' \
	  '  make P4215.html             Build one paper as generated/P4215.html.' \
	  '  make P4215                  Build one paper as generated/P4215.html.' \
	  '  make html                   Build HTML for all top-level P*.md papers.' \
	  '  make pdf                    Build PDF for all top-level P*.md papers.' \
	  '  make latex                  Build LaTeX for all top-level P*.md papers.' \
	  '  make p4215-images           Regenerate P4215 SVGs from D2 with zero padding.' \
	  '  make update-p4215-images    Alias for p4215-images.'

.PHONY: update
update:
	@cd wg21 && $(MAKE) update

.PHONY: html pdf latex
html: $(addsuffix .html,$(PAPERS))
pdf: $(addsuffix .pdf,$(PAPERS))
latex: $(addsuffix .latex,$(PAPERS))

.PHONY: $(PAPERS)
$(PAPERS): %: %.md
	$(MAKE) -f $(WG21_MAKEFILE) $@.html

.PHONY: %.html %.pdf %.latex
%.html %.pdf %.latex:
	$(MAKE) -f $(WG21_MAKEFILE) $@

.PHONY: p4215-images update-p4215-images
p4215-images update-p4215-images: $(P4215_SVG)

.PHONY: FORCE
FORCE:

$(P4215_SVG): %.svg: %.d2 FORCE
	d2 --pad 0 $< $@
