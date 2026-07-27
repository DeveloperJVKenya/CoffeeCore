#!/usr/bin/env python3
"""Verify a signed deforestation-analysis result.

Saved verbatim from Planetek's P26B3800_EUDR_Check_API.zip (download link
sent 2026-07-25, expires ~2026-08-01) so it survives after that link dies.
This file is reference only — it is NOT executed by the app or by Cloud
Functions. The equivalent verification logic used in production lives in
functions/index.js (verifyPlanetekSignature / canonicalJson), ported to
Node so it can run server-side inside runPlanetekDeforestationAnalysis
without shelling out to Python. See docs/planetek_eudr/README.md.
"""

from __future__ import annotations

import argparse
import base64
import binascii
import hashlib
import hmac
import json
import sys
from pathlib import Path
from typing import Any

# Be sure to install cryptography==46.0.3 first
from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey


DEFAULT_PUBLIC_KEY = "ESk6chNPFPIx-pySnrHxoDVFJjvelQZ-RM7UhdyRuDo="
DEFAULT_FINGERPRINT = "955f2fa5090b49826feb221df76a1e710a6abe660161e4ca2badd146ef0e3a4d"
DEFAULT_PAYLOAD: dict[str, Any] = {
    "data": {
        "aoi": "aoi",
        "deforestation_certified": True,
        "forest_area_2020_ha": 362.4,
        "deforested_area_ha": 6.49,
        "deforested_percentage": 1.791,
    },
    "metadata": {
        "deployment_id": "a089937c-5ba9-43be-8ef0-afe59c16c1bb",
        "deployment_version": "0.2.1",
        "algorithm_version": "0.2.1",
        "signature_algorithm": "ed25519-sha256",
        "signature": "nAYbHpAq0MhJW4HTxwKxM04JsKjTqP7WPTjVZpNlxg1iSbuuQs2dXGngOQ9aTg0Wmf4f0JQJZG9ThELsdUIODg==",
        "public_key_fingerprint": "955f2fa5090b49826feb221df76a1e710a6abe660161e4ca2badd146ef0e3a4d",
    },
}

SIGNED_METADATA_FIELDS = (
    "deployment_id",
    "deployment_version",
    "algorithm_version",
)


class VerificationError(ValueError):
    """Raised when a payload cannot be verified."""


def _urlsafe_b64decode(value: str, field_name: str) -> bytes:
    try:
        return base64.b64decode(value, altchars=b"-_", validate=True)
    except (binascii.Error, ValueError) as exc:
        raise VerificationError(f"{field_name} is not valid URL-safe base64") from exc


def verify_payload(
    payload: dict[str, Any],
    public_key_b64: str = DEFAULT_PUBLIC_KEY,
    expected_fingerprint: str = DEFAULT_FINGERPRINT,
) -> None:
    """Verify the key fingerprint and Ed25519 signature.

    Raises VerificationError if any check fails.
    """
    try:
        data = payload["data"]
        metadata = payload["metadata"]
        signature_algorithm = metadata["signature_algorithm"]
        signature_b64 = metadata["signature"]
        payload_fingerprint = metadata["public_key_fingerprint"]
        signed_metadata = {field: metadata[field] for field in SIGNED_METADATA_FIELDS}
    except (KeyError, TypeError) as exc:
        raise VerificationError(f"payload is missing required field: {exc}") from exc

    if signature_algorithm != "ed25519-sha256":
        raise VerificationError(
            f"unsupported signature algorithm: {signature_algorithm!r}"
        )

    public_key_bytes = _urlsafe_b64decode(public_key_b64, "public key")
    if len(public_key_bytes) != 32:
        raise VerificationError("Ed25519 public key must be exactly 32 bytes")

    calculated_fingerprint = hashlib.sha256(public_key_bytes).hexdigest()
    if not hmac.compare_digest(calculated_fingerprint, expected_fingerprint):
        raise VerificationError(
            "the supplied public key does not match the expected fingerprint"
        )
    if not hmac.compare_digest(payload_fingerprint, expected_fingerprint):
        raise VerificationError(
            "the payload fingerprint does not match the expected fingerprint"
        )

    signed_bytes = json.dumps(
        {"data": data, "metadata": signed_metadata},
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
    ).encode("utf-8")
    signature = _urlsafe_b64decode(signature_b64, "signature")

    try:
        Ed25519PublicKey.from_public_bytes(public_key_bytes).verify(
            signature, signed_bytes
        )
    except InvalidSignature as exc:
        raise VerificationError("invalid signature") from exc


def _read_payload(path: str | None) -> dict[str, Any]:
    if path is None:
        return DEFAULT_PAYLOAD
    if path == "-":
        return json.load(sys.stdin)
    with Path(path).open(encoding="utf-8") as payload_file:
        return json.load(payload_file)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Verify a signed deforestation-analysis JSON payload."
    )
    parser.add_argument(
        "payload",
        nargs="?",
        help="JSON payload file; omit to use the embedded payload, or use '-' for stdin",
    )
    parser.add_argument(
        "--public-key",
        default=DEFAULT_PUBLIC_KEY,
        help="URL-safe-base64 raw Ed25519 public key",
    )
    parser.add_argument(
        "--fingerprint",
        default=DEFAULT_FINGERPRINT,
        help="expected SHA-256 fingerprint of the raw public key",
    )
    args = parser.parse_args()

    try:
        verify_payload(
            _read_payload(args.payload),
            public_key_b64=args.public_key,
            expected_fingerprint=args.fingerprint,
        )
    except (OSError, json.JSONDecodeError, VerificationError) as exc:
        print(f"Verification failed: {exc}", file=sys.stderr)
        return 1

    print("Signature is valid.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
