# apps/front — interface

## Commandes (depuis la racine)
- Un test : `make test-one F=apps/front/src/lib/format.test.ts`

## Conventions
- Stack du cours Web : React + TypeScript + Vite ; Chakra UI v3, React Router et TanStack Query
  s'ajoutent au sprint 2 avec la skill `add-dependency`.
- Les types (`Analysis`, `Kpis`, `Series`) suivent le contrat JSON de `docs/cadrage.md` (§ 7.2) ;
  ne pas en inventer les champs.
- Données descendues par props depuis la page ; seul état local : l'instant de lecture vidéo.
- Statut d'analyse interrogé avec `refetchInterval`, arrêté à `done` ou `failed`.
- Tests : Vitest, fichier `X.test.ts(x)` à côté du module.
- Lint : oxlint (pas ESLint) ; format : Prettier, sans point-virgule.
