# RoadVisionAI Mobile App

This folder contains the Flutter client scaffold for RoadVisionAI. It is designed to talk to the existing FastAPI backend and present accident-risk scores in a polished mobile dashboard.

## What It Does

- Checks backend health and shows connection state
- Sends automatic or snapshot prediction requests
- Renders the returned risk level, confidence, reasons, and driving advice
- Uses a secure setup where secrets remain on the backend, not inside the app

## Run It

1. Install Flutter.
2. From this folder, run `flutter pub get`.
3. Start the backend server.
4. Create a `.env` file from `.env.example` and fill in your OpenWeather API key.

   `cp .env.example .env`

5. Launch the app normally, for example:

   `flutter run`

For a real device, use your system IP address (for example `192.168.1.5`) in the `.env` file instead of `10.0.2.2`.

Make sure the backend server is actually running and bound to all interfaces. You can start it from the root folder with:

```bat
run_backend.bat
```

If the mobile phone still cannot connect, verify Windows Firewall allows incoming traffic on port `8000`.

## Notes

- The app uses `geolocator` to request runtime location permission on Android.
- The branded logo and splash screen are included in `mobile_app/assets/`.
- The app intentionally does not store backend API keys in source.
