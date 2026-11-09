import os
import subprocess
import base64

OUTPUT_DIR = "assets/store_screenshots"
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Common SVG icons
ICONS = {
    "shield": '<svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor"><path d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4zm-2 16l-4-4 1.41-1.41L10 14.17l6.59-6.59L18 9l-8 8z"/></svg>',
    "camera": '<svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor"><path d="M17 10.5V7c0-.55-.45-1-1-1H4c-.55 0-1 .45-1 1v10c0 .55.45 1 1 1h12c.55 0 1-.45 1-1v-3.5l4 4v-11l-4 4z"/></svg>',
    "qr": '<svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor"><path d="M3 3h8v8H3zm2 2v4h4V5zm8-2h8v8h-8zm2 2v4h4V5zM3 13h8v8H3zm2 2v4h4v-4zm13-2h3v2h-3zm-3 2h3v3h-3zm3 3h3v3h-3zm-3 3h3v2h-3zm3-5h2v2h-2z"/></svg>',
    "wifi": '<svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor"><path d="M12 4C7.31 4 3.07 5.9 0 8.98L12 21 24 8.98C20.93 5.9 16.69 4 12 4zm0 3.5c3.78 0 7.22 1.48 9.77 3.91L12 18.27 2.23 11.41C4.78 8.98 8.22 7.5 12 7.5z"/></svg>',
    "baby": '<svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2c-4.97 0-9 4.03-9 9 0 2.12.74 4.07 1.97 5.61L4.35 17.9c-.39.39-.39 1.02 0 1.41.39.39 1.02.39 1.41 0l1.3-1.3C8.42 18.66 10.12 19 12 19c1.88 0 3.58-.34 4.94-.99l1.3 1.3c.39.39 1.02.39 1.41 0 .39-.39.39-1.02 0-1.41l-.62-1.29C20.26 15.07 21 13.12 21 11c0-4.97-4.03-9-9-9zm-3 8c.83 0 1.5.67 1.5 1.5S9.83 13 9 13s-1.5-.67-1.5-1.5.67-1.5 1.5-1.5zm6 0c.83 0 1.5.67 1.5 1.5s-.67 1.5-1.5 1.5-1.5-.67-1.5-1.5.67-1.5 1.5-1.5z"/></svg>',
    "mic": '<svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor"><path d="M12 14c1.66 0 3-1.34 3-3V5c0-1.66-1.34-3-3-3S9 3.34 9 5v6c0 1.66 1.34 3 3 3zm5-3c0 2.76-2.24 5-5 5s-5-2.24-5-5H5c0 3.53 2.61 6.43 6 6.92V21h2v-2.08c3.39-.49 6-3.39 6-6.92h-2z"/></svg>',
    "music": '<svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor"><path d="M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z"/></svg>',
    "battery": '<svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor"><path d="M15.67 4H14V2h-4v2H8.33C7.6 4 7 4.6 7 5.33v15.33C7 21.4 7.6 22 8.33 22h7.33c.74 0 1.34-.6 1.34-1.33V5.33C17 4.6 16.4 4 15.67 4zM11 20v-5.5H9L13 7v5.5h2L11 20z"/></svg>',
    "torch": '<svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor"><path d="M7 2v3h10V2H7zm0 5v2.22l2 2V22h6v-10.78l2-2V7H7z"/></svg>',
    "moon": '<svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor"><path d="M12.3 2a10 10 0 0 0-1.9 19.8 10 10 0 0 0 11.6-11.6A10 10 0 0 0 12.3 2z"/></svg>',
}

