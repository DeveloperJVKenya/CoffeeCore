const { onRequest } = require("firebase-functions/v2/https");
const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { defineSecret } = require("firebase-functions/params");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

// Lazy-initialized — NOT called at module load time. Firebase CLI's local
// deploy-time discovery step requires this file just to read the exported
// function declarations, without real Application Default Credentials
// available; an eager initializeApp() call stalls there trying to reach the
// GCE metadata server and blows past the CLI's 10s discovery timeout. Deferring
// this to first actual invocation means it only ever runs inside Cloud
// Functions itself, where ADC resolves immediately.
let firestoreDb;
function db() {
  if (!firestoreDb) {
    initializeApp();
    firestoreDb = getFirestore();
  }
  return firestoreDb;
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
