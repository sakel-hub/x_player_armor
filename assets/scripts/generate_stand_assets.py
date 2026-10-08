#!/usr/bin/env python3
"""
Stand Asset Generator for x_player_armor
Generates professional pixel art textures and 16x16 inventory icons:
  - textures/x_player_armor_stand_shared.png (64x64)
  - textures/x_player_armor_stand_locked.png (64x64)
  - textures/x_player_armor_stand_inv.png (16x16)
  - textures/x_player_armor_stand_locked_inv.png (16x16)
"""

import os
import struct
import zlib

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
MOD_DIR = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))
TEXTURES_DIR = os.path.join(MOD_DIR, "textures")
os.makedirs(TEXTURES_DIR, exist_ok=True)


def write_png(filename, width, height, rgba_data):
    """Writes a 32-bit RGBA PNG file using pure Python zlib and struct."""
    sig = b"\x89PNG\r\n\x1a\n"
    ihdr_data = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    ihdr = b"IHDR" + ihdr_data
    ihdr_chunk = struct.pack(">I", len(ihdr_data)) + ihdr + struct.pack(">I", zlib.crc32(ihdr) & 0xFFFFFFFF)

    raw = bytearray()
    for y in range(height):
        raw.append(0)  # Filter type 0 (None)
        raw.extend(rgba_data[y * width * 4 : (y + 1) * width * 4])

    compressed = zlib.compress(bytes(raw), 9)
    idat = b"IDAT" + compressed
    idat_chunk = struct.pack(">I", len(compressed)) + idat + struct.pack(">I", zlib.crc32(idat) & 0xFFFFFFFF)

    iend = b"IEND"
    iend_chunk = struct.pack(">I", 0) + iend + struct.pack(">I", zlib.crc32(iend) & 0xFFFFFFFF)

    with open(filename, "wb") as f:
        f.write(sig + ihdr_chunk + idat_chunk + iend_chunk)


class PixelCanvas:
    """A 2D pixel buffer with (0,0) at bottom-left and (width-1, height-1) at top-right."""

    def __init__(self, width, height):
        self.w = width
        self.h = height
        self.pixels = bytearray([0, 0, 0, 0] * (width * height))

    def set_pixel(self, x, y, rgba):
        if 0 <= x < self.w and 0 <= y < self.h:
            # PNG file rows go from top (y=h-1) down to bottom (y=0)
            png_row = (self.h - 1) - y
            idx = (png_row * self.w + x) * 4
            self.pixels[idx : idx + 4] = bytearray(rgba)

    def fill_rect(self, x0, x1, y0, y1, rgba):
        for y in range(y0, y1):
            for x in range(x0, x1):
                self.set_pixel(x, y, rgba)

    def save(self, filepath):
        write_png(filepath, self.w, self.h, self.pixels)


# --- PALETTES ---
# Wood tones
W_SHADOW_DEEP = (62, 39, 20, 255)
W_SHADOW_MID  = (92, 61, 30, 255)
W_BASE_DARK   = (112, 75, 37, 255)
W_BASE        = (130, 87, 43, 255)
W_BASE_LIGHT  = (148, 99, 49, 255)
W_HIGHLIGHT   = (172, 118, 62, 255)
W_BEVEL       = (204, 145, 82, 255)
W_TOP_LIGHT   = (222, 162, 98, 255)

# Brass / Copper accents (Shared stand)
B_DARK        = (110, 70, 20, 255)
B_MID         = (185, 130, 30, 255)
B_LIGHT       = (230, 180, 55, 255)
B_GLEAM       = (255, 225, 130, 255)

# Steel / Iron accents (Locked stand)
S_DARKEST     = (32, 34, 40, 255)
S_DARK        = (56, 60, 72, 255)
S_MID         = (92, 100, 118, 255)
S_LIGHT       = (145, 156, 178, 255)
S_GLEAM       = (215, 224, 238, 255)


