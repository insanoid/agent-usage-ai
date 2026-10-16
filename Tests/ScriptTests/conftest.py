"""Load bin/agent-usage as a module; it has no .py extension."""

import importlib.machinery
import importlib.util
from pathlib import Path

import pytest

SCRIPT = Path(__file__).resolve().parents[2] / "bin" / "agent-usage"


@pytest.fixture(scope="session")
def au():
    loader = importlib.machinery.SourceFileLoader("agent_usage", str(SCRIPT))
    spec = importlib.util.spec_from_loader("agent_usage", loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module
