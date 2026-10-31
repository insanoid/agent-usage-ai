"""Load the unmodified collector from a wheel or an editable source checkout."""

from importlib.machinery import SourceFileLoader
from importlib.util import module_from_spec, spec_from_loader
from pathlib import Path
from types import ModuleType


def load_collector() -> ModuleType:
    """Use the bundled collector; editable installs use the repository original."""
    path = Path(__file__).with_name("_collector.py")
    if not path.is_file():
        path = Path(__file__).resolve().parents[2] / "bin" / "agent-usage"
    loader = SourceFileLoader("agent_usage._collector", str(path))
    spec = spec_from_loader(loader.name, loader)
    if spec is None:
        raise ImportError("Cannot load the bundled usage collector.")
    module = module_from_spec(spec)
    loader.exec_module(module)
    return module


collector = load_collector()
