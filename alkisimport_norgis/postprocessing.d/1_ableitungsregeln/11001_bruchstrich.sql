-- Bruchstrich
SELECT 'Erzeuge Flurstücksbruchstriche...';

-- 1. Temp-Tabellen für PTO und Darstellung vorbereiten
CREATE TEMP TABLE temp_pto AS
SELECT
    gml_id AS pto_gml_id,             -- Original-GML-ID von PTO
    unnest(dientzurdarstellungvon) AS obj_id,
    wkb_geometry,
    schriftinhalt,
    advstandardmodell,
    sonstigesmodell,
    drehwinkel,
    horizontaleausrichtung,
    signaturnummer
FROM ap_pto
WHERE endet IS NULL;

CREATE INDEX idx_temp_pto_obj ON temp_pto(obj_id);

CREATE TEMP TABLE temp_darstellung AS
SELECT
    gml_id AS darstellung_gml_id,    -- Original-GML-ID der Darstellung
    unnest(dientzurdarstellungvon) AS obj_id,
    signaturnummer
FROM ap_darstellung
WHERE endet IS NULL;

CREATE INDEX idx_temp_dar_obj ON temp_darstellung(obj_id);

-- 2. Insert vorberechnen
INSERT INTO po_lines(gml_id,thema,layer,line,signaturnummer,modell)
WITH bruchstrich0 AS (
    SELECT
        o.gml_id,
        COALESCE(t.wkb_geometry, st_centroid(o.wkb_geometry)) AS point,
        greatest(
            COALESCE(length(split_part(replace(t.schriftinhalt,'-','/'),'/',1)), length(o.zaehler::text)),
            COALESCE(length(split_part(replace(t.schriftinhalt,'-','/'),'/',2)), length(o.nenner::text))
        ) AS len,
        COALESCE(d.signaturnummer,'2001') AS signaturnummer,
        COALESCE(t.advstandardmodell||t.sonstigesmodell, o.advstandardmodell||o.sonstigesmodell) AS modell,
        COALESCE(t.drehwinkel,0) AS drehwinkel,
        t.horizontaleausrichtung
    FROM ax_flurstueck o
    LEFT JOIN temp_pto t ON o.gml_id = t.obj_id
    LEFT JOIN temp_darstellung d ON o.gml_id = d.obj_id
    WHERE o.endet IS NULL
      AND COALESCE(o.nenner,'0') <> '0'
      AND CASE
            WHEN :alkis_fnbruch THEN COALESCE(t.signaturnummer,'4115') NOT IN ('4113','4122')
            ELSE COALESCE(t.signaturnummer,'4113') IN ('4115','4123')
          END
),
bruchstrich1 AS (
    SELECT * FROM bruchstrich0 WHERE len > 0
)
SELECT
    gml_id,
    'Flurstücke' AS thema,
    'ax_flurstueck_nummer' AS layer,
    CASE
        WHEN horizontaleausrichtung='rechtsbündig'
             THEN st_multi(st_rotate(
                     st_makeline(
                        st_translate(point, -(2*len), 0),
                        point),
                     drehwinkel, st_x(point), st_y(point)))
        WHEN horizontaleausrichtung='linksbündig'
             THEN st_multi(st_rotate(
                     st_makeline(
                        point,
                        st_translate(point, 2*len, 0)),
                     drehwinkel, st_x(point), st_y(point)))
        ELSE st_multi(st_rotate(
                     st_makeline(
                       st_translate(point, -len, 0),
                       st_translate(point, len, 0)),
                     drehwinkel, st_x(point), st_y(point)))
    END AS line,
    signaturnummer,
    modell
FROM bruchstrich1;
