import os

os.environ["APP_TOKEN"] = "test"
os.environ.setdefault("GROQ_API_KEY", "test-key")

import pytest
from fastapi.testclient import TestClient


@pytest.fixture
def client():
    from app.main import app
    return TestClient(app)


@pytest.fixture
def auth():
    return {"Authorization": "Bearer test"}


@pytest.fixture(autouse=True)
def drossel_frisch():
    """Jeder Test beginnt mit leeren Zählern, sonst sperrt die Drossel spätere Tests."""
    from app import main
    main.DROSSEL.zuruecksetzen()
    yield