def generate_stand_texture(is_locked=False):
    canvas = PixelCanvas(64, 64)

    # 1. Base Slab Top Face (16x16: X in [0, 16], Y in [48, 64])
    # 4 distinct wooden planks running horizontally with subtle grain
    for p in range(4):
        py0 = 48 + p * 4
        for y in range(py0, py0 + 4):
            for x in range(0, 16):
                # Base plank color with grain noise
                if y == py0:
                    c = W_SHADOW_MID  # Plank seam
                elif y == py0 + 3:
                    c = W_BASE_LIGHT if (x % 3 != 0) else W_HIGHLIGHT
                else:
                    c = W_BASE if ((x + y) % 4 != 0) else W_BASE_LIGHT
                canvas.set_pixel(x, y, c)

    # Bevel around outer border of Base Top
    for x in range(0, 16):
        canvas.set_pixel(x, 63, W_TOP_LIGHT)   # Top edge highlight
        canvas.set_pixel(x, 48, W_SHADOW_DEEP) # Bottom edge shadow
    for y in range(48, 64):
        canvas.set_pixel(0, y, W_BEVEL)        # Left edge highlight
        canvas.set_pixel(15, y, W_SHADOW_MID)  # Right edge shadow

    # Base Bottom Face (16x16: X in [16, 32], Y in [48, 64])
    canvas.fill_rect(16, 32, 48, 64, W_SHADOW_DEEP)
    for y in range(49, 63):
        for x in range(17, 31):
            canvas.set_pixel(x, y, W_SHADOW_MID if (x + y) % 3 == 0 else W_BASE_DARK)

    # Metal corner brackets on Base Top:
    metal_dark = S_DARK if is_locked else B_DARK
    metal_mid = S_MID if is_locked else B_MID
    metal_light = S_LIGHT if is_locked else B_LIGHT
    metal_gleam = S_GLEAM if is_locked else B_GLEAM

    corners = [(0, 48), (12, 48), (0, 60), (12, 60)]
    for cx, cy in corners:
        # 4x4 L-bracket
        for dy in range(4):
            for dx in range(4):
                if (dx <= 1 or dy <= 1) or (dx >= 2 and dy >= 2 and (dx + dy <= 5)):
                    canvas.set_pixel(cx + dx, cy + dy, metal_mid)
        # Highlight and rivet
        canvas.set_pixel(cx + 1, cy + 1, metal_light)
        canvas.set_pixel(cx + 2, cy + 2, metal_gleam)

    # 2. Base 4 Side Rims (each 16x2 at Y in [46, 48])
    for i, x0 in enumerate([0, 16, 32, 48]):
        for x in range(x0, x0 + 16):
            canvas.set_pixel(x, 47, W_BEVEL if i == 0 else W_BASE_LIGHT)
            canvas.set_pixel(x, 46, W_SHADOW_DEEP)
        # Metal brackets on side rim ends
        canvas.set_pixel(x0, 47, metal_light)
        canvas.set_pixel(x0, 46, metal_dark)
        canvas.set_pixel(x0 + 15, 47, metal_light)
        canvas.set_pixel(x0 + 15, 46, metal_dark)

    # 3. Shoulder Crossbar (12x2 faces at Y in [38, 42])
    # Front [0..12, 38..40] & Back [12..24, 38..40]
    for x in range(0, 24):
        canvas.set_pixel(x, 39, W_BASE_LIGHT)
        canvas.set_pixel(x, 38, W_BASE)
    # Top [0..12, 40..42] & Bottom [12..24, 40..42]
    for x in range(0, 12):
        canvas.set_pixel(x, 41, W_TOP_LIGHT)
        canvas.set_pixel(x, 40, W_BEVEL)
    for x in range(12, 24):
        canvas.set_pixel(x, 41, W_SHADOW_MID)
        canvas.set_pixel(x, 40, W_SHADOW_DEEP)
    # Caps [24..28, 38..40]
    canvas.fill_rect(24, 28, 38, 40, W_BASE)

    # Shoulder Joint Brackets / Bands:
    # Outer arm joints (cols 0-1 and 10-11)
    for bx in [0, 10, 12, 22]:
        canvas.set_pixel(bx, 39, metal_light)
        canvas.set_pixel(bx, 38, metal_dark)
        canvas.set_pixel(bx + 1, 39, metal_gleam)
        canvas.set_pixel(bx + 1, 38, metal_mid)

    # 4. Hip Crossbar (6x2 faces at Y in [38, 42])
    # Front [30..36, 38..40] & Back [36..42, 38..40]
    for x in range(30, 42):
        canvas.set_pixel(x, 39, W_BASE_LIGHT)
        canvas.set_pixel(x, 38, W_BASE)
    # Top [30..36, 40..42] & Bottom [36..42, 40..42]
    for x in range(30, 36):
        canvas.set_pixel(x, 41, W_TOP_LIGHT)
        canvas.set_pixel(x, 40, W_BEVEL)
    for x in range(36, 42):
        canvas.set_pixel(x, 41, W_SHADOW_MID)
        canvas.set_pixel(x, 40, W_SHADOW_DEEP)
    # Caps [42..46, 38..40]
    canvas.fill_rect(42, 46, 38, 40, W_BASE)

    # 5. Neck / Head Peg (2x7 faces at Y in [28, 35], cap [0..2, 35..37])
    for dy in range(7):
        y = 28 + dy
        # Front [0..2]
        canvas.set_pixel(0, y, W_HIGHLIGHT)
        canvas.set_pixel(1, y, W_BASE)
        # Right [2..4]
        canvas.set_pixel(2, y, W_BASE)
        canvas.set_pixel(3, y, W_SHADOW_MID)
        # Back [4..6]
        canvas.set_pixel(4, y, W_SHADOW_MID)
        canvas.set_pixel(5, y, W_SHADOW_DEEP)
        # Left [6..8]
        canvas.set_pixel(6, y, W_HIGHLIGHT)
        canvas.set_pixel(7, y, W_BASE)
    # Top Cap [0..2, 35..37]
    canvas.fill_rect(0, 2, 35, 37, W_BEVEL)
    canvas.set_pixel(0, 35, W_TOP_LIGHT)

    # 6. Torso Posts (2x7 faces at Y in [28, 35])
    # Left Torso [10..18, 28..35]
    for dy in range(7):
        y = 28 + dy
        canvas.set_pixel(10, y, W_HIGHLIGHT)
        canvas.set_pixel(11, y, W_BASE)
        canvas.set_pixel(12, y, W_BASE)
        canvas.set_pixel(13, y, W_SHADOW_MID)
        canvas.set_pixel(14, y, W_SHADOW_MID)
        canvas.set_pixel(15, y, W_SHADOW_DEEP)
        canvas.set_pixel(16, y, W_HIGHLIGHT)
        canvas.set_pixel(17, y, W_BASE)
    # Right Torso [20..28, 28..35]
    for dy in range(7):
        y = 28 + dy
        canvas.set_pixel(20, y, W_HIGHLIGHT)
        canvas.set_pixel(21, y, W_BASE)
        canvas.set_pixel(22, y, W_BASE)
        canvas.set_pixel(23, y, W_SHADOW_MID)
        canvas.set_pixel(24, y, W_SHADOW_MID)
        canvas.set_pixel(25, y, W_SHADOW_DEEP)
        canvas.set_pixel(26, y, W_HIGHLIGHT)
        canvas.set_pixel(27, y, W_BASE)

    # 7. Arm Sticks (2x8 faces at Y in [16, 24], caps [.. 24..26])
    # Left Arm [0..8, 16..24]
    for dy in range(8):
        y = 16 + dy
        canvas.set_pixel(0, y, W_HIGHLIGHT)
        canvas.set_pixel(1, y, W_BASE)
        canvas.set_pixel(2, y, W_BASE)
        canvas.set_pixel(3, y, W_SHADOW_MID)
        canvas.set_pixel(4, y, W_SHADOW_MID)
        canvas.set_pixel(5, y, W_SHADOW_DEEP)
        canvas.set_pixel(6, y, W_HIGHLIGHT)
        canvas.set_pixel(7, y, W_BASE)
    # Bottom Hand Cap [0..2, 24..26]
    canvas.fill_rect(0, 2, 24, 26, W_BEVEL)

    # Right Arm [10..18, 16..24]
    for dy in range(8):
        y = 16 + dy
        canvas.set_pixel(10, y, W_HIGHLIGHT)
        canvas.set_pixel(11, y, W_BASE)
        canvas.set_pixel(12, y, W_BASE)
        canvas.set_pixel(13, y, W_SHADOW_MID)
        canvas.set_pixel(14, y, W_SHADOW_MID)
        canvas.set_pixel(15, y, W_SHADOW_DEEP)
        canvas.set_pixel(16, y, W_HIGHLIGHT)
        canvas.set_pixel(17, y, W_BASE)
    # Bottom Hand Cap [10..12, 24..26]
    canvas.fill_rect(10, 12, 24, 26, W_BEVEL)

    # 8. Leg Posts (2x9 faces at Y in [2, 11], bottom caps [.. 0..2])
    # Left Leg [0..8, 2..11]
    for dy in range(9):
        y = 2 + dy
        canvas.set_pixel(0, y, W_HIGHLIGHT)
        canvas.set_pixel(1, y, W_BASE)
        canvas.set_pixel(2, y, W_BASE)
        canvas.set_pixel(3, y, W_SHADOW_MID)
        canvas.set_pixel(4, y, W_SHADOW_MID)
        canvas.set_pixel(5, y, W_SHADOW_DEEP)
        canvas.set_pixel(6, y, W_HIGHLIGHT)
        canvas.set_pixel(7, y, W_BASE)
    canvas.fill_rect(0, 2, 0, 2, W_SHADOW_DEEP)

    # Right Leg [10..18, 2..11]
    for dy in range(9):
        y = 2 + dy
        canvas.set_pixel(10, y, W_HIGHLIGHT)
        canvas.set_pixel(11, y, W_BASE)
        canvas.set_pixel(12, y, W_BASE)
        canvas.set_pixel(13, y, W_SHADOW_MID)
        canvas.set_pixel(14, y, W_SHADOW_MID)
        canvas.set_pixel(15, y, W_SHADOW_DEEP)
        canvas.set_pixel(16, y, W_HIGHLIGHT)
        canvas.set_pixel(17, y, W_BASE)
    canvas.fill_rect(10, 12, 0, 2, W_SHADOW_DEEP)

    # 9. Locked Variant Special: Heavy Forged Padlock on Chest / Hip
    if is_locked:
        # Paint a crisp metallic padlock over the hip/torso front region
        # Padlock shackle at shoulder center front [5..7, 39..40]
        canvas.set_pixel(5, 39, S_LIGHT)
        canvas.set_pixel(6, 39, S_GLEAM)
        canvas.set_pixel(5, 38, S_DARK)
        canvas.set_pixel(6, 38, S_DARK)
        # Padlock steel body [32..36, 38..40] on hip front
        canvas.set_pixel(33, 39, S_LIGHT)
        canvas.set_pixel(34, 39, S_GLEAM)
        canvas.set_pixel(33, 38, (20, 20, 25, 255)) # Keyhole
        canvas.set_pixel(34, 38, S_MID)

    return canvas


