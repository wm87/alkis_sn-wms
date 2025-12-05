-- Überhaken
SELECT 'Erzeuge Überhaken...';
INSERT INTO po_points(gml_id,thema,layer,point,drehwinkel,signaturnummer,modell)
SELECT
	o.gml_id,
	'Flurstücke' AS thema,
	'ax_flurstueck' AS layer,
	st_multi(p.wkb_geometry) AS point,
	coalesce(p.drehwinkel,0) AS drehwinkel,
	CASE WHEN o.abweichenderrechtszustand='true' THEN 3011 ELSE 3010 END AS signaturnummer,
	coalesce(p.advstandardmodell||p.sonstigesmodell,o.advstandardmodell||o.sonstigesmodell) AS modell
FROM ax_flurstueck o
JOIN ap_ppo p ON ARRAY[o.gml_id] <@ p.dientzurdarstellungvon AND p.art='Haken' AND p.endet IS NULL
WHERE o.endet IS NULL;
