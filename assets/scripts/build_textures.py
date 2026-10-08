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

EMPTY = (0, 0, 0, 0)

PALETTES = {
    "steel": {
        "D": (32, 38, 46, 255),    # dark outline
        "B": (64, 74, 88, 255),    # base dark
        "M": (124, 138, 154, 255), # midtone
        "H": (184, 198, 214, 255), # highlight
        "S": (242, 248, 255, 255), # specular
        "T": (48, 56, 68, 255),    # trim
        "A": (210, 168, 75, 255),  # brass accent
        "G": (20, 24, 30, 255),    # deep visor opening
    },
    "bronze": {
        "D": (48, 24, 12, 255),
        "B": (92, 46, 22, 255),
        "M": (155, 82, 36, 255),
        "H": (212, 128, 58, 255),
        "S": (248, 188, 118, 255),
        "T": (72, 34, 16, 255),
        "A": (228, 172, 82, 255),
        "G": (30, 14, 8, 255),
    },
    "gold": {
        "D": (64, 38, 6, 255),
        "B": (130, 84, 12, 255),
        "M": (205, 150, 22, 255),
        "H": (245, 200, 48, 255),
        "S": (255, 242, 150, 255),
        "T": (100, 64, 12, 255),
        "A": (195, 22, 40, 255),   # ruby
        "G": (38, 22, 4, 255),
    },
    "diamond": {
        "D": (6, 42, 48, 255),
        "B": (18, 88, 100, 255),
        "M": (38, 162, 176, 255),
        "H": (105, 218, 228, 255),
        "S": (212, 250, 255, 255),
        "T": (12, 64, 74, 255),
        "A": (180, 245, 255, 255),
        "G": (4, 28, 34, 255),
    },
    "mithril": {
        "D": (16, 24, 58, 255),
        "B": (38, 54, 118, 255),
        "M": (68, 108, 188, 255),
        "H": (138, 178, 238, 255),
        "S": (218, 235, 255, 255),
        "T": (28, 38, 90, 255),
        "A": (190, 220, 255, 255),
        "G": (10, 16, 42, 255),
    },
    "crystal": {
        "D": (38, 10, 48, 255),
        "B": (78, 22, 98, 255),
        "M": (148, 48, 174, 255),
        "H": (208, 108, 228, 255),
        "S": (245, 198, 255, 255),
        "T": (60, 16, 78, 255),
        "A": (235, 164, 250, 255),
        "G": (24, 6, 32, 255),
    },
    "nether": {
        "D": (18, 14, 20, 255),
        "B": (38, 30, 36, 255),
        "M": (66, 52, 58, 255),
        "H": (180, 38, 16, 255),   # magma rim
        "S": (255, 130, 24, 255),  # searing lava
        "T": (26, 20, 26, 255),
        "A": (255, 220, 95, 255),  # core fire
        "G": (255, 110, 20, 255),  # glowing visor eyes
    },
    "cactus": {
        "D": (10, 34, 12, 255),
        "B": (22, 68, 26, 255),
        "M": (46, 120, 42, 255),
        "H": (88, 170, 74, 255),
        "S": (235, 228, 150, 255), # thorns
        "T": (16, 48, 18, 255),
        "A": (205, 52, 46, 255),   # red flower
        "G": (8, 24, 8, 255),
    },
    "wood": {
        "D": (34, 18, 8, 255),
        "B": (68, 38, 18, 255),
        "M": (118, 70, 34, 255),
        "H": (165, 110, 60, 255),
        "S": (205, 155, 95, 255),
        "T": (48, 26, 12, 255),
        "A": (150, 155, 162, 255), # steel nails/rivets
        "G": (22, 12, 6, 255),
    },
    "admin": {
        "D": (14, 16, 26, 255),
        "B": (54, 60, 78, 255),
        "M": (130, 140, 165, 255),
        "H": (238, 194, 42, 255),  # gold inlay
        "S": (50, 230, 245, 255),  # cyan divine neon
        "T": (30, 34, 48, 255),
        "A": (255, 255, 255, 255), # divine white
        "G": (40, 225, 240, 255),  # cyan visor
    },
}

INV_HELMET = [
    "................",
    ".....DDDDDD.....",
    "....DSHHHHMD....",
    "...DSHMHHHMMD...",
    "..DSHMMMMMMBMD..",
    "..DSHMBBBBMBMD..",
    "..DSHMMMMMMBMD..",
    "..DSDDGGDDGGDD..",
    "..DSGDGGDDGGMD..",
    "..DSHMMMMMMBMD..",
    "..DSHMMMMMMBMD..",
    "..DSHMDDDDBBMD..",
    "..DSMDB..BDMMD..",
    "..DDD......DDD..",
    "................",
    "................",
]

