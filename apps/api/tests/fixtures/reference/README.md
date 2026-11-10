# Vérité terrain — lecture seule pour l'agent

Ce dossier reçoit le repérage manuel des appuis (tâche 8 de la fiche) :
numéro d'image de chaque pose et de chaque lever du pied droit, cadence de capture,
source de la vidéo.

- C'est la référence de la validation (tâche 9) : seul l'étudiant la modifie.
- Le hook `protect-files.sh` bloque toute écriture de l'agent ici, pour qu'un test rouge
  ne soit jamais « réparé » en changeant la valeur attendue.
- Pas de vidéo dans git (vie privée) : uniquement les annotations.

Format suggéré (`<video>.json`) :

```json
{
  "video": "lancer-01",
  "source": "tournage du 2026-11-14, vue de côté",
  "capture_fps": 240,
  "right_foot": [{"touchdown": 412, "takeoff": 498}]
}
```
