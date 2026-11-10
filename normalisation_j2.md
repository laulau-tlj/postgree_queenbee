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
