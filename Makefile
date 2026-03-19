TEST_RUNNER := ./tests/scripts/run.sh

.PHONY: help test fixture debug

help:
	@bash $(TEST_RUNNER) help

test:
	@bash $(TEST_RUNNER) test

fixture:
	@bash $(TEST_RUNNER) fixture

debug:
	@bash $(TEST_RUNNER) debug
