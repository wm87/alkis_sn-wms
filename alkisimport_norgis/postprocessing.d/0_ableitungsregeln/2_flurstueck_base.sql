SELECT 'Flurstücke werden verarbeitet.';

-- Flurstücke
INSERT INTO po_polygons(gml_id,thema,layer,polygon,signaturnummer,modell)
SELECT
	gml_id,
	'Flurstücke' AS thema,
	'ax_flurstueck' AS layer,
	st_multi(wkb_geometry) AS polygon,
	2028 AS signaturnummer,
	advstandardmodell||sonstigesmodell
FROM ax_flurstueck
WHERE endet IS NULL;

UPDATE ax_flurstueck SET abweichenderrechtszustand='false' WHERE abweichenderrechtszustand IS NULL;

SELECT count(*) || ' Flurstücke mit abweichendem Rechtszustand.' FROM ax_flurstueck WHERE abweichenderrechtszustand='true';

-- Flurstücksgrenzen mit abweichendem Rechtszustand
SELECT 'Bestimme Grenzen mit abweichendem Rechtszustand';
INSERT INTO po_lines(gml_id,thema,layer,line,signaturnummer,modell)
SELECT
	a.gml_id,
	'Flurstücke' AS thema,
	'ax_flurstueck' AS layer,
	st_multi( (SELECT st_collect(geom) FROM st_dump( st_intersection(a.wkb_geometry,b.wkb_geometry) ) WHERE geometrytype(geom)='LINESTRING') ) AS line,
	2029 AS signaturnummer,
	a.advstandardmodell||a.sonstigesmodell||b.advstandardmodell||b.sonstigesmodell AS modell
FROM ax_flurstueck a, ax_flurstueck b
WHERE a.ogc_fid<b.ogc_fid
  AND a.abweichenderrechtszustand='true' AND b.abweichenderrechtszustand='true'
  AND a.wkb_geometry && b.wkb_geometry AND st_intersects(a.wkb_geometry,b.wkb_geometry)
  AND a.endet IS NULL AND b.endet IS NULL;


--                    ARZ
-- Schrägstrich: 4113 4122
-- Bruchstrich:  4115 4123

-- Flurstücksnummern
-- Schrägstrichdarstellung
SELECT 'Erzeuge Flurstücksnummern in Schrägstrichdarstellung...';

CREATE TABLE ap_pto_link AS
SELECT
    p.ogc_fid AS pto_id,
    unnest(p.dientzurdarstellungvon) AS gml_id
FROM ap_pto p;

CREATE INDEX ap_pto_link_gml_id_idx
    ON ap_pto_link(gml_id);


INSERT INTO po_labels(gml_id,thema,layer,point,text,signaturnummer,drehwinkel,horizontaleausrichtung,vertikaleausrichtung,skalierung,fontsperrung,modell)
SELECT
    o.gml_id,
    'Flurstücke' AS thema,
    'ax_flurstueck_nummer' AS layer,
    COALESCE(t.wkb_geometry, ST_Centroid(o.wkb_geometry)) AS point,
    COALESCE(REPLACE(t.schriftinhalt,'-','/'), o.zaehler||'/'||o.nenner, o.zaehler::text) AS text,
    COALESCE(d.signaturnummer, t.signaturnummer,
             CASE WHEN o.abweichenderrechtszustand='true'
                  THEN '4122' ELSE '4113' END) AS signaturnummer,
    t.drehwinkel, t.horizontaleausrichtung, t.vertikaleausrichtung,
    t.skalierung, t.fontsperrung,
    COALESCE(t.advstandardmodell||t.sonstigesmodell,
             o.advstandardmodell||o.sonstigesmodell) AS modell
FROM ax_flurstueck o
LEFT JOIN ap_pto_link l
       ON l.gml_id = o.gml_id
LEFT JOIN ap_pto t
       ON t.ogc_fid = l.pto_id
      AND t.art = 'ZAE_NEN'
      AND t.endet IS NULL
LEFT JOIN ap_darstellung d
       ON d.dientzurdarstellungvon @> ARRAY[o.gml_id]
      AND d.art='ZAE_NEN'
      AND d.endet IS NULL
WHERE o.endet IS NULL
  AND (
        COALESCE(t.signaturnummer,'4115') IN ('4113','4122')
        OR COALESCE(o.nenner,'0')='0'
      );