def generate_inventory_icon(is_locked=False):
    canvas = PixelCanvas(16, 16)

    # Palette
    metal_dark = S_DARK if is_locked else B_DARK
    metal_mid = S_MID if is_locked else B_MID
    metal_light = S_LIGHT if is_locked else B_LIGHT
    metal_gleam = S_GLEAM if is_locked else B_GLEAM

    # Base Pedestal (Rows Y in [0, 2] = Canvas Y=13..15 from top):
    # Base top surface at Y=2
    for x in range(2, 14):
        canvas.set_pixel(x, 2, W_BEVEL)
    # Base rim at Y=1
    for x in range(2, 14):
        canvas.set_pixel(x, 1, W_BASE)
    # Base shadow at Y=0
    for x in range(3, 13):
        canvas.set_pixel(x, 0, W_SHADOW_DEEP)

    # Metal corner brackets on base
    canvas.set_pixel(2, 2, metal_gleam)
    canvas.set_pixel(3, 2, metal_light)
    canvas.set_pixel(2, 1, metal_mid)
    canvas.set_pixel(13, 2, metal_light)
    canvas.set_pixel(12, 2, metal_mid)
    canvas.set_pixel(13, 1, metal_dark)

    # Leg Posts (Y in [3, 5])
    for y in range(3, 6):
        canvas.set_pixel(5, y, W_HIGHLIGHT)
        canvas.set_pixel(6, y, W_BASE)
        canvas.set_pixel(9, y, W_BASE)
        canvas.set_pixel(10, y, W_SHADOW_MID)

    # Hip Crossbar (Y=6)
    for x in range(4, 12):
        canvas.set_pixel(x, 6, W_BASE_LIGHT)
    canvas.set_pixel(4, 6, W_HIGHLIGHT)
    canvas.set_pixel(11, 6, W_SHADOW_MID)

    # Torso Posts (Y in [7, 10])
    for y in range(7, 11):
        canvas.set_pixel(5, y, W_HIGHLIGHT)
        canvas.set_pixel(6, y, W_BASE)
        canvas.set_pixel(9, y, W_BASE)
        canvas.set_pixel(10, y, W_SHADOW_MID)

    # Arm Sticks (Y in [6, 10], cols 2 and 13)
    for y in range(6, 11):
        canvas.set_pixel(2, y, W_HIGHLIGHT)
        canvas.set_pixel(13, y, W_SHADOW_MID)
    # Hand ends (Y=5)
    canvas.set_pixel(2, 5, W_BEVEL)
    canvas.set_pixel(13, 5, W_BASE)

    # Shoulder Crossbar (Y in [11, 12], cols 2 to 13)
    for x in range(2, 14):
        canvas.set_pixel(x, 12, W_TOP_LIGHT)
        canvas.set_pixel(x, 11, W_BASE)

    # Shoulder Joint Brackets
    canvas.set_pixel(2, 12, metal_gleam)
    canvas.set_pixel(3, 12, metal_light)
    canvas.set_pixel(2, 11, metal_mid)
    canvas.set_pixel(13, 12, metal_light)
    canvas.set_pixel(12, 12, metal_mid)
    canvas.set_pixel(13, 11, metal_dark)

    # Neck / Head Peg (Y in [13, 15], cols 7 and 8)
    for y in range(13, 15):
        canvas.set_pixel(7, y, W_HIGHLIGHT)
        canvas.set_pixel(8, y, W_BASE)
    # Head cap
    canvas.set_pixel(7, 15, W_TOP_LIGHT)
    canvas.set_pixel(8, 15, W_BEVEL)

    # Locked Variant Icon: Padlock on chest (Y in [8, 10], cols 7 and 8)
    if is_locked:
        # Shackle
        canvas.set_pixel(7, 10, S_LIGHT)
        canvas.set_pixel(8, 10, S_GLEAM)
        # Body
        canvas.set_pixel(7, 9, S_MID)
        canvas.set_pixel(8, 9, S_LIGHT)
        # Keyhole
        canvas.set_pixel(7, 8, (20, 20, 25, 255))
        canvas.set_pixel(8, 8, (230, 180, 55, 255)) # Brass tumbler

    return canvas


