const CFG = {
  supabaseURL: "https://ucnruxztueysdohgamdy.supabase.co",
  supabaseAnonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVjbnJ1eHp0dWV5c2RvaGdhbWR5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM2OTE2NzcsImV4cCI6MjA5OTI2NzY3N30.-fJF0jiS4avyWvXE6VLKZCpVECjultBteNAIxXogCfM",
};

const moods = [["⚡","Energetic"],["😊","Happy"],["💖","Romantic"],["🔥","Aggressive"],["😢","Sad"],["🌟","Uplifting"],["❄️","Chill"],["🧘","Relaxing"],["😔","Melancholic"],["😄","Fun"],["🛸","Futuristic"],["🌙","Dreamy"]];
const genres = [["🎵","Pop"],["🎧","Hip-Hop"],["🎸","Rock"],["🎹","Lo-Fi"],["⚙️","EDM"],["🎤","R&B"],["🤠","Country"],["🦋","Indie"],["🎷","Jazz"],["🥁","Afrobeat"],["🎻","Folk"],["💒","Gospel"]];
const voices = [["🎲","Random"],["👨","Male"],["👩","Female"],["🌟","Nova"],["🔥","Blaze"],["🌊","Echo"],["🏜️","Ryder"],["🌙","Luna"],["⬛","Onyx"]];
const tempos = ["Slow","Medium","Fast","Very Fast"];
const ideas = ["A summer road-trip anthem with friends","Late-night city lights and neon dreams","A heartfelt song for mom's birthday","Chasing sunsets on a golden beach","A breakup ballad about coming back stronger","An epic gym motivation track"];
const titleA = ["Golden","Midnight","Neon","Velvet","Electric","Minted"];
const titleB = ["Hour","Dreams","Heartbeat","Horizon","Echoes","Sunrise"];
const feedSeed = [
  {title:"Neon Overdrive",genre:"EDM",author:"@synthlord",plays:"128K",likes:"9.2K",img:"https://images.unsplash.com/photo-1516280440614-37939bbacd81?w=600&q=80",audioURL:"https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3"},
  {title:"Sunday in Lisbon",genre:"Lo-Fi",author:"@mellowbeats",plays:"87K",likes:"6.4K",img:"https://images.unsplash.com/photo-1501281668745-f7f57925c3b4?w=600&q=80",audioURL:"https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3"},
  {title:"Concrete Kings",genre:"Hip-Hop",author:"@b4rs",plays:"204K",likes:"15K",img:"https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=600&q=80",audioURL:"https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3"},
  {title:"Paper Hearts",genre:"Pop",author:"@ava.m",plays:"62K",likes:"4.1K",img:"https://images.unsplash.com/photo-1470229722913-7c0e2dbbafd3?w=600&q=80",audioURL:"https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3"},
];

const S = {
  screen: localStorage.getItem("sm_onboarded") ? "app" : "onboard",
  ob: 0, tab: "studio", mode: "Simple", plan: 1,
  prompt: "", title: "", lyrics: "", writing: false, instrumental: false,
  genre: "", mood: "", voice: "", tempo: "",
  audioWeight: 0.7, styleWeight: 0.6, weirdness: 0.3,
  audioB64: null, audioUrl: null, photoURL: null,
  coins: 3, isPro: localStorage.getItem("is_pro") === "true",
  userId: localStorage.getItem("sb_user_id"),
  accessToken: localStorage.getItem("sb_access_token"),
  refreshToken: localStorage.getItem("sb_refresh_token"),
  library: JSON.parse(localStorage.getItem("library_v1") || "null") || [
    {id:"s1",title:"You Smiled First",meta:"Pop · Happy",badge:"Sample Song",img:"https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=400&q=80"},
    {id:"s2",title:"Chloe in the Morning Light",meta:"Indie · Romantic",badge:"Sample Song",img:"https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=400&q=80"},
  ],
  feed: JSON.parse(localStorage.getItem("feed_v1") || "null") || feedSeed,
  current: null, showPlayer: false, generating: false, progress: 0, genLbl: "",
  sheet: null, tmpPick: {}, settings: false, extendOpen: false, extendPrompt: "",
  stemsOpen: false, stems: [], stemsStatus: "",
  lyricsOpen: false, vibePrompt: "", takeGroup: null,
};

