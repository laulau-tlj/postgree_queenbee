# Revue de sécurité de notre base 

## Synthèse
Contrôles passés : 11 / 12  Constats : 0 critique(s), 0 haute(s), 1 moyenne(s), 0 basse(s)

## Failles démontrées (étapes 10.1 et 10.2)

| ID | Faille | Preuve | Correction | Retest |
| :--- | :--- | :--- | :--- | :--- |
| P1 | injection par le tri | Saisie `(SELECT telephone::int FROM apicultrice WHERE nom = 'Fatou Sow')` divulgue `+221 77 200 00 04` dans l'erreur ; le `CASE WHEN` à l'aveugle modifie l'ordre de tri. | Liste blanche (`TRI_AUTORISES = {"id", "date_installation"}`), `sql.Identifier(tri)` et masquage des erreurs SQL dans `recherche.py`. | Rejeu de l'attaque par erreur sur `recherche.py` : `Tri refusé : choisissez id ou date_installation.` |
| P2 | vue v_carte_ruches trop large | En `f.ba`, `SELECT * FROM apicultrice;` est refusé (`permission denied`), mais `SELECT * FROM v_carte_ruches;` affiche les 11 ruches et tous les téléphones. | Réécriture de `v_carte_ruches` dans `corrections.sql` sans la colonne `telephone` et filtrage sur `WHERE u.login = current_user`. | `SELECT * FROM v_carte_ruches;` en `f.ba` ne renvoie plus que `SN-KOLD-012` sans numéro de téléphone. |
| P3 | fuite par fonction espion | `SELECT * FROM v_mes_ruches WHERE pg_temp.espion(...);` affiche les positions GPS des 11 ruches dans les `NOTICE`. | Ajout de `WITH (security_barrier = true)` sur les vues filtrantes et `REVOKE TEMPORARY ON DATABASE queenbee FROM PUBLIC;`. | L'espion en session ouverte ne voit plus que `SN-KOLD-012` ; une nouvelle session `f.ba` reçoit `permission denied to create temporary tables`. |

## Constats de la grille (étape 10.3 · Contrôles C1 à C12)

