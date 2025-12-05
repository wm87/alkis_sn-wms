-- Zuordnungspfeile
SELECT 'Erzeuge Zuordnungspfeile...';


CREATE TABLE ap_lpo_flst_join (
    lpo_id text NOT NULL,       -- Primärschlüssel von ap_lpo
    flst_id text NOT NULL       -- einzelne GML-ID aus dientzurdarstellungvon
);

-- Indexe für maximale Performance
CREATE INDEX idx_ap_lpo_flst_join_flst ON ap_lpo_flst_join(flst_id);
CREATE INDEX idx_ap_lpo_flst_join_lpo  ON ap_lpo_flst_join(lpo_id);

-- Join-Tabelle füllen
INSERT INTO ap_lpo_flst_join (lpo_id, flst_id)
SELECT
    l.gml_id,
    unnest(l.dientzurdarstellungvon)
FROM ap_lpo l
WHERE l.dientzurdarstellungvon IS NOT NULL;


INSERT INTO po_lines(gml_id, thema, layer, line, signaturnummer, modell)
SELECT
    o.gml_id,
    'Flurstücke' AS thema,
    'ax_flurstueck_zuordnung' AS layer,
    ST_Multi(l.wkb_geometry) AS line,
    CASE 
        WHEN o.abweichenderrechtszustand = 'true' THEN 2005
        ELSE 2004
    END AS signaturnummer,
    COALESCE(
        l.advstandardmodell || l.sonstigesmodell,
        o.advstandardmodell || o.sonstigesmodell
    ) AS modell
FROM ax_flurstueck o
JOIN ap_lpo_flst_join j
       ON j.flst_id = o.gml_id
JOIN ap_lpo l
       ON l.gml_id = j.lpo_id
WHERE o.endet IS NULL
  AND l.endet IS NULL;
