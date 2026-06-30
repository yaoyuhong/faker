"""API and pipeline tests."""

import numpy as np
from fastapi.testclient import TestClient

from app.homography import compute_homography, image_to_court
from app.main import app
from app.pipeline import run_pipeline


client = TestClient(app)


def test_homography_identity_corners():
    image = np.array([[0, 0], [100, 0], [100, 200], [0, 200]], dtype=np.float64)
    court = np.array([[0, 0], [8.23, 0], [8.23, 23.77], [0, 23.77]], dtype=np.float64)
    h = compute_homography(image, court)
    x, y = image_to_court(h, 50, 100)
    assert 3.5 < x < 4.5
    assert 10 < y < 12


def test_health_endpoint():
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"


def test_session_analyze_flow_without_video(tmp_path):
    # Create session
    cal = {
        "calibration": {
            "imagePoints": [
                {"x": 0, "y": 0},
                {"x": 640, "y": 0},
                {"x": 640, "y": 360},
                {"x": 0, "y": 360},
            ],
            "courtPointsMeters": [
                {"x": 0, "y": 0},
                {"x": 8.23, "y": 0},
                {"x": 8.23, "y": 23.77},
                {"x": 0, "y": 23.77},
            ],
        }
    }
    create = client.post("/v1/sessions", json=cal)
    assert create.status_code == 201
    session_id = create.json()["sessionId"]

    # Upload tiny fake mp4 bytes — pipeline uses synthetic track without weights
    fake_video = tmp_path / "fake.mp4"
    fake_video.write_bytes(b"\x00" * 128)
    upload = client.put(
        f"/v1/sessions/{session_id}/upload",
        files={"file": ("video.mp4", fake_video.read_bytes(), "video/mp4")},
    )
    assert upload.status_code == 200

    analyze = client.post(f"/v1/sessions/{session_id}/analyze")
    assert analyze.status_code == 202
    job_id = analyze.json()["jobId"]

    job = client.get(f"/v1/jobs/{job_id}")
    assert job.status_code == 200
    body = job.json()
    assert body["status"] in {"done", "running", "failed", "pending"}


def test_pipeline_synthetic(tmp_path):
    video = tmp_path / "v.mp4"
    video.write_bytes(b"fake")
    result = run_pipeline(
        video_path=video,
        image_points=[(0, 0), (640, 0), (640, 360), (0, 360)],
        court_points=[(0, 0), (8.23, 0), (8.23, 23.77), (0, 23.77)],
        weights_path=None,
    )
    assert "heatmap" in result
    assert result["meta"]["tracknet"] is False
    assert len(result["ballPositions"]) > 0
