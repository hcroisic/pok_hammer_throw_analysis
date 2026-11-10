# T01 — Commande `hammer info`
- Mode : PRODUIRE (premier cycle complet avec l'agent)
- Départ : `uv run python -m hammer` n'a aucune sous-commande.
- Action : `uv run python -m hammer info <video> [--capture-fps N]` lit la vidéo avec le `cv2`
  fourni par mediapipe (à ajouter avec la skill `add-dependency`).
- Résultat attendu : nombre d'images, cadence du fichier, durée du fichier ; avec `--capture-fps`,
  durée réelle = images / cadence de capture (règle R8).
- Vérification : test sur une courte vidéo synthétique générée par le test (aucune vraie vidéo) ;
  `make check` vert.
- Hors périmètre : détection de pose, API, front.
- Décisions :
