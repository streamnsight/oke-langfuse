TEST_RUNNER := ./tests/scripts/run.sh

.PHONY: help test fixture debug

help:
	@bash $(TEST_RUNNER) help

test:
	@bash $(TEST_RUNNER) test $(if $(SUITE),SUITE=$(SUITE)) $(if $(SCENARIO),SCENARIO=$(SCENARIO))

fixture:
	@bash $(TEST_RUNNER) fixture $(if $(TARGET),TARGET=$(TARGET)) $(if $(ACTION),ACTION=$(ACTION)) $(if $(SIZE),SIZE=$(SIZE)) $(if $(USE_CUSTOM_CLOUD_INIT),USE_CUSTOM_CLOUD_INIT=$(USE_CUSTOM_CLOUD_INIT)) $(if $(IS_PUBLIC_ENDPOINT),IS_PUBLIC_ENDPOINT=$(IS_PUBLIC_ENDPOINT))

debug:
	@bash $(TEST_RUNNER) debug $(if $(TARGET),TARGET=$(TARGET)) $(if $(SCENARIO),SCENARIO=$(SCENARIO))