function saveLib(){ localStorage.setItem("library_v1", JSON.stringify(S.library)); }
function saveFeed(){ localStorage.setItem("feed_v1", JSON.stringify(S.feed)); }
function uid(){ return crypto.randomUUID ? crypto.randomUUID() : String(Date.now()); }
function sleep(ms){ return new Promise(r=>setTimeout(r,ms)); }
function esc(s){ return String(s||"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c])); }

function toast(msg){
  const t=document.getElementById("toast"); if(!t) return;
  t.textContent=msg; t.classList.add("show");
  clearTimeout(toast._t); toast._t=setTimeout(()=>t.classList.remove("show"),2000);
}

async function api(path,{method="GET",body,query,rawB64,contentType,upsert}={}){
  const payload={path,method,body,query,token:S.accessToken,rawB64,contentType,upsert};
  try{
    const res=await fetch("/gumloop/action/sb",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify(payload)});
    if(res.status!==404){
      const wrap=await res.json().catch(()=>({}));
      if(wrap && typeof wrap.status==="number") return wrap;
      return {ok:res.ok,status:res.status,obj:wrap};
    }
  }catch(e){ /* preview without proxy — fall through */ }
  let url=CFG.supabaseURL+path;
  if(query) url+=(url.includes("?")?"&":"?")+new URLSearchParams(query);
  const headers={apikey:CFG.supabaseAnonKey,Authorization:"Bearer "+(S.accessToken||CFG.supabaseAnonKey),"Content-Type":contentType||"application/json"};
  if(upsert) headers["x-upsert"]="true";
  let res;
  try{
    const bin=rawB64?Uint8Array.from(atob(rawB64),c=>c.charCodeAt(0)):undefined;
    res=await fetch(url,{method,headers,body:bin||(body?JSON.stringify(body):undefined),mode:"cors"});
  }catch(e){
    throw new Error("Can't reach Supabase ("+(e.message||"blocked")+"). Open this page from the latest preview link.");
  }
  const text=await res.text();
  let obj={}; try{ obj=text?JSON.parse(text):{}; }catch{ obj={error:text||res.statusText}; }
  return {ok:res.ok,status:res.status,obj};
}
function storeAuth(obj){
  S.accessToken=obj.access_token;
  if(obj.refresh_token) S.refreshToken=obj.refresh_token;
  if(obj.user&&obj.user.id) S.userId=obj.user.id;
  localStorage.setItem("sb_access_token",S.accessToken||"");
  localStorage.setItem("sb_refresh_token",S.refreshToken||"");
  localStorage.setItem("sb_user_id",S.userId||"");
}
async function signInAnon(){
  if(S.accessToken) return;
  if(S.refreshToken){
    const r=await api("/auth/v1/token?grant_type=refresh_token",{method:"POST",body:{refresh_token:S.refreshToken}});
    if(r.status===200&&r.obj.access_token){ storeAuth(r.obj); return; }
  }
  const r=await api("/auth/v1/signup",{method:"POST",body:{data:{},gotrue_meta_security:{}}});
  if(r.obj.access_token) storeAuth(r.obj);
}
async function refreshCredits(){
  if(!S.accessToken) return;
  const r=await api("/rest/v1/profiles",{query:{select:"credits,is_pro"}});
  const row=Array.isArray(r.obj)?r.obj[0]:null;
  if(row){
    if(typeof row.credits==="number") S.coins=row.credits;
    if(typeof row.is_pro==="boolean"){ S.isPro=row.is_pro; localStorage.setItem("is_pro",String(row.is_pro)); }
  }
}
function normalizeSongs(obj){
  const out=[];
  if(Array.isArray(obj.versions)) obj.versions.forEach(v=>{ if(v.audioUrl) out.push({title:v.title,audioURL:v.audioUrl,imageURL:v.imageUrl,audioId:v.audioId}); });
  else if(obj.audioUrl) out.push({title:obj.title,audioURL:obj.audioUrl,imageURL:obj.imageUrl,audioId:obj.audioId});
  return out;
}

async function pollJob(jobId){
  const deadline=Date.now()+300000;
  while(Date.now()<deadline){
    await sleep(2500);
    const p=await api("/functions/v1/job-status",{query:{jobId}});
    if(p.obj.error&&!p.obj.status) throw new Error(p.obj.error);
    S.progress=Math.max(S.progress, Number(p.obj.progress||0), Math.min(93,S.progress+1));
    render();
    if(p.obj.status==="completed") return normalizeSongs(p.obj);
    if(p.obj.status==="failed") throw new Error("Generation failed");
  }
  throw new Error("timeout");
}

function navBtn(id,label){
  return `<button class="${S.tab===id?"on":""}" onclick="S.tab='${id}';render()">${esc(label)}</button>`;
}

function header(){
  return `<header class="topbar">
    <div class="logo"><div class="gem"><span>◆</span></div>Song<b>Minted</b></div>
    <div class="top-actions">
      <span class="pill">● ${S.coins} ${tr("credits")}</span>
      <button class="pill pro" onclick="S.screen='paywall';render()">PRO</button>
      <select class="locale" onchange="setLangOverride(this.value)">
        <option value="auto">🌐 Auto</option>
        ${SUPPORTED.map(c=>`<option value="${c}" ${localStorage.getItem("language_override")===c?"selected":""}>${c.toUpperCase()}</option>`).join("")}
      </select>
      <button class="ghost" onclick="S.settings=!S.settings;render()">${tr("settings")}</button>
    </div>
  </header>`;
}

function studio(){
  const ph = S.mode==="Custom"?tr("prompt_ph_custom"):S.mode==="Photo"?tr("prompt_ph_photo"):tr("prompt_ph_simple");
  return `<h1 class="h-title">${tr("tab_studio")}</h1>
    <div class="seg">
      ${["Simple","Custom","Photo"].map((m,i)=>`<button class="${S.mode===m?"on":""}" onclick="S.mode='${m}';render()">${tr(["mode_simple","mode_custom","mode_photo"][i])}</button>`).join("")}
    </div>
    <div class="inputbox" style="position:relative">
      <textarea placeholder="${esc(ph)}" oninput="S.prompt=this.value">${esc(S.prompt)}</textarea>
      <button class="btn gold" style="position:absolute;right:12px;bottom:12px;padding:10px 14px" onclick="S.prompt=ideas[Math.floor(Math.random()*ideas.length)];render();toast('🎲')">🎲</button>
    </div>
    <input type="text" class="card" style="margin:12px 0" placeholder="${esc(tr("your_song"))}" value="${esc(S.title)}" oninput="S.title=this.value">
    ${S.mode==="Photo"?`<label class="upload">${S.photoURL?"✓ "+tr("change_photo"):tr("choose_photo")}
      <input type="file" accept="image/*" class="hidden" onchange="onPhoto(this)"></label>`:""}
    ${!S.instrumental?`<div class="card" style="margin:12px 0">
      <div style="display:flex;justify-content:space-between"><b>${tr("lyrics_caps")}</b>
        <button class="ghost" onclick="writeLyrics()">${S.writing?tr("writing"):"✨ "+tr("write_for_me")}</button></div>
      <textarea placeholder="${esc(tr("lyrics_ph"))}" oninput="S.lyrics=this.value">${esc(S.lyrics)}</textarea>
    </div>`:""}
    <label class="upload" style="margin:12px 0;display:block">${(S.audioB64||S.audioUrl)?tr("clip_ready"):tr("upload_audio")}
      <input type="file" accept="audio/*,video/mp4,video/quicktime,.mp4,.m4a,.wav,.mp3" class="hidden" onchange="onAudio(this)"></label>
    <div style="display:flex;justify-content:space-between;align-items:center;margin:12px 0">
      <span>${tr("instrumental")}</span>
      <input type="checkbox" ${S.instrumental?"checked":""} onchange="S.instrumental=this.checked;render()">
    </div>
    <div class="optgrid">
      <div class="opt ${S.voice?"set":""}" onclick="S.sheet='voice';render()"><div>🎤</div><div class="nm">${tr("lbl_voice")}</div><div class="val">${esc(S.voice)}</div></div>
      <div class="opt ${S.genre?"set":""}" onclick="S.sheet='genre';render()"><div>🎵</div><div class="nm">${tr("lbl_genre")}</div><div class="val">${esc(S.genre)}</div></div>
      <div class="opt ${S.mood?"set":""}" onclick="S.sheet='mood';render()"><div>🎭</div><div class="nm">${tr("lbl_mood")}</div><div class="val">${esc(S.mood)}</div></div>
      <div class="opt ${S.tempo?"set":""}" onclick="cycleTempo()"><div>⏱</div><div class="nm">${tr("lbl_tempo")}</div><div class="val">${esc(S.tempo)}</div></div>
    </div>
    <div class="fine card" style="margin:16px 0">
      <div class="row"><span>${tr("faithful_audio")}</span><b>${Math.round(S.audioWeight*100)}%</b></div>
      <input type="range" min="0" max="1" step="0.01" value="${S.audioWeight}" oninput="S.audioWeight=+this.value;render()">
      <div class="row"><span>${tr("faithful_style")}</span><b>${Math.round(S.styleWeight*100)}%</b></div>
      <input type="range" min="0" max="1" step="0.01" value="${S.styleWeight}" oninput="S.styleWeight=+this.value;render()">
      <div class="row"><span>${tr("weirdness")}</span><b>${Math.round(S.weirdness*100)}%</b></div>
      <input type="range" min="0" max="1" step="0.01" value="${S.weirdness}" oninput="S.weirdness=+this.value;render()">
    </div>
    <button class="btn" style="width:100%" onclick="mint()">${S.audioB64?"◆ "+tr("tab_cover"):"◆ "+tr("mint_song")} · 1 ●</button>`;
}

function cover(){
  return `<h1 class="h-title">${tr("tab_cover")}</h1>
    <p class="muted">${esc(tr("ob3_sub"))}</p>
    <div class="inputbox" style="margin:12px 0"><input type="text" placeholder="${esc(tr("prompt_ph_simple").split("\\n")[0])}" value="${esc(S.prompt)}" oninput="S.prompt=this.value"></div>
    <label class="upload">${(S.audioB64||S.audioUrl)?tr("clip_ready"):tr("upload_audio")}
      <input type="file" accept="audio/*,video/mp4,video/quicktime,.mp4,.m4a,.wav,.mp3" class="hidden" onchange="onAudio(this)"></label>
    <div class="optgrid" style="margin:16px 0">
      ${voices.map(([e,n])=>`<div class="opt ${S.voice===n?"set":""}" onclick="S.voice='${n}';render()">${e}<div class="val">${n}</div></div>`).join("")}
    </div>
    <button class="btn gold" style="width:100%;margin-top:12px" onclick="mint()">◆ ${tr("tab_cover")}</button>`;
}

function tools(){
  const packs=[
    ["🎹",tr("instrumental"),()=>{S.genre="Lo-Fi";S.mood="Chill";S.prompt="A smooth instrumental beat";S.instrumental=true;S.tab="studio";render();}],
    ["👥","Duet",()=>{S.genre="Pop";S.mood="Romantic";S.prompt="A male and female duet love song";S.tab="studio";render();}],
    ["🎁","Birthday",()=>{S.genre="Pop";S.mood="Fun";S.prompt="An upbeat happy-birthday anthem";S.tab="studio";render();}],
    ["❤","Wedding",()=>{S.genre="Pop";S.mood="Romantic";S.prompt="A heartfelt wedding ballad";S.tab="studio";render();}],
    ["🔄","Genre Swap",()=>{S.genre="EDM";S.mood="Energetic";S.prompt=S.prompt||"Reimagine my idea in a brand-new genre";S.tab="studio";render();}],
    ["⏱","Tempo Shift",()=>{S.genre="Hip-Hop";S.mood="Chill";S.prompt=S.prompt||"Same vibe, different tempo";S.tab="studio";render();}],
  ];
  window._tpl=packs;
  return `<h1 class="h-title">${tr("tab_tools")}</h1>
    <div class="tpl-grid">${packs.map((p,i)=>`<button class="tpl" onclick="_tpl[${i}][2]()">${p[0]}<div>${p[1]}</div></button>`).join("")}</div>`;
}

function explore(){
  return `<h1 class="h-title">${tr("explore_title")}</h1>
    <div class="feedgrid">${S.feed.map((f,i)=>`<div class="feedcard" style="background-image:url('${f.img||""}')" onclick="playFeed(${i})">
      <div class="fov"></div><div class="fbody"><div><b>${esc(f.title)}</b><div style="opacity:.8;font-size:12px">${esc(f.genre)} · ${esc(f.author)}</div></div><span>▶</span></div>
    </div>`).join("")}</div>`;
}

function vault(){
  return `<h1 class="h-title">${tr("vault_title")}</h1>
    <div class="songrow" onclick="S.tab='studio';render()"><div class="th" style="display:flex;align-items:center;justify-content:center;font-size:28px">＋</div><b>${tr("mint_a_song")}</b></div>
    ${S.library.map((s,i)=>`<div class="songrow" onclick="playLib(${i})">
      <div class="th" style="${s.img||s.imageURL?`background-image:url('${s.img||s.imageURL}')`:""}"></div>
      <div><div style="font-weight:800">${esc(s.title)}</div><div style="color:var(--muted)">${esc(s.meta||"")}</div><span class="pill">${esc(s.badge||"")}</span></div>
    </div>`).join("")}`;
}

function appShell(){
  const pages={studio,cover,tools,explore,vault};
  return `${header()}
    <div class="shell">
      <nav class="nav">
        ${navBtn("studio",tr("tab_studio"))}${navBtn("cover",tr("tab_cover"))}${navBtn("tools",tr("tab_tools"))}${navBtn("explore",tr("tab_explore"))}${navBtn("vault",tr("tab_vault"))}
      </nav>
      <main class="main">${pages[S.tab]()}</main>
    </div>
    <nav class="mobnav">
      ${["studio","cover","tools","explore","vault"].map(id=>`<button class="${S.tab===id?"on":""}" onclick="S.tab='${id}';render()">${tr("tab_"+id)}</button>`).join("")}
    </nav>`;
}

function onboard(){
  const slides=[
    [tr("ob1_pre"),tr("ob1_hl"),tr("ob1_sub"),"https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=1400&q=80"],
    [tr("ob2_pre"),tr("ob2_hl"),tr("ob2_sub"),"https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=1400&q=80"],
    [tr("ob3_pre"),tr("ob3_hl"),tr("ob3_sub"),"https://images.unsplash.com/photo-1478737270239-2f02b77fc618?w=1400&q=80"],
    [tr("ob4_pre"),tr("ob4_hl"),tr("ob4_sub"),"https://images.unsplash.com/photo-1459749411175-04bf5292ceea?w=1400&q=80"],
  ];
  const s=slides[S.ob];
  return `<div class="ob" style="min-height:100dvh">
    <div class="ob-hero" style="background-image:url('${s[3]}')"></div><div class="ob-fade"></div>
    <div class="ob-inner">
      <h1>${esc(s[0])} <em>${esc(s[1])}</em></h1>
      <p style="color:#bcc7ce;font-size:18px">${esc(s[2])}</p>
      <div style="display:flex;gap:8px;margin:18px 0">${slides.map((_,i)=>`<i style="width:${i===S.ob?11:9}px;height:${i===S.ob?11:9}px;border-radius:50%;background:${i===S.ob?"#34d399":"#3a4650"};display:block"></i>`).join("")}</div>
      <button class="btn" onclick="obNext()">${S.ob<3?tr("continue"):tr("get_started")} →</button>
    </div>
  </div>`;
}

function paywall(){
  const plans=[["Weekly","€5.99"],["Yearly","€49.99"],["Lifetime","€79.99"]];
  return `<div class="pw">
    <button class="ghost" onclick="S.screen='app';render()">✕</button>
    <h1 style="font-size:36px;font-weight:800">${tr("pro_title")}</h1>
    <p style="color:var(--muted)">${tr("pro_sub")}</p>
    <div class="plans" style="margin:20px 0">${plans.map((p,i)=>`<div class="plan ${S.plan===i?"sel":""}" onclick="S.plan=${i};render()"><b>${p[0]}</b><div>${p[1]}</div></div>`).join("")}</div>
    <button class="btn gold" style="width:100%" onclick="S.isPro=true;localStorage.setItem('is_pro','true');S.screen='app';toast(tr('pro_title'));render()">${tr("continue")}</button>
    <p style="color:var(--muted);font-size:12px;margin-top:10px">Stripe is not wired. This unlocks Pro on this browser only.</p>
  </div>`;
}

function sheets(){
  if(!S.sheet) return "";
  const list=S.sheet==="genre"?genres:S.sheet==="mood"?moods:voices;
  return `<div class="sheet-wrap open"><div class="sheet-bg" onclick="S.sheet=null;render()"></div>
    <div class="sheet"><h3>${tr("pick_"+S.sheet)}</h3>
      <div class="emojigrid">${list.map(([e,n])=>`<div class="emojicell ${ (S.sheet==="voice"?S.voice:S.sheet==="genre"?S.genre:S.mood)===n?"sel":""}" onclick="pickOpt('${n}')"><div class="circ">${e}</div>${n}</div>`).join("")}</div>
    </div></div>`;
}

function siblingTakes(){
  if(!S.current||!S.current.jobId) return [];
  return S.library.filter(x=>x.jobId===S.current.jobId);
}
function playerFull(){
  const s=S.current; if(!S.showPlayer||!s) return "";
  const takes=siblingTakes();
  return `<div class="player-full">
    <div style="width:100%;display:flex;justify-content:space-between"><button class="ghost" onclick="S.showPlayer=false;render()">‹</button></div>
    <div class="pl-art" style="${s.img||s.imageURL?`background-image:url('${s.img||s.imageURL}')`:"background:var(--grad)"}"></div>
    <h2 style="font-size:28px;font-weight:800">${esc(s.title)}</h2>
    <p style="color:var(--muted)">${esc(s.meta||"")}</p>
    ${takes.length>1?`<div class="takes">${takes.map((tk,i)=>`<button class="${tk.id===s.id?"on":""}" onclick="pickTake('${tk.id}')">${takes.length===2?(i?"Take B":"Take A"):"Take "+(i+1)}</button>`).join("")}</div>`:""}
    <div class="pl-bar" onclick="seek(event)"><div class="fill" id="plFill" style="width:0"></div></div>
    <div style="display:flex;gap:28px;align-items:center;margin:22px 0">
      <button class="ghost" onclick="skip(-15)">-15</button>
      <button class="btn" style="width:72px;height:72px;border-radius:50%;padding:0" onclick="togglePlay()">▶</button>
      <button class="ghost" onclick="skip(15)">+15</button>
    </div>
    <div class="actions">
      <div class="a" onclick="downloadSong()">${tr("download")}</div>
      <div class="a" onclick="publishSong()">${tr("publish")}</div>
      <div class="a" onclick="S.extendOpen=true;render()">${tr("extend")}</div>
      <div class="a" onclick="S.stemsOpen=true;render()">${tr("stems")}</div>
      <div class="a" onclick="startVideo()">${tr("music_video")}</div>
      <div class="a" onclick="S.lyricsOpen=!S.lyricsOpen;render()">Lyrics</div>
      <div class="a" onclick="shareSong()">Share</div>
    </div>
    ${S.lyricsOpen&&s.lyrics?`<pre class="lyrics">${esc(s.lyrics)}</pre>`:S.lyricsOpen?`<p class="muted">No lyrics on this take.</p>`:""}
    <div class="card" style="width:min(480px,92vw);margin-top:16px">
      <b>Vibe iterate</b>
      <p class="muted">Like Mozart chat: describe the change, we mint a new take (1 credit).</p>
      <textarea oninput="S.vibePrompt=this.value" placeholder="Make the chorus bigger, more 808s, keep the melody">${esc(S.vibePrompt)}</textarea>
      <button class="btn ghost" style="width:100%;margin-top:10px" onclick="vibeIterate()">Iterate · 1 ◆</button>
    </div>
    ${S.extendOpen?`<div class="card" style="width:min(480px,92vw);margin-top:16px">
      <b>${tr("extend_song")}</b><p>${tr("extend_sub")} Continues from the playhead, like Udio Extend.</p>
      <textarea oninput="S.extendPrompt=this.value" placeholder="${esc(tr("where_next_ph"))}">${esc(S.extendPrompt)}</textarea>
      <button class="btn" style="width:100%;margin-top:10px" onclick="extendSong()">${tr("extend")}</button>
    </div>`:""}
    ${S.stemsOpen?`<div class="card" style="width:min(480px,92vw);margin-top:16px">
      <b>${tr("stems")}</b><p>${tr("stems_sub")}</p>
      <button class="btn ghost" style="width:100%;margin:6px 0" onclick="runStems('separate_vocal')">${tr("stems_2")}</button>
      <button class="btn ghost" style="width:100%" onclick="runStems('split_stem')">${tr("stems_full")}</button>
      <p>${esc(S.stemsStatus)}</p>
      <div class="stemlist">${S.stems.map(x=>`<a href="${x.url}" download>${esc(x.name)}</a>`).join("")}</div>
    </div>`:""}
  </div>`;
}

function genOverlay(){
  if(!S.generating) return "";
  return `<div class="gen"><div class="mint-coin">◆</div>
    <div class="eq">${Array.from({length:11}).map((_,i)=>`<i style="animation-delay:${i*0.09}s"></i>`).join("")}</div>
    <div style="font-size:48px;font-weight:800">${Math.round(S.progress)}%</div>
    <div style="color:#bcc7ce">${esc(S.genLbl||"Minting…")}</div></div>`;
}

function settings(){
  if(!S.settings) return "";
  return `<div class="overlay" onclick="if(event.target===this){S.settings=false;render()}">
    <div class="panel" style="max-width:420px;margin:auto;border-radius:24px;padding:24px">
      <h2>${tr("settings")}</h2>
      <p style="color:var(--muted);font-size:12px">${tr("credits")}: ${S.coins}<br>ID<br><code style="color:var(--emerald);word-break:break-all">${S.userId||"—"}</code></p>
      <button class="ghost" style="width:100%;margin:8px 0" onclick="S.screen='paywall';S.settings=false;render()">${tr("go_pro")}</button>
      <button class="ghost" style="width:100%" onclick="resetAccount()">${tr("clear")} account</button>
    </div>
  </div>`;
}

function render(){
  const root=document.getElementById("root");
  let html="";
  if(S.screen==="onboard") html=onboard();
  else if(S.screen==="paywall") html=paywall();
  else html=appShell();
  root.innerHTML=html+sheets()+playerFull()+genOverlay()+settings();
}

window.obNext=()=>{ if(S.ob<3){S.ob++;render();} else { localStorage.setItem("sm_onboarded","1"); S.screen="paywall"; render(); } };
window.cycleTempo=()=>{ const i=tempos.indexOf(S.tempo); S.tempo=tempos[(i+1)%tempos.length]; render(); };
window.pickOpt=(n)=>{ if(S.sheet==="genre") S.genre=n; else if(S.sheet==="mood") S.mood=n; else S.voice=n; S.sheet=null; render(); };
window.playLib=(i)=>{ S.current=S.library[i]; S.showPlayer=true; playAudio(S.current); render(); };
window.playFeed=(i)=>{ const f=S.feed[i]; S.current={title:f.title,meta:f.genre+" · "+f.author,badge:"◆ Community",img:f.img,audioURL:f.audioURL}; S.showPlayer=true; playAudio(S.current); render(); };

function playAudio(song){
  const a=document.getElementById("audioEl");
  if(!a||!song||!song.audioURL) return;
  if(a.src!==song.audioURL) a.src=song.audioURL;
  a.play().catch(()=>{});
}
window.togglePlay=()=>{ const a=document.getElementById("audioEl"); if(!a) return; if(a.paused) a.play(); else a.pause(); };
window.skip=(s)=>{ const a=document.getElementById("audioEl"); if(a) a.currentTime=Math.max(0,a.currentTime+s); };
window.seek=(e)=>{ const a=document.getElementById("audioEl"); const b=e.currentTarget.getBoundingClientRect(); if(a&&a.duration) a.currentTime=((e.clientX-b.left)/b.width)*a.duration; };

function encodeWavMono(buffer, maxSec=45, sampleRate=16000){
  const src=buffer.numberOfChannels>1?(()=>{const L=buffer.getChannelData(0),R=buffer.getChannelData(1),m=new Float32Array(L.length); for(let i=0;i<L.length;i++) m[i]=(L[i]+R[i])/2; return m;})():buffer.getChannelData(0);
  const take=Math.min(src.length, Math.floor(buffer.sampleRate*maxSec));
  const outLen=Math.floor(take*sampleRate/buffer.sampleRate);
  const pcm=new Int16Array(outLen);
  for(let i=0;i<outLen;i++){
    const x=src[Math.min(take-1, Math.floor(i*buffer.sampleRate/sampleRate))];
    const s=Math.max(-1,Math.min(1,x));
    pcm[i]=s<0?s*0x8000:s*0x7fff;
  }
  const bytes=pcm.byteLength;
  const wav=new ArrayBuffer(44+bytes);
  const v=new DataView(wav);
  const w=(o,s)=>{ for(let i=0;i<s.length;i++) v.setUint8(o+i,s.charCodeAt(i)); };
  w(0,"RIFF"); v.setUint32(4,36+bytes,true); w(8,"WAVE"); w(12,"fmt "); v.setUint32(16,16,true);
  v.setUint16(20,1,true); v.setUint16(22,1,true); v.setUint32(24,sampleRate,true);
  v.setUint32(28,sampleRate*2,true); v.setUint16(32,2,true); v.setUint16(34,16,true);
  w(36,"data"); v.setUint32(40,bytes,true);
  new Uint8Array(wav,44).set(new Uint8Array(pcm.buffer, pcm.byteOffset, pcm.byteLength));
  return new Uint8Array(wav);
}
function wavToB64(u8){
  let bin="";
  for(let i=0;i<u8.length;i+=0x8000) bin+=String.fromCharCode.apply(null,u8.subarray(i,i+0x8000));
  return btoa(bin);
}
function extFor(file){
  const n=(file.name||"").toLowerCase();
  if(n.endsWith(".mp3")||file.type==="audio/mpeg") return {ext:"mp3", mime:"audio/mpeg"};
  if(n.endsWith(".m4a")||n.endsWith(".aac")||file.type==="audio/mp4"||file.type==="audio/x-m4a") return {ext:"m4a", mime:"audio/mp4"};
  if(n.endsWith(".wav")||file.type==="audio/wav") return {ext:"wav", mime:"audio/wav"};
  return {ext:"wav", mime:"audio/wav"};
}
async function uploadCoverBytes(bytes, mime, ext){
  await signInAnon();
  if(!S.userId) throw new Error("Sign-in failed");
  const path=S.userId+"/"+uid()+"."+ext;
  const u8=bytes instanceof Uint8Array?bytes:new Uint8Array(bytes);
  const put=await api("/storage/v1/object/covers/"+path,{method:"POST",rawB64:wavToB64(u8),contentType:mime,upsert:true});
  if(!put.ok){
    const t=JSON.stringify(put.obj||{});
    const low=t.toLowerCase();
    if(t.includes("Bucket not found")||put.status===404) throw new Error("NO_BUCKET");
    if(put.status===413||low.includes("too large")||low.includes("maximum allowed size")||low.includes("payload")) throw new Error("TOO_LARGE");
    throw new Error((put.obj&&put.obj.error)||t.slice(0,180)||"upload failed");
  }
  const sign=await api("/storage/v1/object/sign/covers/"+path,{method:"POST",body:{expiresIn:86400}});
  const so=sign.obj||{};
  const rel=so.signedURL||so.signedUrl;
  if(!rel) throw new Error("Could not sign clip");
  return CFG.supabaseURL+"/storage/v1"+(rel.startsWith("/")?rel:"/"+rel);
}
window.onAudio=async(inp)=>{
  const f=inp.files&&inp.files[0]; if(!f) return;
  toast("Reading clip…");
  S.audioB64=null; S.audioUrl=null;
  let decoded=null;
  try{
    const meta=extFor(f);
    const isVideo=/video|mp4|quicktime/i.test(f.type+" "+f.name);
    const buf=await f.arrayBuffer();
    const ctx=new (window.AudioContext||window.webkitAudioContext)();
    decoded=await ctx.decodeAudioData(buf.slice(0));
    await ctx.close();
    const compact=encodeWavMono(decoded, 120, 16000);
    let uploaded=false;
    if(!isVideo && f.size<=12*1024*1024){
      try{
        S.audioUrl=await uploadCoverBytes(new Uint8Array(buf), meta.mime, meta.ext);
        uploaded=true;
        toast(tr("clip_ready")+" · original uploaded");
      }catch(e){ if(String(e.message)==="NO_BUCKET") throw e; }
    }
    if(!uploaded){
      S.audioUrl=await uploadCoverBytes(compact, "audio/wav", "wav");
      toast(tr("clip_ready")+" · 2 min audio uploaded");
    }
    S.audioB64=null;
  }catch(e){
    const msg=String(e.message||e);
    if(decoded){
      S.audioB64=wavToB64(encodeWavMono(decoded, 45));
      S.audioUrl=null;
      toast(msg==="TOO_LARGE"?"File was too big. Using first 45s.":tr("clip_ready")+" (45s)");
    }else{
      S.audioB64=null; S.audioUrl=null;
      toast(msg==="TOO_LARGE"?"File too large. Use an mp3/m4a under 12MB.":"Couldn't read that file. Use mp3 or m4a.");
    }
  }
  render();
};
window.onPhoto=(inp)=>{ const f=inp.files&&inp.files[0]; if(!f) return; const r=new FileReader(); r.onload=()=>{ S.photoURL=r.result; toast(tr("change_photo")); render(); }; r.readAsDataURL(f); };

window.writeLyrics=async()=>{
  if(S.writing) return; S.writing=true; render();
  try{
    await signInAnon();
    const idea=(S.prompt||"").trim()||((S.mood||"Happy")+" "+(S.genre||"Pop")+" song");
    const r=await api("/functions/v1/mint",{method:"POST",body:{action:"lyrics",prompt:idea}});
    if(r.obj.lyrics){ S.lyrics=r.obj.lyrics; if(!S.title&&r.obj.title) S.title=r.obj.title; toast(tr("write_for_me")); }
    else toast(r.obj.error||"lyrics failed");
  }catch(e){ toast(e.message); }
  S.writing=false; render();
};

window.mint=async()=>{
  const g=S.genre||"Pop", m=S.mood||"Happy";
  const title=(S.title||"").trim()||(titleA[Math.floor(Math.random()*6)]+" "+titleB[Math.floor(Math.random()*6)]);
  S.generating=true; S.progress=8; S.genLbl="…"; S.showPlayer=false; render();
  try{
    await signInAnon();
    if(!S.accessToken) throw new Error("Sign-in failed");
    const body={
      prompt:(S.prompt||"").trim()||(m+" "+g+" song"),
      style:g, mood:m, tempo:S.tempo, voice:S.voice, title,
      instrumental:S.instrumental, kind:(S.audioB64||S.audioUrl)?"cover":"song",
      audioWeight:S.audioWeight, styleWeight:S.styleWeight, weirdness:S.weirdness,
    };
    if(!S.instrumental&&S.lyrics) body.lyrics=S.lyrics;
    if(S.audioUrl) body.audioUrl=S.audioUrl;
    else if(S.audioB64 && S.audioB64.length<400000) body.audioBase64=S.audioB64;
    else if(S.audioB64) throw new Error("Cover clip is ready locally but Storage upload failed, so it was not sent. Try mp3/m4a again after a refresh.");
    const start=await api("/functions/v1/mint",{method:"POST",body});
    if(start.obj.paywall){ S.generating=false; S.screen="paywall"; render(); return; }
    const jobId=start.obj.jobId; if(!jobId) throw new Error(start.obj.error||start.obj.detail||start.obj.message||("mint failed ("+start.status+")"));
    const results=await pollJob(jobId);
    results.forEach((v,i)=>{
      S.library.unshift({
        id:uid(), title:v.title||title, meta:g+" · "+m,
        badge:(S.audioB64||S.audioUrl)?"◆ Cover":"◆ Minted",
        audioURL:v.audioURL, img:S.photoURL||v.imageURL, imageURL:S.photoURL||v.imageURL,
        providerAudioId:v.audioId, jobId, liked:false, lyrics:S.lyrics||"",
        take:i===0?"A":"B",
      });
    });
    saveLib(); S.current=S.library[0]; S.audioB64=null; S.audioUrl=null;
    await refreshCredits();
    S.generating=false; S.progress=100; S.showPlayer=true; playAudio(S.current); render();
  }catch(e){ S.generating=false; toast(e.message||String(e)); render(); }
};

window.downloadSong=()=>{
  const s=S.current; if(!s||!s.audioURL){ toast(tr("nothing_download")); return; }
  const a=document.createElement("a"); a.href=s.audioURL; a.download=(s.title||"song")+".mp3"; a.target="_blank"; a.click();
};
window.publishSong=()=>{
  const s=S.current; if(!s) return;
  S.feed.unshift({title:s.title,genre:S.genre||"Pop",author:"@you",plays:"0",likes:"0",img:s.img||s.imageURL,audioURL:s.audioURL});
  saveFeed(); toast(tr("publish_explore")); render();
};
window.extendSong=async()=>{
  const s=S.current;
  if(!s||!s.providerAudioId){ toast("This track can't be extended"); return; }
  S.generating=true; S.progress=5; S.showPlayer=false; S.extendOpen=false; render();
  try{
    await signInAnon();
    const ael=document.getElementById("audioEl");
    const continueAt=ael&&ael.currentTime?Math.floor(ael.currentTime):undefined;
    const start=await api("/functions/v1/extend",{method:"POST",body:{audioId:s.providerAudioId,title:s.title,prompt:S.extendPrompt||"",continueAt}});
    if(!start.obj.jobId) throw new Error(start.obj.error||"extend failed");
    const results=await pollJob(start.obj.jobId);
    results.forEach(v=>S.library.unshift({id:uid(),title:(v.title||s.title)+" (Extended)",meta:s.meta,badge:"◆ Extended",audioURL:v.audioURL,img:v.imageURL||s.img,providerAudioId:v.audioId,jobId:start.obj.jobId}));
    saveLib(); S.current=S.library[0]; await refreshCredits();
    S.generating=false; S.showPlayer=true; playAudio(S.current); render();
  }catch(e){ S.generating=false; toast(e.message); render(); }
};
window.runStems=async(type)=>{
  const s=S.current;
  if(!s||!s.jobId||!s.providerAudioId){ toast("Need a minted track"); return; }
  if(!S.isPro){ S.stemsOpen=false; S.screen="paywall"; render(); return; }
  S.stemsStatus=tr("separating"); render();
  try{
    await signInAnon();
    const r=await api("/functions/v1/stems",{method:"POST",body:{jobId:s.jobId,audioId:s.providerAudioId,type}});
    if(r.obj.stems){ S.stems=r.obj.stems; S.stemsStatus=""; }
    else S.stemsStatus=r.obj.error||"stems failed";
  }catch(e){ S.stemsStatus=e.message; }
  await refreshCredits(); render();
};
window.startVideo=async()=>{
  if(!S.isPro){ S.screen="paywall"; render(); return; }
  try{
    await signInAnon();
    const r=await api("/functions/v1/video",{method:"POST",body:{prompt:"cinematic music video, "+(S.current&&S.current.meta||""),motion:"push_in",imageUrl:S.current&&(S.current.imageURL||S.current.img)}});
    if(r.status===404||r.obj.code==="NOT_FOUND"){ toast(tr("video_soon")); return; }
    toast(r.obj.error||r.obj.jobId||tr("video_soon"));
  }catch(e){ toast(tr("video_soon")); }
};

window.pickTake=(id)=>{ const s=S.library.find(x=>x.id===id); if(!s) return; S.current=s; S.showPlayer=true; playAudio(s); render(); };
window.shareSong=async()=>{
  const s=S.current; if(!s||!s.audioURL) return;
  try{
    if(navigator.share) await navigator.share({title:s.title,url:s.audioURL});
    else { await navigator.clipboard.writeText(s.audioURL); toast("Link copied"); }
  }catch(e){ toast("Share cancelled"); }
};
window.vibeIterate=async()=>{
  const note=(S.vibePrompt||"").trim();
  if(!note){ toast("Describe the change"); return; }
  const s=S.current;
  S.prompt=(s&&s.title?s.title+". ":"")+note;
  S.mode="Custom";
  S.showPlayer=false;
  await mint();
};
window.resetAccount=()=>{
  ["sb_access_token","sb_refresh_token","sb_user_id","library_v1","is_pro"].forEach(k=>localStorage.removeItem(k));
  location.reload();
};

const audioEl=document.getElementById("audioEl");
if(audioEl) audioEl.addEventListener("timeupdate",()=>{
  const fill=document.getElementById("plFill");
  if(fill&&audioEl.duration) fill.style.width=(audioEl.currentTime/audioEl.duration*100)+"%";
});

(async()=>{
  await loadStrings();
  await detectLang();
  render();
  try{ await signInAnon(); await refreshCredits(); render(); }catch(e){ console.warn(e); }
})();
