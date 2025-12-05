-- ===========================================
-- Flurstücks-Zähler / Bruchdarstellung
-- ===========================================
SELECT 'Erzeuge Flurstückszähler...';

WITH 
-- PTO-Dienst-Zuordnung: Array unnesten
pto_dient AS (
    SELECT
        t.gml_id AS pto_id,
        unnest(t.dientzurdarstellungvon) AS flst_id
    FROM ap_pto t
    WHERE t.endet IS NULL
),

-- Darstellung-Dienst-Zuordnung: Array unnesten
darst_dient AS (
    SELECT
        d.gml_id AS dar_id,
        unnest(d.dientzurdarstellungvon) AS flst_id
    FROM ap_darstellung d
    WHERE d.endet IS NULL
),

-- PTO mit Text, Modell, etc.
pto AS (
    SELECT
        t.gml_id AS pto_id,
        pd.flst_id,
        t.wkb_geometry,
        t.schriftinhalt,
        t.drehwinkel,
        t.horizontaleausrichtung,
        t.skalierung,
        t.fontsperrung,
        t.signaturnummer,
        t.advstandardmodell,
        t.sonstigesmodell
    FROM ap_pto t
    JOIN pto_dient pd ON pd.pto_id = t.gml_id
),

-- Darstellung mit Signaturen
darst AS (
    SELECT
        d.gml_id AS dar_id,
        dd.flst_id,
        d.signaturnummer
    FROM ap_darstellung d
    JOIN darst_dient dd ON dd.dar_id = d.gml_id
),

-- Hauptdatenquelle: Flurstück + PTO + Darstellung
basis AS (
    SELECT
        o.gml_id,
        o.zaehler,
        o.nenner,
        o.abweichenderrechtszustand,
        o.advstandardmodell,
        o.sonstigesmodell,
        COALESCE(pto.wkb_geometry, ST_Centroid(o.wkb_geometry)) AS point_geom,
        pto.schriftinhalt AS p_schrift,
        COALESCE(pto.drehwinkel,0) AS drehwinkel,
        COALESCE(pto.horizontaleausrichtung,'zentrisch') AS horizontaleausrichtung,
        COALESCE(pto.skalierung,1) AS skalierung,
        COALESCE(pto.fontsperrung,0) AS fontsperrung,
        COALESCE(darst.signaturnummer, pto.signaturnummer,
                 CASE WHEN o.abweichenderrechtszustand='true' THEN '4123' ELSE '4115' END
        ) AS signaturnummer,
        COALESCE(pto.advstandardmodell || pto.sonstigesmodell, o.advstandardmodell || o.sonstigesmodell) AS modell
    FROM ax_flurstueck o
    LEFT JOIN pto ON pto.flst_id = o.gml_id
    LEFT JOIN darst ON darst.flst_id = o.gml_id
    WHERE o.endet IS NULL
      AND COALESCE(o.nenner,'0') <> '0'
      AND (
        CASE WHEN :alkis_fnbruch
             THEN COALESCE(pto.signaturnummer,'4115') NOT IN ('4113','4122')
             ELSE COALESCE(pto.signaturnummer,'4113') IN ('4115','4123')
        END
      )
),

-- Textwerte für Zähler/Nenner extrahieren
textwerte AS (
    SELECT
        gml_id,
        COALESCE(split_part(replace(p_schrift,'-','/'), '/', 1), zaehler::text) AS z_text,
        COALESCE(split_part(replace(p_schrift,'-','/'), '/', 2), nenner::text) AS n_text,
        zaehler,
        nenner,
        point_geom,
        drehwinkel,
        horizontaleausrichtung,
        skalierung,
        fontsperrung,
        signaturnummer,
        modell,
        'Basis'::text AS vertikaleausrichtung
    FROM basis
),

-- Längenberechnung wie Original
berechnet AS (
    SELECT
        gml_id,
        point_geom,
        drehwinkel,
        horizontaleausrichtung,
        skalierung,
        fontsperrung,
        signaturnummer,
        z_text AS text,
        GREATEST(LENGTH(z_text), LENGTH(n_text)) AS len,
        modell,
        vertikaleausrichtung
    FROM textwerte
)

-- INSERT in po_labels
INSERT INTO po_labels
(gml_id, thema, layer, point, text, signaturnummer,
 drehwinkel, horizontaleausrichtung, vertikaleausrichtung,
 skalierung, fontsperrung, modell)
SELECT
    gml_id,
    'Flurstücke',
    'ax_flurstueck_nummer',
    CASE
        WHEN horizontaleausrichtung='rechtsbündig' THEN ST_Translate(point_geom, -len, 0.0)
        WHEN horizontaleausrichtung='linksbündig' THEN ST_Translate(point_geom,  len, 0.0)
        ELSE point_geom
    END,
    COALESCE(text, '?') AS text,
    signaturnummer,
    drehwinkel,
    'zentrisch',
    vertikaleausrichtung,
    skalierung,
    fontsperrung,
    modell
FROM berechnet;
