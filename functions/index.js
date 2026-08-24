const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { defineSecret, defineString } = require("firebase-functions/params");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, Timestamp, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const crypto = require("crypto");
const logger = require("firebase-functions/logger");

// Lazy-initialized — NOT called at module load time. Firebase CLI's local
// deploy-time discovery step requires this file just to read the exported
// function declarations, without real Application Default Credentials
// available; an eager initializeApp() call stalls there trying to reach the
// GCE metadata server and blows past the CLI's 10s discovery timeout. Deferring
// this to first actual invocation means it only ever runs inside Cloud
// Functions itself, where ADC resolves immediately.
let appInitialized = false;
function ensureAppInitialized() {
  if (!appInitialized) {
    initializeApp();
    appInitialized = true;
  }
}

let firestoreDb;
function db() {
  ensureAppInitialized();
  if (!firestoreDb) firestoreDb = getFirestore();
  return firestoreDb;
}

let messaging;
function fcm() {
  ensureAppInitialized();
  if (!messaging) messaging = getMessaging();
  return messaging;
}

// Server-side pass-through proxies for third-party APIs that don't send
// CORS headers, so Flutter web builds can't call them directly from the
// browser. Native (Android/iOS/desktop) builds call the real APIs directly
// and never hit these — only web routes through here (see kIsWeb checks in
// climate_satellite_service.dart / eudr_compliance_service.dart).

const AGRO_BASE = "https://api.agromonitoring.com/agro/1.0";
const GFW_BASE = "https://data-api.globalforestwatch.org";

async function forward(req, res, base) {
  const path = req.path === "/" ? "" : req.path;
  const qIndex = req.url.indexOf("?");
  const search = qIndex >= 0 ? req.url.slice(qIndex) : "";
  const upstreamUrl = `${base}${path}${search}`;

  const headers = {};
  const contentType = req.get("content-type");
  if (contentType) headers["content-type"] = contentType;
  const apiKey = req.get("x-api-key");
  if (apiKey) headers["x-api-key"] = apiKey;

  const init = { method: req.method, headers };
  if (req.method !== "GET" && req.method !== "HEAD") {
    init.body = JSON.stringify(req.body || {});
  }

  try {
    const upstreamRes = await fetch(upstreamUrl, init);
    const text = await upstreamRes.text();
    res.status(upstreamRes.status);
    res.set(
      "Content-Type",
      upstreamRes.headers.get("content-type") || "application/json"
    );
    res.send(text);
  } catch (err) {
    res.status(502).json({ error: "Upstream request failed", detail: String(err) });
  }
}

exports.agroProxy = onRequest(
  { region: "us-central1", cors: true },
  (req, res) => forward(req, res, AGRO_BASE)
);

exports.gfwProxy = onRequest(
  { region: "us-central1", cors: true },
  (req, res) => forward(req, res, GFW_BASE)
);

// ── NuaSense weather station API ────────────────────────────────────────
//
// Callable (not a plain HTTP proxy like agroProxy/gfwProxy above) because
// the NuaSense API key must never reach the client — it's only readable
// here, inside Cloud Functions, via Secret Manager
// (`firebase functions:secrets:set NUASENSE_API_KEY`).
//
// NUASENSE_BASE_URL is a plain (non-secret) runtime param — set it with
// `firebase functions:config` equivalent for v2 params: create
// functions/.env.coffeecore-7111a with `NUASENSE_BASE_URL=https://...`,
// or `firebase functions:secrets:set NUASENSE_BASE_URL` also works since
// defineString falls back to reading env/secret files the same way. It's
// still unset as of this writing — getNuaSenseData fails closed with a
// clear "failed-precondition" error until it's configured, rather than
// silently calling an invented host.
//
// Endpoint allowlist mirrors exactly what lib/screens/Weather Station/
// nuasense_service.dart calls — nothing else is reachable through here.
const nuaSenseApiKey = defineSecret("NUASENSE_API_KEY");
const nuaSenseBaseUrl = defineString("NUASENSE_BASE_URL", { default: "" });

const NUASENSE_ALLOWED_ENDPOINTS = new Set([
  "weather",
  "derived",
  "stations",
  "derived/forecast",
]);

exports.getNuaSenseData = onCall(
  { region: "us-central1", secrets: [nuaSenseApiKey] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to load weather station data.");
    }

    const { endpoint, params } = request.data || {};
    if (typeof endpoint !== "string" || !NUASENSE_ALLOWED_ENDPOINTS.has(endpoint)) {
      throw new HttpsError("invalid-argument", "Unsupported NuaSense endpoint.");
    }

    const baseUrl = nuaSenseBaseUrl.value();
    if (!baseUrl) {
      throw new HttpsError(
        "failed-precondition",
        "NUASENSE_BASE_URL is not configured yet. Set it via functions/.env.coffeecore-7111a."
      );
    }

    const query = new URLSearchParams();
    if (params && typeof params === "object") {
      for (const [key, value] of Object.entries(params)) {
        if (value !== undefined && value !== null) query.set(key, String(value));
      }
    }
    const search = query.toString();
    const url = `${baseUrl.replace(/\/$/, "")}/${endpoint}${search ? `?${search}` : ""}`;

    let upstreamRes;
    try {
      upstreamRes = await fetch(url, {
        headers: { "x-api-key": nuaSenseApiKey.value() },
      });
    } catch (err) {
      throw new HttpsError("unavailable", `Could not reach NuaSense API: ${err}`);
    }

    const text = await upstreamRes.text();
    if (!upstreamRes.ok) {
      throw new HttpsError(
        "unavailable",
        `NuaSense API error (HTTP ${upstreamRes.status})`,
        { detail: text }
      );
    }

    try {
      return JSON.parse(text);
    } catch (err) {
      throw new HttpsError("internal", "NuaSense API returned an unparseable response.");
    }
  }
);

