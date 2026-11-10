-- tests_contournement.sql
-- Pour chaque test : la commande, le résultat recopié en commentaire, puis "attendu" ou "problème".
-- Se lance en postgres ; SET ROLE fait agir la session comme l'utilisateur voulu.

-- préparation (en postgres, on range des identifiants que f.ba n'a pas le droit de lire)
SELECT id AS ruche_autre FROM ruche WHERE code = 'SN-KOLD-011' \gset

INSERT INTO recolte (ruche_id, date_recolte, volume_kg)
SELECT id, current_date, 6.6 FROM ruche WHERE code LIKE 'CM-BAF%' LIMIT 1;
SELECT id AS recolte_cm FROM recolte WHERE volume_kg = 6.6 LIMIT 1 \gset


\echo '--- test 1 : f.ba lit apicultrice directement'
SET ROLE "f.ba";
SELECT * FROM apicultrice;
-- résultat :
-- verdict :

\echo '--- test 2 : f.ba lit v_mes_ruches'
SELECT code FROM v_mes_ruches;
-- résultat :
-- verdict :

\echo '--- test 3 : f.ba déclare une récolte sur sa ruche'
INSERT INTO v_mes_recoltes (ruche_id, date_recolte, volume_kg)
SELECT id, current_date, 7.7 FROM v_mes_ruches;
-- résultat :
-- verdict :

\echo '--- test 4 : f.ba déclare une récolte sur la ruche d une autre'
INSERT INTO v_mes_recoltes (ruche_id, date_recolte, volume_kg)
VALUES (:'ruche_autre', current_date, 5.0);
-- résultat :
-- verdict :

\echo '--- test 5 : f.ba déclare une récolte déjà validée'
INSERT INTO v_mes_recoltes (ruche_id, date_recolte, volume_kg, statut)
SELECT id, current_date, 5.0, 'validee' FROM v_mes_ruches;
-- résultat :
-- verdict :

\echo '--- test 6 : f.ba modifie un volume directement'
UPDATE recolte SET volume_kg = 99;
-- résultat :
-- verdict :

\echo '--- test 7 : f.ba appelle valider_recolte'
SELECT valider_recolte(gen_random_uuid());
-- résultat :
-- verdict :

\echo '--- test 8 : f.ba écrit une fausse ligne dans le journal'
INSERT INTO journal_audit (acteur, table_cible, operation)
VALUES ('coord.sn', 'recolte', 'UPDATE');
-- résultat :
-- verdict :

\echo '--- test 9 : f.ba désactive le trigger d audit'
ALTER TABLE recolte DISABLE TRIGGER recolte_audit;
-- résultat :
-- verdict :
RESET ROLE;

-- on récupère la récolte du test 3 pour le test 10
SELECT id AS recolte_fba FROM recolte WHERE volume_kg = 7.7 LIMIT 1 \gset

\echo '--- test 10 : coord.sn valide la récolte du test 3, puis la revalide'
SET ROLE "coord.sn";
SELECT valider_recolte(:'recolte_fba');
SELECT valider_recolte(:'recolte_fba');
-- résultat :
-- verdict :

\echo '--- test 11 : coord.sn valide une récolte d un autre site (CM-BAF)'
SELECT valider_recolte(:'recolte_cm');
-- résultat :
-- verdict :
RESET ROLE;

\echo '--- test 12 : admin.beeafrica lit le journal, puis supprime un utilisateur'
SET ROLE "admin.beeafrica";
SELECT acteur, table_cible, operation FROM journal_audit ORDER BY id;
DELETE FROM utilisateur WHERE login = 'awa.diop';
-- résultat :
-- verdict :
RESET ROLE;
