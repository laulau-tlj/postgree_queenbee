# Normalisation – Jour 2 – Groupe ___

Les captures d'écran de chaque étape sont dans `Lab6_captures.pdf` (C01 à C13).

## Étape 6.1 · Analyse de formation_plat

**Les dépendances**

- `(telephone, theme) → formateur` : pour un thème, une apicultrice n'a qu'un seul formateur.
- `formateur → theme` : un formateur n'enseigne qu'un seul thème.

Les trois tests `GROUP BY … HAVING` donnent **(0 ligne)** chacun (captures C03 et C04) : les données ne contredisent pas ces règles.

**Les clés candidates**

- `(telephone, theme)` : c'est la clé primaire.
- `(telephone, formateur)` : le formateur donne le thème, donc avec le téléphone on retrouve toute la ligne.

**3NF ? Oui.** La seule dépendance dont la partie gauche n'est pas une clé est `formateur → theme`, mais `theme` fait partie d'une clé candidate. La 3NF l'accepte.

**BCNF ? Non.** `formateur` n'est pas une super-clé : il ne détermine pas le téléphone.

**L'anomalie**

Dans une transaction annulée, on passe Moussa Sarr en `capteurs` sur la ligne de `+221 77 100 00 02`. La table accepte sans message (capture C04) :

```
  formateur  |      themes
-------------+-------------------
 Moussa Sarr | {capteurs,varroa}
```

La règle `formateur → theme` est cassée par une seule ligne modifiée.

## Étape 6.2 · Le découpage

**Le mauvais découpage** : `p1 (telephone, theme)` et `p2 (theme, formateur)`.

La jointure donne **16 lignes au lieu de 8**, dont **8 inventées** (capture C05). Par exemple, `+221 77 100 00 02` serait suivie par trois formateurs varroa (Moussa Sarr, Ibrahima Fall, Kouassi Yao) alors qu'elle n'en a qu'un.

Pourquoi : la colonne commune `theme` n'est la clé d'aucun des deux morceaux. Un thème a plusieurs apicultrices et plusieurs formateurs, donc la jointure associe tout le monde avec tout le monde.

**Le bon découpage** : `formateur (id, nom UNIQUE, theme)` et `suivi_formation (apicultrice_id, formateur_id)`. La colonne commune est le formateur, qui est la clé de la table `formateur` : le découpage est sans perte.

**Le problème rencontré** : au premier lancement, `INSERT 0 5` puis `INSERT 0 3` au lieu de 8 (capture C06).

Quatre téléphones du tableau n'existent pas dans notre base : notre jeu d'essai du jour 1 utilise d'autres numéros. On a corrigé ces lignes avec les numéros de nos apicultrices :

| Numéro du tableau | Remplacé par | Apicultrice |
|---|---|---|
| +221 77 200 00 01 | +221 77 200 00 03 | Aminata Diop (SN-KOLD) |
| +225 07 100 00 01 | +225 07 00 00 00 05 | Adjoua Koffi |
| +225 07 100 00 02 | +225 07 00 00 00 06 | Mariam Traoré |
| +237 6 77 100 01 | +237 6 70 00 00 07 | Chantal Mbarga |

Après correction : `INSERT 0 5` (cinq formateurs) puis `INSERT 0 8` (huit suivis) (capture C07).

**La preuve** : la double comparaison `EXCEPT` donne **(0 ligne)** (capture C08). Rien de perdu, rien d'inventé.

**Quelle contrainte garantit formateur → theme ?**
Le `UNIQUE` sur `formateur.nom` : chaque formateur n'a qu'une seule ligne, donc un seul thème. Le `CHECK` limite en plus le thème à varroa, recolte ou capteurs.

**Pourquoi suivi_formation pointe vers apicultrice(id) au lieu de recopier le téléphone ?**
- La clé étrangère garantit que l'apicultrice existe.
- Le téléphone n'est pas un bon identifiant : il peut changer, et dans notre schéma il n'est même pas `UNIQUE`.
- C'est une donnée personnelle : on évite de la recopier dans une deuxième table.

## Étape 6.3 · La règle perdue et le trigger

**La règle perdue** : après le découpage, plus aucune table ne contient à la fois l'apicultrice et le thème. On inscrit Awa Diop (`+221 77 100 00 02`) chez Ibrahima Fall alors qu'elle a déjà Moussa Sarr pour le varroa. La base accepte (capture C09) :

```
INSERT 0 1
   nom    | theme  |           formateurs
----------+--------+---------------------------------
 Awa Diop | varroa | {"Ibrahima Fall","Moussa Sarr"}
```

