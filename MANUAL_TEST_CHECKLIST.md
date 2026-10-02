# Lions Rock OS manual test checklist

Updated 2026-10-01. Record Pass / Fail / Skipped, device, date, and a short note. Database/source passes in FUNCTIONAL_TESTS.md do not replace these live browser checks. Use designated test accounts and clearly labelled test records. Do not send real customer invoices or move money as a test.

## Access and navigation
- [ ] Owner signs in to the managerial dashboard; Artist lands on the member workspace; Business-only cannot enter Artist tools.
- [ ] New-user invite asks for password setup; existing-user invite preserves the existing account. Password reset returns to the live app.
- [ ] Sign out/in, wrong-workspace denial, suspension/reactivation, expiry and membership removal enforce access.
- [ ] Two Artists cannot see each other's projects, bookings, files, requests or notifications.
- [ ] Menus highlight red from dashboard and inside a project; Services highlights; Refresh visibly acknowledges the click. Check iPhone and Mac.

## Services, bookings and document numbers
- [ ] Imported services exclude membership packages. Full Mix starts at 120 minutes; instrumental creation at 180; other initial defaults at 60; saved management edits persist.
- [ ] Request a session; Owner confirms/cancels/reschedules it. Times display in Barbados time. Duration/time changes persist. Adjacent sessions work and overlapping sessions fail.
- [ ] Ordinary booking invoices use 50% deposit; vault leases require full payment before release.
- [ ] Create generator invoice, booking invoice, then another generator invoice. Numbers continue in order; reopening/retrying booking invoice reuses its number. Check quotes separately.
- [ ] From two authenticated sessions create genuinely simultaneous orders; each commits with a different correct number. This test remains unverified.

## Invoice generator and email
- [ ] Booking/vault/project handoffs carry the correct document, recipient, line items, currency and number.
- [ ] Generated PDFs match the saved invoice/quote; totals and deposits are correct.
- [ ] Mail remains accessible. A new handoff replaces prior attachments and resets CC/BCC appropriately.
- [ ] Authorize a test Gmail send to your own test address; verify received PDF/audio bytes.
- [ ] EML export includes expected PDF/audio. Apple Mail device compatibility is skipped at user request.

## Files and instrumental vault
- [ ] Upload actual reference audio, retrieve it, and compare bytes. Owner delivers master/MP3; Artist cannot deliver/reissue a master.
- [ ] Expired project delivery refuses new downloads; Owner reissue restores them.
- [ ] Vault draft cannot publish without both audio objects and licence terms. Published preview actually plays.
- [ ] Choose a clean master, set BPM, optionally select your own short audio tag and beats per bar (default 4). Generate/listen; tag occurs at the start and every eight bars. At 120 BPM/4 beats per bar, repeats at 16/32/48 seconds. At 60 BPM, every 32 seconds.
- [ ] Save with automatic generation: clean master remains unchanged; published preview is a separate WAV capped at 90 seconds. Compare downloaded master bytes with original. Change BPM/tag/master and regenerate; cancel or switch item/account mid-generation and confirm no stale preview publishes.
- [ ] Without a custom tag, hear the tone at eight-bar intervals. Unsupported codecs/silent or long tags fail with a clear message; prepared manual preview remains available. Test on Mac and iPhone, including generation from an existing saved master. Custom tag is not retained as a studio preset.
- [ ] Artist requests once; Owner approves; retry produces one shared-number invoice. Another Artist cannot access the request/master.
- [ ] Unpaid/part-paid lease refuses release; recorded full payment plus explicit release enables actual master download.
- [ ] Refund/payment correction/void removes financial download eligibility. Already downloaded copies cannot be recalled.
- [ ] Catalogue archive/restore and existing lease behavior are clear.

## Payment records and printing
- [ ] Partial cash/bank entries update recorded paid and outstanding; full entry settles the invoice. Retrying a submission adds one entry.
- [ ] Existing legacy paid amount is preserved once as an explicitly unverified opening balance.
- [ ] Refund/correction requires a reason and original entry; cannot exceed remaining recorded payment. Entries cannot be rewritten.
- [ ] Ledger invoice cannot overwrite paid balance or delete payment history; void works.
- [ ] Payment receipt/refund/correction record prints or saves as PDF correctly on Mac/iPhone. Popup blocking is handled.
- [ ] Confirm app records do not execute transfers, charges or refunds; online provider remains unconnected.

## Guardian/minor workflow
- [ ] Owner marks a designated test Artist as Minor and enters guardian name/email under Admin > Access List. Minor loses Business access; adult classification is not inferred from existing accounts.
- [ ] Minor sees service names/times and request status, with no prices, deposit figures, project budgets or lease price/financial terms. API bypass and permissions have database tests; check rendered screens.
- [ ] Minor creates a project, changes its status, uploads/downloads permitted files and requests a booking/lease.
- [ ] Owner issues the linked invoice, selects it in Payments, and creates a private guardian link. Deliver it only to the designated test guardian.
- [ ] Prepare guardian email from Payments: recipient is the saved guardian, private link and invoice number match, old PDF/audio/CC/BCC are cleared, and changing invoices while generating does not retain a stale draft. Review before sending to your designated test guardian.
- [ ] Guardian opens link without signing in, sees correct invoice totals/items/terms/time, and must enter name plus consent to approve.
- [ ] Unapproved invoice payment/lease release fails; approved invoice allows recorded payment and release.
- [ ] Cash request appears once in Owner notifications; does not mark paid. Guardian sees recorded payment/adjustment history and can print.
- [ ] Alter invoice amount, line items, deposit, terms or booked time; old approval is rejected. New link revokes old link. Expired/invalid tokens fail.
- [ ] Guardian contact changes, suspension/removal and reclassification invalidate active links. No guardian contact or approval token appears in the Artist API.
- [ ] Linked invoice/quote generator handoff defaults to guardian email, not the minor. Minor payment notifications remain figure-free and open the member destination.
- [ ] Guardian identity is asserted by the recipient of a private bearer link; independent identity verification, online checkout, operational email delivery and dual formal receipt issuance are not yet implemented.

