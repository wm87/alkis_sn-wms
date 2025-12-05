SELECT 'Flurnummer';

INSERT INTO po_labels(gml_id,thema,layer,point,text,signaturnummer,drehwinkel,
    horizontaleausrichtung,vertikaleausrichtung,skalierung,fontsperrung,modell)
SELECT
    o.gml_id,
    'Lagebezeichnungen',
    'ax_gemarkungsteilflur',
    t.wkb_geometry,
    coalesce(schriftinhalt, CASE WHEN bezeichnung LIKE 'Flur %' THEN bezeichnung ELSE 'Flur '||bezeichnung END),
    coalesce(t.signaturnummer,'4200'),
    t.drehwinkel, t.horizontaleausrichtung, t.vertikaleausrichtung, t.skalierung, t.fontsperrung,
    coalesce(t.advstandardmodell||t.sonstigesmodell,o.advstandardmodell||o.sonstigesmodell)
FROM ax_gemarkungsteilflur o
JOIN ap_pto t 
    ON o.gml_id = ANY(t.dientzurdarstellungvon)
   AND t.art = 'BEZ'
   AND t.endet IS NULL
WHERE coalesce(t.schriftinhalt,'') <> 'Flur 0'
  AND o.endet IS NULL;