| ID | Contrôle | Gravité | Constat | Preuve (commande et résultat) | Correction | Retest |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| R1 | C12 (et C6/C7) | Moyenne | Arrêt de `roles.sql` sur `column r.code does not exist` (la colonne s'appelle `r.nom`), bloquant la création des droits et de la politique RLS sur `recolte`, et décalage de login (`f.sow` vs `f.ba`). | `psql -v ON_ERROR_STOP=1 -f roles.sql` échoue ; `INSERT INTO recolte` en `f.ba` renvoie `permission denied for table recolte`. | Alignement du login `f.ba` dans `utilisateur` et ajout des `GRANT` + politique RLS `recolte_apicultrice_isolement` dans `corrections.sql`. | `INSERT` refusé par RLS sur la ruche d'une autre apicultrice (C7) et accepté sur `SN-KOLD-012` avec trace `acteur = f.ba` dans `journal_audit` (C6). |

---

## Détail des preuves d'injection SQL dans `ORDER BY`

### 1. Fonctionnement normal (`recherche_vuln.py`)
- **Saisie** : `Site : SN-CASA` | `Tri : id`
- **Réponse** :
```text
(UUID('02e8ffd3-e9ab-492f-9ac5-1827d3a25b9a'), datetime.date(2025, 3, 10), Decimal('-16.27250'))
(UUID('b5412afc-2633-40f7-88bc-0f1a993c8721'), datetime.date(2025, 6, 2), Decimal('-16.28000'))
(UUID('c2d33fee-1e06-4983-9bb0-b83eabb83cac'), datetime.date(2025, 3, 10), Decimal('-16.27200'))
```

### 2. Exploitation de la vulnérabilité (`ORDER BY` non paramétré)

#### Attaque par erreur (*Error-based*)
- **Saisie** : `(SELECT telephone::int FROM apicultrice WHERE nom = 'Fatou Sow')`
- **Réponse** :
```text
psycopg.errors.InvalidTextRepresentation: invalid input syntax for type integer: "+221 77 200 00 04"
```
- **Analyse** : La conversion forcée en entier fait échouer la requête et divulgue la donnée confidentielle dans le message d'erreur.

#### Attaque à l'aveugle (*Blind Boolean-based*)
- **Saisie 1 (condition vraie `'77'`)** : `CASE WHEN (SELECT substr(telephone, 6, 2) FROM apicultrice WHERE nom = 'Fatou Sow') = '77' THEN id::text ELSE longitude::text END`
- **Réponse 1** :
```text
(UUID('02e8ffd3-e9ab-492f-9ac5-1827d3a25b9a'), datetime.date(2025, 3, 10), Decimal('-16.27250'))
(UUID('b5412afc-2633-40f7-88bc-0f1a993c8721'), datetime.date(2025, 6, 2), Decimal('-16.28000'))
(UUID('c2d33fee-1e06-4983-9bb0-b83eabb83cac'), datetime.date(2025, 3, 10), Decimal('-16.27200'))
```
- **Saisie 2 (condition fausse `'78'`)** : `CASE WHEN (SELECT substr(telephone, 6, 2) FROM apicultrice WHERE nom = 'Fatou Sow') = '78' THEN id::text ELSE longitude::text END`
- **Réponse 2** :
```text
(UUID('c2d33fee-1e06-4983-9bb0-b83eabb83cac'), datetime.date(2025, 3, 10), Decimal('-16.27200'))
(UUID('02e8ffd3-e9ab-492f-9ac5-1827d3a25b9a'), datetime.date(2025, 3, 10), Decimal('-16.27250'))
(UUID('b5412afc-2633-40f7-88bc-0f1a993c8721'), datetime.date(2025, 6, 2), Decimal('-16.28000'))
```
- **Analyse** : Le changement d'ordre des lignes permet à un attaquant d'extraire le numéro caractère par caractère sans message d'erreur.

#### Attaque empilée (*Stacked queries*)
- **Saisie** : `id; DROP TABLE journal_audit`
- **Réponse** :
```text
psycopg.errors.SyntaxError: cannot insert multiple commands into a prepared statement
```
- **Analyse** : Le protocole étendu de `psycopg` refuse l'exécution de plusieurs instructions séparées par un point-virgule.

### 3. Correction (`recherche.py`)
- **Mesures appliquées** : Validation par liste blanche (`TRI_AUTORISES = {"id", "date_installation"}`), échappement via `psycopg.sql.Identifier(tri)` et interception des exceptions SQL pour masquer les détails internes.
- **Test avec l'attaque par erreur** :
```text
Tri refusé : choisissez id ou date_installation.
```

---

## Notre propre code

### Faille 1 : Vue trop permissive (`v_carte_ruches`)
- **Preuve** : Connecté en `f.ba`, `SELECT * FROM apicultrice;` est bloqué (`permission denied`), mais `SELECT * FROM v_carte_ruches;` affiche les 11 ruches ainsi que les noms et téléphones de toutes les apicultrices, car la vue s'exécute avec les droits de `postgres`.
- **Correction** : Réécriture de `v_carte_ruches` dans `corrections.sql` en retirant la colonne `telephone` et en filtrant avec `WHERE u.login = current_user`.
- **Retest** : `SELECT * FROM v_carte_ruches;` ne retourne plus que la ruche de `f.ba` (`SN-KOLD-012`), sans aucun numéro de téléphone.

### Faille 2 : Fuite de données via fonction temporaire (`pg_temp.espion`)
- **Preuve** : En appelant `pg_temp.espion(...)` dans le `WHERE` de `v_mes_ruches`, l'optimiseur exécute la fonction avant le filtre de la vue et affiche les coordonnées GPS des 11 ruches via les `NOTICE`.
- **Correction** : Activation de `security_barrier = true` sur toutes les vues filtrantes et révocation du privilège temporaire (`REVOKE TEMPORARY ON DATABASE queenbee FROM PUBLIC;`).
- **Retest** : Dans la session ouverte, l'espion ne voit plus que `SN-KOLD-012`. Dans une nouvelle session `f.ba`, la création d'objets temporaires est bloquée (`ERROR: permission denied to create temporary tables`).
