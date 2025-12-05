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
            (SELECT bezeichnung
             FROM ax_gemarkung b
             WHERE a.gemeindezugehoerigkeit_land=b.land
               AND a.gemarkungsnummer=b.gemarkungsnummer
               AND b.endet IS NULL
             LIMIT 1),
            '(Gemarkung '||gemeindezugehoerigkeit_land||gemarkungsnummer||')'
        ) AS gemarkungsname
    FROM ax_flurstueck a
    WHERE endet IS NULL
    GROUP BY gemeindezugehoerigkeit_land,
             gemeindezugehoerigkeit_regierungsbezirk,
             gemeindezugehoerigkeit_kreis,
             gemeindezugehoerigkeit_gemeinde,
             gemarkungsnummer
    ORDER BY gemeindezugehoerigkeit_land,
             gemeindezugehoerigkeit_regierungsbezirk,
             gemeindezugehoerigkeit_kreis,
             gemeindezugehoerigkeit_gemeinde,
             gemarkungsnummer;

CREATE INDEX pp_gemarkungen_lrkg
    ON pp_gemarkungen(gemeindezugehoerigkeit_land,
                      gemeindezugehoerigkeit_regierungsbezirk,
                      gemeindezugehoerigkeit_kreis,
                      gemeindezugehoerigkeit_gemeinde);

CREATE INDEX pp_gemarkungen_lg
    ON pp_gemarkungen(gemeindezugehoerigkeit_land, gemarkungsnummer);

ANALYZE pp_gemarkungen;

\set gemarkung_simplify 2.2
\set gemeinde_simplify 5.0


--
-- Gemarkungen
--
SELECT 'Gemarkungsgrenzen werden aufbereitet...';

WITH polygons_norm AS (
    SELECT
        gml_id,
        polygon,
        layer,
        substring(layer FROM 'ax_flurstueck_flur_([0-9]+)([0-9]+)') AS gemarkung_key
    FROM po_polygons
)
INSERT INTO po_polygons(gml_id,thema,layer,signaturnummer,sn_randlinie,modell,polygon)
SELECT
    MIN(p.gml_id) AS gml_id,
    'Politische Grenzen' AS thema,
    'ax_flurstueck_gemarkung_' || g.gemeindezugehoerigkeit_land || g.gemarkungsnummer AS layer,
    'pg-gemarkung' AS signaturnummer,
    'pg-gemarkung' AS sn_randlinie,
    ARRAY['norGIS'] AS modell,
    ST_Multi(
        ST_Simplify(
            ST_UnaryUnion(
                ST_Collect(
                    ST_MakeValid(
                        ST_SnapToGrid(p.polygon, 0.001)
                    )
                )
            ),
            :gemarkung_simplify
        )
    ) AS polygon
FROM polygons_norm p
JOIN pg_temp.pp_gemarkungen g
  ON p.gemarkung_key = g.gemeindezugehoerigkeit_land || g.gemarkungsnummer
GROUP BY g.gemeindezugehoerigkeit_land, g.gemarkungsnummer;


WITH polygons_norm AS (
    SELECT
        gml_id,
        polygon,
        layer,
        -- extrahiere den Schlüssel aus dem Layer-String
        substring(layer FROM 'ax_flurstueck_flur_([0-9]+)([0-9]+)') AS gemarkung_key
    FROM po_polygons
)
INSERT INTO po_labels(gml_id,thema,layer,point,text,signaturnummer,drehwinkel,modell)
SELECT
    p.gml_id,
    'Politische Grenzen' AS thema,
    p.layer,
    ST_PointOnSurface(p.polygon) AS point,
    g.gemarkungsname AS text,
    'pg-gemarkung' AS signaturnummer,
    0 AS drehwinkel,
    ARRAY['norGIS'] AS modell
FROM polygons_norm p
JOIN pp_gemarkungen g
  ON p.gemarkung_key = g.gemeindezugehoerigkeit_land || g.gemarkungsnummer;

