-- tests_schema.sql : on joue l'attaquant (lancer SANS ON_ERROR_STOP)

-- Test 1 : une ruche dont l'apicultrice n'existe pas. Attendu : refus
INSERT INTO ruche (nom, latitude, longitude, date_installation, apicultrice_id, site_id)
VALUES ('SN-CASA-777', 12.5, -16.2, current_date, gen_random_uuid(), 'SN-CASA');
-- OBTENU : refus.
-- ERROR:  insert or update on table "ruche" violates foreign key constraint "ruche_apicultrice_fk"
-- DETAIL:  Key (apicultrice_id)=(...) is not present in table "apicultrice".

-- Test 2 : supprimer une apicultrice qui a des ruches. Attendu : refus
DELETE FROM apicultrice WHERE telephone = '+221 77 100 00 01';
-- OBTENU : refus.
-- ERROR:  update or delete on table "apicultrice" violates foreign key constraint "ruche_apicultrice_fk" on table "ruche"
-- DETAIL:  Key (id)=(...) is still referenced from table "ruche".

-- Test 3 : une ruche sans apicultrice. Attendu : refus
INSERT INTO ruche (nom, latitude, longitude, date_installation, apicultrice_id, site_id)
VALUES ('SN-CASA-778', 12.5, -16.2, current_date, NULL, 'SN-CASA');
-- OBTENU : refus (règle NOT NULL).
-- ERROR:  null value in column "apicultrice_id" of relation "ruche" violates not-null constraint

-- Test 4 : une table SANS clé étrangère : la ruche orpheline est acceptée,
-- mais disparaît dès qu'on la joint aux apicultrices. Attendu : accepté, puis 0 ligne
DROP TABLE IF EXISTS ruche_sans_fk;
CREATE TABLE ruche_sans_fk (id serial PRIMARY KEY, code text, apicultrice_id uuid);
INSERT INTO ruche_sans_fk (code, apicultrice_id) VALUES ('ORPHELINE-1', gen_random_uuid());
SELECT r.code FROM ruche_sans_fk r JOIN apicultrice a ON a.id = r.apicultrice_id;  -- 0 ligne
-- OBTENU : INSERT 0 1 (accepté), puis (0 rows) : l'orpheline est acceptée, puis invisible dans la jointure.
DROP TABLE ruche_sans_fk;

-- Test 5 : id serial : devinable. Attendu : 1, 2, 3
DROP TABLE IF EXISTS test_serial;
CREATE TABLE test_serial (id serial PRIMARY KEY, code text);
INSERT INTO test_serial (code) VALUES ('a'), ('b'), ('c');
SELECT * FROM test_serial;
-- OBTENU : id = 1, 2, 3. Un attaquant qui voit /ruches/2 essaie /ruches/3 : devinable. D'où l'UUID.
DROP TABLE test_serial;

-- Test 6 : une mesure déjà reçue (même ruche, même instant). Attendu : refus
INSERT INTO mesure (ruche_id, horodatage, poids_kg)
SELECT ruche_id, horodatage, 30.0 FROM mesure LIMIT 1;
-- OBTENU : refus (anti-rejeu).
-- ERROR:  duplicate key value violates unique constraint "mesure_ruche_horodatage_uq"
-- DETAIL:  Key (ruche_id, horodatage)=(..., 2026-11-08 00:00:00+00) already exists.

-- Test 7 : les ruches dont le site diffère de celui de leur apicultrice
-- Hypothèse du lab 1 : une ruche est installée sur le site de son apicultrice,
-- mais le schéma ne l'impose pas (deux colonnes site_id) : c'est un contrôle à faire.
-- Attendu : 0 ligne tant que les données sont cohérentes
SELECT r.nom, r.site_id AS site_ruche, a.site_id AS site_apicultrice
FROM ruche r JOIN apicultrice a ON a.id = r.apicultrice_id
WHERE r.site_id <> a.site_id;
-- OBTENU : (0 rows). Les données sont cohérentes, mais c'est le jeu d'essai qui le garantit, pas le schéma.

-- Test 8 : passer une récolte « déclarée » à « validée » sans validateur. Attendu : refus
UPDATE recolte SET statut = 'validee' WHERE statut = 'declaree';
-- OBTENU : refus.
-- ERROR:  new row for relation "recolte" violates check constraint "recolte_validation_ck"

-- Bonus : niveau de confiance hors bornes, volume négatif
INSERT INTO alerte (ruche_id, type_alerte, niveau_confiance, horodatage)
SELECT id, 'vol', 1.7, now() FROM ruche LIMIT 1;
-- OBTENU : refus. ERROR:  new row for relation "alerte" violates check constraint "alerte_niveau_confiance_ck"
INSERT INTO recolte (ruche_id, date_recolte, quantite_kg)
SELECT id, current_date, -5 FROM ruche LIMIT 1;
-- OBTENU : refus. ERROR:  new row for relation "recolte" violates check constraint "recolte_quantite_ck"

-- QUESTION : un UUID suffit-il à protéger la ruche d'une autre apicultrice ?
-- NON. Un UUID est impossible à deviner, mais ce n'est pas un contrôle d'accès : s'il fuit
-- (log, lien partagé, capture d'écran), n'importe qui peut l'utiliser. Il faut en plus vérifier
-- côté serveur que la ruche demandée appartient à l'utilisateur connecté
-- (WHERE r.id = %s AND r.apicultrice_id = <apicultrice du compte connecté>).
-- L'UUID réduit le risque d'énumération (IDOR) ; il ne remplace pas l'autorisation.
