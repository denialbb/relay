.PHONY: check test lint complexity validate

check: validate lint test complexity

validate:
	omarchy plugin validate ./

lint:
	command -v qmllint >/dev/null && qmllint BarWidget.qml TriageDrawer.qml components/*.qml services/*.qml models/*.qml theme/*.qml || echo "qmllint missing, skipping (CI needs it)"

test:
	node --test tests/

complexity:
	node tools/check-complexity.mjs
