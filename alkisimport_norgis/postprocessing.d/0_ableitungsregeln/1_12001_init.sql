-- für ap_pto.dientzurdarstellungvon (character(16)[])
CREATE INDEX IF NOT EXISTS ap_pto_dientzurdarstellungvon_gin
  ON public.ap_pto USING gin (dientzurdarstellungvon);

-- für ap_lto.dientzurdarstellungvon (falls ap_lto hat dieselbe Array-Spalte)
CREATE INDEX IF NOT EXISTS ap_lto_dientzurdarstellungvon_gin
  ON public.ap_lto USING gin (dientzurdarstellungvon);
