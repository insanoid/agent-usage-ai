"""Authenticated read-only HTTP access to cached subscription usage."""

from __future__ import annotations

import hmac
import stat
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from pathlib import Path

from starlette.applications import Starlette
from starlette.concurrency import run_in_threadpool
from starlette.requests import Request
from starlette.responses import JSONResponse
from starlette.routing import Route

from agent_usage.snapshot import CollectionWorker, SnapshotStore

MIN_TOKEN_LENGTH = 32


def read_token(path: Path) -> str:
    """Read a private bearer token file, rejecting weak tokens and public files."""
    info = path.stat()
    if not stat.S_ISREG(info.st_mode) or info.st_mode & 0o077:
        raise ValueError("API token file must be a regular file with mode 0600")
    token = path.read_text().strip()
    if len(token) < MIN_TOKEN_LENGTH or not token.isascii() or any(c.isspace() for c in token):
        raise ValueError("API token must contain at least 32 non-whitespace ASCII characters")
    return token


def create_app(
    store: SnapshotStore, token: str, worker: CollectionWorker | None = None
) -> Starlette:
    """Create the private API; endpoints only read already collected snapshots."""
    expected = f"Bearer {token}".encode()

    @asynccontextmanager
    async def lifespan(app: Starlette) -> AsyncIterator[None]:
        if worker is not None:
            worker.start()
        try:
            yield
        finally:
            if worker is not None:
                await run_in_threadpool(worker.stop)

    async def usage(request: Request) -> JSONResponse:
        headers = {"Cache-Control": "no-store"}
        supplied = request.headers.get("authorization", "").encode()
        if not hmac.compare_digest(supplied, expected):
            headers["WWW-Authenticate"] = "Bearer"
            return JSONResponse({"error": "Unauthorized"}, status_code=401, headers=headers)
        report = store.read()
        if report is None:
            return JSONResponse(
                {"error": "Usage is not available yet"}, status_code=503, headers=headers
            )
        if request.url.path == "/health":
            return JSONResponse({"status": "ready"}, headers=headers)
        return JSONResponse(report, headers=headers)

    return Starlette(routes=[Route("/v1/usage", usage), Route("/health", usage)], lifespan=lifespan)


def serve(config: Path, token_file: Path, snapshot: Path, port: int, free_resets: bool) -> None:
    """Serve only on loopback; Tailscale Serve supplies private HTTPS."""
    import uvicorn

    from agent_usage.service import UsageService

    token = read_token(token_file.expanduser())
    service = UsageService(config, free_resets=free_resets)
    store = SnapshotStore(snapshot.expanduser())
    worker = CollectionWorker(store, lambda: service.report(refresh=True))
    uvicorn.run(
        create_app(store, token, worker),
        host="127.0.0.1",
        port=port,
        access_log=False,
        proxy_headers=False,
    )
