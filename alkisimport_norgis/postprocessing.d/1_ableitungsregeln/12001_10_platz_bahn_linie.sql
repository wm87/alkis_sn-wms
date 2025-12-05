SELECT 'Lagebezeichnung Platz/Bahnverkehr, Text auf Linien';

INSERT INTO po_labels(gml_id,thema,layer,line,text,signaturnummer,
    horizontaleausrichtung,vertikaleausrichtung,skalierung,fontsperrung,modell)
SELECT
    o.gml_id,
    'Lagebezeichnungen' AS thema,
    'ax_lagebezeichnungohnehausnummer' AS layer,
    t.wkb_geometry AS line,
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
    4141 AS signaturnummer,
    horizontaleausrichtung, vertikaleausrichtung, skalierung, fontsperrung,
    coalesce(t.advstandardmodell||t.sonstigesmodell,
             o.advstandardmodell||o.sonstigesmodell) AS modell
FROM ax_lagebezeichnungohnehausnummer o
JOIN ap_lto t
  ON o.gml_id = ANY(t.dientzurdarstellungvon)
 AND t.art IN ('Platz','Bahnverkehr')
 AND t.endet IS NULL
 AND coalesce(t.signaturnummer,'') <> '6000'
WHERE o.endet IS NULL;
