# Lab 9 · Transactions et Concurrence

## Étape 9.1 · L'action et sa trace ensemble
## Étape 9.1 · L'action et sa trace ensemble
- **Journal applicatif (`journal_appli`)** : L'insertion est validée immédiatement. L'`UPDATE` échoue ensuite sur la contrainte `recolte_validation_tracee`. Le journal ment car il affiche une validation qui n'existe pas en base.
- **Trigger d'audit (`journal_audit`)** : Compteur initial = `1`. Après `UPDATE 2` dans la transaction = `3`. Après `SELECT 1/0` et `ROLLBACK` = `1`. L'action et sa trace sont atomiques.

## Étape 9.2 · La course au jeton (test manuel sur `RT-f.ba-1`)

## 9.2 Course au jeton à la main (`RT-f.sow-1`)

| Temps | Terminal A | Réponse A | Terminal B | Réponse B |
| :--- | :--- | :--- | :--- | :--- |
| T1 | `BEGIN;` + `SELECT` sur `RT-f.sow-1` | `1 row` (`utilise_le` NULL) | — | — |
| T2 | — | — | `BEGIN;` + `SELECT` sur `RT-f.sow-1` | `1 row` (`utilise_le` NULL) |
| T3 | `UPDATE jeton` + `INSERT session_app` + `COMMIT;` | `UPDATE 1`, `INSERT 0 1`, `COMMIT` | — | — |
| T4 | — | — | `UPDATE jeton` + `INSERT session_app` + `COMMIT;` | `UPDATE 1`, `INSERT 0 1`, `COMMIT` |

Résultat : `SELECT count(*) FROM session_app` renvoie **2 sessions** pour un seul jeton.


## Étape 9.4 · Comparaison des 4 mécanismes

| Méthode | Où agit-elle ? | Que voit la 2e requête ? | Avantage | Limite |
| :--- | :--- | :--- | :--- | :--- |
| **`SELECT ... FOR UPDATE`** | Verrou sur la ligne lue dans la transaction | Elle est bloquée en attente jusqu'au `COMMIT` de la 1re | Sécurise des calculs complexes en plusieurs requêtes | Peut ralentir l'application ou créer des interblocages (*deadlocks*) |
| **`UPDATE ... RETURNING`** | Requête SQL unique atomique | Elle reçoit `0 ligne` (`None`) immédiatement | Très rapide, pas besoin de transaction longue | Uniquement possible si tout tient dans un seul `UPDATE` |
| **`UNIQUE (jeton_id)`** | Contrainte sur la table `session_app` | Elle reçoit une erreur `UniqueViolation` à l'`INSERT` | Protection ultime garantie par la base de données | Le code Python doit attraper l'exception SQL |
| **`REPEATABLE READ`** | Niveau d'isolation de la transaction | Elle échoue au `COMMIT` (`could not serialize access`) | Protège toutes les données lues dans la transaction | Oblige l'application à relancer la transaction (*retry*) |

### Question sur le trigger du Lab 6 (`suivi_formation_df`)
- **Pourquoi est-il vulnérable ?** Le trigger fait un `SELECT EXISTS(...)` puis laisse passer l'`INSERT`. Si deux transactions insèrent en même temps deux formateurs différents du même thème pour la même apicultrice, aucune ne voit l'insertion non validée de l'autre : la règle est contournée.
- **Comment le protéger ?** Utiliser le niveau d'isolation **`SERIALIZABLE`** ou poser un verrou consultatif (`pg_advisory_xact_lock(apicultrice_id)`) au début du trigger.

<!-- On vide d'abord session_app car les tests 9.2 et 9.3 y avaient laissé des doublons qui bloqueraient l'ajout de la contrainte -->