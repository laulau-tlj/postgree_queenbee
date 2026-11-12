-- 1. Réécriture sécurisée de v_carte_ruches : sans téléphone, filtrée sur l'utilisateur connecté et avec security_barrier
DROP VIEW IF EXISTS v_carte_ruches;

CREATE VIEW v_carte_ruches WITH (security_barrier = true) AS
SELECT r.nom AS code, r.latitude, r.longitude, a.nom
FROM ruche r
JOIN apicultrice a ON a.id = r.apicultrice_id
JOIN utilisateur u ON u.apicultrice_id = a.id
WHERE u.login = current_user;

GRANT SELECT ON v_carte_ruches TO qb_apicultrice;

-- 2. Activation de security_barrier sur toutes vos vues filtrantes
ALTER VIEW IF EXISTS v_mes_ruches SET (security_barrier = true);
ALTER VIEW IF EXISTS v_mes_mesures SET (security_barrier = true);
ALTER VIEW IF EXISTS v_mes_recoltes SET (security_barrier = true);
ALTER VIEW IF EXISTS v_moi SET (security_barrier = true);

-- 3. Interdiction de créer des tables ou fonctions temporaires
REVOKE TEMPORARY ON DATABASE queenbee FROM PUBLIC;

-- 4. Droits et isolement RLS sur ruche et recolte pour qb_apicultrice
GRANT SELECT ON ruche TO qb_apicultrice;
GRANT SELECT, INSERT ON recolte TO qb_apicultrice;

ALTER TABLE recolte ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS recolte_apicultrice_isolement ON recolte;
CREATE POLICY recolte_apicultrice_isolement ON recolte
    FOR ALL TO qb_apicultrice
    USING (ruche_id IN (
        SELECT r.id FROM ruche r
        JOIN utilisateur u ON u.apicultrice_id = r.apicultrice_id
        WHERE u.login = current_user
    ))
    WITH CHECK (ruche_id IN (
        SELECT r.id FROM ruche r
        JOIN utilisateur u ON u.apicultrice_id = r.apicultrice_id
        WHERE u.login = current_user
    ));

-- Autoriser la lecture des colonnes d'identification pour évaluer les politiques RLS
GRANT SELECT (id, login, apicultrice_id) ON utilisateur TO qb_apicultrice;

-- 5. Aligner les logins applicatifs avec les rôles de connexion (constat R1)
-- les rôles créés dans roles.sql doivent trouver leur ligne dans utilisateur
UPDATE utilisateur SET login = 'f.ba'
WHERE login = 'f.sow';   -- Fatou, propriétaire de SN-KOLD-012

UPDATE utilisateur SET login = 'awa.diop'
WHERE apicultrice_id = (SELECT id FROM apicultrice WHERE nom = 'Awa Diop');

INSERT INTO utilisateur (login, role, site_id)
SELECT 'coord.sn', 'coordinateur', 'SN-KOLD'
WHERE NOT EXISTS (SELECT 1 FROM utilisateur WHERE login = 'coord.sn');

INSERT INTO utilisateur (login, role)
SELECT 'admin.beeafrica', 'administrateur'
WHERE NOT EXISTS (SELECT 1 FROM utilisateur WHERE login = 'admin.beeafrica');
