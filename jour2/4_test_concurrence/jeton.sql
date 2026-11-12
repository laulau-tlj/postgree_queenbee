DROP TABLE IF EXISTS session_app, jeton CASCADE;

CREATE TABLE jeton (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    utilisateur_id uuid NOT NULL REFERENCES utilisateur(id) ON DELETE CASCADE,
    valeur text NOT NULL UNIQUE,
    expire_le timestamptz NOT NULL DEFAULT (now() + interval '1 day'),
    utilise_le timestamptz NULL
);

CREATE TABLE session_app (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    utilisateur_id uuid NOT NULL REFERENCES utilisateur(id) ON DELETE CASCADE,
    jeton_id uuid NOT NULL UNIQUE REFERENCES jeton(id) ON DELETE CASCADE,
    ouverte_le timestamptz NOT NULL DEFAULT clock_timestamp()
);

-- Génération des 30 jetons de test pour l'apicultrice f.ba (RT-f.ba-1 à RT-f.ba-30)
INSERT INTO jeton (utilisateur_id, valeur)
SELECT u.id, 'RT-f.sow-' || i
FROM generate_series(1, 30) AS i
CROSS JOIN utilisateur u
WHERE u.login = 'f.sow';
