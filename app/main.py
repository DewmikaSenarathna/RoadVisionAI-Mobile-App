from __future__ import annotations

import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import joblib
import numpy as np
import requests
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field, field_validator

APP_DIR = Path(__file__).resolve().parent
ROOT_DIR = APP_DIR.parent
STATIC_DIR = ROOT_DIR / "static"
ARTIFACTS_DIR = ROOT_DIR / "artifacts"
ASSETS_DIR = ROOT_DIR / "assets"
MODEL_PATH = ARTIFACTS_DIR / "accident_model.pkl"
FEATURES_PATH = ARTIFACTS_DIR / "final_features.pkl"
PREPROCESSOR_PATH = ARTIFACTS_DIR / "preprocessor.pkl"
API_KEY = os.getenv("ROADVISIONAI_API_KEY", "").strip()
ALLOWED_ORIGINS = [origin.strip() for origin in os.getenv("ROADVISIONAI_CORS_ORIGINS", "http://localhost:5173,http://127.0.0.1:5173,http://localhost:3000,http://127.0.0.1:3000,http://localhost:8000").split(",") if origin.strip()]

app = FastAPI(
    title="RoadVisionAI Accident Risk API",
    description="Secure prediction backend for accident risk scoring.",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=False,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Content-Type", "Authorization", "X-API-Key"],
)
app.add_middleware(GZipMiddleware, minimum_size=500)

app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")

FEATURE_NAMES: list[str] = []
MODEL: Any = None
PREPROCESSOR: Any = None
MODEL_SOURCE = "fallback"

RISK_ORDER = ["Low", "Medium", "High", "Very High"]
RISK_COLORS = {
    "Low": "#1ecf8c",
    "Medium": "#ffbf47",
    "High": "#ff7a45",
    "Very High": "#ff4d4f",
}


class AutoPredictRequest(BaseModel):
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    distance_mi: float = Field(0.0, ge=0)
    speed_mph: float | None = Field(default=None, ge=0)

    @field_validator("distance_mi")
    @classmethod
    def normalize_distance(cls, value: float) -> float:
        return round(float(value), 3)


class ManualPredictRequest(BaseModel):
    distance_mi: float = Field(..., ge=0)
    start_lat: float = Field(..., ge=-90, le=90)
    start_lng: float = Field(..., ge=-180, le=180)
    hour: int = Field(..., ge=0, le=23)
    day_of_week: int = Field(..., ge=0, le=6)
    is_weekend: bool
    is_night: bool
    rain_flag: int = Field(0, ge=0, le=1)
    fog_flag: int = Field(0, ge=0, le=1)
    snow_flag: int = Field(0, ge=0, le=1)
    temperature_f: float = Field(0)
    wind_chill_f: float = Field(0)
    humidity: float = Field(0, ge=0, le=100)
    pressure_in: float = Field(0)
    visibility_mi: float = Field(0)
    wind_speed_mph: float = Field(0, ge=0)
    precipitation_in: float = Field(0, ge=0)
    bump: int = Field(0, ge=0, le=1)
    crossing: int = Field(0, ge=0, le=1)
    give_way: int = Field(0, ge=0, le=1)
    junction: int = Field(0, ge=0, le=1)
    no_exit: int = Field(0, ge=0, le=1)
    railway: int = Field(0, ge=0, le=1)
    roundabout: int = Field(0, ge=0, le=1)
    station: int = Field(0, ge=0, le=1)
    stop: int = Field(0, ge=0, le=1)
    traffic_calming: int = Field(0, ge=0, le=1)
    traffic_signal: int = Field(0, ge=0, le=1)
    turning_loop: int = Field(0, ge=0, le=1)

    @field_validator(
        "rain_flag",
        "fog_flag",
        "snow_flag",
        "bump",
        "crossing",
        "give_way",
        "junction",
        "no_exit",
        "railway",
        "roundabout",
        "station",
        "stop",
        "traffic_calming",
        "traffic_signal",
        "turning_loop",
        mode="before",
    )
    @classmethod
    def normalize_binary(cls, value: Any) -> int:
        if isinstance(value, bool):
            return int(value)
        if isinstance(value, (int, float)):
            return 1 if float(value) >= 1 else 0
        text = str(value).strip().lower()
        if text in {"1", "true", "yes", "on"}:
            return 1
        return 0