def generate_base_html(title, subtitle, phone_content):
    return f"""<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{
    width: 1080px;
    height: 1920px;
    background: radial-gradient(circle at 50% 15%, #1e1b4b 0%, #0f172a 50%, #020617 100%);
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
    color: #f8fafc;
    overflow: hidden;
    position: relative;
    display: flex;
    flex-direction: column;
    align-items: center;
    padding-top: 55px;
  }}

  /* Top Marketing Header */
  .header-zone {{
    text-align: center;
    margin-bottom: 40px;
    z-index: 10;
    max-width: 960px;
  }}
  .badge-pill {{
    display: inline-flex;
    align-items: center;
    gap: 8px;
    padding: 8px 18px;
    background: rgba(99, 102, 241, 0.18);
    border: 1px solid rgba(129, 140, 248, 0.35);
    border-radius: 999px;
    font-size: 19px;
    font-weight: 700;
    color: #a5b4fc;
    letter-spacing: 0.5px;
    margin-bottom: 14px;
    text-transform: uppercase;
  }}
  .main-title {{
    font-size: 52px;
    font-weight: 800;
    line-height: 1.15;
    background: linear-gradient(135deg, #ffffff 0%, #cbd5e1 100%);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    margin-bottom: 12px;
  }}
  .main-subtitle {{
    font-size: 26px;
    font-weight: 500;
    color: #94a3b8;
    line-height: 1.35;
  }}

  /* Phone Mockup Frame */
  .phone-frame {{
    width: 820px;
    height: 1580px;
    background: #0b0f19;
    border-radius: 54px;
    border: 9px solid #334155;
    box-shadow: 0 35px 80px rgba(0, 0, 0, 0.8), 0 0 0 1px rgba(255, 255, 255, 0.08);
    position: relative;
    overflow: hidden;
    display: flex;
    flex-direction: column;
  }}

  /* Phone Status Bar */
  .status-bar {{
    height: 52px;
    padding: 0 34px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    font-size: 19px;
    font-weight: 600;
    color: #cbd5e1;
    z-index: 20;
    background: transparent;
  }}
  .notch-pill {{
    width: 140px;
    height: 28px;
    background: #020617;
    border-radius: 14px;
    position: absolute;
    left: 50%;
    transform: translateX(-50%);
    top: 12px;
  }}
  .status-right {{
    display: flex;
    align-items: center;
    gap: 12px;
  }}

  /* In-App Content Area */
  .app-screen {{
    flex: 1;
    display: flex;
    flex-direction: column;
    position: relative;
    overflow: hidden;
    padding: 12px 24px 24px;
  }}

  /* Reusable App Components */
  .app-bar {{
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 10px 0 18px;
  }}
  .brand-logo {{
    display: flex;
    align-items: center;
    gap: 12px;
  }}
  .brand-icon {{
    width: 44px;
    height: 44px;
    background: linear-gradient(135deg, #4f46e5, #06b6d4);
    border-radius: 12px;
    display: flex;
    align-items: center;
    justify-content: center;
    color: white;
  }}
  .brand-text {{
    font-size: 28px;
    font-weight: 800;
    color: #ffffff;
    letter-spacing: -0.5px;
  }}
  .user-badge {{
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 8px 14px;
    background: #1e293b;
    border: 1px solid #334155;
    border-radius: 20px;
    font-size: 15px;
    color: #cbd5e1;
  }}
  .user-avatar {{
    width: 22px;
    height: 22px;
    border-radius: 50%;
    background: #4f46e5;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 12px;
    font-weight: bold;
  }}

  .card {{
    background: #1e293b;
    border: 1px solid #334155;
    border-radius: 22px;
    padding: 22px;
    margin-bottom: 16px;
  }}
</style>
</head>
<body>
  <div class="header-zone">
    <div class="badge-pill">{title['badge']}</div>
    <div class="main-title">{title['main']}</div>
    <div class="main-subtitle">{subtitle}</div>
  </div>

  <div class="phone-frame">
    <div class="status-bar">
      <span>09:41</span>
      <div class="notch-pill"></div>
      <div class="status-right">
        <span>5G</span>
        <span>100%</span>
      </div>
    </div>
    <div class="app-screen">
      {phone_content}
    </div>
  </div>
</body>
</html>
"""

