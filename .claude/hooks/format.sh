#!/usr/bin/env bash
# PostToolUse (Edit|Write) : formate le fichier que l'agent vient d'écrire.
# Ne bloque jamais : un échec de formatage ne doit pas interrompre le travail.

command -v jq >/dev/null 2>&1 || exit 0
FILE=$(jq -r '.tool_input.file_path // empty')
{ [ -n "$FILE" ] && [ -f "$FILE" ]; } || exit 0
ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"

case "$FILE" in
  "$ROOT"/apps/api/*.py)
    (cd "$ROOT/apps/api" && uv run --quiet ruff format "$FILE") >/dev/null 2>&1 ;;
  "$ROOT"/apps/front/*.ts|"$ROOT"/apps/front/*.tsx|"$ROOT"/apps/front/*.css|"$ROOT"/apps/front/*.json)
    # binaire local : pas de npx, donc aucun téléchargement possible
    PRETTIER="$ROOT/apps/front/node_modules/.bin/prettier"
    [ -x "$PRETTIER" ] && (cd "$ROOT/apps/front" && "$PRETTIER" --write "$FILE") >/dev/null 2>&1 ;;
esac
exit 0
