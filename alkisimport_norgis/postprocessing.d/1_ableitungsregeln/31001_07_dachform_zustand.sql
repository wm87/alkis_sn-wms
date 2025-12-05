-- 31001_07_dachform_zustand.sql
-- Dachform und Gebäudezustände

-- Sicherstellen, dass die notwendigen Unique Constraints existieren
ALTER TABLE IF EXISTS ap_pto
ADD CONSTRAINT ap_pto_gml_id_unique UNIQUE (gml_id);

ALTER TABLE IF EXISTS ap_darstellung
ADD CONSTRAINT ap_darstellung_gml_id_unique UNIQUE (gml_id);

-- Hilfstabellen für die Zuordnung
CREATE TABLE IF NOT EXISTS ap_pto_dient (
  pto_id character varying REFERENCES ap_pto(gml_id),
  gml_id character varying
);

CREATE TABLE IF NOT EXISTS ap_darstellung_dient (
  darst_id character varying REFERENCES ap_darstellung(gml_id),
  gml_id character varying
);

-- Daten füllen
INSERT INTO ap_pto_dient (pto_id, gml_id)
SELECT gml_id, unnest(dientzurdarstellungvon)
FROM ap_pto
WHERE art = 'DAF' AND endet IS NULL;

INSERT INTO ap_darstellung_dient (darst_id, gml_id)
SELECT gml_id, unnest(dientzurdarstellungvon)
FROM ap_darstellung
WHERE art = 'DAF' AND endet IS NULL;

-- Ausgabe vor Insert
SELECT 'Dachform-Beschriftungen einfügen';

WITH dachform_map AS (
  SELECT * FROM (VALUES
    ('1000', 'F'), ('2100', 'P'), ('2200', 'VP'), ('3100', 'S'),
    ('3200', 'W'), ('3300', 'KW'), ('3400', 'M'), ('3500', 'Z'),
    ('3600', 'KE'), ('3700', 'KU'), ('3800', 'SH'), ('3900', 'B'),
    ('4000', 'T'), ('5000', 'MD'), ('9999', 'SD')
  ) AS df(code, label)
),
gebaeude_base AS (
  SELECT
    o.gml_id,
    o.wkb_geometry,
    o.advstandardmodell,
    o.sonstigesmodell,
    df.label AS text
  FROM ax_gebaeude o
  JOIN dachform_map df ON o.dachform::text = df.code
  WHERE o.dachform IS NOT NULL AND o.endet IS NULL
),
pto_filtered AS (
  SELECT * FROM ap_pto WHERE art = 'DAF' AND endet IS NULL
),
darst_filtered AS (
  SELECT * FROM ap_darstellung WHERE art = 'DAF' AND endet IS NULL
),
label_data AS (
  SELECT
    g.gml_id,
    COALESCE(t.wkb_geometry, ST_Centroid(g.wkb_geometry)) AS point,
    g.text,
    COALESCE(d.signaturnummer, t.signaturnummer, '4070') AS signaturnummer,
    t.drehwinkel,
    t.horizontaleausrichtung,
    t.vertikaleausrichtung,
    t.skalierung,
    t.fontsperrung,
    COALESCE(t.advstandardmodell || t.sonstigesmodell, g.advstandardmodell || g.sonstigesmodell) AS modell
  FROM gebaeude_base g
  LEFT JOIN ap_pto_dient pd ON g.gml_id = pd.gml_id
  LEFT JOIN pto_filtered t ON t.gml_id = pd.pto_id
  LEFT JOIN ap_darstellung_dient dd ON g.gml_id = dd.gml_id
  LEFT JOIN darst_filtered d ON d.gml_id = dd.darst_id
)
INSERT INTO po_labels (
  gml_id, thema, layer, point, text, signaturnummer,
  drehwinkel, horizontaleausrichtung, vertikaleausrichtung,
  skalierung, fontsperrung, modell
)
SELECT
  gml_id,
  'Gebäude',
  'ax_gebaeude_dachform',
  point,
  text,
  signaturnummer,
  drehwinkel,
  horizontaleausrichtung,
  vertikaleausrichtung,
  skalierung,
  fontsperrung,
  modell
FROM label_data;

-- Ausgabe vor Insert
SELECT 'Gebäudezustände einfügen';

INSERT INTO po_labels (
    gml_id, thema, layer, point, text, signaturnummer,
    drehwinkel, horizontaleausrichtung, vertikaleausrichtung,
    skalierung, fontsperrung, modell
)
SELECT
    o.gml_id,
    'Gebäude',
    'ax_gebaeude_zustand',
    COALESCE(t.wkb_geometry, ST_Centroid(o.wkb_geometry)) AS point,
    COALESCE(
        NULLIF(t.schriftinhalt, ''),
        CASE o.zustand
            WHEN 2200 THEN '(zerstört)'
            WHEN 2300 THEN '(teilweise zerstört)'
            WHEN 3000 THEN '(geplant)'
            WHEN 4000 THEN '(im Bau)'
        END
    ) AS text,
    COALESCE(d.signaturnummer, t.signaturnummer, '4070') AS signaturnummer,
    t.drehwinkel,
    t.horizontaleausrichtung,
    t.vertikaleausrichtung,
    t.skalierung,
    t.fontsperrung,
    COALESCE(
        o.advstandardmodell || o.sonstigesmodell,
        t.advstandardmodell || t.sonstigesmodell
    ) AS modell
FROM ax_gebaeude o
LEFT JOIN ap_pto t
  ON o.gml_id = ANY(t.dientzurdarstellungvon)
 AND t.art = 'ZUS'
 AND t.endet IS NULL
LEFT JOIN ap_darstellung d
  ON o.gml_id = ANY(d.dientzurdarstellungvon)
 AND d.art = 'ZUS'
 AND d.endet IS NULL
WHERE o.zustand IN (2200, 2300, 3000, 4000)
  AND o.endet IS NULL;