@app.middleware("http")
async def add_security_headers(request: Request, call_next):
    if API_KEY:
        header_key = request.headers.get("x-api-key") or request.headers.get("authorization", "").removeprefix("Bearer ").strip()
        if header_key != API_KEY and request.url.path.startswith("/api/"):
            return JSONResponse(status_code=401, content={"detail": "Unauthorized"})

    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["Permissions-Policy"] = "geolocation=(self), camera=()"
    response.headers["Cache-Control"] = "no-store"
    return response


@app.on_event("startup")
def load_artifacts() -> None:
    global FEATURE_NAMES, MODEL, PREPROCESSOR, MODEL_SOURCE
    FEATURE_NAMES = joblib.load(FEATURES_PATH)
    loaded_model = joblib.load(MODEL_PATH)
    if isinstance(loaded_model, type):
        MODEL = None
        MODEL_SOURCE = "heuristic"
    else:
        MODEL = loaded_model
        MODEL_SOURCE = "ml"
    try:
        PREPROCESSOR = joblib.load(PREPROCESSOR_PATH)
    except Exception:
        PREPROCESSOR = None


@app.get("/")
def home() -> FileResponse:
    return FileResponse(STATIC_DIR / "index.html")


@app.get("/brand-logo")
def brand_logo() -> FileResponse:
    for candidate in [ASSETS_DIR / "Logo.png", STATIC_DIR / "logo.svg"]:
        if candidate.exists():
            return FileResponse(candidate)
    raise HTTPException(status_code=404, detail="Logo asset not found")


@app.get("/brand-wordmark")
def brand_wordmark() -> FileResponse:
    for candidate in [ASSETS_DIR / "Brand_Name.png", STATIC_DIR / "brand-name.svg"]:
        if candidate.exists():
            return FileResponse(candidate)
    raise HTTPException(status_code=404, detail="Brand wordmark asset not found")