# Screen 1: Live Parent Video Monitor
def screen1_parent_monitor():
    title = {"badge": "Parent Unit • Ultra Low Latency", "main": "Live HD Video & Sound Monitor"}
    subtitle = "Crystal-clear real-time stream with smart cry alerts & battery telemetry"
    content = f"""
    <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:14px;">
      <div style="display:flex; align-items:center; gap:12px;">
        <div style="width:38px; height:38px; border-radius:12px; background:#1e293b; display:flex; align-items:center; justify-content:center; border:1px solid #334155;">
          ‹
        </div>
        <div>
          <div style="font-size:22px; font-weight:700;">Nursery Camera (Crib)</div>
          <div style="font-size:14px; color:#10b981; display:flex; align-items:center; gap:6px;">
            <span style="width:8px; height:8px; border-radius:50%; background:#10b981; display:inline-block;"></span>
            Live (P2P Encrypted) • 30 fps
          </div>
        </div>
      </div>
      <div style="display:flex; align-items:center; gap:6px; background:#0f172a; padding:6px 14px; border-radius:20px; border:1px solid #334155; font-size:15px; font-weight:600; color:#38bdf8;">
        {ICONS['battery']} 94% Charging
      </div>
    </div>

    <!-- Live Video Viewport -->
    <div style="flex:1; border-radius:26px; overflow:hidden; position:relative; background:radial-gradient(circle at 50% 50%, #1e293b 0%, #090d16 100%); border:1px solid #334155; display:flex; flex-direction:column; justify-content:space-between; padding:22px;">
      <!-- Baby Illustration Simulation inside Camera -->
      <div style="position:absolute; inset:0; display:flex; align-items:center; justify-content:center; opacity:0.85;">
        <svg width="400" height="400" viewBox="0 0 200 200" fill="none">
          <circle cx="100" cy="100" r="85" fill="#1e293b" stroke="#334155" stroke-width="2"/>
          <!-- Crib & Baby sleeping silhouette -->
          <ellipse cx="100" cy="115" rx="55" ry="35" fill="#38bdf8" fill-opacity="0.2"/>
          <circle cx="100" cy="90" r="28" fill="#cbd5e1" fill-opacity="0.8"/>
          <!-- Sleepy eyes -->
          <path d="M88 92 Q93 96 98 92" stroke="#0f172a" stroke-width="2.5" stroke-linecap="round"/>
          <path d="M102 92 Q107 96 112 92" stroke="#0f172a" stroke-width="2.5" stroke-linecap="round"/>
          <!-- Blanket -->
          <path d="M60 110 Q100 135 140 110 L140 145 Q100 160 60 145 Z" fill="#6366f1" fill-opacity="0.45"/>
          <text x="100" y="172" text-anchor="middle" fill="#94a3b8" font-size="11" font-weight="600">INFANT SLEEPING PEACEFULLY</text>
        </svg>
      </div>

      <!-- Top Overlay Overlay Pills -->
      <div style="display:flex; justify-content:space-between; z-index:5;">
        <div style="background:rgba(15, 23, 42, 0.75); backdrop-filter:blur(8px); padding:8px 16px; border-radius:14px; border:1px solid rgba(255,255,255,0.1); font-size:14px; font-weight:600; display:flex; align-items:center; gap:8px;">
          <span style="color:#ef4444;">● REC</span> HD 1080p
        </div>
        <div style="background:rgba(15, 23, 42, 0.75); backdrop-filter:blur(8px); padding:8px 16px; border-radius:14px; border:1px solid rgba(255,255,255,0.1); font-size:14px; font-weight:600; display:flex; align-items:center; gap:8px;">
          {ICONS['torch']} Flashlight Off
        </div>
      </div>

      <!-- Live Sound Level Meter (Cry Detection) -->
      <div style="background:rgba(15, 23, 42, 0.85); backdrop-filter:blur(10px); border-radius:20px; padding:18px 22px; border:1px solid rgba(255,255,255,0.12); z-index:5;">
        <div style="display:flex; justify-content:space-between; font-size:15px; font-weight:700; margin-bottom:10px;">
          <span style="color:#10b981; display:flex; align-items:center; gap:6px;">
            <span style="width:8px; height:8px; border-radius:50%; background:#10b981;"></span>
            Audio Monitor: Normal (Quiet)
          </span>
          <span style="color:#94a3b8;">18 dB</span>
        </div>
        <div style="height:12px; background:#334155; border-radius:6px; overflow:hidden; display:flex; gap:3px; padding:2px;">
          <div style="width:25%; background:#10b981; border-radius:4px;"></div>
          <div style="width:15%; background:#10b981; border-radius:4px;"></div>
          <div style="width:10%; background:#34d399; border-radius:4px;"></div>
          <div style="flex:1; background:transparent;"></div>
        </div>
      </div>
    </div>

    <!-- Bottom Controls -->
    <div style="margin-top:16px; display:flex; gap:14px;">
      <div style="flex:1; background:#4f46e5; border-radius:22px; padding:20px; display:flex; align-items:center; justify-content:center; gap:12px; font-size:18px; font-weight:700; color:white; box-shadow:0 10px 25px rgba(79, 70, 229, 0.4);">
        {ICONS['mic']} Hold to Talk (Walkie-Talkie)
      </div>
      <div style="width:72px; height:72px; background:#1e293b; border:1px solid #334155; border-radius:22px; display:flex; align-items:center; justify-content:center; color:#38bdf8;">
        {ICONS['music']}
      </div>
    </div>
    """
    return generate_base_html(title, subtitle, content)

