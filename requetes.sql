-- requetes.sql : algèbre relationnelle et premières requêtes (Lab 3)
-- Lancement : psql -U postgres -d queenbee -v ON_ERROR_STOP=1 -f requetes.sql

-- Q1. Les ruches du site SN-CASA, avec leur position
-- Algèbre : π nom, latitude, longitude ( σ site_id = 'SN-CASA' ( ruche ) )
SELECT nom, latitude, longitude
FROM ruche
WHERE site_id = 'SN-CASA'
ORDER BY nom;
-- Résultat : 3 lignes

-- Q2. Chaque apicultrice et son nombre de ruches
-- Algèbre : apicultrice ⟕ (apicultrice.id = ruche.apicultrice_id) ruche, puis comptage par apicultrice.id
-- GROUP BY a.id : on compte par personne, pas par nom (les deux « Aminata Diop » restent séparées)
SELECT a.nom, a.site_id, count(r.id) AS nb_ruches
FROM apicultrice a
LEFT JOIN ruche r ON r.apicultrice_id = a.id
GROUP BY a.id, a.nom, a.site_id
ORDER BY nb_ruches DESC, a.nom, a.site_id;
-- Résultat : 8 lignes

-- Q3. Les ruches jamais inspectées
-- Algèbre : π nom ( ruche ⋈ ( π id ( ruche ) − π ruche_id ( inspection ) ) )
SELECT nom
FROM ruche
WHERE id IN (SELECT id FROM ruche EXCEPT SELECT ruche_id FROM inspection)
ORDER BY nom;
-- Résultat : 5 lignes

-- Q4. Les sites qui ont au moins une alerte ouverte (chaque site une seule fois)
-- Algèbre : π site_id ( σ statut = 'ouverte' ( alerte ) ⋈ (alerte.ruche_id = ruche.id) ruche )
SELECT DISTINCT r.site_id
FROM alerte al
JOIN ruche r ON r.id = al.ruche_id
WHERE al.statut = 'ouverte'
ORDER BY r.site_id;
-- Résultat : 2 lignes

-- Q5. Vue pour le coordinateur : code, site, dernière pesée, sans nom ni téléphone
-- Algèbre : π nom, site_id, poids_kg, horodatage ( ruche ⋈ dernière mesure de chaque ruche )
CREATE OR REPLACE VIEW v_ruche_coordinateur AS
SELECT r.nom AS code, r.site_id, m.poids_kg AS derniere_pesee_kg, m.horodatage AS pesee_le
FROM ruche r
JOIN LATERAL (
  SELECT poids_kg, horodatage FROM mesure
  WHERE ruche_id = r.id
  ORDER BY horodatage DESC LIMIT 1
) m ON true;

SELECT * FROM v_ruche_coordinateur ORDER BY code;
-- Résultat : 11 lignes (une par ruche)

-- Pourquoi une application ne doit-elle jamais faire SELECT * sur la table des apicultrices ?
-- SELECT * renvoie toutes les colonnes, y compris le téléphone (donnée personnelle), même
-- quand l'application n'en a pas besoin : il se retrouve dans l'application, les logs, l'écran.
-- Et si on ajoute plus tard une colonne sensible, elle sera exposée sans que personne ne
-- s'en rende compte. On ne sélectionne que les colonnes utiles (projection), ou on passe par
-- une vue comme v_ruche_coordinateur.
