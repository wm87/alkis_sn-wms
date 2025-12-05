DELETE FROM alkis_schriften WHERE signaturnummer IN ('pg-flur','pg-gemarkung','pg-gemeinde','pg-kreis');
DELETE FROM alkis_linie WHERE signaturnummer IN ('pg-flur','pg-gemarkung','pg-gemeinde','pg-kreis');
DELETE FROM alkis_linien WHERE signaturnummer IN ('pg-flur','pg-gemarkung','pg-gemeinde','pg-kreis');

INSERT INTO alkis_linien(katalog,signaturnummer,darstellungsprioritaet,name)
	SELECT
		katalog,
		signaturnummer,
		'450' AS darstellungsprioritaet,
		ARRAY['norGIS: ' || CASE signaturnummer
		WHEN 'pg-flur' THEN 'Flurgrenze'
		WHEN 'pg-gemarkung' THEN 'Gemarkungsgrenze'
		WHEN 'pg-gemeinde' THEN 'Gemeindegrenze'
		WHEN 'pg-kreis' THEN 'Kreisgrenze'
		END] AS name
	FROM generate_series(1,2) AS katalog, unnest(ARRAY['pg-flur','pg-gemarkung','pg-gemeinde','pg-kreis']) AS signaturnummer;

INSERT INTO alkis_linie(id,i,katalog,signaturnummer,strichart,abschluss,scheitel,strichstaerke,pfeilhoehe,pfeillaenge,farbe,position)
	SELECT
		(SELECT max(id)+1 FROM alkis_linie)+row_number() OVER () AS id,
		0 AS i,
		katalog,
		signaturnummer,
		NULL AS strichart,
		/* abschluss */ 'Abgeschnitten',
		/* scheitel */ 'Spitz',
		CASE signaturnummer
		WHEN 'pg-flur' THEN -40
		WHEN 'pg-gemarkung' THEN -60
		WHEN 'pg-gemeinde' THEN -80
		WHEN 'pg-kreis' THEN -100
		END AS grad_pt,
		NULL AS pfeilhoehe,
		NULL AS pfeillaenge,
		(SELECT farbe FROM alkis_linie WHERE katalog=1 AND signaturnummer='2012' AND i=0) AS farbe, -- Farbe aus Flurgrenze 2028
		NULL as position
	FROM generate_series(1,2) AS katalog, unnest(ARRAY['pg-flur','pg-gemarkung','pg-gemeinde','pg-kreis']) AS signaturnummer;

INSERT INTO alkis_schriften(katalog,signaturnummer,darstellungsprioritaet,name,seite,art,stil,grad_pt,horizontaleausrichtung,vertikaleausrichtung,farbe,alignment_umn,alignment_dxf,sperrung_pt,effekt,position)
	SELECT
		katalog,
		signaturnummer,
		'450' AS darstellungsprioritaet,
		ARRAY['norGIS: ' || CASE signaturnummer
		WHEN 'pg-flur' THEN 'Flurgrenze'
		WHEN 'pg-gemarkung' THEN 'Gemarkungsgrenze'
		WHEN 'pg-gemeinde' THEN 'Gemeindegrenze'
		WHEN 'pg-kreis' THEN 'Kreisgrenze'
		END] AS name,
		NULL AS seite,
		'Arial' AS art,
		'Normal' AS stil,
		CASE signaturnummer
		WHEN 'pg-flur' THEN -6
		WHEN 'pg-gemarkung' THEN -10
		WHEN 'pg-gemeinde' THEN -12
		WHEN 'pg-kreis' THEN -14
		END AS grad_pt,
		'zentrisch' AS horizontaleausrichtung,
		'Mitte' AS vertikaleausrichtung,
		(SELECT farbe FROM alkis_linie WHERE katalog=1 AND signaturnummer='2012' and i=0) AS farbe, -- Farbe wie Grenze
		'CC' AS alignment_umn,
		5 AS alignment_dxf,
		NULL AS sperrung_pt,
		NULL AS effekt,
		NULL AS position
	FROM generate_series(1,2) AS katalog, unnest(ARRAY['pg-flur','pg-gemarkung','pg-gemeinde','pg-kreis']) AS signaturnummer;

DELETE FROM po_polygons WHERE sn_randlinie IN ('pg-flur','pg-gemarkung','pg-gemeinde','pg-kreis');
DELETE FROM po_labels WHERE signaturnummer IN ('pg-flur','pg-gemarkung','pg-gemeinde','pg-kreis');


SELECT alkis_dropobject('ax_flurstueck_lgf');
CREATE INDEX ax_flurstueck_lgf ON ax_flurstueck(gemeindezugehoerigkeit_land,gemarkungsnummer,flurnummer);


CREATE FUNCTION pg_temp.pointonsurface(polygon GEOMETRY) RETURNS GEOMETRY AS $$
BEGIN
	BEGIN
		RETURN st_pointonsurface(polygon);
	EXCEPTION WHEN OTHERS THEN
		BEGIN
			RETURN st_centroid(polygon);
		EXCEPTION WHEN OTHERS THEN
			RETURN NULL;
		END;
	END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;
