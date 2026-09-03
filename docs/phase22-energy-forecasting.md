# EH Home Phase 22 — Energy Forecasting + Predictive Intelligence + Smart Optimization

## Architectural Specification & Design Document

### 1. Executive Summary
Phase 22 enhances the EH Home Energy Platform by introducing explainable, deterministic multi-horizon forecasting, device/room/home baseline estimation, proactive anomaly detection with graduated severity classifications, explainable efficiency scoring (0-100), and predictive load-shifting recommendations without introducing heavyweight machine learning dependencies.

---

## 2. Core Architectural Pillars

### 2.1 Multi-Horizon Forecasting Engine
The forecasting engine produces explainable point-by-point predictions:
- **`next_hour`**: 1-hour lookahead in 15-minute intervals.
- **`next_24_hours`**: 24-hour lookahead in 1-hour intervals.
- **`next_7_days`**: 7-day lookahead in 1-hour intervals with day-of-week activity weighting.
- **`current_month`**: Remainder of the current billing cycle.

Mathematical baseline calculation:
$$E_{\text{pred}}(h) = \overline{E_{\text{hist}}}(h) \times W_{\text{dow}}$$
where $\overline{E_{\text{hist}}}(h)$ is the historical average consumption for hour $h \in [0, 23]$ across the past 30 days, and $W_{\text{dow}}$ is the weekend activity weighting factor (1.15 for weekends, 1.00 for weekdays).

Every forecast is explicitly tagged with `isEstimate: true` and a calculated `confidenceScore` $\in [0.0, 1.0]$. When fewer than 3 historical samples exist, the engine returns `dataCoverage: 'INSUFFICIENT'` with confidence capped at 0.20.

---

### 2.2 Device, Room & Home Baselines
- **Device Baseline**: Computes typical active power ($W$), typical daily energy ($\text{kWh}$), typical overnight consumption ($00:00 - 06:00$), and typical operating hours (hours active on at least 40% of observed days).
- **Room Baseline**: Aggregates device baselines for all registered devices in a room.
- **Home Baseline**: Aggregates all devices across the home.

---

### 2.3 Explainable Anomaly Detection & Severity
Monitors real-time and aggregate consumption against established baselines:
- **`UNUSUAL_POWER_SPIKE`**: Real-time or peak power exceeding $2.0\times$ typical device power.
- **`UNEXPECTED_OVERNIGHT_LOAD`**: Overnight draw exceeding $2.5\times$ typical overnight baseline.
- **`UNEXPECTED_OPERATING_DURATION`**: Heavy consumption during hours not present in typical operating hours.

#### Graduated Severity Engine:
- **`INFO`**: Deviation $< 25\%$
- **`LOW`**: Deviation $25\% - 50\%$
- **`MEDIUM`**: Deviation $50\% - 100\%$
- **`HIGH`**: Deviation $100\% - 300\%$
- **`CRITICAL`**: Deviation $> 300\%$ or severe overnight power draw

---

### 2.4 Explainable Energy Efficiency Scoring
The energy efficiency score (0–100) and grade (`A+`, `A`, `B`, `C`, `D`, `F`) are computed deterministically from 5 weighted behavioral components:
1. **Standby Loss Score (25%)**: Penalizes vampire / overnight baseline ratio ($> 10\%$ of total).
2. **Peak Demand Score (25%)**: Penalizes disproportionate peak hour concentration ($> 40\%$).
3. **Threshold Compliance Score (20%)**: Deducts 5 points per active anomaly/violation.
4. **Tariff Efficiency Score (15%)**: Measures consumption alignment with off-peak tariff periods.
5. **Consumption Trend Score (15%)**: Compares recent run-rate against historical baselines.

$$\text{Score} = 0.25 S_{\text{standby}} + 0.25 S_{\text{peak}} + 0.20 S_{\text{threshold}} + 0.15 S_{\text{tariff}} + 0.15 S_{\text{trend}}$$

---

### 2.5 Predictive Optimization Recommendations
Evidence-based recommendations:
- **`PEAK_AVOIDANCE`**: Flags predicted high-power windows during peak tariff rates with estimated cost savings.
- **`ANOMALY_INSPECTION`**: Directs user to inspect equipment displaying persistent anomalies.
- **`BUDGET_PROTECTION`**: Recommends load curtailment when projected monthly cost threatens to exceed configured budgets.

All recommendations explicitly flag `isEstimate: true` and include underlying calculation evidence.

---

### 2.6 Forecast Accuracy Evaluation (MAE / MAPE)
Accuracy records track predicted vs actual realization:
$$\text{MAE} = \frac{1}{N} \sum_{i=1}^{N} |y_i - \hat{y}_i|$$
$$\text{MAPE} = \frac{100\%}{N} \sum_{i=1}^{N} \frac{|y_i - \hat{y}_i|}{y_i}$$

---

### 2.7 Database Schema (Migration 015)
- `energy_forecasts`: Persists multi-horizon forecasts with points array.
- `energy_anomalies`: Tracks detected anomalies, severity, observed/baseline values, and confirmations.
- `energy_baselines`: Stores historical device, room, and home baseline snapshots.
- `forecast_accuracy_records`: Historical error tracking for forecast calibration.
- `energy_efficiency_scores`: Snapshot history of efficiency scores and grades.

---

## 3. Physical Hardware Status
- **Physical Hardware Changes**: **NONE** (All forecasting, predictive intelligence, anomaly detection, and scoring operate upstream in backend and Flutter client layers using telemetry aggregates).
