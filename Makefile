DOLRECOMP_DIR    := lib/DolRecomp
MODERNGEKKO_DIR  := lib/ModernGekko
DOLRECOMP_BUILD  := $(DOLRECOMP_DIR)/build
MODERNGEKKO_BUILD:= $(MODERNGEKKO_DIR)/build

DOLRECOMP_BIN      := $(DOLRECOMP_BUILD)/dolrecomp
MODERNGEKKO_PORT_BIN := $(MODERNGEKKO_BUILD)/moderngekko-port

# One game per slug directory, so multiple extracted discs (GameCube or
# Wii, any title) can coexist. The slug is derived from ISO's filename the
# first time a game is set up; pass GAME=<slug> on later invocations to
# select it without ISO. With neither given, defaults to Melee.
DEFAULT_GAME_SLUG := Super-Smash-Bros-Melee-USA-En-Ja-Rev-2-1-02
EXTRACTED_ROOT := extracted
GAME_SLUG := $(if $(ISO),$(strip $(shell basename "$(ISO)" | sed -E 's/\.[Ii][Ss][Oo]$$//; s/[^A-Za-z0-9]+/-/g; s/^-+//; s/-+$$//')),$(if $(GAME),$(GAME),$(DEFAULT_GAME_SLUG)))
EXTRACTED_DIR := $(EXTRACTED_ROOT)/$(GAME_SLUG)
MODULES_DIR   := build/modules

JOBS ?= $(shell sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)
CMAKE_BUILD_TYPE ?= Release

# Extra arguments forwarded after `--` to `moderngekko-run` via `make run`,
# e.g. RUN_ARGS="--headless" or RUN_ARGS="--graphics Vulkan".
RUN_ARGS ?=

SUBMODULE_STAMP := .git/.recomp-submodules-stamp
WIT_STAMP := .git/.recomp-wit-stamp

.DEFAULT_GOAL := help

.PHONY: help all tools dolrecomp moderngekko submodules wit extract recompile run \
        clean clean-extracted clean-tools

help:
	@echo "MeleeRecomp"
	@echo ""
	@echo "Works with any GameCube or Wii ISO, not just Melee -- Melee is just"
	@echo "the default when neither ISO= nor GAME= is given."
	@echo ""
	@echo "  make tools                       Build DolRecomp and ModernGekko"
	@echo "  make extract ISO=path/to.iso     Extract a GameCube/Wii ISO"
	@echo "  make recompile ISO=path/to.iso   Recompile + compile a runnable module"
	@echo "  make run ISO=path/to.iso         Recompile (if needed) and launch the game"
	@echo "  make clean                       Remove all build output"
	@echo ""
	@echo "  make run                                          # Melee, once extracted"
	@echo "  make run ISO=iso/Super\\ Smash\\ Bros...iso          # Melee, first time"
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

# --- submodules -------------------------------------------------------------

$(SUBMODULE_STAMP): .gitmodules
	git submodule update --init --recursive
	@mkdir -p "$$(dirname "$(SUBMODULE_STAMP)")"
	@touch "$(SUBMODULE_STAMP)"

submodules: $(SUBMODULE_STAMP)

# --- tools -------------------------------------------------------------------

dolrecomp: submodules
	cmake -S $(DOLRECOMP_DIR) -B $(DOLRECOMP_BUILD) -G Ninja -DCMAKE_BUILD_TYPE=$(CMAKE_BUILD_TYPE)
	cmake --build $(DOLRECOMP_BUILD) -j$(JOBS)

moderngekko: submodules
	cmake -S $(MODERNGEKKO_DIR) -B $(MODERNGEKKO_BUILD) -G Ninja -DCMAKE_BUILD_TYPE=$(CMAKE_BUILD_TYPE)
	cmake --build $(MODERNGEKKO_BUILD) -j$(JOBS)

tools: dolrecomp moderngekko

# Wii ISO extraction needs Wiimms ISO Tools; DolRecomp downloads its own
# copy into extern/wit on first use. GameCube extraction doesn't need this,
# but running it unconditionally keeps the pipeline simple.
#
# The prebuilt macOS wit binaries ship with a signature current Gatekeeper
# rejects outright (`invalid signature (code or signature have been
# modified)`, SIGKILL on launch) -- re-signing ad-hoc locally fixes it.
$(WIT_STAMP): | dolrecomp
	echo y | $(DOLRECOMP_BIN) --setup
	@if [ "$$(uname)" = "Darwin" ] && [ -d extern/wit/bin ]; then \
		codesign --force --deep --sign - extern/wit/bin/* 2>/dev/null || true; \
	fi
	@mkdir -p "$$(dirname "$(WIT_STAMP)")"
	@touch "$(WIT_STAMP)"

wit: $(WIT_STAMP)

# --- recompile pipeline -------------------------------------------------------

# Real file target: skipped automatically once this game has already been
# extracted, so ISO is only required the first time per game. dolrecomp/wit
# are order-only prerequisites (`|`) since they're phony/always "run" --
# normal prerequisites would force re-extraction on every invocation.
# GAME_SLUG always resolves to something (falls back to Melee), so the only
# way this recipe runs with nothing to do is a game that isn't extracted yet.
$(EXTRACTED_DIR)/sys/main.dol: | dolrecomp wit
	@if [ -z "$(ISO)" ]; then \
		echo "error: no extracted game at $(EXTRACTED_DIR) yet -- pass ISO=/path/to/game.iso" >&2; \
		exit 1; \
	fi
	@if [ ! -f "$(ISO)" ]; then \
		echo "error: ISO not found: $(ISO)" >&2; \
		exit 1; \
	fi
	$(DOLRECOMP_BIN) extract "$(ISO)" $(EXTRACTED_DIR)
	@# Wii discs have multiple partitions (UPDATE/CHANNEL/DATA); the wit
	@# bridge extracts each into its own subfolder instead of flattening
	@# the game (DATA) partition to the top level like GameCube does.
	@if [ ! -f "$(EXTRACTED_DIR)/sys/main.dol" ] && [ -f "$(EXTRACTED_DIR)/DATA/sys/main.dol" ]; then \
		mv "$(EXTRACTED_DIR)/DATA"/* "$(EXTRACTED_DIR)/"; \
		rmdir "$(EXTRACTED_DIR)/DATA"; \
	fi

extract: $(EXTRACTED_DIR)/sys/main.dol

# moderngekko-port caches compiled modules by DOL hash + toolchain, so
# re-running these is cheap once a module has already been built.
recompile: moderngekko $(EXTRACTED_DIR)/sys/main.dol
	$(MODERNGEKKO_PORT_BIN) build $(EXTRACTED_DIR) --output $(MODULES_DIR)

run: moderngekko $(EXTRACTED_DIR)/sys/main.dol
	$(MODERNGEKKO_PORT_BIN) run $(EXTRACTED_DIR) --output $(MODULES_DIR) -- $(RUN_ARGS)

# --- cleanup -------------------------------------------------------------------

clean-extracted:
	rm -rf $(EXTRACTED_ROOT) generated $(MODULES_DIR)

clean-tools:
	rm -rf $(DOLRECOMP_BUILD) $(MODERNGEKKO_BUILD)

clean: clean-extracted clean-tools
