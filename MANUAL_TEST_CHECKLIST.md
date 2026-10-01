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
- [ ] Financial reward benefits remain disabled.

## Remaining build-dependent checks
Online payment provider sandbox/production setup, guardian outbound notifications/dual receipts, automatic tagged previews, explain-only Direction Engine, admin MFA and original data reconciliation require their own checks as those features are implemented.
