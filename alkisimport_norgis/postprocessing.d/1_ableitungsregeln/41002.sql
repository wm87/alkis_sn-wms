SELECT 'Industrie- und Gewerbeflächen werden verarbeitet.';

--------------------------------------------------------------------
-- TEMPORÄRE TABELLEN
--------------------------------------------------------------------

CREATE TEMP TABLE tmp_pto AS
SELECT
    unnest(t.dientzurdarstellungvon) AS gml_id,
    t.art,
    t.wkb_geometry,
    t.schriftinhalt,
    t.signaturnummer,
    t.advstandardmodell,
    t.sonstigesmodell,
    t.drehwinkel,
    t.horizontaleausrichtung,
    t.vertikaleausrichtung,
    t.skalierung,
    t.fontsperrung
FROM ap_pto t
WHERE t.endet IS NULL;

CREATE TEMP TABLE tmp_darstellung AS
SELECT
    unnest(d.dientzurdarstellungvon) AS gml_id,
    d.art,
    d.signaturnummer,
    d.advstandardmodell,
    d.sonstigesmodell
FROM ap_darstellung d
WHERE d.endet IS NULL;

CREATE TEMP TABLE tmp_ppo AS
SELECT
    unnest(p.dientzurdarstellungvon) AS gml_id,
    p.art,
    p.wkb_geometry,
    p.signaturnummer,
    p.advstandardmodell,
    p.sonstigesmodell,
    p.drehwinkel
FROM ap_ppo p
WHERE p.endet IS NULL;

CREATE INDEX ON tmp_pto(gml_id, art);
CREATE INDEX ON tmp_darstellung(gml_id, art);
CREATE INDEX ON tmp_ppo(gml_id, art);

--------------------------------------------------------------------
-- 1. FLÄCHEN
--------------------------------------------------------------------

INSERT INTO po_polygons(gml_id, thema, layer, polygon, signaturnummer, modell)
SELECT
    gml_id,
    'Industrie und Gewerbe',
    'ax_industrieundgewerbeflaeche',
    ST_Multi(wkb_geometry),
    25151403,
    advstandardmodell || sonstigesmodell
FROM ax_industrieundgewerbeflaeche
WHERE endet IS NULL;

--------------------------------------------------------------------
-- 2. NAMENS-LABELS
--------------------------------------------------------------------

INSERT INTO po_labels(
    gml_id, thema, layer, point, text,
    signaturnummer, drehwinkel,
    horizontaleausrichtung, vertikaleausrichtung,
    skalierung, fontsperrung, modell
)
SELECT
    g.gml_id,
    'Industrie und Gewerbe',
    'ax_industrieundgewerbeflaeche',
    COALESCE(t.wkb_geometry, ST_Centroid(g.wkb_geometry)) AS point,
    COALESCE(t.schriftinhalt, g.name, '') AS text,
    COALESCE(d.signaturnummer, t.signaturnummer, '4141') AS signaturnummer,
    COALESCE(t.drehwinkel, 0) AS drehwinkel,
    COALESCE(t.horizontaleausrichtung, 'zentrisch') AS horizontaleausrichtung,
    COALESCE(t.vertikaleausrichtung, 'Mitte') AS vertikaleausrichtung,
    COALESCE(t.skalierung, 1) AS skalierung,
    COALESCE(t.fontsperrung, 0) AS fontsperrung,
    COALESCE(
        t.advstandardmodell || t.sonstigesmodell,
        d.advstandardmodell || d.sonstigesmodell,
        g.advstandardmodell || g.sonstigesmodell
    ) AS modell
FROM ax_industrieundgewerbeflaeche g
LEFT JOIN tmp_pto t
       ON g.gml_id = t.gml_id AND t.art = 'NAM'
LEFT JOIN tmp_darstellung d
       ON g.gml_id = d.gml_id AND d.art = 'NAM'
WHERE g.endet IS NULL
  AND COALESCE(t.schriftinhalt, g.name) IS NOT NULL;

--------------------------------------------------------------------
-- 3. FUNKTIONS-LABELS
--------------------------------------------------------------------

