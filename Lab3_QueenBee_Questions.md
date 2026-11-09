# Lab 3 – Algèbre relationnelle et requêtes – Queen Bee

Fichiers rendus : `requetes.sql`, `query_vuln.py`, `query.py`.

## Étape 3.1 – Cinq questions à la base

| Question | Algèbre relationnelle | Résultat |
|---|---|---|
| Q1. Ruches du site SN-CASA avec leur position | π nom, latitude, longitude (σ site_id = 'SN-CASA' (ruche)) | 3 lignes |
| Q2. Chaque apicultrice et son nombre de ruches | apicultrice ⟕ ruche, puis comptage par apicultrice | 8 lignes, les deux Aminata Diop séparées |
| Q3. Ruches jamais inspectées | π id (ruche) − π ruche_id (inspection) | 5 lignes |
| Q4. Sites avec au moins une alerte ouverte | π site_id (σ statut = 'ouverte' (alerte) ⋈ ruche) | 2 lignes |
| Q5. Vue v_ruche_coordinateur (code, site, dernière pesée) | π nom, site_id, poids_kg (ruche ⋈ dernière mesure) | 11 lignes |

**Pourquoi une application ne doit-elle jamais faire `SELECT *` sur la table des apicultrices ?**

`SELECT *` renvoie toutes les colonnes, y compris le téléphone, même quand on n'en a pas besoin. Si on ajoute plus tard une colonne sensible, elle sera exposée sans qu'on s'en rende compte. Il faut sélectionner seulement les colonnes utiles, ou passer par une vue.

## Étape 3.2 – Le programme vulnérable, puis sa correction

| Saisie | query_vuln.py | query.py |
|---|---|---|
| code normal (SN-CASA-014) | 1 ligne | 1 ligne |
| `' OR '1'='1` | 11 lignes (toutes les ruches) | 0 ligne |
| `' UNION SELECT nom, telephone FROM apicultrice --` | 8 lignes (noms et téléphones) | 0 ligne |

**Pourquoi query.py résiste ?**

Parce que la requête et la valeur sont envoyées séparément (`%s`). Ce que tape l'utilisateur n'est jamais lu comme du SQL, c'est juste une valeur cherchée telle quelle.

## Testez-vous

**1. Quelle différence entre JOIN et LEFT JOIN pour compter les ruches de chaque apicultrice ?**

`JOIN` ne garde que les apicultrices qui ont au moins une ruche. `LEFT JOIN` les garde toutes, et celles sans ruche apparaissent avec 0.

**2. Dans l'attaque `' UNION SELECT nom, telephone FROM apicultrice --`, à quoi servent l'apostrophe et les deux tirets ?**

L'apostrophe ferme le texte ouvert par le programme, ce qui permet d'écrire du SQL après. Les deux tirets mettent en commentaire la fin de la requête (l'apostrophe ajoutée par le programme), pour qu'elle reste valide.

**3. Pourquoi supprimer les apostrophes de la saisie ne suffit-il pas ?**

Certaines injections n'ont pas besoin d'apostrophe (sur un champ numérique par exemple), et en supprimant les apostrophes on abîme les vraies données comme « Côte d'Ivoire ». La vraie solution, c'est la requête paramétrée.
