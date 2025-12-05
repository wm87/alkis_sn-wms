-- =====================================================================
-- Vorbereitende Performance-Indexe (idempotent)
-- =====================================================================
-- Array-Containment für ANY()/<@>
CREATE INDEX IF NOT EXISTS ap_pto_dientzurdarstellungvon_gin
    ON ap_pto USING gin (dientzurdarstellungvon);
CREATE INDEX IF NOT EXISTS ap_darstellung_dientzurdarstellungvon_gin
    ON ap_darstellung USING gin (dientzurdarstellungvon);

-- Filter-/Join-Indexe
CREATE INDEX IF NOT EXISTS ax_lmh_gml_id_btree
    ON ax_lagebezeichnungmithausnummer (gml_id);
CREATE INDEX IF NOT EXISTS ax_lmh_endet_btree
    ON ax_lagebezeichnungmithausnummer (endet);
CREATE INDEX IF NOT EXISTS ap_pto_endet_art_btree
    ON ap_pto (endet, art);
CREATE INDEX IF NOT EXISTS ap_darstellung_endet_art_btree
    ON ap_darstellung (endet, art);

-- =====================================================================
-- Lagebezeichnung mit Hausnummer (12002)
-- =====================================================================
SELECT 'Lagebezeichnungen mit Hausnummer werden verarbeitet.';

-- Mit Hausnummer, Ortsteil
SELECT 'Ortsteil verarbeitet.';

-- Ortsteil-Labels (Whitespace bereinigt, NULLs ausgeschaltet)
INSERT INTO po_labels (
    gml_id, thema, layer, point, text, signaturnummer,
    drehwinkel, horizontaleausrichtung, vertikaleausrichtung,
    skalierung, fontsperrung, modell
)
SELECT
    o.gml_id,
    'Gebäude' AS thema,
    'ax_lagebezeichnungmithausnummer' AS layer,
    t.wkb_geometry AS point,
    btrim(t.schriftinhalt) AS text,
    COALESCE(t.signaturnummer, '4160') AS signaturnummer,
    t.drehwinkel, t.horizontaleausrichtung, t.vertikaleausrichtung,
    t.skalierung, t.fontsperrung,
    COALESCE(t.advstandardmodell || t.sonstigesmodell,
             o.advstandardmodell || o.sonstigesmodell) AS modell
FROM ax_lagebezeichnungmithausnummer o
JOIN ap_pto t
  ON o.gml_id = ANY(t.dientzurdarstellungvon)
WHERE o.endet IS NULL
  AND t.endet IS NULL
  AND t.art = 'Ort'
  AND t.schriftinhalt IS NOT NULL
  AND btrim(t.schriftinhalt) <> '';

-- Gebäudehausnummern werden verarbeitet.
SELECT 'Gebäudehausnummern werden verarbeitet.';

-- Temporäre Tabelle für zeigtAuf (mit Index)
CREATE TEMP TABLE po_zeigtauf_hausnummer (
    zeigtauf CHAR(16) PRIMARY KEY,
    wkb_geometry GEOMETRY,
    prefix VARCHAR
) ON COMMIT PRESERVE ROWS;

-- Optional: schnellerer Insert ohne Unique-Checks -> danach Duplikate entfernen
-- Falls Duplikate erwartet werden, lasse PRIMARY KEY stehen und nutze ON CONFLICT.

-- Vereinheitlichte Inserts für Turm, Gebäude, Flurstück
WITH ins AS (
    SELECT unnest(z.zeigtauf) AS zeigtauf, z.wkb_geometry, '' AS prefix
    FROM ax_turm z
    JOIN ax_lagebezeichnungmithausnummer lmh ON lmh.gml_id = ANY(z.zeigtAuf)
    WHERE z.endet IS NULL AND lmh.endet IS NULL
    UNION ALL
    SELECT unnest(z.zeigtauf), z.wkb_geometry, '' 
    FROM ax_gebaeude z
    JOIN ax_lagebezeichnungmithausnummer lmh ON lmh.gml_id = ANY(z.zeigtAuf)
    WHERE z.endet IS NULL AND lmh.endet IS NULL
    UNION ALL
    SELECT unnest(z.zeigtauf), z.wkb_geometry, 'HsNr. '
    FROM ax_flurstueck z
    JOIN ax_lagebezeichnungmithausnummer lmh ON lmh.gml_id = ANY(z.zeigtAuf)
    WHERE z.endet IS NULL AND lmh.endet IS NULL
)
INSERT INTO po_zeigtauf_hausnummer (zeigtauf, wkb_geometry, prefix)
SELECT zeigtauf, wkb_geometry, prefix
FROM ins
ON CONFLICT DO NOTHING;

