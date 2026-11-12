-- Allow deleting categories that nothing references. Foreign keys from
-- transactions (NO ACTION) and subcategories (RESTRICT) still prevent
-- deleting any category with history; the service checks first and
-- suggests merge/archive.
set local search_path = montra, extensions, public;
grant delete on categories to montra_app;
