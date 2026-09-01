TEXLIVE_IMAGE ?= ghcr.io/xu-cheng/texlive-alpine:latest
TYPST_IMAGE ?= ghcr.io/typst/typst:latest
TEST_IMAGE ?= os-practicos-tests
UBUNTU_IMAGE ?= ubuntu:latest
FONTS_DIR ?= fonts
TEX_FILES ?= TP1/Practico1.tex TP1/Practico1-extra.tex TP2/Practico2.tex TP2/Practico2-extra.tex TP3/Practico3.tex TP3/Practico3-extra.tex TP4/Practico4.tex TP4/Practico4-extra.tex
TYPST_FILES ?= TP1-typst/Practico1t.typ TP1-typst/Practico1t-extra.typ TP2-typst/Practico2t.typ TP2-typst/Practico2t-extra.typ TP3-typst/Practico3t.typ TP3-typst/Practico3t-extra.typ TP4-typst/Practico4t.typ TP4-typst/Practico4t-extra.typ
WATCH_DIRS := $(sort $(dir $(TEX_FILES) $(TYPST_FILES) TP1/Captura\ desde\ 2026-08-03\ 19-11-55.png) $(FONTS_DIR)/ examples/)

.PHONY: all pdf typst test test-latest clean watch

all: pdf typst

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

typst:
	@set -eu; \
	for typ in $(TYPST_FILES); do \
		dir=$$(dirname "$$typ"); \
		file=$$(basename "$$typ"); \
		echo "Building $$typ"; \
		docker run --rm \
			--user "$$(id -u):$$(id -g)" \
			-v "$(CURDIR):/work" \
			-w "/work/$$dir" \
			"$(TYPST_IMAGE)" \
			compile --root /work --font-path "/work/$(FONTS_DIR)" \
				"$$file" "$${file%.typ}.pdf"; \
	done

test:
	docker build --pull \
		--build-arg UBUNTU_IMAGE="$(UBUNTU_IMAGE)" \
		-f tests/Dockerfile \
		-t "$(TEST_IMAGE)" \
		.
	docker run --rm --network=none "$(TEST_IMAGE)"

test-latest:
	$(MAKE) test UBUNTU_IMAGE=ubuntu:latest

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
	@set -eu; \
	for typ in $(TYPST_FILES); do \
		dir=$$(dirname "$$typ"); \
		file=$$(basename "$$typ"); \
		rm -f "$$dir/$${file%.typ}.pdf"; \
	done

watch:
	@command -v inotifywait >/dev/null || \
		{ echo "watch requires inotify-tools (inotifywait)" >&2; exit 1; }
	@$(MAKE) all
	@echo "Watching $(WATCH_DIRS) for TeX, Typst, and asset changes..."
	@inotifywait -m -r --format '%w%f' $(WATCH_DIRS) | \
	while IFS= read -r changed; do \
		case "$$changed" in \
			*.tex|*.typ|*.sty|*.cls|*.bib|*.png|*.jpg|*.jpeg|*.svg|*.eps) \
				echo "Changed $$changed"; \
				$(MAKE) all; \
				;; \
		esac; \
	done
