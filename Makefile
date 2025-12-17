# Helm Chart Testing Makefile
SHELL := /bin/bash

# Chart Discovery - automatically find all charts in charts/ directory
CHARTS := $(shell find charts -maxdepth 2 -name "Chart.yaml" -type f | sed 's|/Chart.yaml||' | sed 's|charts/||' | sort)

# Chart Selection - allow targeting specific chart via CHART parameter
CHART ?=

.PHONY: test test-changed help check-deps check-chart

# Colors for output
GREEN := \033[32m
RED := \033[31m
YELLOW := \033[33m
BLUE := \033[34m
NC := \033[0m # No Color

help:
	@echo "Available targets:"
	@echo "  test              - Run tests for all charts (or CHART=name for specific)"
	@echo "  test-changed      - Run tests on changed charts only"
	@echo ""
	@echo "Chart Selection:"
	@echo "  CHART=name        - Target specific chart (e.g., CHART=generic-app)"
	@echo ""
	@echo "Examples:"
	@echo "  make test                                      # Test all charts"
	@echo "  make test CHART=generic-app                    # Test specific chart"
	@echo ""
	@echo "Note: When CHART is not specified, operations run on all discovered charts."

# =============================================================================
# Checks
# =============================================================================

# Check dependencies
check-deps:
	@if ! helm plugin list | grep -q unittest; then \
		printf "$(RED)Error: helm-unittest plugin not installed$(NC)\n"; \
		echo "Please install it with: helm plugin install https://github.com/helm-unittest/helm-unittest.git"; \
		exit 1; \
	fi
	@printf "$(GREEN)✓ helm-unittest plugin found$(NC)\n"
	@if ! command -v ct >/dev/null 2>&1; then \
		printf "$(RED)Error: chart-testing (ct) not found$(NC)\n"; \
		echo "Please install it with: brew install chart-testing"; \
		echo "Or see: https://github.com/helm/chart-testing"; \
		exit 1; \
	fi
	@printf "$(GREEN)✓ chart-testing (ct) found$(NC)\n"

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

# =============================================================================
# Chart Testing (ct) Integration Targets
# =============================================================================

# Run ct lint on one or all charts
test:
ifeq ($(CHART),)
	@printf "$(YELLOW)Running ct lint on all charts...$(NC)\n"
	@ct lint --config ct.yaml --all
else
	$(MAKE) check-chart
	@printf "$(YELLOW)Running ct lint on chart $(CHART) charts...$(NC)\n"
	@ct lint --config ct.yaml --charts charts/$(CHART)
endif

# Run ct lint on changed charts only
test-changed: check-deps
	@printf "$(YELLOW)Running ct lint on changed charts...$(NC)\n"
	@ct lint --config ct.yaml
