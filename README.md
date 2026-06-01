# RoadVisionAI Accident Shield

RoadVisionAI is a mobile-first accident risk prediction app built with FastAPI, a trained risk model, and a polished browser UI. The repository has been reorganized for public release so the runtime code, artifacts, assets, and notebook work are separated cleanly.

## Repository Layout

- `app/` - backend package and API entrypoint
- `artifacts/` - trained model, feature order, and preprocessing artifacts
- `assets/` - brand images used by the web app
- `notebooks/` - model training and experimentation notebook
- `static/` - browser UI, styles, and client-side logic
- `main.py` - compatibility entrypoint for `uvicorn main:app`
- `.gitignore` - excludes local environments and cache files from GitHub
- `.env.example` - documented environment variables for safe local setup

## Run Locally

1. Install dependencies from `requirements.txt`.
2. Copy `.env.example` to `.env` and set `ROADVISIONAI_API_KEY` if you want request authentication.
3. Start the server with `uvicorn app.main:app --host 127.0.0.1 --port 8000`.
4. Open `http://127.0.0.1:8000` in a browser.

## Publish Checklist

- Keep `.venv/`, `.env`, cache folders, and notebook checkpoints out of GitHub.
- Do not commit secrets, API keys, or any machine-specific configuration.
- If the model artifacts are too large for normal Git history, move them to Git LFS or release assets before publishing.

## Notes

- Automatic mode uses live GPS, weather, and road context from the browser plus external APIs.
- Manual mode lets you enter the exact feature values used by the model.
- If the saved pickle artifacts cannot be loaded cleanly in the local environment, the app falls back to a safe heuristic scorer so the UI remains usable.
