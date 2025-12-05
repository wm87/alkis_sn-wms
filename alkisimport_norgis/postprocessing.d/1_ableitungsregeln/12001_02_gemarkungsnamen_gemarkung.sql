SELECT 'Gemarkungsnamen (RP)';

INSERT INTO po_labels(gml_id,thema,layer,point,text,signaturnummer,drehwinkel,
    horizontaleausrichtung,vertikaleausrichtung,skalierung,fontsperrung,modell)
SELECT
    o.gml_id,
    'Lagebezeichnungen',
    'ax_gemarkung',
    t.wkb_geometry,
    coalesce(t.schriftinhalt,o.bezeichnung),
    coalesce(t.signaturnummer,'4200'),
    t.drehwinkel, t.horizontaleausrichtung, t.vertikaleausrichtung, t.skalierung, t.fontsperrung,
    coalesce(t.advstandardmodell||t.sonstigesmodell,o.advstandardmodell||o.sonstigesmodell)
FROM ax_gemarkung o
JOIN ap_pto t 
    ON o.gml_id = ANY(t.dientzurdarstellungvon)
   AND t.art='BEZ'
   AND t.endet IS NULL
   AND t.schriftinhalt IS NOT NULL
WHERE o.endet IS NULL
  AND o.gml_id LIKE 'DERP%';
