from pathlib import Path

import pytest
from streamlit.testing.v1 import AppTest

APP_PATH = Path(__file__).parents[1] / "app" / "app.py"


def test_app_renders(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("APP_VERSION", raising=False)

    app_test = AppTest.from_file(str(APP_PATH), default_timeout=30).run()

    assert not app_test.exception, [e.value for e in app_test.exception]
    assert app_test.title[0].value == "Hello, world 👋"
    assert app_test.markdown[0].value == "This is a minimal Streamlit application."
    assert app_test.caption[0].value == "version: development version"
