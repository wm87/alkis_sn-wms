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

\set flur_buffer 0.06
\set flur_simplify 0.5

--
-- Flure
--
-- Meldung ausgeben
SELECT 'Flurgrenzen werden aufbereitet...';

-- Aggregation der Flurstücke
WITH active_flurstuecke AS (
    SELECT 
        gml_id,
        gemeindezugehoerigkeit_land,
        gemarkungsnummer,
        COALESCE(flurnummer, 0) AS flurnummer,
        st_snaptogrid(wkb_geometry, 0, 0, 0.001, 0.001) AS geom
    FROM ax_flurstueck
    WHERE endet IS NULL
),
joined AS (
    SELECT 
        f.gml_id,
        f.gemeindezugehoerigkeit_land,
        f.gemarkungsnummer,
        f.flurnummer,
        f.geom
    FROM active_flurstuecke f
    INNER JOIN pp_gemarkungen g
      ON f.gemeindezugehoerigkeit_land = g.gemeindezugehoerigkeit_land
     AND f.gemarkungsnummer = g.gemarkungsnummer
),
aggregated AS (
    SELECT 
        gemeindezugehoerigkeit_land,
        gemarkungsnummer,
        flurnummer,
        MIN(gml_id) AS min_gml_id,
        st_multi(
          st_simplify(
            st_unaryunion(
              st_collect(st_makevalid(geom))
            ),
            0.5
          )
        ) AS geom_union
    FROM joined
    GROUP BY gemeindezugehoerigkeit_land, gemarkungsnummer, flurnummer
)
INSERT INTO po_polygons(
    gml_id,
    thema,
    layer,
    signaturnummer,
    sn_randlinie,
    modell,
    polygon
)
SELECT 
    min_gml_id,
    'Politische Grenzen'::text AS thema,
    ('ax_flurstueck_flur_' || gemeindezugehoerigkeit_land || gemarkungsnummer || flurnummer)::text AS layer,
    'pg-flur'::text AS signaturnummer,
    'pg-flur'::text AS sn_randlinie,
    '{norGIS}'::text[] AS modell,
    geom_union AS polygon
FROM aggregated;


INSERT INTO po_labels(gml_id,thema,layer,point,text,signaturnummer,drehwinkel,modell)
SELECT
    p.gml_id,
    'Politische Grenzen' AS thema,
    p.layer,
    ST_PointOnSurface(p.polygon) AS point,
    'Flur ' || substring(p.layer FROM 'ax_flurstueck_flur_[0-9]+$') AS text,
    'pg-flur' AS signaturnummer,
    0 AS drehwinkel,
    ARRAY['norGIS'] AS modell
FROM po_polygons p
JOIN pg_temp.pp_gemarkungen g
  ON substring(p.layer FROM 'ax_flurstueck_flur_[0-9]+') = g.gemeindezugehoerigkeit_land || g.gemarkungsnummer;

BEGIN;
DELETE FROM po_polygons WHERE sn_randlinie = 'pg-flur' AND gml_id LIKE 'DEBW%';
DELETE FROM po_labels WHERE signaturnummer = 'pg-flur' AND gml_id LIKE 'DEBW%';
COMMIT;
