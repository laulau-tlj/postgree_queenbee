-- references.sql : que devient une ligne liée quand on supprime la ligne référencée
-- (les noms des contraintes sont ceux de notre schéma du jour 1, vérifiés avec pg_constraint)

-- adhesion : le lien n'a pas de valeur tout seul, il part avec l'apicultrice ou le groupement
ALTER TABLE adhesion
  DROP CONSTRAINT adhesion_apicultrice_id_fkey,
  ADD CONSTRAINT adhesion_apicultrice_id_fkey FOREIGN KEY (apicultrice_id)
      REFERENCES apicultrice (id) ON DELETE CASCADE;

ALTER TABLE adhesion
  DROP CONSTRAINT adhesion_groupement_id_fkey,
  ADD CONSTRAINT adhesion_groupement_id_fkey FOREIGN KEY (groupement_id)
      REFERENCES groupement (id) ON DELETE CASCADE;

-- mesure : ce sont des preuves (poids, vol), on ne doit pas pouvoir les effacer en supprimant une ruche
ALTER TABLE mesure
  DROP CONSTRAINT mesure_ruche_fk,
  ADD CONSTRAINT mesure_ruche_fk FOREIGN KEY (ruche_id)
      REFERENCES ruche (id) ON DELETE RESTRICT;

-- inspection : trace de ce qui a été constaté sur la ruche, à garder
ALTER TABLE inspection
  DROP CONSTRAINT inspection_ruche_fk,
  ADD CONSTRAINT inspection_ruche_fk FOREIGN KEY (ruche_id)
      REFERENCES ruche (id) ON DELETE RESTRICT;

-- recolte : preuve de production (UC-C02), on la garde
ALTER TABLE recolte
  DROP CONSTRAINT recolte_ruche_fk,
  ADD CONSTRAINT recolte_ruche_fk FOREIGN KEY (ruche_id)
      REFERENCES ruche (id) ON DELETE RESTRICT;

-- alerte : une alerte de vol doit rester même si la ruche est retirée
ALTER TABLE alerte
  DROP CONSTRAINT alerte_ruche_fk,
  ADD CONSTRAINT alerte_ruche_fk FOREIGN KEY (ruche_id)
      REFERENCES ruche (id) ON DELETE RESTRICT;

-- vérification : 2 CASCADE et 4 RESTRICT attendus, le reste en NO ACTION
SELECT conrelid::regclass AS table_, conname,
       CASE confdeltype WHEN 'a' THEN 'NO ACTION' WHEN 'r' THEN 'RESTRICT'
            WHEN 'c' THEN 'CASCADE' WHEN 'n' THEN 'SET NULL' END AS on_delete
FROM pg_constraint
WHERE contype = 'f' AND connamespace = 'public'::regnamespace
ORDER BY on_delete, 1;
