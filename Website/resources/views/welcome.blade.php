<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Diabetic Retinopathy Classification System</title>
<style>
    :root {
        --bg: #EFF3F1; --surface: #FFFFFF; --ink: #16241F; --muted: #5C6B65;
        --brand: #1B4B43; --brand-soft: #E4ECE9; --accent: #B8862B; --border: #D9E0DC;
        --font-display: Georgia, 'Iowan Old Style', 'Palatino Linotype', serif;
        --font-body: -apple-system, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
    }
    * { box-sizing: border-box; }
    body { margin: 0; background: var(--bg); color: var(--ink); font-family: var(--font-body); }
    header.site { display: flex; align-items: center; gap: 14px; padding: 22px 32px; border-bottom: 1px solid var(--border); background: var(--surface); }
    .mark { width: 34px; height: 34px; border-radius: 50%; background: radial-gradient(circle at 35% 35%, var(--accent), var(--brand) 70%); }
    header.site h1 { font-family: var(--font-display); font-weight: 600; font-size: 1.2rem; margin: 0; }
    .hero { max-width: 720px; margin: 80px auto; padding: 0 24px; text-align: center; }
    .hero h2 { font-family: var(--font-display); font-size: 2.2rem; margin: 0 0 16px; }
    .hero p { color: var(--muted); font-size: 1.05rem; line-height: 1.6; margin: 0 0 32px; }
    .btn-row { display: flex; gap: 12px; justify-content: center; }
    .btn { padding: 12px 26px; border-radius: 8px; text-decoration: none; font-weight: 600; font-size: 0.95rem; }
    .btn-primary { background: var(--brand); color: #fff; }
    .btn-secondary { background: var(--brand-soft); color: var(--brand); }
    .features { max-width: 900px; margin: 0 auto 80px; padding: 0 24px; display: grid; grid-template-columns: repeat(auto-fit, minmax(220px,1fr)); gap: 20px; }
    .feature { background: var(--surface); border: 1px solid var(--border); border-radius: 12px; padding: 22px; }
    .feature h3 { font-size: 1rem; margin: 0 0 8px; }
    .feature p { color: var(--muted); font-size: 0.88rem; margin: 0; line-height: 1.5; }
</style>
</head>
<body>

<header class="site">
    <div class="mark"></div>
    <h1>Diabetic Retinopathy Classification System</h1>
</header>

<div class="hero">
    <h2>AI-Assisted Retinal Screening</h2>
    <p>
        A decision-support tool for classifying diabetic retinopathy severity from retinal fundus images, using the International Clinical Diabetic Retinopathy (ICDR) severity scale — built to assist healthcare professionals, not replace clinical judgment.
    </p>
    <div class="btn-row">
        <a href="{{ route('login') }}" class="btn btn-primary">Log In</a>
        <a href="{{ route('register') }}" class="btn btn-secondary">Register</a>
    </div>
</div>

<div class="features">
    <div class="feature">
        <h3>ICDR-Based Classification</h3>
        <p>Classifies images across the 5 standard clinical severity stages, from No DR to Proliferative DR.</p>
    </div>
    <div class="feature">
        <h3>Explainable AI</h3>
        <p>Grad-CAM visualization shows where the model focused its attention on each image.</p>
    </div>
    <div class="feature">
        <h3>Built-In Quality Checks</h3>
        <p>Automatically flags blurry, poorly lit, or non-retinal images before analysis.</p>
    </div>
</div>

</body>
</html>