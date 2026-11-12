-- tests_audit.sql : tests de l'étape 8.3 (points 2 à 4), en postgres
-- les résultats sont à recopier en commentaire après chaque test

\echo '--- test 2 : modifier la quantité de la récolte de SN-CASA-014'
UPDATE recolte SET quantite_kg = 14.0
WHERE ruche_id = (SELECT id FROM ruche WHERE nom = 'SN-CASA-014') AND quantite_kg = 12.5;

SELECT acteur, table_cible, operation,
       avant ->> 'quantite_kg' AS avant, apres ->> 'quantite_kg' AS apres
FROM journal_audit ORDER BY id DESC LIMIT 1;
-- résultat : UPDATE 1, puis une ligne du journal :
--   acteur = postgres | table_cible = recolte | operation = UPDATE | avant = 12.50 | apres = 14.00

\echo '--- test 3 : effacer le journal'
SELECT count(*) FROM journal_audit;
UPDATE journal_audit SET acteur = 'personne';
DELETE FROM journal_audit;
TRUNCATE journal_audit;
SELECT count(*) FROM journal_audit;
-- résultat : les trois ordres sont refusés par le trigger journal_interdit() :
--   ERREUR: journal_audit est en ajout seul : UPDATE interdit
--   ERREUR: journal_audit est en ajout seul : DELETE interdit
--   ERREUR: journal_audit est en ajout seul : TRUNCATE interdit
-- le comptage reste identique avant et après (2 lignes).

\echo '--- test 4 : le propriétaire peut désactiver le trigger (limite)'
ALTER TABLE journal_audit DISABLE TRIGGER journal_ajout_seul;
ALTER TABLE journal_audit ENABLE TRIGGER journal_ajout_seul;
-- résultat : ALTER TABLE x2, aucune erreur — le propriétaire de la table
-- (ou un superutilisateur) peut désactiver le trigger : c'est la limite connue
-- de ce mécanisme.
