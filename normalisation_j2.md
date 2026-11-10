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