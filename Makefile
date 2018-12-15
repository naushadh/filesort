define USAGE

Available commands:

  - setup: Setup development environment

	- build: Compile all targets in pedantic mode with performance flags turned on.

	- build-prof: Build all targets in pedantic mode with profiling flags turned on.

	- seed: Seed a data file with 1 Million rows (customize using ROWS).

	- run-base: Run `sort` and capture basic runtime stats.

	- run-x: Run `filesort` and capture basic runtime stats (changes args via ARGS).

	- run-x-profile: Run `filesort` and capture detailed runtime stats (changes args via ARGS).

	- test: A/B Test ./data file(s).

	- clean: Purge the debug working dir.

	- help: Print this usage prompt.

endef
export USAGE

TIMESTAMP := $(shell date +%Y-%m-%dT%H:%M:%S)
ROWS ?= 1M
PARALLEL ?= 4
ARGS ?= --key 1 /tmp/in-${ROWS}.csv --output /tmp/out-x-${ROWS}.csv --parallel=${PARALLEL}
MARKER ?= default.parallel:${PARALLEL}

help:
	@echo "$$USAGE"
.PHONY: help

setup:
	mkdir -p .scratch
	mkdir -p .scratch/debug .scratch/out .scratch/prof
	stack install --verbosity warn profiteur --resolver lts-12.22
.PHONY: setup

build:
	stack install --verbosity warn --pedantic --ghc-options "-O2 -optc-O3 -optc-ffast-math -optc-march=core2 -fforce-recomp"
.PHONY: build

build-prof:
	stack install --pedantic --profile --ghc-options "-O2 -fforce-recomp"
.PHONY: build-prof

seed: build
	stack exec -- filesort-gen --out /tmp/in-$(ROWS).csv --limit $(ROWS)
	du -h /tmp/in-$(ROWS).csv
.PHONY: seed

run-base:
	(/usr/local/bin/time -v sort ${ARGS} --buffer-size=200M) \
	&> .scratch/out/base-$(TIMESTAMP)-$(MARKER)-$(ROWS).txt
.PHONY: run-base

run-x: build clean
	(/usr/local/bin/time -v filesort ${ARGS} +RTS -s) \
	&> .scratch/out/x-$(TIMESTAMP)-$(MARKER)-$(ROWS).txt

	code .scratch/out/x-$(TIMESTAMP)-$(MARKER)-$(ROWS).txt
	wc -l /tmp/out-x-${ROWS}.csv
	sort -c /tmp/out-x-${ROWS}.csv
.PHONY: run-x

run-x-prof: build-prof clean
	(/usr/local/bin/time -v filesort ${ARGS} +RTS -p -sstderr) \
	&> .scratch/out/x-$(TIMESTAMP)-prof-$(MARKER)-$(ROWS).txt

	code .scratch/out/x-$(TIMESTAMP)-prof-$(MARKER)-$(ROWS).txt
	mv filesort.prof .scratch/prof/filesort-$(TIMESTAMP)-$(MARKER)-$(ROWS).prof
	stack exec -- profiteur .scratch/prof/filesort-$(TIMESTAMP)-$(MARKER)-$(ROWS).prof
	open .scratch/prof/filesort-$(TIMESTAMP)-$(MARKER)-$(ROWS).prof.html
.PHONY: run-x-prof

test: build clean
	sort --key 1 --output /tmp/test-base.csv data/comma-in-content.csv
	filesort --key 1 --output /tmp/test-x.csv data/comma-in-content.csv
	diff -u /tmp/test-base.csv /tmp/test-x.csv
.PHONY: test

clean:
	rm -f .scratch/debug/*
.PHONY: clean
