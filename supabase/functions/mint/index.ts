// ============================================================
// POST /functions/v1/mint
// Body: { prompt, style(genre)?, mood?, tempo?, voice?, title?, instrumental?,
//         kind?, audioBase64?, audioUrl? }
// Auth: Supabase user JWT.
//
// - kind "song" (default): text -> song via sunoapi.org /generate.
// - covers: validate an owned private Storage URL, or accept legacy inline audio.
//   Always use sunoapi.org /generate/upload-cover. Missing audio is an error.
//
// Provider = sunoapi.org / kie.ai (supports Upload-and-Cover, which EvoLink
// does not). Swap providers by changing _shared/sunoapi.ts only.
// ============================================================
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { startGeneration, startCover, generateLyrics } from "../_shared/sunoapi.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const jwt = authHeader.replace("Bearer ", "");
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const { data: { user } } = await admin.auth.getUser(jwt);
    if (!user) return json({ error: "unauthenticated" }, 401);

    const b = await req.json().catch(() => ({}));
    const prompt = (b.prompt ?? "").toString();
    const genre  = (b.style ?? b.genre ?? "").toString();
    const mood   = (b.mood ?? "").toString();
    const tempo  = (b.tempo ?? "").toString();
    const voice  = (b.voice ?? "").toString();
    const instrumental = !!b.instrumental;
    const hasInlineAudio = typeof b.audioBase64 === "string" && b.audioBase64.length > 0;
    const sourceUrl = typeof b.audioUrl === "string" ? b.audioUrl.trim()
      : typeof b.upload_url === "string" ? b.upload_url.trim() : "";
    const isCover = b.kind === "cover" || hasInlineAudio || !!sourceUrl;
    let coverUrl = "";
    const weights = { audioWeight: Number(b.audioWeight), styleWeight: Number(b.styleWeight), weirdness: Number(b.weirdness) };

    const v = voice.toLowerCase();
    const vocalDesc = v.includes("female") ? "female vocals" : v.includes("male") ? "male vocals" : "";
    const base = prompt.trim().length > 0 ? prompt.trim() : `${mood} ${genre} song`.trim();
    const tags = [genre, mood, tempo ? `${tempo} tempo` : "", vocalDesc, instrumental ? "instrumental" : ""].filter(Boolean).join(", ");
    let fullPrompt = (tags ? `${base}. Style: ${tags}.` : base) || "An uplifting pop song";
    fullPrompt = fullPrompt.slice(0, 500);

    // Lyrics-only request (no credit, no job): write lyrics from the idea.
    if (b.action === "lyrics") {
      try {
        const ly = await generateLyrics(base || fullPrompt);
        return json({ lyrics: ly.text, title: ly.title });
      } catch (e) {
        return json({ error: "lyrics_error", detail: String(e) }, 502);
      }
    }

    const vg = v.includes("female") ? "f" : (v.includes("male") ? "m" : undefined);
    const lyrics = typeof b.lyrics === "string" ? b.lyrics.trim() : "";

    // Validate reference BEFORE charging. A Cover must never become text generation.
    if (isCover) {
      if (sourceUrl) {
        let u: URL;
        try { u = new URL(sourceUrl); }
        catch { return json({ error: "invalid_cover_reference" }, 400); }
        const origin = new URL(Deno.env.get("SUPABASE_URL")!).origin;
        const prefix = "/storage/v1/object/sign/covers/";
        if (u.origin !== origin || !u.pathname.startsWith(prefix)) {
          return json({ error: "invalid_cover_reference", detail: "Use your private covers upload." }, 400);
        }
        let objectPath: string;
        try { objectPath = decodeURIComponent(u.pathname.slice(prefix.length)); }
        catch { return json({ error: "invalid_cover_reference" }, 400); }
        const parts = objectPath.split("/");
        if (parts[0] !== user.id || parts.length !== 2 || !parts[1] || parts.includes("..") || objectPath.includes("\\")) {
          return json({ error: "cover_reference_not_owned" }, 403);
        }
        // Sign the owned object ourselves, rather than trusting a supplied URL/token.
        const { data: signed, error: signError } = await admin.storage.from("covers").createSignedUrl(objectPath, 86400);
        if (signError || !signed?.signedUrl) {
          return json({ error: "cover_reference_unavailable" }, 400);
        }
        const probe = await fetch(signed.signedUrl, { method: "HEAD", redirect: "error" });
        const bytes = Number(probe.headers.get("content-length"));
        if (!probe.ok || !Number.isFinite(bytes) || bytes <= 0) {
          return json({ error: "cover_reference_unavailable" }, 400);
        }
        if (bytes > 50 * 1024 * 1024) return json({ error: "cover_reference_too_large" }, 413);
        const mime = (probe.headers.get("content-type") || "").split(";")[0];
        if (!["audio/wav", "audio/x-wav", "audio/mpeg", "audio/mp4", "audio/x-m4a"].includes(mime)) {
          return json({ error: "unsupported_cover_audio", detail: "Upload MP3, M4A or WAV audio." }, 415);
        }
        coverUrl = signed.signedUrl;
      } else if (hasInlineAudio) {
        // Compatibility for the existing iOS client; never silently discard its bytes.
        let bytes: Uint8Array;
        try { bytes = Uint8Array.from(atob(b.audioBase64), (c) => c.charCodeAt(0)); }
        catch { return json({ error: "invalid_cover_audio" }, 400); }
        if (!bytes.length) return json({ error: "cover_audio_required" }, 400);
        if (bytes.length > 50 * 1024 * 1024) return json({ error: "cover_reference_too_large" }, 413);
        const isWav = new TextDecoder().decode(bytes.slice(0, 4)) === "RIFF";
        const path = `${user.id}/${crypto.randomUUID()}.${isWav ? "wav" : "m4a"}`;
        const { error: uploadError } = await admin.storage.from("inputs").upload(path, bytes, {
          contentType: isWav ? "audio/wav" : "audio/mp4", upsert: false,
        });
        if (uploadError) return json({ error: "cover_upload_failed" }, 502);
        const { data: pub } = admin.storage.from("inputs").getPublicUrl(path);
        coverUrl = pub.publicUrl;
      } else {
        return json({ error: "cover_audio_required", detail: "No reference audio received. No credits charged." }, 400);
      }
    }

    const cost = 1;
    const { data: spent } = await admin.rpc("spend_credits", { uid: user.id, amount: cost });
    if (!spent) return json({ error: "no_credits", paywall: true }, 402);

    let taskId: string;
    try {
      if (isCover) {
        taskId = await startCover(fullPrompt, coverUrl, instrumental, weights);
      } else {
        const custom = (lyrics || instrumental)
          ? { lyrics, style: (tags || genre || "pop"), title: (b.title ? String(b.title) : ""), vocalGender: vg }
          : undefined;
        taskId = await startGeneration(fullPrompt, instrumental, weights, custom);
      }
    } catch (e) {
      await admin.rpc("refund_credits", { uid: user.id, amount: cost });
      return json({ error: "provider_error", detail: String(e) }, 502);
    }

    const { data: job } = await admin.from("jobs").insert({
      user_id: user.id,
      provider: "sunoapi",
      provider_task_id: taskId,
      kind: isCover ? "cover" : "song",
      cost,
      status: "generating",
      progress: 0,
    }).select().single();

    return json({ jobId: job!.id, status: "generating", kind: isCover ? "cover" : "song", referenceAccepted: isCover }, 200);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
}
