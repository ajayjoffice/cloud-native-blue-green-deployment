import os
from pathlib import Path
import re

from fastapi import FastAPI, Request
from pydantic import BaseModel, Field
from fastapi.responses import FileResponse

VERSION = os.getenv("APP_VERSION", "v1.0.0")
app = FastAPI(title="Blue-Green Demo API", version=VERSION)
STATIC_DIR = Path(__file__).parent / "static"


class GreetingRequest(BaseModel):
    name: str = Field(min_length=1, max_length=80)


@app.get("/")
def root() -> dict[str, str]:
    return {"application": "cloud-native-blue-green", "version": VERSION}


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "version": VERSION}


@app.get("/version")
def version() -> dict[str, str]:
    return {"version": VERSION}


@app.get("/dashboard", include_in_schema=False)
def dashboard() -> FileResponse:
    return FileResponse(STATIC_DIR / "dashboard.html")


@app.get("/deployment/status")
def deployment_status(request: Request) -> dict[str, str | None]:
    upstream = request.headers.get("x-deployment-upstream", "")
    slot = os.getenv("DEPLOYMENT_SLOT")
    if slot not in {"blue", "green"}:
        slot = None
    if re.search(r"(?:blue|:8001)(?:$|,)", upstream):
        slot = "blue"
    elif re.search(r"(?:green|:8002)(?:$|,)", upstream):
        slot = "green"
    return {
        "application": "cloud-native-blue-green",
        "version": VERSION,
        "health": "healthy",
        "active_slot": slot,
        "upstream": upstream or None,
    }


@app.post("/greet")
def greet(request: GreetingRequest) -> dict[str, str]:
    return {"message": f"Hello, {request.name}!", "version": VERSION}
