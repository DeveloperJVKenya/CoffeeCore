# Planetek EUDR Certified Deforestation Analysis — integration notes

Second, independent EUDR deforestation check, added alongside the existing
Global Forest Watch screening (`eudr_compliance_service.dart`), not
replacing it. Source tutorial: `EUDR_Tutorial_v1.0.pdf`, sent by Planetek
2026-07-25 along with `P26B3800_EUDR_Check_API.zip` (download link expires
~2026-08-01 — `check_signature_reference.py` in this folder is a saved copy
of that zip's script so the repo doesn't depend on the link staying alive).

## Credential status (updated 2026-07-27 — LIVE)

| Item | Status |
|---|---|
| `clientId` | `05742eee-d030-4555-8971-c873b0ee3374` — set in Secret Manager |
| `clientSecret` | Received 2026-07-27, set in Secret Manager, deployed |
| Ed25519 public key / fingerprint | Confirmed correct against a real live signed response (below) |
| Deployment name | `deforestation-analysis/deforestation-analysis` → resolves to `a089937c-5ba9-43be-8ef0-afe59c16c1bb` (v0.2.1) |

`runPlanetekDeforestationAnalysis` is deployed
(`us-central1-coffeecore-7111a.cloudfunctions.net/runPlanetekDeforestationAnalysis`)
with both secrets attached, and an unauthenticated smoke call confirms it's
live and correctly auth-gated.

### End-to-end live validation (2026-07-27)

Before deploying, ran the full chain by hand against Planetek's real API
using the tutorial's own sample Ecuador AOI (not through the Cloud
Function — direct `curl`, to validate the credentials and the API shape
independently of our code):

- Token exchange: succeeded.
- Deployment lookup: succeeded — `deployment_id` came back as
  `a089937c-5ba9-43be-8ef0-afe59c16c1bb`, **exactly matching** the sample
  payload's `metadata.deployment_id` in `check_signature_reference.py`.
  Confirms the sample/public key belongs to this real deployment. Live
  version is `0.2.1` (tutorial's "v0.3.0" in the General Info table was
  simply stale — not a real discrepancy).
- Flow run: submitted with the tutorial's Ecuador polygon, polled through
  `SCHEDULED → PENDING → RUNNING → COMPLETED` in ~85 seconds.
- Result values exactly matched the tutorial's own documented example:
  `forest_area_2020_ha: 362.24`, `deforested_area_ha: 6.45`,
  `deforested_percentage: 1.781`, `deforestation_certified: true`.
- **Response shape confirmed**: the real `state.message` decodes to the
  signed envelope (`{"data": {...}, "metadata": {...signature...}}`), not
  the flatter shape shown in the tutorial's illustrative examples — the
  defensive fallback in `runPlanetekDeforestationAnalysis` for the flat
  shape is now known to be a belt-and-suspenders case, not the common path.
- **Signature verification confirmed on a real (non-sample) signature**:
  ran the exact `canonicalJson`/`verifyPlanetekSignature` logic from
  `functions/index.js` against this live response and it returned
  `verified: true`. This closes out the biggest open risk from the earlier
  analysis (Python/Node JSON-canonicalization mismatch) — proven against
  live data, not just the bundled sample.

All four items previously listed as open risks are now resolved except the
poll-loop time cap (item 4 below), which remains a reasonable simplification
for a demo given the observed ~85s run time.

## What was built

- `functions/index.js` — `runPlanetekDeforestationAnalysis` (callable):
  owns the entire token exchange → deployment lookup → submit flow run →
  poll → fetch → **server-side signature verification** → return, so the
  `clientId`/`clientSecret` and the verification logic never reach the
  Flutter client. Follows the same secret-handling shape as the existing
  Sentinel Hub OAuth integration in the same file.
- `lib/screens/Farm Management/models/planetek_analysis_model.dart` —
  result model (`PlanetekAnalysisData`), stored on `FarmPolygon.planetekAnalysis`
  alongside (not replacing) `eudrCompliance`.
- `lib/screens/Farm Management/services/planetek_deforestation_service.dart` —
  builds the GeoJSON `FeatureCollection`/`MultiPolygon` from a farm's
  `List<LatLng>` boundary and calls the callable.
- `lib/screens/Farm Management/providers/planetek_eudr_provider.dart` +
  `widgets/planetek_analysis_card.dart` — UI wiring, added to the existing
  EUDR tab under a "Certified Analysis (Planetek)" section, separate from
  the GFW screening card above it.

## Setup steps — already done

```bash
firebase functions:secrets:set PLANETEK_CLIENT_ID        # done 2026-07-27
firebase functions:secrets:set PLANETEK_CLIENT_SECRET    # done 2026-07-27
firebase deploy --only functions:runPlanetekDeforestationAnalysis  # done 2026-07-27
```

Kept here for reference (e.g. rotating the secret later, or redeploying
after algorithm/API changes).

## Remaining risk

1. **HTTP vs HTTPS.** The tutorial mixes `https://` (deployment lookup) and
   `http://` (flow run polling) for the same host. The live smoke test
   above went through `https://` for both successfully, and the Cloud
   Function tries `https://` first (falling back to `http://`, caching
   whichever responds) — so this is now low-risk, but flagged in case
   Planetek's `http://` flow-run host ever behaves differently under load.
2. Poll loop is capped at ~4 minutes (48 × 5s) inside a single
   `onCall` invocation (`timeoutSeconds: 300`). The live smoke test
   completed in ~85s, well within that cap, but if a larger real farm
   polygon runs long, this needs to move to an async Firestore-job pattern
   instead of a single blocking call — deliberately deferred given the
   1-week demo scope.