## Notifications, analytics and recognition
- [ ] Booking, delivery, vault and recorded payment events reach intended recipients once. Clicking opens the correct view; unread/mark-all-read refresh and sign-out clearing work.
- [ ] Owner analytics 7/30/90-day windows and BBD/USD balances match fixtures; Artist cannot enter analytics.
- [ ] XP/levels/badges reflect new authoritative evidence. Repeated saves/delivery reissues do not inflate XP; archive/reversal/correction removes invalid credit.
- [ ] Direction guidance shows five evidence-cited actions and current stage rationale. Thin/missing records are stated; repeated refresh does not change authoritative scores/rewards. Buttons open the expected workspace only.
- [ ] Owner selects another Artist and guidance changes; denied/removed Artist does not leave old guidance visible. Minor business guidance refers to guardian; no monetary figures appear.
- [ ] Financial reward benefits remain disabled.

## Remaining build-dependent checks
Online payment provider sandbox/production setup, guardian outbound notifications/dual receipts, automatic tagged previews, explain-only Direction Engine, admin MFA and original data reconciliation require their own checks as those features are implemented.


## Optional admin authenticator setup
- Owner: Private Access → Admin Security. Enroll using an authenticator app, verify a six-digit code, then verify a fresh session.
- Check invalid/expired code retry and Cancel setup. Keep QR/setup key private; never send it in chat.
- Confirm sign-out and tab changes clear setup details. Non-Owners cannot open setup.
- Management-wide MFA enforcement and recovery remain pending; enrollment alone does not require MFA for all API/database access.
- Automated mock enrollment/verification/stale-view tests passed. Live Auth enrollment and phone QR scanning remain unverified.


## Receipt email handoff
- Owner Payments: Prepare receipt email for a recorded payment, refund and correction. Check distinct subject and record labels, invoice number, currency and amount.
- Confirm recipient equals the saved invoice recipient; linked minor invoices must use the guardian's saved email. Missing email requires correction before drafting.
- Confirm Mail clears prior attachments/CC/BCC and includes the readable .txt record. Review before manually sending.
- Opening balances must not offer a receipt. Check account changes prevent delayed drafts.
- Live Gmail send, iPhone attachment viewing and printed receipt remain pending.

- MFA recovery preparation: after verifying the primary authenticator, add and verify a backup on a separate device. Check both factors can verify a fresh session. Remove unfinished setups only. Enforcement stays off pending full backend and login-gate validation; see MFA_ENFORCEMENT_REVIEW.md.


## Final-phase security testing — user scheduling decision
On 2026-10-01 the user deferred all remaining security acceptance tests until the end of the build. Keep MFA enforcement off; do not block independent migration work on authenticator setup. Final-phase checks include primary/backup enrollment, fresh sign-in challenge, recovery, privileged RPC/table/storage denial, invite creation/claim, suspension/removal, workspace isolation and explicit enforcement activation only after acceptance.


## Vault mood and musical key
- Owner: add/edit an instrumental with mood and musical key; save, refresh and reopen. Confirm values remain and catalogue displays them.
- Blank metadata is allowed for existing items. Key is descriptive text, not automatic audio-key detection. Unicode sharps/flats should display correctly.
- Database rollback saved Reflective / F♯ minor successfully; current scripts parse and save/display wiring checks passed. Live UI checks remain in final phase.


## Exclusive instrumental flow
- Owner sets optional exclusive price and separate terms; blank price disables offering. Artist/guardian sees prior-lease disclosure.
- Request exclusive; approve twice and verify same invoice/number. Competing exclusive or lease approvals must be blocked during reservation; resolve already approved leases first.
- Unpaid/draft/void invoice must not release. Full recorded payment plus Owner release marks sold and removes future offers; repeat release is safe.
- Existing released licensees retain catalogue/master path subject to existing payment/guardian checks. No download expiry is treated as licence termination.
- Minor views show availability, never exclusive price/terms. Guardian reviews invoiced terms.
- Refund after release, concurrent browser requests, actual download bytes, refreshed UI and guardian flows remain final acceptance checks.


## Studio notice email drafts
- Owner: confirmed booking → Prepare confirmation email; master/MP3 delivery → Prepare delivery email; approved/released vault request → Prepare vault email.
- Verify current artist recipient for adults and recorded guardian for minors. Missing guardian must block drafting.
- Check Barbados session times, delivery access expiry, vault status and exclusive prior-lease disclosure. No public download tokens or audio attachments.
- Existing Mail resets prior draft attachments/CC/BCC; review before manually sending. Live forwarding/UI/Gmail checks remain final phase.
- Automated notice module checks passed adult/guardian recipients, no attachment, missing guardian, cancelled booking and invalid kind. All modified page scripts parse.
