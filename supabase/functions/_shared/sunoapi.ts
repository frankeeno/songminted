// ============================================================
// sunoapi.org / kie.ai adapter — the ONLY file that knows about the provider.
// Unlike EvoLink, this one supports Upload-and-Cover (hum -> cover), so it can
// be the single provider for both plain songs and covers.
//
// Docs: https://docs.sunoapi.org  ·  Base: https://api.sunoapi.org
// Secrets (Supabase ▸ Edge Functions ▸ Secrets):
//   SUNOAPI_KEY  (required), SUNOAPI_BASE_URL (optional), SUNOAPI_CALLBACK_URL (optional)
// ============================================================

const BASE     = Deno.env.get("SUNOAPI_BASE_URL") ?? "https://api.sunoapi.org";
const KEY      = Deno.env.get("SUNOAPI_KEY") ?? "";
const CALLBACK = Deno.env.get("SUNOAPI_CALLBACK_URL") ?? "https://songminted.com/api/suno-callback";
const MODEL    = "V4_5"; // up to 8-min uploads for covers; good genre blending

function headers() {
  return { "Authorization": `Bearer ${KEY}`, "Content-Type": "application/json" };
}

export interface Weights { audioWeight?: number; styleWeight?: number; weirdness?: number; }
const clamp = (n?: number) => (typeof n === "number" ? Math.max(0, Math.min(1, Math.round(n * 100) / 100)) : undefined);

// Generate lyrics only (no audio). Polls to completion and returns the text.
export async function generateLyrics(idea: string): Promise<{ text: string; title: string }> {
  const res = await fetch(`${BASE}/api/v1/lyrics`, {
    method: "POST", headers: headers(),
    body: JSON.stringify({ prompt: idea.slice(0, 200), callBackUrl: CALLBACK }),
  });
  const j = await res.json();
  const taskId = j?.data?.taskId;
  if (j.code !== 200 || !taskId) throw new Error(`lyrics ${j.code} ${j.msg ?? ""}`);
  for (let i = 0; i < 40; i++) {
    await new Promise((r) => setTimeout(r, 2000));
    const p = await fetch(`${BASE}/api/v1/lyrics/record-info?taskId=${encodeURIComponent(taskId)}`, { headers: headers() });
    const d = (await p.json())?.data ?? {};
    const st = String(d.status ?? "PENDING");
    if (st === "SUCCESS") {
      const arr = d.response?.data ?? [];
      const first = arr.find((x: any) => x?.text) ?? arr[0] ?? {};
      return { text: first.text ?? "", title: first.title ?? "" };
    }
    if (["CREATE_TASK_FAILED", "GENERATE_LYRICS_FAILED", "SENSITIVE_WORD_ERROR", "CALLBACK_EXCEPTION"].includes(st)) {
      throw new Error(`lyrics failed: ${st}`);
    }
  }
  throw new Error("lyrics timeout");
}

// Text -> song. Simple mode by default; pass custom.lyrics for exact lyrics.
export async function startGeneration(
  prompt: string, instrumental = false, w: Weights = {},
  custom?: { lyrics?: string; style?: string; title?: string; vocalGender?: string },
): Promise<string> {
  const useCustom = !!(custom && (custom.lyrics || instrumental));
  const body: Record<string, unknown> = { customMode: useCustom, instrumental, model: MODEL, callBackUrl: CALLBACK };
  if (useCustom) {
    body.style = (custom!.style || "pop").slice(0, 1000);
    body.title = (custom!.title || "Untitled").slice(0, 100);
    if (!instrumental) body.prompt = String(custom!.lyrics || prompt).slice(0, 5000);
    if (custom!.vocalGender === "m" || custom!.vocalGender === "f") body.vocalGender = custom!.vocalGender;
  } else {
    body.prompt = prompt.slice(0, 500);
  }
  if (clamp(w.styleWeight) !== undefined) body.styleWeight = clamp(w.styleWeight);
  if (clamp(w.weirdness) !== undefined) body.weirdnessConstraint = clamp(w.weirdness);
  const res = await fetch(`${BASE}/api/v1/generate`, { method: "POST", headers: headers(), body: JSON.stringify(body) });
  const j = await res.json();
  if (j.code !== 200 || !j.data?.taskId) {
    throw new Error(`sunoapi generate failed: ${j.code} ${j.msg ?? ""}`);
  }
  return j.data.taskId as string;
}

// Uploaded/hummed audio -> cover (keeps the melody, new style). uploadUrl must
// be a PUBLICLY downloadable URL. audioWeight (0-1) controls how faithfully the
// output follows YOUR melody — set high so the hum is clearly the basis.
// Returns provider taskId.
export async function startCover(prompt: string, uploadUrl: string, instrumental = false, w: Weights = {}): Promise<string> {
  const body: Record<string, unknown> = {
    customMode: false,
    instrumental,
    model: MODEL,
    prompt: prompt.slice(0, 500),
    uploadUrl,
    audioWeight: clamp(w.audioWeight) ?? 0.75,
    callBackUrl: CALLBACK,
  };
  if (clamp(w.styleWeight) !== undefined) body.styleWeight = clamp(w.styleWeight);
  if (clamp(w.weirdness) !== undefined) body.weirdnessConstraint = clamp(w.weirdness);
  const res = await fetch(`${BASE}/api/v1/generate/upload-cover`, { method: "POST", headers: headers(), body: JSON.stringify(body) });
  const j = await res.json();
  if (j.code !== 200 || !j.data?.taskId) {
    throw new Error(`sunoapi cover failed: ${j.code} ${j.msg ?? ""}`);
  }
  return j.data.taskId as string;
}