-- Temp-Index für schnellere Folgejoins
CREATE INDEX IF NOT EXISTS po_zeigtauf_hausnummer_zeigtauf_btree
    ON po_zeigtauf_hausnummer (zeigtauf);

-- Statistik aktualisieren
ANALYZE po_zeigtauf_hausnummer;
ANALYZE ax_lagebezeichnungmithausnummer;
ANALYZE ax_lagebezeichnungohnehausnummer;

-- Gebäudehausnummern mit Label
CREATE TABLE ap_pto_gml_tbl AS
SELECT ogc_fid AS pto_id,
       unnest(dientzurdarstellungvon) AS gml_id
FROM ap_pto
WHERE endet IS NULL
  AND art = 'HNR';

CREATE INDEX ap_pto_gml_tbl_gml_idx ON ap_pto_gml_tbl(gml_id);
CREATE INDEX ap_pto_gml_tbl_pto_idx ON ap_pto_gml_tbl(pto_id);


CREATE TABLE ap_darstellung_gml_tbl AS
SELECT ogc_fid AS darst_id,
       unnest(dientzurdarstellungvon) AS gml_id,
       signaturnummer
FROM ap_darstellung
WHERE endet IS NULL
  AND art = 'HNR';

CREATE INDEX ap_darstellung_gml_tbl_gml_idx ON ap_darstellung_gml_tbl(gml_id);
CREATE INDEX ap_darstellung_gml_tbl_darst_idx ON ap_darstellung_gml_tbl(darst_id);


INSERT INTO po_labels (
    gml_id, thema, layer, point, text, signaturnummer,
    drehwinkel, horizontaleausrichtung, vertikaleausrichtung,
    skalierung, fontsperrung, modell
)
SELECT
    o.gml_id,
    'Gebäude' AS thema,
    'ax_lagebezeichnungmithausnummer' AS layer,
    (alkis_pnr3002(
        o.gml_id,
        tx.wkb_geometry,
        tx.drehwinkel,
        o.land,
        o.regierungsbezirk,
        o.kreis,
        o.gemeinde,
        o.lage,
        gt.wkb_geometry
    )).p AS point,
    COALESCE(NULLIF(btrim(tx.schriftinhalt), ''),
    COALESCE(gt.prefix, '') || o.hausnummer) AS text,
    COALESCE(d.signaturnummer, tx.signaturnummer, '4070') AS signaturnummer,
    (alkis_pnr3002(
        o.gml_id,
        tx.wkb_geometry,
        tx.drehwinkel,
        o.land,
        o.regierungsbezirk,
        o.kreis,
        o.gemeinde,
        o.lage,
        gt.wkb_geometry
    )).a AS drehwinkel,
    tx.horizontaleausrichtung,
    tx.vertikaleausrichtung,
    tx.skalierung,
    tx.fontsperrung,
    COALESCE(tx.advstandardmodell || tx.sonstigesmodell,
             o.advstandardmodell || o.sonstigesmodell) AS modell
FROM ax_lagebezeichnungmithausnummer o
LEFT JOIN po_zeigtauf_hausnummer gt
  ON o.gml_id = gt.zeigtauf
LEFT JOIN ap_pto_gml_tbl g
  ON g.gml_id = o.gml_id
LEFT JOIN ap_pto tx
  ON tx.ogc_fid = g.pto_id
LEFT JOIN ap_darstellung_gml_tbl dg
  ON dg.gml_id = o.gml_id
LEFT JOIN ap_darstellung d
  ON d.ogc_fid = dg.darst_id
WHERE o.endet IS NULL
  AND (tx.schriftinhalt IS NOT NULL OR o.hausnummer IS NOT NULL)
  AND COALESCE(NULLIF(btrim(tx.schriftinhalt), ''), 
  COALESCE(gt.prefix, '') || o.hausnummer) IS NOT NULL;

-- Statistik aktualisieren
ANALYZE po_labels;
