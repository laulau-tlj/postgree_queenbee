-- tests_audit.sql : tests de l'étape 8.3 (points 2 à 4), en postgres
-- les résultats sont à recopier en commentaire après chaque test

\echo '--- test 2 : modifier le volume de la récolte de SN-CASA-011'
UPDATE recolte SET volume_kg = 14.0
WHERE ruche_id = (SELECT id FROM ruche WHERE code = 'SN-CASA-011') AND volume_kg = 12.5;

SELECT acteur, table_cible, operation,
       avant ->> 'volume_kg' AS avant, apres ->> 'volume_kg' AS apres
FROM journal_audit ORDER BY id DESC LIMIT 1;
-- résultat :

\echo '--- test 3 : effacer le journal'
SELECT count(*) FROM journal_audit;
UPDATE journal_audit SET acteur = 'personne';
DELETE FROM journal_audit;
TRUNCATE journal_audit;
SELECT count(*) FROM journal_audit;
-- résultat :

\echo '--- test 4 : le propriétaire peut désactiver le trigger (limite)'
ALTER TABLE journal_audit DISABLE TRIGGER journal_ajout_seul;
ALTER TABLE journal_audit ENABLE TRIGGER journal_ajout_seul;
-- résultat :
