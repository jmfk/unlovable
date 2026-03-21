SHELL := /bin/bash

SCRIPT_NAME := lovable-local-supabase
SCRIPT_SOURCE := bin/$(SCRIPT_NAME)
BINDIR ?= $(HOME)/.local/bin
INSTALL_PATH := $(BINDIR)/$(SCRIPT_NAME)
ZSHRC ?= $(HOME)/.zshrc

.DEFAULT_GOAL := help

.PHONY: help install install-script ensure-zshrc

help:
	@printf '%s\n' \
		'Available targets:' \
		'  make help     Show this help text' \
		'  make install  Install $(SCRIPT_NAME) into $(BINDIR) and ensure ~/.zshrc includes ~/.local/bin'

install: install-script ensure-zshrc

install-script:
	mkdir -p "$(BINDIR)"
	install -m 0755 "$(SCRIPT_SOURCE)" "$(INSTALL_PATH)"

ensure-zshrc:
	@if [ ! -f "$(ZSHRC)" ]; then touch "$(ZSHRC)"; fi
	@if python3 -c 'import pathlib, sys; text = pathlib.Path(sys.argv[1]).read_text() if pathlib.Path(sys.argv[1]).exists() else ""; raise SystemExit(0 if ".local/bin" in text else 1)' "$(ZSHRC)"; then \
		echo "$(ZSHRC) already configures .local/bin"; \
	else \
		printf '\n# Added by lovable-local-supabase install\nexport PATH="$$HOME/.local/bin:$$PATH"\n' >> "$(ZSHRC)"; \
		echo "Added .local/bin to $(ZSHRC)"; \
	fi