@app.get("/api/health")
def health() -> dict[str, Any]:
    return {
        "status": "ok",
        "app": "RoadVisionAI",
        "loaded_features": len(FEATURE_NAMES),
        "model_ready": MODEL is not None,
        "model_source": MODEL_SOURCE,
        "preprocessor_ready": PREPROCESSOR is not None,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


@app.post("/api/predict/auto")
def predict_auto(payload: AutoPredictRequest) -> dict[str, Any]:
    context = build_automatic_context(payload.latitude, payload.longitude, payload.distance_mi, payload.speed_mph)
    return predict_from_context(context, mode="automatic")


@app.post("/api/predict/snapshot")
def predict_snapshot(payload: AutoPredictRequest) -> dict[str, Any]:
    context = build_automatic_context(payload.latitude, payload.longitude, payload.distance_mi, payload.speed_mph)
    return predict_from_context(context, mode="snapshot")


@app.post("/api/predict/manual")
def predict_manual(payload: ManualPredictRequest) -> dict[str, Any]:
    context = {
        "Distance(mi)": payload.distance_mi,
        "Start_Lat": payload.start_lat,
        "Start_Lng": payload.start_lng,
        "Hour": payload.hour,
        "Day_of_Week": payload.day_of_week,
        "Is_Weekend": int(payload.is_weekend),
        "Is_Night": int(payload.is_night),
        "Rain_Flag": payload.rain_flag,
        "Fog_Flag": payload.fog_flag,
        "Snow_Flag": payload.snow_flag,
        "Temperature(F)": payload.temperature_f,
        "Wind_Chill(F)": payload.wind_chill_f,
        "Humidity(%)": payload.humidity,
        "Pressure(in)": payload.pressure_in,
        "Visibility(mi)": payload.visibility_mi,
        "Wind_Speed(mph)": payload.wind_speed_mph,
        "Precipitation(in)": payload.precipitation_in,
        "Bump": payload.bump,
        "Crossing": payload.crossing,
        "Give_Way": payload.give_way,
        "Junction": payload.junction,
        "No_Exit": payload.no_exit,
        "Railway": payload.railway,
        "Roundabout": payload.roundabout,
        "Station": payload.station,
        "Stop": payload.stop,
        "Traffic_Calming": payload.traffic_calming,
        "Traffic_Signal": payload.traffic_signal,
        "Turning_Loop": payload.turning_loop,
    }
    return predict_from_context(context, mode="manual")


def build_automatic_context(latitude: float, longitude: float, distance_mi: float, speed_mph: float | None) -> dict[str, Any]:
    now = datetime.now().astimezone()
    weather = fetch_weather(latitude, longitude)
    road = fetch_road_features(latitude, longitude)
    return {
        "Distance(mi)": distance_mi,
        "Start_Lat": latitude,
        "Start_Lng": longitude,
        "Hour": now.hour,
        "Day_of_Week": now.weekday(),
        "Is_Weekend": int(now.weekday() >= 5),
        "Is_Night": int(now.hour >= 18 or now.hour <= 6),
        "Rain_Flag": weather["rain_flag"],
        "Fog_Flag": weather["fog_flag"],
        "Snow_Flag": weather["snow_flag"],
        "Temperature(F)": weather["temperature_f"],
        "Wind_Chill(F)": weather["wind_chill_f"],
        "Humidity(%)": weather["humidity"],
        "Pressure(in)": weather["pressure_in"],
        "Visibility(mi)": weather["visibility_mi"],
        "Wind_Speed(mph)": weather["wind_speed_mph"],
        "Precipitation(in)": weather["precipitation_in"],
        "Bump": road["Bump"],
        "Crossing": road["Crossing"],
        "Give_Way": road["Give_Way"],
        "Junction": road["Junction"],
        "No_Exit": road["No_Exit"],
        "Railway": road["Railway"],
        "Roundabout": road["Roundabout"],
        "Station": road["Station"],
        "Stop": road["Stop"],
        "Traffic_Calming": road["Traffic_Calming"],
        "Traffic_Signal": road["Traffic_Signal"],
        "Turning_Loop": road["Turning_Loop"],
        "Speed(mph)": speed_mph,
    }


def fetch_weather(latitude: float, longitude: float) -> dict[str, float]:
    params = {
        "latitude": latitude,
        "longitude": longitude,
        "current": "temperature_2m,relative_humidity_2m,pressure_msl,visibility,windspeed_10m,precipitation,rain,snow,windchill_2m,weather_code",
        "temperature_unit": "fahrenheit",
        "wind_speed_unit": "mph",
        "precipitation_unit": "inch",
        "timezone": "auto",
    }
    try:
        response = requests.get("https://api.open-meteo.com/v1/forecast", params=params, timeout=8)
        response.raise_for_status()
        current = response.json().get("current", {})
    except Exception:
        current = {}

    weather_code = int(current.get("weather_code", 0) or 0)
    rain_flag = int(bool(current.get("rain", 0)) or weather_code in {51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82})
    fog_flag = int(weather_code in {45, 48})
    snow_flag = int(bool(current.get("snow", 0)) or weather_code in {71, 73, 75, 77, 85, 86})
    return {
        "temperature_f": float(current.get("temperature_2m", 68.0) or 68.0),
        "wind_chill_f": float(current.get("windchill_2m", current.get("temperature_2m", 68.0)) or 68.0),
        "humidity": float(current.get("relative_humidity_2m", 50.0) or 50.0),
        "pressure_in": round(float(current.get("pressure_msl", 1013.25) or 1013.25) * 0.0295299830714, 2),
        "visibility_mi": round(float(current.get("visibility", 16093.0) or 16093.0) / 1609.34, 2),
        "wind_speed_mph": float(current.get("windspeed_10m", 0.0) or 0.0),
        "precipitation_in": float(current.get("precipitation", 0.0) or 0.0),
        "rain_flag": rain_flag,
        "fog_flag": fog_flag,
        "snow_flag": snow_flag,
    }


def fetch_road_features(latitude: float, longitude: float) -> dict[str, int]:
    query = f"""
    [out:json][timeout:8];
    (
      node(around:250,{latitude},{longitude})[highway=traffic_signals];
      node(around:250,{latitude},{longitude})[highway=stop];
      node(around:250,{latitude},{longitude})[highway=give_way];
      node(around:250,{latitude},{longitude})[railway=crossing];
      node(around:250,{latitude},{longitude})[railway=level_crossing];
      way(around:250,{latitude},{longitude})[junction=roundabout];
      way(around:250,{latitude},{longitude})[traffic_calming];
      node(around:250,{latitude},{longitude})[traffic_calming];
      node(around:250,{latitude},{longitude})[crossing];
      node(around:250,{latitude},{longitude})[bump];
    );
    out tags center;
    """.strip()
    try:
        response = requests.get("https://overpass-api.de/api/interpreter", params={"data": query}, timeout=8)
        response.raise_for_status()
        elements = response.json().get("elements", [])
    except Exception:
        elements = []

    tags_blob = " ".join(str(element.get("tags", {})).lower() for element in elements)
    return {
        "Bump": int("bump" in tags_blob),
        "Crossing": int("crossing" in tags_blob),
        "Give_Way": int("give_way" in tags_blob or "give-way" in tags_blob),
        "Junction": int("roundabout" in tags_blob or "junction" in tags_blob),
        "No_Exit": 0,
        "Railway": int("railway" in tags_blob),
        "Roundabout": int("roundabout" in tags_blob),
        "Station": int("station" in tags_blob),
        "Stop": int("stop" in tags_blob),
        "Traffic_Calming": int("traffic_calming" in tags_blob),
        "Traffic_Signal": int("traffic_signals" in tags_blob),
        "Turning_Loop": int("turning_loop" in tags_blob),
    }


def predict_from_context(context: dict[str, Any], mode: str) -> dict[str, Any]:
    if MODEL is None or not FEATURE_NAMES:
        return build_fallback_prediction(context, mode)

    row = build_feature_row(context)
    transformed = transform_row(row)

    if hasattr(MODEL, "predict_proba") and not isinstance(MODEL, type):
        probabilities = np.asarray(MODEL.predict_proba(transformed))[0]
        class_index = int(np.argmax(probabilities))
        class_value = int(np.asarray(getattr(MODEL, "classes_", [class_index]))[class_index]) if len(np.asarray(getattr(MODEL, "classes_", [class_index]))) > class_index else class_index
        risk_label = map_to_risk_label(class_value, probabilities)
    else:
        return build_fallback_prediction(context, mode)

    reasons = build_reasons(context, risk_label)
    advice = build_advice(risk_label, reasons)
    confidence = float(np.max(probabilities)) if probabilities.size else 0.0

    return {
        "mode": mode,
        "risk_level": risk_label,
        "risk_color": RISK_COLORS[risk_label],
        "confidence": round(confidence * 100, 2),
        "reasons": reasons,
        "driving_advice": advice,
        "inputs": sanitize_context(context),
        "live_context": build_live_context(context),
    }


def build_fallback_prediction(context: dict[str, Any], mode: str) -> dict[str, Any]:
    score = 0.18
    score += 0.18 if int(context.get("Rain_Flag", 0)) else 0
    score += 0.2 if int(context.get("Fog_Flag", 0)) else 0
    score += 0.16 if int(context.get("Snow_Flag", 0)) else 0
    score += 0.1 if int(context.get("Is_Night", 0)) else 0
    score += 0.08 if int(context.get("Traffic_Signal", 0)) else 0
    score += 0.05 if int(context.get("Junction", 0)) else 0
    score += 0.05 if int(context.get("Stop", 0)) else 0
    score += 0.07 if float(context.get("Visibility(mi)", 10)) < 2 else 0
    score += 0.06 if float(context.get("Wind_Speed(mph)", 0)) > 18 else 0
    score += 0.04 if float(context.get("Precipitation(in)", 0)) > 0 else 0
    score += 0.05 if float(context.get("Distance(mi)", 0)) > 1.0 else 0
    score = max(0.0, min(score, 0.98))
    bucket = min(3, int(score * 4))
    risk_label = RISK_ORDER[bucket]
    reasons = build_reasons(context, risk_label)
    advice = build_advice(risk_label, reasons)
    return {
        "mode": mode,
        "risk_level": risk_label,
        "risk_color": RISK_COLORS[risk_label],
        "confidence": round(score * 100, 2),
        "reasons": reasons,
        "driving_advice": advice,
        "inputs": sanitize_context(context),
        "live_context": build_live_context(context),
        "engine": "heuristic",
    }


def build_feature_row(context: dict[str, Any]) -> dict[str, float]:
    row: dict[str, float] = {}
    for feature in FEATURE_NAMES:
        row[feature] = float(context.get(feature, 0))
    return row


def transform_row(row: dict[str, float]):
    values = np.array([[row[feature] for feature in FEATURE_NAMES]], dtype=float)
    if PREPROCESSOR is not None:
        try:
            return PREPROCESSOR.transform(values)
        except Exception:
            pass
    return values


def map_to_risk_label(class_value: int, probabilities: np.ndarray) -> str:
    if class_value in {0, 1, 2, 3}:
        return RISK_ORDER[class_value]
    if probabilities.size:
        bucket = min(3, max(0, int(round((1.0 - float(np.max(probabilities))) * 3))))
        return RISK_ORDER[bucket]
    return "Medium"


def build_reasons(context: dict[str, Any], risk_label: str) -> list[str]:
    reasons: list[str] = []
    if int(context.get("Rain_Flag", 0)):
        reasons.append("Rain is active in the current conditions.")
    if int(context.get("Fog_Flag", 0)):
        reasons.append("Visibility is impacted by fog.")
    if int(context.get("Snow_Flag", 0)):
        reasons.append("Snow conditions increase road slip risk.")
    if float(context.get("Visibility(mi)", 10)) < 2:
        reasons.append("Low visibility is below a safe driving threshold.")
    if float(context.get("Wind_Speed(mph)", 0)) >= 18:
        reasons.append("Wind speed is elevated and can reduce vehicle stability.")
    if float(context.get("Precipitation(in)", 0)) > 0:
        reasons.append("Active precipitation raises braking distance.")
    if int(context.get("Traffic_Signal", 0)) or int(context.get("Stop", 0)):
        reasons.append("Intersections and stop controls increase conflict points.")
    if int(context.get("Junction", 0)) or int(context.get("Roundabout", 0)):
        reasons.append("Complex junction geometry requires higher driver attention.")
    if int(context.get("Is_Night", 0)):
        reasons.append("Night driving reduces visibility and reaction time.")
    if float(context.get("Distance(mi)", 0)) >= 1.5:
        reasons.append("The trip distance is long enough to accumulate exposure.")
    if not reasons:
        reasons.append(f"Model output indicates {risk_label.lower()} accident exposure for this context.")
    return reasons[:4]


def build_advice(risk_label: str, reasons: list[str]) -> list[str]:
    advice_map = {
        "Low": [
            "Maintain normal following distance.",
            "Keep distractions out of the cabin.",
        ],
        "Medium": [
            "Slow down around junctions and signals.",
            "Increase following distance by at least 2 seconds.",
        ],
        "High": [
            "Reduce speed and avoid abrupt lane changes.",
            "Keep headlights and windshield visibility optimized.",
        ],
        "Very High": [
            "Postpone travel if conditions are avoidable.",
            "Drive defensively and avoid high-risk routes.",
        ],
    }
    advice = advice_map[risk_label][:]
    if any("fog" in item.lower() or "visibility" in item.lower() for item in reasons):
        advice.insert(0, "Use low-beam headlights and reduce speed immediately.")
    return advice[:3]


def sanitize_context(context: dict[str, Any]) -> dict[str, Any]:
    cleaned = {}
    for key, value in context.items():
        if isinstance(value, (int, float, str, bool)) or value is None:
            cleaned[key] = value
    return cleaned


def build_live_context(context: dict[str, Any]) -> dict[str, Any]:
    weather_bits = []
    if int(context.get("Rain_Flag", 0)):
        weather_bits.append("Rain")
    if int(context.get("Fog_Flag", 0)):
        weather_bits.append("Fog")
    if int(context.get("Snow_Flag", 0)):
        weather_bits.append("Snow")
    if not weather_bits:
        weather_bits.append("Clear")

    road_bits = []
    for key in ["Bump", "Crossing", "Give_Way", "Junction", "Railway", "Roundabout", "Station", "Stop", "Traffic_Calming", "Traffic_Signal"]:
        if int(context.get(key, 0)):
            road_bits.append(key.replace("_", " "))
    if not road_bits:
        road_bits.append("No high-risk road feature detected")

    return {
        "weather_summary": ", ".join(weather_bits),
        "road_summary": ", ".join(road_bits[:4]),
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


@app.exception_handler(HTTPException)
async def http_exception_handler(_: Request, exc: HTTPException):
    return JSONResponse(status_code=exc.status_code, content={"detail": exc.detail})
