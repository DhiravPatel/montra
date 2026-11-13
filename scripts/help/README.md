# Help guides (HELP-001)

`content.py` is the single source for the in-app help guides on web and
mobile, in English and Hindi. Facts in it come from `docs/FEATURES.md` and
the backend code; keep them in step when behaviour changes.

Regenerate after editing `content.py`:

```sh
python3 scripts/help/gen_web.py            # web/src/shared/help/guides.ts, features/support/guides/content.ts and the helpGuides/helpContent catalogs
python3 scripts/help/gen_mobile.py mobile  # ARB entries and lib/core/help + support/domain registries
(cd web && pnpm exec prettier --write src/shared/help src/shared/i18n/locales src/features/support/guides)
(cd mobile && flutter gen-l10n && dart format lib)
```

Then run the web and mobile test suites. `gen_mobile.py` rewrites the help
and saved-filter entries in the ARB files; keys and text are unchanged on a
re-run, but entries added by hand after the last run may move to a new
position in the file (order only).
