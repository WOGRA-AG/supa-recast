#!/bin/bash

black --config ./pyproject.toml --check supa_recast tests
isort --settings-path ./pyproject.toml --check-only supa_recast tests
mypy -p supa_recast --check-untyped-defs
coverage run --rcfile ./pyproject.toml -m pytest ./tests
coverage report -m --fail-under 95
