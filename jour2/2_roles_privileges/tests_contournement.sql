-- tests_contournement.sql
-- Pour chaque test : la commande, le résultat recopié en commentaire, puis "attendu" ou "problème".
-- Se lance en postgres ; SET ROLE fait agir la session comme l'utilisateur voulu.

-- préparation (en postgres, on range des identifiants que f.ba n'a pas le droit de lire)
SELECT id AS ruche_autre FROM ruche WHERE nom = 'SN-KOLD-011' \gset

INSERT INTO recolte (ruche_id, date_recolte, quantite_kg)
SELECT id, current_date, 6.6 FROM ruche WHERE nom LIKE 'CM-BAF%' LIMIT 1;
SELECT id AS recolte_cm FROM recolte WHERE quantite_kg = 6.6 LIMIT 1 \gset


\echo '--- test 1 : f.ba lit apicultrice directement'
SET ROLE "f.ba";
SELECT * FROM apicultrice;
-- résultat : ERREUR: droit refusé pour la table apicultrice
-- verdict : attendu

\echo '--- test 2 : f.ba lit v_mes_ruches'
SELECT nom FROM v_mes_ruches;
-- résultat : une seule ligne, SN-KOLD-012 (sa ruche uniquement)
-- verdict : attendu

\echo '--- test 3 : f.ba déclare une récolte sur sa ruche'
INSERT INTO v_mes_recoltes (ruche_id, date_recolte, quantite_kg)
SELECT id, current_date, 7.7 FROM v_mes_ruches;
-- résultat : INSERT 0 1
-- verdict : attendu

\echo '--- test 4 : f.ba déclare une récolte sur la ruche d une autre'
INSERT INTO v_mes_recoltes (ruche_id, date_recolte, quantite_kg)
VALUES (:'ruche_autre', current_date, 5.0);
-- résultat : ERREUR: la nouvelle ligne viole la contrainte de vérification pour la vue « v_mes_recoltes »
-- verdict : attendu (WITH CHECK OPTION bloque la ruche d'une autre apicultrice)

\echo '--- test 5 : f.ba déclare une récolte déjà validée'
INSERT INTO v_mes_recoltes (ruche_id, date_recolte, quantite_kg, statut)
SELECT id, current_date, 5.0, 'validee' FROM v_mes_ruches;
-- résultat : ERREUR: droit refusé pour la vue v_mes_recoltes
-- verdict : attendu (pas de GRANT INSERT sur la colonne statut : impossible de se valider soi-même)

\echo '--- test 6 : f.ba modifie un volume directement'
UPDATE recolte SET quantite_kg = 99;
-- résultat : ERREUR: droit refusé pour la table recolte
-- verdict : attendu

\echo '--- test 7 : f.ba appelle valider_recolte'
SELECT valider_recolte(gen_random_uuid());
-- résultat : ERREUR: droit refusé pour la fonction valider_recolte
-- verdict : attendu (EXECUTE réservé à qb_coordinateur)

\echo '--- test 8 : f.ba écrit une fausse ligne dans le journal'
INSERT INTO journal_audit (acteur, table_cible, operation)
VALUES ('coord.sn', 'recolte', 'UPDATE');
-- résultat : ERREUR: droit refusé pour la table journal_audit
-- verdict : attendu

\echo '--- test 9 : f.ba désactive le trigger d audit'
ALTER TABLE recolte DISABLE TRIGGER recolte_audit;
-- résultat : ERREUR: doit être le propriétaire de la table recolte
-- verdict : attendu
RESET ROLE;

-- on récupère la récolte du test 3 pour le test 10
SELECT id AS recolte_fba FROM recolte WHERE quantite_kg = 7.7 LIMIT 1 \gset

\echo '--- test 10 : coord.sn valide la récolte du test 3, puis la revalide'
SET ROLE "coord.sn";
SELECT valider_recolte(:'recolte_fba');
SELECT valider_recolte(:'recolte_fba');
-- résultat : 1er appel OK (1 ligne vide), 2e : ERREUR: récolte introuvable, déjà traitée ou hors de votre site
-- verdict : attendu (une récolte validée ne peut pas être revalidée)

\echo '--- test 11 : coord.sn valide une récolte d un autre site (CM-BAF)'
SELECT valider_recolte(:'recolte_cm');
-- résultat : ERREUR: récolte introuvable, déjà traitée ou hors de votre site
-- verdict : attendu (un coordinateur ne valide que les récoltes de son site)
RESET ROLE;

\echo '--- test 12 : admin.beeafrica lit le journal, puis supprime un utilisateur'
SET ROLE "admin.beeafrica";
SELECT acteur, table_cible, operation FROM journal_audit ORDER BY id;
DELETE FROM utilisateur WHERE login = 'awa.diop';
-- résultat : lecture du journal OK (8 lignes, acteurs réels : f.ba, coord.sn...),
--          puis ERREUR: droit refusé pour la table utilisateur
-- verdict : attendu (admin lit le journal, mais pas de DELETE sur utilisateur)
RESET ROLE;
