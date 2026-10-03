# Lions Rock OS manual test checklist

Updated 2026-10-03. Record Pass / Fail / Skipped, device, date, and a short note. Database/source passes in FUNCTIONAL_TESTS.md do not replace these live browser checks. Use designated test accounts and clearly labelled test records. Do not send real customer invoices or move money as a test.

## Access and navigation
- [x] Owner signs in to the managerial dashboard; Artist-only and Business-only access boundaries verified live at the backend, with final Owner MFA sign-in accepted.
- [ ] New-user invite asks for password setup; existing-user invite preserves the existing account. Password reset returns to the live app.
- [ ] Sign out/in, wrong-workspace denial, suspension/reactivation, expiry and membership removal enforce access.
- [ ] Two Artists cannot see each other's projects, bookings, files, requests or notifications.
- [ ] Menus highlight red from dashboard and inside a project; Services highlights; Refresh visibly acknowledges the click. Check iPhone and Mac.

## Services, bookings and document numbers
- [ ] Imported services exclude membership packages. Full Mix starts at 120 minutes; instrumental creation at 180; other initial defaults at 60; saved management edits persist.
- [ ] Request a session; Owner confirms/cancels/reschedules it. Times display in Barbados time. Duration/time changes persist. Adjacent sessions work and overlapping sessions fail.
- [ ] Ordinary booking invoices use 50% deposit; vault leases require full payment before release.
- [x] Create generator invoice, booking invoice, then another generator invoice. Numbers continue in order; reopening/retrying booking invoice reuses its number. Quotes tested separately. Shared sequence and idempotency passed.
- [x] Numbering concurrency protections reviewed and accepted: per-account transaction advisory lock plus unique document/reservation/booking-invoice constraints; live database contains zero duplicates and Owner counter matches INV-0006. A browser race remains optional device acceptance, not a correctness blocker.

## Invoice generator and email
- [ ] Booking/vault/project handoffs carry the correct document, recipient, line items, currency and number.
- [ ] Generated PDFs match the saved invoice/quote; totals and deposits are correct.
- [ ] Mail remains accessible. A new handoff replaces prior attachments and resets CC/BCC appropriately.
- [x] Live Gmail send to Owner test address succeeded. PDF/audio-byte attachment presentation remains part of final device walkthrough where applicable.
- [ ] EML export includes expected PDF/audio. Apple Mail device compatibility is skipped at user request.

## Files and instrumental vault
- [x] Actual 5.2 MB MP3 delivery/download path accepted with private storage metadata and collection checks; Owner-only delivery/reissue permissions verified.
- [x] Expired project delivery refuses visibility/download; Owner reissue restores a fresh 30-day window. Rollback/live disposable acceptance passed.
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
- [x] Manual payment records do not execute transfers, charges or refunds. PayPal sandbox checkout/capture is connected separately and was accepted; released Vault licences block refund/correction.

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
PayPal sandbox provider setup is complete. Guardian outbound presentation/dual-receipt choices and final Owner MFA enrollment/enforcement still require interactive acceptance. Tagged previews and the rule-based Direction Engine are implemented and need live/device checks. Historical import/export is excluded by user instruction.


## Optional admin authenticator setup
- [x] Owner: Admin Security primary + backup authenticators enrolled; six-digit verification and a fresh MFA-gated sign-in succeeded.
- [ ] Invalid/expired code retry and Cancel setup remain optional negative-path checks. Keep QR/setup key private; never send it in chat.
- [x] Fresh sign-out/sign-in challenge accepted; non-Owner access remains blocked by role checks. Tab/setup-detail clearing remains a UI polish check.
- Owner MFA enrollment UI is complete. Backend enforcement requires two verified TOTP authenticators plus an aal2 session; enforcement remains OFF until the Owner explicitly enables it.
- Automated mock enrollment/verification/stale-view tests passed. Live Auth enrollment and phone QR scanning remain unverified.


## Receipt email handoff
- Owner Payments: Prepare receipt email for a recorded payment, refund and correction. Check distinct subject and record labels, invoice number, currency and amount.
- Confirm recipient equals the saved invoice recipient; linked minor invoices must use the guardian's saved email. Missing email requires correction before drafting.
- Confirm Mail clears prior attachments/CC/BCC and includes the readable .txt record. Review before manually sending.
- Opening balances must not offer a receipt. Check account changes prevent delayed drafts.
- Live Gmail send, iPhone attachment viewing and printed receipt remain pending.