// ── Sentinel Hub NDWI (Copernicus Data Space Ecosystem) ────────────
//
// Unlike the plain pass-through proxies above, this endpoint owns the
// entire OAuth2 client-credentials exchange and Statistical API call
// itself. The client ID/secret are stored in Google Secret Manager via
// `firebase functions:secrets:set SENTINEL_HUB_CLIENT_ID` /
// `SENTINEL_HUB_CLIENT_SECRET` and are only ever readable inside this
// function's process — they are never sent to, or embedded in, the
// Flutter app (web bundles and decompiled APKs are both public, so a
// client secret baked into either would be exposed to anyone). The app
// only ever calls this endpoint with a farm's polygon coordinates and
// gets back computed NDWI statistics.

const sentinelClientId = defineSecret("SENTINEL_HUB_CLIENT_ID");
const sentinelClientSecret = defineSecret("SENTINEL_HUB_CLIENT_SECRET");

const SENTINEL_AUTH_URL =
  "https://identity.dataspace.copernicus.eu/auth/realms/CDSE/protocol/openid-connect/token";
const SENTINEL_STATS_URL = "https://sh.dataspace.copernicus.eu/api/v1/statistics";

const NDWI_EVALSCRIPT = `
//VERSION=3
function setup() {
  return {
    input: [{ bands: ["B03", "B08", "dataMask"] }],
    output: [
      { id: "ndwi", bands: 1, sampleType: "FLOAT32" },
      { id: "dataMask", bands: 1 }
    ]
  };
}
function evaluatePixel(sample) {
  let ndwi = (sample.B03 - sample.B08) / (sample.B03 + sample.B08);
  return { ndwi: [ndwi], dataMask: [sample.dataMask] };
}
`;

// Best-effort in-memory cache. Persists across warm invocations of the
// same function instance (not guaranteed, but avoids a redundant token
// request on most calls) — never persisted anywhere durable.
let cachedToken = null;
let tokenExpiry = 0;

async function getSentinelAccessToken() {
  if (cachedToken && Date.now() < tokenExpiry) return cachedToken;

  const body = new URLSearchParams({
    grant_type: "client_credentials",
    client_id: sentinelClientId.value(),
    client_secret: sentinelClientSecret.value(),
  });

  const res = await fetch(SENTINEL_AUTH_URL, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: body.toString(),
  });
  const text = await res.text();
  if (!res.ok) {
    throw new Error(`Sentinel Hub auth failed (HTTP ${res.status}): ${text}`);
  }
  const parsed = JSON.parse(text);
  cachedToken = parsed.access_token;
  tokenExpiry = Date.now() + (Number(parsed.expires_in || 300) - 60) * 1000;
  return cachedToken;
}

function closeRing(coordinates) {
  const ring = coordinates.map((c) => [c[0], c[1]]);
  const first = ring[0];
  const last = ring[ring.length - 1];
  if (first[0] !== last[0] || first[1] !== last[1]) ring.push(first);
  return ring;
}

exports.sentinelHubNdwi = onRequest(
  {
    region: "us-central1",
    cors: true,
    secrets: [sentinelClientId, sentinelClientSecret],
  },
  async (req, res) => {
    try {
      const { coordinates, from, to } = req.body || {};
      if (!Array.isArray(coordinates) || coordinates.length < 3) {
        res.status(400).json({ error: "coordinates must be a ring of at least 3 [lng, lat] pairs" });
        return;
      }

      const ring = closeRing(coordinates);

      const rangeEnd = to || new Date().toISOString();
      const rangeStart =
        from || new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();

      const token = await getSentinelAccessToken();

      const statsRes = await fetch(SENTINEL_STATS_URL, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          input: {
            bounds: { geometry: { type: "Polygon", coordinates: [ring] } },
            data: [{ type: "sentinel-2-l2a" }],
          },
          aggregation: {
            timeRange: { from: rangeStart, to: rangeEnd },
            aggregationInterval: { of: "P10D" },
            evalscript: NDWI_EVALSCRIPT,
            resx: 10,
            resy: 10,
          },
        }),
      });

      const statsText = await statsRes.text();
      if (!statsRes.ok) {
        res.status(statsRes.status).json({
          error: "Sentinel Hub Statistical API error",
          detail: statsText,
        });
        return;
      }

      const decoded = JSON.parse(statsText);
      const intervals = decoded.data || [];
      let stats = null;
      let intervalEnd = null;
      for (let i = intervals.length - 1; i >= 0; i--) {
        const entry = intervals[i];
        const bandStats = entry.outputs && entry.outputs.ndwi && entry.outputs.ndwi.bands
          && entry.outputs.ndwi.bands.B0 && entry.outputs.ndwi.bands.B0.stats;
        if (bandStats && bandStats.sampleCount > 0) {
          stats = bandStats;
          intervalEnd = entry.interval && entry.interval.to;
          break;
        }
      }

      if (!stats) {
        res.status(404).json({
          error: "No valid NDWI pixels found in the requested time range (likely cloud cover).",
        });
        return;
      }

      res.status(200).json({
        mean: stats.mean,
        min: stats.min,
        max: stats.max,
        stDev: stats.stDev,
        fetchedAt: intervalEnd || new Date().toISOString(),
      });
    } catch (err) {
      res.status(502).json({ error: "sentinelHubNdwi failed", detail: String(err) });
    }
  }
);

