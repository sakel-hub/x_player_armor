#!/usr/bin/env python3
"""
Armor Stand Audio Asset Sourcing & Mastering Pipeline
Implements the Luanti Sound Effects Engineering standard (.agents/skills/luanti-sounds/SKILL.md):
- Sourced from Freesound.org under Creative Commons 0 (CC0 1.0 Universal)
- Mastered to Mono (1 channel) for OpenAL 3D spatial attenuation
- 44,100 Hz sampling rate
- Silence trimming & anti-click micro-fades (zero-crossing)
- Peak volume normalization to -1.0 dBFS (~0.89 linear)
- Multi-sample variations (<name>.<n>.ogg)
"""

import os
import math
import tempfile
import urllib.request
import aud
import numpy as np

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
MOD_DIR = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))
SOUNDS_DIR = os.path.join(MOD_DIR, "sounds")
TMP_DIR = os.path.join(SCRIPT_DIR, "_tmp")
os.makedirs(SOUNDS_DIR, exist_ok=True)
os.makedirs(TMP_DIR, exist_ok=True)

TARGET_SAMPLE_RATE = 44100
TARGET_PEAK = 0.89  # -1.0 dBFS

SOUND_MANIFEST = [
    # 1. Place sounds (wooden object / stand set down onto floor)
    {
        "filename": "x_player_armor_stand_place.1.ogg",
        "url": "https://cdn.freesound.org/previews/449/449955_9159316-hq.mp3",
        "title": "Wooden Thud (Mono)",
        "sound_id": 449955,
        "author": "Breviceps",
        "license": "CC0 1.0 Universal",
        "max_duration": 0.50,
        "trim_threshold": 0.02,
        "fade_in_ms": 6,
        "fade_out_ms": 60,
    },
    # 2. Dig sounds (wood chopping / punching impacts)
    {
        "filename": "x_player_armor_stand_dig.1.ogg",
        "url": "https://cdn.freesound.org/previews/381/381617_1304060-hq.mp3",
        "title": "snd_ImpactSmallWood01.wav",
        "sound_id": 381617,
        "author": "dorian.mastin",
        "license": "CC0 1.0 Universal",
        "max_duration": 0.35,
        "trim_threshold": 0.02,
        "fade_in_ms": 10,
        "fade_out_ms": 50,
    },
    {
        "filename": "x_player_armor_stand_dig.2.ogg",
        "url": "https://cdn.freesound.org/previews/536/536736_1415754-hq.mp3",
        "title": "Chop.ogg",
        "sound_id": 536736,
        "author": "egomassive",
        "license": "CC0 1.0 Universal",
        "max_duration": 0.40,
        "trim_threshold": 0.02,
        "fade_in_ms": 8,
        "fade_out_ms": 60,
    },
    {
        "filename": "x_player_armor_stand_dig.3.ogg",
        "url": "https://cdn.freesound.org/previews/569/569723_3248005-hq.mp3",
        "title": "Wood impact Single Plank 3",
        "sound_id": 569723,
        "author": "Sheyvan",
        "license": "CC0 1.0 Universal",
        "max_duration": 0.35,
        "trim_threshold": 0.02,
        "fade_in_ms": 8,
        "fade_out_ms": 50,
    },
    # 3. Dug sounds (wood breaking / dismantling into item drop)
    {
        "filename": "x_player_armor_stand_dug.1.ogg",
        "url": "https://cdn.freesound.org/previews/66/66780_242154-hq.mp3",
        "title": "Crate Break 4.wav",
        "sound_id": 66780,
        "author": "kevinkace",
        "license": "CC0 1.0 Universal",
        "max_duration": 0.70,
        "trim_threshold": 0.015,
        "fade_in_ms": 10,
        "fade_out_ms": 90,
    },
    {
        "filename": "x_player_armor_stand_dug.2.ogg",
        "url": "https://cdn.freesound.org/previews/66/66772_242154-hq.mp3",
        "title": "Barrel Break 4.wav",
        "sound_id": 66772,
        "author": "kevinkace",
        "license": "CC0 1.0 Universal",
        "max_duration": 0.70,
        "trim_threshold": 0.015,
        "fade_in_ms": 10,
        "fade_out_ms": 90,
    },
    # 4. Footstep sounds (walking / stepping on wooden base)
    {
        "filename": "x_player_armor_stand_footstep.1.ogg",
        "url": "https://cdn.freesound.org/previews/421/421152_5820033-hq.mp3",
        "title": "Footstep_Wood_Toe_2.wav",
        "sound_id": 421152,
        "author": "GiocoSound",
        "license": "CC0 1.0 Universal",
        "max_duration": 0.25,
        "trim_threshold": 0.015,
        "fade_in_ms": 6,
        "fade_out_ms": 40,
    },
    {
        "filename": "x_player_armor_stand_footstep.2.ogg",
        "url": "https://cdn.freesound.org/previews/421/421153_5820033-hq.mp3",
        "title": "Footstep_Wood_Toe_1.wav",
        "sound_id": 421153,
        "author": "GiocoSound",
        "license": "CC0 1.0 Universal",
        "max_duration": 0.30,
        "trim_threshold": 0.015,
        "fade_in_ms": 8,
        "fade_out_ms": 40,
    },
]


