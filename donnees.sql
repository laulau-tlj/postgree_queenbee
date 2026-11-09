-- donnees.sql : jeu d'essai Queen Bee
BEGIN;

-- 4 sites, 3 pays, dont 2 au Sénégal
INSERT INTO site (id, nom, pays) VALUES
  ('SN-CASA', 'Casamance',  'Sénégal'),
  ('SN-KOLD', 'Kolda',      'Sénégal'),
  ('CI-BOUA', 'Bouaké',     'Côte d''Ivoire'),
  ('CM-BAFO', 'Bafoussam',  'Cameroun');

-- 1 coopérative par site
INSERT INTO cooperative (nom, site_id) VALUES
  ('Coopérative Miel de Casamance', 'SN-CASA'),
  ('Coopérative Abeilles de Kolda', 'SN-KOLD'),
  ('Coopérative Miel de Bouaké',    'CI-BOUA'),
  ('Coopérative Apicole de l''Ouest','CM-BAFO');

-- 8 apicultrices, dont deux « Aminata Diop » (sites différents) et une « Awa Diop »
INSERT INTO apicultrice (nom, telephone, site_id) VALUES
  ('Aminata Diop',   '+221 77 100 00 01', 'SN-CASA'),
  ('Awa Diop',       '+221 77 100 00 02', 'SN-CASA'),
  ('Aminata Diop',   '+221 77 200 00 03', 'SN-KOLD'),
  ('Fatou Sow',      '+221 77 200 00 04', 'SN-KOLD'),
  ('Adjoua Koffi',   '+225 07 00 00 00 05', 'CI-BOUA'),
  ('Mariam Traoré',  '+225 07 00 00 00 06', 'CI-BOUA'),
  ('Chantal Mbarga', '+237 6 70 00 00 07', 'CM-BAFO'),
  ('Esther Nkou',    '+237 6 70 00 00 08', 'CM-BAFO');

-- 11 ruches (nom = code lisible ; la ruche SN-CASA-099 ; Aminata Diop de Casamance et Adjoua Koffi en ont plusieurs)
INSERT INTO ruche (nom, latitude, longitude, date_installation, apicultrice_id, site_id) VALUES
  ('SN-CASA-014', 12.58300, -16.27200, '2025-03-10', (SELECT id FROM apicultrice WHERE telephone = '+221 77 100 00 01'), 'SN-CASA'),
  ('SN-CASA-015', 12.58350, -16.27250, '2025-03-10', (SELECT id FROM apicultrice WHERE telephone = '+221 77 100 00 01'), 'SN-CASA'),
  ('SN-CASA-099', 12.59000, -16.28000, '2025-06-02', (SELECT id FROM apicultrice WHERE telephone = '+221 77 100 00 02'), 'SN-CASA'),
  ('SN-KOLD-011', 12.88330, -14.95000, '2025-04-18', (SELECT id FROM apicultrice WHERE telephone = '+221 77 200 00 03'), 'SN-KOLD'),
  ('SN-KOLD-012', 12.88500, -14.95200, '2025-04-18', (SELECT id FROM apicultrice WHERE telephone = '+221 77 200 00 04'), 'SN-KOLD'),
  ('CI-BOUA-001',  7.69000,  -5.03000, '2025-05-05', (SELECT id FROM apicultrice WHERE telephone = '+225 07 00 00 00 05'), 'CI-BOUA'),
  ('CI-BOUA-002',  7.69100,  -5.03100, '2025-05-05', (SELECT id FROM apicultrice WHERE telephone = '+225 07 00 00 00 05'), 'CI-BOUA'),
  ('CI-BOUA-003',  7.70000,  -5.04000, '2025-07-21', (SELECT id FROM apicultrice WHERE telephone = '+225 07 00 00 00 06'), 'CI-BOUA'),
  ('CM-BAFO-001',  5.47700,  10.41800, '2025-02-14', (SELECT id FROM apicultrice WHERE telephone = '+237 6 70 00 00 07'), 'CM-BAFO'),
  ('CM-BAFO-002',  5.47800,  10.41900, '2025-02-14', (SELECT id FROM apicultrice WHERE telephone = '+237 6 70 00 00 07'), 'CM-BAFO'),
  ('CM-BAFO-003',  5.48500,  10.42500, '2025-08-30', (SELECT id FROM apicultrice WHERE telephone = '+237 6 70 00 00 08'), 'CM-BAFO');

