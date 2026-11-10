-- formation.sql : formations des apicultrices (Lab 6)
DROP TABLE IF EXISTS suivi_formation, formateur, formation_plat CASCADE;

-- Étape 6.1 : le tableau reçu du centre de formation
CREATE TABLE formation_plat (
  telephone  text NOT NULL,
  theme      text NOT NULL,
  formateur  text NOT NULL,
  PRIMARY KEY (telephone, theme)
);

-- 4 numéros du tableau n'existaient pas dans notre base (INSERT 0 3 au lieu de 8 à l'étape 6.2) :
-- on les a remplacés par les numéros de nos apicultrices.
INSERT INTO formation_plat (telephone, theme, formateur) VALUES
  ('+221 77 100 00 01', 'varroa',   'Moussa Sarr'),
  ('+221 77 100 00 01', 'recolte',  'Khady Ndiaye'),
  ('+221 77 100 00 02', 'varroa',   'Moussa Sarr'),
  ('+221 77 200 00 03', 'varroa',   'Ibrahima Fall'),
  ('+221 77 200 00 03', 'capteurs', 'Oumar Diallo'),
  ('+225 07 00 00 00 05', 'varroa',   'Kouassi Yao'),
  ('+225 07 00 00 00 06', 'capteurs', 'Oumar Diallo'),
  ('+237 6 70 00 00 07', 'recolte',  'Khady Ndiaye');

-- Étape 6.2 : le découpage BCNF
-- formateur -> theme : un formateur n'enseigne qu'un seul thème
CREATE TABLE formateur (
  id     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nom    text NOT NULL UNIQUE,
  theme  text NOT NULL CHECK (theme IN ('varroa', 'recolte', 'capteurs'))
);

CREATE TABLE suivi_formation (
  apicultrice_id  uuid NOT NULL REFERENCES apicultrice (id),
  formateur_id    uuid NOT NULL REFERENCES formateur (id),
  PRIMARY KEY (apicultrice_id, formateur_id)
);

INSERT INTO formateur (nom, theme)
SELECT DISTINCT formateur, theme FROM formation_plat;

-- l'apicultrice est retrouvée par son téléphone
INSERT INTO suivi_formation (apicultrice_id, formateur_id)
SELECT a.id, f.id
FROM formation_plat p
JOIN apicultrice a ON a.telephone = p.telephone
JOIN formateur f   ON f.nom = p.formateur;

-- Étape 6.3 : le trigger qui rétablit la règle perdue
-- (une apicultrice n'a qu'un seul formateur par thème)
CREATE OR REPLACE FUNCTION suivi_un_formateur_par_theme() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM suivi_formation s
    JOIN formateur f ON f.id = s.formateur_id
    WHERE s.apicultrice_id = NEW.apicultrice_id          -- même apicultrice
      AND s.formateur_id <> NEW.formateur_id             -- un autre formateur
      AND f.theme = (SELECT theme FROM formateur WHERE id = NEW.formateur_id)  -- même thème
  ) THEN
    RAISE EXCEPTION 'DF violée : cette apicultrice a déjà un formateur pour ce thème';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER suivi_formation_df
BEFORE INSERT OR UPDATE ON suivi_formation
FOR EACH ROW EXECUTE FUNCTION suivi_un_formateur_par_theme();
