-- ============================================================================
-- LAB 5 (Étape 5.1) : Provoquer les trois anomalies dans extrait_plat
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. ANOMALIE DE MISE À JOUR (Page 36)
-- ----------------------------------------------------------------------------

-- Enquête de référence : nombre de mesures et poids moyen par pays (Attendu : 3 pays)
SELECT pays, count(*) AS nb_mesures, round(avg(poids_kg), 2) AS poids_moyen
FROM extrait_plat
GROUP BY pays
ORDER BY pays;

-- Modification d'une seule ligne : 'Sénégal' devient 'Senegal' (sans accent)
-- Note : si 'SN-KOLD-011' n'existe pas dans votre jeu d'essai, remplacez par un code ruche du Sénégal présent dans extrait_plat
UPDATE extrait_plat
SET pays = 'Senegal'
WHERE ruche_code = (SELECT ruche_code FROM extrait_plat WHERE pays = 'Sénégal' LIMIT 1)
  AND horodatage = (SELECT min(horodatage) FROM extrait_plat WHERE pays = 'Sénégal');

-- Modification du téléphone d'une apicultrice sur une seule ligne
UPDATE extrait_plat
SET telephone = '+221 77 999 99 99'
WHERE ruche_code = (SELECT ruche_code FROM extrait_plat WHERE pays = 'Sénégal' LIMIT 1)
  AND horodatage = (SELECT max(horodatage) FROM extrait_plat WHERE pays = 'Sénégal');

-- Relancer l'enquête par pays (Attendu : 4 pays au lieu de 3 !)
SELECT pays, count(*) AS nb_mesures, round(avg(poids_kg), 2) AS poids_moyen
FROM extrait_plat
GROUP BY pays
ORDER BY pays;


-- ----------------------------------------------------------------------------
-- 2. ANOMALIE DE SUPPRESSION (Page 37)
-- ----------------------------------------------------------------------------
BEGIN;

-- Supprimer toutes les mesures d'une apicultrice qui n'a qu'une seule ruche
DELETE FROM extrait_plat
WHERE apicultrice = 'Awa Diop';

-- Chercher son téléphone : il a complètement disparu de la base ! (Attendu : 0 ligne)
SELECT DISTINCT apicultrice, telephone
FROM extrait_plat
WHERE apicultrice = 'Awa Diop';

ROLLBACK;


-- ----------------------------------------------------------------------------
-- 3. ANOMALIE D'INSERTION (Page 37)
-- ----------------------------------------------------------------------------

-- Poser la clé primaire candidate (ruche_code, horodatage)
ALTER TABLE extrait_plat ADD PRIMARY KEY (ruche_code, horodatage);

-- Essayer d'ajouter un nouveau site sans ruche ni mesure (Attendu : ERROR / refus)
INSERT INTO extrait_plat (site_id, site_nom, pays)
VALUES ('CI-BOUA', 'Bouaké', 'Côte d''Ivoire');


/**
Resultat obtenu :
     pays      | nb_mesures | poids_moyen 
---------------+------------+-------------
 Cameroun      |        144 |       39.87
 Côte d'Ivoire |        144 |       39.72
 Sénégal       |        240 |       40.13
(3 lignes)

UPDATE 1
UPDATE 1
     pays      | nb_mesures | poids_moyen 
---------------+------------+-------------
 Cameroun      |        144 |       39.87
 Côte d'Ivoire |        144 |       39.72
 Senegal       |          1 |       30.96
 Sénégal       |        239 |       40.17
(4 lignes)

BEGIN
DELETE 48
 apicultrice | telephone 
-------------+-----------
(0 ligne)

ROLLBACK
ALTER TABLE
psql:anomalies.sql:61: ERROR:  null value in column "ruche_code" of relation "extrait_plat" violates not-null constraint
DÉTAIL : Failing row contains (null, CI-BOUA, Bouaké, Côte d'Ivoire, null, null, null, null, null, null).*/