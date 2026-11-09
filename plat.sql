-- plat.sql : table dénormalisée pour analyser les dépendances fonctionnelles
DROP TABLE IF EXISTS extrait_plat;

CREATE TABLE extrait_plat AS
SELECT
    r.nom          AS ruche_code,
    s.id            AS site_id,
    s.nom           AS site_nom,
    s.pays,
    a.nom           AS apicultrice,
    a.telephone,
    c.nom           AS cooperative,
    m.horodatage,
    m.poids_kg,
    m.temp_int_c
FROM mesure m
JOIN ruche r         ON r.id = m.ruche_id
JOIN site s          ON s.id = r.site_id
JOIN apicultrice a   ON a.id = r.apicultrice_id
JOIN adhesion adh    ON adh.apicultrice_id = a.id
JOIN cooperative c   ON c.id = adh.cooperative_id;