INSERT INTO po_labels(
    gml_id, thema, layer, point, text,
    signaturnummer, drehwinkel,
    horizontaleausrichtung, vertikaleausrichtung,
    skalierung, fontsperrung, modell
)
WITH base AS (
    SELECT
        g.*,
        COALESCE(t.schriftinhalt,'') AS t_text,
        COALESCE(t.wkb_geometry, ST_Translate(ST_Centroid(g.wkb_geometry),0,-7)) AS point,
        COALESCE(t.drehwinkel,0) AS drehwinkel,
        COALESCE(t.horizontaleausrichtung,'zentrisch') AS horizontaleausrichtung,
        COALESCE(t.vertikaleausrichtung,'Mitte') AS vertikaleausrichtung,
        COALESCE(t.skalierung,1) AS skalierung,
        COALESCE(t.fontsperrung,0) AS fontsperrung,
        COALESCE(
            t.advstandardmodell || t.sonstigesmodell,
            d.advstandardmodell || d.sonstigesmodell,
            g.advstandardmodell || g.sonstigesmodell
        ) AS modell,
        COALESCE(d.signaturnummer, t.signaturnummer, '4140') AS signnr
    FROM ax_industrieundgewerbeflaeche g
    LEFT JOIN tmp_pto t
           ON g.gml_id = t.gml_id AND t.art = 'FKT'
    LEFT JOIN tmp_darstellung d
           ON g.gml_id = d.gml_id AND d.art = 'FKT'
    WHERE g.endet IS NULL
)
SELECT
    gml_id,
    'Industrie und Gewerbe',
    'ax_industrieundgewerbeflaeche',
    point,
    COALESCE(
        CASE
            WHEN base.funktion = 1740 THEN
                CASE
                   WHEN COALESCE(base.lagergut,0) IN (0,9999) THEN t_text
                   ELSE t_text || E'\n(' ||
                        COALESCE((SELECT beschreibung FROM ax_lagergut_industrieundgewerbeflaeche WHERE wert=base.lagergut),'') ||
                        ')'
                END
            WHEN base.funktion IN (2520,2522,2550,2552,2560,2562,2580,2582,2610,2612,2620,2622,2630,2640) THEN t_text
            WHEN base.funktion IN (2530,2532) THEN '(' || COALESCE((SELECT beschreibung FROM ax_primaerenergie_industrieundgewerbeflaeche WHERE wert=base.primaerenergie),'') || ')'
            WHEN base.funktion IN (2570,2572) THEN
                t_text || COALESCE(E'\n(' || (SELECT beschreibung FROM ax_primaerenergie_industrieundgewerbeflaeche WHERE wert=base.primaerenergie) || ')','')
            ELSE t_text
        END,
        ''
    ) AS text,
    signnr,
    drehwinkel,
    horizontaleausrichtung,
    vertikaleausrichtung,
    skalierung,
    fontsperrung,
    modell
FROM base
WHERE (t_text <> '' OR base.funktion IS NOT NULL);


--------------------------------------------------------------------
-- 4. FUNKTIONSSYMBOLE (po_points)
--------------------------------------------------------------------

INSERT INTO po_points(
    gml_id, thema, layer, point,
    drehwinkel, signaturnummer, modell
)
SELECT
    g.gml_id,
    'Industrie und Gewerbe',
    'ax_industrieundgewerbeflaeche',
    ST_Multi(COALESCE(p.wkb_geometry, ST_Centroid(g.wkb_geometry))),
    COALESCE(p.drehwinkel, 0),
    COALESCE(
        d.signaturnummer,
        p.signaturnummer,
        CASE
            WHEN g.funktion = 1730 THEN '3401'
            WHEN g.funktion = 2510 THEN '3402'
            WHEN g.funktion IN (2530,2432) THEN '3403'
            WHEN g.funktion = 2540 THEN '3404'
        END
    ),
    COALESCE(
        p.advstandardmodell || p.sonstigesmodell,
        d.advstandardmodell || d.sonstigesmodell,
        g.advstandardmodell || g.sonstigesmodell
    )
FROM ax_industrieundgewerbeflaeche g
LEFT JOIN tmp_ppo p ON g.gml_id = p.gml_id AND p.art = 'FKT'
LEFT JOIN tmp_darstellung d ON g.gml_id = d.gml_id AND d.art = 'FKT'
WHERE g.endet IS NULL
  AND COALESCE(
        d.signaturnummer,
        p.signaturnummer,
        CASE
            WHEN g.funktion = 1730 THEN '3401'
            WHEN g.funktion = 2510 THEN '3402'
            WHEN g.funktion IN (2530,2432) THEN '3403'
            WHEN g.funktion = 2540 THEN '3404'
        END
      ) IS NOT NULL;
