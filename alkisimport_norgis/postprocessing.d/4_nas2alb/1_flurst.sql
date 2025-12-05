SET search_path = :"alkis_schema", :"parent_schema", :"postgis_schema", public;

---
--- 1) Flurstücke prüfen
---
SELECT 'Prüfe Flurstücksgeometrien...';
SELECT alkis_fixareas('ax_flurstueck');

---
--- 2) FLURST leeren
---
TRUNCATE flurst;

---
--- 3) Lagebezeichnungen vorbereiten (performant, aggregiert)
---
DROP TABLE IF EXISTS temp_lagebez;
CREATE TEMP TABLE temp_lagebez AS
SELECT gml_id,
       array_to_string(array_agg(DISTINCT unverschluesselt), E'\n') AS lagebez
FROM ax_lagebezeichnungohnehausnummer
WHERE endet IS NULL
GROUP BY gml_id;

CREATE INDEX temp_lagebez_gml_idx ON temp_lagebez(gml_id);

---
--- 4) Flurstücke einfügen (1:1 wie Original)
---
INSERT INTO flurst(
    flsnr, flsnrk, gemashl, flr, entst, fortf, flsfl, amtlflsfl, gemflsfl,
    af, flurknr, baublock, flskoord, fora, fina, h1shl, h2shl, hinwshl,
    strshl, gemshl, hausnr, lagebez, k_anlverm, anl_verm, blbnr, n_flst,
    ff_entst, ff_stand, ff_datum
)
SELECT
    alkis_flsnr(a) AS flsnr,
    alkis_flsnrk(a) AS flsnrk,
    to_char(alkis_toint(a.land),'fm00') || to_char(alkis_toint(a.gemarkungsnummer),'fm0000') AS gemashl,
    to_char(coalesce(a.flurnummer,0),'fm000') AS flr,
    to_char(date_part('year', a.zeitpunktderentstehung), 'fm0000') || '/     -  ' AS entst,
    NULL AS fortf,
    a.amtlicheflaeche::int AS flsfl,
    a.amtlicheflaeche AS amtlflsfl,
    st_area(a.wkb_geometry) AS gemflsfl,
    '01' AS af,
    NULL AS flurknr,
    NULL AS baublock,
    alkis_flskoord(a) AS flskoord,
    NULL AS fora,
    NULL AS fina,
    NULL AS h1shl,
    NULL AS h2shl,
    NULL AS hinwshl,
    NULL AS strshl,
    to_char(alkis_toint(a.gemeindezugehoerigkeit_land),'fm00')||
    a.gemeindezugehoerigkeit_regierungsbezirk||
    to_char(alkis_toint(a.gemeindezugehoerigkeit_kreis),'fm00')||
    to_char(alkis_toint(a.gemeindezugehoerigkeit_gemeinde),'fm000') AS gemshl,
    NULL AS hausnr,
    (
      SELECT array_to_string(array_agg(DISTINCT lagebez), E'\n')
      FROM temp_lagebez l
      WHERE l.gml_id = ANY(a.zeigtauf)
    ) AS lagebez,
    NULL AS k_anlverm,
    NULL AS anl_verm,
    NULL AS blbnr,
    NULL AS n_flst,
    0 AS ff_entst,
    0 AS ff_stand,
    NULL AS ff_datum
FROM ax_flurstueck a
WHERE a.endet IS NULL
  AND NOT EXISTS (
      SELECT 1
      FROM ax_flurstueck b
      WHERE b.endet IS NULL
        AND alkis_flsnr(a) = alkis_flsnr(b)
        AND b.beginnt < a.beginnt
        AND a.ogc_fid <> b.ogc_fid
  );

---
--- 5) Baulastenblattnummern vorbereiten
---
SELECT 'Belege Baulastenblattnummer...';

SELECT alkis_dropobject('bblnr_temp');
CREATE TEMP TABLE bblnr_temp AS
SELECT
    alkis_flsnr(f) AS flsnr,
    b.bezeichnung
FROM ax_flurstueck f
JOIN ax_bauraumoderbodenordnungsrecht b
  ON b.endet IS NULL
  AND b.artderfestlegung = 2610
  AND f.wkb_geometry && b.wkb_geometry
  AND alkis_relate(f.wkb_geometry, b.wkb_geometry, '2********',
                   'ax_flurstueck:' || f.gml_id || '<=>ax_bauraumoderbodenordnungsrecht:' || b.gml_id)
WHERE f.endet IS NULL;

CREATE INDEX bblnr_temp_flsnr_idx ON bblnr_temp(flsnr);

UPDATE flurst
SET blbnr = sub.blbnr
FROM (
    SELECT flsnr,
           regexp_replace(array_to_string(array_agg(DISTINCT bezeichnung), ','), E'\(.{196}\).+', E'\\1 ...') AS blbnr
    FROM bblnr_temp
    GROUP BY flsnr
) AS sub
WHERE flurst.flsnr = sub.flsnr;
