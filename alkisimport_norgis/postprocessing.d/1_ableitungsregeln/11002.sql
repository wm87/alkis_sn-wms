-- ===========================
-- Optimiertes und fehlerfreies Skript für besondere Flurstücksgrenzen
-- inkl. Statusausgabe pro ADF
-- ===========================

SET client_encoding TO 'UTF8';
SET search_path = :"alkis_schema", :"parent_schema", :"postgis_schema", public;

-- ---------------------------
-- 1️⃣ Strittige Flurstücksgrenzen
-- ---------------------------
INSERT INTO po_lines(gml_id,thema,layer,line,signaturnummer,modell)
SELECT
    o.gml_id,
    'Flurstücke' AS thema,
    'ax_besondereflurstuecksgrenze' AS layer,
    st_multi(o.wkb_geometry) AS line,
    CASE
        WHEN a.abweichenderrechtszustand='true' AND b.abweichenderrechtszustand='true' THEN 2007
        ELSE 2006
    END AS signaturnummer,
    COALESCE(
        array_cat(COALESCE(o.advstandardmodell,'{}'), COALESCE(o.sonstigesmodell,'{}')),
        array_cat(
            array_cat(COALESCE(a.advstandardmodell,'{}'), COALESCE(a.sonstigesmodell,'{}')),
            array_cat(COALESCE(b.advstandardmodell,'{}'), COALESCE(b.sonstigesmodell,'{}'))
        )
    ) AS modell
FROM ax_besondereflurstuecksgrenze o
JOIN ax_flurstueck a
  ON o.wkb_geometry && a.wkb_geometry
 AND st_intersects(o.wkb_geometry,a.wkb_geometry)
 AND a.endet IS NULL
JOIN ax_flurstueck b
  ON o.wkb_geometry && b.wkb_geometry
 AND st_intersects(o.wkb_geometry,b.wkb_geometry)
 AND b.endet IS NULL
WHERE ARRAY[1000] <@ o.artderflurstuecksgrenze
  AND a.ogc_fid < b.ogc_fid
  AND o.endet IS NULL;

-- ---------------------------
-- 2️⃣ Nicht festgestellte Flurstücksgrenzen
-- ---------------------------
INSERT INTO po_lines(gml_id,thema,layer,line,signaturnummer,modell)
SELECT
    o.gml_id,
    'Flurstücke',
    'ax_besondereflurstuecksgrenze',
    st_multi(o.wkb_geometry),
    CASE
        WHEN a.abweichenderrechtszustand='true' AND b.abweichenderrechtszustand='true' THEN 2009
        ELSE 2008
    END,
    COALESCE(
        array_cat(COALESCE(o.advstandardmodell,'{}'), COALESCE(o.sonstigesmodell,'{}')),
        array_cat(
            array_cat(COALESCE(a.advstandardmodell,'{}'), COALESCE(a.sonstigesmodell,'{}')),
            array_cat(COALESCE(b.advstandardmodell,'{}'), COALESCE(b.sonstigesmodell,'{}'))
        )
    ) AS modell
FROM ax_besondereflurstuecksgrenze o
JOIN ax_flurstueck a
  ON o.wkb_geometry && a.wkb_geometry
 AND st_intersects(o.wkb_geometry,a.wkb_geometry)
 AND a.endet IS NULL
JOIN ax_flurstueck b
  ON o.wkb_geometry && b.wkb_geometry
 AND st_intersects(o.wkb_geometry,b.wkb_geometry)
 AND b.endet IS NULL
WHERE ARRAY[2001,2003,2004] && o.artderflurstuecksgrenze
  AND a.ogc_fid < b.ogc_fid
  AND o.endet IS NULL;

-- ---------------------------
-- 3️⃣ Temporäre Tabelle für ADF-Regeln (politische Grenzen)
-- ---------------------------
CREATE TEMP TABLE alkis_politischegrenzen(i INTEGER, sn VARCHAR, adfs INTEGER[]);
INSERT INTO alkis_politischegrenzen(i,sn,adfs) VALUES
(1, '2016', ARRAY[7101]),
(2, '2018', ARRAY[7102]),
(3, '2020', ARRAY[7103]),
(4, '2026', ARRAY[7108]),
(5, '2010', ARRAY[2500,7104]),
(6, '2022', ARRAY[7106]),
(7, '2024', ARRAY[7107]),
(8, '2014', ARRAY[7003]),
(9, '2012', ARRAY[3000]);

