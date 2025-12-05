-- 31001_03_labels_funktion.sql
-- Gebäudebeschriftungen (Funktion)

-- Ausgabe vor Insert
SELECT 'Gebäudebeschriftungen, Funktion einfügen';

-- ------------------------------------------------------------
-- 1) Vorbereitung: Centroid-Spalte nur einmal berechnen
-- ------------------------------------------------------------
ALTER TABLE ax_gebaeude
    ADD COLUMN IF NOT EXISTS centroid geometry(Point, 25833);

UPDATE ax_gebaeude
SET centroid = ST_Centroid(wkb_geometry)
WHERE centroid IS NULL;

CREATE INDEX IF NOT EXISTS idx_ax_gebaeude_endet
    ON ax_gebaeude(endet);


-- ------------------------------------------------------------
-- 2) PTO entnormalisieren (ersetzt ANY(array)-Joins)
-- ------------------------------------------------------------
DROP TABLE IF EXISTS ap_pto_expanded;
CREATE TEMP TABLE ap_pto_expanded AS
SELECT
    p.*,
    unnest(p.dientzurdarstellungvon) AS gml_id_ref
FROM ap_pto p
WHERE p.endet IS NULL;

CREATE INDEX ON ap_pto_expanded (gml_id_ref, art);


-- ------------------------------------------------------------
-- 3) Darstellung entnormalisieren
-- ------------------------------------------------------------
DROP TABLE IF EXISTS ap_darstellung_expanded;
CREATE TEMP TABLE ap_darstellung_expanded AS
SELECT
    d.*,
    unnest(d.dientzurdarstellungvon) AS gml_id_ref
FROM ap_darstellung d
WHERE d.endet IS NULL
  AND d.art IN ('GFK','NAM');

CREATE INDEX ON ap_darstellung_expanded (gml_id_ref, art);


-- ------------------------------------------------------------
-- 4) Labels einfügen (Basislogik unverändert)
-- ------------------------------------------------------------

WITH gebaeudefunktion_mapping AS (
    SELECT * FROM (VALUES
         (3012, 'Rathaus'), (3014, 'Zoll'), (3015, 'Gericht'),
         (3021, 'Schule'), (3034, 'Museum'), (3091, 'Bahnhof'),
         (9998, 'oF'), (2513, 'Wbh'), (3022, 'Schule'),
         (3023, 'Hochschule'), (3038, 'Burg'), (3211, 'Sporthalle')
    ) AS t(gebaeudefunktion, beschreibung)
),
gebaeude_base AS (
    SELECT
        g.gml_id,
        g.wkb_geometry,
        g.centroid,
        g.gebaeudefunktion,
        unnest(COALESCE(g.name, ARRAY[NULL])) AS name,
        g.advstandardmodell || g.sonstigesmodell AS modell
    FROM ax_gebaeude g
    WHERE g.endet IS NULL
),
darstellung AS (
    SELECT
        o.gml_id,
        COALESCE(
            n.wkb_geometry,
            t.wkb_geometry,
            o.centroid
        ) AS point,
        COALESCE(
            n.schriftinhalt,
            t.schriftinhalt,
            o.name,
            gm.beschreibung
        ) AS text,
        COALESCE(
            d.signaturnummer,
            n.signaturnummer,
            t.signaturnummer,
            '4070'
        ) AS signaturnummer,
        COALESCE(n.drehwinkel, t.drehwinkel) AS drehwinkel,
        COALESCE(n.horizontaleausrichtung, t.horizontaleausrichtung) AS horizontaleausrichtung,
        COALESCE(n.vertikaleausrichtung, t.vertikaleausrichtung) AS vertikaleausrichtung,
        COALESCE(n.skalierung, t.skalierung) AS skalierung,
        COALESCE(n.fontsperrung, t.fontsperrung) AS fontsperrung,
        COALESCE(
            t.advstandardmodell || t.sonstigesmodell ||
            n.advstandardmodell || n.sonstigesmodell,
            o.modell
        ) AS modell
    FROM gebaeude_base o
    LEFT JOIN ap_pto_expanded t
           ON t.gml_id_ref = o.gml_id
          AND t.art = 'GFK'

    LEFT JOIN ap_pto_expanded n
           ON n.gml_id_ref = o.gml_id
          AND n.art = 'NAM'

    LEFT JOIN ap_darstellung_expanded d
           ON d.gml_id_ref = o.gml_id

    LEFT JOIN gebaeudefunktion_mapping gm
           ON gm.gebaeudefunktion = o.gebaeudefunktion
)
INSERT INTO po_labels (
    gml_id,
    thema,
    layer,
    point,
    text,
    signaturnummer,
    drehwinkel,
    horizontaleausrichtung,
    vertikaleausrichtung,
    skalierung,
    fontsperrung,
    modell
)
SELECT
    gml_id,
    'Gebäude',
    'ax_gebaeude_funktion',
    point,
    text,
    signaturnummer,
    drehwinkel,
    horizontaleausrichtung,
    vertikaleausrichtung,
    skalierung,
    fontsperrung,
    modell
FROM darstellung
WHERE text IS NOT NULL;
