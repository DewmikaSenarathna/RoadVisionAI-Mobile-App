from app.main import app


if __name__ == "__main__":
    import uvicorn

    print("Starting RoadVisionAI backend on http://0.0.0.0:8000")
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=False)