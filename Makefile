SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := all

.PHONY: all
all: clean build test serve

.PHONY: clean
clean:
	bundle clean

.PHONY: build
build:
	bundle update github-pages
	bundle install

.PHONY: serve
serve:
	bundle exec jekyll serve

.PHONY: test
test:
	act -P ubuntu-latest=nektos/act-environments-ubuntu:18.04 -j lint
