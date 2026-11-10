#!/usr/bin/env bash
# PreToolUse (Edit|Write|NotebookEdit) : bloque l'écriture de fichiers sensibles.
# Code 2 = action bloquée ; le message sur stderr est renvoyé à Claude.

# Sans jq, on ne peut rien vérifier : on bloque plutôt que de laisser passer.
if ! command -v jq >/dev/null 2>&1; then
  echo "Bloqué : jq est introuvable, les garde-fous ne peuvent pas s'exécuter. Installe jq." >&2
  exit 2
fi

FILE=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')
[ -z "$FILE" ] && exit 0
FILE="${FILE//\\//}"                            # séparateurs Windows
ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
REL="${FILE#"$ROOT"/}"                          # chemin relatif à la racine du dépôt
BASE="${REL##*/}"

REASON=""
case "$BASE" in
  .env.example) ;;
  .env|.env.*) REASON="fichier de secrets" ;;
  uv.lock|package-lock.json) REASON="lockfile : il change via uv add ou npm install, pas à la main" ;;
esac
case "/$REL" in
  */.git/*) REASON="dossier .git" ;;
  */tests/fixtures/reference/*) REASON="vérité terrain (repérage manuel) : seul l'étudiant la modifie" ;;
  */.claude/hooks/*|*/.claude/settings.json|*/.claude/settings.local.json)
    REASON="garde-fous de l'agent : seul l'étudiant les modifie" ;;
esac

if [ -n "$REASON" ]; then
  echo "Bloqué par protect-files.sh : $REL est protégé ($REASON)." \
       "Propose la modification à l'utilisateur au lieu de l'écrire." >&2
  exit 2
fi
exit 0
