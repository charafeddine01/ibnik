import wave
import math
import struct
import random
import os

SAMPLE_RATE = 22050

def write_wav(filename, samples):
    with wave.open(filename, 'w') as wf:
        wf.setnchannels(1)  # Mono
        wf.setsampwidth(2)  # 16-bit
        wf.setframerate(SAMPLE_RATE)
        packed = struct.pack(f'<{len(samples)}h', *[int(max(-32767, min(32767, s))) for s in samples])
        wf.writeframes(packed)
    print(f"Generated {filename}: {len(samples)/SAMPLE_RATE:.1f}s, {os.path.getsize(filename)/1024:.1f} KB")

# 1. White Noise (Pink/Brownian sleep noise with gentle low-pass filter)
def generate_white_noise(duration_sec=12):
    num_samples = int(SAMPLE_RATE * duration_sec)
    samples = []
    b0, b1, b2, b3 = 0.0, 0.0, 0.0, 0.0
    for _ in range(num_samples):
        white = (random.random() * 2.0 - 1.0) * 0.35
        # 3-pole pinking filter
        b0 = 0.99886 * b0 + white * 0.0555179
        b1 = 0.99332 * b1 + white * 0.0750759
        b2 = 0.96900 * b2 + white * 0.1538520
        b3 = 0.86650 * b3 + white * 0.3104856
        pink = b0 + b1 + b2 + b3 + white * 0.5362
        samples.append(pink * 7000.0)
    return samples

# 2. Heartbeat (Rhythmic womb heartbeat at 60 bpm: lub-dub)
def generate_heartbeat(duration_sec=12):
    num_samples = int(SAMPLE_RATE * duration_sec)
    samples = [0.0] * num_samples
    bpm = 60
    beat_interval = int(SAMPLE_RATE * (60.0 / bpm))
    
    for beat_start in range(0, num_samples - SAMPLE_RATE, beat_interval):
        # "Lub" sound (lower pitch ~55 Hz, duration 120ms)
        for i in range(int(SAMPLE_RATE * 0.12)):
            t = i / SAMPLE_RATE
            env = math.exp(-t * 28.0) * math.sin(math.pi * i / (SAMPLE_RATE * 0.12))
            val = math.sin(2.0 * math.pi * 55.0 * t) * env * 22000.0
            idx = beat_start + i
            if idx < num_samples:
                samples[idx] += val
        
        # "Dub" sound (slightly higher pitch ~80 Hz, 240ms after Lub, duration 100ms)
        dub_start = beat_start + int(SAMPLE_RATE * 0.24)
        for i in range(int(SAMPLE_RATE * 0.10)):
            t = i / SAMPLE_RATE
            env = math.exp(-t * 32.0) * math.sin(math.pi * i / (SAMPLE_RATE * 0.10))
            val = math.sin(2.0 * math.pi * 78.0 * t) * env * 18000.0
            idx = dub_start + i
            if idx < num_samples:
                samples[idx] += val

    return samples

# 3. Gentle Rain (Soft rainfall ambience)
def generate_rain(duration_sec=12):
    num_samples = int(SAMPLE_RATE * duration_sec)
    samples = [0.0] * num_samples
    # Ambient rain bed (bandpass noise)
    last = 0.0
    for i in range(num_samples):
        white = (random.random() * 2.0 - 1.0)
        last = 0.92 * last + 0.08 * white
        samples[i] = last * 10000.0
        
    # Add random soft raindrop plinks
    num_drops = int(duration_sec * 30)
    for _ in range(num_drops):
        pos = random.randint(0, num_samples - int(SAMPLE_RATE * 0.04))
        pitch = random.uniform(800.0, 1800.0)
        drop_len = int(SAMPLE_RATE * random.uniform(0.015, 0.035))
        for j in range(drop_len):
            t = j / SAMPLE_RATE
            env = math.exp(-t * 120.0)
            val = math.sin(2.0 * math.pi * pitch * t) * env * random.uniform(3000.0, 6000.0)
            samples[pos + j] += val
            
    return samples

# 4. Brahms Lullaby (Music Box timbre)
def generate_brahms():
    notes = {
        'Eb4': 311.13, 'F4': 349.23, 'G4': 392.00, 'Ab4': 415.30,
        'Bb4': 466.16, 'C5': 523.25, 'D5': 587.33, 'Eb5': 622.25, 'F5': 698.46
    }
    melody = [
        ('G4', 0.5), ('G4', 0.5), ('Bb4', 1.0),
        ('G4', 0.5), ('G4', 0.5), ('Bb4', 1.0),
        ('G4', 0.5), ('Bb4', 0.5), ('Eb5', 1.0), ('D5', 0.5),
        ('C5', 0.5), ('C5', 0.5), ('Bb4', 1.0),
        ('F4', 0.5), ('G4', 0.5), ('Ab4', 1.0),
        ('F4', 0.5), ('G4', 0.5), ('Ab4', 1.0),
        ('F4', 0.5), ('Ab4', 0.5), ('D5', 1.0), ('C5', 0.5),
        ('Bb4', 0.5), ('D5', 0.5), ('Eb5', 1.5),
    ]
    tempo_scale = 1.25  # relaxed soothing lullaby pace
    total_sec = sum(dur for _, dur in melody) * tempo_scale + 1.0
    num_samples = int(SAMPLE_RATE * total_sec)
    samples = [0.0] * num_samples
    
    current_time = 0.0
    for note_name, dur in melody:
        freq = notes[note_name]
        start_sample = int(current_time * SAMPLE_RATE)
        note_samples = int(SAMPLE_RATE * 1.8) # Ring out music box decay
        
        for i in range(note_samples):
            idx = start_sample + i
            if idx >= num_samples:
                break
            t = i / SAMPLE_RATE
            # Music box chime: fundamental + soft 2nd & 3rd harmonics + gentle exponential decay
            decay = math.exp(-t * 2.8)
            harmonic1 = math.sin(2.0 * math.pi * freq * t)
            harmonic2 = 0.35 * math.sin(2.0 * math.pi * freq * 2.0 * t)
            harmonic3 = 0.15 * math.sin(2.0 * math.pi * freq * 3.0 * t)
            tone = (harmonic1 + harmonic2 + harmonic3) * decay * 14000.0
            samples[idx] += tone
            
        current_time += dur * tempo_scale
        
    return samples

# 5. Ocean Waves (Slow swelling surf)
def generate_ocean_waves(duration_sec=14):
    num_samples = int(SAMPLE_RATE * duration_sec)
    samples = [0.0] * num_samples
    last = 0.0
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        # Wave swell envelope: 7-second period
        swell = 0.4 + 0.6 * (0.5 * (1.0 + math.sin(2.0 * math.pi * (t / 7.0) - math.pi / 2)))
        white = (random.random() * 2.0 - 1.0)
        last = 0.95 * last + 0.05 * white
        samples[i] = last * swell * 18000.0
    return samples

if __name__ == '__main__':
    out_dir = os.path.dirname(os.path.abspath(__file__))
    write_wav(os.path.join(out_dir, 'white_noise.wav'), generate_white_noise())
    write_wav(os.path.join(out_dir, 'heartbeat.wav'), generate_heartbeat())
    write_wav(os.path.join(out_dir, 'rain.wav'), generate_rain())
    write_wav(os.path.join(out_dir, 'brahms.wav'), generate_brahms())
    write_wav(os.path.join(out_dir, 'waves.wav'), generate_ocean_waves())
    print("All lullaby WAVs generated successfully!")
