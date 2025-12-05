-- 31001_01_polygone.sql
-- Gebäudeflächen (Polygone) erzeugen

-- Ausgabe vor Insert
SELECT 'Gebäudeflächen, Polygone einfügen';

INSERT INTO po_polygons(gml_id,thema,layer,polygon,signaturnummer,modell)
SELECT
	gml_id,
	'Gebäude' AS thema,
	'ax_gebaeude' AS layer,
	polygon,
	signaturnummer,
	modell
FROM (
	SELECT
		gml_id,
		st_multi(wkb_geometry) AS polygon,
		CASE
		WHEN gfk='1XXX' THEN
			CASE
			WHEN NOT hoh AND NOT verfallen AND ofl=0           THEN 25051301
			WHEN     hoh AND NOT verfallen AND ofl=0           THEN 26231301
			WHEN     hoh AND     verfallen AND ofl IN (0,1400) THEN 2030
			WHEN     hoh AND NOT verfallen AND ofl=1400        THEN 20301301
			WHEN NOT hoh AND     verfallen AND ofl IN (0,1400) THEN 2031
			WHEN NOT hoh AND NOT verfallen AND ofl=1400        THEN 20311301
			WHEN NOT hoh                   AND ofl=1200        THEN 2032
			END
		WHEN gfk='2XXX' THEN
			CASE
			WHEN NOT hoh AND NOT verfallen AND ofl=0 THEN
				CASE
				WHEN baw=0     THEN 25051304
				WHEN baw<>4000 THEN 25051304
				WHEN baw=4000  THEN 20311304
				END
			WHEN     hoh AND NOT verfallen AND ofl=0           THEN 26231304
			WHEN     hoh AND     verfallen AND ofl IN (0,1400) THEN 2030
			WHEN     hoh AND NOT verfallen AND ofl=1400        THEN 20301304
			WHEN     hoh AND     verfallen AND ofl IN (0,1400) THEN 2031
			WHEN NOT hoh AND NOT verfallen AND ofl=1400        THEN 20311304
			WHEN NOT hoh                   AND ofl=1200        THEN 2032
			END
		WHEN gfk='3XXX' THEN
			CASE
			WHEN NOT hoh AND NOT verfallen AND ofl=0 THEN
				CASE
				WHEN baw=0     THEN 25051309
				WHEN baw<>4000 THEN 25051309
				WHEN baw=4000  THEN 20311309
				END
			WHEN     hoh AND NOT verfallen AND ofl=0           THEN 26231309
			WHEN     hoh AND     verfallen AND ofl IN (0,1400) THEN 2030
			WHEN     hoh AND NOT verfallen AND ofl=1400        THEN 20301309
			WHEN NOT hoh AND     verfallen AND ofl IN (0,1400) THEN 2031
			WHEN NOT hoh AND NOT verfallen AND ofl=1400        THEN 20311309
			WHEN NOT hoh                   AND ofl=1200        THEN 2032
			END
		WHEN gfk='9998' THEN
			CASE
			WHEN NOT hoh AND NOT verfallen AND ofl=0           THEN 25051304
			WHEN     hoh AND NOT verfallen AND ofl=0           THEN 26231304
			WHEN     hoh AND     verfallen AND ofl IN (0,1400) THEN 2030
			WHEN     hoh AND NOT verfallen AND ofl=1400        THEN 20301304
			WHEN NOT hoh AND     verfallen AND ofl IN (0,1400) THEN 2031
			WHEN NOT hoh AND NOT verfallen AND ofl=1400        THEN 20311304
			WHEN NOT hoh                   AND ofl=1200        THEN 2032
			END
		END AS signaturnummer,
		modell
	FROM (
		SELECT
			o.gml_id,
			CASE
			WHEN gebaeudefunktion BETWEEN 1000 AND 1999 THEN '1XXX'
			WHEN gebaeudefunktion BETWEEN 2000 AND 2999 THEN '2XXX'
			WHEN gebaeudefunktion BETWEEN 3000 AND 3999 THEN '3XXX'
			ELSE gebaeudefunktion::text
			END AS gfk,
			coalesce(hochhaus,'false')='true' AS hoh,
			coalesce(zustand,0) IN (2200,2300,3000,4000) AS verfallen,
			coalesce(lagezurerdoberflaeche,0) AS ofl,
			coalesce(bauweise,0) AS baw,
			wkb_geometry,
			o.advstandardmodell||o.sonstigesmodell AS modell
		FROM ax_gebaeude o
		WHERE o.endet IS NULL AND geometrytype(wkb_geometry) IN ('POLYGON','MULTIPOLYGON')
	) AS o
) AS o
WHERE NOT signaturnummer IS NULL;
