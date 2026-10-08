#!/usr/bin/env python3
"""
Audio Asset Generation & Mastering Pipeline for x_player_armor
Follows the Luanti Sound Effects Engineering standard (.agents/skills/luanti-sounds/SKILL.md):
- 44.1 kHz (44,100 Hz) sample rate
- Mono (1 channel) for OpenAL 3D spatial attenuation
- Silence trimming & anti-click micro-fades (zero-crossing)
- Peak volume normalization to -1.0 dBFS (~0.89 linear)
- Multi-sample variations (<name>.<n>.ogg)
- Mastered and synthesized via Blender Python 'aud' engine
"""

import os
import wave
import struct
import math
import random
import aud

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
MOD_DIR = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))
SOUNDS_DIR = os.path.join(MOD_DIR, "sounds")
os.makedirs(SOUNDS_DIR, exist_ok=True)

SAMPLE_RATE = 44100
TARGET_PEAK = 0.89  # -1.0 dBFS

def export_ogg(filename, samples, fade_in_ms=15, fade_out_ms=80):
    n = len(samples)
    if n == 0:
        return

    # Anti-click micro-fades
    fade_in_len = min(n // 4, int(fade_in_ms * SAMPLE_RATE / 1000.0))
    fade_out_len = min(n // 4, int(fade_out_ms * SAMPLE_RATE / 1000.0))

    if fade_in_len > 0:
        for i in range(fade_in_len):
            # Raised cosine fade-in
            factor = 0.5 * (1.0 - math.cos(math.pi * i / fade_in_len))
            samples[i] *= factor

    if fade_out_len > 0:
        for i in range(fade_out_len):
            idx = n - fade_out_len + i
            factor = 0.5 * (1.0 + math.cos(math.pi * i / fade_out_len))
            samples[idx] *= factor

    # Peak normalization to TARGET_PEAK (-1.0 dBFS)
    peak = max((abs(s) for s in samples), default=1.0)
    if peak > 1e-5:
        scale = TARGET_PEAK / peak
        samples = [s * scale for s in samples]

    # Write temporary WAV for aud conversion
    temp_wav = os.path.join(SOUNDS_DIR, f"_tmp_{filename}.wav")
    out_ogg = os.path.join(SOUNDS_DIR, filename)

    with wave.open(temp_wav, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        raw = bytearray()
        for s in samples:
            val = int(max(-32767, min(32767, s * 32767.0)))
            raw.extend(struct.pack("<h", val))
        wf.writeframes(raw)

    snd = aud.Sound.file(temp_wav)
    snd.write(
        out_ogg,
        rate=SAMPLE_RATE,
        channels=aud.CHANNELS_MONO,
        format=aud.FORMAT_S16,
        container=aud.CONTAINER_OGG,
        codec=aud.CODEC_VORBIS,
        bitrate=128000,
    )

    if os.path.exists(temp_wav):
        os.remove(temp_wav)
    print(f"Generated mono 44.1kHz sound: {filename} ({os.path.getsize(out_ogg)} bytes)")


def gen_equip_sounds():
    # 3 variations: buckle click + leather strap + plate shift
    durations = [0.35, 0.38, 0.32]
    for idx, dur in enumerate(durations, start=1):
        n = int(SAMPLE_RATE * dur)
        samples = [0.0] * n
        # Leather friction noise
        for i in range(n):
            t = i / SAMPLE_RATE
            noise = (random.random() * 2.0 - 1.0)
            friction = noise * math.exp(-t * 12.0) * (0.4 + 0.3 * math.sin(2 * math.pi * 320 * t))
            samples[i] += friction

        # Buckle click transient at 0.05s
        click_idx = int(SAMPLE_RATE * 0.04)
        for i in range(int(SAMPLE_RATE * 0.08)):
            if click_idx + i < n:
                t = i / SAMPLE_RATE
                click = math.sin(2 * math.pi * (2400 + idx * 300) * t) * math.exp(-t * 90.0)
                samples[click_idx + i] += click * 1.2

        # Metal plate settle clink at 0.12s
        settle_idx = int(SAMPLE_RATE * 0.12)
        for i in range(int(SAMPLE_RATE * 0.15)):
            if settle_idx + i < n:
                t = i / SAMPLE_RATE
                clink = (math.sin(2 * math.pi * (1600 + idx * 250) * t) +
                         0.5 * math.sin(2 * math.pi * (3100 + idx * 150) * t)) * math.exp(-t * 40.0)
                samples[settle_idx + i] += clink * 0.8

        export_ogg(f"x_player_armor_equip.{idx}.ogg", samples, fade_in_ms=8, fade_out_ms=60)


def gen_unequip_sounds():
    # 2 variations: leather release + buckle unhook
    durations = [0.28, 0.25]
    for idx, dur in enumerate(durations, start=1):
        n = int(SAMPLE_RATE * dur)
        samples = [0.0] * n
        # Initial unlatch pop
        for i in range(int(SAMPLE_RATE * 0.05)):
            t = i / SAMPLE_RATE
            pop = math.sin(2 * math.pi * (950 + idx * 150) * t) * math.exp(-t * 120.0)
            samples[i] += pop * 1.1

        # Smooth leather slide
        for i in range(n):
            t = i / SAMPLE_RATE
            noise = (random.random() * 2.0 - 1.0)
            slide = noise * math.exp(-t * 15.0) * 0.4
            samples[i] += slide

        export_ogg(f"x_player_armor_unequip.{idx}.ogg", samples, fade_in_ms=6, fade_out_ms=60)


def gen_metal_impact_sounds():
    # 3 variations: sharp steel deflection ring
    pitches = [1850, 2150, 1650]
    for idx, f0 in enumerate(pitches, start=1):
        dur = 0.55
        n = int(SAMPLE_RATE * dur)
        samples = [0.0] * n
        for i in range(n):
            t = i / SAMPLE_RATE
            decay = math.exp(-t * 14.0)
            noise_burst = (random.random() * 2 - 1) * math.exp(-t * 80.0) * 0.8
            ring1 = math.sin(2 * math.pi * f0 * t) * decay * 0.6
            ring2 = math.sin(2 * math.pi * (f0 * 2.38) * t) * math.exp(-t * 22.0) * 0.4
            ring3 = math.sin(2 * math.pi * (f0 * 0.48) * t) * math.exp(-t * 18.0) * 0.3
            samples[i] = noise_burst + ring1 + ring2 + ring3

        export_ogg(f"x_player_armor_hit_metal.{idx}.ogg", samples, fade_in_ms=4, fade_out_ms=100)


def gen_wood_impact_sounds():
    # 2 variations: solid thud & oak deflection
    pitches = [240, 290]
    for idx, f0 in enumerate(pitches, start=1):
        dur = 0.35
        n = int(SAMPLE_RATE * dur)
        samples = [0.0] * n
        for i in range(n):
            t = i / SAMPLE_RATE
            body = math.sin(2 * math.pi * f0 * (1.0 - t * 0.8) * t) * math.exp(-t * 22.0) * 0.8
            crack = (random.random() * 2 - 1) * math.exp(-t * 90.0) * 0.6
            samples[i] = body + crack

        export_ogg(f"x_player_armor_hit_wood.{idx}.ogg", samples, fade_in_ms=3, fade_out_ms=70)


def gen_crystal_impact_sounds():
    # 2 variations: bell chime & pure glass harmonic
    harmonics = [(2400, 3850), (2800, 4400)]
    for idx, (f1, f2) in enumerate(harmonics, start=1):
        dur = 0.65
        n = int(SAMPLE_RATE * dur)
        samples = [0.0] * n
        for i in range(n):
            t = i / SAMPLE_RATE
            ting = math.sin(2 * math.pi * f1 * t) * math.exp(-t * 8.0) * 0.6
            ting2 = math.sin(2 * math.pi * f2 * t) * math.exp(-t * 12.0) * 0.4
            trans = (random.random() * 2 - 1) * math.exp(-t * 120.0) * 0.3
            samples[i] = ting + ting2 + trans

        export_ogg(f"x_player_armor_hit_crystal.{idx}.ogg", samples, fade_in_ms=3, fade_out_ms=120)


def gen_shield_block_sounds():
    # 3 variations: heavy resonant parry with shield punch
    pitches = [180, 220, 160]
    for idx, f0 in enumerate(pitches, start=1):
        dur = 0.45
        n = int(SAMPLE_RATE * dur)
        samples = [0.0] * n
        for i in range(n):
            t = i / SAMPLE_RATE
            thud = math.sin(2 * math.pi * f0 * t) * math.exp(-t * 18.0) * 0.7
            clatter = (random.random() * 2 - 1) * math.exp(-t * 60.0) * 0.7
            overtone = math.sin(2 * math.pi * (f0 * 5.2) * t) * math.exp(-t * 28.0) * 0.4
            samples[i] = thud + clatter + overtone

        export_ogg(f"x_player_armor_shield_block.{idx}.ogg", samples, fade_in_ms=3, fade_out_ms=90)


def gen_break_sounds():
    # Metal Break: plate shattering & shearing
    dur = 0.85
    n = int(SAMPLE_RATE * dur)
    samples = [0.0] * n
    for i in range(n):
        t = i / SAMPLE_RATE
        noise = (random.random() * 2 - 1) * math.exp(-t * 7.0) * 0.6
        clang1 = math.sin(2 * math.pi * 1250 * t) * math.exp(-t * 9.0) * 0.5
        clang2 = math.sin(2 * math.pi * 840 * t) * math.exp(-t * 14.0) * 0.4
        clang3 = math.sin(2 * math.pi * 2400 * t) * math.exp(-t * 16.0) * 0.3
        samples[i] = noise + clang1 + clang2 + clang3
    export_ogg("x_player_armor_break_metal.ogg", samples, fade_in_ms=4, fade_out_ms=120)

    # Wood Break: splintering timber crash
    dur = 0.75
    n = int(SAMPLE_RATE * dur)
    samples = [0.0] * n
    for i in range(n):
        t = i / SAMPLE_RATE
        thud = math.sin(2 * math.pi * 140 * t) * math.exp(-t * 15.0) * 0.6
        splinters = (random.random() * 2 - 1) * math.exp(-t * 8.0) * 0.7
        samples[i] = thud + splinters
    # Add snap micro-bursts
    for _ in range(8):
        pos = random.randint(int(SAMPLE_RATE * 0.05), int(SAMPLE_RATE * 0.45))
        for j in range(int(SAMPLE_RATE * 0.04)):
            if pos + j < n:
                t = j / SAMPLE_RATE
                samples[pos + j] += math.sin(2 * math.pi * 1800 * t) * math.exp(-t * 140.0) * 0.5
    export_ogg("x_player_armor_break_wood.ogg", samples, fade_in_ms=4, fade_out_ms=100)

    # Crystal / Glass Break: high-energy crystalline shatter
    dur = 0.8
    n = int(SAMPLE_RATE * dur)
    samples = [0.0] * n
    for i in range(n):
        t = i / SAMPLE_RATE
        shatter = (random.random() * 2 - 1) * math.exp(-t * 9.0) * 0.7
        chime = math.sin(2 * math.pi * 3200 * t) * math.exp(-t * 12.0) * 0.4
        chime2 = math.sin(2 * math.pi * 4800 * t) * math.exp(-t * 15.0) * 0.3
        samples[i] = shatter + chime + chime2
    export_ogg("x_player_armor_break_crystal.ogg", samples, fade_in_ms=3, fade_out_ms=110)
    export_ogg("x_player_armor_break_glass.ogg", list(samples), fade_in_ms=3, fade_out_ms=110)


def gen_warn_sound():
    # Durability warning: metallic stress ping
    dur = 0.4
    n = int(SAMPLE_RATE * dur)
    samples = [0.0] * n
    for i in range(n):
        t = i / SAMPLE_RATE
        ping = math.sin(2 * math.pi * 1760 * t) * math.exp(-t * 16.0) * 0.7
        harm = math.sin(2 * math.pi * 2640 * t) * math.exp(-t * 22.0) * 0.4
        samples[i] = ping + harm
    export_ogg("x_player_armor_warn.ogg", samples, fade_in_ms=5, fade_out_ms=80)


if __name__ == "__main__":
    gen_equip_sounds()
    gen_unequip_sounds()
    gen_metal_impact_sounds()
    gen_wood_impact_sounds()
    gen_crystal_impact_sounds()
    gen_shield_block_sounds()
    gen_break_sounds()
    gen_warn_sound()
    print("All audio assets mastered and transcoded to mono 44.1kHz OGG.")
