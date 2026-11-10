---
name: write-tests
description: Écrit ou complète des tests selon les conventions du projet (pytest pour apps/api, Vitest pour apps/front). Utiliser pour ajouter des tests, couvrir un cas limite ou reproduire un bug avant de le corriger.
---
# Conventions
- API : pytest, dans `apps/api/tests/` en miroir de `src/hammer/` ; nom `test_<comportement>_quand_<condition>`.
- Front : Vitest, fichier `X.test.ts(x)` à côté du module.
- Arrange / Act / Assert, un comportement par test.
- Pipeline : données synthétiques à réponse connue (cercle de 0,6 m à 2,5 tr/s, trou masqué de 50 ms…),
  tolérances explicites avec `pytest.approx` ; jamais de vraie vidéo dans un test unitaire.
- Une valeur attendue vient d'un calcul analytique écrit dans le test ou de l'étudiant,
  jamais d'une exécution du code testé.
- Ne jamais modifier `apps/api/tests/fixtures/reference/`.
- Couvrir : cas nominal, entrée vide ou trop courte, NaN, limites (trou de 100 ms pile, puis 101 ms), erreurs.

# Procédure
1. Lis le code à tester ET un test existant comme modèle.
2. Liste les cas à couvrir et montre la liste avant d'écrire.
3. Écris les tests, lance `make test-one F=...`, puis vérifie au moins une fois qu'un test
   échoue bien si on casse le code.
