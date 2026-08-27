SHELL := /bin/bash

SCRIPT_NAME := unlovable-local-supabase
LEGACY_SCRIPT_NAME := lovable-local-supabase
SCRIPT_SOURCE := bin/lovable-local-supabase
BINDIR ?= $(HOME)/.local/bin
INSTALL_PATH := $(BINDIR)/$(SCRIPT_NAME)
LEGACY_INSTALL_PATH := $(BINDIR)/$(LEGACY_SCRIPT_NAME)
ZSHRC ?= $(HOME)/.zshrc

.DEFAULT_GOAL := help

.PHONY: help install install-script ensure-zshrc verify-bootstrap

help:
	@printf '%s\n' \
		'Available targets:' \
		'  make help     Show this help text' \
		'  make install  Install $(SCRIPT_NAME) into $(BINDIR); first run can auto-install Supabase CLI if needed' \
		'               It also wires the repo to local Supabase via .env.local and supabase/config.toml' \
		'               Installs $(LEGACY_SCRIPT_NAME) as a compatibility alias' \
		'               Default reruns preserve the local DB; use $(SCRIPT_NAME) --reset for a clean rebuild' \
		'  make verify-bootstrap  Run a smoke test for install aliasing and local env wiring'

install: install-script ensure-zshrc

install-script:
	mkdir -p "$(BINDIR)"
	install -m 0755 "$(SCRIPT_SOURCE)" "$(INSTALL_PATH)"
	rm -f "$(LEGACY_INSTALL_PATH)"
	ln -s "$(INSTALL_PATH)" "$(LEGACY_INSTALL_PATH)"

ensure-zshrc:
	@if [ ! -f "$(ZSHRC)" ]; then touch "$(ZSHRC)"; fi
	@if python3 -c 'import pathlib, sys; text = pathlib.Path(sys.argv[1]).read_text() if pathlib.Path(sys.argv[1]).exists() else ""; raise SystemExit(0 if ".local/bin" in text else 1)' "$(ZSHRC)"; then \
		echo "$(ZSHRC) already configures .local/bin"; \
	else \
		printf '\n# Added by unlovable-local-supabase install\nexport PATH="$$HOME/.local/bin:$$PATH"\n' >> "$(ZSHRC)"; \
		echo "Added .local/bin to $(ZSHRC)"; \
	fi

verify-bootstrap:
	bash "./scripts/verify-local-supabase-bootstrap.sh"
