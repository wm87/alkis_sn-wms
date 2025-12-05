SELECT 'Lagebezeichnung Ortsteil';

INSERT INTO po_labels(gml_id,thema,layer,point,text,signaturnummer,drehwinkel,
    horizontaleausrichtung,vertikaleausrichtung,skalierung,fontsperrung,modell)
SELECT
    o.gml_id,
    'Lagebezeichnungen',
    'ax_lagebezeichnungohnehausnummer',
    t.wkb_geometry,
    schriftinhalt,
    coalesce(t.signaturnummer,'4160'),
    t.drehwinkel, t.horizontaleausrichtung, t.vertikaleausrichtung, t.skalierung, t.fontsperrung,
    coalesce(t.advstandardmodell||t.sonstigesmodell,o.advstandardmodell||o.sonstigesmodell)
FROM ax_lagebezeichnungohnehausnummer o
JOIN ap_pto t 
    ON o.gml_id = ANY(t.dientzurdarstellungvon)
   AND t.art='Ort'
   AND t.endet IS NULL
WHERE coalesce(schriftinhalt,'') <> ''
  AND o.endet IS NULL;
