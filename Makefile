# Helm Chart Testing Makefile
SHELL := /bin/bash

# Chart Discovery - automatically find all charts in charts/ directory
CHARTS := $(shell find charts -maxdepth 2 -name "Chart.yaml" -type f | sed 's|/Chart.yaml||' | sed 's|charts/||' | sort)

# Chart Selection - allow targeting specific chart via CHART parameter
CHART ?=
CHART_DIR = $(if $(CHART),charts/$(CHART),)

.PHONY: test test-unit test-single lint help clean list-charts validate-charts

# Colors for output
GREEN := \033[32m
RED := \033[31m
YELLOW := \033[33m
BLUE := \033[34m
NC := \033[0m # No Color

help:
	@echo "Available targets:"
	@echo "  test              - Run tests for all charts (or CHART=name for specific)"
	@echo "  test-unit         - Run unit tests for all charts (or CHART=name for specific)"
	@echo "  test-single       - Run single test file (requires CHART=name FILE=filename)"
	@echo "  lint              - Lint all charts (or CHART=name for specific)"
	@echo "  list-charts       - Show all discovered charts"
	@echo "  validate-charts   - Validate all charts have proper structure"
	@echo "  clean             - Clean test artifacts"
	@echo ""
	@echo "Chart Selection:"
	@echo "  CHART=name        - Target specific chart (e.g., CHART=generic-app)"
	@echo ""
	@echo "Examples:"
	@echo "  make test                                      # Test all charts"
	@echo "  make test CHART=generic-app                    # Test specific chart"
	@echo "  make test-single CHART=generic-app FILE=deployment_test.yaml"
	@echo "  make lint CHART=generic-app                    # Lint specific chart"
	@echo "  make list-charts                               # Show available charts"
	@echo ""
	@echo "Note: When CHART is not specified, operations run on all discovered charts."

# Check if helm-unittest plugin is installed
check-deps:
	@if ! helm plugin list | grep -q unittest; then \
		printf "$(RED)Error: helm-unittest plugin not installed$(NC)\n"; \
		echo "Please install it with: helm plugin install https://github.com/helm-unittest/helm-unittest.git"; \
		exit 1; \
	fi
	@printf "$(GREEN)✓ helm-unittest plugin found$(NC)\n"

# Validate specific chart exists and has proper structure
check-chart:
	@if [ -z "$(CHART)" ]; then \
		printf "$(RED)Error: CHART parameter required$(NC)\n"; \
		printf "Available charts: $(CHARTS)\n"; \
		printf "Usage: make target CHART=chart-name\n"; \
		exit 1; \
	fi
	@if [ ! -d "charts/$(CHART)" ]; then \
		printf "$(RED)Error: Chart '$(CHART)' not found$(NC)\n"; \
		printf "Available charts: $(CHARTS)\n"; \
		exit 1; \
	fi
	@if [ ! -f "charts/$(CHART)/Chart.yaml" ]; then \
		printf "$(RED)Error: Chart.yaml not found in charts/$(CHART)$(NC)\n"; \
		exit 1; \
	fi
	@printf "$(GREEN)✓ Chart '$(CHART)' validated$(NC)\n"

# Check that we have at least one chart
check-charts-exist:
	@if [ -z "$(CHARTS)" ]; then \
		printf "$(RED)Error: No charts found in charts/ directory$(NC)\n"; \
		printf "Expected structure: charts/CHART_NAME/Chart.yaml\n"; \
		exit 1; \
	fi
	@printf "$(GREEN)✓ Found $(words $(CHARTS)) chart(s): $(CHARTS)$(NC)\n"

# Test single chart (internal function)
define test-single-chart
	@printf "$(BLUE)Testing chart: $(1)$(NC)\n"
	@if helm unittest charts/$(1)/; then \
		printf "$(GREEN)✓ $(1) tests passed$(NC)\n"; \
	else \
		printf "$(RED)✗ $(1) tests failed$(NC)\n"; \
		exit 1; \
	fi
endef

# Test all charts (internal function)
define test-all-charts
	@printf "$(YELLOW)Running tests for all charts...$(NC)\n"
	@failed_charts=""; \
	for chart in $(CHARTS); do \
		printf "$(BLUE)Testing chart: $$chart$(NC)\n"; \
		if helm unittest charts/$$chart/; then \
			printf "$(GREEN)✓ $$chart tests passed$(NC)\n"; \
		else \
			printf "$(RED)✗ $$chart tests failed$(NC)\n"; \
			failed_charts="$$failed_charts $$chart"; \
		fi; \
	done; \
	if [ -n "$$failed_charts" ]; then \
		printf "$(RED)Failed charts:$$failed_charts$(NC)\n"; \
		exit 1; \
	fi
	@printf "$(GREEN)✓ All charts tested successfully$(NC)\n"
endef

# Lint single chart (internal function)
define lint-single-chart
	@printf "$(BLUE)Linting chart: $(1)$(NC)\n"
	@if helm lint charts/$(1)/; then \
		printf "$(GREEN)✓ $(1) linting passed$(NC)\n"; \
	else \
		printf "$(RED)✗ $(1) linting failed$(NC)\n"; \
		exit 1; \
	fi
endef

# Lint all charts (internal function)
define lint-all-charts
	@printf "$(YELLOW)Linting all charts...$(NC)\n"
	@failed_charts=""; \
	for chart in $(CHARTS); do \
		printf "$(BLUE)Linting chart: $$chart$(NC)\n"; \
		if helm lint charts/$$chart/; then \
			printf "$(GREEN)✓ $$chart linting passed$(NC)\n"; \
		else \
			printf "$(RED)✗ $$chart linting failed$(NC)\n"; \
			failed_charts="$$failed_charts $$chart"; \
		fi; \
	done; \
	if [ -n "$$failed_charts" ]; then \
		printf "$(RED)Failed charts:$$failed_charts$(NC)\n"; \
		exit 1; \
	fi
	@printf "$(GREEN)✓ All charts linted successfully$(NC)\n"
endef

# Main test target - runs all tests
test: check-deps check-charts-exist
ifeq ($(CHART),)
	$(call test-all-charts)
else
	$(MAKE) check-chart
	$(call test-single-chart,$(CHART))
endif

# Unit test target - same as test for now, but separated for future enhancement
test-unit: check-deps check-charts-exist
ifeq ($(CHART),)
	$(call test-all-charts)
else
	$(MAKE) check-chart
	$(call test-single-chart,$(CHART))
endif

# Run single test file - requires CHART and FILE parameters
test-single: check-deps check-chart
	@if [ -z "$(FILE)" ]; then \
		printf "$(RED)Error: FILE parameter required$(NC)\n"; \
		printf "Usage: make test-single CHART=chart-name FILE=test-file.yaml\n"; \
		exit 1; \
	fi
	@if [ ! -f "charts/$(CHART)/tests/$(FILE)" ]; then \
		printf "$(RED)Error: Test file charts/$(CHART)/tests/$(FILE) not found$(NC)\n"; \
		exit 1; \
	fi
	@printf "$(YELLOW)Running single test: $(FILE) in $(CHART)$(NC)\n"
	@helm unittest charts/$(CHART)/ -f "tests/$(FILE)"

# Lint charts
lint: check-charts-exist
ifeq ($(CHART),)
	$(call lint-all-charts)
else
	$(MAKE) check-chart
	$(call lint-single-chart,$(CHART))
endif

# List all discovered charts
list-charts:
	@printf "$(YELLOW)Discovered charts in charts/ directory:$(NC)\n"
	@if [ -z "$(CHARTS)" ]; then \
		printf "  $(RED)No charts found$(NC)\n"; \
		printf "  Expected structure: charts/CHART_NAME/Chart.yaml\n"; \
	else \
		for chart in $(CHARTS); do \
			if [ -d "charts/$$chart/tests" ]; then \
				test_count=$$(find charts/$$chart/tests -name "*test.yaml" -o -name "*_test.yaml" | wc -l | tr -d ' '); \
				printf "  $(GREEN)✓$(NC) $$chart ($$test_count test files)\n"; \
			else \
				printf "  $(YELLOW)!$(NC) $$chart (no tests directory)\n"; \
			fi; \
		done; \
		printf "\nTotal: $(words $(CHARTS)) chart(s)\n"; \
	fi

# Validate all charts have proper structure
validate-charts: check-charts-exist
	@printf "$(YELLOW)Validating chart structure...$(NC)\n"
	@failed_charts=""; \
	for chart in $(CHARTS); do \
		printf "Validating $$chart... "; \
		if [ ! -f "charts/$$chart/Chart.yaml" ]; then \
			printf "$(RED)✗ Missing Chart.yaml$(NC)\n"; \
			failed_charts="$$failed_charts $$chart"; \
		elif [ ! -f "charts/$$chart/values.yaml" ]; then \
			printf "$(YELLOW)! Missing values.yaml$(NC)\n"; \
		elif [ ! -d "charts/$$chart/templates" ]; then \
			printf "$(YELLOW)! Missing templates directory$(NC)\n"; \
		else \
			printf "$(GREEN)✓$(NC)\n"; \
		fi; \
	done; \
	if [ -n "$$failed_charts" ]; then \
		printf "$(RED)Charts with issues:$$failed_charts$(NC)\n"; \
		exit 1; \
	fi
	@printf "$(GREEN)✓ All charts validated successfully$(NC)\n"

# Clean test artifacts
clean:
	@printf "$(YELLOW)Cleaning test artifacts...$(NC)\n"
	@find . -name "*.tmp" -delete 2>/dev/null || true
	@find . -name "*.test" -delete 2>/dev/null || true
	@printf "$(GREEN)✓ Cleanup completed$(NC)\n"
