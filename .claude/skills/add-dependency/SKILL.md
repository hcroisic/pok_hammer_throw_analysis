---
name: add-dependency
description: Procédure sûre pour ajouter un paquet Python (uv add) ou npm. Utiliser AVANT toute installation de nouvelle dépendance.
---
Avant d'ajouter une dépendance :
1. Vérifie qu'on n'a pas déjà une dépendance ou du code qui fait la même chose
   (numpy, scipy et le `cv2` fourni par mediapipe couvrent beaucoup).
2. Vérifie que le paquet EXISTE sous ce nom exact sur le registre officiel (pypi.org, npmjs.com) :
   les noms inventés sont une cible d'attaque (slopsquatting).
3. Rapporte : dépôt source, mainteneur, date de la dernière version, téléchargements, licence,
   compatibilité avec Python 3.12 ou avec Vite 8 / React 19. Signale tout ce qui paraît suspect
   (nom proche d'un paquet connu, paquet très récent, peu téléchargé).
4. Propose la commande (`cd apps/api && uv add <paquet>` ou `cd apps/front && npm install <paquet>`)
   et ATTENDS mon accord.
5. Après installation : lockfile mis à jour (`uv.lock` ou `package-lock.json`), `make check` vert,
   et une phrase de justification dans le message de commit.
