# Matrice des droits

Remplie avant d'écrire les GRANT de roles.sql.

| Objet | apicultrice | coordinateur | gestionnaire | admin |
|---|---|---|---|---|
| ses ruches et leurs mesures | lire | non (seulement la liste des ruches de son site) | non | non |
| déclarer une récolte | sur ses ruches | non | non | non |
| valider une récolte (UC-C02) | non | oui, sur son site, par la fonction `valider_recolte` | non | non |
| ruches et téléphones de son site | non | lire | non | non |
| synthèse et export (UC-G01, UC-G02) | non | non | lire | non |
| comptes utilisateurs (UC-AD01) | sa ligne seulement (`v_moi`) | sa ligne seulement | sa ligne seulement | lire, créer, modifier (pas de suppression) |
| journal d'audit | non | non | non | lire |

## Pourquoi ces choix

- Pas d'UPDATE sur `recolte` pour le coordinateur : il pourrait changer les volumes. La fonction ne touche qu'au statut.
- L'apicultrice écrit par `v_mes_recoltes` et seulement sur `ruche_id`, `date_recolte`, `quantite_kg` : elle ne peut pas se mettre le statut à `validee`.
- Le gestionnaire ne voit que des chiffres agrégés (synthèse, export pseudonymisé).
- L'admin gère les comptes mais ne peut rien supprimer, et il lit le journal sans pouvoir le modifier.

## Limite

Un superutilisateur (postgres) ou le propriétaire de la table peut désactiver les triggers du journal
(`ALTER TABLE journal_audit DISABLE TRIGGER journal_ajout_seul;`). Le journal doit donc aussi être
copié hors de la base (vers le SIEM du cahier des charges), sinon un administrateur malhonnête peut
effacer ses traces sans laisser de trace lui-même.
