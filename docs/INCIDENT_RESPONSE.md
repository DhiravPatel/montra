# Montra — Incident Response

How the owner's team responds to security, privacy and availability
incidents (spec §12, §13). Technical procedures are in
[RUNBOOKS.md](RUNBOOKS.md). Vulnerability reports go to `SECURITY_EMAIL`
(see [SECURITY.md](SECURITY.md)).

## Severity

| Level | Examples | Response |
|---|---|---|
| SEV-1 | confirmed exposure of personal or financial data; account takeover at scale; data corruption affecting balances; full outage | page immediately; incident lead within 15 min; status page update within 30 min |
| SEV-2 | partial outage (imports, notifications, AI); a single-account compromise; a vulnerability with a plausible exploit | respond within 1 h |
| SEV-3 | degraded performance; a low-risk vulnerability; failed scheduled jobs with automatic recovery | next business day |

## Roles

- **Incident lead:** owns decisions and the timeline.
- **Technical responder:** follows the runbooks and makes the fix.
- **Communications:** status page (`STATUS_PAGE_URL`), user and
  regulator notices.
- **Legal and privacy reviewer** (privacy incidents): notification duties,
  for example the DPDP Act 2023 in India, and GDPR if EU users are
  served.

One person may hold several roles; the lead role is always explicit.

## Process

1. **Detect.** Alerts on health and metrics, user reports, vulnerability
   reports, or anomalies in security events.
2. **Triage.** Assign a severity and an incident lead, and open an
   incident record with a timeline in UTC.
3. **Contain.**
   - Disable the affected feature or provider: unset its credentials, or
     set `AI_PROVIDER=disabled`.
   - Revoke the affected sessions.
   - Rotate exposed secrets (DEPLOYMENT.md §7).
   - Block abusive traffic at the edge.
4. **Preserve evidence.**
   - Keep the logs: they contain request IDs and no personal values.
   - Keep audit and security events, which are append-only.
   - Record the deployment version and the configuration changes made.
5. **Eradicate and recover.**
   - Fix the cause with a regression test (RLS, API or unit).
   - Deploy, then verify through health checks and the targeted tests.
   - Restore data only through the procedures in RUNBOOKS.md.
6. **Notify** where required. For privacy incidents, decide with the
   legal reviewer within the statutory windows.
7. **Review** within 5 business days, blameless. Record the root cause,
   what worked and the follow-ups with owners. Update THREAT_MODEL.md and
   this document if needed.

## User communication

Use plain language. Say what happened, what data was involved and what
users should do (for example sign out everywhere, change password, review
devices). Never ask users for passwords, OTPs or card details in incident
messages.
