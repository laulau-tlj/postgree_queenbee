-- schema.sql : base Queen Bee (BeeAfrica)
DROP TABLE IF EXISTS alerte, recolte, inspection, mesure, adhesion, utilisateur,
  ruche, apicultrice, cooperative, site CASCADE;

-- 1. SITE : code lisible (court, stable, pas secret)
CREATE TABLE site (
  id   text PRIMARY KEY,                 -- 'SN-CASA'
  nom  text NOT NULL,
  pays text NOT NULL
);

-- 2. COOPERATIVE : une par site
CREATE TABLE cooperative (
  id      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nom     text NOT NULL,
  site_id text NOT NULL CONSTRAINT cooperative_site_fk REFERENCES site(id)
);

-- 3. APICULTRICE : rattachée à un site (donnée personnelle : téléphone)
CREATE TABLE apicultrice (
  id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nom       text NOT NULL,               -- pas unique : homonymes possibles
  telephone text NOT NULL,
  site_id   text NOT NULL CONSTRAINT apicultrice_site_fk REFERENCES site(id)
);

-- 4. RUCHE : le code est lisible mais l'identifiant exposé est un UUID
CREATE TABLE ruche (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nom               text NOT NULL CONSTRAINT ruche_nom_uq UNIQUE,  -- code lisible 'SN-CASA-014'
  latitude          numeric(8,5) NOT NULL CHECK (latitude  BETWEEN -90  AND 90),
  longitude         numeric(8,5) NOT NULL CHECK (longitude BETWEEN -180 AND 180),
  date_installation date NOT NULL,
  apicultrice_id    uuid NOT NULL CONSTRAINT ruche_apicultrice_fk REFERENCES apicultrice(id),
  site_id           text NOT NULL CONSTRAINT ruche_site_fk REFERENCES site(id)
);

-- 5. UTILISATEUR (compte de connexion) : 0,1 apicultrice <-> 0,1 compte
CREATE TABLE utilisateur (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  login          text NOT NULL,           -- unicité posée au lab 4
  role           text NOT NULL CHECK (role IN ('apicultrice','coordinateur','gestionnaire','administrateur')),
  site_id        text CONSTRAINT utilisateur_site_fk REFERENCES site(id),
  apicultrice_id uuid UNIQUE CONSTRAINT utilisateur_apicultrice_fk REFERENCES apicultrice(id)
);

-- 6. ADHESION : association n,n apicultrice <-> cooperative
CREATE TABLE adhesion (
  apicultrice_id uuid NOT NULL CONSTRAINT adhesion_apicultrice_fk REFERENCES apicultrice(id),
  cooperative_id uuid NOT NULL CONSTRAINT adhesion_cooperative_fk REFERENCES cooperative(id),
  date_adhesion  date NOT NULL DEFAULT current_date,
  PRIMARY KEY (apicultrice_id, cooperative_id)
);

-- 7. MESURE : un envoi toutes les 30 min ; UNIQUE = anti-rejeu
CREATE TABLE mesure (
  id             bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  ruche_id       uuid NOT NULL CONSTRAINT mesure_ruche_fk REFERENCES ruche(id),
  horodatage     timestamptz NOT NULL,
  poids_kg       numeric(5,2) CHECK (poids_kg >= 0),
  temp_int_c     numeric(4,1),
  temp_ext_c     numeric(4,1),
  humidite_pct   smallint CHECK (humidite_pct BETWEEN 0 AND 100),
  activite_sonore smallint CHECK (activite_sonore >= 0),
  batterie_pct   smallint CHECK (batterie_pct BETWEEN 0 AND 100),
  CONSTRAINT mesure_ruche_horodatage_uq UNIQUE (ruche_id, horodatage)
);

-- 8. INSPECTION
CREATE TABLE inspection (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ruche_id        uuid NOT NULL CONSTRAINT inspection_ruche_fk REFERENCES ruche(id),
  apicultrice_id  uuid NOT NULL CONSTRAINT inspection_apicultrice_fk REFERENCES apicultrice(id),
  date_inspection date NOT NULL,
  etat_colonie    text NOT NULL,
  presence_reine  boolean NOT NULL,
  observations    text
);

-- 9. RECOLTE : déclarée par l'apicultrice, validée par un compte (qui + quand)
CREATE TABLE recolte (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ruche_id      uuid NOT NULL CONSTRAINT recolte_ruche_fk REFERENCES ruche(id),
  date_recolte  date NOT NULL,
  quantite_kg   numeric(6,2) NOT NULL,
  statut        text NOT NULL DEFAULT 'declaree',
  validee_par   uuid CONSTRAINT recolte_validee_par_fk REFERENCES utilisateur(id),
  date_validation timestamptz,
  CONSTRAINT recolte_quantite_ck CHECK (quantite_kg >= 0),
  CONSTRAINT recolte_validation_ck CHECK (
    statut IN ('declaree','validee')
    AND ((statut = 'validee') = (validee_par IS NOT NULL AND date_validation IS NOT NULL))
    AND (statut = 'validee' OR (validee_par IS NULL AND date_validation IS NULL))
  )
);

-- 10. ALERTE : niveau de confiance entre 0 et 1
CREATE TABLE alerte (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ruche_id       uuid NOT NULL CONSTRAINT alerte_ruche_fk REFERENCES ruche(id),
  type_alerte    text NOT NULL CHECK (type_alerte IN ('essaimage','vol','capteur_silencieux')),
  niveau_confiance numeric(3,2) NOT NULL CONSTRAINT alerte_niveau_confiance_ck CHECK (niveau_confiance BETWEEN 0 AND 1),
  horodatage     timestamptz NOT NULL,
  statut         text NOT NULL DEFAULT 'ouverte' CHECK (statut IN ('ouverte','close'))
);
