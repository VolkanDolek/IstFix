<div align="center">

# IstFix

**Urban Infrastructure Complaint Automation for Istanbul**

*Snap a photo. Classify the issue. Notify the municipality. Automatically.*

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.11x-009688?style=flat-square&logo=fastapi)](https://fastapi.tiangolo.com)
[![YOLOv8](https://img.shields.io/badge/YOLOv8-Ultralytics-purple?style=flat-square)](https://docs.ultralytics.com)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL+PostGIS-16-336791?style=flat-square&logo=postgresql)](https://postgresql.org)
[![Python](https://img.shields.io/badge/Python-3.11+-3776AB?style=flat-square&logo=python)](https://python.org)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)

</div>

---

## About

**IstFix** is a cross-platform mobile application that fully automates the urban infrastructure complaint submission process for Istanbul citizens. The system targets all 40 municipal authorities in Istanbul, covering 39 district municipalities and the Istanbul Metropolitan Municipality (IBB).

A citizen captures a photo of an infrastructure issue. IstFix classifies the problem using an embedded YOLOv8 model, identifies the responsible municipality from the device's GPS coordinates, generates a formal complaint text dynamically via the Gemini API, and dispatches it directly to the correct authority through SendGrid — all without any manual input from the user.

This project was developed as a Graduation Design Project for COMP/SOFT 4902/4912 at Isik University.

**Developers:** Volkan Dölek (21SOFT1019) and Berşan Korkmaz (21SOFT1031)

---

## Key Features

- **Automatic Photo Classification** — YOLOv8 model trained on a custom Roboflow dataset, supporting 5 issue categories: road damage, street lighting failure, waste management, water and drainage, and a general "other" category
- **GPS-Based Municipality Detection** — Geopy and Nominatim reverse geocoding pipeline that maps precise coordinates to one of Istanbul's 40 municipal authorities
- **Dynamic Complaint Generation** — Gemini API produces a formal, context-aware complaint text on every submission, replacing rigid rule-based templates entirely
- **Automated Email Dispatch** — SendGrid SMTP integration with an exponential backoff retry mechanism (up to 3 attempts before permanent failure logging)
- **Report History Map** — Interactive map view where citizens can track all their previously submitted reports spatially
- **KVKK-Compliant Security** — bcrypt password hashing, short-lived JWT sessions, TLS 1.2+ in transit, and minimal GPS data retention

---

## ML Model

IstFix uses a custom-trained **YOLOv8 (Ultralytics)** classification model embedded directly inside the monolithic backend to eliminate internal network latency.

**Issue Categories:**

| Label | Description |
|-------|-------------|
| `road_damage` | Potholes, broken pavement, cracked sidewalks |
| `broken_streetlight` | Non-functional or damaged street lighting |
| `overflowing_bin` | Waste management and overflowing rubbish bins |
| `illegal_dumping` | Unauthorized waste disposal |
| `water_leak` | Water leaks, drainage blockages, flooding |
| `other` | General infrastructure issues |

**Confidence Threshold:** `80%` — classifications below this threshold trigger an error screen prompting the user to retake the photo with better framing or lighting.

---

## Security

| Mechanism | Implementation |
|-----------|----------------|
| Password storage | bcrypt with per-user salting (OWASP standard) |
| Session management | Short-lived JWT, invalidated on logout |
| Brute-force protection | Account locked for 15 minutes after 5 consecutive failed logins |
| Data in transit | TLS 1.2 or higher enforced on all HTTPS traffic |
| API key management | Stored server-side in `.env`, never exposed to the client |
| KVKK compliance | GPS coordinates used only for municipality resolution and not retained; full account deletion removes all personal data in a single transaction |

---

## Performance Targets

The following non-functional requirements are defined in the SDD and verified through automated testing:

| Requirement | Target | Verification Method |
|-------------|--------|---------------------|
| End-to-end report processing | 10 seconds under 4G | Automated performance test on a reference device |
| Reverse geocoding response | 3 seconds | API timeout simulation in integration tests |
| Map rendering (200 markers) | 5 seconds | Load test with 200 seeded reports |
| ML classification accuracy | 80% | Per-class confusion matrix on held-out test set |
| First-time user report submission | 3 minutes | Structured walkthrough with at least 3 first-time users |

---

## Supported Municipalities

IstFix routes complaints to all **40 local authorities** in Istanbul:

- **1** Istanbul Metropolitan Municipality (IBB)
- **39** District municipalities (Adalar through Zeytinburnu)

All municipality email addresses are stored in the database and can be updated at any time through the administrator interface without requiring a redeployment (UC-8, SDD DG-M2).

---

<div align="center">

Isik University · COMP/SOFT 4902/4912 · 2025-2026

**Volkan Dölek** · **Berşan Korkmaz**

</div>
