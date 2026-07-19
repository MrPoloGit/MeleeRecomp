DOLRECOMP_DIR    := lib/DolRecomp
MODERNGEKKO_DIR  := lib/ModernGekko
DOLRECOMP_BUILD  := $(DOLRECOMP_DIR)/build
MODERNGEKKO_BUILD:= $(MODERNGEKKO_DIR)/build

DOLRECOMP_BIN      := $(DOLRECOMP_BUILD)/dolrecomp
MODERNGEKKO_PORT_BIN := $(MODERNGEKKO_BUILD)/moderngekko-port

# One game per slug directory, so multiple extracted discs (GameCube or
# Wii, any title) can coexist. The slug is derived from ISO's filename the
# first time a game is set up; pass GAME=<slug> on later invocations to
# select it without ISO. There is no default game -- ISO= or GAME= must be
# given.
EXTRACTED_ROOT := extracted
GAME_SLUG := $(if $(ISO),$(strip $(shell basename "$(ISO)" | sed -E 's/\.[Ii][Ss][Oo]$$//; s/[^A-Za-z0-9]+/-/g; s/^-+//; s/-+$$//')),$(GAME))
EXTRACTED_DIR := $(EXTRACTED_ROOT)/$(GAME_SLUG)
MODULES_DIR   := build/modules

JOBS ?= $(shell sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)
CMAKE_BUILD_TYPE ?= Release

# Toolchain used to compile the per-game module: auto, clang, gcc, or msvc.
# Defaults per-platform: gcc on Linux, Apple Clang on macOS, MSVC on Windows.
# Override with TOOLCHAIN=<name> -- see the "Toolchain" section in README.md.
ifeq ($(OS),Windows_NT)
DEFAULT_TOOLCHAIN := msvc
else ifeq ($(shell uname -s),Darwin)
DEFAULT_TOOLCHAIN := clang
else
DEFAULT_TOOLCHAIN := gcc
endif
TOOLCHAIN ?= $(DEFAULT_TOOLCHAIN)

# Extra arguments forwarded after `--` to `moderngekko-run` via `make run`,
# e.g. RUN_ARGS="--headless" or RUN_ARGS="--graphics Vulkan".
RUN_ARGS ?=

DOLRECOMP_REPO   := git@github.com:MrPoloGit/DolRecomp.git
MODERNGEKKO_REPO := git@github.com:MrPoloGit/ModernGekko.git

WIT_STAMP := .git/.recomp-wit-stamp

.DEFAULT_GOAL := help

.PHONY: help all tools dolrecomp moderngekko wit extract recompile run \
        clean clean-extracted clean-tools

help:
	@echo "MeleeRecomp"
	@echo ""
	@echo "Works with any GameCube or Wii ISO -- there is no default game."
	@echo "ISO= or GAME= is required the first time you run a target that"
	@echo "needs an extracted game."
	@echo ""
	@echo "  make tools                       Build DolRecomp and ModernGekko"
	@echo "  make extract ISO=path/to.iso     Extract a GameCube/Wii ISO"
	@echo "  make recompile ISO=path/to.iso   Recompile + compile a runnable module"
	@echo "  make run ISO=path/to.iso         Recompile (if needed) and launch the game"
	@echo "  make clean                       Remove all build output"
	@echo ""
	@echo "  make run ISO=iso/Your\\ Game.iso   # first time for a new game"
	@echo "  make run GAME=Your-Game-Slug     # afterwards, once extracted"
	@echo ""
	@echo "TOOLCHAIN selects the compiler for the per-game module: auto, clang,"
	@echo "gcc, or msvc. Defaults to gcc on Linux, clang on macOS, msvc on"
	@echo "Windows. e.g. make run GAME=<slug> TOOLCHAIN=clang"
	@echo ""
	@echo "ISO only needs to be passed once per game. It also picks the slug"
	@echo "used under extracted/<slug>/ -- pass GAME=<slug> on later invocations"
	@echo "instead of ISO to run a different already-extracted game, e.g.:"
	@echo ""
	@echo "  make run ISO=iso/Mario\\ Kart\\ Wii\\ \\(USA\\).iso   # first time"
	@echo "  make run GAME=Mario-Kart-Wii-USA-En-Fr-Es        # afterwards"
	@echo ""
	@echo "Drop ISOs under iso/ (gitignored) if you want a fixed local path."
	@echo ""
	@echo "Bring your own legally-owned game dumps. No game data is included"
	@echo "in or downloaded by this repository."

