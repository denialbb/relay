.PHONY: check test lint complexity validate payload-guard

check: validate payload-guard lint test complexity

validate:
	omarchy plugin validate ./

payload-guard:
	@if find . -type f -not -path './node_modules/*' -not -path './.git/*' | grep -qiE '(^|/)(AGENTS|CLAUDE)\.md$$|agent_testing_runbook\.md$$|\.cursorrules$$'; then echo "ERROR: agent-control files must not ship in the payload"; exit 1; fi
	@echo "payload guard: OK"

lint:
	command -v qmllint >/dev/null && qmllint BarWidget.qml TriageDrawer.qml components/*.qml services/*.qml models/*.qml theme/*.qml || echo "qmllint missing, skipping (CI needs it)"

test:
	node --test tests/

complexity:
	node tools/check-complexity.mjs
