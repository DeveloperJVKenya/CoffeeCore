const { onRequest } = require("firebase-functions/v2/https");

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
