# 🚦 RoadVisionAI

### AI-Powered Road Accident Risk Prediction Platform

RoadVisionAI is an intelligent road safety platform that leverages **Machine Learning, Weather Intelligence and Geospatial Road Analysis** to predict accident risk before a journey begins. By combining real-time environmental conditions with road infrastructure data, the system provides actionable risk assessments that help promote safer travel decisions.

---

## 🌟 Overview

Road accidents remain one of the leading causes of injuries and fatalities worldwide. RoadVisionAI was developed to demonstrate how Artificial Intelligence can be applied to road safety by transforming weather, location and road feature data into meaningful accident risk predictions.

The platform delivers:

* Real-time accident risk prediction
* Weather-aware safety analysis
* Risk classification and confidence scoring
* Personalized driving recommendations
* Web and mobile integration support
* Secure REST API services

RoadVisionAI is suitable for:

* Academic and research projects
* Smart transportation initiatives
* AI and Machine Learning demonstrations
* Mobile and web application integration
* Intelligent decision-support systems

---

# 🎯 Key Features

### 🔍 Automatic Risk Prediction

Predict accident risk using:

* GPS coordinates
* Live weather conditions
* Road network characteristics
* Environmental context

### 📊 Risk Classification

The model categorizes road conditions into:

* 🟢 Low Risk
* 🟡 Medium Risk
* 🟠 High Risk
* 🔴 Very High Risk

### 📈 Confidence Analysis

Each prediction includes a confidence score that helps users understand the reliability of the model's assessment.

### 🚗 Intelligent Safety Recommendations

RoadVisionAI generates practical driving guidance based on detected risk factors.

### 🧠 Machine Learning Powered

Predictions are generated using a trained machine learning model combined with preprocessing pipelines and engineered road-safety features.

### 🔐 API Security

Optional API key authentication is available for protecting prediction endpoints.

### ⚡ Fallback Prediction Engine

If the trained model becomes unavailable, the system automatically switches to a heuristic-based prediction mode to maintain service availability.

---

# 🏗 System Architecture

## Backend Layer

The backend is developed using FastAPI and provides:

* RESTful API services
* Model inference
* Weather data integration
* Road feature extraction
* Risk scoring logic
* Static frontend hosting

### Core Technologies

* Python
* FastAPI
* Scikit-Learn
* Pandas
* NumPy

---

## Weather Intelligence Layer

RoadVisionAI enriches predictions using live weather information including:

* Rain_Flag
* Fog_Flag
* Snow_Flag
* Temperature(F)
* Wind_Chill(F)
* Humidity(%)
* Pressure(in)
* Visibility(mi)
* Wind_Speed(mph)
* Precipitation(in)s

Weather context can be obtained through:

* Open-Meteo
* OpenWeather APIs
* Custom weather providers

---

## Geospatial Analysis Layer

Version 1 of RoadVisionAI did not uses location-based inputs. Advanced geospatial road infrastructure analysis using OpenStreetMap and the Overpass API is planned for a future release.

Planned geospatial features include:

* Road type detection
* Junction density analysis
* Traffic signal identification
* Crossing point detection
* Speed-related indicators
* Infrastructure complexity assessment

---

## Frontend Layer

The browser-based interface provides:

* Interactive predictions
* Automate map-based location selection
* Automate map-based weather tracking
* Risk level visualization
* Perentage of risk
* Reasons for risk
* Guidence for minimize risk

---

## Mobile Layer

A Flutter application scaffold is included for future Android and iOS deployment.

---

# 📂 Project Structure

```text
RoadVisionAI/
│
├── app/                    # FastAPI application
├── artifacts/              # Trained ML model assets
├── assets/                 # Branding resources
├── mobile_app/             # Flutter mobile client
├── notebooks/              # Training & experimentation notebooks
├── static/                 # Frontend application
├── Dockerfile
├── render.yaml
├── requirements.txt
├── main.py
└── README.md
```

---

# 🚀 Getting Started

## Prerequisites

* Python 3.10+
* pip
* Git

Optional:

* Flutter SDK
* Docker

---

## Installation

Clone the repository:

```bash
git clone https://github.com/DewmikaSenarathna/RoadVision-AI.git
```

Install dependencies:

```bash
pip install -r requirements.txt
```

---

## Environment Configuration

Create a local environment file:

```bash
cp .env.example .env
```

Configure the following variables:

```env
ROADVISIONAI_API_KEY=

ROADVISIONAI_CORS_ORIGINS=

ROADVISIONAI_WEATHER_API_BASE_URL=

ROADVISIONAI_WEATHER_API_KEY=
```

---

## Run Locally

Start the FastAPI server:

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Application URL:

```text
https://accident-predictor-1.onrender.com/
```

---

Returns:

* Service status
* Model availability
* Diagnostic information

---

## Automatic Prediction

```http
POST /api/predict/auto
```

Automatically retrieves:

* Weather data
* Environmental features

before generating a risk prediction.

---

## Snapshot Prediction

```http
POST /api/predict/snapshot
```

Performs location-based risk prediction using a single environmental snapshot.

---

# 🧠 Machine Learning Pipeline

The prediction workflow consists of:

1. Data Collection
2. Data Preprocessing
3. Feature Engineering
4. Model Training
5. Model Evaluation
6. Risk Classification
7. Confidence Estimation

Stored artifacts include:

```text
artifacts/
├── accident_model.pkl
├── preprocessor.pkl
└── final_features.pkl
```

---

# 🌍 Deployment

RoadVisionAI is deployed on Render, providing reliable cloud hosting for the FastAPI backend and frontend application.

Render Deployment:

* The project includes a render.yaml configuration file for streamlined deployment on Render.

Live application: 

```text
https://accident-predictor-1.onrender.com/
```


---

# 📊 Future Roadmap

Planned enhancements include:

* Road condition tracking feature
* Route-level risk analysis
* Alternative route comparison
* Real-time traffic integration
* Historical accident data integration
* Explainable AI dashboards
* User authentication system
* Analytics and reporting modules

---

# 🤝 Contributing

Contributions are welcome.

Potential areas for contribution:

* Machine Learning improvements
* Frontend enhancements
* Geospatial analytics
* API optimization
* Testing and quality assurance
* Documentation

Please fork the repository and submit a pull request.

---

# 👨‍💻 Author

**Don Dew**
Computer Engineering Undergraduate | AI & Software Developer

---

# 📄 License

This project is released for educational, research and demonstration purposes.

Please review the license terms before commercial usage.

---

