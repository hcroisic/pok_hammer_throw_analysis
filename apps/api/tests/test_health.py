from fastapi.testclient import TestClient

from hammer.__main__ import main
from hammer.api.main import app


def test_health_repond_ok_quand_api_demarree() -> None:
    client = TestClient(app)

    response = client.get("/health")

    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_cli_affiche_aide_quand_aucune_commande() -> None:
    assert main([]) == 0
