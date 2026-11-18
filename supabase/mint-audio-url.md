# Full-length Cover: mint must fetch `audioUrl`

The web client now uploads the clip to Storage and sends:

```json
{ "kind": "cover", "audioUrl": "https://…/storage/v1/object/sign/covers/…", "prompt": "…" }
```

`/mint` currently expects `audioBase64` in the JSON body (max ~6MB). For full songs, in the mint Edge Function:

1. If `audioUrl` is set, `fetch(audioUrl)` with the user’s JWT / service role as needed.
2. Convert those bytes to whatever EvoLink already gets from `audioBase64`.
3. Do not require `audioBase64` when `audioUrl` is present.

Until that change is deployed, the web app falls back to a 45s WAV in `audioBase64` if the `covers` bucket is missing.
