-- ========================================================
-- 1️⃣ Join-Tabellen erstellen
-- ========================================================

CREATE TABLE IF NOT EXISTS rel_pto_flurstueck (
    pto_id varchar NOT NULL,
    flurstueck_id varchar NOT NULL
);

CREATE TABLE IF NOT EXISTS rel_darst_flurstueck (
    darst_id varchar NOT NULL,
    flurstueck_id varchar NOT NULL
);

-- ========================================================
-- 2️⃣ Join-Tabellen befüllen
-- ========================================================

TRUNCATE rel_pto_flurstueck;

INSERT INTO rel_pto_flurstueck (pto_id, flurstueck_id)
SELECT
    t.gml_id AS pto_id,
    TRIM(UNNEST(t.dientzurdarstellungvon)) AS flurstueck_id
FROM ap_pto t
WHERE t.dientzurdarstellungvon IS NOT NULL
  AND array_length(t.dientzurdarstellungvon, 1) > 0;

TRUNCATE rel_darst_flurstueck;

INSERT INTO rel_darst_flurstueck (darst_id, flurstueck_id)
SELECT
    d.gml_id AS darst_id,
    TRIM(UNNEST(d.dientzurdarstellungvon)) AS flurstueck_id
FROM ap_darstellung d
WHERE d.dientzurdarstellungvon IS NOT NULL
  AND array_length(d.dientzurdarstellungvon, 1) > 0;

-- ========================================================
-- 3️⃣ Indexe erstellen
-- ========================================================

CREATE INDEX IF NOT EXISTS idx_pto_flst_flurstueck ON rel_pto_flurstueck (flurstueck_id);
CREATE INDEX IF NOT EXISTS idx_pto_flst_pto ON rel_pto_flurstueck (pto_id);

CREATE INDEX IF NOT EXISTS idx_darst_flst_flurstueck ON rel_darst_flurstueck (flurstueck_id);
CREATE INDEX IF NOT EXISTS idx_darst_flst_darst ON rel_darst_flurstueck (darst_id);

-- ========================================================
-- 4️⃣ INSERT in po_labels
-- ========================================================

SELECT 'Erzeuge Flurstücksnenner...';

WITH flurstueck AS MATERIALIZED (
    SELECT 
        o.gml_id,
        o.wkb_geometry,
        COALESCE(o.nenner::text,'0') AS nenner,
        COALESCE(o.zaehler::text,'0') AS zaehler,
        o.abweichenderrechtszustand,
        COALESCE(o.advstandardmodell || o.sonstigesmodell, ARRAY[]::varchar[]) AS modell
    FROM ax_flurstueck o
    WHERE o.endet IS NULL
      AND COALESCE(o.nenner,'0') <> '0'
),
pto AS MATERIALIZED (
    SELECT
        t.gml_id,
        t.wkb_geometry,
        t.signaturnummer,
        t.drehwinkel,
        t.horizontaleausrichtung,
        t.skalierung,
        t.fontsperrung,
        COALESCE(t.advstandardmodell || t.sonstigesmodell, ARRAY[]::varchar[]) AS modell,
        split_part(replace(t.schriftinhalt,'-','/'), '/', 1) AS z_text,
        split_part(replace(t.schriftinhalt,'-','/'), '/', 2) AS n_text
    FROM ap_pto t
    WHERE t.endet IS NULL
),
darst AS MATERIALIZED (
    SELECT *
    FROM ap_darstellung d
    WHERE d.endet IS NULL
)
INSERT INTO po_labels(
    gml_id, thema, layer, point, text, signaturnummer,
    drehwinkel, horizontaleausrichtung, vertikaleausrichtung,
    skalierung, fontsperrung, modell
)
SELECT
    f.gml_id,
    'Flurstücke' AS thema,
    'ax_flurstueck_nummer' AS layer,
    CASE
        WHEN p.horizontaleausrichtung='rechtsbündig' THEN st_translate(
            COALESCE(p.wkb_geometry, st_centroid(f.wkb_geometry)), -l.len, 0.0
        )
        WHEN p.horizontaleausrichtung='linksbündig' THEN st_translate(
            COALESCE(p.wkb_geometry, st_centroid(f.wkb_geometry)), l.len, 0.0
        )
        ELSE COALESCE(p.wkb_geometry, st_centroid(f.wkb_geometry))
    END AS point,
    COALESCE(p.n_text, f.nenner) AS text,
    COALESCE(d.signaturnummer, p.signaturnummer,
        CASE WHEN f.abweichenderrechtszustand='true' THEN '4123' ELSE '4115' END
    ) AS signaturnummer,
    p.drehwinkel,
    'zentrisch' AS horizontaleausrichtung,
    'oben' AS vertikaleausrichtung,
    p.skalierung,
    p.fontsperrung,
    COALESCE(p.modell, f.modell, ARRAY[]::varchar[]) AS modell
FROM flurstueck f
LEFT JOIN rel_pto_flurstueck rp ON rp.flurstueck_id = f.gml_id
LEFT JOIN pto p ON p.gml_id = rp.pto_id
LEFT JOIN rel_darst_flurstueck rd ON rd.flurstueck_id = f.gml_id
LEFT JOIN darst d ON d.gml_id = rd.darst_id
CROSS JOIN LATERAL (
    SELECT GREATEST(
        length(COALESCE(p.z_text, f.zaehler)),
        length(COALESCE(p.n_text, f.nenner))
    ) AS len
) AS l
WHERE (
    (:alkis_fnbruch = TRUE  AND COALESCE(p.signaturnummer,'4115') NOT IN ('4113','4122'))
    OR
    (:alkis_fnbruch = FALSE AND COALESCE(p.signaturnummer,'4113') IN ('4115','4123'))
)
AND COALESCE(p.n_text, f.nenner) IS NOT NULL;