def get_inv_helmet(mat):
    grid = [list(row) for row in INV_HELMET]
    if mat == "gold":
        grid[1] = list("..DDD.DDDD.DDD..")
        grid[2] = list("..DSHDDAADDHMD..")
        grid[3] = list("...DSHAAAADHMD..")
    elif mat == "nether":
        grid[0] = list("D...D......D...D")
        grid[1] = list("HD.HD.DDDD.DH.DH")
        grid[2] = list(".DSDSHHHHMDSDD..")
        grid[7] = list("..DSDDGGDDGGDD..")
        grid[8] = list("..DSHDGGAAGGMD..")
    elif mat == "cactus":
        grid[0] = list(".......AA.......")
        grid[1] = list(".....DDAADD.....")
        grid[4][2] = 'S'
        grid[4][13] = 'S'
        grid[9][2] = 'S'
        grid[9][13] = 'S'
    elif mat == "wood":
        grid[2] = list("....DSAHHHMD....")
        grid[7] = list("..DSDDGGDDGGDD..")
        grid[8] = list("..DSHDAADAGGMD..")
        grid[9] = list("..DSHMAAMABBMD..")
    elif mat == "admin":
        grid[0] = list("S...S.DDDD.S...S")
        grid[1] = list(".S.SDSHHHHMD.S.S")
        grid[2] = list("..SSDSHHHHMDSS..")
        grid[7] = list("..DSDDGSDDGGDD..")
        grid[8] = list("..DSHDGGDDGGMD..")
    elif mat == "crystal":
        grid[0] = list("...S....S....S..")
        grid[1] = list("..DSD..DSD..DSD.")
        grid[2] = list("...DSHHHHMDD....")
    elif mat == "mithril":
        grid[1] = list("....DD.SS.DD....")
        grid[2] = list("...DSHDAADHMD...")
    return grid

INV_CHESTPLATE = [
    "................",
    ".DDDD......DDDD.",
    "DSHMMD....DSHMMD",
    "DSHMMMD..DSHMMMD",
    "DSHMMMDDDDSMMBMD",
    ".DSHMMMDDSMBDMD.",
    "..DSHMMMBMBDMD..",
    "..DSHMMMBMBDMD..",
    "..DSHMMMBMBDMD..",
    "...DSHMMMMBMD...",
    "...DSHMMMMBMD...",
    "...DSHMMMMBMD...",
    "...DSHMBBBBMD...",
    "...DSHMBBBBMD...",
    "....DDDDDDDD....",
    "................",
]

def get_inv_chestplate(mat):
    grid = [list(row) for row in INV_CHESTPLATE]
    if mat == "gold":
        grid[6][7] = 'A'
        grid[6][8] = 'A'
        grid[7][7] = 'A'
        grid[7][8] = 'A'
    elif mat == "nether":
        grid[6][7] = 'A'
        grid[7][8] = 'S'
        grid[8][7] = 'S'
        grid[9][8] = 'H'
        grid[10][7] = 'H'
    elif mat == "cactus":
        grid[1][0] = 'S'
        grid[1][15] = 'S'
        grid[7][7] = 'A'
        grid[7][8] = 'A'
    elif mat == "diamond":
        grid[6][7] = 'S'
        grid[6][8] = 'H'
        grid[7][7] = 'H'
        grid[7][8] = 'M'
    elif mat == "wood":
        grid[5][5] = 'A'
        grid[5][10] = 'A'
        grid[12][5] = 'A'
        grid[12][10] = 'A'
    elif mat == "admin":
        grid[6][7] = 'A'
        grid[6][8] = 'A'
        grid[7][6] = 'S'
        grid[7][7] = 'A'
        grid[7][8] = 'A'
        grid[7][9] = 'S'
        grid[8][7] = 'A'
        grid[8][8] = 'A'
    return grid

INV_LEGGINGS = [
    "................",
    "..DDDDDDDDDDDD..",
    ".DSHMMMMMMMMBMD.",
    ".DSHMMDAADMMBMD.",
    ".DSHMMDAADMMBMD.",
    ".DSHMDDDDDDMBMD.",
    ".DSHMD....DMBMD.",
    ".DSHMD....DMBMD.",
    ".DSHMD....DMBMD.",
    ".DSHMD....DMBMD.",
    ".DSHMD....DMBMD.",
    ".DSHMD....DMBMD.",
    ".DSHMD....DMBMD.",
    ".DSHMD....DMBMD.",
    ".DDDMD....DMDDD.",
    "..DDD......DDD..",
]

def get_inv_leggings(mat):
    grid = [list(row) for row in INV_LEGGINGS]
    if mat == "nether":
        grid[8][4] = 'S'
        grid[9][4] = 'H'
        grid[10][11] = 'S'
        grid[11][11] = 'H'
    elif mat == "cactus":
        grid[7][1] = 'S'
        grid[7][14] = 'S'
        grid[11][1] = 'S'
        grid[11][14] = 'S'
    elif mat == "admin":
        grid[3][7] = 'S'
        grid[3][8] = 'S'
        grid[4][7] = 'S'
        grid[4][8] = 'S'
        grid[9][4] = 'H'
        grid[9][11] = 'H'
    return grid

INV_BOOTS = [
    "................",
    "................",
    "..DDDD....DDDD..",
    ".DSHMMD..DSHMMD.",
    ".DSHMMD..DSHMMD.",
    ".DSHMMD..DSHMMD.",
    ".DSHMMD..DSHMMD.",
    ".DSHMMD..DSHMMD.",
    ".DSHMMD..DSHMMD.",
    ".DSHMMMDDSHMMMD.",
    "DSHMMMMMDHMMMMMD",
    "DSHMMMMMDHMMMMMD",
    "DSHMMMMMDHMMMMMD",
    ".DDDDDDDDDDDDDD.",
    "................",
    "................",
]

def get_inv_boots(mat):
    grid = [list(row) for row in INV_BOOTS]
    if mat == "nether":
        grid[10][2] = 'S'
        grid[11][3] = 'H'
        grid[10][10] = 'S'
        grid[11][11] = 'H'
    elif mat == "admin":
        grid[3][3] = 'H'
        grid[3][10] = 'H'
        grid[7][3] = 'S'
        grid[7][10] = 'S'
    elif mat == "cactus":
        grid[8][1] = 'S'
        grid[8][8] = 'S'
    return grid

