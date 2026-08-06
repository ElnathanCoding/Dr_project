# Diabetic Retinopathy AI Screening System

AI-assisted retinal screening tool that classifies diabetic retinopathy severity from fundus images using the International Clinical Diabetic Retinopathy (ICDR) severity scale, with Grad-CAM explainability and a full clinical reference library — built to support healthcare professionals, not replace clinical judgment.

---

## Table of Contents

- [Purpose](#purpose)
- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Features](#features)
- [Project Structure](#project-structure)
- [Setup](#setup)
- [Known Limitations](#known-limitations)
- [Roadmap](#roadmap)

---

## Purpose

Diabetic retinopathy (DR) is a leading cause of vision loss among working-age adults, and is often asymptomatic in its early stages. This system allows a healthcare professional to upload a retinal fundus image and receive:

- A severity classification across the 5 standard ICDR stages
- A confidence score and full probability breakdown
- A Grad-CAM visualization showing where the model focused its attention
- Contextual clinical reference material for the predicted stage

This is a **decision-support tool**, not a diagnostic authority. All results are intended to be reviewed by a licensed healthcare professional.

---

## Architecture

```
                 USER
                  |
                  v
          Laravel Website (port 8000)
        /  (public landing)    /dashboard  (auth-protected tool)
                  |
                  v
          FastAPI AI Server (port 5000)
                  |
       ------------------------
       |                      |
       v                      v
 Image Quality Check    EfficientNetB0 Model
 (rejects blurry/dark/         |
  non-retinal images)          v
       |                Grad-CAM Heatmap
       |                Generation
       ------------------------
                  |
                  v
          JSON Response
   (prediction, confidence, probabilities,
    heatmap filename, quality note)
                  |
                  v
          Laravel Displays Result
```

**Why two separate services:** The AI/ML logic (Python, TensorFlow) and the web application (PHP, Laravel) are decoupled — the FastAPI server acts purely as a prediction API, and Laravel never touches the model directly. This keeps the two concerns independently testable, deployable, and replaceable.

---

## Tech Stack

| Layer | Technology |
|---|---|
| AI / ML | Python 3.12, TensorFlow/Keras, EfficientNetB0 (transfer learning) |
| AI Backend | FastAPI, Uvicorn, OpenCV (Grad-CAM overlay generation) |
| Web Frontend/Backend | Laravel (PHP), Blade templates, Laravel Breeze (auth) |
| Frontend Build | Vite, Node.js |

---

## Features

### Core Prediction Pipeline
- 5-class ICDR severity classification (No DR, Mild, Moderate, Severe, Proliferative DR)
- Confidence score and full per-class probability breakdown
- Grad-CAM attention heatmap overlay
- Automated image quality gate — rejects blurry, overexposed, underexposed, and non-retinal images before they reach the model (uses a corner-darkness/vignette check in addition to color, shape, and texture heuristics, since real fundus photos are captured through a circular aperture with a black background)

### Trust & Transparency
- **Reliability banner** — flags low-confidence (<60%) or ambiguous (top-2 predictions within 15%) results, recommending clinical correlation rather than presenting every result as equally certain
- **Image quality transparency** — the quality gate's internal confidence score is surfaced to the user on every result, not just rejections
- **About This AI panel** — model architecture, dataset size, and an explicit limitations statement
- **Non-fabricated explanations** — stage explanations describe the general clinical findings that define each ICDR stage, never claiming the AI detected specific lesions in a specific image (the model is an image-level classifier, not a lesion detector)

### Clinical Reference
- Full ICDR Disease Severity Scale reference with expandable "Learn More" detail per stage (follow-up timing, progression risk, standard treatment considerations)
- General DR overview and symptom reference

### Workflow
- Session Analysis Log — browser-only (sessionStorage), lets a user click back through results analyzed earlier in the same session without re-uploading; clears automatically when the tab closes (intentionally not a persistent database, per the constraint that patient history features are restricted to licensed professionals)
- Eye laterality (OD/OS) tagging per analysis
- Drag-and-drop image upload
- Printable/downloadable result report (browser print-to-PDF)

### Security & Access
- Full authentication (Laravel Breeze) — the actual tool lives behind `/dashboard`, gated by login; `/` is a public landing page
- Rate limiting on the prediction endpoint (throttle: 10 requests/minute) to prevent abuse
- Standard Laravel protections: hashed passwords (bcrypt), CSRF protection, XSS-safe Blade escaping, SQL-injection-safe Eloquent queries

---

## Project Structure

```
Dr_project/
├── Scripts/                    # AI / ML backend
│   ├── ai_server.py            # FastAPI server (/predict endpoint)
│   ├── gradcam.py              # Grad-CAM generation
│   ├── image_quality.py        # Pre-inference quality gate
│   ├── image_utils.py          # Preprocessing
│   ├── build_model.py          # EfficientNetB0 architecture
│   ├── train_model.py          # Training entry point
│   ├── evaluate_model.py       # Test-set evaluation
│   ├── data_loader.py          # Dataset loading
│   ├── split_dataset.py        # Train/val/test split
│   └── Models/
│       └── best_model.keras    # Trained model weights
│
└── Website/                    # Laravel application
    ├── app/Http/Controllers/
    │   └── PredictionController.php
    ├── resources/views/
    │   ├── welcome.blade.php   # Public landing page
    │   └── dashboard.blade.php # The actual tool (auth-protected)
    └── routes/web.php
```

---

## Setup

### Prerequisites
- Python 3.12 with a virtual environment
- Node.js (LTS) and npm
- PHP 8.2+ and Composer

### AI Server
```bash
cd Scripts
# activate your virtual environment first
uvicorn ai_server:app --host 0.0.0.0 --port 5000 --reload
```

### Laravel Website
```bash
cd Website
composer install
npm install
npm run build
php artisan migrate
php artisan serve
```

Visit `http://127.0.0.1:8000` — register/log in, then you'll land on `/dashboard`.

---

## Known Limitations

- **Dataset accuracy:** The current training dataset has known label-quality issues (~20% estimated inaccuracy per informal review) and is planned to be replaced with a cleaner dataset.
- **No lesion-level localization:** The model classifies the whole image; it cannot identify or point to specific lesion types (microaneurysms, exudates, hemorrhages) individually. Grad-CAM shows attention regions, not lesion identification. True lesion-level localization (e.g. bounding boxes) would require a different model type trained on lesion-annotated data.
- **Quality gate is heuristic, not learned:** The non-retina image rejection uses hand-tuned image properties (color, shape, texture, corner darkness) rather than a trained classifier, and can in principle still be fooled by unusual inputs.
- **No offline hosting configured yet:** The system currently requires manual local hosting (a laptop running both servers); a dedicated deployment strategy for field/offline use (e.g. medical missions) is planned but not yet implemented.

---

## Roadmap

- [ ] Replace training dataset with a higher-quality, re-verified dataset
- [ ] Re-train and re-evaluate the model after the dataset update
- [ ] PDF medical report generation (formal, letterhead-style — beyond the current browser print)
- [ ] Public deployment (free-tier hosting for a demo version; separate reliable hosting for real clinical use)
- [ ] Offline/field deployment strategy for medical missions