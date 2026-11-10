# apps/api — pipeline, CLI et API

## Commandes (depuis la racine)
- Un test : `make test-one F=apps/api/tests/test_health.py`
- CLI : `cd apps/api && uv run python -m hammer --help`

## Organisation prévue (à tenir à jour)
- `src/hammer/pipeline/` (mode APPRENDRE) : `pose.py` (MediaPipe), `cleaning.py` (occlusions,
  inversions), `interpolation.py` (spline, Savitzky-Golay), `events.py` (points bas, appuis),
  `metrics.py` (KPI par tour), `config.py` (seuils).
- `src/hammer/api/` : FastAPI, tâche de fond, SQLite.
- `tests/` en miroir de `src/hammer/` ; `tests/fixtures/reference/` en lecture seule.

## Conventions
- Typage complet (mypy) ; numpy et scipy pour le calcul.
- Seuils (visibilité 0,5 ; saut 20 m/s ; trou max 100 ms) dans `pipeline/config.py`, jamais en dur.
- Tests du pipeline sur trajectoires synthétiques à réponse connue (cercle de 0,6 m à 2,5 tr/s),
  avec tolérances explicites (`pytest.approx`) ; jamais de vraie vidéo dans les tests unitaires.