def render_grid(grid, palette):
    w = len(grid[0])
    h = len(grid)
    pixels = [[EMPTY for _ in range(w)] for _ in range(h)]
    for y in range(h):
        for x in range(w):
            code = grid[y][x]
            if code in palette:
                pixels[y][x] = palette[code]
    return pixels

# 64x32 CHARACTER SHEET BUILDER
def build_character_sheet(mat):
    pal = PALETTES[mat]
    D, B, M, H, S, T, A, G = (pal[k] for k in ['D', 'B', 'M', 'H', 'S', 'T', 'A', 'G'])
    sheet = [[EMPTY for _ in range(64)] for _ in range(32)]

    # 1. SHIELD (x=0..15, y=0..15)
    for y in range(16):
        if y == 0:
            x_ranges = [(0, 3), (13, 16)]
        elif y <= 9:
            x_ranges = [(0, 16)]
        elif y <= 11:
            x_ranges = [(1, 15)]
        elif y == 12:
            x_ranges = [(2, 14)]
        elif y == 13:
            x_ranges = [(3, 13)]
        elif y == 14:
            x_ranges = [(4, 12)]
        else:
            x_ranges = [(6, 10)]

        for x_start, x_end in x_ranges:
            for x in range(x_start, x_end):
                c = M
                if x == x_start or x == x_end - 1 or y in (0, 15) or (y == 9 and (x < 1 or x > 14)):
                    c = H if (x == x_start and y < 8) or y <= 1 else D
                elif x == x_start + 1 or x == x_end - 2 or y in (1, 14):
                    c = T
                else:
                    if x + y < 14:
                        c = H if x + y < 8 else M
                    else:
                        c = B
                sheet[y][x] = c

    # Shield central emblem per material:
    if mat == "steel":
        for y in range(4, 12):
            sheet[y][7] = S; sheet[y][8] = H
        for x in range(5, 11):
            sheet[7][x] = S; sheet[8][x] = H
    elif mat == "bronze":
        for y in range(5, 11):
            for x in range(5, 11):
                sheet[y][x] = S if (x in (7, 8) and y in (7, 8)) else A
    elif mat == "gold":
        for y in range(6, 10):
            sheet[y][7] = A; sheet[y][8] = A
        sheet[7][6] = A; sheet[7][9] = A
    elif mat == "diamond":
        sheet[6][7] = S; sheet[6][8] = S
        sheet[7][6] = S; sheet[7][7] = A; sheet[7][8] = A; sheet[7][9] = H
        sheet[8][6] = H; sheet[8][7] = A; sheet[8][8] = A; sheet[8][9] = M
        sheet[9][7] = M; sheet[9][8] = B
    elif mat == "mithril":
        sheet[5][7] = S; sheet[5][8] = S
        sheet[6][6] = S; sheet[6][9] = S
        sheet[7][6] = A; sheet[7][9] = A
        sheet[8][7] = H; sheet[8][8] = H
        sheet[9][7] = B; sheet[9][8] = B
    elif mat == "crystal":
        sheet[6][7] = S; sheet[7][6] = S; sheet[7][8] = A; sheet[8][7] = A
    elif mat == "nether":
        sheet[5][5] = S; sheet[5][10] = S
        sheet[6][6] = S; sheet[6][9] = S
        for y in range(6, 12):
            sheet[y][7] = S; sheet[y][8] = H
        sheet[8][6] = S; sheet[8][9] = H
    elif mat == "cactus":
        for y in range(4, 12):
            sheet[y][5] = B; sheet[y][8] = S; sheet[y][10] = B
        sheet[4][7] = A; sheet[4][8] = A
    elif mat == "wood":
        for y in range(2, 14):
            sheet[y][5] = D; sheet[y][10] = D
        for x in range(2, 14):
            if sheet[7][x] != EMPTY: sheet[7][x] = A
        sheet[7][4] = D; sheet[7][11] = D
    elif mat == "admin":
        for y in range(5, 11):
            sheet[y][7] = S; sheet[y][8] = S
        for x in range(4, 12):
            sheet[7][x] = S
        sheet[7][7] = A; sheet[7][8] = A

    # 2. BOOTS (x=16..31, y=0..10)
    for y in range(0, 4):
        for x in range(20, 28):
            sheet[y][x] = H if (y == 0 or x == 20) else (B if y == 3 or x == 27 else M)
    for y in range(4, 11):
        for x in range(16, 32):
            face_x = (x - 16) % 4
            is_front = (20 <= x <= 23)
            is_back = (28 <= x <= 31)
            if y == 10:
                sheet[y][x] = D
            elif y == 4:
                sheet[y][x] = T
            elif is_front:
                sheet[y][x] = S if face_x == 1 and y < 8 else (H if face_x in (0, 1) else (B if face_x == 3 else M))
            elif is_back:
                sheet[y][x] = B if face_x < 3 else D
            else:
                sheet[y][x] = H if face_x == 0 else (B if face_x == 3 else M)

    # 3. HELMET (x=32..63, y=0..14)
    for y in range(0, 8):
        for x in range(40, 48):
            if x in (43, 44):
                sheet[y][x] = S if y in (0, 1) else H
            elif x < 43 and y < 4:
                sheet[y][x] = H
            elif x > 44 and y > 4:
                sheet[y][x] = B
            else:
                sheet[y][x] = M
    for y in range(8, 14):
        for x in range(32, 64):
            is_front = (40 <= x <= 47)
            is_back = (56 <= x <= 63)
            fx = (x - 32) % 8

            if is_front:
                if y in (11, 12):
                    if x in (41, 42, 45, 46):
                        continue
                    elif x in (43, 44):
                        sheet[y][x] = T
                    else:
                        sheet[y][x] = D
                elif y == 13:
                    if x in (41, 42, 43, 44, 45, 46):
                        continue
                    else:
                        sheet[y][x] = D
                else:
                    if y == 8:
                        sheet[y][x] = H
                    elif x in (43, 44):
                        sheet[y][x] = S
                    elif x < 43:
                        sheet[y][x] = H
                    else:
                        sheet[y][x] = M
            elif is_back:
                sheet[y][x] = B if fx < 6 else D
            else:
                sheet[y][x] = H if fx <= 1 else (B if fx >= 6 else M)

    for x in range(57, 63):
        sheet[14][x] = D if x in (57, 62) else B

    # 4. LEGGINGS (x=0..15, y=16..27 + belt at x=16..39, y=31)
    for y in range(16, 20):
        for x in range(4, 8):
            sheet[y][x] = H if (y == 16 or x == 4) else (B if y == 19 or x == 7 else M)
    for y in range(20, 28):
        for x in range(0, 16):
            is_front = (4 <= x <= 7)
            is_back = (12 <= x <= 15)
            fx = x % 4
            if y == 27:
                sheet[y][x] = T
            elif is_front:
                if y in (25, 26):
                    sheet[y][x] = S if fx == 1 else (H if fx in (0, 2) else M)
                else:
                    sheet[y][x] = H if fx <= 1 else (B if fx == 3 else M)
            elif is_back:
                sheet[y][x] = B if fx < 3 else D
            else:
                sheet[y][x] = H if fx == 0 else (B if fx == 3 else M)

    for x in range(16, 40):
        if x in (23, 24):
            sheet[31][x] = A
        elif x in (22, 25):
            sheet[31][x] = D
        else:
            sheet[31][x] = T

    # 5. CHESTPLATE / TORSO (x=16..39, y=16..31)
    for y in range(16, 20):
        for x in range(20, 28):
            if y >= 18 and 22 <= x <= 25:
                continue
            sheet[y][x] = H if y == 16 or x == 20 else (B if x == 27 else M)
    for y in range(16, 20):
        for x in range(28, 36):
            sheet[y][x] = B

    for y in range(20, 32):
        for x in range(16, 40):
            is_flank_r = (16 <= x <= 19)
            is_front = (20 <= x <= 27)
            is_flank_l = (28 <= x <= 31)
            is_back = (32 <= x <= 39)

            if is_front:
                if y == 20 and 22 <= x <= 25:
                    continue
                if y == 21 and 23 <= x <= 24:
                    continue

                fx = x - 20
                if fx == 3:
                    c = S if y in (22, 23) else H
                elif fx == 4:
                    c = H if y in (22, 23) else M
                elif fx < 3:
                    c = H if fx == 1 or y == 21 else (B if fx == 0 else M)
                else:
                    c = B if fx == 7 else M

                if mat == "nether" and y in (24, 25, 26) and x in (23, 24):
                    c = S if y == 25 else H
                elif mat == "diamond" and y in (24, 25) and x in (23, 24):
                    c = S if x == 23 and y == 24 else A
                elif mat == "gold" and y in (24, 25) and x in (23, 24):
                    c = A
                elif mat == "admin" and y in (24, 25) and x in (23, 24):
                    c = S

                sheet[y][x] = c
            elif is_back:
                fx = x - 32
                if fx in (3, 4):
                    sheet[y][x] = M
                elif fx < 3:
                    sheet[y][x] = M if fx == 1 else B
                else:
                    sheet[y][x] = B if fx < 7 else D
            elif is_flank_r:
                fx = x - 16
                sheet[y][x] = H if fx == 0 else (B if fx == 3 else M)
            elif is_flank_l:
                fx = x - 28
                sheet[y][x] = M if fx == 0 else (D if fx == 3 else B)

    # 6. SLEEVES / PAULDRONS (x=40..55, y=16..23)
    for y in range(16, 20):
        for x in range(44, 48):
            sheet[y][x] = S if y == 16 and x == 44 else (H if y == 16 or x == 44 else M)
    for y in range(20, 24):
        for x in range(40, 56):
            is_front = (44 <= x <= 47)
            is_back = (52 <= x <= 55)
            fx = (x - 40) % 4
            if y == 23:
                sheet[y][x] = T
            elif is_front:
                sheet[y][x] = S if fx == 1 and y == 20 else (H if fx <= 1 else M)
            elif is_back:
                sheet[y][x] = B if fx < 3 else D
            else:
                sheet[y][x] = H if fx == 0 else (B if fx == 3 else M)

    return sheet

