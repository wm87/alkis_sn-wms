-- 31001_04_weitere_funktionen.sql
-- Weitere Gebäudefunktionen (Punkte)

-- Ausgabe vor Insert
SELECT 'Weitere Gebäudefunktionen einfügen';

WITH funktion_mapping AS (
    SELECT * FROM (VALUES
        (1000,'3300'), (1010,'3302'), (1020,'3303'), (1030,'3305'),
        (1040,'3306'), (1050,'3308'), (1060,'3336'), (1070,'3309'),
        (1080,'3311'), (1090,'3112'), (1110,'3314'), (1130,'3315'),
        (1140,'3318'), (1150,'3319'), (1160,'3320'), (1170,'3338'),
        (1180,'3324'), (1190,'3321'), (1200,'3340'), (1210,'3323'),
        (1220,'3324')
    ) AS t(gebaeudefunktion, signaturnummer)
),
gebaeude_funktion AS (
    SELECT
        g.gml_id,
        g.wkb_geometry,
        fm.signaturnummer,
        g.advstandardmodell || g.sonstigesmodell AS modell
    FROM ax_gebaeude g
    JOIN LATERAL unnest(g.weiteregebaeudefunktion) AS u(gebaeudefunktion) ON TRUE
    LEFT JOIN funktion_mapping fm ON u.gebaeudefunktion = fm.gebaeudefunktion
    WHERE g.endet IS NULL
)
INSERT INTO po_points (
    gml_id, thema, layer, point, drehwinkel, signaturnummer, modell
)
SELECT
    o.gml_id,
    'Gebäude',
    'ax_gebaeude_funktion',
    ST_Multi(COALESCE(p.wkb_geometry, ST_Centroid(o.wkb_geometry))),
    p.drehwinkel,
    COALESCE(d.signaturnummer, p.signaturnummer, o.signaturnummer),
    COALESCE(p.advstandardmodell || p.sonstigesmodell, o.modell)
FROM gebaeude_funktion o
LEFT JOIN ap_ppo p
  ON o.gml_id = ANY(p.dientzurdarstellungvon)
 AND p.art = 'GFK'
 AND p.endet IS NULL
LEFT JOIN ap_darstellung d
  ON o.gml_id = ANY(d.dientzurdarstellungvon)
 AND d.art = 'GFK'
 AND d.endet IS NULL
WHERE o.signaturnummer IS NOT NULL;
