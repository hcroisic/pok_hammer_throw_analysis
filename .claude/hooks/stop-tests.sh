#!/usr/bin/env bash
# Stop : si du code a changé, les tests doivent passer avant que Claude s'arrête.
# DÉSACTIVÉ par défaut (absent de settings.json) : en mode APPRENDRE, des tests rouges sont
# normaux et ce hook pousserait l'agent à réparer le code de l'étudiant à sa place.
# À activer pour les sessions PRODUIRE, tant que `make test` reste sous la minute.

command -v jq >/dev/null 2>&1 || exit 0
INPUT=$(cat)
# Évite une boucle infinie si le hook a déjà relancé Claude
if [ "$(printf '%s' "$INPUT" | jq -r '.stop_hook_active')" = "true" ]; then exit 0; fi

# Rien de modifié : rien à vérifier
if git diff --quiet && git diff --cached --quiet; then exit 0; fi

if ! OUT=$(make test 2>&1); then
  echo "Les tests échouent. Corrige-les avant de terminer :" >&2
  printf '%s\n' "$OUT" | tail -n 40 >&2
  exit 2      # sur Stop, code 2 = Claude continue de travailler
fi
exit 0
