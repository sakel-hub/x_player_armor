import zlib, struct, binascii, os

def write_png_rgba(path, width, height, pixels):
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        for x in range(width):
            r, g, b, a = pixels[y][x]
            raw.extend([r, g, b, a])
    compressed = zlib.compress(bytes(raw), 9)
    def make_chunk(chunk_type, data):
        length = len(data)
        crc = binascii.crc32(chunk_type + data) & 0xffffffff
        return struct.pack('>I', length) + chunk_type + data + struct.pack('>I', crc)
    png = bytearray(b'\x89PNG\r\n\x1a\n')
    ihdr_data = struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)
    png.extend(make_chunk(b'IHDR', ihdr_data))
    png.extend(make_chunk(b'IDAT', compressed))
    png.extend(make_chunk(b'IEND', b''))
    with open(path, 'wb') as f:
        f.write(png)

def create_particle_sheet():
    width = 16
    frame_h = 16
    num_frames = 8
    total_h = frame_h * num_frames

    # Initialize blank 16x128 canvas
    canvas = [[(0, 0, 0, 0) for _ in range(width)] for _ in range(total_h)]

    def blend_pixel(x, y, r, g, b, a):
        if 0 <= x < width and 0 <= y < total_h and a > 0:
            cr, cg, cb, ca = canvas[y][x]
            if ca == 0:
                canvas[y][x] = (r, g, b, a)
            else:
                # Alpha composite
                alpha_out = a + ca * (255 - a) // 255
                if alpha_out > 0:
                    r_out = (r * a + cr * ca * (255 - a) // 255) // alpha_out
                    g_out = (g * a + cg * ca * (255 - a) // 255) // alpha_out
                    b_out = (b * a + cb * ca * (255 - a) // 255) // alpha_out
                    canvas[y][x] = (min(255, r_out), min(255, g_out), min(255, b_out), min(255, alpha_out))

    # =========================================================================
    # FRAME 0: Golden Heal Star (y: 0..15)
    # Luminous 4-pointed radiant divine sparkle / holy glint
    # =========================================================================
    fy0 = 0
    # Core 2x2 blinding white
    for dx in (7, 8):
        for dy in (7, 8):
            canvas[fy0 + dy][dx] = (255, 255, 250, 255)

    # Inner bright yellow corona
    for dx, dy in [(6,7), (6,8), (9,7), (9,8), (7,6), (8,6), (7,9), (8,9)]:
        canvas[fy0 + dy][dx] = (255, 245, 160, 255)

    # 4 Main Cardinal Rays (Vertical & Horizontal)
    ray_coords = [
        # (dx, dy, (r, g, b, a))
        (7, 5, (255, 225, 70, 245)), (8, 5, (255, 225, 70, 245)),
        (7, 10, (255, 225, 70, 245)), (8, 10, (255, 225, 70, 245)),
        (5, 7, (255, 225, 70, 245)), (5, 8, (255, 225, 70, 245)),
        (10, 7, (255, 225, 70, 245)), (10, 8, (255, 225, 70, 245)),

        (7, 4, (255, 205, 40, 220)), (8, 4, (255, 205, 40, 220)),
        (7, 11, (255, 205, 40, 220)), (8, 11, (255, 205, 40, 220)),
        (4, 7, (255, 205, 40, 220)), (4, 8, (255, 205, 40, 220)),
        (11, 7, (255, 205, 40, 220)), (11, 8, (255, 205, 40, 220)),

        (7, 3, (250, 175, 25, 180)), (8, 3, (250, 175, 25, 180)),
        (7, 12, (250, 175, 25, 180)), (8, 12, (250, 175, 25, 180)),
        (3, 7, (250, 175, 25, 180)), (3, 8, (250, 175, 25, 180)),
        (12, 7, (250, 175, 25, 180)), (12, 8, (250, 175, 25, 180)),

        (7, 2, (240, 140, 15, 120)), (8, 2, (240, 140, 15, 120)),
        (7, 13, (240, 140, 15, 120)), (8, 13, (240, 140, 15, 120)),
        (2, 7, (240, 140, 15, 120)), (2, 8, (240, 140, 15, 120)),
        (13, 7, (240, 140, 15, 120)), (13, 8, (240, 140, 15, 120)),

        (7, 1, (230, 110, 10, 60)), (8, 1, (230, 110, 10, 60)),
        (7, 14, (230, 110, 10, 60)), (8, 14, (230, 110, 10, 60)),
        (1, 7, (230, 110, 10, 60)), (1, 8, (230, 110, 10, 60)),
        (14, 7, (230, 110, 10, 60)), (14, 8, (230, 110, 10, 60)),
    ]
    for dx, dy, col in ray_coords:
        canvas[fy0 + dy][dx] = col

    # Diagonal glints
    diag_coords = [
        (6, 6, (255, 235, 120, 230)), (9, 6, (255, 235, 120, 230)),
        (6, 9, (255, 235, 120, 230)), (9, 9, (255, 235, 120, 230)),
        (5, 5, (255, 195, 45, 160)), (10, 5, (255, 195, 45, 160)),
        (5, 10, (255, 195, 45, 160)), (10, 10, (255, 195, 45, 160)),
        (4, 4, (245, 155, 20, 80)), (11, 4, (245, 155, 20, 80)),
        (4, 11, (245, 155, 20, 80)), (11, 11, (245, 155, 20, 80)),
    ]
    for dx, dy, col in diag_coords:
        canvas[fy0 + dy][dx] = col

    # Soft ambient corona halo
    for dx, dy in [(5,6), (6,5), (9,5), (10,6), (5,9), (6,10), (9,10), (10,9)]:
        canvas[fy0 + dy][dx] = (255, 210, 50, 65)

    # =========================================================================
    # FRAME 1: Emerald Rejuvenation Cross (y: 16..31)
    # Luminous restorative emerald life emblem
    # =========================================================================
    fy1 = 16
    # Cross layout:
    # Vertical bar: x in 6..9, y in 2..13 (local)
    # Horizontal bar: x in 2..13, y in 6..9 (local)

    # Ambient healing glow aura around cross
    for ly in range(1, 15):
        for lx in range(1, 15):
            in_v = (5 <= lx <= 10 and 1 <= ly <= 14)
            in_h = (1 <= lx <= 14 and 5 <= ly <= 10)
            if in_v or in_h:
                canvas[fy1 + ly][lx] = (40, 240, 140, 45)

    # Outer border / bevel (deep verdant green)
    border_pixels = []
    # Vertical arm top/bottom caps and edges
    for lx in range(6, 10):
        border_pixels.extend([(lx, 2), (lx, 13)])
    for ly in range(3, 6):
        border_pixels.extend([(6, ly), (9, ly)])
    for ly in range(10, 13):
        border_pixels.extend([(6, ly), (9, ly)])

    # Horizontal arm left/right caps and edges
    for ly in range(6, 10):
        border_pixels.extend([(2, ly), (13, ly)])
    for lx in range(3, 6):
        border_pixels.extend([(lx, 6), (lx, 9)])
    for lx in range(10, 13):
        border_pixels.extend([(lx, 6), (lx, 9)])

    for lx, ly in border_pixels:
        canvas[fy1 + ly][lx] = (12, 120, 60, 230)

    # Inner Cross Fill: Rich emerald & celestial green
    for ly in range(3, 13):
        for lx in range(7, 9):
            canvas[fy1 + ly][lx] = (35, 215, 120, 255)
    for ly in range(7, 9):
        for lx in range(3, 13):
            canvas[fy1 + ly][lx] = (35, 215, 120, 255)

    # High-intensity inner core & cross bar highlights
    for lx in range(7, 9):
        for ly in range(4, 12):
            canvas[fy1 + ly][lx] = (90, 250, 165, 255)
    for ly in range(7, 9):
        for lx in range(4, 12):
            canvas[fy1 + ly][lx] = (90, 250, 165, 255)

    # Blinding mint-white center glint
    for lx in (7, 8):
        for ly in (7, 8):
            canvas[fy1 + ly][lx] = (235, 255, 245, 255)

    # Corner sparkle gleams
    for lx, ly in [(4, 4), (11, 4), (4, 11), (11, 11)]:
        canvas[fy1 + ly][lx] = (160, 255, 205, 140)

    # =========================================================================
    # FRAME 2: Golden Ascending Mote / Sparkle Orb (y: 32..47)
    # Floating concentrated magical life essence
    # =========================================================================
    fy2 = 32
    cx, cy = 7.5, 7.5
    for ly in range(16):
        for lx in range(16):
            dx = lx - cx
            dy = ly - cy
            dist = (dx * dx + dy * dy) ** 0.5
            if dist <= 1.5:
                canvas[fy2 + ly][lx] = (255, 255, 250, 255)
            elif dist <= 2.6:
                canvas[fy2 + ly][lx] = (255, 235, 95, 245)
            elif dist <= 4.0:
                canvas[fy2 + ly][lx] = (255, 185, 30, 190)
            elif dist <= 5.5:
                canvas[fy2 + ly][lx] = (245, 135, 12, 100)
            elif dist <= 7.0:
                canvas[fy2 + ly][lx] = (220, 85, 0, 35)

    # Floating ascending micro-motes
    canvas[fy2 + 2][7] = (255, 245, 160, 200)
    canvas[fy2 + 1][8] = (255, 220, 80, 140)
    canvas[fy2 + 3][6] = (250, 190, 40, 120)
    canvas[fy2 + 12][8] = (240, 140, 20, 130)
    canvas[fy2 + 14][7] = (220, 100, 10, 80)

    # =========================================================================
    # FRAME 3: Electric Cyan Shield Deflection Flash (y: 48..63)
    # Impact barrier deflection flash for shield blocks
    # =========================================================================
    fy3 = 48
    # High energy horizontal streak
    for lx in range(1, 15):
        dist_x = abs(lx - 7.5)
        if dist_x <= 1.0:
            for ly in (7, 8):
                canvas[fy3 + ly][lx] = (245, 255, 255, 255)
        elif dist_x <= 3.0:
            for ly in (7, 8):
                canvas[fy3 + ly][lx] = (110, 240, 255, 255)
        elif dist_x <= 5.0:
            for ly in (7, 8):
                canvas[fy3 + ly][lx] = (45, 190, 255, 220)
        else:
            for ly in (7, 8):
                canvas[fy3 + ly][lx] = (15, 120, 240, 140)

    # Vertical deflection spike
    for ly in range(2, 14):
        dist_y = abs(ly - 7.5)
        if dist_y <= 2.0:
            for lx in (7, 8):
                if canvas[fy3 + ly][lx][3] < 240:
                    canvas[fy3 + ly][lx] = (120, 240, 255, 240)
        elif dist_y <= 4.5:
            for lx in (7, 8):
                canvas[fy3 + ly][lx] = (50, 180, 255, 180)
        else:
            for lx in (7, 8):
                canvas[fy3 + ly][lx] = (15, 110, 230, 90)

    # Barrier plasma glints
    canvas[fy3 + 5][5] = (140, 245, 255, 200)
    canvas[fy3 + 5][10] = (140, 245, 255, 200)
    canvas[fy3 + 10][5] = (140, 245, 255, 200)
    canvas[fy3 + 10][10] = (140, 245, 255, 200)
    canvas[fy3 + 4][4] = (40, 160, 255, 120)
    canvas[fy3 + 4][11] = (40, 160, 255, 120)
    canvas[fy3 + 11][4] = (40, 160, 255, 120)
    canvas[fy3 + 11][11] = (40, 160, 255, 120)

    # Diffuse barrier glow
    for ly in range(5, 11):
        for lx in range(5, 11):
            if canvas[fy3 + ly][lx][3] == 0:
                canvas[fy3 + ly][lx] = (25, 150, 255, 60)

    # =========================================================================
    # FRAME 4: Amber Ricochet Spark (y: 64..79)
    # High-velocity impact spark and flying hot metal ember
    # =========================================================================
    fy4 = 64
    # Blazing spark head at (11, 4) - (12, 3) (local)
    canvas[fy4 + 3][12] = (255, 255, 230, 255)
    canvas[fy4 + 4][11] = (255, 255, 200, 255)
    canvas[fy4 + 3][11] = (255, 240, 140, 255)
    canvas[fy4 + 4][12] = (255, 240, 140, 255)

    # Directional streak down-left
    streak = [
        (10, 5, (255, 190, 40, 255)), (9, 6, (255, 170, 30, 255)),
        (10, 6, (255, 160, 20, 240)), (8, 7, (255, 140, 20, 240)),
        (7, 8, (245, 110, 15, 220)), (6, 9, (240, 85, 10, 200)),
        (5, 10, (225, 65, 10, 170)), (4, 11, (205, 45, 5, 130)),
        (3, 12, (180, 30, 0, 90)), (2, 13, (150, 20, 0, 50))
    ]
    for lx, ly, col in streak:
        canvas[fy4 + ly][lx] = col

    # Ember flakes
    canvas[fy4 + 2][10] = (255, 210, 70, 170)
    canvas[fy4 + 6][11] = (255, 160, 30, 160)
    canvas[fy4 + 7][5] = (250, 130, 15, 150)
    canvas[fy4 + 11][3] = (210, 50, 5, 100)

    # Warm fiery aura
    for lx, ly in [(11, 2), (13, 3), (12, 5), (10, 4)]:
        canvas[fy4 + ly][lx] = (255, 120, 10, 70)

    # =========================================================================
    # FRAME 5: Steel Armor Shatter Shard (y: 80..95)
    # Heavy angular metallic plate fragment
    # =========================================================================
    fy5 = 80
    # Shard silhouette
    shard_pixels = {
        # (lx, ly): (r, g, b, a)
        # Specular top edge
        (5, 3): (245, 250, 255, 255),
        (6, 3): (240, 248, 255, 255),
        (7, 4): (230, 240, 252, 255),
        (8, 4): (230, 240, 252, 255),
        (9, 5): (215, 230, 248, 255),
        (10, 5): (210, 225, 245, 255),
        (11, 6): (195, 215, 238, 255),

        # Upper polished metal facet
        (4, 4): (220, 232, 246, 255),
        (5, 4): (190, 205, 222, 255),
        (6, 4): (180, 196, 214, 255),
        (7, 5): (175, 190, 208, 255),
        (8, 5): (168, 184, 202, 255),
        (9, 6): (160, 176, 194, 255),
        (10, 6): (150, 166, 184, 255),

        # Mid body
        (3, 5): (190, 205, 222, 255),
        (4, 5): (165, 180, 198, 255),
        (5, 5): (155, 170, 188, 255),
        (6, 5): (145, 160, 178, 255),
        (7, 6): (140, 155, 172, 255),
        (8, 6): (132, 146, 164, 255),
        (9, 7): (125, 138, 156, 255),
        (10, 7): (115, 128, 145, 255),

        # Lower bevel & shadows
        (3, 6): (140, 155, 172, 255),
        (4, 6): (120, 134, 150, 255),
        (5, 6): (108, 120, 136, 255),
        (6, 6): (96, 108, 124, 255),
        (7, 7): (88, 98, 114, 255),
        (8, 7): (80, 90, 104, 255),
        (9, 8): (72, 82, 96, 255),

        # Dark bevel underside
        (4, 7): (85, 96, 112, 255),
        (5, 7): (70, 80, 94, 255),
        (6, 7): (60, 70, 84, 255),
        (7, 8): (52, 60, 74, 255),
        (8, 8): (46, 54, 66, 255),

        # Deep contour outline
        (4, 3): (55, 64, 76, 255),
        (2, 5): (45, 52, 64, 255),
        (3, 7): (38, 44, 54, 255),
        (4, 8): (32, 38, 48, 255),
        (5, 8): (30, 36, 45, 255),
        (6, 8): (30, 36, 45, 255),
        (7, 9): (28, 34, 42, 255),
        (8, 9): (28, 34, 42, 255),
        (9, 9): (30, 36, 45, 255),
        (10, 8): (35, 42, 52, 255),
        (11, 7): (40, 48, 60, 255),
        (12, 6): (45, 54, 66, 255),

        # Detached micro-debris flecks
        (13, 3): (220, 235, 250, 220),
        (14, 4): (140, 155, 175, 180),
        (1, 8): (180, 195, 215, 190),
        (2, 11): (100, 112, 128, 160),
    }
    for (lx, ly), col in shard_pixels.items():
        canvas[fy5 + ly][lx] = col

    # =========================================================================
    # FRAME 6: Prismatic Crystal / Diamond Shard (y: 96..111)
    # Faceted jewel fragment with refraction gleams
    # =========================================================================
    fy6 = 96
    crystal_pixels = {
        # Specular Apex Peak
        (7, 2): (255, 255, 255, 255),
        (8, 2): (255, 255, 255, 255),
        (7, 3): (255, 255, 255, 255),
        (8, 3): (240, 252, 255, 255),

        # Upper Left Facet (Pale Ice Cyan)
        (6, 3): (230, 250, 255, 250),
        (5, 4): (210, 245, 255, 250),
        (6, 4): (195, 240, 255, 250),
        (4, 5): (185, 235, 255, 245),
        (5, 5): (175, 230, 255, 245),
        (6, 5): (165, 225, 252, 245),
        (3, 6): (160, 220, 250, 240),
        (4, 6): (150, 215, 248, 240),
        (5, 6): (140, 205, 245, 240),

        # Upper Right Facet (Bright Aqua Azure)
        (9, 3): (220, 245, 255, 250),
        (9, 4): (170, 230, 255, 250),
        (10, 4): (190, 238, 255, 250),
        (7, 4): (200, 242, 255, 250),
        (8, 4): (180, 235, 255, 250),
        (7, 5): (155, 220, 250, 245),
        (8, 5): (140, 210, 248, 245),
        (9, 5): (130, 200, 245, 245),
        (10, 5): (145, 212, 248, 245),
        (11, 5): (165, 225, 252, 245),
        (6, 6): (125, 195, 242, 240),
        (7, 6): (110, 185, 238, 240),
        (8, 6): (100, 175, 235, 240),
        (9, 6): (115, 185, 240, 240),
        (10, 6): (130, 195, 245, 240),
        (11, 6): (145, 210, 250, 240),

        # Lower Center & Bottom Facet (Deep Sapphire & Indigo)
        (4, 7): (90, 165, 230, 240),
        (5, 7): (75, 150, 220, 240),
        (6, 7): (60, 135, 210, 240),
        (7, 7): (50, 120, 200, 240),
        (8, 7): (45, 110, 190, 240),
        (9, 7): (55, 125, 205, 240),
        (10, 7): (70, 140, 215, 240),

        (5, 8): (40, 105, 180, 235),
        (6, 8): (32, 92, 168, 235),
        (7, 8): (28, 80, 155, 235),
        (8, 8): (35, 95, 170, 235),
        (9, 8): (48, 110, 185, 235),

        (6, 9): (20, 65, 135, 230),
        (7, 9): (18, 58, 125, 230),
        (8, 9): (24, 72, 140, 230),

        (7, 10): (12, 45, 105, 220),

        # Prismatic chromatic dispersion (violet refraction at edge)
        (12, 6): (210, 160, 255, 210),
        (11, 7): (180, 120, 245, 190),

        # Micro gem glints
        (2, 5): (210, 245, 255, 200),
        (13, 4): (200, 235, 255, 180),
        (5, 11): (100, 180, 255, 150),
    }
    for (lx, ly), col in crystal_pixels.items():
        canvas[fy6 + ly][lx] = col

    # =========================================================================
    # FRAME 7: Wood / Bronze Splinter & Chitin Shard (y: 112..127)
    # Organic jagged splinter with wood grain striations
    # =========================================================================
    fy7 = 112
    splinter_pixels = {
        # Top spearhead splinter
        (6, 2): (235, 195, 130, 255),
        (7, 2): (245, 210, 150, 255),
        (6, 3): (220, 175, 110, 255),
        (7, 3): (235, 195, 130, 255),
        (8, 3): (200, 150, 85, 255),

        # Highlight wood fiber strip
        (5, 4): (225, 185, 120, 255),
        (6, 4): (235, 195, 130, 255),
        (7, 4): (190, 140, 75, 255),
        (8, 4): (160, 110, 50, 255),

        (5, 5): (215, 170, 105, 255),
        (6, 5): (225, 185, 120, 255),
        (7, 5): (175, 125, 65, 255),
        (8, 5): (145, 95, 42, 255),
        (9, 5): (120, 75, 30, 255),

        (4, 6): (210, 165, 100, 255),
        (5, 6): (220, 175, 110, 255),
        (6, 6): (165, 115, 55, 255),
        (7, 6): (135, 88, 38, 255),
        (8, 6): (110, 68, 26, 255),

        # Mid splinter body
        (4, 7): (200, 155, 90, 255),
        (5, 7): (210, 165, 100, 255),
        (6, 7): (150, 100, 48, 255),
        (7, 7): (120, 75, 30, 255),
        (8, 7): (95, 56, 20, 255),

        (5, 8): (190, 145, 80, 255),
        (6, 8): (175, 130, 70, 255),
        (7, 8): (135, 88, 38, 255),
        (8, 8): (105, 62, 24, 255),

        (5, 9): (180, 135, 72, 255),
        (6, 9): (150, 100, 48, 255),
        (7, 9): (115, 72, 28, 255),

        (6, 10): (165, 120, 60, 255),
        (7, 10): (130, 84, 35, 255),
        (8, 10): (100, 58, 22, 255),

        (6, 11): (150, 105, 50, 255),
        (7, 11): (110, 68, 26, 255),

        (7, 12): (130, 85, 38, 255),
        (8, 12): (90, 52, 18, 255),

        (8, 13): (105, 64, 24, 255),

        # Silhouette edges
        (5, 3): (90, 55, 22, 255),
        (4, 4): (80, 48, 18, 255),
        (4, 5): (75, 44, 16, 255),
        (3, 6): (70, 40, 14, 255),
        (3, 7): (65, 36, 12, 255),
        (4, 8): (60, 32, 10, 255),
        (4, 9): (55, 28, 8, 255),
        (5, 10): (50, 25, 8, 255),
        (9, 4): (95, 58, 22, 255),
        (10, 5): (85, 50, 18, 255),
        (9, 6): (75, 42, 15, 255),
        (9, 7): (70, 38, 14, 255),

        # Detached wood chips
        (11, 3): (210, 165, 95, 200),
        (12, 4): (150, 105, 50, 180),
        (2, 9): (180, 135, 75, 190),
        (3, 12): (120, 75, 30, 160),
    }
    for (lx, ly), col in splinter_pixels.items():
        canvas[fy7 + ly][lx] = col

    # Write output PNG
    base_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    out_path = os.path.join(base_dir, "textures", "x_player_armor_particles.png")
    write_png_rgba(out_path, width, total_h, canvas)
    print(f"Successfully generated particle sheet: {out_path} ({width}x{total_h}, {num_frames} frames)")

if __name__ == "__main__":
    create_particle_sheet()
