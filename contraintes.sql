-- ============================================================================
-- LAB 4 : Vérification des dépendances fonctionnelles et unicité des logins
-- ============================================================================

-- ----------------------------------------------------------------------------
-- ÉTAPE 4.3 : Confronter les dépendances aux données
-- ----------------------------------------------------------------------------

-- 1. Test des vraies dépendances fonctionnelles (Attendu : 0 ligne pour chacune)

-- DF 1 : site_id -> site_nom, pays
SELECT site_id, count(DISTINCT (site_nom, pays)) AS versions
FROM extrait_plat
GROUP BY site_id
HAVING count(DISTINCT (site_nom, pays)) > 1;
-- Résultat attendu : (0 rows)

-- DF 2 : ruche_code -> site_id, telephone
SELECT ruche_code, count(DISTINCT (site_id, telephone)) AS versions
FROM extrait_plat
GROUP BY ruche_code
HAVING count(DISTINCT (site_id, telephone)) > 1;
-- Résultat attendu : (0 rows)

-- DF 3 : telephone -> apicultrice, cooperative
SELECT telephone, count(DISTINCT (apicultrice, cooperative)) AS versions
FROM extrait_plat
GROUP BY telephone
HAVING count(DISTINCT (apicultrice, cooperative)) > 1;
-- Résultat attendu : (0 rows)

-- DF 4 : ruche_code, horodatage -> poids_kg, temp_int_c
SELECT ruche_code, horodatage, count(DISTINCT (poids_kg, temp_int_c)) AS versions
FROM extrait_plat
GROUP BY ruche_code, horodatage
HAVING count(DISTINCT (poids_kg, temp_int_c)) > 1;
-- Résultat attendu : (0 rows)


-- 2. Test de la fausse dépendance : apicultrice -> telephone
SELECT apicultrice, count(DISTINCT telephone) AS nb_telephones
FROM extrait_plat
GROUP BY apicultrice
HAVING count(DISTINCT telephone) > 1;
-- Résultat attendu : Aminata Diop | 2 (1 row)


-- ----------------------------------------------------------------------------
-- ÉTAPE 4.4 : Rendre les logins uniques
-- ----------------------------------------------------------------------------

-- Commande 1 : Afficher les logins en double (Attendu : a.diop, trois fois)
SELECT u.login, a.nom, a.site_id, a.telephone
FROM utilisateur u
LEFT JOIN apicultrice a ON a.id = u.apicultrice_id
WHERE u.login IN (
    SELECT login FROM utilisateur GROUP BY login HAVING count(*) > 1
)
ORDER BY u.login, a.site_id;

-- Commande 2 : Tenter de poser la contrainte UNIQUE (Attendu : ERROR / refus)
-- ALTER TABLE utilisateur ADD CONSTRAINT utilisateur_login_unique UNIQUE (login);
-- Résultat attendu : ERROR: could not create unique index "utilisateur_login_unique" (Key (login)=(a.diop) is duplicated)

-- Commande 3 : Corriger les doublons en donnant un login unique à chaque personne
-- (Exemple : on ajoute le suffixe du site ou le prénom complet pour les distinguer)
UPDATE utilisateur u
SET login = 'aminata.diop.' || lower(a.site_id)
FROM apicultrice a
WHERE a.id = u.apicultrice_id
  AND a.nom = 'Aminata Diop';

UPDATE utilisateur u
SET login = 'awa.diop'
FROM apicultrice a
WHERE a.id = u.apicultrice_id
  AND a.nom = 'Awa Diop';

-- Commande 4 : Poser la contrainte UNIQUE maintenant que les doublons sont corrigés (Attendu : ALTER TABLE)
ALTER TABLE utilisateur ADD CONSTRAINT utilisateur_login_unique UNIQUE (login);

-- Commande 5 : Le piège des majuscules (insérer 'A.Diop', puis le supprimer)
INSERT INTO utilisateur (login, role) VALUES ('A.Diop', 'apicultrice');
-- Résultat attendu : INSERT 0 1 (la majuscule contourne la contrainte UNIQUE classique !)

DELETE FROM utilisateur WHERE login = 'A.Diop';
-- Résultat attendu : DELETE 1

-- Commande 6 : Bloquer la casse avec un index unique sur lower(login)
CREATE UNIQUE INDEX utilisateur_login_ci ON utilisateur (lower(login));

-- Tester à nouveau l'insertion de 'A.Diop' (Attendu : ERROR / refus par utilisateur_login_ci)
-- INSERT INTO utilisateur (login, role) VALUES ('A.Diop', 'apicultrice');
-- Résultat attendu : ERROR: duplicate key value violates unique constraint "utilisateur_login_ci"

-- Question finale (STRIDE) : Quelles lettres STRIDE un login partagé permet-il ?
-- Réponse :
-- 1. S (Spoofing / Usurpation d'identité) : un utilisateur peut se connecter avec le login d'une autre personne portant le même identifiant.
-- 2. R (Repudiation / Répudiation) : impossible de prouver avec certitude qui a effectué une action (validation de récolte, modification) si plusieurs personnes partagent le même login.
/**  site_id | versions 
---------+----------
(0 ligne)

 ruche_code | versions 
------------+----------
(0 ligne)

 telephone | versions 
-----------+----------
(0 ligne)

 ruche_code | horodatage | versions 
------------+------------+----------
(0 ligne)

 apicultrice  | nb_telephones 
--------------+---------------
 Aminata Diop |             2
(1 ligne)

 login  |     nom      | site_id |     telephone     
--------+--------------+---------+-------------------
 a.diop | Aminata Diop | SN-CASA | +221 77 100 00 01
 a.diop | Awa Diop     | SN-CASA | +221 77 100 00 02
 a.diop | Aminata Diop | SN-KOLD | +221 77 200 00 03
(3 lignes)

UPDATE 2
UPDATE 1
ALTER TABLE
INSERT 0 1
DELETE 1
CREATE INDEX */