all: tools

# --- lib clones ----------------------------------------------------------------
$(DOLRECOMP_DIR)/.git:
	git clone $(DOLRECOMP_REPO) $(DOLRECOMP_DIR)
	git -C $(DOLRECOMP_DIR) submodule update --init --recursive

$(MODERNGEKKO_DIR)/.git:
	git clone $(MODERNGEKKO_REPO) $(MODERNGEKKO_DIR)
	git -C $(MODERNGEKKO_DIR) submodule update --init --recursive

# --- tools -------------------------------------------------------------------
dolrecomp: $(DOLRECOMP_DIR)/.git
	cmake -S $(DOLRECOMP_DIR) -B $(DOLRECOMP_BUILD) -G Ninja -DCMAKE_BUILD_TYPE=$(CMAKE_BUILD_TYPE)
	cmake --build $(DOLRECOMP_BUILD) -j$(JOBS)

moderngekko: $(MODERNGEKKO_DIR)/.git
	cmake -S $(MODERNGEKKO_DIR) -B $(MODERNGEKKO_BUILD) -G Ninja -DCMAKE_BUILD_TYPE=$(CMAKE_BUILD_TYPE)
	cmake --build $(MODERNGEKKO_BUILD) -j$(JOBS)

tools: dolrecomp moderngekko

# Wii ISO extraction needs Wiimms ISO Tools
$(WIT_STAMP): | dolrecomp
	echo y | $(DOLRECOMP_BIN) --setup
	@if [ "$$(uname)" = "Darwin" ] && [ -d extern/wit/bin ]; then \
		codesign --force --deep --sign - extern/wit/bin/* 2>/dev/null || true; \
	fi
	@mkdir -p "$$(dirname "$(WIT_STAMP)")"
	@touch "$(WIT_STAMP)"

wit: $(WIT_STAMP)

# --- recompile pipeline -------------------------------------------------------
$(EXTRACTED_DIR)/sys/main.dol: | dolrecomp wit
	@if [ -z "$(GAME_SLUG)" ]; then \
		echo "error: no ISO= or GAME= given -- see 'make help'" >&2; \
		exit 1; \
	fi
	@if [ -z "$(ISO)" ]; then \
		echo "error: no extracted game at $(EXTRACTED_DIR) yet -- pass ISO=/path/to/game.iso" >&2; \
		exit 1; \
	fi
	@if [ ! -f "$(ISO)" ]; then \
		echo "error: ISO not found: $(ISO)" >&2; \
		exit 1; \
	fi
	$(DOLRECOMP_BIN) extract "$(ISO)" $(EXTRACTED_DIR)
	@if [ ! -f "$(EXTRACTED_DIR)/sys/main.dol" ] && [ -f "$(EXTRACTED_DIR)/DATA/sys/main.dol" ]; then \
		mv "$(EXTRACTED_DIR)/DATA"/* "$(EXTRACTED_DIR)/"; \
		rmdir "$(EXTRACTED_DIR)/DATA"; \
	fi

extract: $(EXTRACTED_DIR)/sys/main.dol

# moderngekko-port caches compiled modules by DOL hash + toolchain, so
# re-running these is cheap once a module has already been built.
recompile: moderngekko $(EXTRACTED_DIR)/sys/main.dol
	$(MODERNGEKKO_PORT_BIN) build $(EXTRACTED_DIR) --toolchain $(TOOLCHAIN) --output $(MODULES_DIR)

run: moderngekko $(EXTRACTED_DIR)/sys/main.dol
	$(MODERNGEKKO_PORT_BIN) run $(EXTRACTED_DIR) --toolchain $(TOOLCHAIN) --output $(MODULES_DIR) -- $(RUN_ARGS)

# --- cleanup -------------------------------------------------------------------

clean-extracted:
	rm -rf $(EXTRACTED_ROOT) generated $(MODULES_DIR)

clean-tools:
	rm -rf $(DOLRECOMP_BUILD) $(MODERNGEKKO_BUILD)

clean: clean-extracted clean-tools