// Continue/lengthen an existing track. audioId is the provider track id we
// stored when the song was generated. defaultParamFlag=false continues using
// the original song's parameters (simplest); pass prompt+continueAt for custom.
export async function startExtend(
  audioId: string,
  opts: { prompt?: string; style?: string; title?: string; continueAt?: number } = {},
): Promise<string> {
  const custom = typeof opts.prompt === "string" && typeof opts.continueAt === "number";
  const body: Record<string, unknown> = { defaultParamFlag: custom, audioId, model: MODEL, callBackUrl: CALLBACK };
  if (custom) {
    body.prompt = String(opts.prompt).slice(0, 500);
    body.style = opts.style;
    body.title = opts.title;
    body.continueAt = opts.continueAt;
  }
  const res = await fetch(`${BASE}/api/v1/generate/extend`, { method: "POST", headers: headers(), body: JSON.stringify(body) });
  const j = await res.json();
  if (j.code !== 200 || !j.data?.taskId) throw new Error(`extend ${j.code} ${j.msg ?? ""}`);
  return j.data.taskId as string;
}

export interface Track { id?: string; audioUrl: string; imageUrl?: string; title?: string; }
export interface TaskStatus { status: "generating" | "completed" | "failed"; progress: number; tracks: Track[]; }

// Poll a task via record-info. Maps the provider's status strings to ours.
export async function getTask(taskId: string): Promise<TaskStatus> {
  const res = await fetch(`${BASE}/api/v1/generate/record-info?taskId=${encodeURIComponent(taskId)}`, {
    headers: headers(),
  });
  const body = await res.json();
  const d = body?.data ?? {};
  const s = String(d.status ?? "PENDING");

  const failed = ["CREATE_TASK_FAILED", "GENERATE_AUDIO_FAILED", "CALLBACK_EXCEPTION", "SENSITIVE_WORD_ERROR"];
  if (failed.includes(s)) return { status: "failed", progress: 0, tracks: [] };

  const suno = d.response?.sunoData;
  const tracks: Track[] = Array.isArray(suno)
    ? suno.filter((x: any) => x?.audioUrl).map((x: any) => ({ id: x.id, audioUrl: x.audioUrl, imageUrl: x.imageUrl, title: x.title }))
    : [];

  if (s === "SUCCESS" && tracks.length > 0) return { status: "completed", progress: 100, tracks };

  const progress = s === "FIRST_SUCCESS" ? 70 : s === "TEXT_SUCCESS" ? 40 : 15;
  return { status: "generating", progress, tracks: [] };
}

// Split a finished track into stems. `musicTaskId` + `audioId` identify the
// source track (the generation task and the chosen version). type:
//   "separate_vocal" -> vocals + instrumental (2 tracks)
//   "split_stem"     -> up to 12 tracks (drums, bass, guitar, keys…)
// Polls to completion; returns [{ name, url }]. Verify the endpoint/field names
// against https://docs.sunoapi.org (Vocal Removal / Stem Separation) if the
// provider changes them.
export async function separateStems(
  musicTaskId: string, audioId: string, type: "separate_vocal" | "split_stem",
): Promise<{ name: string; url: string }[]> {
  const res = await fetch(`${BASE}/api/v1/vocal-removal/generate`, {
    method: "POST", headers: headers(),
    body: JSON.stringify({ taskId: musicTaskId, audioId, type, callBackUrl: CALLBACK }),
  });
  const j = await res.json();
  const taskId = j?.data?.taskId;
  if (j.code !== 200 || !taskId) throw new Error(`stems ${j.code} ${j.msg ?? ""}`);

  for (let i = 0; i < 90; i++) {           // separation can take a couple of minutes
    await new Promise((r) => setTimeout(r, 3000));
    const p = await fetch(`${BASE}/api/v1/vocal-removal/record-info?taskId=${encodeURIComponent(taskId)}`, { headers: headers() });
    const d = (await p.json())?.data ?? {};
    const flag = String(d.successFlag ?? "PENDING");
    if (flag === "SUCCESS") {
      const resp = d.response ?? {};
      const out: { name: string; url: string }[] = [];
      const push = (name: string, url: unknown) => { if (typeof url === "string" && url) out.push({ name, url }); };
      // Preferred: the labelled array of stems (name + audio_url).
      if (Array.isArray(resp.originData)) {
        for (const s of resp.originData) push(String(s.stem_type_group_name ?? "Stem"), s.audio_url);
      }
      // Fallback: the individual *Url fields.
      if (out.length === 0) {
        push("Vocals", resp.vocalUrl);
        push("Instrumental", resp.instrumentalUrl);
        push("Backing Vocals", resp.backingVocalsUrl);
        push("Drums", resp.drumsUrl);
        push("Bass", resp.bassUrl);
        push("Guitar", resp.guitarUrl);
        push("Keyboard", resp.keyboardUrl);
        push("Percussion", resp.percussionUrl);
        push("Strings", resp.stringsUrl);
        push("Synth", resp.synthUrl);
        push("FX", resp.fxUrl);
        push("Brass", resp.brassUrl);
        push("Woodwinds", resp.woodwindsUrl);
      }
      return out;
    }
    if (["CREATE_TASK_FAILED", "GENERATE_AUDIO_FAILED", "CALLBACK_EXCEPTION"].includes(flag)) {
      throw new Error(`stems failed: ${flag} ${d.errorMessage ?? ""}`);
    }
  }
  throw new Error("stems timeout");
}
