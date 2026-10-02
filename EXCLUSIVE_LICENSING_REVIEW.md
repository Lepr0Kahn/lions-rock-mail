# Exclusive instrumental licensing review

Status: implementation specification; exclusive offers are not enabled.

Original routes_beats.py supports separate exclusive pricing, snapshots request kind/price, creates a 100% invoice, and marks the beat sold_exclusive/inactive upon paid Owner release. It does not revoke earlier beat grants. The merged app currently supports nonexclusive leases only.

Proposed behavior:
- Owner sets optional exclusive price and separate, explicit exclusive licence terms. Blank price keeps exclusive requests unavailable. Never reuse nonexclusive terms for an exclusive sale.
- Artist requests lease or exclusive; freeze kind, price, currency, title and terms for the request/invoice. Minor financial details remain guardian-only.
- Serialize decisions with an instrumental row lock before the request row lock. One approved exclusive reserves the instrumental against competing approvals/new requests; already approved leases must be resolved before exclusive approval. Do not silently void or refund invoices.
- Keep the shared INV allocator and existing 100% recorded settlement requirement. An approval, payment intent or cash request does not complete the exclusive sale.
- Owner explicitly releases after full recorded payment and any required guardian approval. Then remove the instrumental from future sales; retries remain idempotent and cannot release to a second exclusive buyer.
- Preserve previously released nonexclusive lease access under their original terms. Make that fact visible to the Owner and exclusive buyer; do not imply an unencumbered copyright transfer.
- No automatic legal terms, copyright ownership claim, refund/transfer, or retroactive termination of prior licences.

Owner policy approved 2026-10-01:
- Preserve existing nonexclusive licences under their original agreed terms and disclose them to the exclusive buyer.
- Download/access expiry is separate from licence expiry. Do not infer that prior licences expire or promise sole remaining rights without explicit licence end dates.
- Actual exclusive licence terms must still be supplied or approved per instrumental; price does not establish copyright or legal scope.

Verification to accompany implementation: competing exclusive approvals; ordinary lease versus exclusive reservation; existing approved/released leases; retry/release after payment; draft/void/unpaid rejection; guardian/minor flow; metadata edits versus snapshots; existing master access after catalogue removal; unchanged INV/QUO sequence. Final live security/device acceptance remains deferred.
