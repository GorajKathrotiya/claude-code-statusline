.PHONY: build clean test

SKILL_NAME = statusline
OUTPUT     = $(SKILL_NAME).skill

build:
	@mkdir -p dist/$(SKILL_NAME)/assets
	@cp skill/SKILL.md dist/$(SKILL_NAME)/SKILL.md
	@cp -L statusline-command.sh dist/$(SKILL_NAME)/assets/statusline-command.sh
	@cd dist && zip -rq ../$(OUTPUT) $(SKILL_NAME)/
	@rm -rf dist
	@echo "Built $(OUTPUT)"

test:
	@sh tests/run_tests.sh

clean:
	@rm -f $(OUTPUT)
	@echo "Cleaned"
