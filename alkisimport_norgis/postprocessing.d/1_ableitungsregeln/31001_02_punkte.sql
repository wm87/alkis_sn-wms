-- 31001_02_punkte.sql
-- Punktsymbole für Gebäude

-- Ausgabe vor Insert
SELECT 'Punktsymbole für Gebäude einfügen';

INSERT INTO po_points(gml_id,thema,layer,point,drehwinkel,signaturnummer,modell)
SELECT
	o.gml_id,
	'Gebäude' AS thema,
	'ax_gebaeude_funktion' AS layer,
	st_multi(coalesce(p.wkb_geometry,st_centroid(o.wkb_geometry))) AS point,
	coalesce(p.drehwinkel,0) AS drehwinkel,
	coalesce(d.signaturnummer,p.signaturnummer,o.signaturnummer) AS signaturnummer,
	coalesce(p.advstandardmodell||p.sonstigesmodell||d.advstandardmodell||d.sonstigesmodell,o.modell) AS modell
FROM (
	SELECT
		gml_id,
		wkb_geometry,
		CASE gebaeudefunktion
		WHEN 2030 THEN '3300'
		WHEN 2056 THEN '3338'
		WHEN 2071 THEN '3302'
		WHEN 2072 THEN '3303'
		WHEN 2081 THEN '3305'
		WHEN 2092 THEN '3306'
		WHEN 2094 THEN '3308'
		WHEN 2461 THEN '3309' WHEN 2462 THEN '3309'
		WHEN 2465 THEN '3336'
		WHEN 2523 THEN CASE WHEN gml_id LIKE 'DERP%' THEN 'RP3521' ELSE '3521' END
		WHEN 2612 THEN '3311'
		WHEN 3013 THEN '3312'
		WHEN 3032 THEN '3314'
		WHEN 3037 THEN '3315'
		WHEN 3041 THEN '3316' -- TODO: PNR 1113?
		WHEN 3042 THEN '3317'
		WHEN 3043 THEN '3318' -- TODO: PNR 1113?
		WHEN 3046 THEN '3319'
		WHEN 3047 THEN '3320'
		WHEN 3051 THEN '3321' WHEN 3052 THEN '3321'
		WHEN 3065 THEN '3323'
		WHEN 3071 THEN '3324'
		WHEN 3072 THEN '3326'
		WHEN 3094 THEN '3328'
		WHEN 3095 THEN '3330'
		WHEN 3097 THEN '3332'
		WHEN 3221 THEN '3334'
		WHEN 3290 THEN '3340'
		END AS signaturnummer,
		advstandardmodell||sonstigesmodell AS modell
	FROM ax_gebaeude
	WHERE endet IS NULL
) AS o
LEFT OUTER JOIN ap_ppo p ON o.gml_id = ANY(p.dientzurdarstellungvon) AND p.art='GFK' AND p.endet IS NULL
LEFT OUTER JOIN ap_darstellung d ON o.gml_id = ANY(d.dientzurdarstellungvon) AND d.art='GFK' AND d.endet IS NULL
WHERE NOT o.signaturnummer IS NULL;