def build_enhanced_wood_shield():
    pal_w = PALETTES["wood"]
    pal_s = PALETTES["steel"]
    SD, SB, SM, SH, SS, ST = (pal_s[k] for k in ["D", "B", "M", "H", "S", "T"])
    WD, WB, WM, WH, WS, WT, WG = (pal_w[k] for k in ["D", "B", "M", "H", "S", "T", "G"])
    grid = [[EMPTY for _ in range(16)] for _ in range(16)]

    # Row 0 (x=2..13): Arched forged steel top crest
    grid[0][2] = SS
    for x in range(3, 6): grid[0][x] = SH
    for x in range(6, 11): grid[0][x] = SM
    for x in range(11, 13): grid[0][x] = SB
    grid[0][13] = SD

    # Row 1 (x=1..14): Heavy forged steel top band with iron rivets
    grid[1][1] = SS; grid[1][2] = SM; grid[1][3] = SS; grid[1][4] = SH; grid[1][5] = SM; grid[1][6] = SM
    grid[1][7] = SS; grid[1][8] = SH; grid[1][9] = SM; grid[1][10] = SM; grid[1][11] = SH; grid[1][12] = SH
    grid[1][13] = SM; grid[1][14] = SD

    # Row 2 (x=1..14): Steel-to-wood transition border
    grid[2][1] = SH; grid[2][2] = ST
    for x in range(3, 13): grid[2][x] = WT
    grid[2][13] = ST; grid[2][14] = SD

    # Rows 3..6: Upper oak wood planks with steel side bindings
    for y in range(3, 7):
        grid[y][1] = SH; grid[y][2] = ST; grid[y][13] = ST; grid[y][14] = SD
        grid[y][3] = WH if y < 5 else WM
        grid[y][4] = WM; grid[y][5] = WM; grid[y][6] = WG
        grid[y][7] = WM if y < 5 else WB; grid[y][8] = WB; grid[y][9] = WG
        grid[y][10] = WB; grid[y][11] = WB; grid[y][12] = WB

    # Rivets on upper planks
    grid[4][4] = SS; grid[4][5] = SM; grid[4][11] = SH; grid[4][12] = SB

    # Upper boss apex
    grid[6][7] = SS; grid[6][8] = SH

    # Row 7: Central steel cross-brace with rivets & raised steel boss
    grid[7][1] = SS; grid[7][2] = SH; grid[7][3] = SS; grid[7][4] = SH; grid[7][5] = SH
    grid[7][6] = SS; grid[7][7] = SS; grid[7][8] = SH; grid[7][9] = SM
    grid[7][10] = SM; grid[7][11] = SM; grid[7][12] = SH; grid[7][13] = SB; grid[7][14] = SD

    # Row 8: Central steel cross-brace shadow & lower boss
    grid[8][1] = SH; grid[8][2] = ST; grid[8][3] = SM; grid[8][4] = SM; grid[8][5] = SM
    grid[8][6] = SH; grid[8][7] = SH; grid[8][8] = SM; grid[8][9] = SB
    grid[8][10] = SB; grid[8][11] = SB; grid[8][12] = SB; grid[8][13] = ST; grid[8][14] = SD

    # Rows 9..11: Lower oak wood planks
    grid[9][7] = SM; grid[9][8] = SB
    for y in range(9, 12):
        grid[y][1] = SH; grid[y][2] = ST; grid[y][13] = ST; grid[y][14] = SD
        grid[y][3] = WM; grid[y][4] = WM; grid[y][5] = WB; grid[y][6] = WG
        if y > 9: grid[y][7] = WB; grid[y][8] = WB
        g_right = WT if y == 11 else WB
        grid[y][9] = WG; grid[y][10] = WB; grid[y][11] = WB; grid[y][12] = g_right

    # Rivets on lower planks
    grid[10][4] = SH; grid[10][5] = SM; grid[10][10] = SM; grid[10][11] = SB

    # Row 12 (x=2..13): Transition to steel bottom shoe
    grid[12][2] = SH; grid[12][3] = ST
    for x in range(4, 12): grid[12][x] = WT
    grid[12][12] = ST; grid[12][13] = SD

    # Row 13 (x=2..13): Steel bottom shoe with rivets
    grid[13][2] = SS; grid[13][3] = SH; grid[13][4] = SS; grid[13][5] = SH; grid[13][6] = SH
    grid[13][7] = SS; grid[13][8] = SH; grid[13][9] = SM; grid[13][10] = SB; grid[13][11] = SH
    grid[13][12] = SB; grid[13][13] = SD

    # Row 14 (x=3..12): Bottom shoe taper
    grid[14][3] = SH
    for x in range(4, 8): grid[14][x] = SM
    for x in range(8, 12): grid[14][x] = SB
    grid[14][12] = SD

    # Row 15 (x=4..11): Bottom steel ground plate
    grid[15][4] = SM
    for x in range(5, 8): grid[15][x] = SB
    for x in range(8, 12): grid[15][x] = SD

    return grid