# Screen 2: Home Dashboard & Paired Cameras
def screen2_home_dashboard():
    title = {"badge": "Zero Setup Hassle", "main": "One-Tap Connect & Auto-Pair"}
    subtitle = "Save baby units forever with live battery telemetry & connection status"
    content = f"""
    <!-- App Header -->
    <div class="app-bar">
      <div class="brand-logo">
        <div class="brand-icon">{ICONS['baby']}</div>
        <div class="brand-text">Ibnik</div>
      </div>
      <div class="user-badge">
        <div class="user-avatar">P</div>
        <span>parent@gmail.com</span>
      </div>
    </div>

    <!-- Active Nursery Cameras Section -->
    <div style="margin-top:10px; margin-bottom:10px;">
      <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:14px;">
        <div style="font-size:20px; font-weight:800; color:#ffffff;">Paired Nursery Cameras</div>
        <div style="font-size:14px; font-weight:600; color:#38bdf8;">1 Online</div>
      </div>

      <!-- Camera Card 1 (Online) -->
      <div class="card" style="border-left:5px solid #10b981; display:flex; justify-content:space-between; align-items:center;">
        <div style="display:flex; align-items:center; gap:16px;">
          <div style="width:52px; height:52px; border-radius:16px; background:rgba(16, 185, 129, 0.15); display:flex; align-items:center; justify-content:center; color:#10b981;">
            {ICONS['baby']}
          </div>
          <div>
            <div style="font-size:18px; font-weight:700;">Nursery Camera</div>
            <div style="font-size:14px; color:#10b981; display:flex; align-items:center; gap:6px; margin-top:4px;">
              <span style="width:8px; height:8px; border-radius:50%; background:#10b981;"></span>
              Online • 94% Battery
            </div>
          </div>
        </div>
        <div style="background:#4f46e5; color:white; padding:12px 24px; border-radius:14px; font-size:15px; font-weight:700;">
          Connect
        </div>
      </div>

      <!-- Camera Card 2 (Offline) -->
      <div class="card" style="opacity:0.75; display:flex; justify-content:space-between; align-items:center;">
        <div style="display:flex; align-items:center; gap:16px;">
          <div style="width:52px; height:52px; border-radius:16px; background:rgba(148, 163, 184, 0.15); display:flex; align-items:center; justify-content:center; color:#94a3b8;">
            {ICONS['camera']}
          </div>
          <div>
            <div style="font-size:18px; font-weight:700;">Playroom Tablet</div>
            <div style="font-size:14px; color:#64748b; display:flex; align-items:center; gap:6px; margin-top:4px;">
              <span style="width:8px; height:8px; border-radius:50%; background:#64748b;"></span>
              Offline
            </div>
          </div>
        </div>
        <div style="background:#334155; color:#94a3b8; padding:12px 24px; border-radius:14px; font-size:15px; font-weight:700;">
          Offline
        </div>
      </div>
    </div>

    <!-- Set Up Devices Section -->
    <div style="margin-top:16px;">
      <div style="font-size:20px; font-weight:800; color:#ffffff; margin-bottom:14px;">Set Up Devices</div>

      <!-- Role Card 1: Pair Camera -->
      <div class="card" style="background:linear-gradient(135deg, rgba(79, 70, 229, 0.25), #1e293b); border-color:#4f46e5;">
        <div style="display:flex; align-items:flex-start; gap:16px;">
          <div style="width:50px; height:50px; border-radius:16px; background:#4f46e5; display:flex; align-items:center; justify-content:center; color:white;">
            {ICONS['qr']}
          </div>
          <div style="flex:1;">
            <div style="font-size:18px; font-weight:700;">Pair Baby Camera (Show QR)</div>
            <div style="font-size:14px; color:#cbd5e1; margin-top:4px; line-height:1.4;">
              Display pairing QR code for the baby phone to scan and link forever.
            </div>
          </div>
        </div>
      </div>

      <!-- Role Card 2: Baby Unit -->
      <div class="card">
        <div style="display:flex; align-items:flex-start; gap:16px;">
          <div style="width:50px; height:50px; border-radius:16px; background:#10b981; display:flex; align-items:center; justify-content:center; color:white;">
            {ICONS['camera']}
          </div>
          <div style="flex:1;">
            <div style="font-size:18px; font-weight:700;">Baby Unit (Nursery Camera)</div>
            <div style="font-size:14px; color:#cbd5e1; margin-top:4px; line-height:1.4;">
              Turns this device into the nursery camera with sound detection & lullabies.
            </div>
          </div>
        </div>
      </div>

      <!-- Role Card 3: Local Offline Mode -->
      <div class="card">
        <div style="display:flex; align-items:flex-start; gap:16px;">
          <div style="width:50px; height:50px; border-radius:16px; background:#06b6d4; display:flex; align-items:center; justify-content:center; color:white;">
            {ICONS['wifi']}
          </div>
          <div style="flex:1;">
            <div style="font-size:18px; font-weight:700;">Local Wi-Fi Mode (Offline)</div>
            <div style="font-size:14px; color:#cbd5e1; margin-top:4px; line-height:1.4;">
              Direct peer-to-peer pairing over local Wi-Fi without cloud servers.
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Security Footer -->
    <div style="margin-top:auto; text-align:center; font-size:13px; color:#64748b; display:flex; align-items:center; justify-content:center; gap:6px;">
      {ICONS['shield']} End-to-End Encrypted (DTLS-SRTP) • 100% Free
    </div>
    """
    return generate_base_html(title, subtitle, content)

