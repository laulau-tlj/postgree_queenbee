-- Génération de 90 jours de mesures toutes les 30 minutes (47 520 lignes pour 11 ruches)
INSERT INTO mesure (ruche_id, horodatage, poids_kg, temp_int_c, batterie_pct)
SELECT 
    r.id,
    TIMESTAMPTZ '2026-12-14 00:00:00+00' + (h * INTERVAL '30 minutes'),
    round((30 + random() * 5)::numeric, 2),
    round((34 + (random() - 0.5) * 2)::numeric, 1),
    90
FROM ruche r
CROSS JOIN generate_series(0, 90 * 48 - 1) AS h;

ANALYZE mesure;
