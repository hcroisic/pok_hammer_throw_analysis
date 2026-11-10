# AGENTS.md

## Projet
POK de Centrale Méditerranée (parcours Do-IT) : une vidéo de lancer de marteau → des KPI par tour
(avance du pied droit sur le point bas, durées d'appui, vitesse des mains, rayon).
Monorepo : `apps/api` (Python 3.12, FastAPI, MediaPipe, SciPy, SQLite) et `apps/front`
(React + TypeScript + Vite). Besoins, règles R1–R9 et critères CA1–CA10 : `docs/cadrage.md`.

## Commandes (depuis la racine)
- Installer : `make setup`
- Lancer en local : `make dev` (API sur :8000, front sur :5173)
- Tous les tests : `make test`
- Un seul test : `make test-one F=apps/api/tests/test_health.py` (à privilégier)
- Avant de dire « terminé » : `make check` doit passer ; montre sa sortie.

## Façon de travailler
- `apps/api/src/hammer/pipeline/` est en mode APPRENDRE : l'étudiant écrit ce code. Explique,
  questionne, relis, donne des indices ; ne fournis pas la solution (skill `tuteur`).
- Ailleurs, mode PRODUIRE : tâche cadrée, plan d'abord si plus de 3 fichiers, petits pas.
- Tickets et mini-specs : Markdown dans `.scratch/` (`T<numéro>-<résumé>.md`).
- Store prompts in ./prompts/ as Markdown files named <timestamp>-<summary>.md. Use a UTC
  timestamp in YYYYMMDDTHHMMSSZ format and a snake_case summary of at most three words.
  This should be done with every starting prompts. The rest of the session should not be written.

## Architecture (ce qui ne se devine pas)
- `hammer.pipeline` est du Python pur, sans FastAPI : appelé par la CLI
  (`uv run python -m hammer ...`) et par la tâche de fond de l'API.
- `hammer.api` orchestre seulement : aucune logique de calcul.
- API asynchrone : `POST /analyses` → 202 + id ; le front interroge `GET /analyses/{id}`
  jusqu'à `done` ou `failed`. BackgroundTasks + SQLite suffisent.
- Résultats lourds dans `data/<id>/` (landmarks.json, series.json) ; SQLite garde les métadonnées.

## Conventions
- Unités SI dans le code (s, m, m/s) ; ms et degrés seulement à l'affichage.
- Temps = numéro d'image / cadence de capture déclarée (`capture_fps`, règle R8), jamais la
  cadence du fichier.
- Point manquant = NaN, jamais 0.
- Corriger un bug = d'abord un test qui échoue, puis le correctif.
- Commits : Conventional Commits, un commit par tâche, numéro de ticket à la fin
  (`feat(pipeline): poses du pied droit (T07)`).
- Branches : `nom/sprintN` créées depuis `main` ; jamais de push direct sur `main`.

## Interdits
- Ne jamais lire ni modifier `.env` ; la référence est `.env.example`.
- Ne jamais modifier `apps/api/tests/fixtures/reference/` (vérité terrain, repérage manuel).
- Ne jamais committer de vidéo ni le dossier `data/` (vie privée).
- Pas de dépendance nouvelle sans la signaler et la justifier (skill `add-dependency`).
- Pas de brique hors cadrage (Redis, Celery, ORM, file de messages…).

## Pièges connus
- Un ralenti à 240 i/s exporté à 30 i/s dure 8 fois plus longtemps : demander `capture_fps`.
- `mediapipe` installe déjà `opencv-contrib-python` (module `cv2`) : ne pas ajouter `opencv-python`.
- MediaPipe : `visibility` < 0,5 = point non fiable ; inversions gauche/droite fréquentes.