# Screen 3: Optical QR Pairing
def screen3_qr_pairing():
    title = {"badge": "Permanent Optical Pairing", "main": "Pair Any Two Phones in Seconds"}
    subtitle = "Point the nursery camera at the parent QR code — works across any Google accounts"
    content = f"""
    <div style="display:flex; align-items:center; gap:14px; margin-bottom:16px;">
      <div style="width:38px; height:38px; border-radius:12px; background:#1e293b; display:flex; align-items:center; justify-content:center; border:1px solid #334155;">
        ‹
      </div>
      <div>
        <div style="font-size:22px; font-weight:800;">Pair Nursery Camera</div>
        <div style="font-size:14px; color:#94a3b8;">Scan on baby phone to link permanently</div>
      </div>
    </div>

    <div style="flex:1; display:flex; flex-direction:column; align-items:center; justify-content:center;">
      <!-- White QR Card -->
      <div style="background:#ffffff; padding:28px; border-radius:32px; box-shadow:0 20px 50px rgba(0,0,0,0.5); display:flex; flex-direction:column; align-items:center; margin-bottom:28px;">
        <!-- Simulated QR SVG -->
        <svg width="280" height="280" viewBox="0 0 140 140">
          <rect width="140" height="140" fill="white"/>
          <!-- Top Left Marker -->
          <rect x="10" y="10" width="35" height="35" rx="6" fill="#0f172a"/>
          <rect x="17" y="17" width="21" height="21" rx="4" fill="white"/>
          <rect x="22" y="22" width="11" height="11" rx="2" fill="#0f172a"/>
          <!-- Top Right Marker -->
          <rect x="95" y="10" width="35" height="35" rx="6" fill="#0f172a"/>
          <rect x="102" y="17" width="21" height="21" rx="4" fill="white"/>
          <rect x="107" y="22" width="11" height="11" rx="2" fill="#0f172a"/>
          <!-- Bottom Left Marker -->
          <rect x="10" y="95" width="35" height="35" rx="6" fill="#0f172a"/>
          <rect x="17" y="102" width="21" height="21" rx="4" fill="white"/>
          <rect x="22" y="107" width="11" height="11" rx="2" fill="#0f172a"/>
          <!-- Random Matrix Blocks -->
          <rect x="52" y="15" width="8" height="8" fill="#0f172a"/>
          <rect x="68" y="15" width="14" height="8" fill="#0f172a"/>
          <rect x="52" y="30" width="16" height="8" fill="#0f172a"/>
          <rect x="74" y="30" width="8" height="16" fill="#0f172a"/>
          <rect x="52" y="52" width="35" height="35" rx="8" fill="#4f46e5"/>
          <circle cx="69.5" cy="69.5" r="9" fill="white"/>
          <rect x="15" y="55" width="8" height="20" fill="#0f172a"/>
          <rect x="30" y="70" width="15" height="8" fill="#0f172a"/>
          <rect x="95" y="55" width="20" height="8" fill="#0f172a"/>
          <rect x="110" y="70" width="18" height="15" fill="#0f172a"/>
          <rect x="55" y="95" width="20" height="8" fill="#0f172a"/>
          <rect x="65" y="110" width="22" height="15" fill="#0f172a"/>
          <rect x="95" y="95" width="15" height="15" fill="#0f172a"/>
          <rect x="115" y="115" width="15" height="15" fill="#0f172a"/>
        </svg>

        <div style="margin-top:16px; font-family:monospace; font-size:16px; font-weight:bold; color:#0f172a; letter-spacing:1.5px; background:#f1f5f9; padding:6px 16px; border-radius:10px;">
          CHANNEL: ibnik-crib-8942
        </div>
      </div>

      <!-- Instructions Pill -->
      <div style="background:#1e293b; border:1px solid #334155; border-radius:20px; padding:20px 24px; text-align:center; max-width:680px;">
        <div style="font-size:18px; font-weight:700; color:#ffffff; margin-bottom:6px;">Waiting for Baby Phone Scan...</div>
        <div style="font-size:15px; color:#94a3b8; line-height:1.45;">
          Open Ibnik on your other phone &rarr; Tap <b>"Baby Unit"</b> &rarr; Point camera at this QR code.
        </div>
        <div style="margin-top:14px; display:inline-flex; align-items:center; gap:8px; font-size:14px; font-weight:600; color:#10b981; background:rgba(16, 185, 129, 0.12); padding:6px 14px; border-radius:12px;">
          ✓ Ready to pair once and reconnect forever
        </div>
      </div>
    </div>
    """
    return generate_base_html(title, subtitle, content)