-- ---------------------------
-- 4️⃣ Temporäre Tabelle für optimierte Geometrie & Modell mit LATERAL
-- ---------------------------
CREATE TEMP TABLE po_besondereflurstuecksgrenze AS
SELECT
    MIN(p.ogc_fid) AS ogc_fid,
    MIN(p.gml_id) AS gml_id,
    array_agg(DISTINCT m) AS modell,
    array_agg(DISTINCT a) AS artderflurstuecksgrenze,
    p.wkb_geometry
FROM ax_besondereflurstuecksgrenze p
LEFT JOIN LATERAL unnest(array_cat(COALESCE(p.advstandardmodell,'{}'), COALESCE(p.sonstigesmodell,'{}'))) AS m ON TRUE
LEFT JOIN LATERAL unnest(COALESCE(p.artderflurstuecksgrenze, '{}')) AS a ON TRUE
WHERE p.endet IS NULL
  AND (st_numpoints(p.wkb_geometry) > 3 OR NOT st_equals(st_startpoint(p.wkb_geometry), st_endpoint(p.wkb_geometry)))
GROUP BY p.wkb_geometry, st_asbinary(p.wkb_geometry);

CREATE INDEX po_besondereflurstuecksgrenze_geom_idx ON po_besondereflurstuecksgrenze USING gist (wkb_geometry);
CREATE INDEX po_besondereflurstuecksgrenze_adfg ON po_besondereflurstuecksgrenze USING gin (artderflurstuecksgrenze);
ANALYZE po_besondereflurstuecksgrenze;

-- ---------------------------
-- 5️⃣ Funktion zum Entfernen wiederholter Punkte
-- ---------------------------
CREATE OR REPLACE FUNCTION pg_temp.removerepeatedpoints(geom geometry) RETURNS geometry AS $$
DECLARE
    p_array geometry[];
BEGIN
    SELECT array_agg(p) INTO p_array
    FROM (
        SELECT (g).geom AS p,
               lag((g).geom) OVER (ORDER BY (g).path) AS pp
        FROM st_dumppoints(geom) AS g
    ) AS t
    WHERE pp IS NULL OR NOT st_equals(pp, p);

    RETURN st_makeline(p_array);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ---------------------------
-- 6️⃣ Statusausgabe pro ADF (ersetzt RAISE NOTICE)
-- ---------------------------
WITH counts AS (
    SELECT
        adf.sn,
        adf.adfs,
        COUNT(*) AS n
    FROM po_besondereflurstuecksgrenze p
    JOIN alkis_politischegrenzen adf
      ON adf.adfs && COALESCE(p.artderflurstuecksgrenze,'{}')
    GROUP BY adf.sn, adf.adfs
)
SELECT 'adfs:{' || array_to_string(adfs, ',') || '} sn:' || sn || ' n:' || n AS notice
FROM counts;

-- ---------------------------
-- 7️⃣ Politische Grenzen set-basiert verschmelzen
-- ---------------------------
INSERT INTO po_lines(gml_id,thema,layer,line,signaturnummer,modell)
SELECT
    p.gml_id,
    'Politische Grenzen',
    'ax_besondereflurstuecksgrenze',
    st_multi(
      pg_temp.removerepeatedpoints(
        CASE
          WHEN GeometryType(st_union(p.wkb_geometry)) IN ('LINESTRING','MULTILINESTRING') THEN
            st_union(p.wkb_geometry)
          ELSE
            st_collectionextract(st_union(p.wkb_geometry), 2)
        END
      )
    ),
    adf.sn,
    p.modell
FROM po_besondereflurstuecksgrenze p
JOIN alkis_politischegrenzen adf
  ON adf.adfs && COALESCE(p.artderflurstuecksgrenze,'{}')
GROUP BY p.gml_id, adf.sn, p.modell;



/*
adfs:{7106} sn:2022 n:246520
adfs:{7101} sn:2016 n:21116
adfs:{7003} sn:2014 n:645160
adfs:{7102} sn:2018 n:47272
adfs:{2500,7104} sn:2010 n:77653
*/