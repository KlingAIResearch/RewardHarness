"""Unit tests for the model-id mismatch detection in scripts/check_env.py.

The interesting behaviour added in iter 130 is `_probe_one` parsing the
`/v1/models` response body so the calling `check_endpoints` can compare
the served model against `REWARDHARNESS_SUBAGENT_MODEL`. Locked in here.
"""
import importlib.util
import json
import sys
from io import BytesIO
from pathlib import Path
from unittest.mock import patch

SCRIPT_PATH = Path(__file__).resolve().parent.parent / "scripts" / "check_env.py"


def _load_check_env():
    """Import scripts/check_env.py as a module without executing main()."""
    spec = importlib.util.spec_from_file_location("check_env", SCRIPT_PATH)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class _FakeResponse:
    def __init__(self, body, status=200):
        self._body = body if isinstance(body, bytes) else json.dumps(body).encode()
        self.status = status

    def __enter__(self):
        return self

    def __exit__(self, *_):
        return False

    def read(self):
        return self._body


class TestProbeOne:

    def test_returns_served_id_on_200(self):
        mod = _load_check_env()
        body = {"data": [{"id": "my-vlm-7b"}]}
        with patch("urllib.request.urlopen", return_value=_FakeResponse(body)):
            url, err, served = mod._probe_one("http://x/v1", timeout=1.0)
        assert err == ""
        assert served == "my-vlm-7b"

    def test_empty_served_id_on_malformed_body(self):
        mod = _load_check_env()
        with patch("urllib.request.urlopen", return_value=_FakeResponse(b"not json")):
            url, err, served = mod._probe_one("http://x/v1", timeout=1.0)
        # HTTP 200 but body unparseable: status_line is empty (probe succeeded)
        # and served_model is empty (couldn't extract id).
        assert err == ""
        assert served == ""

    def test_empty_served_id_on_missing_data_field(self):
        mod = _load_check_env()
        with patch("urllib.request.urlopen", return_value=_FakeResponse({"foo": "bar"})):
            url, err, served = mod._probe_one("http://x/v1", timeout=1.0)
        assert err == ""
        assert served == ""

    def test_non_200_returns_status_line(self):
        mod = _load_check_env()
        with patch("urllib.request.urlopen", return_value=_FakeResponse({}, status=500)):
            url, err, served = mod._probe_one("http://x/v1", timeout=1.0)
        assert "HTTP 500" in err
        assert served == ""
