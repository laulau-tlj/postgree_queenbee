-- roles.sql : groupes, personnes, droits minimum, vues par rôle, validation d'une récolte
-- (à lancer après audit.sql, qui crée qui())

-- 1. les groupes (les rôles sont communs à tout le serveur, donc on teste avant de créer)
DO $$
DECLARE g text;
BEGIN
  FOREACH g IN ARRAY ARRAY['qb_apicultrice', 'qb_coordinateur', 'qb_gestionnaire', 'qb_admin'] LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = g) THEN
      EXECUTE format('CREATE ROLE %I NOLOGIN', g);
    END IF;
  END LOOP;
END $$;

-- 2. les personnes (mots de passe de TP seulement)
DO $$
DECLARE p record;
BEGIN
  FOR p IN SELECT * FROM (VALUES
      ('f.ba',            'Ruche-fb-2027',    'qb_apicultrice'),
      ('awa.diop',        'Ruche-ad-2027',    'qb_apicultrice'),
      ('coord.sn',        'Ruche-cs-2027',    'qb_coordinateur'),
      ('gest.beeafrica',  'Ruche-gb-2027',    'qb_gestionnaire'),
      ('admin.beeafrica', 'Ruche-admin-2027', 'qb_admin')
    ) AS t(nom, mdp, groupe)
  LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = p.nom) THEN
      EXECUTE format('CREATE ROLE %I LOGIN PASSWORD %L IN ROLE %I', p.nom, p.mdp, p.groupe);
    END IF;
  END LOOP;
END $$;

-- le gestionnaire doit aussi exister dans utilisateur
INSERT INTO utilisateur (login, role)
SELECT 'gest.beeafrica', 'gestionnaire'
WHERE NOT EXISTS (SELECT 1 FROM utilisateur WHERE login = 'gest.beeafrica');

-- 3. tout fermer, puis ouvrir le minimum
-- (on ne retire pas TEMPORARY : le lab 10 en a besoin pour l'attaque)
REVOKE CONNECT ON DATABASE queenbee FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;

GRANT CONNECT ON DATABASE queenbee
  TO qb_apicultrice, qb_coordinateur, qb_gestionnaire, qb_admin;
GRANT USAGE ON SCHEMA public
  TO qb_apicultrice, qb_coordinateur, qb_gestionnaire, qb_admin;
GRANT EXECUTE ON FUNCTION qui()
  TO qb_apicultrice, qb_coordinateur, qb_gestionnaire, qb_admin;

-- 4. les vues : chacun ne voit que ses lignes
DROP VIEW IF EXISTS v_mes_recoltes, v_mes_mesures, v_mes_ruches,
                    v_recoltes_site, v_ruches_site, v_moi;

CREATE VIEW v_moi AS
SELECT id, login, role FROM utilisateur WHERE login = qui();

-- apicultrice
CREATE VIEW v_mes_ruches AS
SELECT r.id, r.code, r.site_id, r.latitude, r.longitude, r.date_installation
FROM ruche r
JOIN utilisateur u ON u.apicultrice_id = r.apicultrice_id
WHERE u.login = qui();

CREATE VIEW v_mes_mesures AS
SELECT m.*
FROM mesure m
WHERE m.ruche_id IN (SELECT id FROM v_mes_ruches);

CREATE VIEW v_mes_recoltes AS
SELECT rc.id, rc.ruche_id, rc.date_recolte, rc.volume_kg, rc.statut
FROM recolte rc
WHERE rc.ruche_id IN (SELECT id FROM v_mes_ruches)
WITH CHECK OPTION;

-- coordinateur : son site seulement
CREATE VIEW v_ruches_site AS
SELECT r.id, r.code, r.site_id, a.nom AS apicultrice, a.telephone
FROM ruche r
JOIN apicultrice a ON a.id = r.apicultrice_id
JOIN utilisateur u ON u.site_id = r.site_id
WHERE u.login = qui();

CREATE VIEW v_recoltes_site AS
SELECT rc.id, rc.ruche_id, rc.date_recolte, rc.volume_kg, rc.statut,
       rc.validee_par, rc.validee_le
FROM recolte rc
JOIN ruche r ON r.id = rc.ruche_id
JOIN utilisateur u ON u.site_id = r.site_id
WHERE u.login = qui();

-- 5. validation d'une récolte : le coordinateur n'a pas UPDATE sur recolte,
-- il passe par cette fonction qui ne change que le statut
CREATE OR REPLACE FUNCTION valider_recolte(p_recolte uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_coord utilisateur%ROWTYPE;
  n int;
BEGIN
  SELECT * INTO v_coord FROM utilisateur
  WHERE login = qui() AND role = 'coordinateur';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'réservé aux coordinateurs';
  END IF;

  UPDATE recolte rc
  SET statut = 'validee', validee_par = v_coord.id, validee_le = now()
  FROM ruche r
  WHERE rc.id = p_recolte
    AND rc.statut = 'declaree'
    AND r.id = rc.ruche_id
    AND r.site_id = v_coord.site_id;
  GET DIAGNOSTICS n = ROW_COUNT;

  IF n = 0 THEN
    RAISE EXCEPTION 'récolte introuvable, déjà traitée ou hors de votre site';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION valider_recolte(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION valider_recolte(uuid) TO qb_coordinateur;

-- 6. les droits (voir matrice_droits.md)
GRANT SELECT ON v_moi
  TO qb_apicultrice, qb_coordinateur, qb_gestionnaire, qb_admin;

GRANT SELECT ON v_mes_ruches, v_mes_mesures, v_mes_recoltes TO qb_apicultrice;
GRANT INSERT (ruche_id, date_recolte, volume_kg) ON v_mes_recoltes TO qb_apicultrice;

GRANT SELECT ON v_ruches_site, v_recoltes_site TO qb_coordinateur;

GRANT SELECT ON synthese_site_jour, v_export_bailleur TO qb_gestionnaire;

GRANT SELECT, INSERT, UPDATE ON utilisateur TO qb_admin;   -- pas de DELETE
GRANT SELECT ON journal_audit TO qb_admin;