// ── Sentinel Hub colorized raster (NDVI/NDWI, clipped to farm shape) ──
//
// Renders an actual pixel-by-pixel colorized Sentinel-2 image (not a single
// aggregate value) so the map can show real within-field variation, like a
// standard NDVI/NDWI heat-map. The evalscript below computes the index per
// pixel and maps it directly to RGB using the SAME stop/color tables as
// FarmTheme.ndviColors/ndwiColors in the Flutter app, so the raster and the
// on-screen legend never disagree. Pixels outside the farm polygon (or with
// no valid data) are made fully transparent via the alpha channel, so the
// PNG can be dropped straight onto the map as a GroundOverlay and it reads
// as "clipped to the farm shape" without any extra masking on the client.

const SENTINEL_PROCESS_URL = "https://sh.dataspace.copernicus.eu/api/v1/process";

// Mirrors FarmTheme.ndviStops/ndviColors and ndwiStops/ndwiColors exactly.
const RAMPS = {
  ndvi: {
    bands: ["B04", "B08", "dataMask"],
    formula: "(sample.B08 - sample.B04) / (sample.B08 + sample.B04)",
    stops: [-1.0, 0.0, 0.1, 0.2, 0.35, 0.5, 0.7, 1.0],
    colors: [
      [0x9e, 0x9e, 0x9e],
      [0x8d, 0x6e, 0x63],
      [0xbc, 0xaa, 0x33],
      [0xd4, 0xcb, 0x27],
      [0xa8, 0xd1, 0x4c],
      [0x6c, 0xbf, 0x43],
      [0x3e, 0x8e, 0x28],
      [0x1b, 0x5e, 0x20],
    ],
  },
  ndwi: {
    bands: ["B03", "B08", "dataMask"],
    formula: "(sample.B03 - sample.B08) / (sample.B03 + sample.B08)",
    stops: [-1.0, -0.3, -0.1, 0.0, 0.1, 0.3, 0.6, 1.0],
    colors: [
      [0x6d, 0x4c, 0x29],
      [0xa9, 0x82, 0x5a],
      [0xd8, 0xc7, 0x9a],
      [0xe0, 0xe0, 0xc0],
      [0xae, 0xd9, 0xe0],
      [0x4f, 0xa3, 0xd1],
      [0x15, 0x65, 0xc0],
      [0x0d, 0x47, 0xa1],
    ],
  },
};

function buildRasterEvalscript(metric) {
  const ramp = RAMPS[metric];
  return `
//VERSION=3
function setup() {
  return {
    input: [{ bands: ${JSON.stringify(ramp.bands)} }],
    output: { bands: 4, sampleType: "AUTO" }
  };
}
var STOPS = ${JSON.stringify(ramp.stops)};
var COLORS = ${JSON.stringify(ramp.colors)};
function lerpRamp(value) {
  var v = Math.max(STOPS[0], Math.min(STOPS[STOPS.length - 1], value));
  for (var i = 0; i < STOPS.length - 1; i++) {
    if (v >= STOPS[i] && v <= STOPS[i + 1]) {
      var t = (v - STOPS[i]) / (STOPS[i + 1] - STOPS[i]);
      var c0 = COLORS[i], c1 = COLORS[i + 1];
      return [
        c0[0] + (c1[0] - c0[0]) * t,
        c0[1] + (c1[1] - c0[1]) * t,
        c0[2] + (c1[2] - c0[2]) * t,
      ];
    }
  }
  return COLORS[COLORS.length - 1];
}
function evaluatePixel(sample) {
  var index = ${ramp.formula};
  var rgb = lerpRamp(index);
  return [rgb[0] / 255, rgb[1] / 255, rgb[2] / 255, sample.dataMask];
}
`;
}

exports.sentinelHubRaster = onRequest(
  {
    region: "us-central1",
    cors: true,
    secrets: [sentinelClientId, sentinelClientSecret],
    timeoutSeconds: 60,
  },
  async (req, res) => {
    try {
      const { coordinates, metric, from, to } = req.body || {};
      if (!Array.isArray(coordinates) || coordinates.length < 3) {
        res.status(400).json({ error: "coordinates must be a ring of at least 3 [lng, lat] pairs" });
        return;
      }
      if (metric !== "ndvi" && metric !== "ndwi") {
        res.status(400).json({ error: 'metric must be "ndvi" or "ndwi"' });
        return;
      }

      const ring = closeRing(coordinates);
      const lngs = ring.map((c) => c[0]);
      const lats = ring.map((c) => c[1]);
      const west = Math.min(...lngs);
      const east = Math.max(...lngs);
      const south = Math.min(...lats);
      const north = Math.max(...lats);

      const lngSpan = Math.max(east - west, 1e-6);
      const latSpan = Math.max(north - south, 1e-6);
      const midLatRad = ((south + north) / 2) * (Math.PI / 180);
      const aspect = (lngSpan * Math.cos(midLatRad)) / latSpan;
      const maxDim = 640;
      const width = aspect >= 1 ? maxDim : Math.max(64, Math.round(maxDim * aspect));
      const height = aspect >= 1 ? Math.max(64, Math.round(maxDim / aspect)) : maxDim;

      const rangeEnd = to || new Date().toISOString();
      const rangeStart =
        from || new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();

      const token = await getSentinelAccessToken();

      const processRes = await fetch(SENTINEL_PROCESS_URL, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          authorization: `Bearer ${token}`,
          accept: "image/png",
        },
        body: JSON.stringify({
          input: {
            bounds: {
              bbox: [west, south, east, north],
              properties: { crs: "http://www.opengis.net/def/crs/OGC/1.3/CRS84" },
              geometry: { type: "Polygon", coordinates: [ring] },
            },
            data: [
              {
                type: "sentinel-2-l2a",
                dataFilter: {
                  timeRange: { from: rangeStart, to: rangeEnd },
                  mosaickingOrder: "leastCC",
                  maxCloudCoverage: 40,
                },
              },
            ],
          },
          output: {
            width,
            height,
            responses: [{ identifier: "default", format: { type: "image/png" } }],
          },
          evalscript: buildRasterEvalscript(metric),
        }),
      });

      if (!processRes.ok) {
        const errText = await processRes.text();
        res.status(processRes.status).json({
          error: "Sentinel Hub Process API error",
          detail: errText,
        });
        return;
      }

      const arrayBuffer = await processRes.arrayBuffer();
      const base64 = Buffer.from(arrayBuffer).toString("base64");

      res.status(200).json({
        imageBase64: base64,
        bbox: { west, south, east, north },
        fetchedAt: new Date().toISOString(),
      });
    } catch (err) {
      res.status(502).json({ error: "sentinelHubRaster failed", detail: String(err) });
    }
  }
);

