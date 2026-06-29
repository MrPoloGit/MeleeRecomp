PROJECT_ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

ifeq ($(OS),Windows_NT)
    DETECTED_OS := Windows
    EXE         := .exe
    SEP         := $(strip \)
else
    UNAME_S := $(shell uname -s)
    ifeq ($(UNAME_S),Linux)
        DETECTED_OS := Linux
    endif
    ifeq ($(UNAME_S),Darwin)
        DETECTED_OS := macOS
    endif
    EXE :=
    SEP := /
endif

SRC_DIR         := $(PROJECT_ROOT)src
LIB_DIR         := $(PROJECT_ROOT)lib
DOLRECOMP_DIR   := $(LIB_DIR)/DolRecomp
LIBPORPOISE_DIR := $(LIB_DIR)/libPorpoise
MODERNGEKKO_DIR := $(LIB_DIR)/ModernGekko
GXR_DIR			:= $(LIB_DIR)/GXR
DOLRECOMP       := $(DOLRECOMP_DIR)/build/dolrecomp$(EXE)

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'
.PHONY: help

setup: ## Initialize submodules, build DolRecomp and libPorpoise
	git submodule update --init --recursive
	cd $(DOLRECOMP_DIR) && cmake -S . -B build
	cd $(DOLRECOMP_DIR) && cmake --build build --config Release
	cd $(DOLRECOMP_DIR) && ctest --test-dir build -C Release --output-on-failure
	ifeq ($(DETECTED_OS),Windows)
		cd $(LIBPORPOISE_DIR) && build.bat
	else
		cd $(LIBPORPOISE_DIR) && ./build.sh
	endif
.PHONY: setup

extract-generate: ## Extract DOL from ISO using DolRecomp and generate code
	$(DOLRECOMP) extract $(PROJECT_ROOT)iso$(SEP)ssbm.iso $(PROJECT_ROOT)extracted
	$(DOLRECOMP) --gamecube $(PROJECT_ROOT)extracted$(SEP)sys$(SEP)main.dol $(PROJECT_ROOT)generated
.PHONY: extract-generate

build:  ## Build everything
	$(MAKE) extract-generate
.PHONY: build
