# Original OS data reconciliation

Reviewed 2026-10-01 Barbados. This is a source/schema comparison, not a completed historical data migration.

## Evidence and limits
Source repository: Lepr0Kahn/LIONS-ROCK-OS-FOR-SAGE, backend route modules and seed.py. Target: Lepr0Kahn/lions-rock-mail and current Supabase public schema. No MongoDB export was found among the source repository paths. seed.py explicitly seeds demo members/projects; it is not an authoritative historical export. Tracked backend/uploads files exist, but file names alone do not establish rightful account/project ownership or whether a file is production data.

Target read-only count snapshot: memberships 4; artist_projects 1; artist_project_files 1; studio_bookings 3; documents 4; payments 0; studio_instrumentals 0; studio_instrumental_requests 0. These counts do not prove source/target parity. No records, files, memberships or financial balances were changed by this review.

## Collection mapping
| Original collections | Target / disposition |
|---|---|
| users, memberships | Supabase Auth, app_memberships, artist_career_profiles. Explicit source-user → target-user map required; do not copy password/MFA hashes or infer matching from names. |
| projects, files | artist_projects, artist_project_files, private artist-project-files Storage. Preserve actual source dates/statuses, map owner/project IDs, transfer and hash bytes; source URL alone is insufficient. |
| services, service_variants | studio_services, studio_service_variants; invoice services already integrated. Preserve current Owner edits; exclude membership packages. |
| bookings | studio_bookings. Map offering/project/account, actual starts/ends and cancellation/confirmation states. Confirmed is not proof of attendance. |
| invoices, quotes | documents, document_items. Preserve historical source number as migration reference; use existing shared allocator for new documents. Reconcile line totals/currency/tax/paid amounts without duplicate issuance. |
| payments, refunds, receipts | payments ledger and record/email receipt flows. Require original provenance, amounts, dates and linkage. Unverified legacy balances remain opening entries; do not label them processor-confirmed. |
| payment_intents, paypal_webhook_events | Provider-backed checkout not activated. Preserve provider identifiers for later reconciliation; do not replay charges/refunds. |
| guardian_links, cash_requests | Private guardian workflow. Reissue recipient-bound approval links deliberately; do not migrate old bearer tokens. Cash intent is not settlement. |
| beats, beats_requests, beat_grants | studio_instrumentals, studio_instrumental_requests, private instrumental Storage. Match master/preview bytes, terms, prices and invoice linkage; no master release without validated settlement/approval. |
| beat_plays, beat_play_tokens | Historical analytics/ephemeral playback authorization: no equivalent imported dataset yet; do not migrate tokens. |
| milestones, xp_ledger, badge_awards | Career event/reversal ledger and recognition projections. Import authentic history as backfilled evidence; historical migration must not generate new reward XP. Reconcile historical awards separately. |
| reward_grants | Monetary benefit claim/fulfilment remains disabled pending Owner approval. Preserve historical obligations for review; do not silently grant or fulfil. |
| directions | Current rule-based guidance; historical AI directions require export and provenance. No AI provider connected. |
| notifications, outbox_jobs, audit_log | In-app notifications/activity records have partial equivalents. Historical delivery/audit evidence requires explicit archival mapping; never resend old outbox jobs automatically. |
| applications | Public applications intentionally closed; current access is private invite-only. Historical applications may be archived rather than activated. |
| config | Review each setting against approved merged-app behavior; source capacity/VAT/reward/payment settings are not automatically approved. |
| magic_links, login_attempts, mfa_challenges | Do not migrate active sessions, login links, challenges or MFA secrets. New Auth onboarding/recovery is separate. |

## Feature gaps discovered or confirmed
Source beat metadata includes mood, song_key and exclusive_price; target currently has genre/BPM and lease terms/pricing, with exclusive licensing still outstanding. Historical playback analytics, reward fulfilment/capacity, external email/outbox automation and provider-backed AI/payment features remain outstanding. Existing .txt receipt emails are current record handoffs, not immutable historical receipt snapshots or dual formal guardian/artist receipts.

## Import prerequisites and sequence
1. Obtain an authorized MongoDB export and original private file inventory when the old deployment/database is available. Keep credentials, password hashes, MFA secrets and bearer tokens out of chat and migration payloads.
2. Classify production versus fixtures/demo data and build explicit account mappings. Keep unresolved records in a review list.
3. Produce a dry-run inventory: counts, duplicate source IDs, missing references, currency totals, file hashes, and proposed target matches. No writes during dry run.
4. Import with a persistent source-ID mapping and idempotent batches; preserve existing target edits and financial numbering. Do not invoke normal creation triggers as if imported history were new activity.
5. Reconcile counts, references, financial totals per currency, date ranges, delivery expiry and bytes. Final security/live acceptance tests remain deferred by user instruction.

## Current status
Source/schema reconciliation completed. Historical row and byte reconciliation is blocked on an authoritative source export; repository demo seeds must not substitute for it. Continue independent feature build work while this prerequisite remains pending.
