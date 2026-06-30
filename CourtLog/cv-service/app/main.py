"""FastAPI entrypoint — upload, background analysis, job polling."""

from __future__ import annotations

import logging
import shutil
import uuid
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from fastapi import BackgroundTasks, FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from app.config import SESSIONS_DIR, TRACKNET_WEIGHTS
from app.pipeline import run_pipeline

logger = logging.getLogger(__name__)

app = FastAPI(title="CourtLog CV API", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

_EXECUTOR = ThreadPoolExecutor(max_workers=2)
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
    meta: dict[str, Any] | None = None

    model_config = {"populate_by_name": True}


class JobStatus(BaseModel):
    status: str
    progress: float
    error: str | None = None
    result: AnalysisResult | None = None


def _session_dir(session_id: str) -> Path:
    path = SESSIONS_DIR / session_id
    path.mkdir(parents=True, exist_ok=True)
    return path


def _video_path(session_id: str) -> Path:
    return _session_dir(session_id) / "video.mp4"


@app.get("/health")
def health() -> dict[str, Any]:
    return {
        "status": "ok",
        "tracknet_weights": TRACKNET_WEIGHTS.exists(),
    }


@app.post("/v1/sessions", response_model=CreateSessionResponse, status_code=201)
def create_session(body: CreateSessionRequest, base_url: str = "http://localhost:8000") -> CreateSessionResponse:
    session_id = uuid.uuid4()
    sid = str(session_id)
    _SESSIONS[sid] = {
        "calibration": body.calibration.model_dump(by_alias=True),
        "health": body.health.model_dump(by_alias=True) if body.health else None,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "uploaded": False,
    }
    _session_dir(sid)
    upload_url = f"{base_url}/v1/sessions/{session_id}/upload"
    return CreateSessionResponse(session_id=session_id, upload_url=upload_url)


@app.put("/v1/sessions/{session_id}/upload")
async def upload_video(session_id: uuid.UUID, file: UploadFile = File(...)) -> dict[str, str]:
    sid = str(session_id)
    if sid not in _SESSIONS:
        raise HTTPException(status_code=404, detail="session not found")

    dest = _video_path(sid)
    with dest.open("wb") as out:
        shutil.copyfileobj(file.file, out)

    _SESSIONS[sid]["uploaded"] = True
    _SESSIONS[sid]["video_path"] = str(dest)
    return {"status": "uploaded", "sessionId": sid}


@app.post("/v1/sessions/{session_id}/analyze", response_model=JobResponse, status_code=202)
def start_analysis(session_id: uuid.UUID, background_tasks: BackgroundTasks) -> JobResponse:
    sid = str(session_id)
    session = _SESSIONS.get(sid)
    if not session:
        raise HTTPException(status_code=404, detail="session not found")
    if not session.get("uploaded") and not _video_path(sid).exists():
        raise HTTPException(status_code=400, detail="video not uploaded")

    job_id = uuid.uuid4()
    jid = str(job_id)
    _JOBS[jid] = {
        "session_id": sid,
        "status": "pending",
        "progress": 0.0,
        "result": None,
        "error": None,
    }
    background_tasks.add_task(_run_analysis, jid)
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


def _run_analysis(job_id: str) -> None:
    job = _JOBS[job_id]
    sid = job["session_id"]
    session = _SESSIONS[sid]
    job["status"] = "running"
    job["progress"] = 0.1

    try:
        calibration = session["calibration"]
        image_points = [(p["x"], p["y"]) for p in calibration["imagePoints"]]
        court_points = [(p["x"], p["y"]) for p in calibration["courtPointsMeters"]]
        video = Path(session.get("video_path", _video_path(sid)))

        job["progress"] = 0.3
        result = run_pipeline(
            video_path=video,
            image_points=image_points,
            court_points=court_points,
            weights_path=TRACKNET_WEIGHTS if TRACKNET_WEIGHTS.exists() else None,
        )
        job["progress"] = 1.0
        job["status"] = "done"
        job["result"] = result
    except Exception as exc:  # noqa: BLE001
        logger.exception("analysis failed for job %s", job_id)
        job["status"] = "failed"
        job["error"] = str(exc)
        job["progress"] = 1.0
