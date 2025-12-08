# Helm Chart Testing Makefile
SHELL := /bin/bash
CHART_DIR := charts/generic-app

.PHONY: test test-unit test-single lint help clean

# Colors for output
GREEN := \033[32m
RED := \033[31m
YELLOW := \033[33m
NC := \033[0m # No Color

help:
	@echo "Available targets:"
	@echo "  test         - Run unit tests with default values"
	@echo "  test-unit    - Run unit tests with default values"
	@echo "  test-single  - Run single test file (use FILE=filename)"
	@echo "  lint         - Run helm lint on charts"
	@echo "  clean        - Clean test artifacts"
	@echo ""
	@echo "Examples:"
	@echo "  make test-single FILE=deployment_test.yaml"
	@echo "  make test"
	@echo ""
	@echo "Note: Example values in test-values/ are for documentation and"
	@echo "      demonstration purposes. They are not used in unit testing."

# Check if helm-unittest plugin is installed
check-deps:
	@if ! helm plugin list | grep -q unittest; then \
		printf "$(RED)Error: helm-unittest plugin not installed$(NC)\n"; \
		echo "Please install it with: helm plugin install https://github.com/helm-unittest/helm-unittest.git"; \
		exit 1; \
	fi
	@printf "$(GREEN)✓ helm-unittest plugin found$(NC)\n"

# Validate chart directory exists
check-chart:
	@if [ ! -d "$(CHART_DIR)" ]; then \
		printf "$(RED)Error: Chart directory $(CHART_DIR) not found$(NC)\n"; \
		exit 1; \
	fi
	@if [ ! -f "$(CHART_DIR)/Chart.yaml" ]; then \
		printf "$(RED)Error: Chart.yaml not found in $(CHART_DIR)$(NC)\n"; \
		exit 1; \
	fi
	@printf "$(GREEN)✓ Chart directory validated$(NC)\n"

# Run unit tests with default values
test: check-deps check-chart test-unit
	@printf "$(GREEN)✓ All tests completed successfully$(NC)\n"

# Run unit tests with default values
test-unit: check-deps check-chart
	@printf "$(YELLOW)Running unit tests with default values...$(NC)\n"
	@if helm unittest $(CHART_DIR)/; then \
		printf "$(GREEN)✓ Unit tests passed$(NC)\n"; \
	else \
		printf "$(RED)✗ Unit tests failed$(NC)\n"; \
		exit 1; \
	fi

# Run single test file
test-single: check-deps check-chart
	@if [ -z "$(FILE)" ]; then \
		printf "$(RED)Error: FILE parameter required. Use: make test-single FILE=filename$(NC)\n"; \
		exit 1; \
	fi
	@if [ ! -f "$(CHART_DIR)/tests/$(FILE)" ]; then \
		printf "$(RED)Error: Test file $(CHART_DIR)/tests/$(FILE) not found$(NC)\n"; \
		exit 1; \
	fi
	@printf "$(YELLOW)Running single test: $(FILE)$(NC)\n"
	@helm unittest $(CHART_DIR)/ -f "tests/$(FILE)"

# Lint charts
lint:
	@printf "$(YELLOW)Linting charts...$(NC)\n"
	@if helm lint charts/*/; then \
		printf "$(GREEN)✓ Linting passed$(NC)\n"; \
	else \
		printf "$(RED)✗ Linting failed$(NC)\n"; \
		exit 1; \
	fi

# Clean test artifacts
clean:
	@printf "$(YELLOW)Cleaning test artifacts...$(NC)\n"
	@find . -name "*.tmp" -delete 2>/dev/null || true
	@find . -name "*.test" -delete 2>/dev/null || true
	@printf "$(GREEN)✓ Cleanup completed$(NC)\n"