# Queen Bee – Dossier de conception, jour 2

## Membres du groupe
- [Laura](https://github.com/laulau-tlj)
- [Khady](https://github.com/Somechild00)
- [Junel](https://github.com/JunelAmelon)
- [Amale](https://github.com/Amale921)

## Les 5 parties
1. Schéma normalisé : 1_schema_normalise/
2. Rôles et privilèges : 2_roles_privileges/ (4 rôles, 8 vues, 1 fonction de validation)
3. Trigger d'audit : 3_trigger_audit/ (tables auditées : recolte, utilisateur)
4. Test de concurrence : 4_test_concurrence/ (2 sessions avant, 1 après)
5. Revue de sécurité : 5_revue_securite/ (1 constat moyen, corrigé ; 3 failles démontrées P1–P3, toutes corrigées)

## Reconstruire (après la base du jour 1, avec -v ON_ERROR_STOP=1)
1. formation.sql 2. volume.sql (une fois) 3. denormalisation.sql
4. references.sql puis check.sql 5. audit.sql 6. roles.sql
7. jeton.sql 8. corrections.sql

## Nos choix principaux
- BCNF + trigger pour les formations : `formation_plat` n'était qu'en 3NF (`formateur → theme` ne part pas d'une clé), donc découpage en `formateur` + `suivi_formation`, et la règle « un formateur par thème par apicultrice » perdue au découpage est rétablie par le trigger `suivi_formation_df`.
- La synthèse `synthese_site_jour` est rafraîchie à la demande (prévu : une fois par nuit) ; le vol est détecté sur les mesures brutes à l'arrivée, jamais sur la vue matérialisée qui peut avoir jusqu'à 24 h de retard.
- Le journal d'audit est en ajout seul (triggers `journal_ajout_seul` et `journal_sans_truncate`), fermé à `PUBLIC`, lisible par `qb_admin` seul, et nomme le vrai acteur via `qui()`.

## Limites connues
- un superutilisateur peut désactiver les triggers du journal : le test 4 de `tests_audit.sql` montre que `DISABLE TRIGGER` passe sans erreur ; il faudrait un audit externe hors de la base ou restreindre le rôle propriétaire.
