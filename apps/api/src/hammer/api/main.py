"""Application FastAPI. Lancer avec `make dev` (http://localhost:8000/docs)."""

from fastapi import FastAPI

from hammer import __version__

app = FastAPI(title="POK marteau", version=__version__)


@app.get("/health")
def health() -> dict[str, str]:
    """Sonde de vie : sert au front et à Docker Compose."""
    return {"status": "ok", "version": __version__}