def build_enhanced_cactus_shield():
    pal_c = PALETTES["cactus"]
    pal_s = PALETTES["steel"]
    SD, SB, SM, SH, SS, ST = (pal_s[k] for k in ["D", "B", "M", "H", "S", "T"])
    CD, CB, CM, CH, CS, CT, CA, CG = (pal_c[k] for k in ["D", "B", "M", "H", "S", "T", "A", "G"])
    grid = [[EMPTY for _ in range(16)] for _ in range(16)]

    # Row 0 (x=2..13): Arched forged steel top crest
    grid[0][2] = SS
    for x in range(3, 6): grid[0][x] = SH
    for x in range(6, 11): grid[0][x] = SM
    for x in range(11, 13): grid[0][x] = SB
    grid[0][13] = SD

    # Row 1 (x=1..14): Heavy forged steel top band with iron rivets
    grid[1][1] = SS; grid[1][2] = SM; grid[1][3] = SS; grid[1][4] = SH; grid[1][5] = SM; grid[1][6] = SM
    grid[1][7] = SS; grid[1][8] = SH; grid[1][9] = SM; grid[1][10] = SM; grid[1][11] = SH; grid[1][12] = SH
    grid[1][13] = SM; grid[1][14] = SD

    # Row 2 (x=1..14): Steel-to-cactus rim boundary
    grid[2][1] = SH; grid[2][2] = ST
    for x in range(3, 13): grid[2][x] = CT
    grid[2][13] = ST; grid[2][14] = SD

    # Rows 3..6: Upper cactus ribs
    for y in range(3, 7):
        grid[y][1] = SH; grid[y][2] = CT; grid[y][13] = CT; grid[y][14] = SD
        grid[y][3] = CH if y < 5 else CM
        grid[y][4] = CM; grid[y][5] = CM; grid[y][6] = CG
        grid[y][7] = CM if y < 5 else CB; grid[y][8] = CB; grid[y][9] = CG
        grid[y][10] = CB; grid[y][11] = CB; grid[y][12] = CB

    # Upper thorny spines at y=4 (protruding flanks & face)
    grid[4][0] = CS; grid[4][4] = CS; grid[4][11] = CS; grid[4][15] = CS

    # Top petal of central desert flower blossom at y=6
    grid[6][7] = CA; grid[6][8] = CA

    # Rows 7..8: Central steel braces with Desert Blossom Crest
    # Steel brace left (x=1..5)
    grid[7][1] = SS; grid[7][2] = SH; grid[7][3] = SS; grid[7][4] = SH; grid[7][5] = SH
    grid[8][1] = SH; grid[8][2] = ST; grid[8][3] = SM; grid[8][4] = SM; grid[8][5] = SM
    # Steel brace right (x=10..14)
    grid[7][10] = SM; grid[7][11] = SM; grid[7][12] = SH; grid[7][13] = SB; grid[7][14] = SD
    grid[8][10] = SB; grid[8][11] = SB; grid[8][12] = SB; grid[8][13] = ST; grid[8][14] = SD
    # Blossom core at x=6..9, y=7..8
    grid[7][6] = CA; grid[7][7] = CS; grid[7][8] = CS; grid[7][9] = CA
    grid[8][6] = CA; grid[8][7] = CA; grid[8][8] = CA; grid[8][9] = CA
    # Mid thorny spines at y=7
    grid[7][0] = CS; grid[7][15] = CS

    # Bottom petal of desert flower blossom at y=9
    grid[9][7] = CA; grid[9][8] = CA

    # Rows 9..11: Lower cactus ribs
    for y in range(9, 12):
        grid[y][1] = SH; grid[y][2] = CT; grid[y][13] = CT; grid[y][14] = SD
        grid[y][3] = CM; grid[y][4] = CM; grid[y][5] = CB; grid[y][6] = CG
        if y > 9: grid[y][7] = CB; grid[y][8] = CB
        grid[y][9] = CG; grid[y][10] = CB; grid[y][11] = CB; grid[y][12] = CT

    # Lower thorny spines at y=10 (protruding flanks & face)
    grid[10][0] = CS; grid[10][4] = CS; grid[10][11] = CS; grid[10][15] = CS

    # Row 12 (x=2..13): Transition to steel bottom shoe
    grid[12][2] = SH; grid[12][3] = CT
    for x in range(4, 12): grid[12][x] = CT
    grid[12][12] = CT; grid[12][13] = SD

    # Row 13 (x=2..13): Steel bottom shoe with rivets
    grid[13][2] = SS; grid[13][3] = SH; grid[13][4] = SS; grid[13][5] = SH; grid[13][6] = SH
    grid[13][7] = SS; grid[13][8] = SH; grid[13][9] = SM; grid[13][10] = SB; grid[13][11] = SH
    grid[13][12] = SB; grid[13][13] = SD

    # Row 14 (x=3..12): Bottom shoe taper
    grid[14][3] = SH
    for x in range(4, 8): grid[14][x] = SM
    for x in range(8, 12): grid[14][x] = SB
    grid[14][12] = SD

    # Row 15 (x=4..11): Bottom steel ground plate
    grid[15][4] = SM
    for x in range(5, 8): grid[15][x] = SB
    for x in range(8, 12): grid[15][x] = SD

    return grid