def main():
    print("Generating stand textures...")
    tex_shared = generate_stand_texture(is_locked=False)
    tex_shared_path = os.path.join(TEXTURES_DIR, "x_player_armor_stand_shared.png")
    tex_shared.save(tex_shared_path)
    print(f"Generated {tex_shared_path} ({os.path.getsize(tex_shared_path)} bytes)")

    tex_locked = generate_stand_texture(is_locked=True)
    tex_locked_path = os.path.join(TEXTURES_DIR, "x_player_armor_stand_locked.png")
    tex_locked.save(tex_locked_path)
    print(f"Generated {tex_locked_path} ({os.path.getsize(tex_locked_path)} bytes)")

    print("Generating stand inventory icons (16x16)...")
    icon_shared = generate_inventory_icon(is_locked=False)
    icon_shared_path = os.path.join(TEXTURES_DIR, "x_player_armor_stand_inv.png")
    icon_shared.save(icon_shared_path)
    print(f"Generated {icon_shared_path} ({os.path.getsize(icon_shared_path)} bytes)")

    icon_locked = generate_inventory_icon(is_locked=True)
    icon_locked_path = os.path.join(TEXTURES_DIR, "x_player_armor_stand_locked_inv.png")
    icon_locked.save(icon_locked_path)
    print(f"Generated {icon_locked_path} ({os.path.getsize(icon_locked_path)} bytes)")


if __name__ == "__main__":
    main()
