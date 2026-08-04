TEXLIVE_IMAGE ?= ghcr.io/xu-cheng/texlive-alpine:latest
TEX_FILES ?= TP1/Practico1.tex
WATCH_DIRS := $(sort $(dir $(TEX_FILES)))

.PHONY: all pdf clean watch

all: pdf

pdf:
	@set -eu; \
	for tex in $(TEX_FILES); do \
		dir=$$(dirname "$$tex"); \
		file=$$(basename "$$tex"); \
		echo "Building $$tex"; \
		docker run --rm \
			--user "$$(id -u):$$(id -g)" \
			-v "$(CURDIR):/work" \
			-w "/work/$$dir" \
			"$(TEXLIVE_IMAGE)" \
			latexmk -pdf -file-line-error -halt-on-error \
				-interaction=nonstopmode "$$file"; \
	done

clean:
	@set -eu; \
	for tex in $(TEX_FILES); do \
		dir=$$(dirname "$$tex"); \
		file=$$(basename "$$tex"); \
		docker run --rm \
			--user "$$(id -u):$$(id -g)" \
			-v "$(CURDIR):/work" \
			-w "/work/$$dir" \
			"$(TEXLIVE_IMAGE)" \
			latexmk -C "$$file"; \
	done

watch:
	@command -v inotifywait >/dev/null || \
		{ echo "watch requires inotify-tools (inotifywait)" >&2; exit 1; }
	@$(MAKE) pdf
	@echo "Watching $(WATCH_DIRS) for TeX and asset changes..."
	@inotifywait -m -r --format '%w%f' $(WATCH_DIRS) | \
	while IFS= read -r changed; do \
		case "$$changed" in \
			*.tex|*.sty|*.cls|*.bib|*.png|*.jpg|*.jpeg|*.svg|*.eps) \
				echo "Changed $$changed"; \
				$(MAKE) pdf; \
				;; \
		esac; \
	done
