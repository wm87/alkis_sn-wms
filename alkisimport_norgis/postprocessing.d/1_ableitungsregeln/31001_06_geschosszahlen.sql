-- 31001_06_geschosszahlen.sql
-- Geschosszahl-Label-Erzeugung

-- Ausgabe vor Insert
SELECT 'Gebäudegeschosse einfügen';

WITH darstellung_expanded AS (
  SELECT
    d.signaturnummer,
    unnest(d.dientzurdarstellungvon) AS darstellungs_gml_id
  FROM ap_darstellung d
  WHERE d.art = 'AOG_AUG' AND d.endet IS NULL
),
pto_expanded AS (
  SELECT
    t.wkb_geometry,
    t.signaturnummer,
    t.drehwinkel,
    t.horizontaleausrichtung,
    t.vertikaleausrichtung,
    t.skalierung,
    t.fontsperrung,
    t.advstandardmodell,
    t.sonstigesmodell,
    unnest(t.dientzurdarstellungvon) AS darstellungs_gml_id
  FROM ap_pto t
  WHERE t.art = 'AOG_AUG' AND t.endet IS NULL
),
gefilterte_gebaeude AS (
  SELECT *
  FROM ax_gebaeude
  WHERE (anzahlderoberirdischengeschosse IS NOT NULL OR anzahlderunterirdischengeschosse IS NOT NULL)
    AND endet IS NULL
),
geschosszahl_text AS (
  SELECT
    gml_id,
    CASE
      WHEN anzahlderoberirdischengeschosse IS NOT NULL AND anzahlderunterirdischengeschosse IS NOT NULL THEN
        trim(to_char(anzahlderoberirdischengeschosse, 'FM999')) || ' / -' || trim(to_char(anzahlderunterirdischengeschosse, 'FM999'))
      WHEN anzahlderoberirdischengeschosse IS NOT NULL THEN
        trim(to_char(anzahlderoberirdischengeschosse, 'FM999'))
      WHEN anzahlderunterirdischengeschosse IS NOT NULL THEN
        '-' || trim(to_char(anzahlderunterirdischengeschosse, 'FM999'))
    END AS text
  FROM gefilterte_gebaeude
)
INSERT INTO po_labels (
  gml_id, thema, layer, point, text, signaturnummer,
  drehwinkel, horizontaleausrichtung, vertikaleausrichtung,
  skalierung, fontsperrung, modell
)
SELECT
  o.gml_id,
  'Gebäude',
  'ax_gebaeude_geschosse',
  COALESCE(t.wkb_geometry, ST_Centroid(o.wkb_geometry)) AS point,
  gt.text,
  COALESCE(d.signaturnummer, t.signaturnummer, '4070') AS signaturnummer,
  t.drehwinkel,
  t.horizontaleausrichtung,
  t.vertikaleausrichtung,
  t.skalierung,
  t.fontsperrung,
  COALESCE(
    t.advstandardmodell || t.sonstigesmodell,
    o.advstandardmodell || o.sonstigesmodell
  ) AS modell
FROM gefilterte_gebaeude o
JOIN geschosszahl_text gt ON o.gml_id = gt.gml_id
LEFT JOIN pto_expanded t ON o.gml_id = t.darstellungs_gml_id
LEFT JOIN darstellung_expanded d ON o.gml_id = d.darstellungs_gml_id;