def process_sound(spec):
    fn = spec["filename"]
    url = spec["url"]
    out_path = os.path.join(SOUNDS_DIR, fn)

    print(f"Downloading {fn} from Freesound #{spec['sound_id']}...")
    with tempfile.NamedTemporaryFile(dir=TMP_DIR, suffix=".mp3", delete=False) as tf:
        tmp_download = tf.name

    try:
        req = urllib.request.Request(
            url,
            headers={"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"},
        )
        with urllib.request.urlopen(req, timeout=15) as resp, open(tmp_download, "wb") as out_f:
            out_f.write(resp.read())

        if os.path.getsize(tmp_download) < 1000:
            raise RuntimeError(f"Downloaded file too small: {os.path.getsize(tmp_download)} bytes")

        # Load into aud engine
        snd = aud.Sound(tmp_download)
        rate, channels = snd.specs
        data = snd.data()

        # Downmix to mono if stereo/multichannel
        if len(data.shape) > 1 and data.shape[1] > 1:
            mono = np.mean(data, axis=1)
        else:
            mono = data.flatten()

        # Resample to 44.1 kHz if necessary
        if int(rate) != TARGET_SAMPLE_RATE:
            resampled_snd = aud.Sound.buffer(mono.reshape(-1, 1).astype(np.float32), int(rate)).resample(TARGET_SAMPLE_RATE, 2)
            mono = resampled_snd.data().flatten()
            rate = TARGET_SAMPLE_RATE

        rate = int(rate)

        # Trim leading/trailing silence based on threshold
        thresh = spec.get("trim_threshold", 0.02)
        abs_s = np.abs(mono)
        above = np.where(abs_s > thresh)[0]
        if len(above) > 0:
            # Keep 5ms pre-transient pad to preserve acoustic attack
            pre_pad = int(0.005 * rate)
            # Keep 40ms post-decay tail before fadeout
            post_pad = int(0.040 * rate)
            start_idx = max(0, above[0] - pre_pad)
            end_idx = min(len(mono), above[-1] + post_pad)
            mono = mono[start_idx:end_idx]

        # Enforce max duration
        max_dur = spec.get("max_duration", 1.0)
        max_samples = int(max_dur * rate)
        if len(mono) > max_samples:
            mono = mono[:max_samples]

        # Anti-click micro-fades (raised cosine)
        fade_in_len = min(len(mono) // 4, int(spec.get("fade_in_ms", 15) * rate / 1000.0))
        fade_out_len = min(len(mono) // 4, int(spec.get("fade_out_ms", 70) * rate / 1000.0))

        if fade_in_len > 0:
            fade_in = 0.5 * (1.0 - np.cos(np.pi * np.arange(fade_in_len) / fade_in_len))
            mono[:fade_in_len] *= fade_in

        if fade_out_len > 0:
            fade_out = 0.5 * (1.0 + np.cos(np.pi * np.arange(fade_out_len) / fade_out_len))
            mono[-fade_out_len:] *= fade_out

        # Peak normalization to -1.0 dBFS (0.89 linear amplitude)
        peak = np.max(np.abs(mono))
        if peak > 1e-4:
            mono = mono * (TARGET_PEAK / peak)

        # Write to OGG Vorbis 44.1kHz mono via aud
        mono_buf = mono.reshape(-1, 1).astype(np.float32)
        out_snd = aud.Sound.buffer(mono_buf, TARGET_SAMPLE_RATE)
        out_snd.write(
            out_path,
            rate=TARGET_SAMPLE_RATE,
            channels=aud.CHANNELS_MONO,
            format=aud.FORMAT_S16,
            container=aud.CONTAINER_OGG,
            codec=aud.CODEC_VORBIS,
            bitrate=128000,
        )

        # Verify output
        v_snd = aud.Sound.file(out_path)
        v_rate, v_chan = v_snd.specs
        v_size = os.path.getsize(out_path)
        print(f"  [OK] Mastered {fn}: {v_size} bytes, {v_rate}Hz, channels={v_chan}")

    finally:
        if os.path.exists(tmp_download):
            os.remove(tmp_download)


def main():
    print("=== Mastering Armor Stand Sounds for Luanti ===")
    for spec in SOUND_MANIFEST:
        process_sound(spec)
    print("=== All Stand Sounds Mastered Successfully ===")


if __name__ == "__main__":
    main()
