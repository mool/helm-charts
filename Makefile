# Helm Chart Testing Makefile
SHELL := /bin/bash
CHART_DIR := charts/generic-app

.PHONY: test test-unit test-examples test-single lint help clean

# Colors for output
GREEN := \033[32m
RED := \033[31m
YELLOW := \033[33m
NC := \033[0m # No Color

help:
	@echo "Available targets:"
	@echo "  test         - Run all unit tests"
	@echo "  test-unit    - Run unit tests with default values"
	@echo "  test-examples - Run tests with homelab example values"
	@echo "  test-single   - Run single test file (use FILE=filename)"
	@echo "  lint         - Run helm lint on charts"
	@echo "  clean        - Clean test artifacts"
	@echo ""
	@echo "Examples:"
	@echo "  make test-single FILE=deployment_test.yaml"
	@echo "  make test-examples"

# Check if helm-unittest plugin is installed
check-deps:
	@if ! helm plugin list | grep -q unittest; then \
		echo "$(RED)Error: helm-unittest plugin not installed$(NC)"; \
		echo "Please install it with: helm plugin install https://github.com/helm-unittest/helm-unittest.git"; \
		exit 1; \
	fi
	@echo "$(GREEN)✓ helm-unittest plugin found$(NC)"

# Validate chart directory exists
check-chart:
	@if [ ! -d "$(CHART_DIR)" ]; then \
		echo "$(RED)Error: Chart directory $(CHART_DIR) not found$(NC)"; \
		exit 1; \
	fi
	@if [ ! -f "$(CHART_DIR)/Chart.yaml" ]; then \
		echo "$(RED)Error: Chart.yaml not found in $(CHART_DIR)$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)✓ Chart directory validated$(NC)"

# Run all tests
test: check-deps check-chart test-unit test-examples
	@echo "$(GREEN)✓ All tests completed successfully$(NC)"

# Run unit tests with default values
test-unit: check-deps check-chart
	@echo "$(YELLOW)Running unit tests with default values...$(NC)"
	@if helm unittest $(CHART_DIR)/; then \
		echo "$(GREEN)✓ Unit tests passed$(NC)"; \
	else \
		echo "$(RED)✗ Unit tests failed$(NC)"; \
		exit 1; \
	fi

# Run tests with example configurations
test-examples: check-deps check-chart
	@echo "$(YELLOW)Running tests with homelab examples...$(NC)"
	@test_failed=0; \
	for values_file in $(CHART_DIR)/test-values/*.yaml; do \
		if [ -f "$$values_file" ]; then \
			echo "Testing with $$(basename $$values_file)..."; \
			if ! helm unittest $(CHART_DIR)/ -v "$$values_file"; then \
				echo "$(RED)✗ Failed with $$(basename $$values_file)$(NC)"; \
				test_failed=1; \
			else \
				echo "$(GREEN)✓ Passed with $$(basename $$values_file)$(NC)"; \
			fi; \
		fi; \
	done; \
	if [ $$test_failed -eq 1 ]; then \
		echo "$(RED)✗ Some example configuration tests failed$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)✓ All example configuration tests passed$(NC)"

# Run single test file
test-single: check-deps check-chart
	@if [ -z "$(FILE)" ]; then \
		echo "$(RED)Error: FILE parameter required. Use: make test-single FILE=filename$(NC)"; \
		exit 1; \
	fi
	@if [ ! -f "$(CHART_DIR)/tests/$(FILE)" ]; then \
		echo "$(RED)Error: Test file $(CHART_DIR)/tests/$(FILE) not found$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Running single test: $(FILE)$(NC)"
	@helm unittest $(CHART_DIR)/ -f "tests/$(FILE)"

# Lint charts
lint:
	@echo "$(YELLOW)Linting charts...$(NC)"
	@if helm lint charts/*/; then \
		echo "$(GREEN)✓ Linting passed$(NC)"; \
	else \
		echo "$(RED)✗ Linting failed$(NC)"; \
		exit 1; \
	fi

# Clean test artifacts
clean:
	@echo "$(YELLOW)Cleaning test artifacts...$(NC)"
	@find . -name "*.tmp" -delete 2>/dev/null || true
	@find . -name "*.test" -delete 2>/dev/null || true
	@echo "$(GREEN)✓ Cleanup completed$(NC)"