La ligne fautive a ensuite été supprimée (`DELETE 1`).

**Le trigger** `suivi_formation_df` (fonction `suivi_un_formateur_par_theme()`), posé en relançant `formation.sql` (captures C10 et C12) :

- Awa Diop chez Ibrahima Fall (varroa, elle a déjà Moussa Sarr) :
  `ERREUR:  DF violée : cette apicultrice a déjà un formateur pour ce thème` (capture C11)
- Awa Diop chez Khady Ndiaye (récolte, thème nouveau pour elle) :
  `INSERT 0 1`

## Étape 6.4 · Revue BCNF de toutes nos tables

| Table | Dépendances (clé primaire et UNIQUE) | Partie gauche = super-clé ? | BCNF ? |
|---|---|---|---|
| site | id → nom, pays | oui | oui |
| cooperative | id → nom, site_id | oui | oui |
| apicultrice | id → nom, telephone, site_id | oui | oui |
| ruche | id → tout ; nom (UNIQUE) → tout | oui | oui |
| utilisateur | id → tout ; login (UNIQUE, lab 4) → tout ; apicultrice_id (UNIQUE) → tout | oui | oui |
| adhesion | (apicultrice_id, cooperative_id) → date_adhesion | oui | oui |
| mesure | id → tout ; (ruche_id, horodatage) (UNIQUE) → tout | oui | oui |
| inspection | id → tout | oui | oui |
| recolte | id → tout | oui | oui |
| alerte | id → tout | oui | oui |
| formateur | id → nom, theme ; nom (UNIQUE) → id, theme | oui | oui |
| suivi_formation | aucune autre colonne que la clé (apicultrice_id, formateur_id) | oui | oui |
| formation_plat | (telephone, theme) → formateur ; **formateur → theme** | non pour formateur → theme | **non** (3NF seulement) |

`formation_plat` est le tableau reçu tel quel. On travaille sur `formateur` et `suivi_formation`.

**apicultrice.site_id et ruche.site_id : le même fait écrit deux fois ?**

Résultat de la requête : 8 lignes, et chaque apicultrice n'a des ruches que sur son propre site (capture C13).

Les données ne suffisent pas à trancher. Dans nos hypothèses du lab 1, une ruche est installée sur le site de son apicultrice. Si c'est une règle métier, `ruche.site_id` est une copie qui peut diverger d'`apicultrice.site_id`. Aujourd'hui, rien dans le schéma ne garantit la cohérence : seule notre requête de contrôle (test 7 du lab 2) la vérifie. Pour la garantir, il faudrait soit supprimer `ruche.site_id` (on le retrouve par l'apicultrice), soit ajouter une clé étrangère composée `(apicultrice_id, site_id)` vers `apicultrice (id, site_id)`.

## Testez-vous · Lab 6

**1. R(A, B, C) avec A → B. Le découpage (A, B) + (A, C) est-il sans perte ? Et (A, B) + (B, C) ?**
(A, B) + (A, C) est sans perte : la colonne commune A est la clé de (A, B), puisque A → B. (A, B) + (B, C) peut inventer des lignes : la colonne commune B n'est la clé d'aucun des deux morceaux.

**2. Pourquoi formation_plat est-elle en 3NF, alors que formateur → theme ne part pas d'une clé ?**
Parce que `theme` fait partie d'une clé candidate, `(telephone, theme)`. La 3NF accepte une dépendance qui ne part pas d'une clé si la colonne de droite appartient à une clé. La BCNF, elle, ne l'accepte pas.

**3. Pourquoi le trigger a-t-il besoin de la condition s.formateur_id <> NEW.formateur_id ?**
Sans elle, le trigger se trouverait lui-même. Lors d'un `UPDATE`, l'ancienne ligne est encore dans la table avec le même formateur : la modification serait refusée alors qu'elle ne viole rien.

