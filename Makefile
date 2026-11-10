# Commandes standard du projet : l'agent, la CI et toi utilisez les mêmes.
# Toutes se lancent depuis la racine du dépôt. Les recettes commencent par une TABULATION.
API   := apps/api
FRONT := apps/front

.PHONY: help setup dev dev-api dev-front test test-api test-front test-one lint format typecheck check

help: ## liste les commandes
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | sed -E 's/:.*## / : /'

setup: ## installe les dépendances (API et front)
	cd $(API) && uv sync
	cd $(FRONT) && if [ -f package-lock.json ]; then npm ci; else npm install; fi

dev: ## lance l'API (http://localhost:8000) et le front (http://localhost:5173)
	$(MAKE) -j2 dev-api dev-front

dev-api:
	cd $(API) && uv run uvicorn hammer.api.main:app --reload --port 8000

dev-front:
	cd $(FRONT) && npm run dev

test: test-api test-front ## lance toute la suite de tests

test-api:
	cd $(API) && uv run pytest -q

test-front:
	cd $(FRONT) && npm test --silent

test-one: ## un seul test : make test-one F=apps/api/tests/test_x.py ou F=apps/front/src/x.test.ts
	@case "$(F)" in \
	  $(API)/*) cd $(API) && uv run pytest -q $(patsubst $(API)/%,%,$(F)) ;; \
	  $(FRONT)/*) cd $(FRONT) && npm test --silent -- $(patsubst $(FRONT)/%,%,$(F)) ;; \
	  *) echo "F doit commencer par $(API)/ ou $(FRONT)/" >&2; exit 2 ;; \
	esac

lint: ## vérifie le style (ruff, oxlint)
	cd $(API) && uv run ruff check .
	cd $(FRONT) && npm run lint --silent

format: ## formate le code (ruff format, Prettier)
	cd $(API) && uv run ruff format .
	cd $(FRONT) && npm run format --silent

typecheck: ## vérifie les types (mypy, tsc)
	cd $(API) && uv run mypy
	cd $(FRONT) && npm run typecheck --silent

check: lint typecheck test ## tout ce que la CI vérifie : doit passer avant de dire « terminé »
