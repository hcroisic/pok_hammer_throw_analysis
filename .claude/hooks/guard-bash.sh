#!/usr/bin/env bash
# PreToolUse (Bash) : refuse quelques commandes destructrices.
# Filet de sécurité contre les erreurs, pas une protection contre un attaquant :
# les règles deny de settings.json restent la première barrière.

if ! command -v jq >/dev/null 2>&1; then
  echo "Bloqué : jq est introuvable, les garde-fous ne peuvent pas s'exécuter. Installe jq." >&2
  exit 2
fi

CMD=$(jq -r '.tool_input.command // empty')
DANGER='rm -rf (/|~)( |$)|git push (-f|--force)|git reset --hard|git clean|drop (table|database)'
DANGER+='|chmod -R 777|curl[^|]*\| *(ba)?sh|wget[^|]*\| *(ba)?sh'
DANGER+='|rm -rf? +(\./)?data(/|( |$))'     # data/ contient les vidéos tournées : irremplaçables

if printf '%s' "$CMD" | grep -Eiq "$DANGER"; then
  echo "Bloqué par guard-bash.sh : commande jugée dangereuse. Propose une alternative" \
       "sûre ou demande à l'utilisateur de la lancer lui-même." >&2
  exit 2
fi
exit 0