// ── Planetek EUDR Certified Deforestation Analysis ──────────────────────
//
// Second, independent EUDR deforestation check alongside the existing GFW
// screening in eudr_compliance_service.dart. Owns the whole flow —
// client-credentials token exchange, deployment lookup, submitting the
// Prefect flow run, polling it to completion, and verifying the Ed25519
// signature on the result — entirely server-side, so PLANETEK_CLIENT_ID/
// PLANETEK_CLIENT_SECRET never reach the Flutter app. Configure with:
//   firebase functions:secrets:set PLANETEK_CLIENT_ID
//   firebase functions:secrets:set PLANETEK_CLIENT_SECRET
// See docs/planetek_eudr/README.md for full context, credential status,
// and the open risks around signature-canonicalization and response shape
// that are unverifiable until a real clientSecret is in place.

const planetekClientId = defineSecret("PLANETEK_CLIENT_ID");
const planetekClientSecret = defineSecret("PLANETEK_CLIENT_SECRET");

const PLANETEK_TOKEN_URL =
  "https://archytas.planetek.it/api/v1/tokens/client-credentials";
const PLANETEK_DEPLOYMENT_URL =
  "https://flows.archytas.planetek.it/api/deployments/name";
const PLANETEK_DEPLOYMENT_NAME = "deforestation-analysis/deforestation-analysis";
const PLANETEK_DEPLOYMENT_RUN_URL = "https://flows.archytas.planetek.it/api/deployments";
// Tutorial mixes https:// (deployment lookup) and http:// (flow-run polling)
// for the same host — try https first (consistent with the other endpoints),
// fall back to http, and cache whichever one actually answers.
const PLANETEK_FLOW_RUN_URL_CANDIDATES = [
  "https://flows.archytas.planetek.it/api/flow_runs",
  "http://flows.archytas.planetek.it/api/flow_runs",
];

// Public key Planetek gave alongside check_signature.py — not secret (it's
// a *public* key), safe to keep in source. See docs/planetek_eudr/.
const PLANETEK_PUBLIC_KEY_B64 = "ESk6chNPFPIx-pySnrHxoDVFJjvelQZ-RM7UhdyRuDo=";
const PLANETEK_PUBLIC_KEY_FINGERPRINT =
  "955f2fa5090b49826feb221df76a1e710a6abe660161e4ca2badd146ef0e3a4d";
const PLANETEK_SIGNED_METADATA_FIELDS = [
  "deployment_id",
  "deployment_version",
  "algorithm_version",
];

// Deployment UUID is stable "unless the algorithm is updated" per the
// tutorial — seeded with the value confirmed live on 2026-07-27
// (deployment "deforestation-analysis" v0.2.1) so a warm *or cold*
// function instance skips the lookup round trip entirely in the common
// case. resolvePlanetekDeploymentId() still exists as the self-healing
// path: if Planetek ever rotates this (e.g. an algorithm upgrade), the
// cached UUID will 404 on create_flow_run, submitPlanetekRun() clears the
// cache and re-resolves once, and this constant just becomes a stale
// first guess instead of a hard dependency.
let cachedPlanetekDeploymentId = "a089937c-5ba9-43be-8ef0-afe59c16c1bb";
// Whichever flow-run base URL (https/http) actually answered, cached the
// same way. https:// is confirmed working as of the 2026-07-27 live test,
// so seed it instead of paying the fallback probe on every cold instance.
let cachedPlanetekFlowRunBase = "https://flows.archytas.planetek.it/api/flow_runs";

// Tokens are requested with a 60s TTL — polling a single flow run can
// easily issue a dozen+ requests over that time, so refetching a token
// per-request (as a naive implementation would) wastes a full auth round
// trip on every single one. Cache it in-process and only refresh a few
// seconds before it actually expires, mirroring the Sentinel Hub
// cachedToken/tokenExpiry pattern above. This does not change what gets
// fetched or verified — only how many times we re-authenticate to fetch it.
let cachedPlanetekToken = null;
let cachedPlanetekTokenExpiry = 0;
const PLANETEK_TOKEN_TTL_SECONDS = 60;
const PLANETEK_TOKEN_REFRESH_BUFFER_SECONDS = 8;

async function getPlanetekToken() {
  if (cachedPlanetekToken && Date.now() < cachedPlanetekTokenExpiry) {
    logger.info("planetek.token: cache hit");
    return cachedPlanetekToken;
  }

  const t0 = Date.now();
  const res = await fetch(PLANETEK_TOKEN_URL, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      clientId: planetekClientId.value(),
      clientSecret: planetekClientSecret.value(),
      audiences: ["prefect"],
      ttlSeconds: PLANETEK_TOKEN_TTL_SECONDS,
    }),
  });
  const text = await res.text();
  logger.info(`planetek.token: HTTP ${res.status} in ${Date.now() - t0}ms`);
  if (!res.ok) {
    throw new Error(`Planetek token request failed (HTTP ${res.status}): ${text}`);
  }
  const parsed = JSON.parse(text);
  if (!parsed.exchange_token) {
    throw new Error("Planetek token response missing exchange_token");
  }

  cachedPlanetekToken = parsed.exchange_token;
  const ttl = Number(parsed.expiresIn || PLANETEK_TOKEN_TTL_SECONDS);
  cachedPlanetekTokenExpiry =
    Date.now() + Math.max(ttl - PLANETEK_TOKEN_REFRESH_BUFFER_SECONDS, 1) * 1000;
  return cachedPlanetekToken;
}

