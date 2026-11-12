-- check.sql : valeurs impossibles refusées par la base, quel que soit le programme

ALTER TABLE mesure
  ADD CONSTRAINT mesure_batterie_0_100 CHECK (batterie_pct BETWEEN 0 AND 100),
  ADD CONSTRAINT mesure_humidite_0_100 CHECK (humidite_pct BETWEEN 0 AND 100),
  ADD CONSTRAINT mesure_poids_positif  CHECK (poids_kg >= 0);

ALTER TABLE utilisateur
  ADD CONSTRAINT utilisateur_role_valide
  CHECK (role IN ('apicultrice', 'coordinateur', 'gestionnaire', 'administrateur'));

ALTER TABLE alerte
  ADD CONSTRAINT alerte_statut_valide
  CHECK (statut IN ('ouverte', 'close'));

ALTER TABLE recolte
  ADD CONSTRAINT recolte_statut_valide
  CHECK (statut IN ('declaree', 'validee', 'ecart'));

-- tests à faire à la main dans psql (ils sont refusés, donc pas dans le fichier) :
--   UPDATE mesure SET batterie_pct = 150 WHERE ctid = (SELECT ctid FROM mesure LIMIT 1);
--   UPDATE alerte SET statut = 'fermée' WHERE statut = 'traitee';
