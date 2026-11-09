import os
import subprocess

OUTPUT_DIR = "assets/store_screenshots"
os.makedirs(OUTPUT_DIR, exist_ok=True)

# 1. 512x512 App Icon / Logo
def generate_icon_html():
    return """<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    width: 512px;
    height: 512px;
    background: radial-gradient(circle at 35% 25%, #4338ca 0%, #1e1b4b 45%, #0b0f19 90%);
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
    position: relative;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  }

  /* Ambient Glow Rings */
  .glow-ring-outer {
    position: absolute;
    width: 430px;
    height: 430px;
    border-radius: 50%;
    border: 1.5px solid rgba(56, 189, 248, 0.2);
    box-shadow: 0 0 60px rgba(79, 70, 229, 0.4);
  }
  .glow-ring-inner {
    position: absolute;
    width: 370px;
    height: 370px;
    border-radius: 50%;
    border: 1.5px dashed rgba(99, 102, 241, 0.35);
  }

  /* Center Emblem */
  .emblem {
    width: 320px;
    height: 320px;
    position: relative;
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 10;
  }
</style>
</head>
<body>
  <div class="glow-ring-outer"></div>
  <div class="glow-ring-inner"></div>

  <div class="emblem">
    <svg width="320" height="320" viewBox="0 0 200 200" fill="none">
      <defs>
        <!-- Gradients -->
        <linearGradient id="shieldGrad" x1="0" y1="0" x2="200" y2="200" gradientUnits="userSpaceOnUse">
          <stop offset="0%" stop-color="#38bdf8"/>
          <stop offset="50%" stop-color="#4f46e5"/>
          <stop offset="100%" stop-color="#1e1b4b"/>
        </linearGradient>

        <linearGradient id="lensGrad" x1="40" y1="40" x2="160" y2="160" gradientUnits="userSpaceOnUse">
          <stop offset="0%" stop-color="#0284c7"/>
          <stop offset="100%" stop-color="#090d16"/>
        </linearGradient>

        <linearGradient id="coreGlow" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stop-color="#ffffff"/>
          <stop offset="100%" stop-color="#38bdf8"/>
        </linearGradient>

        <filter id="shadowFilter" x="-20%" y="-20%" width="140%" height="140%">
          <feDropShadow dx="0" dy="8" stdDeviation="12" flood-color="#000000" flood-opacity="0.6"/>
        </filter>
      </defs>

      <!-- Outer Protective Guard Hex / Shield / Halo -->
      <circle cx="100" cy="100" r="82" fill="url(#shieldGrad)" filter="url(#shadowFilter)"/>
      <circle cx="100" cy="100" r="76" fill="#0f172a" stroke="rgba(255,255,255,0.15)" stroke-width="2"/>

      <!-- Camera Aperture Outer Ring -->
      <circle cx="100" cy="100" r="64" fill="url(#lensGrad)" stroke="#38bdf8" stroke-width="2.5" stroke-dasharray="4 3"/>

      <!-- Inner Glass Lens -->
      <circle cx="100" cy="100" r="48" fill="#030712" stroke="rgba(56, 189, 248, 0.4)" stroke-width="2"/>

      <!-- Glowing Baby Silhouette inside camera iris -->
      <!-- Baby Head & Face -->
      <circle cx="100" cy="94" r="23" fill="url(#coreGlow)" filter="url(#shadowFilter)"/>
      <!-- Soft Sleepy Eyes -->
      <path d="M91 95 Q95 99 99 95" stroke="#0f172a" stroke-width="2.6" stroke-linecap="round"/>
      <path d="M101 95 Q105 99 109 95" stroke="#0f172a" stroke-width="2.6" stroke-linecap="round"/>
      <!-- Small peaceful smile -->
      <path d="M96 104 Q100 107 104 104" stroke="#0f172a" stroke-width="2.2" stroke-linecap="round"/>

      <!-- Baby Swaddle / Body Curve -->
      <path d="M78 116 Q100 136 122 116 Q122 138 100 144 Q78 138 78 116 Z" fill="url(#coreGlow)"/>

      <!-- Signal / Audio Broadcast Waves at Top -->
      <path d="M85 64 Q100 56 115 64" stroke="#38bdf8" stroke-width="3" stroke-linecap="round" fill="none" opacity="0.9"/>
      <path d="M76 54 Q100 44 124 54" stroke="#38bdf8" stroke-width="3" stroke-linecap="round" fill="none" opacity="0.6"/>

      <!-- Lens Reflection Specular Dot -->
      <circle cx="82" cy="78" r="6" fill="#ffffff" opacity="0.8"/>
      <circle cx="89" cy="73" r="2.5" fill="#ffffff" opacity="0.5"/>
    </svg>
  </div>
</body>
</html>
"""

