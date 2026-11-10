# POK — Analyse vidéo du lancer de marteau

> Export Markdown de la fiche de cadrage, version du 6 novembre 2026, pour les agents. La fiche en ligne fait foi : réexporte ce fichier quand elle change.

Nov 6, 2026 · @hugo

## En bref

Le POK livre en 20 h une application web qui transforme la vidéo d'un lancer de marteau en métriques de technique, tour par tour. La priorité, fixée avec l'entraîneuse, est le moment où le pied droit se pose par rapport au point bas du marteau ; les images où l'athlète se masque lui-même sont comblées par des splines cubiques.

- **Entrée** : une vidéo au ralenti, à 120 ou 240 images/s, filmée sur trépied depuis l'extérieur de la cage, ou une vidéo trouvée en ligne dont la cadence de capture est connue.
- **Sortie** : par tour, l'avance du pied droit sur le point bas (ms), la durée des appuis et du tour (s), la vitesse des mains (m/s) et les pertes de rayon ; chaque point interpolé est signalé. Le X-factor devient une option exploratoire.
- **Rendu** : un exposé appuyé sur la démo de l'application, avec le dépôt lancé par `docker compose up`, 3 vrais lancers analysés, cette fiche et une mesure chiffrée de l'erreur d'interpolation.

| Cours | Notion mobilisée | Où elle apparaît dans le POK |
| --- | --- | --- |
| System design | Les 7 étapes, besoins chiffrés, MoSCoW, Given/When/Then | Plan de cette fiche (sections 1 à 9), entretien avec l'entraîneuse (section 12) |
| System design | File d'attente et worker (parties 5.3 et 6) | L'analyse tourne en arrière-plan ; l'API répond tout de suite |
| System design | Contrat REST, codes HTTP, base SQL, ADR | Ressource `/analyses`, SQLite, décisions tracées |
| System design | Vie privée (partie 7.7) | Inférence locale, suppression des vidéos |
| Web front | React, TypeScript, Vite, Chakra UI, React Router | Pages « Déposer » et « Analyse » |
| Web front | TanStack Query (état serveur) | Suivi du statut, cache des résultats |
| Web front | Critères avant le code, SDD, `AGENTS.md`, `prompts/` | Tests écrits avant chaque fonction de calcul |
| Hors cours (voir section 12) | Estimation de pose, méthodes numériques, détection d'événements | MediaPipe, `CubicSpline`, filtre de Savitzky-Golay |

## 1. Le problème reformulé

Un entraîneur de club n'a pas d'outil simple pour mesurer, à partir d'une vidéo de smartphone, ce qui se passe pendant les deux secondes des tours. L'étude de référence citée ici filme avec deux caméras synchronisées à 60 images/s et calibre l'espace avec un cadre de 28 points ([Frontiers, 2024](https://www.frontiersin.org/journals/bioengineering-and-biotechnology/articles/10.3389/fbioe.2024.1449465/full)).

**La question à laquelle l'app répond** : sur ce lancer, le pied droit s'est-il posé assez tôt avant le point bas du marteau, le lanceur a-t-il perdu du rayon, et chaque tour a-t-il été plus rapide que le précédent ? Ce sont les priorités de l'entraîneuse (section 12) : sa correction la plus fréquente est un pied droit posé trop tard, qui laisse le lanceur « derrière le marteau ».

**Pourquoi c'est difficile**

