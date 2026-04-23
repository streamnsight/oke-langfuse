TEST_RUNNER := ./tests/scripts/run.sh

.PHONY: help test fixture fixture-prewarm fixture-down-all debug

help:
	@bash $(TEST_RUNNER) help

test:
	@bash $(TEST_RUNNER) test $(if $(SUITE),SUITE=$(SUITE),SUITE=fast) $(if $(SCENARIO),SCENARIO=$(SCENARIO))

fixture:
	@bash $(TEST_RUNNER) fixture $(if $(TARGET),TARGET=$(TARGET)) $(if $(ACTION),ACTION=$(ACTION)) $(if $(SIZE),SIZE=$(SIZE)) $(if $(USE_CUSTOM_CLOUD_INIT),USE_CUSTOM_CLOUD_INIT=$(USE_CUSTOM_CLOUD_INIT)) $(if $(IS_PUBLIC_ENDPOINT),IS_PUBLIC_ENDPOINT=$(IS_PUBLIC_ENDPOINT))

fixture-prewarm:
	@bash $(TEST_RUNNER) fixture-prewarm $(if $(SUITE),SUITE=$(SUITE),SUITE=live)

fixture-down-all:
	@bash $(TEST_RUNNER) fixture-down-all

debug:
	@bash $(TEST_RUNNER) debug $(if $(TARGET),TARGET=$(TARGET)) $(if $(SCENARIO),SCENARIO=$(SCENARIO))
