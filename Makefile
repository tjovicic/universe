GIT_REVISION := $(shell git rev-parse --short HEAD)

.PHONY: cuefmt
cuefmt:
	@(find . -name '*.cue' -exec cue fmt -s {} \;)

.PHONY: cuelint
cuelint: cuefmt
	@test -z "$$(git status -s . | grep -e "^ M"  | grep .cue | cut -d ' ' -f3 | tee /dev/stderr)"

.PHONY: shellcheck
shellcheck:
	shellcheck ./tests/*.bats ./tests/*.bash
	shellcheck ./stdlib/*.bats ./stdlib/*.bash

.PHONY: lint
lint: shellcheck cuelint

.PHONY: integration
integration: core-integration universe-test

.PHONY: core-integration
core-integration:
	yarn --cwd "./tests" install
	DAGGER_BINARY="/usr/local/bin/dagger" yarn --cwd "./tests" test

.PHONY: universe-test
universe-test:
	yarn --cwd "./universe" install
	DAGGER_BINARY="/usr/local/bin/dagger" yarn --cwd "./universe" test

