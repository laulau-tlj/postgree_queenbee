--
-- PostgreSQL database dump
--

\restrict Y9iLwCXuidnOv3L2OEt5KSNIvd7hQnPiQsN9C2u8DnmchLpsaV09RWiX9VnO4Vz

-- Dumped from database version 18.6
-- Dumped by pg_dump version 18.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: audit_ligne(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.audit_ligne() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
  INSERT INTO journal_audit (acteur, table_cible, operation, ligne_id, avant, apres)
  VALUES (qui(), TG_TABLE_NAME, TG_OP,
          CASE WHEN TG_OP = 'DELETE' THEN OLD.id::text ELSE NEW.id::text END,
          CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD) END,
          CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN to_jsonb(NEW) END);
  RETURN NULL;
END;
$$;


ALTER FUNCTION public.audit_ligne() OWNER TO postgres;

--
-- Name: journal_interdit(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.journal_interdit() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'journal_audit est en ajout seul : % interdit', TG_OP;
END;
$$;


ALTER FUNCTION public.journal_interdit() OWNER TO postgres;

--
-- Name: qui(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.qui() RETURNS text
    LANGUAGE sql STABLE
    AS $$
  SELECT CASE WHEN current_setting('role') = 'none' THEN session_user::text
              ELSE current_setting('role') END
$$;


ALTER FUNCTION public.qui() OWNER TO postgres;

--
-- Name: suivi_un_formateur_par_theme(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.suivi_un_formateur_par_theme() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM suivi_formation s
    JOIN formateur f ON f.id = s.formateur_id
    WHERE s.apicultrice_id = NEW.apicultrice_id          -- mÃªme apicultrice
      AND s.formateur_id <> NEW.formateur_id             -- un autre formateur
      AND f.theme = (SELECT theme FROM formateur WHERE id = NEW.formateur_id)  -- mÃªme thÃ¨me
  ) THEN
    RAISE EXCEPTION 'DF violÃ©e : cette apicultrice a dÃ©jÃ  un formateur pour ce thÃ¨me';
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.suivi_un_formateur_par_theme() OWNER TO postgres;

--
-- Name: valider_recolte(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.valider_recolte(p_recolte uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_coord utilisateur%ROWTYPE;
  n int;
BEGIN
  SELECT * INTO v_coord FROM utilisateur
  WHERE login = qui() AND role = 'coordinateur';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'rÃ©servÃ© aux coordinateurs';
  END IF;

  UPDATE recolte rc
  SET statut = 'validee', validee_par = v_coord.id, date_validation = now()
  FROM ruche r
  WHERE rc.id = p_recolte
    AND rc.statut = 'declaree'
    AND r.id = rc.ruche_id
    AND r.site_id = v_coord.site_id;
  GET DIAGNOSTICS n = ROW_COUNT;

  IF n = 0 THEN
    RAISE EXCEPTION 'rÃ©colte introuvable, dÃ©jÃ  traitÃ©e ou hors de votre site';
  END IF;
END;
$$;


ALTER FUNCTION public.valider_recolte(p_recolte uuid) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: adhesion; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.adhesion (
    apicultrice_id uuid NOT NULL,
    cooperative_id uuid NOT NULL,
    date_adhesion date DEFAULT CURRENT_DATE NOT NULL
);


ALTER TABLE public.adhesion OWNER TO postgres;

--
-- Name: alerte; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.alerte (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ruche_id uuid NOT NULL,
    type_alerte text NOT NULL,
    niveau_confiance numeric(3,2) NOT NULL,
    horodatage timestamp with time zone NOT NULL,
    statut text DEFAULT 'ouverte'::text NOT NULL,
    CONSTRAINT alerte_niveau_confiance_ck CHECK (((niveau_confiance >= (0)::numeric) AND (niveau_confiance <= (1)::numeric))),
    CONSTRAINT alerte_statut_check CHECK ((statut = ANY (ARRAY['ouverte'::text, 'close'::text]))),
    CONSTRAINT alerte_statut_valide CHECK ((statut = ANY (ARRAY['ouverte'::text, 'close'::text]))),
    CONSTRAINT alerte_type_alerte_check CHECK ((type_alerte = ANY (ARRAY['essaimage'::text, 'vol'::text, 'capteur_silencieux'::text])))
);


ALTER TABLE public.alerte OWNER TO postgres;

--
-- Name: apicultrice; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.apicultrice (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nom text NOT NULL,
    telephone text NOT NULL,
    site_id text NOT NULL
);


ALTER TABLE public.apicultrice OWNER TO postgres;

--
-- Name: cle_pseudonymisation; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cle_pseudonymisation (
    id integer NOT NULL,
    cle text NOT NULL,
    CONSTRAINT cle_pseudonymisation_id_check CHECK ((id = 1))
);


ALTER TABLE public.cle_pseudonymisation OWNER TO postgres;

--
-- Name: cooperative; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cooperative (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nom text NOT NULL,
    site_id text NOT NULL
);


ALTER TABLE public.cooperative OWNER TO postgres;

--
-- Name: formateur; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.formateur (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nom text NOT NULL,
    theme text NOT NULL,
    CONSTRAINT formateur_theme_check CHECK ((theme = ANY (ARRAY['varroa'::text, 'recolte'::text, 'capteurs'::text])))
);


ALTER TABLE public.formateur OWNER TO postgres;

--
-- Name: formation_plat; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.formation_plat (
    telephone text NOT NULL,
    theme text NOT NULL,
    formateur text NOT NULL
);


ALTER TABLE public.formation_plat OWNER TO postgres;

--
-- Name: inspection; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.inspection (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ruche_id uuid NOT NULL,
    apicultrice_id uuid NOT NULL,
    date_inspection date NOT NULL,
    etat_colonie text NOT NULL,
    presence_reine boolean NOT NULL,
    observations text
);


ALTER TABLE public.inspection OWNER TO postgres;

--
-- Name: jeton; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.jeton (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    utilisateur_id uuid NOT NULL,
    valeur text NOT NULL,
    expire_le timestamp with time zone DEFAULT (now() + '1 day'::interval) NOT NULL,
    utilise_le timestamp with time zone
);


ALTER TABLE public.jeton OWNER TO postgres;

--
-- Name: journal_audit; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.journal_audit (
    id bigint NOT NULL,
    horodatage timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    acteur text NOT NULL,
    table_cible text NOT NULL,
    operation text NOT NULL,
    ligne_id text,
    avant jsonb,
    apres jsonb,
    CONSTRAINT journal_audit_operation_check CHECK ((operation = ANY (ARRAY['INSERT'::text, 'UPDATE'::text, 'DELETE'::text])))
);


ALTER TABLE public.journal_audit OWNER TO postgres;

--
-- Name: journal_audit_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.journal_audit ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.journal_audit_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: mesure; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.mesure (
    id bigint NOT NULL,
    ruche_id uuid NOT NULL,
    horodatage timestamp with time zone NOT NULL,
    poids_kg numeric(5,2),
    temp_int_c numeric(4,1),
    temp_ext_c numeric(4,1),
    humidite_pct smallint,
    activite_sonore smallint,
    batterie_pct smallint,
    CONSTRAINT mesure_activite_sonore_check CHECK ((activite_sonore >= 0)),
    CONSTRAINT mesure_batterie_0_100 CHECK (((batterie_pct >= 0) AND (batterie_pct <= 100))),
    CONSTRAINT mesure_batterie_pct_check CHECK (((batterie_pct >= 0) AND (batterie_pct <= 100))),
    CONSTRAINT mesure_humidite_0_100 CHECK (((humidite_pct >= 0) AND (humidite_pct <= 100))),
    CONSTRAINT mesure_humidite_pct_check CHECK (((humidite_pct >= 0) AND (humidite_pct <= 100))),
    CONSTRAINT mesure_poids_kg_check CHECK ((poids_kg >= (0)::numeric)),
    CONSTRAINT mesure_poids_positif CHECK ((poids_kg >= (0)::numeric))
);


ALTER TABLE public.mesure OWNER TO postgres;

--
-- Name: mesure_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.mesure ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.mesure_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: recolte; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.recolte (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ruche_id uuid NOT NULL,
    date_recolte date NOT NULL,
    quantite_kg numeric(6,2) NOT NULL,
    statut text DEFAULT 'declaree'::text NOT NULL,
    validee_par uuid,
    date_validation timestamp with time zone,
    CONSTRAINT recolte_quantite_ck CHECK ((quantite_kg >= (0)::numeric)),
    CONSTRAINT recolte_statut_valide CHECK ((statut = ANY (ARRAY['declaree'::text, 'validee'::text, 'ecart'::text]))),
    CONSTRAINT recolte_validation_ck CHECK (((statut = ANY (ARRAY['declaree'::text, 'validee'::text])) AND ((statut = 'validee'::text) = ((validee_par IS NOT NULL) AND (date_validation IS NOT NULL))) AND ((statut = 'validee'::text) OR ((validee_par IS NULL) AND (date_validation IS NULL)))))
);


ALTER TABLE public.recolte OWNER TO postgres;

--
-- Name: ruche; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ruche (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nom text NOT NULL,
    latitude numeric(8,5) NOT NULL,
    longitude numeric(8,5) NOT NULL,
    date_installation date NOT NULL,
    apicultrice_id uuid NOT NULL,
    site_id text NOT NULL,
    CONSTRAINT ruche_latitude_check CHECK (((latitude >= ('-90'::integer)::numeric) AND (latitude <= (90)::numeric))),
    CONSTRAINT ruche_longitude_check CHECK (((longitude >= ('-180'::integer)::numeric) AND (longitude <= (180)::numeric)))
);


ALTER TABLE public.ruche OWNER TO postgres;

--
-- Name: session_app; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.session_app (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    utilisateur_id uuid NOT NULL,
    jeton_id uuid NOT NULL,
    ouverte_le timestamp with time zone DEFAULT clock_timestamp() NOT NULL
);


ALTER TABLE public.session_app OWNER TO postgres;

--
-- Name: site; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.site (
    id text NOT NULL,
    nom text NOT NULL,
    pays text NOT NULL
);


ALTER TABLE public.site OWNER TO postgres;

--
-- Name: suivi_formation; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.suivi_formation (
    apicultrice_id uuid NOT NULL,
    formateur_id uuid NOT NULL
);


ALTER TABLE public.suivi_formation OWNER TO postgres;

--
-- Name: synthese_site_jour; Type: MATERIALIZED VIEW; Schema: public; Owner: postgres
--

CREATE MATERIALIZED VIEW public.synthese_site_jour AS
 SELECT r.site_id,
    ((m.horodatage AT TIME ZONE 'UTC'::text))::date AS jour,
    count(*) AS nb_mesures,
    round(avg(m.poids_kg), 2) AS poids_moyen,
    min(m.poids_kg) AS poids_min,
    min(m.batterie_pct) AS batterie_min
   FROM (public.mesure m
     JOIN public.ruche r ON ((r.id = m.ruche_id)))
  GROUP BY r.site_id, (((m.horodatage AT TIME ZONE 'UTC'::text))::date)
  WITH NO DATA;


ALTER MATERIALIZED VIEW public.synthese_site_jour OWNER TO postgres;

--
-- Name: utilisateur; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.utilisateur (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    login text NOT NULL,
    role text NOT NULL,
    site_id text,
    apicultrice_id uuid,
    CONSTRAINT utilisateur_role_check CHECK ((role = ANY (ARRAY['apicultrice'::text, 'coordinateur'::text, 'gestionnaire'::text, 'administrateur'::text]))),
    CONSTRAINT utilisateur_role_valide CHECK ((role = ANY (ARRAY['apicultrice'::text, 'coordinateur'::text, 'gestionnaire'::text, 'administrateur'::text])))
);


ALTER TABLE public.utilisateur OWNER TO postgres;

--
-- Name: v_carte_ruches; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_carte_ruches WITH (security_barrier='true') AS
 SELECT r.nom AS code,
    r.latitude,
    r.longitude,
    a.nom
   FROM ((public.ruche r
     JOIN public.apicultrice a ON ((a.id = r.apicultrice_id)))
     JOIN public.utilisateur u ON ((u.apicultrice_id = a.id)))
  WHERE (u.login = CURRENT_USER);


ALTER VIEW public.v_carte_ruches OWNER TO postgres;

--
-- Name: v_export_bailleur; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_export_bailleur AS
 SELECT "left"(encode(public.hmac((a.id)::text, k.cle, 'sha256'::text), 'hex'::text), 12) AS apicultrice_pseudo,
    s.pays,
    s.nom AS site,
    round(r.latitude, 1) AS latitude_approx,
    round(r.longitude, 1) AS longitude_approx,
    COALESCE(sum(rc.quantite_kg) FILTER (WHERE (rc.statut = 'validee'::text)), (0)::numeric) AS total_recoltes_validees_kg
   FROM ((((public.ruche r
     JOIN public.apicultrice a ON ((a.id = r.apicultrice_id)))
     JOIN public.site s ON ((s.id = r.site_id)))
     LEFT JOIN public.recolte rc ON ((rc.ruche_id = r.id)))
     CROSS JOIN public.cle_pseudonymisation k)
  GROUP BY ("left"(encode(public.hmac((a.id)::text, k.cle, 'sha256'::text), 'hex'::text), 12)), s.pays, s.nom, (round(r.latitude, 1)), (round(r.longitude, 1));


ALTER VIEW public.v_export_bailleur OWNER TO postgres;

--
-- Name: v_mes_ruches; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_mes_ruches WITH (security_barrier='true') AS
 SELECT r.id,
    r.nom,
    r.site_id,
    r.latitude,
    r.longitude,
    r.date_installation
   FROM (public.ruche r
     JOIN public.utilisateur u ON ((u.apicultrice_id = r.apicultrice_id)))
  WHERE (u.login = public.qui());


ALTER VIEW public.v_mes_ruches OWNER TO postgres;

--
-- Name: v_mes_mesures; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_mes_mesures WITH (security_barrier='true') AS
 SELECT id,
    ruche_id,
    horodatage,
    poids_kg,
    temp_int_c,
    temp_ext_c,
    humidite_pct,
    activite_sonore,
    batterie_pct
   FROM public.mesure m
  WHERE (ruche_id IN ( SELECT v_mes_ruches.id
           FROM public.v_mes_ruches));


ALTER VIEW public.v_mes_mesures OWNER TO postgres;

--
-- Name: v_mes_recoltes; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_mes_recoltes WITH (security_barrier='true') AS
 SELECT id,
    ruche_id,
    date_recolte,
    quantite_kg,
    statut
   FROM public.recolte rc
  WHERE (ruche_id IN ( SELECT v_mes_ruches.id
           FROM public.v_mes_ruches))
  WITH CASCADED CHECK OPTION;


ALTER VIEW public.v_mes_recoltes OWNER TO postgres;

--
-- Name: v_moi; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_moi WITH (security_barrier='true') AS
 SELECT id,
    login,
    role
   FROM public.utilisateur
  WHERE (login = public.qui());


ALTER VIEW public.v_moi OWNER TO postgres;

--
-- Name: v_recoltes_site; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_recoltes_site AS
 SELECT rc.id,
    rc.ruche_id,
    rc.date_recolte,
    rc.quantite_kg,
    rc.statut,
    rc.validee_par,
    rc.date_validation
   FROM ((public.recolte rc
     JOIN public.ruche r ON ((r.id = rc.ruche_id)))
     JOIN public.utilisateur u ON ((u.site_id = r.site_id)))
  WHERE (u.login = public.qui());


ALTER VIEW public.v_recoltes_site OWNER TO postgres;

--
-- Name: v_ruches_site; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_ruches_site AS
 SELECT r.id,
    r.nom,
    r.site_id,
    a.nom AS apicultrice,
    a.telephone
   FROM ((public.ruche r
     JOIN public.apicultrice a ON ((a.id = r.apicultrice_id)))
     JOIN public.utilisateur u ON ((u.site_id = r.site_id)))
  WHERE (u.login = public.qui());


ALTER VIEW public.v_ruches_site OWNER TO postgres;

--
-- Name: adhesion adhesion_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.adhesion
    ADD CONSTRAINT adhesion_pkey PRIMARY KEY (apicultrice_id, cooperative_id);


--
-- Name: alerte alerte_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.alerte
    ADD CONSTRAINT alerte_pkey PRIMARY KEY (id);


--
-- Name: apicultrice apicultrice_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.apicultrice
    ADD CONSTRAINT apicultrice_pkey PRIMARY KEY (id);


--
-- Name: cle_pseudonymisation cle_pseudonymisation_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cle_pseudonymisation
    ADD CONSTRAINT cle_pseudonymisation_pkey PRIMARY KEY (id);


--
-- Name: cooperative cooperative_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cooperative
    ADD CONSTRAINT cooperative_pkey PRIMARY KEY (id);


--
-- Name: formateur formateur_nom_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.formateur
    ADD CONSTRAINT formateur_nom_key UNIQUE (nom);


--
-- Name: formateur formateur_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.formateur
    ADD CONSTRAINT formateur_pkey PRIMARY KEY (id);


--
-- Name: formation_plat formation_plat_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.formation_plat
    ADD CONSTRAINT formation_plat_pkey PRIMARY KEY (telephone, theme);


--
-- Name: inspection inspection_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inspection
    ADD CONSTRAINT inspection_pkey PRIMARY KEY (id);


--
-- Name: jeton jeton_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.jeton
    ADD CONSTRAINT jeton_pkey PRIMARY KEY (id);


--
-- Name: jeton jeton_valeur_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.jeton
    ADD CONSTRAINT jeton_valeur_key UNIQUE (valeur);


--
-- Name: journal_audit journal_audit_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.journal_audit
    ADD CONSTRAINT journal_audit_pkey PRIMARY KEY (id);


--
-- Name: mesure mesure_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mesure
    ADD CONSTRAINT mesure_pkey PRIMARY KEY (id);


--
-- Name: mesure mesure_ruche_horodatage_uq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mesure
    ADD CONSTRAINT mesure_ruche_horodatage_uq UNIQUE (ruche_id, horodatage);


--
-- Name: recolte recolte_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.recolte
    ADD CONSTRAINT recolte_pkey PRIMARY KEY (id);


--
-- Name: ruche ruche_nom_uq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ruche
    ADD CONSTRAINT ruche_nom_uq UNIQUE (nom);


--
-- Name: ruche ruche_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ruche
    ADD CONSTRAINT ruche_pkey PRIMARY KEY (id);


--
-- Name: session_app session_app_jeton_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.session_app
    ADD CONSTRAINT session_app_jeton_id_key UNIQUE (jeton_id);


--
-- Name: session_app session_app_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.session_app
    ADD CONSTRAINT session_app_pkey PRIMARY KEY (id);


--
-- Name: site site_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.site
    ADD CONSTRAINT site_pkey PRIMARY KEY (id);


--
-- Name: suivi_formation suivi_formation_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.suivi_formation
    ADD CONSTRAINT suivi_formation_pkey PRIMARY KEY (apicultrice_id, formateur_id);


--
-- Name: utilisateur utilisateur_apicultrice_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.utilisateur
    ADD CONSTRAINT utilisateur_apicultrice_id_key UNIQUE (apicultrice_id);


--
-- Name: utilisateur utilisateur_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.utilisateur
    ADD CONSTRAINT utilisateur_pkey PRIMARY KEY (id);


--
-- Name: synthese_site_jour_pk; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX synthese_site_jour_pk ON public.synthese_site_jour USING btree (site_id, jour);


--
-- Name: journal_audit journal_ajout_seul; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER journal_ajout_seul BEFORE DELETE OR UPDATE ON public.journal_audit FOR EACH ROW EXECUTE FUNCTION public.journal_interdit();


--
-- Name: journal_audit journal_sans_truncate; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER journal_sans_truncate BEFORE TRUNCATE ON public.journal_audit FOR EACH STATEMENT EXECUTE FUNCTION public.journal_interdit();


--
-- Name: recolte recolte_audit; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER recolte_audit AFTER INSERT OR DELETE OR UPDATE ON public.recolte FOR EACH ROW EXECUTE FUNCTION public.audit_ligne();


--
-- Name: suivi_formation suivi_formation_df; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER suivi_formation_df BEFORE INSERT OR UPDATE ON public.suivi_formation FOR EACH ROW EXECUTE FUNCTION public.suivi_un_formateur_par_theme();


--
-- Name: utilisateur utilisateur_audit; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER utilisateur_audit AFTER INSERT OR DELETE OR UPDATE ON public.utilisateur FOR EACH ROW EXECUTE FUNCTION public.audit_ligne();


--
-- Name: adhesion adhesion_apicultrice_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.adhesion
    ADD CONSTRAINT adhesion_apicultrice_fk FOREIGN KEY (apicultrice_id) REFERENCES public.apicultrice(id) ON DELETE CASCADE;


--
-- Name: adhesion adhesion_cooperative_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.adhesion
    ADD CONSTRAINT adhesion_cooperative_fk FOREIGN KEY (cooperative_id) REFERENCES public.cooperative(id) ON DELETE CASCADE;


--
-- Name: alerte alerte_ruche_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.alerte
    ADD CONSTRAINT alerte_ruche_fk FOREIGN KEY (ruche_id) REFERENCES public.ruche(id) ON DELETE RESTRICT;


--
-- Name: apicultrice apicultrice_site_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.apicultrice
    ADD CONSTRAINT apicultrice_site_fk FOREIGN KEY (site_id) REFERENCES public.site(id);


--
-- Name: cooperative cooperative_site_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cooperative
    ADD CONSTRAINT cooperative_site_fk FOREIGN KEY (site_id) REFERENCES public.site(id);


--
-- Name: inspection inspection_apicultrice_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inspection
    ADD CONSTRAINT inspection_apicultrice_fk FOREIGN KEY (apicultrice_id) REFERENCES public.apicultrice(id);


--
-- Name: inspection inspection_ruche_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inspection
    ADD CONSTRAINT inspection_ruche_fk FOREIGN KEY (ruche_id) REFERENCES public.ruche(id) ON DELETE RESTRICT;


--
-- Name: jeton jeton_utilisateur_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.jeton
    ADD CONSTRAINT jeton_utilisateur_id_fkey FOREIGN KEY (utilisateur_id) REFERENCES public.utilisateur(id) ON DELETE CASCADE;


--
-- Name: mesure mesure_ruche_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mesure
    ADD CONSTRAINT mesure_ruche_fk FOREIGN KEY (ruche_id) REFERENCES public.ruche(id) ON DELETE RESTRICT;


--
-- Name: recolte recolte_ruche_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.recolte
    ADD CONSTRAINT recolte_ruche_fk FOREIGN KEY (ruche_id) REFERENCES public.ruche(id) ON DELETE RESTRICT;


--
-- Name: recolte recolte_validee_par_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.recolte
    ADD CONSTRAINT recolte_validee_par_fk FOREIGN KEY (validee_par) REFERENCES public.utilisateur(id);


--
-- Name: ruche ruche_apicultrice_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ruche
    ADD CONSTRAINT ruche_apicultrice_fk FOREIGN KEY (apicultrice_id) REFERENCES public.apicultrice(id);


--
-- Name: ruche ruche_site_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ruche
    ADD CONSTRAINT ruche_site_fk FOREIGN KEY (site_id) REFERENCES public.site(id);


--
-- Name: session_app session_app_jeton_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.session_app
    ADD CONSTRAINT session_app_jeton_id_fkey FOREIGN KEY (jeton_id) REFERENCES public.jeton(id) ON DELETE CASCADE;


--
-- Name: session_app session_app_utilisateur_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.session_app
    ADD CONSTRAINT session_app_utilisateur_id_fkey FOREIGN KEY (utilisateur_id) REFERENCES public.utilisateur(id) ON DELETE CASCADE;


--
-- Name: suivi_formation suivi_formation_apicultrice_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.suivi_formation
    ADD CONSTRAINT suivi_formation_apicultrice_id_fkey FOREIGN KEY (apicultrice_id) REFERENCES public.apicultrice(id);


--
-- Name: suivi_formation suivi_formation_formateur_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.suivi_formation
    ADD CONSTRAINT suivi_formation_formateur_id_fkey FOREIGN KEY (formateur_id) REFERENCES public.formateur(id);


--
-- Name: utilisateur utilisateur_apicultrice_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.utilisateur
    ADD CONSTRAINT utilisateur_apicultrice_fk FOREIGN KEY (apicultrice_id) REFERENCES public.apicultrice(id);


--
-- Name: utilisateur utilisateur_site_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.utilisateur
    ADD CONSTRAINT utilisateur_site_fk FOREIGN KEY (site_id) REFERENCES public.site(id);


--
-- Name: recolte; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.recolte ENABLE ROW LEVEL SECURITY;

--
-- Name: recolte recolte_apicultrice_isolement; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY recolte_apicultrice_isolement ON public.recolte TO qb_apicultrice USING ((ruche_id IN ( SELECT r.id
   FROM (public.ruche r
     JOIN public.utilisateur u ON ((u.apicultrice_id = r.apicultrice_id)))
  WHERE (u.login = CURRENT_USER)))) WITH CHECK ((ruche_id IN ( SELECT r.id
   FROM (public.ruche r
     JOIN public.utilisateur u ON ((u.apicultrice_id = r.apicultrice_id)))
  WHERE (u.login = CURRENT_USER))));


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: pg_database_owner
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO qb_apicultrice;
GRANT USAGE ON SCHEMA public TO qb_coordinateur;
GRANT USAGE ON SCHEMA public TO qb_gestionnaire;
GRANT USAGE ON SCHEMA public TO qb_admin;


--
-- Name: FUNCTION armor(bytea); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.armor(bytea) FROM PUBLIC;


--
-- Name: FUNCTION armor(bytea, text[], text[]); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.armor(bytea, text[], text[]) FROM PUBLIC;


--
-- Name: FUNCTION audit_ligne(); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.audit_ligne() FROM PUBLIC;


--
-- Name: FUNCTION crypt(text, text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.crypt(text, text) FROM PUBLIC;


--
-- Name: FUNCTION dearmor(text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.dearmor(text) FROM PUBLIC;


--
-- Name: FUNCTION decrypt(bytea, bytea, text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.decrypt(bytea, bytea, text) FROM PUBLIC;


--
-- Name: FUNCTION decrypt_iv(bytea, bytea, bytea, text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.decrypt_iv(bytea, bytea, bytea, text) FROM PUBLIC;


--
-- Name: FUNCTION digest(bytea, text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.digest(bytea, text) FROM PUBLIC;


--
-- Name: FUNCTION digest(text, text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.digest(text, text) FROM PUBLIC;


--
-- Name: FUNCTION encrypt(bytea, bytea, text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.encrypt(bytea, bytea, text) FROM PUBLIC;


--
-- Name: FUNCTION encrypt_iv(bytea, bytea, bytea, text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.encrypt_iv(bytea, bytea, bytea, text) FROM PUBLIC;


--
-- Name: FUNCTION fips_mode(); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.fips_mode() FROM PUBLIC;


--
-- Name: FUNCTION gen_random_bytes(integer); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.gen_random_bytes(integer) FROM PUBLIC;


--
-- Name: FUNCTION gen_random_uuid(); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.gen_random_uuid() FROM PUBLIC;


--
-- Name: FUNCTION gen_salt(text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.gen_salt(text) FROM PUBLIC;


--
-- Name: FUNCTION gen_salt(text, integer); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.gen_salt(text, integer) FROM PUBLIC;


--
-- Name: FUNCTION hmac(bytea, bytea, text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.hmac(bytea, bytea, text) FROM PUBLIC;


--
-- Name: FUNCTION hmac(text, text, text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.hmac(text, text, text) FROM PUBLIC;


--
-- Name: FUNCTION journal_interdit(); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.journal_interdit() FROM PUBLIC;


--
-- Name: FUNCTION pgp_armor_headers(text, OUT key text, OUT value text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.pgp_armor_headers(text, OUT key text, OUT value text) FROM PUBLIC;


--
-- Name: FUNCTION pgp_key_id(bytea); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.pgp_key_id(bytea) FROM PUBLIC;


--
-- Name: FUNCTION pgp_pub_decrypt(bytea, bytea); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.pgp_pub_decrypt(bytea, bytea) FROM PUBLIC;


--
-- Name: FUNCTION pgp_pub_decrypt(bytea, bytea, text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.pgp_pub_decrypt(bytea, bytea, text) FROM PUBLIC;


--
-- Name: FUNCTION pgp_pub_decrypt(bytea, bytea, text, text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.pgp_pub_decrypt(bytea, bytea, text, text) FROM PUBLIC;


--
-- Name: FUNCTION pgp_pub_decrypt_bytea(bytea, bytea); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.pgp_pub_decrypt_bytea(bytea, bytea) FROM PUBLIC;


--
-- Name: FUNCTION pgp_pub_decrypt_bytea(bytea, bytea, text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.pgp_pub_decrypt_bytea(bytea, bytea, text) FROM PUBLIC;


--
-- Name: FUNCTION pgp_pub_decrypt_bytea(bytea, bytea, text, text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.pgp_pub_decrypt_bytea(bytea, bytea, text, text) FROM PUBLIC;


--
-- Name: FUNCTION pgp_pub_encrypt(text, bytea); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.pgp_pub_encrypt(text, bytea) FROM PUBLIC;


--
-- Name: FUNCTION pgp_pub_encrypt(text, bytea, text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.pgp_pub_encrypt(text, bytea, text) FROM PUBLIC;


--
-- Name: FUNCTION pgp_pub_encrypt_bytea(bytea, bytea); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.pgp_pub_encrypt_bytea(bytea, bytea) FROM PUBLIC;


--
-- Name: FUNCTION pgp_pub_encrypt_bytea(bytea, bytea, text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.pgp_pub_encrypt_bytea(bytea, bytea, text) FROM PUBLIC;


--
-- Name: FUNCTION pgp_sym_decrypt(bytea, text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.pgp_sym_decrypt(bytea, text) FROM PUBLIC;


--
-- Name: FUNCTION pgp_sym_decrypt(bytea, text, text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.pgp_sym_decrypt(bytea, text, text) FROM PUBLIC;


--
-- Name: FUNCTION pgp_sym_decrypt_bytea(bytea, text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.pgp_sym_decrypt_bytea(bytea, text) FROM PUBLIC;


--
-- Name: FUNCTION pgp_sym_decrypt_bytea(bytea, text, text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.pgp_sym_decrypt_bytea(bytea, text, text) FROM PUBLIC;


--
-- Name: FUNCTION pgp_sym_encrypt(text, text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.pgp_sym_encrypt(text, text) FROM PUBLIC;


--
-- Name: FUNCTION pgp_sym_encrypt(text, text, text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.pgp_sym_encrypt(text, text, text) FROM PUBLIC;


--
-- Name: FUNCTION pgp_sym_encrypt_bytea(bytea, text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.pgp_sym_encrypt_bytea(bytea, text) FROM PUBLIC;


--
-- Name: FUNCTION pgp_sym_encrypt_bytea(bytea, text, text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.pgp_sym_encrypt_bytea(bytea, text, text) FROM PUBLIC;


--
-- Name: FUNCTION qui(); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.qui() FROM PUBLIC;
GRANT ALL ON FUNCTION public.qui() TO qb_apicultrice;
GRANT ALL ON FUNCTION public.qui() TO qb_coordinateur;
GRANT ALL ON FUNCTION public.qui() TO qb_gestionnaire;
GRANT ALL ON FUNCTION public.qui() TO qb_admin;


--
-- Name: FUNCTION suivi_un_formateur_par_theme(); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.suivi_un_formateur_par_theme() FROM PUBLIC;


--
-- Name: FUNCTION valider_recolte(p_recolte uuid); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.valider_recolte(p_recolte uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.valider_recolte(p_recolte uuid) TO qb_coordinateur;


--
-- Name: TABLE journal_audit; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.journal_audit TO qb_admin;


--
-- Name: TABLE recolte; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT ON TABLE public.recolte TO qb_apicultrice;


--
-- Name: TABLE ruche; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.ruche TO qb_apicultrice;


--
-- Name: TABLE synthese_site_jour; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.synthese_site_jour TO qb_gestionnaire;


--
-- Name: TABLE utilisateur; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,UPDATE ON TABLE public.utilisateur TO qb_admin;


--
-- Name: COLUMN utilisateur.id; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT(id) ON TABLE public.utilisateur TO qb_apicultrice;


--
-- Name: COLUMN utilisateur.login; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT(login) ON TABLE public.utilisateur TO qb_apicultrice;


--
-- Name: COLUMN utilisateur.apicultrice_id; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT(apicultrice_id) ON TABLE public.utilisateur TO qb_apicultrice;


--
-- Name: TABLE v_carte_ruches; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.v_carte_ruches TO qb_apicultrice;


--
-- Name: TABLE v_export_bailleur; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.v_export_bailleur TO qb_gestionnaire;


--
-- Name: TABLE v_mes_ruches; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.v_mes_ruches TO qb_apicultrice;


--
-- Name: TABLE v_mes_mesures; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.v_mes_mesures TO qb_apicultrice;


--
-- Name: TABLE v_mes_recoltes; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.v_mes_recoltes TO qb_apicultrice;


--
-- Name: COLUMN v_mes_recoltes.ruche_id; Type: ACL; Schema: public; Owner: postgres
--

GRANT INSERT(ruche_id) ON TABLE public.v_mes_recoltes TO qb_apicultrice;


--
-- Name: COLUMN v_mes_recoltes.date_recolte; Type: ACL; Schema: public; Owner: postgres
--

GRANT INSERT(date_recolte) ON TABLE public.v_mes_recoltes TO qb_apicultrice;


--
-- Name: COLUMN v_mes_recoltes.quantite_kg; Type: ACL; Schema: public; Owner: postgres
--

GRANT INSERT(quantite_kg) ON TABLE public.v_mes_recoltes TO qb_apicultrice;


--
-- Name: TABLE v_moi; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.v_moi TO qb_apicultrice;
GRANT SELECT ON TABLE public.v_moi TO qb_coordinateur;
GRANT SELECT ON TABLE public.v_moi TO qb_gestionnaire;
GRANT SELECT ON TABLE public.v_moi TO qb_admin;


--
-- Name: TABLE v_recoltes_site; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.v_recoltes_site TO qb_coordinateur;


--
-- Name: TABLE v_ruches_site; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.v_ruches_site TO qb_coordinateur;


--
-- PostgreSQL database dump complete
--

\unrestrict Y9iLwCXuidnOv3L2OEt5KSNIvd7hQnPiQsN9C2u8DnmchLpsaV09RWiX9VnO4Vz