-- chaque apicultrice adhère à la coopérative de son site
INSERT INTO adhesion (apicultrice_id, cooperative_id)
SELECT a.id, c.id FROM apicultrice a JOIN cooperative c ON c.site_id = a.site_id;

-- un compte par apicultrice : login « initiale.nom »
INSERT INTO utilisateur (login, role, site_id, apicultrice_id)
SELECT lower(left(nom, 1)) || '.' || lower(split_part(nom, ' ', 2)), 'apicultrice', site_id, id
FROM apicultrice;
-- un coordinateur et un administrateur
INSERT INTO utilisateur (login, role, site_id) VALUES
  ('coord.casa', 'coordinateur',   'SN-CASA'),
  ('admin',      'administrateur', NULL);

-- 48 mesures par ruche (toutes les 30 min pendant 24 h)
INSERT INTO mesure (ruche_id, horodatage, poids_kg, temp_int_c, temp_ext_c, humidite_pct, activite_sonore, batterie_pct)
SELECT r.id, TIMESTAMPTZ '2026-11-08 00:00+00' + h * INTERVAL '30 minutes',
       round((30 + random() * 20)::numeric, 2),
       round((33 + random() * 3)::numeric, 1),
       round((22 + random() * 12)::numeric, 1),
       50 + floor(random() * 30)::int,
       floor(random() * 100)::int,
       100 - h
FROM ruche r CROSS JOIN generate_series(0, 47) AS h;

-- 6 inspections (ruches jamais inspectées : SN-CASA-099, CI-BOUA-002/003, CM-BAFO-002/003)
INSERT INTO inspection (ruche_id, apicultrice_id, date_inspection, etat_colonie, presence_reine, observations)
SELECT r.id, r.apicultrice_id, d, etat, reine, obs
FROM (VALUES
  ('SN-CASA-014', DATE '2026-10-01', 'forte',  true,  'RAS'),
  ('SN-CASA-015', DATE '2026-10-01', 'moyenne',true,  'quelques cellules royales'),
  ('SN-KOLD-011', DATE '2026-10-05', 'forte',  true,  'bon couvain'),
  ('SN-KOLD-012', DATE '2026-10-05', 'faible', false, 'reine non vue'),
  ('CI-BOUA-001', DATE '2026-10-09', 'moyenne',true,  'varroa à surveiller'),
  ('CM-BAFO-001', DATE '2026-10-12', 'forte',  true,  'RAS')
) AS v(code, d, etat, reine, obs)
JOIN ruche r ON r.nom = v.code;

-- 3 récoltes : 2 déclarées, 1 validée (par le coordinateur, avec la date)
INSERT INTO recolte (ruche_id, date_recolte, quantite_kg, statut, validee_par, date_validation) VALUES
  ((SELECT id FROM ruche WHERE nom = 'SN-CASA-014'), '2026-10-20', 12.50, 'validee',
   (SELECT id FROM utilisateur WHERE login = 'coord.casa'), TIMESTAMPTZ '2026-10-22 09:30+00'),
  ((SELECT id FROM ruche WHERE nom = 'SN-KOLD-011'), '2026-10-25',  8.00, 'declaree', NULL, NULL),
  ((SELECT id FROM ruche WHERE nom = 'CI-BOUA-001'), '2026-11-02',  6.75, 'declaree', NULL, NULL);

-- 4 alertes, dont 2 ouvertes, sur 2 sites (SN-CASA et SN-KOLD)
INSERT INTO alerte (ruche_id, type_alerte, niveau_confiance, horodatage, statut) VALUES
  ((SELECT id FROM ruche WHERE nom = 'SN-CASA-014'), 'essaimage',          0.87, TIMESTAMPTZ '2026-11-08 06:00+00', 'ouverte'),
  ((SELECT id FROM ruche WHERE nom = 'SN-KOLD-011'), 'vol',                0.65, TIMESTAMPTZ '2026-11-08 02:30+00', 'ouverte'),
  ((SELECT id FROM ruche WHERE nom = 'CI-BOUA-001'), 'capteur_silencieux', 0.90, TIMESTAMPTZ '2026-11-05 14:00+00', 'close'),
  ((SELECT id FROM ruche WHERE nom = 'CM-BAFO-002'), 'essaimage',          0.55, TIMESTAMPTZ '2026-11-03 10:15+00', 'close');

COMMIT;