def build_armor_ui_icon():
    pal_s = PALETTES["steel"]
    pal_g = PALETTES["gold"]

    SD, SB, SM, SH, SS, ST, SA, SG = (pal_s[k] for k in ["D", "B", "M", "H", "S", "T", "A", "G"])
    GD, GB, GM, GH, GS = (pal_g[k] for k in ["D", "B", "M", "H", "S"])
    RUBY_L = (255, 60, 80, 255)   # bright ruby highlight
    RUBY_D = pal_g["A"]           # deep royal ruby (195, 22, 40, 255)
    grid = [[EMPTY for _ in range(32)] for _ in range(32)]

    # 1. Gorget (Neck Guard): y=3..6, x=12..19
    for y in range(3, 7):
        for x in range(12, 20):
            if y == 3:
                grid[y][x] = GS if x in (13, 14) else (GH if x < 16 else GM)
            elif y == 4:
                grid[y][x] = SS if x in (13, 14) else (SH if x < 16 else SM)
            elif y == 5:
                grid[y][x] = SH if x < 15 else (SM if x < 18 else SB)
            elif y == 6:
                grid[y][x] = ST
    grid[3][12] = GD; grid[3][19] = GD
    grid[4][12] = SD; grid[4][19] = SD
    grid[5][12] = SD; grid[5][19] = SD

    # 2. Left Pauldron (Shoulder Guard): y=5..15, x=3..11
    for x in range(5, 12): grid[5][x] = SH if x < 8 else SM
    grid[5][4] = SS; grid[5][3] = SD
    for y in range(6, 9):
        grid[y][3] = SD
        grid[y][4] = SS if y == 6 else SH
        for x in range(5, 11):
            grid[y][x] = SH if (x + y) < 13 else SM
        grid[y][11] = ST
    grid[6][5] = GS; grid[6][6] = GH

    for y in range(9, 13):
        grid[y][2] = SD
        grid[y][3] = SH
        for x in range(4, 10):
            grid[y][x] = SM if (x + y) < 16 else SB
        grid[y][10] = ST
    grid[9][4] = GS; grid[9][5] = GH

    for y in range(13, 16):
        grid[y][3] = SD
        grid[y][4] = SM
        for x in range(5, 9):
            grid[y][x] = SB
        grid[y][9] = SD
    grid[13][5] = GH; grid[13][6] = GM

    # 3. Right Pauldron: y=5..15, x=20..28
    for x in range(20, 27): grid[5][x] = SM if x < 24 else SB
    grid[5][27] = SD; grid[5][28] = SD
    for y in range(6, 9):
        grid[y][20] = ST
        for x in range(21, 28):
            grid[y][x] = SM if x < 24 else SB
        grid[y][28] = SD
    grid[6][25] = GM; grid[6][26] = GD

    for y in range(9, 13):
        grid[y][21] = ST
        for x in range(22, 28):
            grid[y][x] = SB if x < 26 else ST
        grid[y][28] = SD; grid[y][29] = SD
    grid[9][26] = GM; grid[9][27] = GD

    for y in range(13, 16):
        grid[y][22] = ST
        for x in range(23, 28):
            grid[y][x] = SB if x < 26 else SD
        grid[y][28] = SD
    grid[13][25] = GM

    # 4. Chestplate (Pectoral Plates): y=7..18, x=10..21
    for y in range(7, 19):
        for x in range(10, 22):
            if x == 10 or x == 21:
                grid[y][x] = ST if x == 10 else SD
            elif x < 15:
                if x == 11 and y < 14:
                    grid[y][x] = SS if y in (9, 10) else SH
                elif x + y < 22:
                    grid[y][x] = SH if x + y < 18 else SM
                else:
                    grid[y][x] = SM
            elif x in (15, 16):
                if x == 15:
                    grid[y][x] = SS if y < 14 else SH
                else:
                    grid[y][x] = SM if y < 14 else SB
            else:
                if x + y < 25:
                    grid[y][x] = SM if x < 19 else SB
                else:
                    grid[y][x] = SB if x < 20 else ST

    # 5. Golden Royal Crest with Ruby Center: y=9..15, x=13..18
    grid[9][15] = GS; grid[9][16] = GH
    grid[10][14] = GS; grid[10][15] = GS; grid[10][16] = GH; grid[10][17] = GM
    grid[11][13] = GH; grid[11][14] = GS; grid[11][15] = RUBY_L; grid[11][16] = GH; grid[11][17] = GM; grid[11][18] = GD
    grid[12][13] = GM; grid[12][14] = GH; grid[12][15] = RUBY_D; grid[12][16] = GH; grid[12][17] = GM; grid[12][18] = GD
    grid[13][14] = GM; grid[13][15] = GH; grid[13][16] = GM; grid[13][17] = GD
    grid[14][15] = GM; grid[14][16] = GD

    # 6. Abdominal Fauld (Articulated Lames): y=19..22, x=11..20
    for x in range(11, 21):
        grid[19][x] = SH if x < 15 else (SM if x == 15 else (SB if x < 19 else ST))
        grid[20][x] = SM if x < 15 else (SB if x < 19 else SD)
    grid[19][11] = SD; grid[19][20] = SD; grid[20][11] = SD; grid[20][20] = SD
    for x in range(12, 20):
        grid[21][x] = SH if x < 15 else (SM if x == 15 else (SB if x < 18 else ST))
        grid[22][x] = SM if x < 15 else (SB if x < 18 else SD)
    grid[21][12] = SD; grid[21][19] = SD; grid[22][12] = SD; grid[22][19] = SD

    # 7. Belt with Gold Buckle: y=23..24, x=11..20
    for x in range(11, 21):
        grid[23][x] = ST if x < 15 else SD
        grid[24][x] = SG
    grid[23][14] = GS; grid[23][15] = GS; grid[23][16] = GH; grid[23][17] = GM
    grid[24][14] = GH; grid[24][15] = GM; grid[24][16] = GM; grid[24][17] = GD

    # 8. Tassets: y=25..28, x=10..21
    for y in range(25, 29):
        x_min = 10 if y < 28 else 11
        for x in range(x_min, 16):
            if y == 25: grid[y][x] = SH if x < 13 else SM
            elif y in (26, 27): grid[y][x] = SM if x < 13 else SB
            else: grid[y][x] = SD
        grid[y][x_min] = SD; grid[y][15] = ST
    grid[26][12] = GS

    for y in range(25, 29):
        x_max = 21 if y < 28 else 20
        for x in range(16, x_max + 1):
            if y == 25: grid[y][x] = SM if x < 19 else SB
            elif y in (26, 27): grid[y][x] = SB if x < 19 else ST
            else: grid[y][x] = SD
        grid[y][16] = ST; grid[y][x_max] = SD
    grid[26][19] = GM

    return grid

