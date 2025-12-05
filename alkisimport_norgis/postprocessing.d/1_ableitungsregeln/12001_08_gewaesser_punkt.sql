SELECT 'Lagebezeichnung Fließgewässer/Stehendes Gewässer';

INSERT INTO po_labels(gml_id,thema,layer,point,text,signaturnummer,drehwinkel,
    horizontaleausrichtung,vertikaleausrichtung,skalierung,fontsperrung,modell)
SELECT
    o.gml_id,
    'Gewässer' AS thema,
    'ax_lagebezeichnungohnehausnummer' AS layer,
    t.wkb_geometry AS point,
    coalesce(
        schriftinhalt,
        unverschluesselt,
        (SELECT bezeichnung
         FROM ax_lagebezeichnungkatalogeintrag
         WHERE schluesselgesamt = to_char(o.land::int,'fm00')
             || coalesce(o.regierungsbezirk,'0')
             || to_char(o.kreis::int,'fm00')
             || to_char(o.gemeinde::int,'fm000')
             || o.lage
         ORDER BY beginnt DESC
         LIMIT 1),
        '(Lagebezeichnung zu '''||to_char(o.land::int,'fm00')||coalesce(o.regierungsbezirk,'0')
         || to_char(o.kreis::int,'fm00')||to_char(o.gemeinde::int,'fm000')||o.lage||''' fehlt)'
    ) AS text,
    coalesce(t.signaturnummer,'4117') AS signaturnummer,
    drehwinkel, horizontaleausrichtung, vertikaleausrichtung, skalierung, fontsperrung,
    coalesce(t.advstandardmodell||t.sonstigesmodell,
             o.advstandardmodell||o.sonstigesmodell) AS modell
FROM ax_lagebezeichnungohnehausnummer o
JOIN ap_pto t
  ON o.gml_id = ANY(t.dientzurdarstellungvon)
 AND t.art IN ('Fliessgewaesser','StehendesGewaesser')
 AND t.endet IS NULL
WHERE o.endet IS NULL;