async function resolvePlanetekDeploymentId({ forceRefresh = false } = {}) {
  if (cachedPlanetekDeploymentId && !forceRefresh) {
    logger.info("planetek.deployment: cache hit");
    return cachedPlanetekDeploymentId;
  }
  const token = await getPlanetekToken();
  const t0 = Date.now();
  const res = await fetch(`${PLANETEK_DEPLOYMENT_URL}/${PLANETEK_DEPLOYMENT_NAME}`, {
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
  });
  const text = await res.text();
  logger.info(`planetek.deployment: HTTP ${res.status} in ${Date.now() - t0}ms (forceRefresh=${forceRefresh})`);
  if (!res.ok) {
    throw new Error(`Planetek deployment lookup failed (HTTP ${res.status}): ${text}`);
  }
  const parsed = JSON.parse(text);
  if (!parsed.id) {
    throw new Error("Planetek deployment lookup response missing id");
  }
  cachedPlanetekDeploymentId = parsed.id;
  return parsed.id;
}

async function submitPlanetekRun(featureCollection) {
  const deploymentId = await resolvePlanetekDeploymentId();
  const token = await getPlanetekToken();
  const t0 = Date.now();
  const res = await fetch(
    `${PLANETEK_DEPLOYMENT_RUN_URL}/${deploymentId}/create_flow_run`,
    {
      method: "POST",
      headers: {
        accept: "application/json, text/plain, */*",
        "content-type": "application/json",
        authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({ parameters: { feature_collection: featureCollection } }),
    }
  );
  logger.info(`planetek.submit: HTTP ${res.status} in ${Date.now() - t0}ms (deploymentId=${deploymentId})`);

  // Self-heal against a stale cached deployment ID (e.g. after Planetek
  // rotates the deployment on an algorithm upgrade): re-resolve once and
  // retry, instead of failing outright on a seeded/cached UUID gone stale.
  if (res.status === 404) {
    logger.warn("planetek.submit: 404 on cached deploymentId, re-resolving and retrying once");
    const freshDeploymentId = await resolvePlanetekDeploymentId({ forceRefresh: true });
    const retryToken = await getPlanetekToken();
    const retryT0 = Date.now();
    const retryRes = await fetch(
      `${PLANETEK_DEPLOYMENT_RUN_URL}/${freshDeploymentId}/create_flow_run`,
      {
        method: "POST",
        headers: {
          accept: "application/json, text/plain, */*",
          "content-type": "application/json",
          authorization: `Bearer ${retryToken}`,
        },
        body: JSON.stringify({ parameters: { feature_collection: featureCollection } }),
      }
    );
    const retryText = await retryRes.text();
    logger.info(`planetek.submit.retry: HTTP ${retryRes.status} in ${Date.now() - retryT0}ms (deploymentId=${freshDeploymentId})`);
    if (!retryRes.ok) {
      throw new Error(`Planetek create_flow_run failed (HTTP ${retryRes.status}): ${retryText}`);
    }
    const retryParsed = JSON.parse(retryText);
    if (!retryParsed.id) {
      throw new Error("Planetek create_flow_run response missing id");
    }
    logger.info(`planetek.submit: flowRunId=${retryParsed.id}`);
    return retryParsed.id;
  }

  const text = await res.text();
  if (!res.ok) {
    throw new Error(`Planetek create_flow_run failed (HTTP ${res.status}): ${text}`);
  }
  const parsed = JSON.parse(text);
  if (!parsed.id) {
    throw new Error("Planetek create_flow_run response missing id");
  }
  logger.info(`planetek.submit: flowRunId=${parsed.id}`);
  return parsed.id;
}

async function fetchPlanetekFlowRun(flowRunId) {
  const token = await getPlanetekToken();
  // Try the cached-good base first (the common case — zero wasted probes),
  // but still fall through to the other candidate within this same call if
  // it fails, instead of only self-healing on the *next* call.
  const orderedBases = cachedPlanetekFlowRunBase
    ? [
        cachedPlanetekFlowRunBase,
        ...PLANETEK_FLOW_RUN_URL_CANDIDATES.filter(
          (b) => b !== cachedPlanetekFlowRunBase
        ),
      ]
    : PLANETEK_FLOW_RUN_URL_CANDIDATES;

  let lastErr;
  for (const base of orderedBases) {
    const t0 = Date.now();
    try {
      const res = await fetch(`${base}/${flowRunId}`, {
        headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
      });
      const text = await res.text();
      logger.info(`planetek.poll: HTTP ${res.status} in ${Date.now() - t0}ms (base=${base})`);
      if (!res.ok) throw new Error(`HTTP ${res.status}: ${text}`);
      cachedPlanetekFlowRunBase = base;
      return JSON.parse(text);
    } catch (err) {
      logger.warn(`planetek.poll: base ${base} failed in ${Date.now() - t0}ms: ${err}`);
      lastErr = err;
    }
  }
  cachedPlanetekFlowRunBase = null;
  throw new Error(`Planetek flow run fetch failed on all endpoints: ${lastErr}`);
}

// ── Signature verification (Node port of check_signature.py) ────────────
//
// Must match Python's json.dumps(..., sort_keys=True,
// separators=(",", ":"), ensure_ascii=False) byte-for-byte, or a
// genuinely valid signature will appear invalid. The one known trap:
// JSON round-tripping loses Python's int/float distinction, so a
// whole-number float like 100.0 would re-serialize as "100" in plain JS
// instead of "100.0" — pyFloat() below forces the ".0" back on for any
// JS number that came through this path, since every numeric field in
// the known "data" shape (forest_area_2020_ha, deforested_area_ha,
// deforested_percentage) is a Python float, never an int.

function base64UrlToBuffer(value) {
  const b64 = value.replace(/-/g, "+").replace(/_/g, "/");
  return Buffer.from(b64, "base64");
}

function pyFloat(n) {
  return Number.isInteger(n) ? `${n}.0` : String(n);
}

function canonicalJson(value) {
  if (value === null || value === undefined) return "null";
  if (typeof value === "boolean") return value ? "true" : "false";
  if (typeof value === "number") return pyFloat(value);
  if (typeof value === "string") return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(",")}]`;
  if (typeof value === "object") {
    const keys = Object.keys(value).sort();
    return `{${keys
      .map((k) => `${JSON.stringify(k)}:${canonicalJson(value[k])}`)
      .join(",")}}`;
  }
  throw new Error(`canonicalJson: unsupported value type ${typeof value}`);
}

function ed25519PublicKeyFromRaw(rawKeyBuffer) {
  const jwk = { kty: "OKP", crv: "Ed25519", x: rawKeyBuffer.toString("base64url") };
  return crypto.createPublicKey({ key: jwk, format: "jwk" });
}

function verifyPlanetekSignature(payload) {
  const data = payload && payload.data;
  const metadata = payload && payload.metadata;
  if (!data || !metadata) {
    return { verified: false, reason: "payload missing data/metadata envelope" };
  }

  const algorithm = metadata.signature_algorithm;
  const signatureB64 = metadata.signature;
  const payloadFingerprint = metadata.public_key_fingerprint;
  if (algorithm !== "ed25519-sha256") {
    return { verified: false, reason: `unsupported signature algorithm: ${algorithm}` };
  }
  if (!signatureB64 || !payloadFingerprint) {
    return { verified: false, reason: "metadata missing signature or fingerprint" };
  }

  const publicKeyBytes = base64UrlToBuffer(PLANETEK_PUBLIC_KEY_B64);
  const calculatedFingerprint = crypto
    .createHash("sha256")
    .update(publicKeyBytes)
    .digest("hex");
  if (
    calculatedFingerprint !== PLANETEK_PUBLIC_KEY_FINGERPRINT ||
    payloadFingerprint !== PLANETEK_PUBLIC_KEY_FINGERPRINT
  ) {
    return { verified: false, reason: "public key fingerprint mismatch" };
  }

  const signedMetadata = {};
  for (const field of PLANETEK_SIGNED_METADATA_FIELDS) {
    signedMetadata[field] = metadata[field];
  }

  try {
    const signedBytes = Buffer.from(
      canonicalJson({ data, metadata: signedMetadata }),
      "utf8"
    );
    const publicKey = ed25519PublicKeyFromRaw(publicKeyBytes);
    const ok = crypto.verify(
      null,
      signedBytes,
      publicKey,
      base64UrlToBuffer(signatureB64)
    );
    return { verified: ok, reason: ok ? null : "signature mismatch" };
  } catch (err) {
    return { verified: false, reason: `verification error: ${err}` };
  }
}

exports.runPlanetekDeforestationAnalysis = onCall(
  {
    region: "us-central1",
    secrets: [planetekClientId, planetekClientSecret],
    // Raised from 300s -> 540s: live traffic is now regularly seeing the
    // Prefect flow run itself (not our auth/submit overhead — see the
    // planetek.* timing logs) take longer than the old 4-minute poll
    // budget, which surfaced as a false "deadline-exceeded" even though
    // the analysis was still legitimately running. See docs/planetek_eudr/.
    timeoutSeconds: 540,
    memory: "256MiB",
  },
  async (request) => {
    const requestStart = Date.now();
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Sign in to run the certified EUDR deforestation analysis."
      );
    }

    const featureCollection = request.data && request.data.featureCollection;
    if (
      !featureCollection ||
      featureCollection.type !== "FeatureCollection" ||
      !Array.isArray(featureCollection.features) ||
      featureCollection.features.length === 0
    ) {
      throw new HttpsError(
        "invalid-argument",
        "featureCollection must be a valid GeoJSON FeatureCollection with at least one feature."
      );
    }

    logger.info(
      `planetek.run: starting for uid=${request.auth.uid}, features=${featureCollection.features.length}`
    );

    let flowRunId;
    const submitStart = Date.now();
    try {
      flowRunId = await submitPlanetekRun(featureCollection);
    } catch (err) {
      logger.error(`planetek.run: submit failed after ${Date.now() - submitStart}ms: ${err}`);
      throw new HttpsError(
        "unavailable",
        `Could not submit the certified deforestation analysis to Planetek: ${err}`
      );
    }
    logger.info(`planetek.run: submitted in ${Date.now() - submitStart}ms, flowRunId=${flowRunId}`);

    const pollIntervalMs = 5000;
    const maxPolls = 96; // ~8 minutes of polling, within the 540s function timeout
    let finalRun = null;
    for (let attempt = 0; attempt < maxPolls; attempt++) {
      let run;
      const pollStart = Date.now();
      try {
        run = await fetchPlanetekFlowRun(flowRunId);
      } catch (err) {
        logger.error(
          `planetek.run: status check failed on attempt ${attempt + 1}/${maxPolls} ` +
            `(elapsed ${Date.now() - requestStart}ms): ${err}`
        );
        throw new HttpsError(
          "unavailable",
          `Could not check the Planetek analysis status: ${err}`
        );
      }

      const stateType = run.state && run.state.type;
      logger.info(
        `planetek.run: attempt ${attempt + 1}/${maxPolls} state=${stateType} ` +
          `(poll took ${Date.now() - pollStart}ms, total elapsed ${Date.now() - requestStart}ms)`
      );
      if (stateType === "COMPLETED") {
        finalRun = run;
        break;
      }
      if (stateType === "FAILED") {
        throw new HttpsError(
          "unavailable",
          "The Planetek deforestation analysis failed. Check the farm boundary is a " +
            "valid polygon, or contact Planetek if this persists."
        );
      }
      if (stateType === "CRASHED") {
        throw new HttpsError(
          "resource-exhausted",
          "The Planetek deforestation analysis crashed — this farm boundary is likely " +
            "too large for the allocated compute. Try again with a smaller area."
        );
      }
      await new Promise((resolve) => setTimeout(resolve, pollIntervalMs));
    }

    if (!finalRun) {
      logger.error(
        `planetek.run: gave up after ${maxPolls} polls, total elapsed ${Date.now() - requestStart}ms`
      );
      throw new HttpsError(
        "deadline-exceeded",
        "The Planetek deforestation analysis is taking longer than expected. Please try again shortly."
      );
    }

    let analysis;
    try {
      analysis = JSON.parse(finalRun.state.message);
    } catch (err) {
      throw new HttpsError("internal", "Planetek returned an unparseable analysis result.");
    }

    // Real responses are expected to carry the signed envelope shape used by
    // check_signature.py ({"data": {...}, "metadata": {...}}). Fall back to
    // treating the whole object as unsigned data if a flatter shape (like
    // the tutorial's own illustrative examples) comes back instead — never
    // fail the whole flow over this, just don't claim it's verified.
    let data = analysis;
    let signatureVerified = false;
    let signatureNote = "Response was not in the signed envelope shape — not verified.";
    let metadata = null;
    if (analysis && typeof analysis === "object" && analysis.data && analysis.metadata) {
      data = analysis.data;
      metadata = analysis.metadata;
      const result = verifyPlanetekSignature(analysis);
      signatureVerified = result.verified;
      signatureNote = result.verified
        ? "Signature verified."
        : `Signature NOT verified: ${result.reason}`;
    }

    logger.info(
      `planetek.run: done in ${Date.now() - requestStart}ms total, ` +
        `certified=${data.deforestation_certified}, signatureVerified=${signatureVerified}`
    );

    return {
      aoi: data.aoi ?? null,
      deforestationCertified: data.deforestation_certified ?? null,
      forestArea2020Ha: data.forest_area_2020_ha ?? null,
      deforestedAreaHa: data.deforested_area_ha ?? null,
      deforestedPercentage: data.deforested_percentage ?? null,
      algorithmVersion: metadata ? metadata.algorithm_version ?? null : null,
      deploymentVersion: metadata ? metadata.deployment_version ?? null : null,
      deploymentId: metadata ? metadata.deployment_id ?? null : null,
      flowRunId,
      signatureVerified,
      signatureNote,
    };
  }
);

// ── EUDR Due Diligence Statement (DDS) — exporter handoff package ───────
//
// JV Almacis is NOT a TRACES participant. It never registers with TRACES,
// never holds TRACES credentials, and never submits anything to the EU's
// Information System — that is entirely the exporter's own process, on
// the exporter's own TRACES account (or their own chosen authorised
// representative), invisible to this codebase. See docs/planetek_eudr/
// and the TRACES integration notes for the full reasoning.
//
// What JV Almacis DOES do is generate the evidence handoff package an
// exporter needs for their own filing — plot geolocation
// (TracesDdsExportService's FeatureCollection, built client-side) plus
// operator/commodity data, shaped to (approximately) match what a DDS
// requires. This function just assembles and returns that package; it
// makes no network calls and needs no secrets, because there is nothing
// external to authenticate against — the exporter is the one who takes
// this and enters/imports it into their own TRACES account.
//
// UNVERIFIED CAVEAT: the exact field names/structure below are assembled
// from Planetek's tutorial plus public EUDR/TRACES documentation (blog
// posts, a third-party Node client's example payload) — NOT the
// authoritative CIRCABC API spec (which only the exporter, as a
// registered TRACES operator, can access). Treat this as a best-current
// draft of "what a DDS needs," useful for a human to review or an
// exporter's own system to consume — not a guaranteed-correct schema.

function buildEudrDdsPayload({ featureCollection, operator, commodity }) {
  return {
    statement: {
      internalReferenceNumber: `coffeecore-${Date.now()}`,
      activityType: "EXPORT",
      countryOfActivity: (operator && operator.country) || null,
      // Per the third-party TRACES client example: whether geolocation is
      // withheld from downstream lookups. Defaulting to visible (false) —
      // revisit once the real spec confirms this is even the right field.
      geoLocationConfidential: false,
    },
    operator: {
      eori: (operator && operator.eori) || null,
      name: (operator && operator.name) || null,
      address: (operator && operator.address) || null,
      country: (operator && operator.country) || null,
    },
    commodity: {
      hsHeading: (commodity && commodity.hsCode) || null,
      description: (commodity && commodity.tradeName) || "Coffee",
      descriptors: {
        deforestationBaseline: "2020-12-31",
      },
    },
    geolocation: featureCollection || null,
    // Upstream DDS reference/verification numbers this statement builds
    // on (plot → cooperative → exporter chaining) — always empty until a
    // real upstream DDS has actually been filed and its numbers recorded
    // via DdsExportBatchService.recordSubmission.
    associatedStatements: [],
  };
}

exports.generateEudrDdsHandoffPackage = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Sign in to generate a Due Diligence Statement handoff package."
      );
    }

    const { featureCollection, operator, commodity } = request.data || {};
    if (!featureCollection || featureCollection.type !== "FeatureCollection") {
      throw new HttpsError(
        "invalid-argument",
        "featureCollection must be a valid GeoJSON FeatureCollection."
      );
    }

    const payload = buildEudrDdsPayload({ featureCollection, operator, commodity });

    return {
      package: payload,
      submittedByJvAlmacis: false,
      note:
        "This is an evidence handoff package for the exporter's own TRACES " +
        "filing — JV Almacis does not submit to TRACES itself. Field names " +
        "are a best-current draft pending confirmation against the " +
        "exporter's own CIRCABC API spec access.",
    };
  }
);

// ---------------------------------------------------------------------------
// Community feature — enforce "only one accepted answer per question"
// server-side. The Flutter client (CommunityRepositoryImpl.markAcceptedSolution)
// sets accepted_comment_id on the post and is_accepted_solution on the new
// comment directly, but has no way to safely clear the flag on whichever
// comment was PREVIOUSLY accepted (that doc's id isn't necessarily known to
// the client at that point, and a security-rule-scoped client write can't
// reach into an arbitrary other comment doc). This trigger does that part.
// ---------------------------------------------------------------------------
exports.onCommunityPostUpdated = onDocumentUpdated(
  "community_posts/{postId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    if (!before || !after) return;

    const previousAcceptedId = before.accepted_comment_id;
    const newAcceptedId = after.accepted_comment_id;

    if (!previousAcceptedId || previousAcceptedId === newAcceptedId) {
      return;
    }

    await db()
      .collection("community_comments")
      .doc(previousAcceptedId)
      .update({ is_accepted_solution: false });
  }
);

// ---------------------------------------------------------------------------
// Follow-up reminder push notifications
//
// The Flutter client already schedules a LOCAL on-device notification the
// moment an intervention is logged (see _scheduleFollowUpReminder in
// coffee_intervention_page.dart / coffee_disease_intervention_page.dart) —
// that fires even while the app is backgrounded or closed, using the
// device's own OS scheduler. What it can't do is guarantee delivery once the
// exact-alarm permission is revoked, the device reboots, or the app is
// force-stopped — and it has no concept of "only when the device is online",
// which is specifically what push exists for. This scheduled function is
// the reliability backstop: it runs hourly, finds interventions whose
// 1-week follow-up is due and hasn't been pushed yet, and sends an FCM
// message to every device token registered for that farmer. It intentionally
// does NOT touch/cancel the local notification — both firing is fine.
// ---------------------------------------------------------------------------

const FOLLOWUP_COLLECTIONS = [
  {
    name: "coffee_pest_interventions",
    type: "pest_followup",
    completedField: "followUpCompleted",
    pushSentField: "followUpPushSent",
    dueAtField: "followUpDueAt",
    buildMessage: (data) => ({
      title: `Time to check on ${data.pestName || "your crop"}`,
      body: "It's been a week — see how your crop responded and log the outcome.",
    }),
  },
  {
    name: "coffee_disease_interventions",
    type: "disease_followup",
    completedField: "followUpCompleted",
    pushSentField: "followUpPushSent",
    dueAtField: "followUpDueAt",
    buildMessage: (data) => ({
      title: `Time to check on ${data.diseaseName || "your crop"}`,
      body: "It's been a week — see how your crop responded and log the outcome.",
    }),
  },
  {
    name: "fertilization_weeks",
    type: "fertilizer_followup",
    completedField: "completed",
    pushSentField: "pushSent",
    dueAtField: "dueAt",
    buildMessage: (data) => ({
      title: `Week ${data.weekNumber || ""} fertilization due`,
      body: `${data.action || "Scheduled application"} — ${data.product || ""}`,
    }),
  },
];

async function sendFollowUpPush(userId, title, body, data) {
  const userDoc = await db().collection("Users").doc(userId).get();
  const tokens = (userDoc.exists && userDoc.data().fcmTokens) || [];
  if (!Array.isArray(tokens) || tokens.length === 0) {
    logger.info(`followupReminders: no fcmTokens for user ${userId}, skipping push`);
    return;
  }

  const response = await fcm().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data,
    android: { priority: "high" },
  });

  const deadTokens = [];
  response.responses.forEach((r, i) => {
    if (!r.success) {
      const code = r.error && r.error.code;
      if (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-argument"
      ) {
        deadTokens.push(tokens[i]);
      } else {
        logger.warn(`followupReminders: send failed for a token of ${userId}: ${code}`);
      }
    }
  });

  if (deadTokens.length > 0) {
    await db()
      .collection("Users")
      .doc(userId)
      .update({ fcmTokens: FieldValue.arrayRemove(...deadTokens) });
    logger.info(`followupReminders: pruned ${deadTokens.length} dead token(s) for ${userId}`);
  }
}

exports.sendFollowUpReminders = onSchedule(
  { schedule: "every 60 minutes", region: "us-central1" },
  async () => {
    const now = Timestamp.now();

    for (const collectionConfig of FOLLOWUP_COLLECTIONS) {
      const { name, type, completedField, pushSentField, dueAtField, buildMessage } =
        collectionConfig;
      const snapshot = await db()
        .collection(name)
        .where(completedField, "==", false)
        .where(pushSentField, "==", false)
        .where(dueAtField, "<=", now)
        .get();

      logger.info(`followupReminders: ${snapshot.size} due in ${name}`);

      for (const doc of snapshot.docs) {
        const data = doc.data();
        const userId = data.userId;
        if (!userId) continue;

        const { title, body } = buildMessage(data);

        try {
          await sendFollowUpPush(userId, title, body, {
            type,
            interventionId: doc.id,
            collection: name,
          });
        } catch (err) {
          logger.error(`followupReminders: push failed for ${name}/${doc.id}: ${err}`);
        }

        // Mark attempted regardless of outcome — prevents an unreachable
        // user (no tokens, or a persistent send error) from being re-queried
        // and retried every single hour indefinitely.
        await doc.ref.update({ [pushSentField]: true });
      }
    }
  }
);