**4. Un avantage et un inconvénient de rester en 3NF plutôt que de passer en BCNF ?**
Avantage : la règle « un formateur par thème pour une apicultrice » reste garantie par la clé primaire `(telephone, theme)`, sans trigger. Inconvénient : le thème du formateur est recopié sur plusieurs lignes, donc une seule ligne modifiée peut le contredire (l'anomalie de Moussa Sarr).

## Lab 7 · Dénormaliser, en connaissance de cause

### Étape 7.1 & 7.2 · Synthèse et performances
- **Volume** : `volume.sql` lancé une seule fois : `INSERT 0 47520`, puis `ANALYZE`.
- **Tableau de bord sur la table brute `mesure` (`EXPLAIN ANALYZE`)** : `26,733 ms` (Seq Scan sur 48 048 lignes, Hash Join avec les 3 ruches de SN-CASA, 13 104 lignes retenues, tri de 433 lignes). Résultat : 144 mesures par jour (3 ruches × 48), et non 192, car SN-CASA compte 3 ruches dans ma base.
- **Même requête sur la vue matérialisée `synthese_site_jour`** : `0,034 ms` (Index Scan Backward sur `synthese_site_jour_pk`, 3 pages lues), soit environ 800 fois plus rapide.
- **Prix de la copie** : la première lecture de la vue montrait des chiffres différents des mesures brutes (32,43 kg contre 32,60 kg le 13 mars) : la vue n'était pas à jour. Après `REFRESH`, les chiffres redeviennent identiques.
- **Vol du 15 mars à 6 h** (mesure de 8,40 kg insérée sur `SN-CASA-014`) : absent de la vue avant le `REFRESH`, présent après (`nb_mesures = 1`, `poids_min = 8.40`).
- **Retard de visibilité** : si la vue n'est rafraîchie qu'une fois par nuit (ex. à minuit), un vol à 6 h reste invisible environ **18 heures**, et jusqu'à **24 heures** au pire.
- **Où détecter un vol (UC-CY04)** : sur les **mesures brutes**, au moment où la mesure arrive (trigger ou règle d'alerte), jamais sur la vue matérialisée, qui sert à afficher vite et reste en retard.

### Étape 7.3 · Export pseudonymisé pour le bailleur (UC-G02)
- **Cassage du haché simple** : le SHA-256 du numéro de Fatou Sow est cassé par force brute sur 1 million de combinaisons (`+221 77 2XX XX XX`). Numéro retrouvé : `+221 77 200 00 04` en **2 855 ms (environ 2,9 s)**. Un hachage sans clé secrète ne protège pas des données à faible entropie comme les numéros de téléphone.
- **Vue `v_export_bailleur`** : 8 lignes pour 11 ruches, sans nom ni téléphone, positions arrondies (`12.6 | -16.3`, etc.), `contient_la_cle = f`.
- **Colonnes retirées et justifications (minimisation RGPD)** :
  - `apicultrice.nom` et `apicultrice.telephone` : identifiants directs ; remplacés par un pseudonyme `HMAC-SHA256` tronqué à 12 caractères, calculé à partir de `apicultrice.id` et d'une clé secrète stockée dans une table fermée à `PUBLIC`.
  - `ruche.nom` (code exact comme `SN-CASA-014`) : désigne une ruche précise, donc indirectement la personne qui l'exploite.
  - `latitude` et `longitude` exactes : permettent de localiser la ruche ; arrondies à `0,1°` (environ 11 km) pour garder une carte utile sans exposer l'emplacement.
  - Récoltes non validées (`statut = 'declaree'`) et détail des récoltes : seul le total des récoltes validées est transmis (`FILTER (WHERE rc.statut = 'validee')`).
- **RGPD** : ces données sont pseudonymisées, pas anonymisées : celui qui possède la clé peut retrouver la personne.

### Étape 7.4 · Journal d'audit (`journal_audit`)
`denormalisation.sql` relancé deux fois de suite avec `ON_ERROR_STOP=1` : aucune erreur, le script est rejouable (seule la notice « pgcrypto existe déjà » apparaît).

1. **Absence de clé étrangère sur `ligne_id`** : avec une clé étrangère vers `recolte(id)`, `RESTRICT` empêcherait de supprimer la récolte, `CASCADE` effacerait la trace avec elle, et `SET NULL` perdrait le lien : dans les trois cas, la preuve est perdue ou bloquée. De plus, le journal couvre plusieurs tables (`table_cible`) et stocke l'identifiant en `text`, ce qu'une clé étrangère unique ne permet pas.
2. **Recopie intégrale dans `avant` et `apres` (`jsonb`)** : oui, c'est acceptable ici, car le journal doit figer l'état exact de la ligne avant et après chaque modification, même si elle est ensuite supprimée. Le volume reste faible car seules les actions sensibles (récoltes, utilisateurs) sont auditées, pas les mesures des capteurs. Garde-fou : ces copies peuvent contenir des données personnelles (table `utilisateur`), donc le journal est fermé à `PUBLIC`, lisible par l'admin seul, avec une durée de conservation à prévoir.
3. **`clock_timestamp()` plutôt que `now()`** : `now()` renvoie l'heure du début de la transaction, donc toutes les lignes d'une même transaction auraient la même heure et l'ordre des actions serait perdu. `clock_timestamp()` enregistre l'heure réelle de chaque écriture.