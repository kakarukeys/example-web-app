"""Minimal hello-world Streamlit application."""

import os
from typing import Final

import streamlit as st

DEFAULT_VERSION: Final[str] = "development version"


def get_app_version() -> str:
    """Return the version injected at image build time."""
    return os.getenv("APP_VERSION", DEFAULT_VERSION)


def main() -> None:
    """Render the page."""
    st.set_page_config(page_title="Hello World", page_icon="👋")
    st.title("Hello, world 👋")
    st.write("This is a minimal Streamlit application.")
    st.caption(f"version: {get_app_version()}")


if __name__ == "__main__":
    main()