def export_all(textures_dir):
    materials = ["admin", "bronze", "cactus", "crystal", "diamond", "gold", "mithril", "nether", "steel", "wood"]
    print(f"Exporting reworked textures for {len(materials)} materials into {textures_dir}...")

    for mat in materials:
        pal = PALETTES[mat]

        # 1. 64x32 Unified Character Armor Sheet
        sheet = build_character_sheet(mat)
        sheet_path = os.path.join(textures_dir, f"x_player_armor_{mat}.png")
        write_png_rgba(sheet_path, 64, 32, sheet)
        print(f"  [Sheet 64x32] {os.path.basename(sheet_path)}")

        # 2. 16x16 Inventory Helmet
        h_grid = get_inv_helmet(mat)
        h_pix = render_grid(h_grid, pal)
        h_path = os.path.join(textures_dir, f"x_player_armor_inv_helmet_{mat}.png")
        write_png_rgba(h_path, 16, 16, h_pix)

        # 3. 16x16 Inventory Chestplate
        c_grid = get_inv_chestplate(mat)
        c_pix = render_grid(c_grid, pal)
        c_path = os.path.join(textures_dir, f"x_player_armor_inv_chestplate_{mat}.png")
        write_png_rgba(c_path, 16, 16, c_pix)

        # 4. 16x16 Inventory Leggings
        l_grid = get_inv_leggings(mat)
        l_pix = render_grid(l_grid, pal)
        l_path = os.path.join(textures_dir, f"x_player_armor_inv_leggings_{mat}.png")
        write_png_rgba(l_path, 16, 16, l_pix)

        # 5. 16x16 Inventory Boots
        b_grid = get_inv_boots(mat)
        b_pix = render_grid(b_grid, pal)
        b_path = os.path.join(textures_dir, f"x_player_armor_inv_boots_{mat}.png")
        write_png_rgba(b_path, 16, 16, b_pix)

        # 6. 16x16 Inventory Shield (matches shield on sheet)
        s_pix = [[sheet[y][x] for x in range(16)] for y in range(16)]
        s_path = os.path.join(textures_dir, f"x_player_armor_inv_shield_{mat}.png")
        write_png_rgba(s_path, 16, 16, s_pix)

    # 7. Enhanced Tower Shields (Wood & Cactus with forged steel reinforcements)
    # Enhanced Wood Shield
    wood_shield_16 = build_enhanced_wood_shield()
    wood_inv_path = os.path.join(textures_dir, "x_player_armor_inv_shield_enhanced_wood.png")
    write_png_rgba(wood_inv_path, 16, 16, wood_shield_16)
    print(f"  [Inv 16x16] {os.path.basename(wood_inv_path)}")

    wood_sheet = [[EMPTY for _ in range(64)] for _ in range(32)]
    for y in range(16):
        for x in range(16):
            wood_sheet[y][x] = wood_shield_16[y][x]
    wood_sheet_path = os.path.join(textures_dir, "x_player_armor_shield_enhanced_wood.png")
    write_png_rgba(wood_sheet_path, 64, 32, wood_sheet)
    print(f"  [Sheet 64x32] {os.path.basename(wood_sheet_path)}")

    # Enhanced Cactus Shield
    cactus_shield_16 = build_enhanced_cactus_shield()
    cactus_inv_path = os.path.join(textures_dir, "x_player_armor_inv_shield_enhanced_cactus.png")
    write_png_rgba(cactus_inv_path, 16, 16, cactus_shield_16)
    print(f"  [Inv 16x16] {os.path.basename(cactus_inv_path)}")

    cactus_sheet = [[EMPTY for _ in range(64)] for _ in range(32)]
    for y in range(16):
        for x in range(16):
            cactus_sheet[y][x] = cactus_shield_16[y][x]
    cactus_sheet_path = os.path.join(textures_dir, "x_player_armor_shield_enhanced_cactus.png")
    write_png_rgba(cactus_sheet_path, 64, 32, cactus_sheet)
    print(f"  [Sheet 64x32] {os.path.basename(cactus_sheet_path)}")

    # 8. Armor Formspec UI CTA Button Icons (inventory_plus & unified_inventory)
    icon_32 = build_armor_ui_icon()
    inv_plus_path = os.path.join(textures_dir, "x_player_armor_inventory_plus.png")
    write_png_rgba(inv_plus_path, 32, 32, icon_32)
    print(f"  [UI 32x32] {os.path.basename(inv_plus_path)}")

    icon_path = os.path.join(textures_dir, "x_player_armor_icon.png")
    write_png_rgba(icon_path, 32, 32, icon_32)
    print(f"  [UI 32x32] {os.path.basename(icon_path)}")

    print("All textures exported successfully.")

if __name__ == "__main__":
    import sys
    script_dir = os.path.dirname(os.path.abspath(__file__))
    default_dir = os.path.abspath(os.path.join(script_dir, "..", "..", "textures"))
    out_dir = sys.argv[1] if len(sys.argv) > 1 else default_dir
    export_all(out_dir)
