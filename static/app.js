const screens = {
  splash: document.getElementById('screen-splash'),
  home: document.getElementById('screen-home'),
  result: document.getElementById('screen-result'),
};

const state = {
  mode: 'auto',
  watchId: null,
  refreshTimer: null,
  latest: {
    latitude: null,
    longitude: null,
    speed: null,
    distance_mi: 0,
  },
};

const manualPanel = document.getElementById('manual-panel');
const locationText = document.getElementById('location-text');
const timeText = document.getElementById('time-text');
const weatherText = document.getElementById('weather-text');
const speedText = document.getElementById('speed-text');
const riskBadge = document.getElementById('risk-badge');
const lastRefresh = document.getElementById('last-refresh');

const ui = {
  riskTitle: document.getElementById('risk-title'),
  riskPill: document.getElementById('risk-pill'),
  riskMeterFill: document.getElementById('risk-meter-fill'),
  confidenceText: document.getElementById('confidence-text'),
  modeText: document.getElementById('mode-text'),
  gpsText: document.getElementById('gps-text'),
  statusText: document.getElementById('status-text'),
  reasonList: document.getElementById('reason-list'),
  adviceList: document.getElementById('advice-list'),
};

function showScreen(name) {
  Object.entries(screens).forEach(([key, el]) => el.classList.toggle('active', key === name));
}

function toast(message) {
  const existing = document.querySelector('.toast');
  if (existing) existing.remove();
  const node = document.createElement('div');
  node.className = 'toast';
  node.textContent = message;
  document.body.appendChild(node);
  window.setTimeout(() => node.remove(), 2600);
}

function updateLiveSummary(sample) {
  const lat = sample.latitude?.toFixed(5) ?? '--';
  const lng = sample.longitude?.toFixed(5) ?? '--';
  locationText.textContent = `${lat}, ${lng}`;
  timeText.textContent = new Date().toLocaleString();
  weatherText.textContent = sample.weather_summary || 'Live weather unavailable';
  speedText.textContent = sample.speed_mph == null ? '-- mph' : `${sample.speed_mph.toFixed(1)} mph`;
  lastRefresh.textContent = `Updated ${new Date().toLocaleTimeString()}`;
}

function renderPrediction(payload) {
  ui.riskTitle.textContent = payload.risk_level;
  ui.riskPill.textContent = payload.risk_level;
  ui.riskPill.style.background = `${payload.risk_color}22`;
  ui.riskPill.style.borderColor = `${payload.risk_color}55`;
  ui.riskMeterFill.style.width = payload.risk_level === 'Low' ? '24%' : payload.risk_level === 'Medium' ? '48%' : payload.risk_level === 'High' ? '74%' : '94%';
  ui.confidenceText.textContent = `${payload.confidence.toFixed(1)}%`;
  ui.modeText.textContent = payload.mode;
  ui.gpsText.textContent = payload.inputs?.Start_Lat != null ? `${Number(payload.inputs.Start_Lat).toFixed(5)}, ${Number(payload.inputs.Start_Lng).toFixed(5)}` : 'Auto';
  ui.statusText.textContent = payload.engine === 'heuristic' ? 'Live heuristic fallback' : 'Live model scoring';
  ui.reasonList.innerHTML = payload.reasons.map((reason) => `<li>${reason}</li>`).join('');
  ui.adviceList.innerHTML = payload.driving_advice.map((item) => `<li>${item}</li>`).join('');
  riskBadge.textContent = payload.risk_level;
  showScreen('result');
}

