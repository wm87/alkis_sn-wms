--
-- Tatsächliche Nutzung
--

SELECT 'Tatsächliche Nutzungen werden verarbeitet.';

--
-- Wohnbauflächen, Polygone
--
INSERT INTO po_polygons (
    gml_id,
    thema,
    layer,
    polygon,
    signaturnummer,
    modell
)
SELECT
    gml_id,
    'Wohnbauflächen' AS thema,
    'ax_wohnbauflaeche' AS layer,
    st_multi(wkb_geometry) AS polygon,
    25151401 AS signaturnummer,
    COALESCE(advstandardmodell, '{}') || COALESCE(sonstigesmodell, '{}') AS modell
FROM ax_wohnbauflaeche
WHERE endet IS NULL;

--
-- Wohnbauflächen, Labels
--
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
    o.gml_id,
    'Wohnbauflächen' AS thema,
    'ax_wohnbauflaeche' AS layer,
    COALESCE(t.wkb_geometry, st_centroid(o.wkb_geometry)) AS point,
    COALESCE(t.schriftinhalt, o.name) AS text,
    COALESCE(d.signaturnummer, t.signaturnummer, '4141') AS signaturnummer,
    drehwinkel,
    horizontaleausrichtung,
    vertikaleausrichtung,
    skalierung,
    fontsperrung,
    COALESCE(t.advstandardmodell, '{}') ||
    COALESCE(t.sonstigesmodell, '{}') ||
    COALESCE(o.advstandardmodell, '{}') ||
    COALESCE(o.sonstigesmodell, '{}') AS modell
FROM ax_wohnbauflaeche o
LEFT JOIN ap_pto t
       ON o.gml_id = ANY(t.dientzurdarstellungvon)
      AND t.art = 'NAM'
      AND t.endet IS NULL
LEFT JOIN ap_darstellung d
       ON o.gml_id = ANY(d.dientzurdarstellungvon)
      AND d.art = 'NAM'
      AND d.endet IS NULL
WHERE o.endet IS NULL
  AND COALESCE(t.schriftinhalt, o.name) IS NOT NULL;