# Screen 4: Baby Unit Nursery Camera
def screen4_baby_unit():
    title = {"badge": "Nursery Unit • High Reliability", "main": "Smart Nursery Camera with Cry Guard"}
    subtitle = "Night mode, screen dimming, sound detection & remote lullabies"
    content = f"""
    <!-- Top HUD -->
    <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:14px;">
      <div style="display:flex; align-items:center; gap:10px;">
        <div style="width:12px; height:12px; border-radius:50%; background:#10b981; box-shadow:0 0 12px #10b981;"></div>
        <div>
          <div style="font-size:20px; font-weight:800;">Baby Unit Active</div>
          <div style="font-size:14px; color:#94a3b8;">Connected to Parent Unit</div>
        </div>
      </div>
      <div style="display:flex; gap:8px;">
        <div style="background:#1e293b; border:1px solid #334155; padding:6px 12px; border-radius:12px; font-size:14px; font-weight:600; color:#cbd5e1;">
          {ICONS['battery']} 98%
        </div>
      </div>
    </div>

    <!-- Active Camera Preview Surface -->
    <div style="flex:1; border-radius:26px; overflow:hidden; position:relative; background:radial-gradient(circle at 50% 50%, #1e293b 0%, #030712 100%); border:1px solid #334155; display:flex; flex-direction:column; justify-content:space-between; padding:22px;">
      <!-- Baby silhouette in night vision -->
      <div style="position:absolute; inset:0; display:flex; align-items:center; justify-content:center;">
        <svg width="400" height="400" viewBox="0 0 200 200" fill="none">
          <circle cx="100" cy="100" r="85" fill="#0f172a" stroke="#1e293b" stroke-width="2"/>
          <ellipse cx="100" cy="115" rx="55" ry="35" fill="#10b981" fill-opacity="0.12"/>
          <circle cx="100" cy="90" r="28" fill="#64748b" fill-opacity="0.7"/>
          <path d="M88 92 Q93 96 98 92" stroke="#020617" stroke-width="2.5" stroke-linecap="round"/>
          <path d="M102 92 Q107 96 112 92" stroke="#020617" stroke-width="2.5" stroke-linecap="round"/>
          <path d="M60 110 Q100 135 140 110 L140 145 Q100 160 60 145 Z" fill="#06b6d4" fill-opacity="0.35"/>
          <text x="100" y="172" text-anchor="middle" fill="#10b981" font-size="11" font-weight="700">INFRARED NIGHT MODE ACTIVE</text>
        </svg>
      </div>

      <!-- Quick Toggles -->
      <div style="display:flex; justify-content:space-between; z-index:5;">
        <div style="background:rgba(15, 23, 42, 0.8); backdrop-filter:blur(8px); padding:8px 16px; border-radius:14px; border:1px solid rgba(255,255,255,0.1); font-size:14px; font-weight:600; display:flex; align-items:center; gap:8px;">
          {ICONS['moon']} Screen Dimmer On
        </div>
        <div style="background:rgba(15, 23, 42, 0.8); backdrop-filter:blur(8px); padding:8px 16px; border-radius:14px; border:1px solid rgba(255,255,255,0.1); font-size:14px; font-weight:600; display:flex; align-items:center; gap:8px;">
          {ICONS['torch']} Flashlight
        </div>
      </div>

      <!-- Real-Time Microphone & Cry Detection Level -->
      <div style="background:rgba(15, 23, 42, 0.9); backdrop-filter:blur(10px); border-radius:20px; padding:20px; border:1px solid rgba(255,255,255,0.12); z-index:5;">
        <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:8px;">
          <div style="font-size:16px; font-weight:700; color:#ffffff;">Smart Sound Guard</div>
          <div style="font-size:14px; font-weight:700; color:#10b981;">NURSERY QUIET</div>
        </div>
        <div style="font-size:13px; color:#94a3b8; margin-bottom:12px;">Background audio streaming directly to parent phone</div>
        <div style="height:10px; background:#334155; border-radius:5px; overflow:hidden; display:flex; gap:3px;">
          <div style="width:20%; background:#10b981;"></div>
          <div style="width:10%; background:#10b981;"></div>
        </div>
      </div>
    </div>

    <!-- Bottom Status Info -->
    <div style="margin-top:16px; background:#1e293b; border-radius:20px; padding:18px 24px; border:1px solid #334155; display:flex; justify-content:space-between; align-items:center;">
      <div style="display:flex; align-items:center; gap:12px;">
        <div style="width:40px; height:40px; border-radius:12px; background:rgba(6, 182, 212, 0.15); display:flex; align-items:center; justify-content:center; color:#06b6d4;">
          {ICONS['music']}
        </div>
        <div>
          <div style="font-size:16px; font-weight:700;">Lullaby Remote Ready</div>
          <div style="font-size:13px; color:#94a3b8;">Can be triggered anytime from Parent unit</div>
        </div>
      </div>
      <div style="color:#06b6d4; font-size:14px; font-weight:700;">Ready</div>
    </div>
    """
    return generate_base_html(title, subtitle, content)

