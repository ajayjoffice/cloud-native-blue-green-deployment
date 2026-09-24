import os

from fastapi import FastAPI
from pydantic import BaseModel, Field

VERSION = os.getenv("APP_VERSION", "v1.0.0")
app = FastAPI(title="Blue-Green Demo API", version=VERSION)


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


@app.post("/greet")
def greet(request: GreetingRequest) -> dict[str, str]:
    return {"message": f"Hello, {request.name}!", "version": VERSION}
