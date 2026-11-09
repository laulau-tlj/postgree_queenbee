-- ============================================================================
-- LAB 5 (Étapes 5.2 et 5.3) : Découpage en 3NF/BCNF et preuve sans perte
-- ============================================================================

BEGIN;

DROP SCHEMA IF EXISTS norm CASCADE;
CREATE SCHEMA norm;

-- 1. Table norm.site (déterminant : site_id)
CREATE TABLE norm.site (
    site_id  text PRIMARY KEY,
    site_nom text NOT NULL,
    pays     text NOT NULL
);

-- 2. Table norm.apicultrice (déterminant : telephone)
CREATE TABLE norm.apicultrice (
    telephone   text PRIMARY KEY,
    apicultrice text NOT NULL,
    cooperative text NOT NULL
);

-- 3. Table norm.ruche (déterminant : ruche_code)
CREATE TABLE norm.ruche (
    ruche_code text PRIMARY KEY,
    site_id    text NOT NULL REFERENCES norm.site(site_id),
    telephone  text NOT NULL REFERENCES norm.apicultrice(telephone)
);

-- 4. Table norm.mesure (clé : ruche_code, horodatage)
CREATE TABLE norm.mesure (
    ruche_code text NOT NULL REFERENCES norm.ruche(ruche_code),
    horodatage timestamptz NOT NULL,
    poids_kg   numeric(5,2),
    temp_int_c numeric(4,1),
    PRIMARY KEY (ruche_code, horodatage)
);

-- Remplissage des 4 tables depuis extrait_plat
INSERT INTO norm.site
SELECT DISTINCT site_id, site_nom, pays FROM extrait_plat;

INSERT INTO norm.apicultrice
SELECT DISTINCT telephone, apicultrice, cooperative FROM extrait_plat;

INSERT INTO norm.ruche
SELECT DISTINCT ruche_code, site_id, telephone FROM extrait_plat;

INSERT INTO norm.mesure
SELECT ruche_code, horodatage, poids_kg, temp_int_c FROM extrait_plat;

COMMIT;

-- ============================================================================
-- ÉTAPE 5.3 : Preuve sans perte (Vue norm.reconstruit)
-- ============================================================================

CREATE OR REPLACE VIEW norm.reconstruit AS
SELECT
    r.ruche_code,
    s.site_id,
    s.site_nom,
    s.pays,
    a.apicultrice,
    a.telephone,
    a.cooperative,
    m.horodatage,
    m.poids_kg,
    m.temp_int_c
FROM norm.mesure m
JOIN norm.ruche r       USING (ruche_code)
JOIN norm.site s        USING (site_id)
JOIN norm.apicultrice a USING (telephone);


/** 
Tester le blocage, nettoyer, puis réussir la migration (Pages 38 et 39)
Premier lancement (sur les données corrompues) :
psql -U postgres -d queenbee -v ON_ERROR_STOP=1 -f migration_3nf.sql

Nettoyer les 2 anomalies dans extrait_plat (Page 39) :
Lancez ces deux commandes de réparation pour remettre 'Sénégal' et le vrai téléphone de l'apicultrice modifiée :bash
psql -U postgres -d queenbee -c "UPDATE extrait_plat SET pays = 'Sénégal' WHERE pays = 'Senegal';"
psql -U postgres -d queenbee -c "UPDATE extrait_plat SET telephone = (SELECT telephone FROM extrait_plat WHERE apicultrice = (SELECT apicultrice FROM extrait_plat WHERE telephone = '+221 77 999 99 99' LIMIT 1) AND telephone <> '+221 77 999 99 99' LIMIT 1) WHERE telephone = '+221 77 999 99 99';"

Relancer la migration proprement :
psql -U postgres -d queenbee -v ON_ERROR_STOP=1 -f migration_3nf.sql


Exécuter les 3 preuves finales
# 1. Preuve sans perte (Attendu : 0 ligne)
psql -U postgres -d queenbee -c "(SELECT * FROM extrait_plat EXCEPT SELECT * FROM norm.reconstruit) UNION ALL (SELECT * FROM norm.reconstruit EXCEPT SELECT * FROM extrait_plat);"

# 2. Rejouer les attaques :
# - Un second pays pour un site existant (Attendu : ERROR / refus)
psql -U postgres -d queenbee -c "INSERT INTO norm.site VALUES ('SN-CASA', 'Casamance', 'Senegal');"

# - Un site sans ruche (Attendu : INSERT 0 1 / accepté)
psql -U postgres -d queenbee -c "INSERT INTO norm.site VALUES ('CI-BOUA', 'Bouaké', 'Côte d''Ivoire');"

# 3. Relancer l'enquête par pays sur les tables norm (Attendu : 3 pays, car CI-BOUA n'a pas encore de mesure)
psql -U postgres -d queenbee -c "SELECT s.pays, count(*) AS nb_mesures, round(avg(m.poids_kg), 2) AS poids_moyen FROM norm.mesure m JOIN norm.ruche r USING (ruche_code) JOIN norm.site s USING (site_id) GROUP BY s.pays ORDER BY s.pays;"

*/ 

