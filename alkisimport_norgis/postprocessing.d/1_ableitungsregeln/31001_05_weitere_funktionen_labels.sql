-- 31001_05_weitere_funktionen_labels.sql
-- Weitere Gebäudefunktionsbeschriftungen

-- Ausgabe vor Insert
SELECT 'Weitere Gebäudefunktionsbeschriftungen einfügen';

INSERT INTO po_labels (
    gml_id, thema, layer, point, text, signaturnummer,
    drehwinkel, horizontaleausrichtung, vertikaleausrichtung,
    skalierung, fontsperrung, modell
)
SELECT
    o.gml_id,
    'Gebäude',
    'ax_gebaeude_funktion',
    COALESCE(t.wkb_geometry, ST_Centroid(o.wkb_geometry)) AS point,
    o.label_text AS text,
    COALESCE(d.signaturnummer, n.signaturnummer, t.signaturnummer, '4070') AS signaturnummer,
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
FROM (
    SELECT
        gml_id,
        wkb_geometry,
        unnest(COALESCE(name, ARRAY[NULL])) AS name,
        unnest(weiteregebaeudefunktion) AS gebaeudefunktion,
        advstandardmodell || sonstigesmodell AS modell,
        CASE
            WHEN gebaeudefunktion = 1100 AND COALESCE(name, NULL) IS NULL THEN 'Zoll'
            WHEN gebaeudefunktion = 1129 AND COALESCE(name, NULL) IS NULL THEN 'Museum'
        END AS label_text
    FROM ax_gebaeude
    WHERE endet IS NULL
) AS o
LEFT JOIN ap_pto t
  ON o.gml_id = ANY(t.dientzurdarstellungvon)
 AND t.art = 'GFK'
 AND t.endet IS NULL
LEFT JOIN ap_pto n
  ON o.gml_id = ANY(n.dientzurdarstellungvon)
 AND n.art = 'NAM'
 AND n.endet IS NULL
LEFT JOIN ap_darstellung d
  ON o.gml_id = ANY(d.dientzurdarstellungvon)
 AND d.art IN ('NAM','GFK')
 AND d.endet IS NULL
WHERE o.gebaeudefunktion IS NOT NULL
  AND o.label_text IS NOT NULL;
