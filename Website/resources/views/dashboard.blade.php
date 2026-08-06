<x-app-layout>
<div class="py-4">
<div class="mx-auto">

<style>
    :root {
        --bg: #EFF3F1; --surface: #FFFFFF; --ink: #16241F; --muted: #5C6B65;
        --brand: #1B4B43; --brand-soft: #E4ECE9; --accent: #B8862B; --border: #D9E0DC;
        --warn-bg: #FBF0DE; --warn-border: #E3B462; --warn-ink: #7A5310;
        --err-bg: #FBEAE8; --err-border: #E3A199; --err-ink: #8A2E24;
        --c-no-dr: #2F8F5B; --c-mild: #B7A233; --c-moderate: #D98B2B; --c-severe: #C2571F; --c-proliferate: #9E2B2B;
        --font-display: Georgia, 'Iowan Old Style', 'Palatino Linotype', serif;
        --font-body: -apple-system, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
        --font-mono: Consolas, 'SF Mono', 'Cascadia Code', 'Courier New', monospace;
    }
    * { box-sizing: border-box; }
    body { background: var(--bg); color: var(--ink); font-family: var(--font-body); line-height: 1.55; }
    .mono { font-family: var(--font-mono); }

    .layout { max-width: 1180px; margin: 20px auto; padding: 0 24px; display: grid; grid-template-columns: 1.1fr 0.9fr; gap: 24px; align-items: start; }
    @media (max-width: 900px) { .layout { grid-template-columns: 1fr; } }

    .panel { background: var(--surface); border: 1px solid var(--border); border-radius: 14px; padding: 28px; }
    .panel + .panel { margin-top: 24px; }

    .eyebrow { font-family: var(--font-mono); font-size: 0.7rem; letter-spacing: 0.12em; text-transform: uppercase; color: var(--accent); margin-bottom: 6px; display: block; }
    .panel h2 { font-family: var(--font-display); font-weight: 600; font-size: 1.2rem; margin: 0 0 4px; }
    .panel p.desc { margin: 0 0 20px; color: var(--muted); font-size: 0.9rem; }

    .dropzone { border: 1.5px dashed var(--border); border-radius: 10px; padding: 24px; display: flex; align-items: center; gap: 14px; transition: border-color 0.15s ease, background 0.15s ease; }
    .dropzone:hover, .dropzone.dragover { border-color: var(--accent); background: var(--brand-soft); }
    input[type="file"] { font-family: var(--font-body); font-size: 0.85rem; color: var(--muted); }

    .btn-row { display: flex; gap: 10px; margin-top: 18px; flex-wrap: wrap; }
    button { font-family: var(--font-body); font-weight: 600; font-size: 0.88rem; border: none; border-radius: 8px; padding: 11px 20px; cursor: pointer; transition: transform 0.1s ease, opacity 0.15s ease; }
    button:active { transform: scale(0.98); }
    button:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
    .btn-preview { background: var(--brand-soft); color: var(--brand); }
    .btn-preview:hover { background: #d7e3de; }
    .btn-analyze { background: var(--brand); color: #fff; }
    .btn-analyze:hover { opacity: 0.9; }
    .btn-print { background: var(--surface); color: var(--brand); border: 1px solid var(--border) !important; }
    .btn-print:hover { border-color: var(--brand) !important; }
    .btn-retry { background: var(--err-ink); color: #fff; }
    .btn-clear-log { background: var(--surface); color: var(--muted); border: 1px solid var(--border) !important; font-size: 0.8rem; padding: 7px 14px; }

    .image-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin-top: 22px; }
    .image-slot h3 { font-size: 0.72rem; letter-spacing: 0.06em; text-transform: uppercase; color: var(--muted); margin: 0 0 8px; font-weight: 600; }
    .image-slot img { width: 100%; aspect-ratio: 1; object-fit: cover; border-radius: 8px; border: 1px solid var(--border); display: none; background: var(--brand-soft); }

    .status-line { display: flex; align-items: center; gap: 10px; margin-bottom: 22px; font-family: var(--font-mono); font-size: 0.78rem; color: var(--muted); }
    .status-dot { width: 8px; height: 8px; border-radius: 50%; background: var(--border); flex-shrink: 0; }
    .status-dot.busy { background: var(--accent); animation: pulse 1s ease-in-out infinite; }
    .status-dot.ok { background: var(--c-no-dr); }
    .status-dot.err { background: var(--c-proliferate); }
    @keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.35; } }
    @media (prefers-reduced-motion: reduce) { .status-dot.busy { animation: none; } }

    .reliability-banner { display: none; align-items: flex-start; gap: 10px; background: var(--warn-bg); border: 1px solid var(--warn-border); color: var(--warn-ink); border-radius: 10px; padding: 13px 15px; font-size: 0.83rem; margin-bottom: 20px; line-height: 1.5; }
    .reliability-banner.show { display: flex; }
    .reliability-banner .icon { font-family: var(--font-mono); font-weight: 600; flex-shrink: 0; }

    .connection-error { display: none; background: var(--err-bg); border: 1px solid var(--err-border); color: var(--err-ink); border-radius: 10px; padding: 16px 18px; font-size: 0.85rem; margin-bottom: 4px; line-height: 1.5; }
    .connection-error.show { display: block; }
    .connection-error .title { font-weight: 700; margin-bottom: 4px; }
    .connection-error .btn-retry { margin-top: 12px; }

    .prediction-headline { font-family: var(--font-display); font-weight: 700; font-size: 2rem; margin: 0 0 4px; letter-spacing: -0.01em; }
    .confidence-line { font-family: var(--font-mono); font-size: 0.85rem; color: var(--muted); margin-bottom: 6px; }
    .quality-note { font-size: 0.78rem; color: var(--muted); margin-bottom: 22px; font-style: italic; }

    .gauge-wrap { margin-bottom: 26px; }
    .gauge-label { display: flex; justify-content: space-between; font-size: 0.68rem; letter-spacing: 0.05em; text-transform: uppercase; color: var(--muted); margin-bottom: 8px; }
    .gauge-track { position: relative; height: 10px; border-radius: 6px; background: linear-gradient(to right, var(--c-no-dr) 0%, var(--c-mild) 25%, var(--c-moderate) 50%, var(--c-severe) 75%, var(--c-proliferate) 100%); }
    .gauge-pointer { position: absolute; top: -6px; width: 3px; height: 22px; background: var(--ink); border-radius: 2px; transform: translateX(-50%); left: 10%; transition: left 0.5s cubic-bezier(0.2, 0.8, 0.2, 1); }

    .prob-row { display: grid; grid-template-columns: 100px 1fr 52px; align-items: center; gap: 10px; margin-bottom: 10px; font-size: 0.82rem; }
    .prob-name { color: var(--ink); font-weight: 500; }
    .prob-track { height: 6px; border-radius: 4px; background: var(--brand-soft); overflow: hidden; }
    .prob-fill { height: 100%; background: var(--brand); border-radius: 4px; transition: width 0.4s ease; }
    .prob-value { font-family: var(--font-mono); text-align: right; color: var(--muted); }

    .explanation { margin-top: 22px; padding-top: 20px; border-top: 1px solid var(--border); font-size: 0.88rem; color: var(--ink); }
    .explanation .eyebrow { margin-bottom: 8px; }

    .print-meta { display: none; font-family: var(--font-mono); font-size: 0.8rem; color: var(--muted); margin-bottom: 16px; }

    .disclaimer { margin-top: 24px; padding: 16px 18px; background: var(--brand-soft); border-radius: 10px; font-size: 0.78rem; color: var(--muted); line-height: 1.6; }
    .legend { display: flex; gap: 16px; flex-wrap: wrap; margin-top: 14px; font-size: 0.78rem; color: var(--muted); }
    .legend span { display: inline-flex; align-items: center; gap: 6px; }
    .legend i { width: 9px; height: 9px; border-radius: 50%; display: inline-block; }

    .empty-state { color: var(--muted); font-size: 0.88rem; padding: 30px 0; text-align: center; font-style: italic; }

    /* Full-bleed background — makes the whole page area match the palette
       instead of light cards floating on Breeze's default dark shell */
    .page-bleed {
        background: var(--bg);
        width: 100vw;
        position: relative;
        left: 50%;
        right: 50%;
        margin-left: -50vw;
        margin-right: -50vw;
        padding: 32px 0 60px;
    }

    /* Hero banner */
    .hero-banner {
        max-width: 1180px;
        margin: 0 auto 28px;
        padding: 0 24px;
    }
    .hero-inner {
        background: linear-gradient(135deg, var(--brand) 0%, #123832 100%);
        border-radius: 18px;
        padding: 40px 36px;
        color: #fff;
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 24px;
        flex-wrap: wrap;
        box-shadow: 0 10px 30px rgba(27,75,67,0.25);
    }
    .hero-text h1 {
        font-family: var(--font-display);
        font-weight: 700;
        font-size: 1.7rem;
        margin: 0 0 8px;
        letter-spacing: -0.01em;
    }
    .hero-text p {
        margin: 0;
        color: rgba(255,255,255,0.75);
        font-size: 0.92rem;
        max-width: 480px;
    }
    .hero-icon {
        width: 64px; height: 64px;
        border-radius: 50%;
        background: rgba(255,255,255,0.12);
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 1.8rem;
        flex-shrink: 0;
        border: 1px solid rgba(255,255,255,0.2);
    }

    /* Panel depth/hover polish */
    .panel {
        box-shadow: 0 1px 3px rgba(22,36,31,0.04);
        transition: box-shadow 0.2s ease, transform 0.2s ease;
    }
    .panel:hover { box-shadow: 0 6px 20px rgba(22,36,31,0.08); }

    .stage-card { box-shadow: 0 1px 2px rgba(22,36,31,0.03); }
    .stage-card:hover { transform: translateY(-1px); box-shadow: 0 4px 14px rgba(22,36,31,0.08); }

    .session-log-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 4px; }
    .log-empty { color: var(--muted); font-size: 0.85rem; font-style: italic; padding: 16px 0; }
    .log-list { display: flex; flex-direction: column; gap: 8px; max-height: 320px; overflow-y: auto; }
    .log-item { display: grid; grid-template-columns: 10px 1fr auto auto; align-items: center; gap: 12px; padding: 10px 12px; border: 1px solid var(--border); border-radius: 8px; cursor: pointer; font-size: 0.83rem; background: var(--surface); transition: border-color 0.15s ease, background 0.15s ease; }
    .log-item:hover { border-color: var(--accent); background: var(--brand-soft); }
    .log-item.active { border-color: var(--brand); background: var(--brand-soft); }
    .log-dot { width: 10px; height: 10px; border-radius: 50%; }
    .log-pred { font-weight: 600; }
    .log-time { color: var(--muted); font-family: var(--font-mono); font-size: 0.75rem; }
    .log-conf { font-family: var(--font-mono); color: var(--muted); font-size: 0.78rem; }
    .log-note { font-size: 0.76rem; color: var(--muted); margin-top: 10px; }

    .education { max-width: 1180px; margin: 24px auto 40px; padding: 0 24px; }
    .education-intro { background: var(--surface); border: 1px solid var(--border); border-radius: 14px; padding: 32px; margin-bottom: 24px; }
    .education-intro h2 { font-family: var(--font-display); font-weight: 600; font-size: 1.5rem; margin: 0 0 12px; }
    .education-intro p { color: var(--muted); font-size: 0.94rem; max-width: 760px; margin: 0 0 16px; }
    .symptom-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 12px; margin-top: 18px; }
    .symptom-chip { border: 1px solid var(--border); border-radius: 8px; padding: 12px 14px; font-size: 0.85rem; display: flex; align-items: center; gap: 10px; }
    .symptom-chip::before { content: ""; width: 6px; height: 6px; border-radius: 50%; background: var(--accent); flex-shrink: 0; }
    .scale-header { display: flex; align-items: baseline; justify-content: space-between; margin-bottom: 18px; flex-wrap: wrap; gap: 8px; }
    .scale-header h2 { font-family: var(--font-display); font-weight: 600; font-size: 1.3rem; margin: 0; }
    .scale-header span.tag { font-family: var(--font-mono); font-size: 0.72rem; color: var(--muted); letter-spacing: 0.04em; }
    .stage-cards { display: grid; gap: 14px; margin-bottom: 24px; }
    .stage-card { background: var(--surface); border: 1px solid var(--border); border-radius: 12px; padding: 20px 22px; display: grid; grid-template-columns: 64px 1fr; gap: 18px; align-items: start; transition: border-color 0.3s ease, box-shadow 0.3s ease, background 0.3s ease; scroll-margin-top: 100px; }
    .stage-card.active { border-color: var(--stage-color, var(--accent)); box-shadow: 0 0 0 3px color-mix(in srgb, var(--stage-color, var(--accent)) 18%, transparent); background: color-mix(in srgb, var(--stage-color, var(--accent)) 5%, var(--surface)); }
    .stage-number { width: 44px; height: 44px; border-radius: 50%; background: var(--stage-color); color: #fff; font-family: var(--font-mono); font-weight: 500; font-size: 0.95rem; display: flex; align-items: center; justify-content: center; }
    .stage-body h3 { font-family: var(--font-display); font-weight: 600; font-size: 1.08rem; margin: 0 0 4px; }
    .stage-body .clinical-name { font-family: var(--font-mono); font-size: 0.72rem; color: var(--muted); text-transform: uppercase; letter-spacing: 0.04em; margin-bottom: 10px; display: block; }
    .stage-body p { margin: 0 0 8px; font-size: 0.88rem; color: var(--ink); }
    .stage-body .criteria { color: var(--muted); font-size: 0.85rem; }
    .active-badge { display: none; font-family: var(--font-mono); font-size: 0.68rem; letter-spacing: 0.06em; text-transform: uppercase; background: var(--stage-color); color: #fff; padding: 3px 9px; border-radius: 999px; margin-left: 10px; vertical-align: middle; }
    .stage-card.active .active-badge { display: inline-block; }

    .learn-more-btn {
        background: none;
        border: 1px solid var(--border) !important;
        color: var(--brand);
        font-size: 0.78rem;
        padding: 6px 12px;
        margin-top: 4px;
    }
    .learn-more-btn:hover { border-color: var(--brand) !important; background: var(--brand-soft); }

    .stage-detail {
        display: none;
        margin-top: 14px;
        padding-top: 14px;
        border-top: 1px solid var(--border);
        font-size: 0.85rem;
        color: var(--ink);
    }
    .stage-detail.open { display: block; }
    .stage-detail h4 {
        font-size: 0.72rem;
        letter-spacing: 0.05em;
        text-transform: uppercase;
        color: var(--accent);
        margin: 14px 0 6px;
    }
    .stage-detail h4:first-child { margin-top: 0; }
    .stage-detail p { margin: 0 0 4px; color: var(--muted); line-height: 1.6; }

    .about-panel { background: var(--surface); border: 1px solid var(--border); border-radius: 14px; padding: 32px; }
    .about-panel h2 { font-family: var(--font-display); font-weight: 600; font-size: 1.3rem; margin: 0 0 18px; }
    .about-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 22px; margin-bottom: 22px; }
    .about-item .label { font-family: var(--font-mono); font-size: 0.7rem; letter-spacing: 0.05em; text-transform: uppercase; color: var(--accent); margin-bottom: 6px; }
    .about-item .value { font-size: 0.92rem; color: var(--ink); }
    .limitations-box { background: var(--brand-soft); border-radius: 10px; padding: 16px 18px; font-size: 0.84rem; color: var(--muted); line-height: 1.65; }
    .limitations-box strong { color: var(--ink); }

    @media print {
        header, nav, .no-print, .btn-row, .btn-print,
        .status-line, .session-log-panel, .education, .hero-banner {
            display: none !important;
        }
        body { background: #fff; }
        .page-bleed { background: #fff; padding: 0; }
        .layout { display: block; margin: 0; padding: 0; max-width: 100%; }
        .panel { border: none; padding: 0; box-shadow: none; margin-bottom: 20px; }
        .print-meta { display: block !important; }
        .image-grid { grid-template-columns: 1fr 1fr; page-break-inside: avoid; }
        .image-slot img { display: block !important; }
    }
</style>

<div class="page-bleed">

<div class="hero-banner">
    <div class="hero-inner">
        <div class="hero-text">
            <h1 data-i18n="hero_title">AI-Assisted Retinal Screening</h1>
            <p data-i18n="hero_desc">Upload a retinal fundus image for ICDR-based diabetic retinopathy classification, with Grad-CAM explainability and full clinical reference material.</p>
        </div>
        <div class="hero-icon">👁</div>
    </div>
    <div style="text-align:right; margin-top:10px;">
        <button id="langToggle" onclick="toggleLanguage()" style="background:rgba(255,255,255,0.15); color:#fff; border:1px solid rgba(255,255,255,0.3) !important; font-size:0.78rem; padding:6px 14px;">🌐 Filipino / English</button>
    </div>
</div>

<div class="layout">

    <div>
        <div class="panel">
            <span class="eyebrow no-print" data-i18n="eyebrow_input">01 — Input</span>
            <h2 class="no-print" data-i18n="upload_title">Upload Retinal Image</h2>
            <p class="desc no-print" data-i18n="upload_desc">Select a retinal fundus image to analyze.</p>

            <div class="dropzone no-print" id="dropzone">
                <input type="file" id="imageInput" accept="image/*" aria-label="Upload retinal fundus image">
            </div>

            <div class="no-print" style="margin-top:14px;">
                <label for="eyeSide" data-i18n="eye_label" style="font-size:0.78rem; color:var(--muted); display:block; margin-bottom:6px;">Eye</label>
                <select id="eyeSide" aria-label="Select which eye this image is from" style="width:100%; padding:8px 10px; border:1px solid var(--border); border-radius:8px; font-family:var(--font-body); font-size:0.85rem; color:var(--ink); background:var(--surface);">
                    <option value="" data-i18n="eye_not_specified">Not specified</option>
                    <option value="OD (Right Eye)" data-i18n="eye_od">OD — Right Eye</option>
                    <option value="OS (Left Eye)" data-i18n="eye_os">OS — Left Eye</option>
                </select>
            </div>

            <div class="btn-row">
                <button class="btn-preview" onclick="previewImage()" data-i18n="btn_preview">Preview Image</button>
                <button class="btn-analyze" onclick="analyzeImage()" data-i18n="btn_analyze">Analyze Image</button>
            </div>

            <div class="image-grid">
                <div class="image-slot">
                    <h3>Original</h3>
                    <img id="preview" alt="Uploaded retinal image">
                </div>
                <div class="image-slot">
                    <h3>Grad-CAM Attention</h3>
                    <img id="gradcam" alt="Grad-CAM heatmap overlay">
                </div>
            </div>
        </div>

        <div class="panel session-log-panel">
            <div class="session-log-header">
                <div>
                    <span class="eyebrow" data-i18n="eyebrow_log">Session Log</span>
                    <h2 data-i18n="log_title">Recent Analyses</h2>
                </div>
                <div style="display:flex; gap:6px;">
                    <button class="btn-clear-log" onclick="clearSessionLog()" aria-label="Clear session log">Clear</button>
                    <button class="btn-clear-log" onclick="exportSessionLogCSV()" aria-label="Export session log as CSV file">Export CSV</button>
                </div>
            </div>
            <p class="desc" data-i18n="log_desc" style="margin-bottom:14px;">Results from this browsing session — click one to view it again. Cleared automatically when you close this tab.</p>
            <div id="logList"></div>
            <p class="log-note" data-i18n="log_note">Not saved to any database or patient record — this list exists only in your browser and disappears when the tab closes.</p>
        </div>
    </div>

    <div class="panel">
        <span class="eyebrow" data-i18n="eyebrow_readout">02 — Readout</span>
        <h2 data-i18n="results_title">Prediction Results</h2>

        <div class="status-line" role="status" aria-live="polite">
            <span class="status-dot" id="statusDot" aria-hidden="true"></span>
            <span id="status" data-i18n="status_awaiting">Awaiting image</span>
        </div>

        <div class="connection-error" id="connectionError">
            <div class="title">Could not reach the AI server</div>
            <div>Check that the AI server is running and your device is connected to the same network, then try again.</div>
            <button class="btn-retry" onclick="analyzeImage()">Retry Analysis</button>
        </div>

        <div id="resultsBody">
            <div class="empty-state" id="emptyState">
                Upload and analyze an image to see results here.
            </div>

            <div id="filledState" style="display:none;">

                <div class="print-meta" id="printMeta"></div>

                <div class="reliability-banner" id="reliabilityBanner">
                    <span class="icon">⚠</span>
                    <span id="reliabilityText"></span>
                </div>

                <div class="prediction-headline" id="prediction">—</div>
                <div class="confidence-line">Confidence: <span id="confidence">—</span></div>
                <div class="quality-note" id="qualityNote"></div>

                <div class="gauge-wrap">
                    <div class="gauge-label"><span data-i18n="legend_no_dr">No DR</span><span data-i18n="legend_pdr">Proliferate DR</span></div>
                    <div class="gauge-track"><div class="gauge-pointer" id="gaugePointer"></div></div>
                </div>

                <div id="probabilities"></div>

                <div class="explanation">
                    <span class="eyebrow">AI Explanation</span>
                    <p id="explanation" style="margin:0;">—</p>
                </div>

                <div class="btn-row">
                    <button class="btn-print" onclick="window.print()" aria-label="Save or print this result">🖨 Save / Print This Result</button>
                </div>
            </div>
        </div>

        <div class="disclaimer" data-i18n="disclaimer">
            This AI system is designed to assist healthcare professionals in the classification of diabetic retinopathy using retinal fundus images. The prediction, confidence score, probability distribution, and Grad-CAM visualization are generated for decision support purposes only. Final medical decisions should always be made by a licensed ophthalmologist or qualified healthcare professional after clinical evaluation.
        </div>

        <div class="legend">
            <span><i style="background:var(--c-no-dr)"></i> <span data-i18n="legend_no_dr">No DR</span></span>
            <span><i style="background:var(--c-mild)"></i> <span data-i18n="legend_mild">Mild</span></span>
            <span><i style="background:var(--c-moderate)"></i> <span data-i18n="legend_moderate">Moderate</span></span>
            <span><i style="background:var(--c-severe)"></i> <span data-i18n="legend_severe">Severe</span></span>
            <span><i style="background:var(--c-proliferate)"></i> <span data-i18n="legend_pdr">Proliferate DR</span></span>
        </div>
    </div>

</div>

<div class="education">

    <div class="education-intro">
        <span class="eyebrow" data-i18n="eyebrow_reference">03 — Reference</span>
        <h2 data-i18n="edu_title">Understanding Diabetic Retinopathy</h2>
        <p data-i18n="edu_p1">
            Diabetic retinopathy (DR) is damage to the blood vessels of the retina caused by prolonged high blood sugar levels. It is one of the leading causes of vision loss among working-age adults, and progresses through distinct clinical stages — often with no symptoms in its earliest phase, which is why regular screening matters even when vision feels normal.
        </p>
        <p data-i18n="edu_p2">Symptoms often don't appear until the disease has progressed. Common warning signs include:</p>

        <div class="symptom-grid">
            <div class="symptom-chip" data-i18n="symptom_1">Blurred or fluctuating vision</div>
            <div class="symptom-chip" data-i18n="symptom_2">Floaters or dark spots</div>
            <div class="symptom-chip" data-i18n="symptom_3">Empty or dark areas in vision</div>
            <div class="symptom-chip" data-i18n="symptom_4">Difficulty seeing at night</div>
            <div class="symptom-chip" data-i18n="symptom_5">Impaired color vision</div>
            <div class="symptom-chip" data-i18n="symptom_6">Sudden or gradual vision loss</div>
        </div>
    </div>

    <div class="scale-header">
        <h2 data-i18n="icdr_title">ICDR Disease Severity Scale</h2>
        <span class="tag" data-i18n="icdr_tag">International Clinical Diabetic Retinopathy Scale</span>
    </div>

    <div class="stage-cards" id="stageCards">

        <div class="stage-card" data-stage="No_DR" style="--stage-color: var(--c-no-dr);">
            <div class="stage-number">0</div>
            <div class="stage-body">
                <h3><span data-i18n="stage0_title">No Apparent Retinopathy</span> <span class="active-badge">AI Result</span></h3>
                <span class="clinical-name">No_DR</span>
                <p>No visible abnormalities on retinal examination. The blood vessels of the retina appear structurally normal.</p>
                <p class="criteria"><strong>Clinical criteria:</strong> No microaneurysms or hemorrhages present.</p>
                <button class="learn-more-btn" aria-expanded="false" onclick="toggleStageDetail('detail-no-dr')">Learn More ▾</button>
                <div class="stage-detail" id="detail-no-dr">
                    <h4>Follow-Up</h4>
                    <p>Annual dilated eye exams are typically recommended, even with no current signs of retinopathy, since DR risk accumulates with duration of diabetes.</p>
                    <h4>Risk Factors for Progression</h4>
                    <p>Poor glycemic control (elevated HbA1c), hypertension, and dyslipidemia are the primary modifiable risk factors associated with developing retinopathy over time.</p>
                </div>
            </div>
        </div>

        <div class="stage-card" data-stage="Mild" style="--stage-color: var(--c-mild);">
            <div class="stage-number">1</div>
            <div class="stage-body">
                <h3><span data-i18n="stage1_title">Mild Nonproliferative DR</span> <span class="active-badge">AI Result</span></h3>
                <span class="clinical-name">Mild NPDR</span>
                <p>The earliest visible stage. Small areas of balloon-like swelling appear in the retina's tiny blood vessels.</p>
                <p class="criteria"><strong>Clinical criteria:</strong> Microaneurysms only.</p>
                <button class="learn-more-btn" aria-expanded="false" onclick="toggleStageDetail('detail-mild')">Learn More ▾</button>
                <div class="stage-detail" id="detail-mild">
                    <h4>Follow-Up</h4>
                    <p>Typically re-examined annually. Usually asymptomatic at this stage — vision is not yet noticeably affected.</p>
                    <h4>Progression Risk</h4>
                    <p>Can remain stable for years or progress, particularly with poor glycemic control. Tighter blood sugar management can slow or halt progression.</p>
                </div>
            </div>
        </div>

        <div class="stage-card" data-stage="Moderate" style="--stage-color: var(--c-moderate);">
            <div class="stage-number">2</div>
            <div class="stage-body">
                <h3><span data-i18n="stage2_title">Moderate Nonproliferative DR</span> <span class="active-badge">AI Result</span></h3>
                <span class="clinical-name">Moderate NPDR</span>
                <p>Blood vessels that nourish the retina become blocked, and more extensive changes are visible than in the mild stage.</p>
                <p class="criteria"><strong>Clinical criteria:</strong> More than microaneurysms alone, but less than the severe stage's defined threshold.</p>
                <button class="learn-more-btn" aria-expanded="false" onclick="toggleStageDetail('detail-moderate')">Learn More ▾</button>
                <div class="stage-detail" id="detail-moderate">
                    <h4>Follow-Up</h4>
                    <p>Re-examination is typically recommended every 6–12 months given increased progression risk compared to Mild NPDR.</p>
                    <h4>Possible Complications</h4>
                    <p>Diabetic macular edema (fluid buildup in the central retina) can occur at this stage or later, and is a leading cause of vision impairment in DR — worth screening for specifically, as it can occur independently of overall DR severity.</p>
                </div>
            </div>
        </div>

        <div class="stage-card" data-stage="Severe" style="--stage-color: var(--c-severe);">
            <div class="stage-number">3</div>
            <div class="stage-body">
                <h3><span data-i18n="stage3_title">Severe Nonproliferative DR</span> <span class="active-badge">AI Result</span></h3>
                <span class="clinical-name">Severe NPDR</span>
                <p>A significant number of blood vessels are blocked, depriving areas of the retina of their blood supply. These areas signal the retina to grow new blood vessels.</p>
                <p class="criteria"><strong>Clinical criteria (4-2-1 rule — any one qualifies):</strong> &gt;20 intraretinal hemorrhages in each of 4 quadrants; definite venous beading in ≥2 quadrants; prominent intraretinal microvascular abnormalities (IRMA) in ≥1 quadrant — with no signs of proliferative disease yet.</p>
                <button class="learn-more-btn" aria-expanded="false" onclick="toggleStageDetail('detail-severe')">Learn More ▾</button>
                <div class="stage-detail" id="detail-severe">
                    <h4>Follow-Up</h4>
                    <p>Close monitoring is warranted, often every 2–4 months, given substantial risk of progression to proliferative disease within about a year if untreated.</p>
                    <h4>Treatment Considerations</h4>
                    <p>Early panretinal photocoagulation (PRP) laser treatment may be considered at this stage in some cases, particularly if follow-up compliance is uncertain — this is a clinical judgment call for the treating ophthalmologist, not something this tool determines.</p>
                </div>
            </div>
        </div>

        <div class="stage-card" data-stage="Proliferate_DR" style="--stage-color: var(--c-proliferate);">
            <div class="stage-number">4</div>
            <div class="stage-body">
                <h3><span data-i18n="stage4_title">Proliferative DR</span> <span class="active-badge">AI Result</span></h3>
                <span class="clinical-name">PDR</span>
                <p>The most advanced stage. The retina grows new, abnormal blood vessels (neovascularization) that are fragile and prone to leaking, which can lead to significant vision loss if untreated.</p>
                <p class="criteria"><strong>Clinical criteria:</strong> Neovascularization and/or vitreous or preretinal hemorrhage.</p>
                <button class="learn-more-btn" aria-expanded="false" onclick="toggleStageDetail('detail-pdr')">Learn More ▾</button>
                <div class="stage-detail" id="detail-pdr">
                    <h4>Urgency</h4>
                    <p>Requires prompt ophthalmologic evaluation — this stage carries meaningful risk of severe, potentially irreversible vision loss without timely treatment.</p>
                    <h4>Possible Complications</h4>
                    <p>Vitreous hemorrhage (bleeding into the eye's gel) and tractional retinal detachment are serious complications associated with untreated PDR.</p>
                    <h4>Treatment Approaches</h4>
                    <p>Panretinal photocoagulation (PRP) laser, anti-VEGF injections, and vitrectomy surgery (for advanced complications) are standard treatment options — the appropriate choice depends on individual clinical presentation and is determined by the treating ophthalmologist.</p>
                </div>
            </div>
        </div>

    </div>

    <div class="about-panel">
        <span class="eyebrow" data-i18n="eyebrow_transparency">04 — Transparency</span>
        <h2 data-i18n="about_title">About This AI</h2>

        <div class="about-grid">
            <div class="about-item">
                <div class="label" data-i18n="about_arch_label">Model Architecture</div>
                <div class="value">EfficientNetB0 (transfer learning)</div>
            </div>
            <div class="about-item">
                <div class="label" data-i18n="about_dataset_label">Training Dataset</div>
                <div class="value">35,110 retinal fundus images</div>
            </div>
            <div class="about-item">
                <div class="label" data-i18n="about_scale_label">Classification Scale</div>
                <div class="value">ICDR 5-stage severity</div>
            </div>
            <div class="about-item">
                <div class="label" data-i18n="about_explain_label">Explainability</div>
                <div class="value">Grad-CAM attention mapping</div>
            </div>
        </div>

        <div class="limitations-box">
            <strong>Limitations:</strong> This model was trained on a fixed dataset and may not generalize perfectly to all imaging equipment, populations, or edge cases. It is a decision-support tool, not a diagnostic authority — every result should be interpreted by a qualified healthcare professional. The system includes an automated image quality check to reject unsuitable photos, but no automated system is completely free of error. Confidence and probability scores reflect the model's internal certainty, not a guarantee of clinical accuracy.
        </div>
    </div>

</div>

<script>
const severityOrder = ["No_DR", "Mild", "Moderate", "Severe", "Proliferate_DR"];
const severityColor = {
    "No_DR": "var(--c-no-dr)", "Mild": "var(--c-mild)", "Moderate": "var(--c-moderate)",
    "Severe": "var(--c-severe)", "Proliferate_DR": "var(--c-proliferate)"
};

const LOG_KEY = "drSessionLog";
const LOG_MAX = 25;
let activeLogId = null;

function getSessionLog(){
    try { return JSON.parse(sessionStorage.getItem(LOG_KEY)) || []; }
    catch { return []; }
}

function saveSessionLog(log){
    sessionStorage.setItem(LOG_KEY, JSON.stringify(log));
}

function addToSessionLog(entry){
    const log = getSessionLog();
    log.unshift(entry);
    if (log.length > LOG_MAX) log.pop();
    saveSessionLog(log);
    renderSessionLog();
}

function clearSessionLog(){
    sessionStorage.removeItem(LOG_KEY);
    activeLogId = null;
    renderSessionLog();
}

function exportSessionLogCSV(){
    const log = getSessionLog();
    if (log.length === 0){
        alert("No analyses to export yet.");
        return;
    }

    const headers = ["Date/Time", "Eye", "Prediction", "Confidence", "No_DR %", "Mild %", "Moderate %", "Severe %", "Proliferate_DR %", "Quality Note"];
    const rows = log.map(e => [
        e.timeLabel || "",
        e.eyeSide || "Not specified",
        e.prediction || "",
        e.confidence || "",
        e.probabilities?.No_DR?.toFixed(2) ?? "",
        e.probabilities?.Mild?.toFixed(2) ?? "",
        e.probabilities?.Moderate?.toFixed(2) ?? "",
        e.probabilities?.Severe?.toFixed(2) ?? "",
        e.probabilities?.Proliferate_DR?.toFixed(2) ?? "",
        (e.quality_note || "").replace(/,/g, ";")
    ]);

    const csvContent = [headers, ...rows]
        .map(row => row.map(cell => `"${String(cell).replace(/"/g, '""')}"`).join(","))
        .join("\n");

    const blob = new Blob([csvContent], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = `dr-session-log-${new Date().toISOString().slice(0,19).replace(/:/g,"-")}.csv`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
}

function renderSessionLog(){
    const log = getSessionLog();
    const container = document.getElementById("logList");

    if (log.length === 0){
        container.innerHTML = '<div class="log-empty">No analyses yet this session.</div>';
        return;
    }

    container.innerHTML = '<div class="log-list">' + log.map(entry => `
        <div class="log-item ${entry.id === activeLogId ? 'active' : ''}" onclick="loadFromLog('${entry.id}')">
            <span class="log-dot" style="background:${severityColor[entry.prediction] || 'var(--border)'}"></span>
            <span class="log-pred">${(entry.prediction || '—').replace('_',' ')}${entry.eyeSide ? ' · ' + entry.eyeSide : ''}</span>
            <span class="log-conf mono">${entry.confidence}</span>
            <span class="log-time">${entry.time}</span>
        </div>
    `).join('') + '</div>';
}

function loadFromLog(id){
    const log = getSessionLog();
    const entry = log.find(e => e.id === id);
    if (!entry) return;

    activeLogId = id;
    renderSessionLog();
    renderResult(entry, false);
}

function previewImage(){
    const input = document.getElementById("imageInput");
    const preview = document.getElementById("preview");
    if (input.files.length === 0){ alert("Choose an image first."); return; }
    preview.src = URL.createObjectURL(input.files[0]);
    preview.style.display = "block";
}

// Drag-and-drop support for the dropzone
const dropzoneEl = document.getElementById("dropzone");
dropzoneEl.addEventListener("dragover", (e) => {
    e.preventDefault();
    dropzoneEl.classList.add("dragover");
});
dropzoneEl.addEventListener("dragleave", () => {
    dropzoneEl.classList.remove("dragover");
});
dropzoneEl.addEventListener("drop", (e) => {
    e.preventDefault();
    dropzoneEl.classList.remove("dragover");
    if (e.dataTransfer.files.length > 0){
        document.getElementById("imageInput").files = e.dataTransfer.files;
        previewImage();
    }
});

function setStatus(text, mode){
    document.getElementById("status").textContent = text;
    document.getElementById("statusDot").className = "status-dot" + (mode ? " " + mode : "");
}

function highlightStage(prediction){
    document.querySelectorAll(".stage-card").forEach(card => card.classList.remove("active"));
    if (!prediction) return;
    const match = document.querySelector(`.stage-card[data-stage="${prediction}"]`);
    if (match){
        match.classList.add("active");
        match.scrollIntoView({ behavior: "smooth", block: "center" });
    }
}

function toggleStageDetail(id){
    const detail = document.getElementById(id);
    const btn = detail.previousElementSibling;
    const isOpen = detail.classList.toggle("open");
    btn.textContent = isOpen ? "Show Less ▴" : "Learn More ▾";
    btn.setAttribute("aria-expanded", isOpen ? "true" : "false");
}

// ================= Language Toggle =================
// Covers static interface text. Dynamic AI-generated explanation text
// (from the backend) stays English-only for now — translating that would
// require duplicating logic server-side, out of scope for this pass.

const translations = {
    en: {
        hero_title: "AI-Assisted Retinal Screening",
        hero_desc: "Upload a retinal fundus image for ICDR-based diabetic retinopathy classification, with Grad-CAM explainability and full clinical reference material.",
        eyebrow_input: "01 — Input",
        upload_title: "Upload Retinal Image",
        upload_desc: "Select a retinal fundus image to analyze.",
        eye_label: "Eye",
        eye_not_specified: "Not specified",
        eye_od: "OD — Right Eye",
        eye_os: "OS — Left Eye",
        btn_preview: "Preview Image",
        btn_analyze: "Analyze Image",
        eyebrow_log: "Session Log",
        log_title: "Recent Analyses",
        log_desc: "Results from this browsing session — click one to view it again. Cleared automatically when you close this tab.",
        log_note: "Not saved to any database or patient record — this list exists only in your browser and disappears when the tab closes.",
        eyebrow_readout: "02 — Readout",
        results_title: "Prediction Results",
        status_awaiting: "Awaiting image",
        legend_no_dr: "No DR",
        legend_mild: "Mild",
        legend_moderate: "Moderate",
        legend_severe: "Severe",
        legend_pdr: "Proliferate DR",
        disclaimer: "This AI system is designed to assist healthcare professionals in the classification of diabetic retinopathy using retinal fundus images. The prediction, confidence score, probability distribution, and Grad-CAM visualization are generated for decision support purposes only. Final medical decisions should always be made by a licensed ophthalmologist or qualified healthcare professional after clinical evaluation.",
        eyebrow_reference: "03 — Reference",
        edu_title: "Understanding Diabetic Retinopathy",
        edu_p1: "Diabetic retinopathy (DR) is damage to the blood vessels of the retina caused by prolonged high blood sugar levels. It is one of the leading causes of vision loss among working-age adults, and progresses through distinct clinical stages — often with no symptoms in its earliest phase, which is why regular screening matters even when vision feels normal.",
        edu_p2: "Symptoms often don't appear until the disease has progressed. Common warning signs include:",
        symptom_1: "Blurred or fluctuating vision",
        symptom_2: "Floaters or dark spots",
        symptom_3: "Empty or dark areas in vision",
        symptom_4: "Difficulty seeing at night",
        symptom_5: "Impaired color vision",
        symptom_6: "Sudden or gradual vision loss",
        icdr_title: "ICDR Disease Severity Scale",
        icdr_tag: "International Clinical Diabetic Retinopathy Scale",
        stage0_title: "No Apparent Retinopathy",
        stage1_title: "Mild Nonproliferative DR",
        stage2_title: "Moderate Nonproliferative DR",
        stage3_title: "Severe Nonproliferative DR",
        stage4_title: "Proliferative DR",
        eyebrow_transparency: "04 — Transparency",
        about_title: "About This AI",
        about_arch_label: "Model Architecture",
        about_dataset_label: "Training Dataset",
        about_scale_label: "Classification Scale",
        about_explain_label: "Explainability"
    },
    fil: {
        hero_title: "AI na Tulong sa Pagsusuri ng Retina",
        hero_desc: "Mag-upload ng larawan ng retina para sa klasipikasyon ng diabetic retinopathy batay sa ICDR, kasama ang Grad-CAM na paliwanag at kumpletong sanggunian sa klinika.",
        eyebrow_input: "01 — Input",
        upload_title: "I-upload ang Larawan ng Retina",
        upload_desc: "Pumili ng larawan ng retina para suriin.",
        eye_label: "Mata",
        eye_not_specified: "Hindi tinukoy",
        eye_od: "OD — Kanang Mata",
        eye_os: "OS — Kaliwang Mata",
        btn_preview: "I-preview ang Larawan",
        btn_analyze: "Suriin ang Larawan",
        eyebrow_log: "Talaan ng Sesyon",
        log_title: "Kamakailang Pagsusuri",
        log_desc: "Mga resulta mula sa sesyong ito — i-click ang isa para makita muli. Awtomatikong nabubura kapag isinara ang tab.",
        log_note: "Hindi ito nase-save sa anumang database o talaan ng pasyente — nasa browser mo lang ito at mawawala kapag isinara ang tab.",
        eyebrow_readout: "02 — Resulta",
        results_title: "Resulta ng Pagsusuri",
        status_awaiting: "Naghihintay ng larawan",
        legend_no_dr: "Walang DR",
        legend_mild: "Banayad",
        legend_moderate: "Katamtaman",
        legend_severe: "Malubha",
        legend_pdr: "Proliferate DR",
        disclaimer: "Ang AI system na ito ay idinisenyo upang tumulong sa mga propesyonal sa kalusugan sa pag-uuri ng diabetic retinopathy gamit ang mga larawan ng retina. Ang prediksyon, confidence score, probability distribution, at Grad-CAM visualization ay ginawa para sa layuning suporta sa desisyon lamang. Ang huling desisyong medikal ay dapat palaging gawin ng lisensyadong ophthalmologist o kwalipikadong propesyonal sa kalusugan pagkatapos ng klinikal na ebalwasyon.",
        eyebrow_reference: "03 — Sanggunian",
        edu_title: "Pag-unawa sa Diabetic Retinopathy",
        edu_p1: "Ang diabetic retinopathy (DR) ay pinsala sa mga daluyan ng dugo ng retina dulot ng matagal na mataas na asukal sa dugo. Isa ito sa mga pangunahing sanhi ng pagkawala ng paningin sa mga nasa edad na nagtatrabaho, at umuusad sa iba't ibang klinikal na yugto — kadalasan ay walang sintomas sa unang yugto, kaya mahalaga ang regular na pagsusuri kahit normal ang pakiramdam sa paningin.",
        edu_p2: "Kadalasan ay hindi lumalabas ang mga sintomas hangga't hindi umuusad ang sakit. Kabilang sa mga karaniwang babala ay:",
        symptom_1: "Malabo o pabago-bagong paningin",
        symptom_2: "Mga lumulutang o madidilim na bahagi",
        symptom_3: "Walang laman o madilim na bahagi ng paningin",
        symptom_4: "Hirap makakita sa gabi",
        symptom_5: "Kapansanan sa pagkilala ng kulay",
        symptom_6: "Biglaan o unti-unting pagkawala ng paningin",
        icdr_title: "ICDR Antas ng Kalubhaan ng Sakit",
        icdr_tag: "International Clinical Diabetic Retinopathy Scale",
        stage0_title: "Walang Kapansin-pansing Retinopathy",
        stage1_title: "Banayad na Nonproliferative DR",
        stage2_title: "Katamtamang Nonproliferative DR",
        stage3_title: "Malubhang Nonproliferative DR",
        stage4_title: "Proliferative DR",
        eyebrow_transparency: "04 — Transparency",
        about_title: "Tungkol sa AI na Ito",
        about_arch_label: "Arkitektura ng Modelo",
        about_dataset_label: "Dataset ng Pagsasanay",
        about_scale_label: "Sukat ng Klasipikasyon",
        about_explain_label: "Explainability"
    }
};

function toggleLanguage(){
    const current = localStorage.getItem("drLang") || "en";
    const next = current === "en" ? "fil" : "en";
    applyLanguage(next);
    localStorage.setItem("drLang", next);
}

function applyLanguage(lang){
    const dict = translations[lang] || translations.en;
    document.querySelectorAll("[data-i18n]").forEach(el => {
        const key = el.getAttribute("data-i18n");
        if (dict[key]){
            if (el.tagName === "OPTION") { el.textContent = dict[key]; }
            else { el.textContent = dict[key]; }
        }
    });
    document.documentElement.setAttribute("lang", lang === "fil" ? "fil" : "en");
}

// Apply saved language preference on load
applyLanguage(localStorage.getItem("drLang") || "en");

function updateReliabilityBanner(probabilities, confidenceStr){
    const banner = document.getElementById("reliabilityBanner");
    const text = document.getElementById("reliabilityText");
    if (!probabilities){ banner.classList.remove("show"); return; }

    const confidence = parseFloat(confidenceStr);
    const sorted = Object.values(probabilities).sort((a,b) => b-a);
    const top = sorted[0] ?? 0, second = sorted[1] ?? 0, margin = top - second;
    const lowConfidence = confidence < 60, ambiguous = margin < 15;

    if (lowConfidence || ambiguous){
        let reason = lowConfidence
            ? "The AI's confidence in this result is below 60%."
            : `The top two possible stages are close in probability (within ${margin.toFixed(1)}%), meaning the result is less clear-cut.`;
        text.textContent = `Low-confidence result — ${reason} Clinical correlation and professional review are recommended before relying on this result.`;
        banner.classList.add("show");
    } else {
        banner.classList.remove("show");
    }
}

function renderResult(data, isNew){
    document.getElementById("emptyState").style.display = "none";
    document.getElementById("filledState").style.display = "block";
    document.getElementById("connectionError").classList.remove("show");

    const isError = data.status === "Error";

    document.getElementById("prediction").textContent = data.prediction || "—";
    document.getElementById("confidence").textContent = data.confidence || "—";
    document.getElementById("explanation").textContent = data.message || "—";
    document.getElementById("qualityNote").textContent = data.quality_note ? `Image quality check: ${data.quality_note}` : "";

    setStatus(isError ? "Rejected" : (isNew ? "Complete" : "Viewing past result"), isError ? "err" : "ok");

    const idx = severityOrder.indexOf(data.prediction);
    const pointer = document.getElementById("gaugePointer");
    if (idx >= 0){
        pointer.style.left = `${(idx / (severityOrder.length - 1)) * 100}%`;
        pointer.style.background = severityColor[data.prediction];
    } else {
        pointer.style.left = "0%";
        pointer.style.background = "var(--border)";
    }

    const gradcam = document.getElementById("gradcam");
    if (data.heatmap){
        gradcam.src = "/heatmaps/" + data.heatmap + (isNew ? ("?t=" + new Date().getTime()) : "");
        gradcam.style.display = "block";
    } else {
        gradcam.style.display = "none";
    }

    let html = "";
    if (data.probabilities){
        for (const [name, value] of Object.entries(data.probabilities)){
            html += `
                <div class="prob-row">
                    <span class="prob-name">${name.replace("_", " ")}</span>
                    <div class="prob-track"><div class="prob-fill" style="width:${value}%; background:${severityColor[name] || "var(--brand)"}"></div></div>
                    <span class="prob-value mono">${value.toFixed(2)}%</span>
                </div>
            `;
        }
    }
    document.getElementById("probabilities").innerHTML = html;

    if (!isError){
        const stamp = data.timeLabel || new Date().toLocaleString();
        const eyeLabel = data.eyeSide ? ` — ${data.eyeSide}` : "";
        document.getElementById("printMeta").textContent =
            `Diabetic Retinopathy Classification System — Report generated ${stamp}${eyeLabel}`;
        updateReliabilityBanner(data.probabilities, data.confidence);
        highlightStage(data.prediction);
    }

    if (isNew && !isError){
        const entry = {
            id: crypto.randomUUID ? crypto.randomUUID() : String(Date.now()),
            time: new Date().toLocaleTimeString(),
            timeLabel: new Date().toLocaleString(),
            prediction: data.prediction,
            confidence: data.confidence,
            message: data.message,
            quality_note: data.quality_note,
            probabilities: data.probabilities,
            heatmap: data.heatmap,
            status: data.status,
            eyeSide: data.eyeSide
        };
        activeLogId = entry.id;
        addToSessionLog(entry);
    }
}

function analyzeImage(){
    const input = document.getElementById("imageInput");
    if (input.files.length === 0){ alert("Choose an image first."); return; }

    document.getElementById("connectionError").classList.remove("show");
    setStatus("Running AI…", "busy");
    document.getElementById("emptyState").style.display = "none";
    document.getElementById("filledState").style.display = "block";
    document.getElementById("prediction").textContent = "Analyzing…";
    document.getElementById("confidence").textContent = "…";
    document.getElementById("explanation").textContent = "Please wait…";
    document.getElementById("probabilities").innerHTML = "";
    document.getElementById("qualityNote").textContent = "";
    document.getElementById("reliabilityBanner").classList.remove("show");
    highlightStage(null);

    let formData = new FormData();
    formData.append("image", input.files[0]);

    fetch("/predict", {
        method: "POST",
        headers: { "X-CSRF-TOKEN": "{{ csrf_token() }}" },
        body: formData
    })
    .then(response => {
        if (!response.ok) throw new Error("Server responded with an error status.");
        return response.json();
    })
    .then(data => {
        data.eyeSide = document.getElementById("eyeSide").value || null;
        renderResult(data, true);
    })
    .catch(error => {
        console.log(error);
        setStatus("Connection failed", "err");
        document.getElementById("filledState").style.display = "none";
        document.getElementById("emptyState").style.display = "none";
        document.getElementById("connectionError").classList.add("show");
    });
}

renderSessionLog();
</script>

</div>

</div>
</div>
</x-app-layout>