# 2. 1024x500 Feature Graphic
def generate_feature_graphic_html():
    return """<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    width: 1024px;
    height: 500px;
    background: radial-gradient(circle at 75% 45%, #1e1b4b 0%, #0f172a 55%, #020617 100%);
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
    color: #ffffff;
    overflow: hidden;
    position: relative;
    display: flex;
    align-items: center;
    padding: 0 60px;
  }

  /* Decorative Ambient Waves */
  .bg-glow {
    position: absolute;
    width: 600px;
    height: 600px;
    border-radius: 50%;
    background: radial-gradient(circle, rgba(79, 70, 229, 0.3) 0%, transparent 70%);
    right: 50px;
    top: -50px;
    pointer-events: none;
  }
  .bg-grid {
    position: absolute;
    inset: 0;
    background-image: linear-gradient(rgba(255, 255, 255, 0.03) 1px, transparent 1px),
                      linear-gradient(90deg, rgba(255, 255, 255, 0.03) 1px, transparent 1px);
    background-size: 40px 40px;
    pointer-events: none;
  }

  /* Left Hero Content */
  .hero-content {
    flex: 1;
    z-index: 10;
    max-width: 540px;
  }
  .brand-badge {
    display: inline-flex;
    align-items: center;
    gap: 10px;
    background: rgba(99, 102, 241, 0.2);
    border: 1px solid rgba(129, 140, 248, 0.35);
    padding: 7px 16px;
    border-radius: 999px;
    font-size: 14px;
    font-weight: 700;
    color: #a5b4fc;
    letter-spacing: 0.5px;
    text-transform: uppercase;
    margin-bottom: 16px;
  }
  .badge-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: #10b981;
    box-shadow: 0 0 10px #10b981;
  }

  .title-group {
    display: flex;
    align-items: center;
    gap: 16px;
    margin-bottom: 12px;
  }
  .app-icon-mini {
    width: 56px;
    height: 56px;
    border-radius: 16px;
    background: linear-gradient(135deg, #38bdf8, #4f46e5);
    box-shadow: 0 8px 20px rgba(79, 70, 229, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    border: 1.5px solid rgba(255, 255, 255, 0.25);
  }
  .app-name {
    font-size: 52px;
    font-weight: 900;
    letter-spacing: -1px;
    line-height: 1;
    background: linear-gradient(135deg, #ffffff 0%, #cbd5e1 100%);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
  }
  .app-tagline {
    font-size: 23px;
    font-weight: 600;
    color: #38bdf8;
    margin-bottom: 22px;
    letter-spacing: -0.3px;
  }

  /* Feature Checklist Pills */
  .features-grid {
    display: flex;
    flex-wrap: wrap;
    gap: 10px;
  }
  .feat-pill {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    background: rgba(30, 41, 59, 0.85);
    backdrop-filter: blur(8px);
    border: 1px solid rgba(255, 255, 255, 0.12);
    padding: 8px 14px;
    border-radius: 12px;
    font-size: 13.5px;
    font-weight: 600;
    color: #e2e8f0;
  }
  .feat-icon {
    color: #10b981;
    font-weight: bold;
  }

  /* Right Mockup Showcase */
  .mockup-container {
    width: 380px;
    height: 440px;
    position: relative;
    z-index: 10;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .phone-card {
    width: 320px;
    height: 420px;
    background: #0b0f19;
    border-radius: 36px;
    border: 5px solid #334155;
    box-shadow: 0 30px 70px rgba(0, 0, 0, 0.85), 0 0 0 1px rgba(255, 255, 255, 0.1);
    transform: rotate(3deg) translateY(10px);
    overflow: hidden;
    display: flex;
    flex-direction: column;
    padding: 14px;
  }
  .phone-notch {
    width: 80px;
    height: 16px;
    background: #020617;
    border-radius: 8px;
    margin: 0 auto 10px;
  }

  /* Inside Phone Monitor Preview */
  .phone-video-view {
    flex: 1;
    border-radius: 20px;
    background: radial-gradient(circle at 50% 50%, #1e293b 0%, #030712 100%);
    border: 1px solid #334155;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    padding: 12px;
    position: relative;
  }
  .baby-silhouette {
    position: absolute;
    inset: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    opacity: 0.85;
  }
</style>
</head>
<body>
  <div class="bg-glow"></div>
  <div class="bg-grid"></div>

  <!-- Left Content -->
  <div class="hero-content">
    <div class="brand-badge">
      <span class="badge-dot"></span>
      Ultra Low-Latency P2P Monitoring
    </div>

    <div class="title-group">
      <div class="app-icon-mini">
        <svg width="34" height="34" viewBox="0 0 24 24" fill="white">
          <path d="M12 2c-4.97 0-9 4.03-9 9 0 2.12.74 4.07 1.97 5.61L4.35 17.9c-.39.39-.39 1.02 0 1.41.39.39 1.02.39 1.41 0l1.3-1.3C8.42 18.66 10.12 19 12 19c1.88 0 3.58-.34 4.94-.99l1.3 1.3c.39.39 1.02.39 1.41 0 .39-.39.39-1.02 0-1.41l-.62-1.29C20.26 15.07 21 13.12 21 11c0-4.97-4.03-9-9-9zm-3 8c.83 0 1.5.67 1.5 1.5S9.83 13 9 13s-1.5-.67-1.5-1.5.67-1.5 1.5-1.5zm6 0c.83 0 1.5.67 1.5 1.5s-.67 1.5-1.5 1.5-1.5-.67-1.5-1.5.67-1.5 1.5-1.5z"/>
        </svg>
      </div>
      <div class="app-name">Ibnik</div>
    </div>

    <div class="app-tagline">Smart HD Video & Audio Baby Monitor</div>

    <div class="features-grid">
      <div class="feat-pill"><span class="feat-icon">✓</span> Live HD Video & Audio</div>
      <div class="feat-pill"><span class="feat-icon">✓</span> Smart Cry Detection</div>
      <div class="feat-pill"><span class="feat-icon">✓</span> Two-Way Talk</div>
      <div class="feat-pill"><span class="feat-icon">✓</span> Soothing Lullabies</div>
      <div class="feat-pill"><span class="feat-icon">✓</span> Offline Wi-Fi & 4G/5G</div>
      <div class="feat-pill"><span class="feat-icon">✓</span> End-to-End Encrypted</div>
    </div>
  </div>

  <!-- Right Phone Mockup -->
  <div class="mockup-container">
    <div class="phone-card">
      <div class="phone-notch"></div>
      <div class="phone-video-view">
        <div style="display:flex; justify-content:space-between; align-items:center; z-index:5;">
          <div style="font-size:12px; font-weight:700; background:rgba(15,23,42,0.8); padding:4px 8px; border-radius:8px; border:1px solid rgba(255,255,255,0.1); color:#38bdf8;">
            ● Nursery (Live)
          </div>
          <div style="font-size:11px; font-weight:700; color:#10b981;">94% Bat</div>
        </div>

        <div class="baby-silhouette">
          <svg width="180" height="180" viewBox="0 0 200 200" fill="none">
            <circle cx="100" cy="100" r="75" fill="#1e293b" stroke="#334155" stroke-width="1.5"/>
            <ellipse cx="100" cy="115" rx="45" ry="28" fill="#38bdf8" fill-opacity="0.2"/>
            <circle cx="100" cy="92" r="22" fill="#cbd5e1" fill-opacity="0.85"/>
            <path d="M91 94 Q95 97 99 94" stroke="#0f172a" stroke-width="2" stroke-linecap="round"/>
            <path d="M101 94 Q105 97 109 94" stroke="#0f172a" stroke-width="2" stroke-linecap="round"/>
            <path d="M68 110 Q100 130 132 110 L132 135 Q100 148 68 135 Z" fill="#6366f1" fill-opacity="0.45"/>
          </svg>
        </div>

        <div style="background:rgba(15,23,42,0.9); backdrop-filter:blur(8px); border-radius:12px; padding:8px 12px; border:1px solid rgba(255,255,255,0.12); z-index:5;">
          <div style="display:flex; justify-content:space-between; font-size:11px; font-weight:700; margin-bottom:5px;">
            <span style="color:#10b981;">Audio: Quiet (18 dB)</span>
            <span style="color:#38bdf8;">HD 30fps</span>
          </div>
          <div style="height:6px; background:#334155; border-radius:3px; overflow:hidden;">
            <div style="width:35%; height:100%; background:#10b981;"></div>
          </div>
        </div>
      </div>
      <div style="margin-top:10px; background:#4f46e5; border-radius:12px; padding:8px; text-align:center; font-size:12px; font-weight:700; color:white;">
        Hold to Talk (Walkie-Talkie)
      </div>
    </div>
  </div>
</body>
</html>
"""

ASSETS = [
    ("app_icon_512x512.html", "app_icon_512x512.png", 512, 512, generate_icon_html),
    ("feature_graphic_1024x500.html", "feature_graphic_1024x500.png", 1024, 500, generate_feature_graphic_html),
]

for html_file, png_file, width, height, generator in ASSETS:
    html_path = os.path.join(OUTPUT_DIR, html_file)
    png_path = os.path.join(OUTPUT_DIR, png_file)
    
    with open(html_path, "w", encoding="utf-8") as f:
        f.write(generator())
    
    abs_html = os.path.abspath(html_path)
    cmd = [
        "google-chrome",
        "--headless",
        "--no-sandbox",
        "--disable-gpu",
        f"--screenshot={png_path}",
        f"--window-size={width},{height}",
        f"file://{abs_html}"
    ]
    subprocess.run(cmd, check=True)
    print(f"Generated {png_path} ({width}x{height}) successfully!")
