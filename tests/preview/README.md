# Isolated sample preview

Run from the repository root:

```sh
node tests/preview/build-preview.cjs . /tmp/lions-rock-preview
python -m http.server 8765 --bind 127.0.0.1 --directory /tmp/lions-rock-preview
```

Open http://127.0.0.1:8765/studio.html. This copies current app HTML into a separate directory, replaces Supabase with sample responses, and supplies a sample BBD 350 Full Mix invoice with a 50% deposit. PDF libraries remain unchanged. Database mutations return an error. CSP blocks outgoing API calls; Google sign-in is removed and send controls are disabled. No production source or live data is modified.

This is a visual fixture, not authentication, payment, persistence, or delivery verification. Do not deploy the generated directory as the live app. Career RPCs and catalogue details are intentionally unavailable in this limited fixture.