async function predictAuto(position) {
  const body = {
    latitude: position.coords.latitude,
    longitude: position.coords.longitude,
    distance_mi: Math.max(0, Number(position.coords.speed || 0) * 0.000621371 * 60),
    speed_mph: position.coords.speed == null ? null : Number(position.coords.speed) * 2.23694,
  };
  state.latest.latitude = body.latitude;
  state.latest.longitude = body.longitude;
  state.latest.speed = body.speed_mph;
  state.latest.distance_mi = body.distance_mi;
  updateLiveSummary({
    latitude: body.latitude,
    longitude: body.longitude,
    speed_mph: body.speed_mph,
    weather_summary: 'Fetching live weather...'
  });
  const response = await fetch('/api/predict/auto', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (!response.ok) throw new Error('Automatic prediction failed');
  const data = await response.json();
  if (data.live_context) {
    updateLiveSummary({
      latitude: body.latitude,
      longitude: body.longitude,
      speed_mph: body.speed_mph,
      weather_summary: `${data.live_context.weather_summary} · ${data.live_context.road_summary}`,
    });
  }
  renderPrediction(data);
}

async function predictSnapshot() {
  if (!navigator.geolocation) {
    toast('Geolocation is not available in this browser.');
    return;
  }
  manualPanel.classList.add('hidden');
  const position = await new Promise((resolve, reject) => {
    navigator.geolocation.getCurrentPosition(resolve, reject, {
      enableHighAccuracy: true,
      maximumAge: 5000,
      timeout: 12000,
    });
  });
  const body = {
    latitude: position.coords.latitude,
    longitude: position.coords.longitude,
    distance_mi: Math.max(0, Number(position.coords.speed || 0) * 0.000621371 * 60),
    speed_mph: position.coords.speed == null ? null : Number(position.coords.speed) * 2.23694,
  };
  updateLiveSummary({
    latitude: body.latitude,
    longitude: body.longitude,
    speed_mph: body.speed_mph,
    weather_summary: 'Collecting live snapshot...',
  });
  const response = await fetch('/api/predict/snapshot', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (!response.ok) throw new Error('Snapshot prediction failed');
  const data = await response.json();
  renderPrediction(data);
}

function startAutoRefresh() {
  if (!navigator.geolocation) {
    toast('Geolocation is not available in this browser.');
    return;
  }
  if (state.watchId != null) navigator.geolocation.clearWatch(state.watchId);
  state.watchId = navigator.geolocation.watchPosition(
    (position) => {
      predictAuto(position).catch((error) => toast(error.message));
    },
    (error) => toast(error.message),
    { enableHighAccuracy: true, maximumAge: 20000, timeout: 15000 }
  );
  if (state.refreshTimer) window.clearInterval(state.refreshTimer);
  state.refreshTimer = window.setInterval(() => {
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        (position) => predictAuto(position).catch((error) => toast(error.message)),
        (error) => toast(error.message),
        { enableHighAccuracy: true, maximumAge: 10000, timeout: 12000 }
      );
    }
  }, 60000);
}

async function loadHealthState() {
  try {
    const response = await fetch('/api/health');
    const data = await response.json();
    riskBadge.textContent = data.status === 'ok' ? 'Live' : 'Ready';
  } catch {
    riskBadge.textContent = 'Ready';
  }
}

document.getElementById('enter-app').addEventListener('click', async () => {
  showScreen('home');
  await loadHealthState();
});

document.getElementById('skip-auto').addEventListener('click', () => {
  showScreen('home');
  manualPanel.classList.add('hidden');
  toast('Live snapshot mode is ready.');
});

document.getElementById('auto-mode').addEventListener('click', () => {
  state.mode = 'auto';
  manualPanel.classList.add('hidden');
  toast('Automatic prediction started.');
  startAutoRefresh();
  if (navigator.geolocation) {
    navigator.geolocation.getCurrentPosition(
      (position) => predictAuto(position).catch((error) => toast(error.message)),
      (error) => toast(error.message),
      { enableHighAccuracy: true, maximumAge: 10000, timeout: 12000 }
    );
  }
});

document.getElementById('manual-mode').addEventListener('click', () => {
  state.mode = 'manual';
  toast('Collecting a one-time live snapshot.');
  predictSnapshot().catch((error) => toast(error.message));
});

document.getElementById('back-home').addEventListener('click', () => {
  showScreen('home');
});

document.getElementById('refresh-auto').addEventListener('click', () => {
  if (!navigator.geolocation) {
    toast('Geolocation is not available in this browser.');
    return;
  }
  navigator.geolocation.getCurrentPosition(
    (position) => predictAuto(position).catch((error) => toast(error.message)),
    (error) => toast(error.message),
    { enableHighAccuracy: true, maximumAge: 5000, timeout: 12000 }
  );
});

manualPanel.classList.add('hidden');
showScreen('splash');
loadHealthState();
