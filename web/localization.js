/* Country-first locale. No GPS. */
const SUPPORTED = ["en","it","es","fr","de","pt"];
const COUNTRIES = {IT:"it",SM:"it",VA:"it",ES:"es",FR:"fr",MC:"fr",DE:"de",AT:"de",LI:"de",CH:"de",PT:"pt",BR:"pt",GB:"en",IE:"en",US:"en",AU:"en",CA:"en",BE:"fr",LU:"fr"};
let STRINGS = {};
let LANG = "en";

function tr(key) {
  const row = STRINGS[key];
  if (!row) return key;
  return row[LANG] || row.en || key;
}

async function loadStrings() {
  try { STRINGS = await (await fetch("/translations.json")).json(); } catch { STRINGS = {}; }
}

async function detectLang() {
  const ov = localStorage.getItem("language_override");
  if (SUPPORTED.includes(ov)) { LANG = ov; return LANG; }
  const nav = (navigator.language || "en").slice(0, 2).toLowerCase();
  LANG = SUPPORTED.includes(nav) ? nav : "en";
  try {
    const r = await fetch("https://get.geojs.io/v1/ip/country.json", { signal: AbortSignal.timeout(3500) });
    if (r.ok) {
      const d = await r.json();
      LANG = COUNTRIES[d.country] || LANG;
    }
  } catch {}
  document.documentElement.lang = LANG;
  return LANG;
}

function setLangOverride(code) {
  if (code === "auto") localStorage.removeItem("language_override");
  else localStorage.setItem("language_override", code);
  location.reload();
}