- Le lanceur enchaîne généralement 3 ou 4 tours ([Brian Mac](https://brianmac.co.uk/hammer/index.htm)) ; chez des lanceuses à environ 62 m, le 4e tour dure environ 0,49 s ([Frontiers, 2024](https://www.frontiersin.org/journals/bioengineering-and-biotechnology/articles/10.3389/fbioe.2024.1449465/full)).
- À chaque tour, le corps cache le bras ou la jambe opposés à la caméra : c'est l'occlusion que les splines doivent combler.
- Le geste est rapide : les finalistes des Mondiaux 2011 lâchaient le marteau à 27,9 m/s en moyenne chez les hommes ([Brian Mac](https://brianmac.co.uk/hammer/index.htm), d'après Isele et al., 2012).
- Les appuis se jouent à quelques millisecondes : à 240 images/s, une image dure environ 4 ms ; à 60 images/s, le repérage est trop grossier (entraîneuse).

**Hypothèses de travail**

- Une seule caméra fixe, à hauteur de hanche et à niveau, de côté et derrière le filet ; un seul athlète dans le champ.
- Lanceur droitier qui tourne vers la gauche (sens antihoraire vu de dessus) ; le sens est un paramètre.
- On mesure le corps, pas la boule du marteau, trop floue sur une vidéo grand public.

**Ce que l'app ne prétend pas faire** : remplacer une capture de mouvement de laboratoire. Ses valeurs se comparent d'un lancer à l'autre, filmés dans les mêmes conditions.

## 2. Besoins fonctionnels et non fonctionnels

Cinq besoins fonctionnels et neuf exigences chiffrées cadrent le MVP. Les seuils viennent de la simulation (section 5), de l'entraîneuse (section 12) ou seront mesurés au sprint 0.

**Fonctionnels : ce que l'app permet de faire**

1. Déposer la vidéo d'un lancer (MP4 ou MOV) et lancer son analyse.
2. Suivre l'avancement : en file, en cours, terminée ou en échec.
3. Consulter les métriques du lancer tour par tour : avance du pied droit, durées des appuis et du tour, vitesse des mains, rayon.
4. Revoir la vidéo avec le squelette superposé, points interpolés distingués.
5. Supprimer une analyse et sa vidéo.

**Non fonctionnels : dans quelles conditions ça doit marcher**

| Type | Exigence chiffrée | D'où vient le chiffre |
| --- | --- | --- |
| Qualité d'entrée | 120 à 240 images/s ; trépied à hauteur de hanche, sans suivre le mouvement ; mise au point et exposition verrouillées ; en journée. Sous 120 images/s, le timing des appuis est marqué « imprécis » | Entraîneuse : à 240 images/s, une image dure environ 4 ms, à 60 c'est trop grossier ; protocole de recherche à 60 images/s et 1/1600 s dans [Frontiers, 2024](https://www.frontiersin.org/journals/bioengineering-and-biotechnology/articles/10.3389/fbioe.2024.1449465/full) |
| Réactivité | `POST /analyses` répond en moins de 2 s après la fin de l'envoi | Cours de System design, duel 3 : ne pas bloquer une requête |
| Temps de traitement | p95 ≤ 3 × la durée de la vidéo sur un portable sans GPU | Cible à confirmer au sprint 0 |
| Qualité des données | Aucun trou de plus de 100 ms interpolé ; 100 % des points interpolés signalés | Section 5 |
| Exactitude des calculs | Vitesse à ± 1 %, avance du pied droit à ± 1 image, rayon à ± 1 cm sur trajectoires synthétiques | Tests unitaires (section 8) |
| Capacité | Vidéo ≤ 30 s réelles et ≤ 300 Mo ; une analyse à la fois | Usage d'un club : un lancer, moulinets compris, tient en quelques secondes |
| Vie privée | Aucune image envoyée à un service tiers ; suppression complète en une action | Cours de System design, partie 7.7 |
| Portabilité | `docker compose up` démarre l'ensemble en moins de 5 min sur une machine neuve | Cours Web front, jour 1 |
| Précision du timing | ± 2 images entre appuis détectés et repérés à la main, soit ± 8 ms à 240 images/s | Validation du sprint 1 (tâches 8 et 9) |

## 3. Périmètre du MVP (MoSCoW)

Le MVP tient en 5 « Must » : déposer, extraire la pose, interpoler, repérer les appuis et calculer, afficher. Le quota de 5 suit le conseil du cours ; les « Should » entrent dans les 3 h restantes, dans l'ordre du tableau. Après l'entretien avec l'entraîneuse, le timing du pied droit passe devant le X-factor.

| # | Fonctionnalité | Priorité | Sprint | Effort estimé |
| --- | --- | --- | --- | --- |
| M1 | Dépôt de vidéo avec cadence de capture déclarée, analyse asynchrone (API, statut) | Must | 2 | 2,5 h |
| M2 | Pose 3D image par image et détection des occlusions | Must | 1 | 2 h |
| M3 | Interpolation par spline cubique des trous ≤ 100 ms, points marqués | Must | 1 | 1 h |
| M4 | Poses et levers du pied droit, points bas des mains, métriques par tour | Must | 1 | 2,5 h |
| M5 | Page de résultats : tableau par tour et courbes, zones interpolées visibles | Must | 2 | 3 h |
| S1 | Correction des inversions gauche/droite, pour suivre le bon pied | Should | 1 | 1 h |
| S2 | Vidéo avec squelette, poses du pied et points bas repérés | Should | 2 | 1,5 h |
| S3 | Suppression d'une analyse et de sa vidéo | Should | 2 | 0,5 h |
| C1 | X-factor exploratoire (« devancer le marteau »), peu fiable avec une seule caméra | Could | — | — |
| C2 | Vitesse estimée de la boule : vitesse de rotation × rayon estimé | Could | — | — |
| C3 | Détection de la boule du marteau, plausible à 240 images/s en pleine lumière | Could | — | — |
| C4 | Mesures 2D absolues, calibrées sur le diamètre du cercle (2,135 m) | Could | — | — |
| C5 | Liste des analyses, comparaison de deux lancers, export CSV | Could | — | — |
| W1 | Comptes et authentification : usage local, un seul utilisateur | Won't | — | — |
| W2 | Déploiement dans le cloud | Won't | — | — |
| W3 | Analyse en temps réel depuis la caméra | Won't | — | — |
| W4 | Prédiction de la distance du lancer | Won't | — | — |

S1 peut remonter en Must si le spike du sprint 0 montre des inversions gauche/droite : sans elle, l'app suivrait le mauvais pied.

## 4. Use cases, règles et critères d'acceptance

Cinq use cases portent le MVP ; chaque critère d'acceptance renvoie à une règle écrite. C'est le principe du cours : la spécification est la règle, le critère est la preuve.

**Use cases (user stories)**

1. **UC1** — En tant qu'entraîneur, je dépose la vidéo d'un lancer afin d'obtenir ses métriques sans rien installer.
2. **UC2** — En tant qu'entraîneur, je suis l'avancement de l'analyse afin de savoir quand revenir.
3. **UC3** — En tant qu'athlète, je vois tour par tour quand mon pied droit se pose par rapport au point bas, et si chaque tour va plus vite, afin de savoir si je reste devant le marteau.
4. **UC4** — En tant qu'entraîneur, je revois la vidéo avec le squelette afin de vérifier que la mesure suit bien l'athlète.
5. **UC5** — En tant qu'athlète, je supprime une analyse afin que ma vidéo ne soit plus conservée.

**Règles du système (spécifications)**

- **R1** — Un point interpolé est toujours signalé comme tel, dans l'API (`interpolated: true`) comme à l'écran.
- **R2** — Aucun trou de plus de 100 ms n'est interpolé ; ses images sont « non fiables » et exclues des métriques.
- **R3** — Une métrique calculée sur moins de 80 % d'images fiables porte la mention « faible confiance ».
- **R4** — Une analyse a un seul statut à la fois : `queued`, puis `processing`, puis `done` ou `failed`, sans retour en arrière.
- **R5** — Toute valeur affichée porte son unité (ms, s, m/s, m, °).
- **R6** — Supprimer une analyse supprime la vidéo et toutes les données dérivées.
- **R7** — Seules les vidéos MP4 ou MOV de 300 Mo au plus, couvrant 30 s réelles au plus, sont acceptées.
- **R8** — La cadence de capture déclarée à l'envoi prime sur celle du fichier : un ralenti à 240 images/s exporté à 30 images/s dure 8 fois trop longtemps.
- **R9** — Un instant d'appui est affiché avec sa précision, ± 1 image ; sous 120 images/s, il porte la mention « imprécis ».

R7 est née du détecteur de trou du cours : le critère CA2 ne se rattachait à aucune règle.

**Critères d'acceptance (Given / When / Then)**

| CA | UC | Règle | Given | When | Then |
| --- | --- | --- | --- | --- | --- |
| CA1 | UC1 | R4 | l'API démarrée | je dépose une vidéo MP4 de 8 s à 120 images/s | je reçois `202` et un identifiant en moins de 2 s après l'envoi ; la page affiche « En file » |
| CA2 | UC1 | R7 | aucune analyse en cours | je dépose un fichier `.txt` | l'API répond `415`, l'écran affiche « Format non supporté (MP4 ou MOV) » et aucune analyse n'est créée |
| CA3 | UC2 | R4 | une analyse au statut `processing` | le traitement se termine | la page passe à « Terminée » sans rechargement, en moins de 2 s, et le suivi s'arrête |
| CA4 | UC3 | R1, R2 | une vidéo à 120 images/s où le poignet droit est masqué 6 images (50 ms) | l'analyse se termine | ces 6 images sont interpolées, hachurées sur la courbe et marquées `interpolated: true` |
| CA5 | UC3 | R2, R3 | un masquage de 40 images (333 ms) | l'analyse se termine | la courbe est interrompue, aucune valeur n'est inventée et le tour concerné porte « faible confiance » |
| CA6 | UC4 | R1 | une analyse terminée | je lis la vidéo | le squelette suit l'athlète avec au plus 1 image de décalage ; les points interpolés sont en orange |
| CA7 | UC5 | R6 | une analyse terminée | je la supprime | `GET /analyses/{id}` répond `404` et le fichier vidéo n'existe plus |
| CA8 | UC3 | Exactitude | un poignet synthétique sur un cercle de 0,60 m à 2 tr/s, échantillonné à 120 images/s | on calcule sa vitesse | on obtient 7,54 m/s à ± 1 % |
| CA9 | UC3 | Exactitude | un pied droit synthétique posé 40 ms avant le point bas des mains, à 240 images/s | on calcule l'avance du pied droit | on obtient 40 ms à ± 1 image, soit ± 4 ms |
| CA10 | UC1 | R8 | un ralenti à 240 images/s exporté à 30 images/s | je le dépose en déclarant 240 images/s | les durées de tour sont en secondes réelles, de l'ordre de 0,5 s et non de 4 s |

CA8 et CA9 ne sont ni des règles ni des scénarios d'usage : ce sont des exigences non fonctionnelles habillées d'un scénario pour être testables.

## 5. Pipeline d'analyse

Six étapes transforment la vidéo en métriques. La simulation ci-dessous montre qu'une spline cubique comble un trou de 100 ms avec environ 1 cm d'erreur, contre près de 18 cm en interpolation linéaire.

1. **Décoder** la vidéo (OpenCV) : cadence réelle et horodatage de chaque image.
2. **Estimer la pose** avec MediaPipe Pose Landmarker (modèle Heavy, mode `VIDEO`, une personne). Il renvoie 33 points par image : coordonnées image pour le squelette, coordonnées monde en mètres centrées sur le milieu des hanches, et une `visibility` ([MediaPipe](https://developers.google.com/edge/mediapipe/solutions/vision/pose_landmarker/web_js)).
3. **Marquer les points manquants** : visibilité inférieure à 0,5, ou saut impossible (plus de 20 m/s implicites d'une image à l'autre). Si échanger les côtés gauche et droit rapproche nettement la pose de la précédente, on les échange.
4. **Combler les trous courts** : pour chaque coordonnée, `CubicSpline` (SciPy, conditions « not-a-knot ») ajustée sur les images fiables et évaluée dans les trous de 100 ms au plus. La durée d'un trou va de la dernière image fiable avant à la première après ; au-delà, les images restent vides et « non fiables ».
5. **Lisser et dériver** : filtre de Savitzky-Golay (fenêtre d'environ 0,1 s, ordre 3), qui fournit aussi la dérivée. Sans lissage, 1 cm de bruit par axe fausse la vitesse de 1,7 m/s à 240 images/s ; filtrée, l'erreur tombe à 0,17 m/s (simulation).
6. **Repérer les événements et agréger** : points bas des mains, qui ouvrent chaque tour, poses et levers du pied droit, puis métriques par tour (section 6) avec leur taux d'images fiables.

[Figure de la fiche en ligne : Simulation sim\_spline.py · 120 images/s · trous de 1 à 23 images · moyenne sur 80 positions par point]

**Lecture**

- L'erreur dépend de l'angle balayé pendant le trou, pas du nombre d'images : 90° de rotation donnent environ 1 cm à 30 comme à 240 images/s.
- La cadence compte ailleurs : moins de flou, plus de points par tour (15 images au 4e tour à 30 images/s, 58 à 120) et des trous plus courts, car chaque image perdue coûte 33 ms à 30 images/s. Elle fixe surtout la précision des appuis : ± 4 ms à 240 images/s.
- PCHIP aplatit les extremums, car il est conçu pour préserver la monotonie : 9 fois plus d'erreur que la spline à 100 ms. Il est écarté.
- La doc SciPy le rappelle : un cercle ne peut pas être représenté exactement par une spline cubique ([SciPy](https://docs.scipy.org/doc/scipy-1.9.1/reference/generated/scipy.interpolate.CubicSpline.html)). D'où le plafond de 100 ms, soit environ un quart de tour.

**Hypothèses de la simulation** : poignet sur un cercle de 0,60 m autour du bassin, plan incliné de 35°, 2,5 tr/s, sans bruit. C'est un cas favorable : sur de vraies vidéos, l'erreur sera plus grande.

**Validation sur vraies vidéos (sprint 1)** : sur des passages bien suivis (visibilité > 0,9), effacer artificiellement des trous de 20 à 200 ms, interpoler, puis comparer à la position d'origine. La courbe obtenue fixe le seuil final, aujourd'hui 100 ms. Les poses du pied droit sont comparées de même à un repérage manuel, image par image, sur une vidéo.

## 6. Les métriques, dans l'ordre de l'entraîneuse

D'abord le timing du pied droit, puis la vitesse de chaque tour, puis le rayon. Les métriques de temps ne dépendent ni de l'échelle ni de la profondeur : ce sont les plus fiables avec une seule caméra.

**Notations.** Pₖ(t) est la position du point k : 11 et 12 pour les épaules, 15 et 16 pour les poignets, 23 et 24 pour les hanches, 28, 30 et 32 pour la cheville, le talon et la pointe du pied droit, 27, 29 et 31 pour le pied gauche ([MediaPipe](https://developers.google.com/edge/mediapipe/solutions/vision/pose_landmarker/index)). Les longueurs utilisent les coordonnées monde, en mètres ; les appuis, les coordonnées image. Les deux mains tenant la même poignée, on suit leur milieu Pₘ ; si un poignet est masqué, l'autre le remplace avec l'écart moyen observé.

### 6.1 Avance du pied droit sur le point bas

```latex
\Delta_k = t_{\mathrm{PB},k} - t_{\mathrm{PD},k} \quad [\mathrm{ms}], \qquad \varphi_k = 360^\circ \times \frac{\Delta_k}{T_k}
```

- t\_PD,k est l'instant où le pied droit se pose au tour k, t\_PB,k celui du point bas des mains le plus proche, T\_k la durée du tour.
- Δ\_k positif : le pied se pose avant le point bas. Plus Δ\_k est petit, plus le pied est tard ; c'est le « derrière le marteau » de l'entraîneuse.
- φ\_k donne la même avance en degrés de rotation du marteau, comparable d'un tour à l'autre même quand les tours accélèrent.
- Détection de la pose : hauteur du talon et de la pointe droits, en coordonnées image, au-dessus du pied gauche qui reste au sol. Le pied est posé quand il redescend sous un seuil et que sa vitesse verticale s'annule ; un double seuil évite les rebonds.
- Précision : ± 1 image, soit ± 4 ms à 240 images/s. C'est la raison des 120 à 240 images/s demandées par l'entraîneuse.
- Littérature : chez des lanceuses, les lancers les plus longs montrent un azimut horizontal du marteau plus faible au poser du pied droit, et l'article recommande de poser ce pied plus tôt ([Frontiers, 2024](https://www.frontiersin.org/journals/bioengineering-and-biotechnology/articles/10.3389/fbioe.2024.1449465/full)).
- Valeur cible : à fixer avec l'entraîneuse, sur des lancers qu'elle juge réussis.

### 6.2 Durées des appuis et des tours

- Appui simple : du lever à la pose du pied droit. Double appui : de la pose au lever suivant. Tour : d'un point bas des mains au suivant.
- Lecture : chaque tour doit être plus court que le précédent, et c'est en double appui que la boule accélère (entraîneuse).
- Repères : chez des lanceuses à environ 62 m, l'appui simple passe de 0,31 s au 1er tour à 0,23 s au 4e, le double appui de 0,34 s à environ 0,25 s ([Frontiers, 2024](https://www.frontiersin.org/journals/bioengineering-and-biotechnology/articles/10.3389/fbioe.2024.1449465/full)).
- La durée du double appui est aussi le chiffre de secours de l'entraîneuse si la vitesse de la boule est trop dure à mesurer.

### 6.3 Vitesse des mains

```latex
v(t) = \left\lVert \frac{d\,\mathbf{P}_m}{dt}(t) \right\rVert \quad [\mathrm{m/s}]
```

- La dérivée vient du filtre de Savitzky-Golay (étape 5). C'est une vitesse relative au bassin : elle mesure la rotation des bras autour du corps.
- Synthèse : maximum de chaque tour, qui doit croître d'un tour à l'autre.
- Le chiffre préféré de l'entraîneuse est la vitesse de la boule en fin de tour ; elle part à 27–28 m/s chez les finalistes mondiaux ([Brian Mac](https://brianmac.co.uk/hammer/index.htm)). La suivre demande l'option C3, l'estimer l'option C2.
- Ordre de grandeur attendu pour les mains : environ 9 m/s avec les hypothèses de la simulation.

### 6.4 Rayon de giration et pertes de rayon

```latex
R_{\mathrm{bras}}(t) = \left\lVert \mathbf{P}_m(t) - \tfrac{1}{2}\big(\mathbf{P}_{11}(t)+\mathbf{P}_{12}(t)\big) \right\rVert, \qquad R_{\mathrm{marteau}} \approx R_{\mathrm{bras}} + L
```

- Pour l'entraîneuse, le rayon va de l'axe de rotation à la boule : bras, épaules et câble compris. La littérature le mesure du centre de la boule au milieu des épaules, de 1,71 à 1,80 m chez des lanceuses à environ 62 m ([Frontiers, 2024](https://www.frontiersin.org/journals/bioengineering-and-biotechnology/articles/10.3389/fbioe.2024.1449465/full)).
- L'app voit la partie bras, R\_bras. Le rayon complet s'estime en ajoutant la longueur du marteau L, au plus 1,215 m chez les hommes, si bras et câble restent alignés.
- Une perte de rayon, c'est R\_bras qui baisse dans le tour : les bras plient ou tirent, la boule tourne sur un cercle plus petit, donc moins vite (v = ωr). Le seuil d'alerte, en centimètres, se fixe avec l'entraîneuse.
- Synthèse : moyenne par tour et plus forte perte, avec l'instant où elle survient.

### 6.5 Devancer le marteau (X-factor, option exploratoire)

```latex
\theta_e = \operatorname{atan2}\big(\pi(\mathbf{P}_{12}-\mathbf{P}_{11})\big), \qquad \theta_h = \operatorname{atan2}\big(\pi(\mathbf{P}_{24}-\mathbf{P}_{23})\big), \qquad X = \operatorname{wrap}_{]-180^\circ,\,180^\circ]}\big(s\,(\theta_h-\theta_e)\big)
```

- π projette sur le plan horizontal, soit le plan (x, z) si la caméra est à niveau, ce que le sprint 0 vérifie sur une image où l'athlète se tient debout. s vaut +1 ou −1 selon le sens de rotation : X est positif quand les hanches devancent les épaules.
- Au marteau, on ne dit pas « X-factor » mais « devancer le marteau » : le bas du corps tourne en avance sur le haut et sur le marteau (entraîneuse). Le terme vient du golf (McLean, 1992), où l'on projette la ligne des hanches et celle des épaules sur le plan transversal ([Joyce et al., 2010](https://people.stfx.ca/smackenz/Courses/DirectedStudy/Articles/Joyce%202010%20Methodological%20considerations%20for%20the%203D%20measurement%20of%20the%20X-factor.pdf)).
- L'entraîneuse prévient : cet angle est peu fiable avec une seule caméra sur un mouvement en rotation, et le timing du pied droit en dit l'essentiel. Il reste donc une option (C1), affichée « exploratoire ».

### 6.6 Découpage en tours

- Les mains passent par un point bas une fois par cycle : chaque minimum de leur hauteur ouvre un cycle, avec au moins 0,3 s entre deux minimums. Mains, câble et boule restant alignés, ce point bas sert de point bas du marteau.
- Un cycle est un moulinet si la ligne des hanches y tourne de moins de 180°, un tour sinon.
- Les durées de tour se comparent aux 0,49 à 0,65 s obtenus en sommant les phases d'appui publiées chez des lanceuses ([Frontiers, 2024](https://www.frontiersin.org/journals/bioengineering-and-biotechnology/articles/10.3389/fbioe.2024.1449465/full)).

## 7. Architecture

Un monolithe modulaire suffit : une SPA React appelle une API FastAPI, qui confie l'analyse à une tâche de fond. Les métadonnées vont en SQLite, les séries en fichiers JSON.

[Figure de la fiche en ligne : Architecture du MVP · 2 services Docker, 1 volume]

Le navigateur n'attend jamais le calcul : il dépose la vidéo, reçoit `202`, puis interroge le statut jusqu'à `done`.

### 7.1 Décisions d'architecture (ADR)

| Décision | Choix | Alternative écartée | Pourquoi |
| --- | --- | --- | --- |
| Estimation de pose | MediaPipe Pose Landmarker, modèle Heavy | YOLO-pose ou RTMPose, en 2D | Le rayon a besoin de coordonnées 3D en mètres, les appuis des coordonnées image : MediaPipe fournit les deux, en local sur CPU |
| Traitement | Asynchrone : statut en base, tâche de fond | Requête bloquante | Une analyse dure des dizaines de secondes ; une requête qui attend occupe une place serveur (duel 3 du cours) |
| File d'attente | `BackgroundTasks` de FastAPI | Celery et Redis | Une analyse à la fois : un broker serait de la sur-ingénierie, comme l'exemple Redis du cours Web (jour 2) |
| Découpage | Monolithe modulaire : `pipeline/` et `api/` séparés | Microservices | Une personne, un utilisateur ; le cours conseille de commencer simple |
| Stockage | SQLite et fichiers JSON | PostgreSQL, MongoDB | Rien à administrer ; les séries se lisent en bloc et ne sont jamais filtrées |
| Suivi côté front | Interrogation chaque seconde (`refetchInterval`) | WebSocket, SSE | Natif dans TanStack Query et suffisant pour un utilisateur |

Limite assumée : une tâche de fond meurt avec le serveur. Au démarrage, toute analyse restée `processing` passe donc en `failed`, avec un message explicite.

### 7.2 Contrat d'API

| Méthode | Route | Entrée | Réponse | Codes |
| --- | --- | --- | --- | --- |
| POST | `/analyses` | multipart : `video`, `captureFps` (cadence réelle, par exemple 240), `handedness` (`right` par défaut) | `{id, status: "queued"}` et en-tête `Location` | 202, 400, 413, 415 |
| GET | `/analyses` | `?limit=20` | `[{id, status, createdAt, durationS}]`, plus récentes d'abord | 200 |
| GET | `/analyses/{id}` | — | statut, avancement, vidéo, synthèse, qualité | 200, 404 |
| GET | `/analyses/{id}/series` | — | `{t, handsSpeed, radius, rightFootHeight, events, interpolated, reliable}`, où `events` liste points bas, poses et levers du pied droit | 200, 404, 409 |
| GET | `/analyses/{id}/landmarks` | — | points image par image, pour le squelette | 200, 404, 409 |
| GET | `/analyses/{id}/video` | en-tête `Range` | flux vidéo | 200, 206, 404 |
| DELETE | `/analyses/{id}` | — | — | 204, 404 |

- **202 plutôt que 201** : le traitement est accepté, pas terminé.
- **409** : les séries sont demandées avant la fin, ce qui entre en conflit avec l'état actuel, au sens du cours.
- **413 et 415** : fichier trop lourd ou format non supporté (règle R7).

Réponse de `GET /analyses/{id}`, avec des valeurs d'exemple :

```json
{
  "id": "0193f2c4-7b1e-7c3a-9d2e-5f8a1b2c3d4e",
  "status": "done",
  "progress": 1.0,
  "video": { "captureFps": 240, "fileFps": 30, "frames": 1920, "durationS": 8.0 },
  "kpis": {
    "turns": 4,
    "turnDurationsS": [0.62, 0.55, 0.51, 0.48],
    "rightFootLeadMs": [96, 88, 71, 54],
    "doubleSupportS": [0.33, 0.27, 0.25, 0.25],
    "handsSpeedMaxMs": [6.1, 7.2, 8.0, 8.6],
    "radiusLossMaxCm": [3, 4, 7, 9]
  },
  "quality": { "reliableRatio": 0.93, "interpolatedRatio": 0.05, "longestGapMs": 83, "timingPrecisionMs": 4, "confidence": "high" },
  "error": null
}
```

Les types TypeScript du front (`Analysis`, `Kpis`, `Series`) se déduisent de ce JSON, comme `BoardData` au sprint 1 du cours Web.

### 7.3 Modèle de données

```text
ANALYSES {
  id           TEXT      PK      -- UUID v7, généré par l'API
  status       TEXT              -- queued | processing | done | failed
  created_at   DATETIME  INDEX   -- liste triée par date
  started_at   DATETIME
  finished_at  DATETIME
  video_path   TEXT              -- data/{id}/video.mp4, jamais le nom envoyé
  capture_fps  REAL              -- déclarée à l'envoi, prime sur file_fps (R8)
  file_fps     REAL              -- lue dans le fichier
  frames       INTEGER
  handedness   TEXT              -- right | left
  params       JSON              -- seuils de visibilité, de trou et d'appui, fenêtre de lissage
  kpis         JSON
  quality      JSON
  error        TEXT
}
```

Les séries vivent dans `data/{id}/landmarks.json` et `data/{id}/series.json`. Un seul index, sur `created_at`, car la liste est la seule requête filtrée : le cours rappelle qu'un index ralentit l'écriture.

### 7.4 Front : routes, composants et données

| Route | Page | Composants | Données (TanStack Query) |
| --- | --- | --- | --- |
| `/` | Déposer | `UploadForm` : fichier, cadence de capture, main forte | `useCreateAnalysis` : `useMutation` sur `POST /analyses`, puis navigation vers `/analyses/:id` |
| `/analyses/:id` | Analyse | `StatusBanner`, `TurnTable`, `MetricChart` × 3, `VideoOverlay` | `useAnalysis` : `useQuery` interrogé chaque seconde tant que le statut n'est pas final ; `useSeries` et `useLandmarks` une fois `done` |
| `/analyses` | Historique (Could) | `AnalysisList` | `useAnalyses` ; suppression par `useMutation`, puis invalidation de la liste |
| `*` | Introuvable | — | — |

Comme au sprint 1 du cours Web, les données descendent de la page vers les composants par props. Le seul état local est l'instant de lecture de la vidéo (`useState`), partagé entre `VideoOverlay` et les courbes pour surligner l'image courante (S2).

## 8. Tests, vie privée et exploitation

Les tests de calcul sont écrits avant le code, la vidéo ne quitte jamais la machine, et chaque analyse laisse une trace chiffrée dans les logs.

**Tests automatisés (pytest), écrits avant chaque fonction**

| Test | Donnée d'entrée | Résultat attendu |
| --- | --- | --- |
| Spline exacte | Polynôme de degré 3 avec un trou de 10 images | Erreur < 10⁻⁹ : les conditions « not-a-knot » reproduisent un polynôme de degré 3 |
| Trou trop long | Trou de 150 ms | Images vides, `reliable: false`, aucune valeur inventée |
| Vitesse | Cercle de 0,60 m à 2 tr/s, 120 images/s | 7,54 m/s à ± 1 % (CA8) |
| Avance du pied droit | Pied droit synthétique posé 40 ms avant le point bas, 240 images/s | 40 ms à ± 4 ms (CA9) |
| Rayon | Mains à 0,60 m du milieu des épaules | 0,60 m à ± 1 cm |
| Inversion gauche/droite | Côtés échangés sur 3 images | Séquence corrigée |
| Découpage | 2 moulinets puis 4 tours | 2 moulinets et 4 tours détectés |
| Erreurs d'API | Fichier absent, `.txt`, id inconnu, séries avant la fin | 400, 415, 404, 409 |
| Bout en bout | Vraie vidéo de 2 s | Statut `done`, synthèse présente |
| Cadence de capture | Ralenti à 240 images/s stocké à 30 images/s | Durées en secondes réelles (CA10) |

Pendant le cadrage, trois calculs ont été vérifiés en Python : la spline (erreur de 10⁻¹⁶ sur le polynôme), la vitesse (0,04 %) et le X-factor de l'option C1 (30,0° sur 4 tours). Côté front, les critères Given/When/Then se vérifient dans le navigateur ; Vitest peut couvrir l'arrêt du suivi au statut `done`.

**Vie privée (partie 7.7 du cours)**

- Une vidéo identifie une personne : consentement écrit de l'athlète filmé, et de ses parents s'il est mineur.
- MediaPipe tourne sur la machine : aucune image ne part vers un service tiers.
- On ne stocke que la vidéo et ses séries ; aucun nom n'est demandé.
- `DELETE /analyses/{id}` efface tout, vidéo comprise (règle R6).
- Les vidéos trouvées en ligne servent à développer et tester, sans être republiées, avec leur source notée. Pour l'exposé, mieux vaut des vidéos du club, avec consentement.

**Sécurité, même en local**

- Taille contrôlée à l'envoi (413) ; type contrôlé, puis lecture d'essai par OpenCV avant traitement (415).
- Fichier enregistré sous un nom généré, jamais sous le nom envoyé, pour éviter les chemins piégés.
- CORS limité à l'origine du front.

**Observabilité** : un log JSON par étape et par analyse, avec l'id, la durée de l'étape, la part d'images fiables, le nombre de trous et le plus long. Ces lignes alimentent les KPI techniques de la section 9.

**Docker Compose** : deux services, `api` (Python, MediaPipe) et `front` (Vite), plus un volume `data/`. Vérifier au sprint 0 que le paquet `mediapipe` s'installe dans l'image, surtout sur puce ARM ; sinon, lancer l'API dans un environnement virtuel.

**Développement avec l'IA (cours Web, jour 3)**

- `AGENTS.md` fixe trois règles : tests avant le code, aucune dépendance nouvelle sans justification, prompts de départ rangés dans `prompts/`.
- Chaque fonction de calcul part d'une mini-spec (entrée, sortie, cas d'échec, test) avant toute génération.
- Micro-prompts et relecture du diff après chaque pas ; toute proposition de Redis, de Celery ou de base NoSQL est refusée (section 7.1).

## 9. KPI du POK

Sept KPI disent si le POK a réussi ; chacun a une cible et une action prévue s'il se dégrade, sans quoi il ne serait pas actionnable. Avance du pied droit, durées, vitesse et rayon sont la sortie de l'app pour l'athlète ; ces KPI mesurent l'app elle-même.

| Famille | KPI | Cible | Si le chiffre se dégrade |
| --- | --- | --- | --- |
| Produit | Analyses abouties sur les lancers filmés selon le protocole | ≥ 9 sur 10 | Revoir le protocole de tournage (angle, distance, cadence) avant de toucher au code |
| Produit | Part d'images fiables par lancer, ni interpolées ni exclues | ≥ 85 % | Passer à 120 images/s ou changer l'angle de la caméra |
| Produit | L'entraîneuse et deux athlètes retrouvent seuls le tour où le pied droit se pose trop tard | 3 testeurs sur 3, sans aide | Annoter les courbes par tour, simplifier la page |
| Technique | Temps de traitement, p95 | ≤ 3 × la durée de la vidéo | Réduire l'entrée à 720p, passer au modèle Full |
| Technique | Erreur d'interpolation médiane (masquage artificiel, trous ≤ 100 ms) | ≤ 2 cm | Baisser le seuil de trou maximal |
| Technique | Temps de réponse de `POST /analyses`, hors envoi | < 2 s | Vérifier que rien de lourd ne tourne dans la requête |
| Technique | Écart entre poses du pied détectées et repérées à la main | ≤ 2 images, soit 8 ms à 240 images/s | Revoir les seuils de détection, ou filmer de côté |

## 10. Planning des 20 h

Les 20 h tiennent en quatre blocs, avec un go/no-go à la 3e heure : si MediaPipe ne suit pas l'athlète, on bascule sur le plan B avant d'écrire l'application.

| # | Bloc | Tâche | Estimé (h) | Réel (h) | Statut |
| --- | --- | --- | --- | --- | --- |
| 1 | Sprint 0 — Démarrage | Dépôt, squelettes API et front, Docker Compose, `AGENTS.md` | 0,5 |  | À faire |
| 2 | Sprint 0 — Démarrage | Filmer 3 lancers avec l'entraîneuse en journée, à 120-240 images/s, de côté ; sinon trouver des vidéos en ligne à cadence connue | 1 |  | À faire |
| 3 | Sprint 0 — Démarrage | Spike MediaPipe : part d'images visibles à travers le filet, pieds compris, temps de traitement, inversions ; go/no-go | 1 |  | À faire |
| 4 | Sprint 1 — Pipeline | Pose 3D et détection des occlusions (M2) | 2 |  | À faire |
| 5 | Sprint 1 — Pipeline | Correction des inversions gauche/droite (S1) | 1 |  | À faire |
| 6 | Sprint 1 — Pipeline | Interpolation par spline et marquage (M3) | 1 |  | À faire |
| 7 | Sprint 1 — Pipeline | Poses et levers du pied droit, points bas, métriques par tour (M4) | 2,5 |  | À faire |
| 8 | Sprint 1 — Pipeline | Repérage manuel des appuis sur une vidéo, image par image | 0,5 |  | À faire |
| 9 | Sprint 1 — Pipeline | Validation : masquage artificiel, écart au repérage manuel, seuils finaux | 1 |  | À faire |
| 10 | Sprint 2 — Application | API, tâche de fond, SQLite, cadence de capture, codes d'erreur (M1) | 2,5 |  | À faire |
| 11 | Sprint 2 — Application | Page de résultats : tableau par tour et courbes (M5) | 3 |  | À faire |
| 12 | Sprint 2 — Application | Vidéo avec squelette, poses du pied et points bas (S2) | 1,5 |  | À faire |
| 13 | Sprint 2 — Application | Suppression d'une analyse (S3) | 0,5 |  | À faire |
| 14 | Clôture | Recette des 10 critères d'acceptance | 0,5 |  | À faire |
| 15 | Clôture | Exposé : support, démo en direct et vidéo de secours | 1 |  | À faire |
| 16 | Clôture | Rétrospective et README | 0,5 |  | À faire |

Total : 2,5 h de démarrage, 8 h de pipeline, 7,5 h d'application et 2 h de clôture, soit 20 h.

- **Jalon 1, fin du sprint 1** : `python -m hammer analyze lancer.mp4` produit la synthèse en JSON et les courbes. Le parcours Do-IT prévoit 3 ou 4 jalons par temps pour présenter ses POK à la promotion ([syllabus](https://syllabus.centrale-med.fr/plugins/odf-web/odf/_content/course-parcours-do-it-developpement-et-organisation-en-it-2-fr-fr-fr/Parcours%20DO-IT%20_%20D%C3%A9veloppement%20et%20Organisation%20en%20IT.pdf)).
- **Jalon 2, fin du sprint 2** : démo de bout en bout dans le navigateur.
- **Git** : une branche par sprint (`nom/sprint0`, `nom/sprint1`…), comme dans le cours Web, et un commit par tâche.
- **Si le temps manque** : couper S3, puis S2. La validation (tâches 8 et 9) ne se coupe pas : c'est elle qui prouve l'interpolation et le timing.

## 11. Risques et plans B

Le risque principal est la qualité de la pose sur un athlète qui tourne vite. Il est testé dès la 3e heure, avant toute ligne d'application. Le second est matériel : il faut une caméra à 120-240 images/s.

| Risque | Signal d'alerte | Plan B |
| --- | --- | --- |
| Pas de caméra à 120-240 images/s sous la main | Matériel | Mode ralenti d'un téléphone récent, le tien ou celui d'un coéquipier ; sinon des vidéos en ligne dont la cadence de capture est indiquée |
| Ralenti exporté à 30 images/s | Durées de tour de plusieurs secondes | Cadence de capture déclarée à l'envoi (règle R8) |
| MediaPipe perd l'athlète ou inverse gauche et droite à chaque tour | Spike : moins de 70 % d'images visibles sur poignets, épaules, hanches et pieds | Correction par continuité (S1), puis un autre angle ; en dernier recours, un modèle 2D (YOLO-pose, RTMPose), le timing des appuis restant mesurable |
| Filet devant l'objectif | Visibilité basse, squelette instable | Mise au point verrouillée sur l'athlète ; comparer vue de côté et vue de derrière au spike |
| Lumière : nuit vers 17 h en novembre | Ralenti sombre et bruité | Filmer en journée, en pleine lumière |
| Flou de bougé | Visibilité basse sur les poignets aux vitesses élevées | Ralenti à 240 images/s, obturation rapide |
| Vidéos sous 120 images/s | Cadence de capture déclarée | Accepter, timing marqué « imprécis » (règle R9) |
| Traitement trop long | p95 supérieur à 3 × la durée de la vidéo | Entrée en 720p, modèle Full |
| Paquet `mediapipe` indisponible pour l'architecture de l'image Docker | Échec du build | API dans un environnement virtuel, front seul dans Docker |
| Plusieurs personnes dans le champ | Le squelette saute d'une personne à l'autre | Recadrer sur le cercle avant l'inférence |
| Dépassement des 20 h | Plus de 2 h de retard à la fin du sprint 1 | Couper S3, puis S2 |

**Sécurité pendant le tournage** : filmer depuis l'extérieur de la cage, derrière le filet et à 2 ou 3 m de lui, car il se déforme à l'impact ; jamais dans le secteur de chute ni face à l'ouverture de la cage (entraîneuse).

## 12. Questions et réponses

L'entraîneuse a répondu à cinq questions sur six, et ses réponses ont réordonné les métriques. Restent sa disponibilité pour tester l'app et le périmètre à valider avec le tuteur.

**Entretien avec l'entraîneuse, 6 novembre 2026**

| Question | Sa réponse | Ce que ça change dans la fiche |
| --- | --- | --- |
| Ce qu'elle corrige le plus souvent | Elle lit le lancer dans l'ordre : moulinets, entrée, double appui, final. La correction la plus fréquente : le pied droit posé trop tard par rapport au point bas, qui met le lanceur « derrière le marteau » | Nouvelle métrique prioritaire, l'avance du pied droit (6.1, M4) |
| Le rayon | La distance de l'axe à la boule, bras, épaules et câble compris ; « perdre du rayon », c'est plier les bras ou tirer avec | Rayon redéfini, pertes de rayon signalées (6.4) ; le sens mécanique √(I/m) est abandonné |
| Hanches et épaules | Central, mais on dit « devancer le marteau » ; l'angle est peu fiable avec une seule caméra, et le pied droit en dit l'essentiel | X-factor en option exploratoire (C1, 6.5) |
| Un seul chiffre par tour | La vitesse de la boule en fin de tour, en hausse à chaque tour ; à défaut, la durée du double appui | Durées des appuis et des tours (6.2), vitesse des mains (6.3), vitesse de la boule en option (C2, C3) |
| Filmer | 120 à 240 images/s ; trépied à hauteur de hanche, mise au point et exposition verrouillées ; hors de la cage, à 2 ou 3 m du filet ; de côté pour les appuis, de derrière pour les tours ; en journée. Le cercle de 2,135 m sert d'échelle. Pas de caméra à 120-240 images/s disponible pour l'instant | Exigences d'entrée (section 2), règles R8 et R9, calibration en option (C4), risques (section 11) |
| Tester l'app à la fin, consentement des athlètes | Pas encore de réponse | À redemander avant le tournage |

**À ton tuteur : le périmètre**

- [ ] **Notion mise en œuvre** : l'architecture web et la méthode de System design comptent-elles comme la notion du POK, la vision par ordinateur restant le domaine d'application ? Sinon, faut-il d'abord un MON sur l'estimation de pose ?
- [ ] **Seul ou en binôme** : en binôme, l'un prend le pipeline, l'autre le front, avec un contrat d'API figé au sprint 0.
- [ ] **Exposé** : quelle durée, et la démo en direct est-elle acceptée, ou faut-il une vidéo ?

## Sources

- [Rotation of the hammer and performance in hammer throwing](https://www.frontiersin.org/journals/bioengineering-and-biotechnology/articles/10.3389/fbioe.2024.1449465/full), Frontiers in Bioengineering and Biotechnology, 2024 : durées d'appui par tour, rayon du marteau, protocole vidéo.
- [Hammer throw, Brian Mac Sports Coach](https://brianmac.co.uk/hammer/index.htm) : vitesses de lâcher aux Mondiaux 2011 (Isele et al., 2012), nombre de tours, diamètre du cercle.
- [Pose landmark detection guide for Web, Google AI Edge](https://developers.google.com/edge/mediapipe/solutions/vision/pose_landmarker/web_js) : sorties, `visibility`, coordonnées monde.
- [Pose landmark detection guide, Google AI Edge](https://developers.google.com/edge/mediapipe/solutions/vision/pose_landmarker/index) : modèles Lite, Full et Heavy, numéros des 33 points.
- [scipy.interpolate.CubicSpline, SciPy](https://docs.scipy.org/doc/scipy-1.9.1/reference/generated/scipy.interpolate.CubicSpline.html) : conditions aux limites, limite sur le cercle.
- [Joyce, Burnett et Ball, Methodological considerations for the 3D measurement of the X-factor](https://people.stfx.ca/smackenz/Courses/DirectedStudy/Articles/Joyce%202010%20Methodological%20considerations%20for%20the%203D%20measurement%20of%20the%20X-factor.pdf), Sports Biomechanics, 2010 : définition et calcul du X-factor.
- [Parcours Do-IT, syllabus Centrale Méditerranée](https://syllabus.centrale-med.fr/plugins/odf-web/odf/_content/course-parcours-do-it-developpement-et-organisation-en-it-2-fr-fr-fr/Parcours%20DO-IT%20_%20D%C3%A9veloppement%20et%20Organisation%20en%20IT.pdf) : POK, MON et jalons.
- Supports de cours fournis : Extended System Design (Adèle Bourgeix) et WEB Front 101, jours 1 à 3 (Matthieu Bouxin).
- Simulation de cadrage : script `sim_spline.py` (NumPy 2.5, SciPy 1.18), joint à la conversation.

* Entretien avec l'entraîneuse, 6 novembre 2026 : priorités, définition du rayon, protocole de tournage (section 12).