# Screen 5: Remote Lullabies & White Noise Sheet
def screen5_lullabies():
    title = {"badge": "Soothing Sleep Aids", "main": "Calming Lullabies & White Noise"}
    subtitle = "Play peaceful melodies and gentle ambient sounds remotely to soothe your baby"
    content = f"""
    <!-- Parent Monitor in Background (Darkened) -->
    <div style="height:140px; border-radius:22px; background:#1e293b; border:1px solid #334155; padding:16px; display:flex; justify-content:space-between; opacity:0.5; margin-bottom:12px;">
      <div>
        <div style="font-size:16px; font-weight:700;">Nursery Camera (Crib)</div>
        <div style="font-size:13px; color:#10b981;">● Live Stream</div>
      </div>
      <div style="font-size:13px; color:#38bdf8;">94% Charging</div>
    </div>

    <!-- Active Lullabies Sheet -->
    <div style="flex:1; background:#1e293b; border:1px solid #475569; border-radius:28px 28px 0 0; padding:24px; display:flex; flex-direction:column; box-shadow:0 -15px 40px rgba(0,0,0,0.6);">
      <!-- Sheet Handle -->
      <div style="width:48px; height:5px; background:#64748b; border-radius:3px; margin:0 auto 18px;"></div>

      <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:18px;">
        <div>
          <div style="font-size:22px; font-weight:800; color:#ffffff;">Calming Sounds & Lullabies</div>
          <div style="font-size:14px; color:#94a3b8;">Plays through Baby Unit speaker</div>
        </div>
        <div style="width:36px; height:36px; border-radius:50%; background:#334155; display:flex; align-items:center; justify-content:center; color:#cbd5e1; font-weight:bold;">
          ✕
        </div>
      </div>

      <!-- Tracks List -->
      <div style="display:flex; flex-direction:column; gap:12px; flex:1;">
        <!-- Playing Track -->
        <div style="background:linear-gradient(135deg, rgba(79, 70, 229, 0.4), #0f172a); border:2px solid #6366f1; border-radius:18px; padding:16px 20px; display:flex; justify-content:space-between; align-items:center;">
          <div style="display:flex; align-items:center; gap:14px;">
            <div style="width:44px; height:44px; border-radius:14px; background:#4f46e5; display:flex; align-items:center; justify-content:center; color:white;">
              {ICONS['music']}
            </div>
            <div>
              <div style="font-size:17px; font-weight:700; color:#ffffff;">Brahms Lullaby</div>
              <div style="font-size:13px; color:#a5b4fc; font-weight:600;">NOW PLAYING • 03:45</div>
            </div>
          </div>
          <div style="color:#a5b4fc; font-size:24px;">❚❚</div>
        </div>

        <!-- Track 2 -->
        <div style="background:#0f172a; border:1px solid #334155; border-radius:18px; padding:16px 20px; display:flex; justify-content:space-between; align-items:center;">
          <div style="display:flex; align-items:center; gap:14px;">
            <div style="width:44px; height:44px; border-radius:14px; background:#1e293b; display:flex; align-items:center; justify-content:center; color:#38bdf8;">
              {ICONS['music']}
            </div>
            <div>
              <div style="font-size:17px; font-weight:700; color:#ffffff;">Twinkle Twinkle Little Star</div>
              <div style="font-size:13px; color:#64748b;">Gentle Music Box • 04:12</div>
            </div>
          </div>
          <div style="color:#64748b; font-size:20px;">▶</div>
        </div>

        <!-- Track 3 -->
        <div style="background:#0f172a; border:1px solid #334155; border-radius:18px; padding:16px 20px; display:flex; justify-content:space-between; align-items:center;">
          <div style="display:flex; align-items:center; gap:14px;">
            <div style="width:44px; height:44px; border-radius:14px; background:#1e293b; display:flex; align-items:center; justify-content:center; color:#38bdf8;">
              {ICONS['moon']}
            </div>
            <div>
              <div style="font-size:17px; font-weight:700; color:#ffffff;">Gentle Rain & White Noise</div>
              <div style="font-size:13px; color:#64748b;">Calming Sleep Sound • Loop</div>
            </div>
          </div>
          <div style="color:#64748b; font-size:20px;">▶</div>
        </div>
      </div>

      <!-- Volume & Timer Controls -->
      <div style="background:#0f172a; border-radius:18px; padding:16px 20px; border:1px solid #334155; margin-top:14px;">
        <div style="display:flex; justify-content:space-between; font-size:14px; font-weight:600; color:#cbd5e1; margin-bottom:10px;">
          <span>Volume on Nursery Unit</span>
          <span style="color:#38bdf8;">70%</span>
        </div>
        <div style="height:8px; background:#334155; border-radius:4px; overflow:hidden;">
          <div style="width:70%; height:100%; background:#38bdf8;"></div>
        </div>
      </div>
    </div>
    """
    return generate_base_html(title, subtitle, content)

SCREENS = [
    ("screenshot_1_live_monitor.html", "screenshot_1_live_monitor.png", screen1_parent_monitor),
    ("screenshot_2_home_dashboard.html", "screenshot_2_home_dashboard.png", screen2_home_dashboard),
    ("screenshot_3_qr_pairing.html", "screenshot_3_qr_pairing.png", screen3_qr_pairing),
    ("screenshot_4_baby_unit.html", "screenshot_4_baby_unit.png", screen4_baby_unit),
    ("screenshot_5_lullabies.html", "screenshot_5_lullabies.png", screen5_lullabies),
]

for html_file, png_file, generator in SCREENS:
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
        "--window-size=1080,1920",
        f"file://{abs_html}"
    ]
    subprocess.run(cmd, check=True)
    print(f"Generated {png_path} successfully!")
