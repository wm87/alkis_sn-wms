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

CREATE TEMPORARY TABLE pp_gemarkungen AS
	SELECT
		gemeindezugehoerigkeit_land,
		coalesce(gemeindezugehoerigkeit_regierungsbezirk,'') AS gemeindezugehoerigkeit_regierungsbezirk,
		gemeindezugehoerigkeit_kreis,
		gemeindezugehoerigkeit_gemeinde,
		gemarkungsnummer,
		coalesce(
			(SELECT bezeichnung FROM ax_gemarkung b WHERE a.gemeindezugehoerigkeit_land=b.land AND a.gemarkungsnummer=b.gemarkungsnummer AND b.endet IS NULL LIMIT 1),
			'(Gemarkung '||gemeindezugehoerigkeit_land||gemarkungsnummer||')'
		) AS gemarkungsname
	FROM ax_flurstueck a
	WHERE endet IS NULL
	GROUP BY gemeindezugehoerigkeit_land, gemeindezugehoerigkeit_regierungsbezirk, gemeindezugehoerigkeit_kreis, gemeindezugehoerigkeit_gemeinde, gemarkungsnummer
	ORDER BY gemeindezugehoerigkeit_land, gemeindezugehoerigkeit_regierungsbezirk, gemeindezugehoerigkeit_kreis, gemeindezugehoerigkeit_gemeinde, gemarkungsnummer;

CREATE INDEX pp_gemarkungen_lrkg ON pp_gemarkungen(gemeindezugehoerigkeit_land, gemeindezugehoerigkeit_regierungsbezirk, gemeindezugehoerigkeit_kreis, gemeindezugehoerigkeit_gemeinde);
CREATE INDEX pp_gemarkungen_lg ON pp_gemarkungen(gemeindezugehoerigkeit_land, gemarkungsnummer);
ANALYZE pp_gemarkungen;

CREATE TEMPORARY TABLE pp_gemeinden AS
	SELECT
		gemeindezugehoerigkeit_land,
		coalesce(gemeindezugehoerigkeit_regierungsbezirk,'') AS gemeindezugehoerigkeit_regierungsbezirk,
		gemeindezugehoerigkeit_kreis,
		gemeindezugehoerigkeit_gemeinde,
		coalesce(
			(SELECT bezeichnung FROM ax_gemeinde b WHERE a.gemeindezugehoerigkeit_land=b.land AND coalesce(a.gemeindezugehoerigkeit_regierungsbezirk,'')=coalesce(b.regierungsbezirk,'') AND a.gemeindezugehoerigkeit_kreis=b.kreis AND a.gemeindezugehoerigkeit_gemeinde=b.gemeinde AND b.endet IS NULL LIMIT 1),
			'(Gemeinde '||gemeindezugehoerigkeit_land||coalesce(gemeindezugehoerigkeit_regierungsbezirk,'')||gemeindezugehoerigkeit_kreis||gemeindezugehoerigkeit_gemeinde||')'
		) AS gemeindename
	FROM pg_temp.pp_gemarkungen a
	GROUP BY gemeindezugehoerigkeit_land, gemeindezugehoerigkeit_regierungsbezirk, gemeindezugehoerigkeit_kreis, gemeindezugehoerigkeit_gemeinde
	ORDER BY gemeindezugehoerigkeit_land, gemeindezugehoerigkeit_regierungsbezirk, gemeindezugehoerigkeit_kreis, gemeindezugehoerigkeit_gemeinde;

CREATE INDEX pp_gemeinden_lrkg ON pp_gemeinden(gemeindezugehoerigkeit_land, gemeindezugehoerigkeit_regierungsbezirk, gemeindezugehoerigkeit_kreis, gemeindezugehoerigkeit_gemeinde);
ANALYZE pp_gemeinden;

\set gemeinde_simplify 5.0

--
-- Gemeinden
--
SELECT 'Gemeindegrenzen werden aufbereitet...';

INSERT INTO po_polygons(gml_id,thema,layer,signaturnummer,sn_randlinie,modell,polygon)
	SELECT
		min(gml_id) AS gml_id,
		'Politische Grenzen' AS thema,
		'ax_flurstueck_gemeinde_'||gemeindezugehoerigkeit_land||gemeindezugehoerigkeit_regierungsbezirk||gemeindezugehoerigkeit_kreis||gemeindezugehoerigkeit_gemeinde AS layer,
		'pg-gemeinde' AS signaturnummer,
		'pg-gemeinde' AS sn_randlinie,
		ARRAY['norGIS'] AS modell,
		st_multi(st_simplify(st_union(st_buffer(polygon,0.20)), :gemeinde_simplify)) AS polygon
	FROM po_polygons
	JOIN pg_temp.pp_gemarkungen ON layer='ax_flurstueck_gemarkung_'||gemeindezugehoerigkeit_land||gemarkungsnummer
	GROUP BY gemeindezugehoerigkeit_land, gemeindezugehoerigkeit_regierungsbezirk, gemeindezugehoerigkeit_kreis, gemeindezugehoerigkeit_gemeinde;

INSERT INTO po_labels(gml_id,thema,layer,point,text,signaturnummer,drehwinkel,modell)
	SELECT
		gml_id,
		'Politische Grenzen' AS thema,
		layer,
		pg_temp.pointonsurface(polygon) AS point,
		gemeindename AS text,
		'pg-gemeinde' AS signaturnummer,
		0 AS drehwinkel,
		ARRAY['norGIS'] AS modell
	FROM po_polygons
	JOIN pg_temp.pp_gemeinden p ON layer='ax_flurstueck_gemeinde_'||gemeindezugehoerigkeit_land||gemeindezugehoerigkeit_regierungsbezirk||gemeindezugehoerigkeit_kreis||gemeindezugehoerigkeit_gemeinde;