- MFA recovery preparation: after verifying the primary authenticator, add and verify a backup on a separate device. Check both factors can verify a fresh session. Backend/login-gate validation is complete; the Admin Security screen exposes enforcement only after two verified factors and an aal2 session. Enforcement remains OFF pending the Owner's interactive enrollment.


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


## Artist development reward benefits
- Owner Rewards: add/edit a custom reward, set scope, XP milestone and capacity, activate/archive. Draft defaults stay inactive until configured.
- Artist: eligible claim, insufficient XP and sold-out state; repeat request reuses claim. Confirm one successful claim per reward.
- Owner queue: approve, decline with reason, record delivered experience with notes; repeat fulfilment is safe. Confirm paid menu prices and invoices unchanged.
- Verify snapshots remain after catalogue edits; corrected XP or suspended Artist blocks approval/fulfilment. Confirm capacity cannot drop below reserved/fulfilled claims.
- Final phase: concurrent last-place requests, account isolation, Owner MFA, phone layout and live Auth updates.
- No old-data export/import required; user explicitly excluded historical migration.


## Reward scheduling and notices
- Owner: approve then schedule/reschedule with future Barbados date/time, duration and location. Verify Artist/guardian views see the latest details.
- Cancel requested/approved claim with reason; verify capacity is returned and Artist can submit a fresh claim. Fulfilled claims cannot cancel.
- Prepare approval/scheduled/fulfilled/declined/cancelled reward email; verify current artist or guardian address, no old attachments, manual review/send.
- Check missing recipient blocks draft. Confirm scheduling creates no paid-menu booking/invoice and manually check calendar availability.
- Live phone input, frame forwarding, email sending and security acceptance remain final phase.



## Cal.com synchronization — added 2 October 2026
Synchronization is activated. Actual server-role access, live account/events/webhook diagnostics, OS-originated booking creation, external Cal.com reschedule replacement-UID reconciliation, acceptance and external cancellation all passed live.
- [x] Owner: Admin → Calendar Connection activation, hidden OS events and signed webhook registration verified.
- [x] OS request/confirmation architecture verified; provider booking occurs on confirmed workflow.
- [x] Owner-created mapped OS session produced one linked Cal.com booking with matching Barbados time and synchronized state.
- [ ] Original public paid links and prices still work; hidden OS events collect no payment.
- [x] External time change followed Cal.com replacement UID and reconciled the same OS booking without duplication; deposit semantics preserved.
- [ ] Change duration at another available time: hidden duration event, original calendar booking cancelled, replacement verified. Verify same-time expansion checks other conflicts while excluding its own verified reservation.
- [x] External Cal.com cancellation reconciled to the same Lions Rock booking; no duplicate booking or replacement invoice was created.
- [x] Cal.com reschedule updates the matching linked OS booking through replacement UID reconciliation. Conflict/out-of-hours review guards remain implemented.
- [ ] Provider failure/timeout: waiting, uncertain, or review state; no blind second creation. Owner can use Recheck calendar after checking/confirming the existing provider booking.
- [ ] Replay a signed webhook: no duplicate notifications or booking changes; invalid signature rejected.
- [ ] Guardian contact receives minor's calendar communication; artist financial details remain hidden.
- [ ] Pausing preserves availability checks and queues new changes; activation resumes scheduled work.
- [ ] Unmapped offerings fail visibly; no fallback to a paid public event. Six services currently mapped.
- [ ] Concurrent requests cannot claim the same OS slot; ticket expires in 60 seconds and cannot be reused.
- [ ] Existing bookings/data are not backfilled; invoice/quote numbering stays shared across generator and OS orders.
- [ ] Final security/MFA/session/suspension/isolation acceptance remains in the final test pass.

Independent database booking/invoice lifecycle and shared numbering passed on 2 October 2026. Live external Cal.com reschedule/cancel acceptance passed on 3 October 2026. Remaining calendar items above are only the narrower failure/recovery/device/security edge checks not already marked complete. Deferred Owner steps are saved in BUILD_NEXT_STEPS.md.
