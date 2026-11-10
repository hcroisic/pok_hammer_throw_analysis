# POK — Analyse vidéo du lancer de marteau

Une vidéo de lancer → des KPI par tour : avance du pied droit sur le point bas, durées d'appui,
vitesse des mains, rayon. Projet de 20 h, parcours Do-IT, Centrale Méditerranée.

## Démarrer

```bash
cp .env.example .env
make setup      # une fois : dépendances de l'API (uv) et du front (npm)
make dev        # API http://localhost:8000/health · front http://localhost:5173
make check      # lint + typage + tests, comme la CI
make help       # toutes les commandes
```

Prérequis : git, make, uv, Node 22, jq (utilisé par les hooks de l'agent).

## Où trouver quoi

- Cadrage (besoins, règles, critères) : `docs/cadrage.md`
- Journal de séance : `docs/journal.md`
- Tickets : `.scratch/` · prompts de départ : `prompts/`
- Instructions pour les agents : `AGENTS.md` (+ `CLAUDE.md` pour Claude Code)
