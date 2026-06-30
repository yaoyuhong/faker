"""FastAPI entrypoint — v0.1 stub with mock analysis."""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Any

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

app = FastAPI(title="CourtLog CV API", version="0.1.0")

# In-memory job store (replace with Redis + worker)
_JOBS: dict[str, dict[str, Any]] = {}
_SESSIONS: dict[str, dict[str, Any]] = {}


class Point2D(BaseModel):
    x: float
    y: float


class Calibration(BaseModel):
    image_points: list[Point2D] = Field(..., min_length=4, max_length=4, alias="imagePoints")
    court_points_meters: list[Point2D] = Field(
        ..., min_length=4, max_length=4, alias="courtPointsMeters"
    )

    model_config = {"populate_by_name": True}


class HealthSummary(BaseModel):
    avg_heart_rate: float | None = Field(None, alias="avgHeartRate")
    max_heart_rate: float | None = Field(None, alias="maxHeartRate")
    active_calories: float | None = Field(None, alias="activeCalories")
    duration_sec: float | None = Field(None, alias="durationSec")

    model_config = {"populate_by_name": True}


class CreateSessionRequest(BaseModel):
    calibration: Calibration
    health: HealthSummary | None = None
    device_id: str | None = Field(None, alias="deviceId")

    model_config = {"populate_by_name": True}


class CreateSessionResponse(BaseModel):
    session_id: uuid.UUID = Field(..., alias="sessionId")
    upload_url: str = Field(..., alias="uploadUrl")

    model_config = {"populate_by_name": True}


class JobResponse(BaseModel):
    job_id: uuid.UUID = Field(..., alias="jobId")

    model_config = {"populate_by_name": True}


class AnalysisResult(BaseModel):
    ball_positions: list[dict[str, float]] = Field(default_factory=list, alias="ballPositions")
    bounces: list[dict[str, Any]] = Field(default_factory=list)
    heatmap: dict[str, Any] = Field(default_factory=dict)
    max_speed_kmh: float = Field(0, alias="maxSpeedKmh")
    avg_speed_kmh: float = Field(0, alias="avgSpeedKmh")
    preview_url: str | None = Field(None, alias="previewUrl")

    model_config = {"populate_by_name": True}


class JobStatus(BaseModel):
    status: str
    progress: float
    error: str | None = None
    result: AnalysisResult | None = None


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/v1/sessions", response_model=CreateSessionResponse, status_code=201)
def create_session(body: CreateSessionRequest) -> CreateSessionResponse:
    session_id = uuid.uuid4()
    _SESSIONS[str(session_id)] = {
        "calibration": body.calibration.model_dump(by_alias=True),
        "health": body.health.model_dump(by_alias=True) if body.health else None,
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    # MVP: local upload endpoint placeholder
    upload_url = f"http://localhost:8000/v1/sessions/{session_id}/upload"
    return CreateSessionResponse(session_id=session_id, upload_url=upload_url)


@app.post("/v1/sessions/{session_id}/analyze", response_model=JobResponse, status_code=202)
def start_analysis(session_id: uuid.UUID) -> JobResponse:
    if str(session_id) not in _SESSIONS:
        raise HTTPException(status_code=404, detail="session not found")

    job_id = uuid.uuid4()
    _JOBS[str(job_id)] = {
        "session_id": str(session_id),
        "status": "done",
        "progress": 1.0,
        "result": _mock_analysis(),
    }
    return JobResponse(job_id=job_id)


@app.get("/v1/jobs/{job_id}", response_model=JobStatus)
def get_job(job_id: uuid.UUID) -> JobStatus:
    job = _JOBS.get(str(job_id))
    if not job:
        raise HTTPException(status_code=404, detail="job not found")
    return JobStatus(
        status=job["status"],
        progress=job["progress"],
        error=job.get("error"),
        result=AnalysisResult(**job["result"]) if job.get("result") else None,
    )


def _mock_analysis() -> dict[str, Any]:
    """Replace with pipeline.run() when TrackNet weights are available."""
    grid = 10
    counts = [[0] * grid for _ in range(grid * 2)]
    counts[8][4] = 5
    counts[9][5] = 3
    counts[12][3] = 7
    return {
        "ballPositions": [{"t": 1.2, "x": 4.1, "y": 12.3}],
        "bounces": [{"t": 1.25, "x": 4.1, "y": 12.3, "in": True, "speedKmh": 72.5}],
        "heatmap": {"grid": grid, "counts": counts},
        "maxSpeedKmh": 98.2,
        "avgSpeedKmh": 61.4,
        "previewUrl": None,
    }
