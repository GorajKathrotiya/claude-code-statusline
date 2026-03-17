.PHONY: build clean

SKILL_NAME = statusline
OUTPUT     = $(SKILL_NAME).skill

build:
	@mkdir -p dist/$(SKILL_NAME)/assets
	@cp skill/SKILL.md dist/$(SKILL_NAME)/SKILL.md
	@cp statusline-command.sh dist/$(SKILL_NAME)/assets/statusline-command.sh
	@cd dist && zip -rq ../$(OUTPUT) $(SKILL_NAME)/
	@rm -rf dist
	@echo "Built $(OUTPUT)"

clean:
	@rm -f $(OUTPUT)
	@echo "Cleaned"
