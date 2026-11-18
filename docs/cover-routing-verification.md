# Cover routing repair

## Confirmed root cause

The deployed `mint` handler defined Cover as `kind === "cover"` AND non-empty `audioBase64`. The web client had switched to `audioUrl` / `upload_url`. URL-only requests therefore reached `startGeneration` and spent a credit creating an unrelated song.

The actual adapter is **sunoapi.org / kie.ai**, not EvoLink. It calls `/api/v1/generate/upload-cover` with camelCase `uploadUrl`, `audioWeight`, `styleWeight` and `weirdnessConstraint`. The earlier snake_case additions in the client did not repair the routing decision.

## Deployed change

- Accept owned private `covers` Storage URLs, freshly signed by the backend.
- Reject missing, foreign, unreadable, unsupported or oversized references before credit spending.
- Route reference-bearing requests only to `startCover`.
- Keep legacy inline audio for iOS and check its upload result.
- Return `kind` and `referenceAccepted` to the client.
- Include `apikey` in allowed CORS request headers.
- Web refuses Cover while upload is pending/failed and checks server acknowledgement.
- Web no longer silently truncates to 45, 60, 120 or 240 seconds.
- Proxy is a transport only; provider mapping stays in Supabase.

## Verification

- 11 isolated backend tests passed, including full URL routing, missing reference, foreign URL, wrong owner, missing object, HEAD failure, invalid base64, iOS legacy upload, normal song and lyrics paths.
- Client regression tests passed: a complete 2,900,000-byte M4A is forwarded unchanged; failed upload has no shortened fallback; missing/pending/failed references cannot mint.
- Deployed live guard checks returned HTTP 400 `cover_audio_required` and `invalid_cover_reference`. The test account's credit balance was unchanged.
- Reopened deployed source and confirmed the URL route and missing-reference guard persisted.

No new paid audio generation was performed. Musical fidelity, exact lyrics and output duration have NOT been verified by this repair. A generation accepted as a cover is not proof of these qualities. The adapter still uses its existing V4_5 model and non-custom Cover configuration. Lyric overrides are not currently forwarded by that Cover adapter.

GitHub and the hosted preview are updated together. This does not automatically update Francis's Mac working copy.
