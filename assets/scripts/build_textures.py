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
        "D": (34, 40, 46, 255),    # #22282e dark plate seam / crevice
        "B": (78, 90, 98, 255),    # #4e5a62 deep steel shadow / lower bevel
        "M": (134, 146, 154, 255), # #86929a core steel midtone
        "H": (194, 206, 212, 255), # #c2ced4 bright brushed steel / inner bevel
        "S": (246, 250, 254, 255), # #f6fafe specular glint / rivet apex
        "T": (54, 64, 72, 255),    # #364048 dark recessed steel groove
        "A": (222, 232, 238, 255), # #dee8ee polished steel accent / rim
        "G": (18, 22, 26, 255),    # #12161a deepest visor crevice
    },
    "bronze": {
        "D": (72, 32, 22, 255),     # #482016 dark outline / plate seam
        "B": (126, 60, 42, 255),    # #7e3c2a shaded bronze
        "M": (174, 92, 62, 255),    # #ac583c core medium bronze
        "H": (218, 132, 94, 255),   # #d67e5c sunlit bronze / top bevel
        "S": (252, 192, 150, 255),  # #fcc096 specular rivet glint (warm copper-peach)
        "T": (102, 46, 32, 255),    # #662e20 recessed shadow base
        "A": (236, 160, 122, 255),  # #eca07a bright rivet dome / accent
        "G": (44, 18, 12, 255),     # #2c120c deep crease / visor slit
    },
    "gold": {
        "D": (110, 62, 6, 255),      # #6e3e06 Darkest outline / plate seam
        "B": (208, 134, 21, 255),    # #d08615 Burnished amber shadow
        "M": (255, 178, 45, 255),    # #ffb22d Core saturated yellow-gold
        "H": (255, 193, 85, 255),    # #ffc155 Luminous gold / plate bevel
        "S": (255, 242, 168, 255),   # #fff2a8 Specular gold glint
        "T": (164, 99, 14, 255),     # #a4630e Chiseled Greek wave crevice
        "A": (248, 72, 94, 255),     # #f8485e Ruby jewel highlight
        "G": (68, 36, 4, 255),       # #442404 Deepest crevice / shadow
    },
    "diamond": {
        "D": (53, 98, 137, 255),    # #356289 dark frame / outline
        "B": (69, 125, 158, 255),   # #457d9e shaded facet / base dark
        "M": (83, 151, 193, 255),   # #5397c1 mid blue
        "H": (119, 206, 251, 255),  # #77cefb light vibrant diamond cyan
        "S": (219, 238, 252, 255),  # #dbeefc highlight sparkle (crisp white-cyan)
        "T": (95, 174, 216, 255),   # #5faed8 mid cyan trim
        "A": (168, 226, 255, 255),  # #a8e2ff specular pale cyan accent
        "G": (36, 69, 99, 255),     # #244563 deep shadow / visor opening
    },
    "mithril": {
        "D": (20, 43, 98, 255),     # #142b62 Abyssal midnight navy seam / outline
        "B": (28, 60, 137, 255),    # #1c3c89 Deep royal cobalt shadow
        "M": (39, 89, 165, 255),    # #2759a5 Core saturated mithril blue body
        "H": (88, 130, 192, 255),   # #5882c0 Pale cobalt blue highlight / plate bevel
        "S": (214, 232, 255, 255),  # #d6e8ff Ultra specular silvery starlight glint
        "T": (59, 107, 180, 255),   # #3b6bb4 Cerulean cobalt midtone
        "A": (132, 164, 211, 255),  # #84a4d3 Light silvery blue / primary highlight
        "G": (12, 24, 58, 255),     # #0c183a Deepest crevice / inner slit
    },
    "crystal": {
        "D": (32, 69, 97, 255),      # #204561 Darkest plate border / outer bevel
        "B": (48, 134, 166, 255),    # #3086a6 Deep teal facet shadow
        "M": (56, 151, 174, 255),    # #3897ae Azure-teal midtone
        "H": (86, 199, 194, 255),    # #56c7c2 Luminous cyan facet highlight
        "S": (147, 217, 214, 255),   # #93d9d6 Specular crystal glint
        "T": (20, 46, 66, 255),      # #142e42 Deep inner slit / sole dark
        "A": (212, 248, 246, 255),   # #d4f8f6 Ultra specular apex glint
        "G": (47, 99, 135, 255),     # #2f6387 Abyssal crevice shadow
    },
    "nether": {
        "D": (22, 21, 23, 255),     # #161517 Deepest obsidian black / crevice
        "B": (36, 33, 38, 255),     # #242126 Deep basalt shadow
        "M": (54, 49, 56, 255),     # #363138 Core basalt dark plate
        "H": (181, 42, 26, 255),    # #b52a1a Saturated glowing crimson vein
        "S": (255, 218, 196, 255),  # #ffdac4 Searing white-hot volcanic spark
        "T": (76, 68, 78, 255),     # #4c444e Chiseled basalt bevel highlight
        "A": (218, 43, 22, 255),    # #da2b16 Blazing scarlet fire
        "G": (226, 115, 113, 255),  # #e27371 Glowing molten visor eyes
    },
    "cactus": {
        "D": (18, 34, 12, 255),     # #12220c dark border / plate boundary
        "B": (58, 84, 32, 255),     # #3a5420 shaded rib flank / groove
        "M": (78, 106, 42, 255),    # #4e6a2a core medium cactus green
        "H": (134, 162, 78, 255),   # #86a24e sunlit rib apex highlight
        "S": (235, 230, 220, 255),  # #ebe6dc spine needle tip (pale ivory)
        "T": (42, 68, 24, 255),     # #2a4418 deep groove shadow
        "A": (226, 68, 84, 255),    # #e24454 cactus blossom petal highlight
        "G": (10, 20, 8, 255),      # #0a1408 deepest crease / slit
    },
    "wood": {
        "D": (38, 26, 18, 255),     # #261a12 Darkest crevice / outline
        "B": (84, 58, 38, 255),     # #543a26 Deep wood shadow
        "M": (136, 98, 66, 255),    # #886242 Core medium oak wood
        "H": (192, 150, 108, 255),  # #c0966c Warm honey-oak plank face
        "S": (244, 218, 178, 255),  # #f4dab2 Specular wood glint / sunlit grain
        "T": (60, 40, 26, 255),     # #3c281a Dark recessed wood groove
        "A": (196, 208, 216, 255),  # #c4d0d8 Forged iron rivets / studs
        "G": (22, 14, 10, 255),     # #160e0a Deepest crease / slit
    },
    "admin": {
        "D": (36, 26, 46, 255),     # Deep amethyst boundary (#241a2e)
        "B": (156, 132, 158, 255),  # Shaded mauve lavender (#9c849e)
        "M": (204, 195, 221, 255),  # Shimmering periwinkle / soft orchid (#ccc3dd)
        "H": (201, 240, 229, 255),  # Soft prismatic seafoam mint (#c9f0e5)
        "S": (72, 230, 248, 255),   # Radiant celestial cyan neon (#48e6f8)
        "T": (92, 72, 102, 255),    # Deep plate shadow (#5c4866)
        "A": (240, 194, 48, 255),   # Pure celestial gold filigree (#f0c230)
        "G": (200, 250, 255, 255),  # White-hot cyan visor core (#c8faff)
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
        grid[5][7] = 'A'; grid[5][8] = 'A'
        grid[6][6] = 'A'; grid[6][7] = 'S'; grid[6][8] = 'S'; grid[6][9] = 'A'
        grid[7][6] = 'A'; grid[7][7] = 'S'; grid[7][8] = 'S'; grid[7][9] = 'A'
        grid[8][7] = 'H'; grid[8][8] = 'H'
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
    elif mat == "bronze":
        grid[6][7] = 'S'
        grid[6][8] = 'A'
        grid[7][7] = 'A'
        grid[7][8] = 'H'
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
    elif mat == "mithril":
        grid[5][7] = 'A'; grid[5][8] = 'A'
        grid[6][6] = 'A'; grid[6][7] = 'S'; grid[6][8] = 'S'; grid[6][9] = 'A'
        grid[7][6] = 'A'; grid[7][7] = 'S'; grid[7][8] = 'S'; grid[7][9] = 'A'
        grid[8][7] = 'A'; grid[8][8] = 'A'
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

DIAMOND_PALETTE = {
    'WH': (219, 238, 252, 255), # #dbeefc - Highlight/Sparkle (crisp ice white-cyan)
    'SP': (168, 226, 255, 255), # #a8e2ff - Specular pale cyan
    'LC': (119, 206, 251, 255), # #77cefb - Light vibrant diamond cyan
    'MC': (95, 174, 216, 255),  # #5faed8 - Mid diamond cyan
    'MB': (83, 151, 193, 255),  # #5397c1 - Core medium blue
    'DB': (69, 125, 158, 255),  # #457d9e - Dark blue shadow
    'DK': (53, 98, 137, 255),   # #356289 - Darkest border/bevel
    'CD': (36, 69, 99, 255),    # #244563 - Deep shadow / crease
    '..': EMPTY,
}

DIAMOND_SHEET_GRID = [
    # Row 00
    "LC SP WH .. .. .. .. .. .. .. .. .. .. MB DB DK "  # Shield (0..15)
    ".. .. .. .. LC SP WH LC LC MC MB DB .. .. .. .. "  # Boots top (16..31)
    ".. .. .. .. .. .. .. .. LC SP WH WH SP LC MC MB .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ", # Helmet top (32..63)

    # Row 01
    "SP WH WH SP SP SP LC LC LC MC MC MB MB DB DB DK "
    ".. .. .. .. LC MC MC MB MB MB DB DB .. .. .. .. "
    ".. .. .. .. .. .. .. .. SP WH WH SP LC MC MB DB .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 02
    "SP WH WH WH SP SP SP LC LC LC MC MC MB MB DB DK "  # Luminous bevel
    ".. .. .. .. MC MB MB DB DB DB DK DK .. .. .. .. "
    ".. .. .. .. .. .. .. .. LC WH SP LC MC MB DB DB .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 03
    "SP WH WH WH SP SP LC LC MC MC MB MB DB DB DB DK "
    ".. .. .. .. MB DB DB DK DK DK CD CD .. .. .. .. "
    ".. .. .. .. .. .. .. .. LC SP LC MC MB DB DB DK .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 04
    "SP WH SP WH SP LC LC MC MC MB MB DB DB DB DB DK "
    "LC MC MB DB MB DB DB DK MC MB DB DK SP WH SP LC "  # Boots cuffs
    ".. .. .. .. .. .. .. .. MC LC MC MB DB DB DK DK .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 05
    "SP LC SP LC SP LC MC SP LC MB DB DB DK DK DB DK "
    "LC MC MB DB MB DB DB DK LC MC MB DB LC SP LC MC "  # Boots shins
    ".. .. .. .. .. .. .. .. MC MC MB DB DB DK DK CD .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 06
    "SP LC LC LC MC SP WH WH LC MC MB DB DB DK DB DK "  # Emblem top
    "LC SP MC DB MB DB DB DK MC MB DB DK LC WH SP MB "  # Boots ankles
    ".. .. .. .. .. .. .. .. MB MB DB DB DK DK CD CD .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 07
    "LC LC MC LC MC LC WH SP MC MC MB DB DB DK DB DK "  # Emblem core
    "LC MC MB DB MB DB DK DK MC MB DB DK LC WH SP MB "  # Boots instep
    ".. .. .. .. .. .. .. .. DB DB DB DK DK CD CD CD .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 08
    "LC MC MC MC MB MC LC MC MB MB DB DB DK DK DB DK "  # Emblem base
    "MC MB DB DK DB DK DK CD MB DB DK DK LC SP LC MB "  # Boots toecap
    "LC LC MC MC MB MB DB DB MC LC SP WH SP LC MC MB SP LC LC MC MC MB MB DB MB MB DB DB DB DK DK CD ", # Helmet sides & front

    # Row 09
    "LC MB MB MC MB MB MB MC MB DB DB DK DK DK DB DK "
    "MB DB DK DK DB DK CD CD DB DK DK CD MC LC MB DB "  # Boots lower toe
    "LC LC MC MC MB MB DB DB LC SP LC WH SP LC MC DB SP LC MC MC MB MB DB DK MB DB DB DB DK DK CD CD ",

    # Row 10
    ".. MB DB MB MB MB MB MB DB DB DB DK DK DB DK .. "
    "DK DK DK CD CD CD CD CD CD DK DK DK DK DK CD CD "  # Boots soles
    "LC MC MC MB MB DB DB DK LC MC MC SP LC MC MB DB LC MC MC MB MB DB DK DK DB DB DB DK DK CD CD CD ",

    # Row 11
    ".. MB DB MB MB MB DB DB DB DK DK DK DK DB DK .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "LC MC MB MB DB DB DK DK LC .. .. WH MC .. .. DB MC MC MB DB DB DK DK CD DB DB DK DK DK CD CD CD ", # Visor nasal guard

    # Row 12
    ".. .. DB DB DB DB DB DK DK DK DK DK DK CD .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "MC MB MB DB DB DK DK CD MC .. .. SP MB .. .. DK MC MB DB DB DK DK CD CD DB DK DK DK CD CD CD CD ",

    # Row 13
    ".. .. .. DB DB DB DK DK DK DK CD CD CD .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "MC MB DB DB DK DK CD CD MB .. .. .. .. .. .. DK MB DB DB DK DK CD CD CD DK DK DK CD CD CD CD CD ",

    # Row 14
    ".. .. .. .. DB DK DK DK DK DK CD CD .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. DK DB DB DB DB DK .. ", # Neck guard flare

    # Row 15
    ".. .. .. .. .. .. DK DK CD CD .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 16
    ".. .. .. .. SP WH LC MC .. .. .. .. .. .. .. .. "  # Leggings top (16)
    ".. .. .. .. SP WH SP LC LC SP LC MC DB DB DB DB DB DK DK DK .. .. .. .. " # Chestplate top (24)
    ".. .. .. .. WH SP LC MC .. .. .. .. .. .. .. .. "  # Sleeves top (16)
    ".. .. .. .. .. .. .. .. ",                         # Empty (8)

    # Row 17
    ".. .. .. .. LC SP MC MB .. .. .. .. .. .. .. .. "
    ".. .. .. .. LC SP LC MC MC LC MC MB DB DB DB DB DB DK DK DK .. .. .. .. "
    ".. .. .. .. SP LC MC MB .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 18
    ".. .. .. .. LC MC MB DB .. .. .. .. .. .. .. .. "
    ".. .. .. .. LC SP .. .. .. .. MC MB DB DB DB DB DB DK DK DK .. .. .. .. "
    ".. .. .. .. LC MC MB DB .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 19
    ".. .. .. .. MC MB DB DK .. .. .. .. .. .. .. .. "
    ".. .. .. .. LC SP .. .. .. .. MC MB DB DB DB DB DB DK DK DK .. .. .. .. "
    ".. .. .. .. MC MB DB DK .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 20
    "LC MC MB DB LC SP LC MB LC MC MB DB MB DB DK CD "  # Leggings thighs (16)
    "LC MC MB DB LC SP .. .. .. .. LC MB MC MB DB DK MC MB LC MC MC MB DB DK " # Chestplate chest (24)
    "LC SP MC MB SP WH SP LC MC MB DB DK MB DB DK CD "  # Sleeves arm (16)
    ".. .. .. .. .. .. .. .. ",                         # Empty (8)

    # Row 21
    "LC MC MB DB LC SP LC MB LC MC MB DB MB DB DK CD "
    "LC MC MB DB LC SP LC .. .. LC MC MB MC MB DB DK MC MB LC MC MC MB DB DK "
    "LC SP MC MB LC SP LC MB MC MB DB DK MB DB DK CD "
    ".. .. .. .. .. .. .. .. ",

    # Row 22
    "LC MC MB DB LC SP LC MB LC MC MB DB MB DB DK CD "
    "LC MC MB DB LC SP LC WH SP LC MC MB MC MB DB DK MC MB LC MC MC MB DB DK "
    "LC MC MB DB LC LC MC MB MC MB DB DK MB DB DK CD "
    ".. .. .. .. .. .. .. .. ",

    # Row 23
    "LC MC MB DB LC SP LC MB LC MC MB DB MB DB DK CD "
    "LC MC MB DB SP WH SP WH SP LC MC MB MC MB DB DK MC MB LC MC MC MB DB DK " # Sparkling chestplate glint!
    "DK DK DK DK DK DK DK DK DK DK DK DK DK DK DK DK "
    ".. .. .. .. .. .. .. .. ",

    # Row 24
    "LC MC MB DB LC LC MC MB LC MC MB DB MB DB DK CD "  # Leggings knee top
    "LC MC MB DB LC SP LC WH SP MC MC MB MC MB DB DK MC MB LC MC MC MB DB DK " # Chestplate emblem
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 25
    "LC MC MB DB SP WH SP MB LC MC MB DB DB DK DK CD "  # Leggings knee glint!
    "LC MC MB DB LC LC MC LC MC MB DB DK MC MB DB DK MB DB LC MC MC MB DK DK "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 26
    "LC MC MB DB LC SP LC MB LC MC MB DB DB DK DK CD "  # Leggings knee base
    "LC MC MB DB LC SP WH SP LC MC MB DB MC MB DB DK MB DB LC MC MC MB DK DK " # Lame 1 specular
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 27
    "DK DK DK DK DK DK DK DK DK DK DK DK DK DK DK DK "  # Leggings hem
    "LC MC MB DB MC LC SP LC MC MB DB DK MC MB DB DK MB DB LC MC MC MB DK DK "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 28
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "LC MC MB DB LC SP LC LC MC MC MB DB MC MB DB DK MB DB LC MC MC MB DK DK " # Lame 2
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 29
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "LC MC MB DB MC LC MC MC MB MB DB DK MC MB DB DK MB DB LC MC MC MB DK DK "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 30
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "MC MB DB DK MC MC MB MB DB DB DK DK MB DB DK DK MB DB MB DB DK DK CD CD " # Lame 3 waist
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 31
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "DB LC DB DB LC DB DK WH SP DK DB LC DB DB LC DB DB LC DB DB LC DB DK DK " # Belt with diamond buckle
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",
]

def build_diamond_sheet():
    sheet = []
    for row_str in DIAMOND_SHEET_GRID:
        tokens = row_str.strip().split()
        sheet.append([DIAMOND_PALETTE[tok] for tok in tokens])
    return sheet

BRONZE_PALETTE = {
    'SP': (252, 192, 150, 255),  # Specular rivet glint / metallic gleam (warm copper-peach)
    'WH': (236, 160, 122, 255),  # Secondary highlight / bright rivet dome
    'HL': (218, 132, 94, 255),   # Highlight / top & left bevels
    'LB': (198, 112, 78, 255),   # Light bronze / sunlit face
    'MB': (174, 92, 62, 255),    # Core medium bronze / body midtone
    'CB': (152, 76, 52, 255),    # Classic bronze / warm metal tone
    'DB': (126, 60, 42, 255),    # Dark bronze shadow / shaded facet
    'SD': (102, 46, 32, 255),    # Recessed shadow base / panel texture
    'DK': (72, 32, 22, 255),     # Darkest outline / cast shadow / plate seam
    'CD': (44, 18, 12, 255),     # Deep crease / inner slit / sole dark
    '..': EMPTY,
}

BRONZE_SHEET_GRID = [
    # Row 00
    "LB SP WH .. .. .. .. .. .. .. .. .. .. MB DB DK "  # Shield (0..15)
    ".. .. .. .. LB SP WH LB LB MB CB DB .. .. .. .. "  # Boots top (16..31)
    ".. .. .. .. .. .. .. .. DK HL SP SP HL LB MB DK .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ", # Helmet top (32..63)

    # Row 01
    "SP WH HL LB LB LB LB LB LB LB LB LB MB CB DB DK "
    ".. .. .. .. LB HL LB MB MB CB DB DK .. .. .. .. "
    ".. .. .. .. .. .. .. .. HL SP LB SD SD LB SP MB .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 02
    "SP HL HL LB MB SD DK DK DK DK SD LB MB DB DB DK "
    ".. .. .. .. MB LB MB CB CB DB DK DK .. .. .. .. "
    ".. .. .. .. .. .. .. .. HL LB SP LB LB SP MB DB .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 03
    "SP HL SD SP WH LB SD DK DK SD LB SP WH SD DB DK "  # Shield rivets at (3,3) & (12,3)
    ".. .. .. .. CB MB CB DB DB DK DK CD .. .. .. .. "
    ".. .. .. .. .. .. .. .. LB SD LB SP WH LB SD DB .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 04
    "SP HL SD DB HL LB MB DK DK HL LB MB DB SD DB DK "
    "LB MB CB DB LB SP WH MB MB CB DB DK CB DB DK CD "  # Boots cuffs with front rivet at col 21
    ".. .. .. .. .. .. .. .. LB SD LB WH DK DB SD DK .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 05
    "HL LB SD DK SD HL LB SD SD MB DB DK SD SD DB DK "
    "LB MB CB DB LB HL LB MB MB CB DB DK CB DB DK CD "  # Boots shins
    ".. .. .. .. .. .. .. .. MB LB SP LB LB SP DB DK .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 06
    "HL LB SD DK DK HL LB LB LB LB MB DK DK SD DB DK "  # Shield central boss top
    "LB MB CB DB LB SP LB MB MB CB DB DK CB DB DK CD "  # Boots ankle with front rivet
    ".. .. .. .. .. .. .. .. MB SP LB SD SD LB SP DK .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 07
    "HL LB DK SD DK HL LB SP WH DB MB DK SD DK DB DK "  # Shield central boss center
    "LB MB CB DB HL LB MB DB MB CB DB DK CB DB DK CD "  # Boots instep
    ".. .. .. .. .. .. .. .. DK MB CB DB DB DK DK CD .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 08
    "LB MB SD DK DK HL LB WH DK DB MB DK DK SD DB DK "  # Shield central boss lower
    "MB CB DB DK LB SP WH MB CB DB DK DK DB DK DK CD "  # Boots sabaton toe cap with rivet at col 21
    "LB SP MB DB CB DB DK DK LB HL SP LB LB SP MB DB MB SP DB DK CB DB DK CD CB DB DK DK CB DB DK CD ", # Helmet brow band with rivets

    # Row 09
    "LB MB SD DK DK DB DB DK DK DK DB DK DK SD DB DK "  # Shield central boss bottom
    "CB DB DK DK LB HL MB DB DB DK DK CD DK DK CD CD "  # Boots lower toe rim
    "LB MB CB DB CB DB DK DK LB HL LB LB LB LB MB DB MB CB DB DK CB DB DK CD CB DB DK DK CB DB DK CD ",

    # Row 10
    ".. LB SD SP WH LB SD DK DK SD LB SP WH SD DB .. "  # Shield lower rivets at (3,10) & (12,10)
    "DK DK DK CD CD CD CD CD CD DK DK DK DK DK CD CD "  # Boots soles
    "LB MB CB DB CB DB DK DK LB LB LB HL LB LB MB DB MB CB DB DK CB DB DK CD DB DB DK DK DK DK CD CD ",

    # Row 11
    ".. MB SD DB HL LB MB DK DK HL LB MB DB SD DK .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "LB MB CB DB DB DK DK DK LB .. .. SP HL .. .. DB MB CB DB DK DK DK CD CD DB DB DK DK DK DK CD CD ", # Eye slits & nasal guard

    # Row 12
    ".. .. DB SD SD HL LB MB DK MB DB DK SD SD .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "MB CB DB DK DK DK CD CD MB .. .. HL LB .. .. DK CB DB DK DK DK CD CD CD DB DK DK DK CD CD CD CD ",

    # Row 13
    ".. .. .. DB DK SD HL LB MB DB DK SD DK .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "MB CB DB DK DK CD CD CD CB .. .. .. .. .. .. DK DK DK DK CD CD CD CD CD DK DK DK CD CD CD CD CD ",

    # Row 14
    ".. .. .. .. DK DK HL LB MB DB DK DK .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. DK LB MB CB DB DK .. ", # Neck guard flare

    # Row 15
    ".. .. .. .. .. .. DK LB DB DK .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 16
    ".. .. .. .. SP WH LB MB .. .. .. .. .. .. .. .. "  # Leggings top (16)
    ".. .. .. .. SP WH SP LB LB SP LB MB DB DB DB DB DB DK DK DK .. .. .. .. " # Chestplate top (24)
    ".. .. .. .. WH SP LB MB .. .. .. .. .. .. .. .. "  # Sleeves top (16)
    ".. .. .. .. .. .. .. .. ",                         # Empty (8)

    # Row 17
    ".. .. .. .. LB SP MB CB .. .. .. .. .. .. .. .. "
    ".. .. .. .. LB SP LB MB MB LB MB CB DB DB DB DB DB DK DK DK .. .. .. .. "
    ".. .. .. .. SP LB MB CB .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 18
    ".. .. .. .. LB MB CB DB .. .. .. .. .. .. .. .. "
    ".. .. .. .. LB SP .. .. .. .. MB CB DB DB DB DB DB DK DK DK .. .. .. .. " # Neck opening
    ".. .. .. .. LB MB CB DB .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 19
    ".. .. .. .. MB CB DB DK .. .. .. .. .. .. .. .. "
    ".. .. .. .. LB SP .. .. .. .. MB CB DB DB DB DB DB DK DK DK .. .. .. .. "
    ".. .. .. .. MB CB DB DK .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 20
    "LB MB CB DB LB SP LB CB MB CB DB DK CB DB DK CD "  # Leggings thighs with front rivet (16)
    "LB MB CB DB LB HL .. .. .. .. MB DB MB CB DB DK MB CB LB LB CB DB DK DK " # Chestplate chest with spine (24)
    "LB SP MB DB LB SP WH MB MB CB DB DK CB DB DK CD "  # Sleeves pauldron face with rivet (16)
    ".. .. .. .. .. .. .. .. ",                         # Empty (8)

    # Row 21
    "LB MB CB DB LB SP LB CB MB CB DB DK CB DB DK CD "
    "LB MB CB DB LB HL LB .. .. LB MB DB MB CB DB DK MB CB LB LB CB DB DK DK "
    "LB SP MB DB LB HL LB MB MB CB DB DK CB DB DK CD "
    ".. .. .. .. .. .. .. .. ",

    # Row 22
    "LB MB CB DB LB SP LB CB MB CB DB DK CB DB DK CD "
    "LB MB CB DB LB HL SP LB LB SP MB DB MB CB DB DK MB SP CB CB DB SP DK DK " # Cross-brace rivets at 22 & 25
    "LB MB CB DB LB MB CB DB MB CB DB DK CB DB DK CD "
    ".. .. .. .. .. .. .. .. ",

    # Row 23
    "LB MB CB DB LB SP LB CB MB CB DB DK CB DB DK CD "
    "LB MB CB DB LB HL LB SP WH LB MB DB MB CB DB DK MB CB LB LB CB DB DK DK " # Central boss emblem at 23 & 24
    "DK DK DK DK DK DK DK DK DK DK DK DK DK DK DK DK "
    ".. .. .. .. .. .. .. .. ",

    # Row 24
    "LB MB CB DB LB HL LB CB MB CB DB DK CB DB DK CD "
    "LB MB CB DB LB HL SP LB LB SP MB DB MB CB DB DK MB CB LB LB CB DB DK DK " # Lower cross-brace rivets
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 25
    "LB MB CB DB LB WH SP CB MB CB DB DK DB DK DK CD "  # Front poleyn kneecap rivet
    "LB MB CB DB LB LB MB LB MB MB DB DK MB CB DB DK CB DB CB CB DB DB DK DK "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 26
    "LB MB CB DB LB HL LB CB DB DK DK CD DB DK DK CD "
    "LB MB CB DB LB HL LB LB MB MB DB DK MB CB DB DK CB DB MB MB CB DB DK DK " # Abdominal lame 1
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 27
    "DK DK DK DK DK DK DK DK DK DK DK DK DK DK DK DK "
    "LB MB CB DB MB LB MB MB CB CB DB DK MB CB DB DK CB DB LB MB CB DB DK DK " # Abdominal lame 2
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 28
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "LB MB CB DB LB HL LB LB MB MB DB DK MB CB DB DK CB DB MB MB CB DB DK DK " # Abdominal lame 3
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 29
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "LB MB CB DB MB LB MB MB CB CB DB DK MB CB DB DK CB DB LB MB CB DB DK DK " # Abdominal lame 4
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 30
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "MB CB DB DK MB CB DB DK MB CB DB DK CB DB DK DK CB DB MB CB DB DK CD CD " # Abdominal lame 5
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 31
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "DB LB DB DB LB DB DK WH SP DK DB LB DB DB LB DB DB LB DB DB LB DB DK DK " # Studded belt & bronze buckle
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",
]

def build_bronze_sheet():
    sheet = []
    for row_str in BRONZE_SHEET_GRID:
        tokens = row_str.strip().split()
        sheet.append([BRONZE_PALETTE[tok] for tok in tokens])
    return sheet

CACTUS_PALETTE = {
    'ST': (235, 230, 220, 255),  # Spine sharp needle tip (pale ivory)
    'SM': (204, 190, 172, 255),  # Spine body (warm buff/cream)
    'SB': (172, 154, 132, 255),  # Spine base / areole pad (tan shadow)
    'HG': (134, 162, 78, 255),   # Sunlit rib apex highlight (olive-sage)
    'LG': (106, 134, 60, 255),   # Light green rib surface
    'MG': (78, 106, 42, 255),    # Core medium cactus green
    'DG': (58, 84, 32, 255),     # Shaded rib flank / groove
    'VD': (42, 68, 24, 255),     # Deep groove shadow
    'SD': (28, 50, 16, 255),     # Shadow crease / plate seam
    'DK': (18, 34, 12, 255),     # Darkest outline / boundary
    'CD': (10, 20, 8, 255),      # Deepest crease / slit / sole dark
    'FL': (226, 68, 84, 255),    # Cactus blossom petal highlight
    'FD': (168, 38, 52, 255),    # Cactus blossom petal shadow
    '..': EMPTY,
}

CACTUS_SHEET_GRID = [
    # Row 00
    "LG HG ST .. .. .. .. .. .. .. .. .. .. MG DG DK "  # Shield (0..15)
    ".. .. .. .. LG HG ST LG LG MG DG VD .. .. .. .. "  # Boots top (16..31)
    ".. .. .. .. .. .. .. .. DK LG HG HG LG MG DG DK .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ", # Helmet top (32..63)

    # Row 01
    "HG ST SM LG LG LG FL FL LG LG LG MG DG VD SD DK "  # Blossom bud at cols 6..7
    ".. .. .. .. LG HG LG MG DG VD SD DK .. .. .. .. "
    ".. .. .. .. .. .. .. .. LG ST LG VD VD LG ST MG .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ", # Skullcap spines

    # Row 02
    "ST SM LG MG VD VD FD FD VD VD MG LG MG DG SD DK "  # Blossom base & ribs
    ".. .. .. .. MG LG MG DG VD SD DK DK .. .. .. .. "
    ".. .. .. .. .. .. .. .. LG LG ST LG LG ST MG DG .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 03
    "LG MG VD ST SM LG VD VD LG ST SM MG VD DG SD DK "  # Upper shield spines at (3,3) & (10,3)
    ".. .. .. .. DG MG DG VD SD DK CD CD .. .. .. .. "
    ".. .. .. .. .. .. .. .. MG VD LG FL FD LG VD DG .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ", # Skullcap apex bloom

    # Row 04
    "LG MG VD SB LG HG LG LG HG LG SB MG VD DG SD DK "
    "LG MG DG VD LG ST SM MG MG DG VD DK DG VD SD DK "  # Boots cuffs with spine
    ".. .. .. .. .. .. .. .. MG VD LG FD FL LG VD DK .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 05
    "LG HG LG VD LG HG ST SM HG LG VD MG DG VD SD DK "  # Center rib spine cluster
    "LG MG DG VD LG HG LG MG MG DG VD DK DG VD SD DK "  # Boots shins
    ".. .. .. .. .. .. .. .. DG LG ST LG LG ST DG DK .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 06
    "ST SM LG VD LG HG SM SB HG LG VD MG DG VD SD DK "
    "LG MG DG VD LG ST LG MG MG DG VD DK DG VD SD DK "  # Boots ankle spine
    ".. .. .. .. .. .. .. .. DG ST LG VD VD LG ST DK .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 07
    "SB LG MG VD VD LG HG HG LG VD VD MG DG VD SD DK "
    "LG MG DG VD HG LG MG DG MG DG VD DK DG VD SD DK "  # Boots instep
    ".. .. .. .. .. .. .. .. DK MG DG VD VD DK DK CD .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 08
    "LG MG VD ST SM LG VD VD LG ST SM MG VD DG SD DK "  # Lower shield spines at (3,8) & (10,8)
    "MG DG VD DK LG ST SM MG DG VD DK DK DG DK DK CD "  # Boots toe cap spine
    "LG ST MG DG DG VD DK DK LG HG ST LG LG ST MG DG MG ST DG VD DG VD DK CD DG VD DK DK DG VD DK CD ", # Helmet brow with spines

    # Row 09
    "LG MG VD SB LG HG LG LG HG LG SB MG VD DG SD DK "
    "DG VD DK DK LG HG MG DG VD DK DK CD DK DK CD CD "  # Boots toe rim
    "LG MG DG VD DG VD DK DK LG HG LG LG LG LG MG DG MG DG VD DK DG VD DK CD DG VD DK DK DG VD DK CD ",

    # Row 10
    ".. LG VD LG HG ST SM HG LG VD MG DG VD SD DK .. "  # Lower center spine
    "DK DK DK CD CD CD CD CD CD DK DK DK DK DK CD CD "  # Boots soles
    "LG MG DG VD DG VD DK DK LG LG LG HG LG LG MG DG MG DG VD DK DG VD DK CD VD VD DK DK DK DK CD CD ",

    # Row 11
    ".. MG VD VD LG HG SM SB LG VD VD DG SD DK DK .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "LG MG DG VD VD DK DK DK LG .. .. ST HG .. .. DG MG DG VD DK DK DK CD CD VD VD DK DK DK DK CD CD ", # Eye slits & nasal spine

    # Row 12
    ".. .. VD VD VD LG HG HG LG VD VD DG SD DK .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "MG DG VD DK DK DK CD CD MG .. .. HG LG .. .. DK DG VD DK DK DK CD CD CD VD DK DK DK CD CD CD CD ",

    # Row 13
    ".. .. .. DK VD LG HG LG VD DG SD DK DK .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "MG DG VD DK DK CD CD CD DG .. .. .. .. .. .. DK DK DK DK CD CD CD CD CD DK DK DK CD CD CD CD CD ",

    # Row 14
    ".. .. .. .. DK VD LG MG DG SD DK DK .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. DK LG MG DG VD DK .. ", # Neck guard flare

    # Row 15
    ".. .. .. .. .. .. DK DG SD DK .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 16
    ".. .. .. .. ST SM LG MG .. .. .. .. .. .. .. .. "  # Leggings top (16)
    ".. .. .. .. ST SM ST LG LG ST LG MG DG DG DG DG DG DK DK DK .. .. .. .. " # Chestplate top (24)
    ".. .. .. .. SM ST LG MG .. .. .. .. .. .. .. .. "  # Sleeves top (16)
    ".. .. .. .. .. .. .. .. ",                         # Empty (8)

    # Row 17
    ".. .. .. .. LG ST MG DG .. .. .. .. .. .. .. .. "
    ".. .. .. .. LG ST LG MG MG LG MG DG DG DG DG DG DG DK DK DK .. .. .. .. "
    ".. .. .. .. ST LG MG DG .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 18
    ".. .. .. .. LG MG DG VD .. .. .. .. .. .. .. .. "
    ".. .. .. .. LG ST .. .. .. .. MG DG DG DG DG DG DG DK DK DK .. .. .. .. " # Neck opening
    ".. .. .. .. LG MG DG VD .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 19
    ".. .. .. .. MG DG VD DK .. .. .. .. .. .. .. .. "
    ".. .. .. .. LG ST .. .. .. .. MG DG DG DG DG DG DG DK DK DK .. .. .. .. "
    ".. .. .. .. MG DG VD DK .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 20
    "LG MG DG VD LG ST LG DG MG DG VD DK DG VD DK CD "  # Leggings thighs with front spine (16)
    "LG MG DG VD LG HG .. .. .. .. MG DG MG DG VD DK MG DG LG LG DG VD DK DK " # Chestplate chest (24)
    "LG ST MG DG LG ST SM MG MG DG VD DK DG VD DK CD "  # Sleeves pauldron with spine (16)
    ".. .. .. .. .. .. .. .. ",                         # Empty (8)

    # Row 21
    "LG MG DG VD LG ST LG DG MG DG VD DK DG VD DK CD "
    "LG MG DG VD LG HG LG .. .. LG MG DG MG DG VD DK MG DG LG LG DG VD DK DK "
    "LG ST MG DG LG HG LG MG MG DG VD DK DG VD DK CD "
    ".. .. .. .. .. .. .. .. ",

    # Row 22
    "LG MG DG VD LG ST LG DG MG DG VD DK DG VD DK CD "
    "LG MG DG VD LG HG ST LG LG ST MG DG MG DG VD DK MG ST DG DG VD ST DK DK " # Chest spines at 22 & 25
    "LG MG DG VD LG MG DG VD MG DG VD DK DG VD DK CD "
    ".. .. .. .. .. .. .. .. ",

    # Row 23
    "LG MG DG VD LG ST LG DG MG DG VD DK DG VD DK CD "
    "LG MG DG VD LG HG LG FL FD LG MG DG MG DG VD DK MG DG LG LG DG VD DK DK " # Central blossom bud at 23 & 24
    "DK DK DK DK DK DK DK DK DK DK DK DK DK DK DK DK "
    ".. .. .. .. .. .. .. .. ",

    # Row 24
    "LG MG DG VD LG HG LG DG MG DG VD DK DG VD DK CD "
    "LG MG DG VD LG HG ST LG LG ST MG DG MG DG VD DK MG DG LG LG DG VD DK DK " # Lower chest spines
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 25
    "LG MG DG VD LG SM ST DG MG DG VD DK VD DK DK CD "  # Front poleyn kneecap spine
    "LG MG DG VD LG LG MG LG MG MG DG DK MG DG VD DK DG VD DG DG VD VD DK DK "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 26
    "LG MG DG VD LG HG LG DG VD DK DK CD VD DK DK CD "
    "LG MG DG VD LG HG LG LG MG MG DG DK MG DG VD DK DG VD MG MG DG VD DK DK " # Abdominal lame 1
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 27
    "DK DK DK DK DK DK DK DK DK DK DK DK DK DK DK DK "
    "LG MG DG VD MG LG MG MG DG DG VD DK MG DG VD DK DG VD LG MG DG VD DK DK " # Abdominal lame 2
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 28
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "LG MG DG VD LG HG LG LG MG MG DG DK MG DG VD DK DG VD MG MG DG VD DK DK " # Abdominal lame 3
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 29
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "LG MG DG VD MG LG MG MG DG DG VD DK MG DG VD DK DG VD LG MG DG VD DK DK " # Abdominal lame 4
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 30
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "MG DG VD DK MG DG VD DK MG DG VD DK DG VD DK DK DG VD MG DG VD DK CD CD " # Abdominal lame 5
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 31
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "VD LG VD VD LG VD DK FL FD DK VD LG VD VD LG VD VD LG VD VD LG VD DK DK " # Studded belt & blossom buckle
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",
]

def build_cactus_sheet():
    sheet = []
    for row_str in CACTUS_SHEET_GRID:
        tokens = row_str.strip().split()
        sheet.append([CACTUS_PALETTE[tok] for tok in tokens])
    return sheet

CRYSTAL_PALETTE = {
    'SG': (212, 248, 246, 255),  # #d4f8f6 Ultra specular apex glint / diamond-crystal sparkle
    'G1': (147, 217, 214, 255),  # #93d9d6 Signature reference highlight / prism gleam
    'C3': (86, 199, 194, 255),   # #56c7c2 Luminous cyan facet highlight
    'C2': (79, 192, 187, 255),   # #4fc0bb Vibrant aqua-cyan facet
    'C1': (73, 186, 181, 255),   # #49bab5 Turquoise body
    'M3': (64, 159, 182, 255),   # #409fb6 Bright cerulean-teal body
    'M2': (56, 151, 174, 255),   # #3897ae Azure-teal midtone
    'M1': (56, 142, 174, 255),   # #388eae Medium azure-teal
    'M0': (53, 139, 171, 255),   # #358bab Saturated deep teal
    'D3': (48, 134, 166, 255),   # #3086a6 Deep teal facet shadow
    'D2': (43, 129, 161, 255),   # #2b81a1 Deep azure-teal
    'S4': (58, 116, 151, 255),   # #3a7497 Slate azure transition
    'S3': (55, 110, 146, 255),   # #376e92 Slate azure facet boundary
    'S2': (53, 107, 142, 255),   # #356b8e Dark slate azure crevice
    'S1': (50, 103, 139, 255),   # #32678b Deep ocean slate
    'S0': (47, 99, 135, 255),    # #2f6387 Abyssal crevice shadow
    'DK': (32, 69, 97, 255),     # #204561 Darkest plate border / outer bevel
    'CD': (20, 46, 66, 255),     # #142e42 Deep inner slit / sole dark
    '..': EMPTY,
}

CRYSTAL_SHEET_GRID = [
    # Row 00
    "C2 C3 G1 .. .. .. .. .. .. .. .. .. .. M1 D3 DK "  # Shield (0..15)
    ".. .. .. .. C3 G1 SG C2 C3 G1 C2 M1 .. .. .. .. "  # Boots top (16..31)
    ".. .. .. .. .. .. .. .. DK C2 C3 G1 G1 C3 M1 DK .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ", # Helmet top (32..63)

    # Row 01
    "G1 C3 C2 C1 M3 M2 M1 D3 D2 S4 S3 S2 D3 M1 C2 DK "  # Shield top beveled rim
    ".. .. .. .. G1 SG C3 M1 G1 C3 M1 D3 .. .. .. .. "
    ".. .. .. .. .. .. .. .. C2 G1 SG C3 C3 SG G1 M1 .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 02
    "C3 G1 C2 C3 G1 M2 M1 S3 S2 D3 M2 M1 C2 C3 G1 DK "  # Upper diagonal crystal facets
    ".. .. .. .. C3 C2 M2 D3 C2 M1 D3 S3 .. .. .. .. "
    ".. .. .. .. .. .. .. .. C3 SG G1 C2 C2 G1 SG M2 .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 03
    "G1 C3 C3 SG G1 C2 M1 D3 S3 S2 D3 M1 C2 C3 G1 DK "  # Specular facet glint at (3,3)
    ".. .. .. .. M2 M1 D3 S3 M1 D3 S3 DK .. .. .. .. "
    ".. .. .. .. .. .. .. .. G1 C3 C2 G1 G1 C2 C3 M1 .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 04
    "C3 G1 G1 C3 C2 M1 D3 S3 S2 S1 S3 D3 M2 M1 C2 DK "
    "M2 C3 G1 C2 C3 G1 SG C2 C2 C3 M1 D3 D3 S3 S2 DK "  # Boots shins & facets
    ".. .. .. .. .. .. .. .. C3 C2 G1 SG SG G1 C2 M2 .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 05
    "G1 C3 C2 M2 M1 D3 S3 C2 C3 G1 M2 D3 S2 D3 M1 DK "  # Secondary prism shard
    "M1 G1 C3 M1 G1 C3 C2 M1 C1 C2 M1 D3 S3 S2 S1 DK "
    ".. .. .. .. .. .. .. .. C2 G1 C3 C2 C2 C3 G1 M1 .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 06
    "C3 G1 M1 D3 S3 S2 C3 SG G1 C3 M1 D3 S3 S2 M2 DK "  # Center prism specular glint
    "M2 C2 M1 D3 C3 G1 C2 M1 M2 M1 D3 S3 S2 S1 S0 DK "
    ".. .. .. .. .. .. .. .. C1 C3 SG C2 C2 SG C3 M2 .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 07
    "G1 C3 D3 S3 S2 C2 C3 SG G1 C2 M1 D3 S3 S2 M1 DK "  # Center diamond core apex
    "D3 M1 D3 S3 C2 C3 G1 M1 M1 D3 S3 DK S1 S0 CD DK "
    ".. .. .. .. .. .. .. .. DK C2 C3 G1 G1 C3 M1 DK .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 08
    "C3 G1 S3 S2 S1 C1 G1 C3 C2 M2 M1 D3 S3 S2 D3 DK "  # Diamond prism base
    "D2 D3 S3 DK C3 G1 SG C2 C2 M1 D3 DK S2 S1 DK DK "  # Ankle crystal guard & toe cap
    "DK C2 C3 G1 G1 C3 M1 DK C2 C3 G1 SG G1 C3 C2 M1 DK C2 C3 G1 G1 C3 M1 DK DK M2 M1 D3 S3 S2 S1 DK ", # Helmet brow band

    # Row 09
    "G1 C3 S2 S1 M2 C2 C3 M1 D3 D2 S3 S2 S1 D3 M1 DK "
    "D3 S3 S2 DK C3 G1 SG C2 C2 M1 D3 DK S2 S1 DK DK "  # Sabaton toe cap with faceted crystal point
    "C2 G1 C3 M2 M2 C3 G1 M1 C1 C3 G1 SG G1 C3 M1 DK C2 G1 C3 M2 M2 C3 G1 M1 M2 M1 D3 S3 D3 S3 S2 DK ", # Forehead prism jewel at (43..44, 9)

    # Row 10
    ".. G1 C3 S3 D3 M1 C2 M1 D3 S3 S2 S1 CD D3 M1 .. "
    "DK S1 S0 CD CD CD CD CD CD DK S1 S0 DK DK CD CD "  # Heavy slate sole
    "G1 C3 M2 M1 M1 M2 C3 M1 C3 G1 M2 M1 M2 M1 D3 DK G1 C3 M2 M1 M1 M2 C3 M1 M1 D3 S3 S2 M1 D3 S3 DK ",

    # Row 11
    ".. C3 G1 S2 S3 D3 M1 D3 S3 S2 S1 CD S2 M1 DK .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "C3 M2 M1 D3 D3 M1 M2 M1 C3 .. .. G1 C3 .. .. M1 C3 M2 M1 D3 D3 M1 M2 M1 D3 S3 S2 S1 D3 S3 S2 DK ", # Visor eye slits at (41..42) & (45..46)

    # Row 12
    ".. .. C3 G1 S3 D3 S3 S2 S1 CD CD S3 M1 DK .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "M2 M1 D3 S3 S3 D3 M1 M2 C2 .. .. C3 M2 .. .. D3 M2 M1 D3 S3 S3 D3 M1 M2 S3 S2 S1 S0 S3 S2 S1 DK ", # Lower visor cheek guards

    # Row 13
    ".. .. .. C3 G1 S3 D3 S2 S1 CD S3 M1 DK .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "M1 D3 S3 S2 S2 S3 D3 M1 C1 .. .. .. .. .. .. S3 M1 D3 S3 S2 S2 S3 D3 M1 S2 S1 S0 CD S2 S1 S0 DK ", # Mouth aperture

    # Row 14
    ".. .. .. .. C3 G1 S2 S1 CD S3 DK DK .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. DK D3 S3 S2 S1 DK .. ", # Neck guard flap

    # Row 15
    ".. .. .. .. .. .. C2 G1 M1 DK .. .. .. .. .. .. "  # Shield faceted tip
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 16
    ".. .. .. .. C3 G1 SG C2 .. .. .. .. .. .. .. .. "  # Leggings top (16)
    ".. .. .. .. C3 G1 SG C2 C2 C3 M1 D3 C3 G1 C2 M1 M2 M1 D3 S3 .. .. .. .. "  # Chestplate shoulders/collar (24)
    ".. .. .. .. C3 G1 SG C2 .. .. .. .. .. .. .. .. "  # Sleeves top (16)
    ".. .. .. .. .. .. .. .. ",                         # Empty (8)

    # Row 17
    ".. .. .. .. G1 C3 C2 M1 .. .. .. .. .. .. .. .. "
    ".. .. .. .. G1 C3 C2 M1 C1 C2 M1 S3 G1 C3 M1 D3 M1 D3 S3 DK .. .. .. .. "
    ".. .. .. .. G1 C3 C2 M1 .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 18
    ".. .. .. .. C2 C3 M1 D3 .. .. .. .. .. .. .. .. "
    ".. .. .. .. C2 M1 .. .. .. .. M1 D3 C2 M1 D3 S3 M2 M1 D3 S3 .. .. .. .. "  # Neck opening (22..25 empty)
    ".. .. .. .. C2 C3 M1 D3 .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 19
    ".. .. .. .. M2 M1 D3 S3 .. .. .. .. .. .. .. .. "
    ".. .. .. .. M1 D3 .. .. .. .. D3 S3 M1 D3 S3 DK M1 D3 S3 DK .. .. .. .. "
    ".. .. .. .. M2 M1 D3 S3 .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 20
    "M2 M1 D3 DK C3 G1 C2 M1 M1 D3 S3 DK D3 S3 S2 DK "  # Leggings thigh (16)
    "M2 M1 D3 DK C2 C3 .. .. .. .. M1 D3 M1 D3 S3 DK C3 G1 SG C2 C3 G1 C2 M1 "  # Chestplate gorget & front (24)
    "C3 G1 SG C2 C3 G1 C2 M1 M2 M1 D3 S3 S3 D3 M1 M2 "  # Sleeves arm (16)
    ".. .. .. .. .. .. .. .. ",                         # Empty (8)

    # Row 21
    "M1 D3 S3 DK C2 C3 G1 M1 D3 S3 S2 DK S2 S1 S0 DK "
    "M1 D3 S3 DK C3 G1 C2 .. .. C2 G1 M1 D3 S3 S2 DK G1 C3 C2 M1 G1 C3 M1 D3 "
    "G1 C3 C2 M1 G1 C3 C2 M1 M1 D3 S3 S2 S2 S3 D3 M1 "
    ".. .. .. .. .. .. .. .. ",

    # Row 22
    "D3 S3 S2 DK C3 SG G1 M1 S3 S2 S1 DK S1 S0 CD DK "  # Knee poleyn apex
    "D3 S3 S2 DK C2 C3 G1 SG SG G1 C3 M1 S3 S2 S1 DK C2 C3 M1 D3 C2 M1 D3 S3 "  # Breastplate twin specular gleams
    "C2 C3 M1 D3 C2 C3 C2 M1 D3 S3 S2 S1 S1 S2 S3 D3 "
    ".. .. .. .. .. .. .. .. ",

    # Row 23
    "S3 S2 S1 DK C1 C3 M1 D3 S2 S1 S0 DK S0 CD CD DK "  # Knee poleyn base
    "S3 S2 S1 DK C1 C2 C3 G1 G1 C3 C2 D3 S2 S1 S0 DK M2 M1 D3 S3 M1 D3 S3 DK "  # Glowing crystal sternum core
    "DK DK DK DK DK DK DK DK DK DK DK DK DK DK DK DK "
    ".. .. .. .. .. .. .. .. ",

    # Row 24
    "M2 C3 G1 C2 C3 G1 C2 M1 C2 C3 M1 D3 D3 S3 S2 DK "  # Shin greave top (16)
    "M2 M1 D3 DK C2 C3 G1 M2 M1 G1 C3 M1 M1 D3 S3 DK D3 S3 S2 S1 C3 G1 S1 S2 "  # Chestplate & backplate (24)
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "  # Empty sleeves (16)
    ".. .. .. .. .. .. .. .. ",                         # Empty (8)

    # Row 25
    "M1 G1 C3 M1 G1 C3 C2 M1 C1 C2 M1 D3 S3 S2 S1 DK "
    "M1 D3 S3 DK C1 C2 C3 G1 C3 C2 M1 D3 D3 S3 S2 DK S3 S2 S1 S0 G1 SG S0 S1 "  # Luminous spine node
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 26
    "M2 C2 M1 D3 C3 G1 C2 M1 M2 M1 D3 S3 S2 S1 S0 DK "  # Abdominal lame 1
    "D3 S3 S2 DK C2 C3 G1 M2 M1 C3 M1 D3 S3 S2 S1 DK S2 S1 S0 CD C3 G1 CD S0 "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 27
    "D3 M1 D3 S3 C2 C3 G1 M1 M1 D3 S3 DK S1 S0 CD DK "  # Abdominal lame 2
    "S3 S2 S1 DK M3 C2 C3 M1 M2 M1 D3 S3 S2 S1 S0 DK S1 S0 CD CD M1 C3 CD CD "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 28
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "  # Leggings empty (16)
    "D3 S3 S2 DK C2 M3 M2 D3 M1 D3 S3 DK S3 S2 S1 DK S2 S1 S0 CD C2 M1 CD S0 "  # Abdominal lame 3 (24)
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "  # Empty (16)
    ".. .. .. .. .. .. .. .. ",                         # Empty (8)

    # Row 29
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "S3 S2 S1 DK M2 M1 D3 S3 D3 S3 S2 DK S2 S1 S0 DK S1 S0 CD CD M2 D3 CD CD "  # Abdominal lame 4
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 30
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "S2 S1 S0 DK M1 D3 S3 DK S3 S2 S1 DK S0 CD CD DK S0 CD CD CD D3 S3 CD CD "  # Fauld / waist
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 31
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "DK S3 DK DK S3 D3 DK G1 SG C3 DK S3 DK S3 DK DK DK S3 S2 DK DK DK DK DK "  # Belt with crystal gem buckle
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",
]

def build_crystal_sheet():
    sheet = []
    for row_str in CRYSTAL_SHEET_GRID:
        tokens = row_str.strip().split()
        sheet.append([CRYSTAL_PALETTE[tok] for tok in tokens])
    return sheet

GOLD_PALETTE = {
    'SP': (255, 242, 168, 255),  # #fff2a8 Specular luster / sunlit gold glint
    'WH': (255, 205, 119, 255),  # #ffcd77 Warm bright gold highlight / wave crest
    'HL': (255, 193,  85, 255),  # #ffc155 Luminous gold / plate bevel
    'LG': (255, 184,  54, 255),  # #ffb836 Light regal gold body
    'MG': (255, 178,  45, 255),  # #ffb22d Core saturated yellow-gold
    'AG': (245, 160,  16, 255),  # #f5a010 Amber-gold body / wave curl center
    'BA': (208, 134,  21, 255),  # #d08615 Burnished amber shadow / groove divider
    'DA': (184, 112,  17, 255),  # #b87011 Dark amber shadow / curl shadow
    'CH': (164,  99,  14, 255),  # #a4630e Chiseled filigree crevice / Greek wave line
    'DK': (110,  62,   6, 255),  # #6e3e06 Darkest outline / plate boundary seam
    'CD': ( 68,  36,   4, 255),  # #442404 Deepest crevice / inner slit / sole dark
    'RB': (248,  72,  94, 255),  # #f8485e Ruby gem highlight / royal medallion
    'RD': (192,  24,  48, 255),  # #c01830 Ruby gem shadow / royal medallion
    '..': EMPTY,
}

GOLD_SHEET_GRID = [
    # Row 00
    "HL WH SP .. .. .. .. .. .. .. .. .. .. MG BA DK "  # Shield (0..15)
    ".. .. .. .. WH BA WH BA WH BA WH DA .. .. .. .. "  # Boots top beaded trim (16..31)
    ".. .. .. .. .. .. .. .. DK HL WH SP SP WH HL DK .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ", # Helmet top crown (32..63)

    # Row 01
    "SP WH HL LG MG AG BA BA BA BA AG MG LG HL WH DK "  # Shield upper bevel rim
    ".. .. .. .. SP HL MG DA SP HL MG DA .. .. .. .. "
    ".. .. .. .. .. .. .. .. HL SP WH LG LG WH SP HL .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 02
    "WH HL WH HL LG CH WH HL LG CH AG BA DA CH BA DK "  # Shield Greek wave band 1
    ".. .. .. .. HL MG DA DK HL MG DA DK .. .. .. .. "
    ".. .. .. .. .. .. .. .. WH HL MG DA DA MG HL WH .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 03
    "HL LG HL CH AG DA HL CH AG DA BA DA CH DK DA DK "  # Wave curl relief
    ".. .. .. .. MG DA DK CD MG DA DK CD .. .. .. .. "
    ".. .. .. .. .. .. .. .. LG WH SP RB RD SP WH LG .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ", # Crown center ruby

    # Row 04
    "LG MG LG DA CH BA LG DA CH BA DA CH DK CD DK DK "  # Wave base & shadow
    "LG MG AG BA WH HL LG CH HL CH AG DA BA DA DK CD "  # Boots shins Greek wave
    ".. .. .. .. .. .. .. .. LG WH SP RD RB SP WH LG .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 05
    "MG AG BA WH BA WH BA WH BA WH BA DA CH DK CD DK "  # Beaded pearl chain band 1
    "MG AG BA DA LG DA CH BA LG DA CH BA DA CH DK CD "
    ".. .. .. .. .. .. .. .. WH HL MG DA DA MG HL WH .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 06
    "AG BA DA HL WH LG BA LG WH HL DA CH DK CD CD DK "  # Royal sun boss top
    "AG BA DA DK WH BA WH BA WH BA WH DA CH DK CD CD "  # Boots ankle beaded stud
    ".. .. .. .. .. .. .. .. HL SP WH LG LG WH SP HL .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 07
    "BA DA CH WH SP HL RB RB HL SP DA CH DK CD CD DK "  # Sun boss ruby gem
    "BA DA DK DK HL SP LG DK HL SP LG DK DK CD CD CD "
    ".. .. .. .. .. .. .. .. DK HL WH SP SP WH HL DK .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 08
    "BA DA CH WH SP HL RD RD HL SP DA CH DK CD CD DK "  # Sun boss ruby base
    "DA CH DK DK HL SP LG DK HL SP LG DK DK CD CD CD "  # Sabaton toe cap
    "DK WH BA WH BA WH BA DK WH BA WH BA WH BA WH DK DK WH BA WH BA WH BA DK DK DA CH DK DK CH DA DK ", # Helmet beaded brow band

    # Row 09
    "AG BA DA HL WH LG BA LG WH HL DA CH DK CD CD DK "  # Sun boss bottom
    "DA CH DK DK HL SP LG DK HL SP LG DK DK CD CD CD "
    "HL WH LG MG MG LG WH HL LG WH SP RB RD SP WH LG HL WH LG MG MG LG WH HL MG AG BA DA CH DK DK CD ", # Forehead royal ruby crest (43..44, 9)

    # Row 10
    ".. BA DA CH WH BA WH BA WH BA WH BA DA CH DK .. "  # Beaded chain band 2
    "DK DA CH CD CD CD CD CD CD DK DA CH DK DK CD CD "  # Durable burnished sole
    "WH HL LG MG AG BA DA DK WH HL LG MG AG BA DA DK WH HL LG MG AG BA DA DK AG BA DA CH DK CD CD CD ",

    # Row 11
    ".. DA CH LG CH WH HL LG CH AG BA CH DK CD DK .. "  # Lower Greek wave
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "HL LG MG DA CH DK DK DK HL .. .. SP MG .. .. DA HL LG MG DA CH DK DK DK BA DA CH DK CD CD CD CD ", # Eye slits & golden nasal guard

    # Row 12
    ".. .. CH HL CH AG DA HL CH AG DA CH DK CD .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "LG MG AG BA DA DK CD CD LG .. .. WH AG .. .. DK LG MG AG BA DA DK CD CD DA CH DK CD CD CD CD CD ", # Cheek guards Greek wave

    # Row 13
    ".. .. .. CH LG DA CH BA DA CH DK DK CD .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "MG AG BA DA CH DK CD CD MG .. .. .. .. .. .. DK MG AG BA DA CH DK CD CD CH DK CD CD CD CD CD CD ", # Lower mouth aperture

    # Row 14
    ".. .. .. .. CH BA DA CH DK DK CD CD .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. DK WH BA WH BA DK .. ", # Beaded neck flap

    # Row 15
    ".. .. .. .. .. .. HL SP LG DK .. .. .. .. .. .. "  # Shield golden tip
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 16
    ".. .. .. .. WH BA WH BA .. .. .. .. .. .. .. .. "  # Leggings top beaded band (16)
    ".. .. .. .. WH BA WH BA WH BA WH BA WH BA WH BA WH BA WH BA .. .. .. .. "  # Chestplate beaded collar (24)
    ".. .. .. .. HL SP WH LG .. .. .. .. .. .. .. .. "  # Sleeves pauldron top (16)
    ".. .. .. .. .. .. .. .. ",                         # Empty (8)

    # Row 17
    ".. .. .. .. HL SP LG MG .. .. .. .. .. .. .. .. "
    ".. .. .. .. HL SP WH LG HL SP WH LG HL SP WH LG HL SP WH LG .. .. .. .. "  # Pauldron/clavicle golden bevels
    ".. .. .. .. SP WH HL MG .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 18
    ".. .. .. .. LG MG AG BA .. .. .. .. .. .. .. .. "
    ".. .. .. .. LG MG .. .. .. .. AG BA LG MG AG BA LG MG AG BA .. .. .. .. "  # Neck opening (22..25 empty)
    ".. .. .. .. WH HL MG DA .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 19
    ".. .. .. .. MG AG BA DA .. .. .. .. .. .. .. .. "
    ".. .. .. .. MG AG .. .. .. .. BA DA MG AG BA DA MG AG BA DA .. .. .. .. "
    ".. .. .. .. HL MG DA DK .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 20
    "LG MG AG BA WH BA WH BA AG BA DA DK DA CH DK CD "  # Leggings thighs (16)
    "LG MG AG BA WH BA .. .. .. .. WH BA AG BA DA DK HL SP WH LG LG WH SP HL "  # Gorget & breastplate top (24)
    "HL SP WH LG LG WH SP HL LG MG AG BA DA CH DK CD "  # Sleeves arm (16)
    ".. .. .. .. .. .. .. .. ",                         # Empty (8)

    # Row 21
    "MG AG BA DA HL SP WH LG BA DA CH DK CH DK CD CD "
    "MG AG BA DA HL SP WH .. .. WH SP HL BA DA CH DK SP WH HL MG MG HL WH SP "
    "SP WH HL LG LG HL WH SP MG AG BA DA CH DK CD CD "
    ".. .. .. .. .. .. .. .. ",

    # Row 22
    "AG BA DA DK WH HL LG CH DA CH DK CD DK CD CD CD "  # Thigh Greek wave
    "AG BA DA DK WH HL LG CH CH LG HL WH DA CH DK CD WH HL MG DA DA MG HL WH "  # Breastplate Greek wave crest
    "WH HL MG DA DA MG HL WH AG BA DA DK DK CD CD CD "
    ".. .. .. .. .. .. .. .. ",

    # Row 23
    "BA DA CH DK HL CH AG DA CH DK CD CD CD CD CD CD "  # Knee poleyn top
    "BA DA CH DK HL CH SP RB RB SP CH HL DA CH DK CD LG MG DA DK DK DA MG LG "  # Pectoral ruby sun medallion!
    "DK DK DK DK DK DK DK DK DK DK DK DK DK DK DK DK "
    ".. .. .. .. .. .. .. .. ",

    # Row 24
    "HL SP WH LG LG DA CH BA LG WH SP HL DA CH DK CD "  # Knee poleyn apex glint (16)
    "BA DA CH DK HL CH SP RD RD SP CH HL DA CH DK CD HL SP WH LG LG WH SP HL "  # Pectoral ruby base & backplate (24)
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "  # Empty sleeves (16)
    ".. .. .. .. .. .. .. .. ",                         # Empty (8)

    # Row 25
    "SP WH HL MG AG BA DA DK AG BA DA CH CH DK CD CD "  # Knee poleyn base
    "AG BA DA DK WH HL LG CH CH LG HL WH DA CH DK CD SP WH HL MG MG HL WH SP "  # Breastplate wave base
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 26
    "WH HL LG CH WH HL LG CH AG BA DA DK DA CH DK CD "  # Shin greave Greek wave
    "LG MG AG BA WH HL LG CH WH HL LG CH AG BA DA DK WH HL MG DA DA MG HL WH "  # Abdominal lame 1 Greek wave
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 27
    "HL CH AG DA HL CH AG DA BA DA CH DK CH DK CD CD "
    "MG AG BA DA WH BA WH BA WH BA WH BA BA DA CH DK MG AG BA DA DA BA AG MG "  # Abdominal lame 2 beaded pearl chain!
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 28
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "  # Leggings empty (16)
    "AG BA DA DK WH HL LG MG LG MG HL WH DA CH DK CD AG BA DA DK DK DA BA AG "  # Abdominal lame 3 beveled gold (24)
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "  # Empty (16)
    ".. .. .. .. .. .. .. .. ",                         # Empty (8)

    # Row 29
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "BA DA CH DK HL LG MG AG MG AG LG HL DA CH DK CD BA DA CH DK DK CH DA BA "  # Abdominal lame 4
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 30
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "DA CH DK CD LG MG AG BA AG BA MG LG CH DK CD CD DA CH DK CD CD DK CH DA "  # Fauld
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",

    # Row 31
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "DK DK CD CD DA BA DK WH RB RD DK BA DK DK CD CD DK DK CD CD CD CD DK DK "  # Ceremonial gold belt with ruby buckle
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. ",
]

def build_gold_sheet():
    sheet = []
    for row_str in GOLD_SHEET_GRID:
        tokens = row_str.strip().split()
        sheet.append([GOLD_PALETTE[tok] for tok in tokens])
    return sheet

MITHRIL_PALETTE = {
    'SP': (214, 232, 255, 255),  # #d6e8ff Ultra specular silvery starlight glint
    'WH': (132, 164, 211, 255),  # #84a4d3 Light silvery blue / primary highlight
    'HL': ( 88, 130, 192, 255),  # #5882c0 Pale cobalt blue highlight / plate bevel
    'MB': ( 59, 107, 180, 255),  # #3b6bb4 Cerulean cobalt midtone / upper body
    'CB': ( 39,  89, 165, 255),  # #2759a5 Core saturated mithril blue body
    'DB': ( 28,  60, 137, 255),  # #1c3c89 Deep royal cobalt shadow / inner bevel
    'DK': ( 20,  43,  98, 255),  # #142b62 Abyssal midnight navy seam / outline
    'CD': ( 12,  24,  58, 255),  # #0c183a Deepest crevice / inner slit / sole dark
    '..': (0, 0, 0, 0),
}

MITHRIL_SHEET_GRID = [
    # Row 00
    "HL WH SP .. .. .. .. .. .. .. .. .. .. HL MB DB "
    ".. .. .. .. HL WH SP HL HL WH SP HL .. .. .. .. "
    ".. .. .. .. .. .. .. .. DK HL WH SP SP WH HL DK "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",
    # Row 01
    "SP WH HL HL MB MB CB CB CB CB MB MB HL HL WH DK "
    ".. .. .. .. SP WH HL MB SP WH HL MB .. .. .. .. "
    ".. .. .. .. .. .. .. .. HL SP WH MB MB WH SP HL "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",
    # Row 02
    "WH HL MB CB CB DB DB DB DB DB DB CB CB MB HL DK "
    ".. .. .. .. HL MB CB DB HL MB CB DB .. .. .. .. "
    ".. .. .. .. .. .. .. .. WH HL CB DB DB CB HL WH "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",
    # Row 03
    "HL MB CB DB HL WH HL CB CB HL WH HL DB CB MB DK "
    ".. .. .. .. MB CB DB DK MB CB DB DK .. .. .. .. "
    ".. .. .. .. .. .. .. .. MB WH SP WH WH SP WH MB "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",
    # Row 04
    "MB CB DB DB CB MB HL WH WH HL MB CB DB DB CB DK "
    "MB CB DB DK HL WH SP MB HL WH SP MB CB DB DK CD "
    ".. .. .. .. .. .. .. .. MB WH SP WH WH SP WH MB "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",
    # Row 05
    "CB DB DB CB MB HL WH SP SP WH HL MB CB DB DB DK "
    "CB DB DK CD WH HL MB CB WH HL MB CB DB DK CD CD "
    ".. .. .. .. .. .. .. .. WH HL CB DB DB CB HL WH "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",
    # Row 06
    "DB DB CB DB HL WH WH SP SP WH WH HL DB CB DB DK "
    "DB DK CD CD HL MB CB DB HL MB CB DB DK CD CD CD "
    ".. .. .. .. .. .. .. .. HL SP WH MB MB WH SP HL "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",
    # Row 07
    "DB CB HL WH WH WH SP SP SP SP WH WH WH HL CB DK "
    "DK CD CD CD HL SP MB DK HL SP MB DK CD CD CD CD "
    ".. .. .. .. .. .. .. .. DK HL WH SP SP WH HL DK "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",
    # Row 08
    "DB CB MB HL WH WH SP SP SP SP WH WH HL MB CB DK "
    "DK CD CD CD HL SP MB DK HL SP MB DK CD CD CD CD "
    "DK WH HL WH SP WH HL DK WH HL WH SP WH HL WH DK "
    "DK WH HL WH SP WH HL DK DK DB DK DK DK DK DB DK ",
    # Row 09
    "DB DB CB DB HL WH WH SP SP WH WH HL DB CB DB DK "
    "DK CD CD CD HL SP MB DK HL SP MB DK CD CD CD CD "
    "HL WH MB CB CB MB WH HL WH SP WH SP SP WH SP WH "
    "HL WH MB CB CB MB WH HL MB CB DB DK DK DB CB MB ",
    # Row 10
    ".. DB DB CB MB HL WH SP SP WH HL MB CB DB DB .. "
    "DK DB CD CD CD CD CD CD CD CD CD CD DK DB DK CD "
    "WH HL MB CB DB DK DK DK WH HL MB CB DB DK DK DK "
    "WH HL MB CB DB DK DK DK CB DB DK CD CD CD DK DB ",
    # Row 11
    ".. DK DB DB CB MB HL WH WH HL MB CB DB DB DK .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "HL MB CB DB DK DK DK DK HL .. .. SP WH .. .. DB "
    "HL MB CB DB DK DK DK DK DB DK CD CD CD CD DK DK ",
    # Row 12
    ".. .. DK DB CB MB MB HL HL MB MB CB DB DK .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "MB CB DB DK CD CD CD CD MB .. .. WH HL .. .. DK "
    "MB CB DB DK CD CD CD CD DK CD CD CD CD CD CD CD ",
    # Row 13
    ".. .. .. DK DB CB MB CB CB MB CB DB DK .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "CB DB DK CD CD CD CD CD CB .. .. .. .. .. .. DK "
    "CB DB DK CD CD CD CD CD CD CD CD CD CD CD CD CD ",
    # Row 14
    ".. .. .. .. DK DB DB CB CB DB DB DK .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. DK WH HL WH HL DK .. ",
    # Row 15
    ".. .. .. .. .. .. DK DB DB DK .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",
    # Row 16
    ".. .. .. .. HL WH SP HL .. .. .. .. .. .. .. .. "
    ".. .. .. .. HL WH SP HL HL WH SP HL HL WH SP HL "
    "HL WH SP HL .. .. .. .. .. .. .. .. HL WH SP HL "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",
    # Row 17
    ".. .. .. .. SP WH HL MB .. .. .. .. .. .. .. .. "
    ".. .. .. .. SP WH HL MB SP WH HL MB SP WH HL MB "
    "SP WH HL MB .. .. .. .. .. .. .. .. SP WH HL MB "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",
    # Row 18
    ".. .. .. .. HL MB CB DB .. .. .. .. .. .. .. .. "
    ".. .. .. .. HL MB .. .. .. .. CB DB HL MB CB DB "
    "HL MB CB DB .. .. .. .. .. .. .. .. HL MB CB DB "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",
    # Row 19
    ".. .. .. .. MB CB DB DK .. .. .. .. .. .. .. .. "
    ".. .. .. .. MB CB .. .. .. .. DB DK MB CB DB DK "
    "MB CB DB DK .. .. .. .. .. .. .. .. MB CB DB DK "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",
    # Row 20
    "MB CB DB DK WH HL MB CB CB DB DK CD DK CD CD CD "
    "MB CB DB DK WH HL .. .. .. .. HL WH DB DK CD CD "
    "HL SP WH MB MB WH SP HL HL SP WH MB MB WH SP HL "
    "MB CB DB DK DB DK CD CD .. .. .. .. .. .. .. .. ",
    # Row 21
    "CB DB DK CD HL WH SP MB DB DK CD CD CD CD CD CD "
    "CB DB DK CD HL WH SP .. .. SP WH HL DK CD CD CD "
    "SP WH HL MB MB HL WH SP SP WH HL MB MB HL WH SP "
    "CB DB DK CD CD CD CD CD .. .. .. .. .. .. .. .. ",
    # Row 22
    "DB DK CD CD WH SP WH HL DK CD CD CD CD CD CD CD "
    "DB DK CD CD WH SP WH HL HL WH SP WH DK CD CD CD "
    "WH HL CB DB DB CB HL WH WH HL CB DB DB CB HL WH "
    "DB DK CD CD CD CD CD CD .. .. .. .. .. .. .. .. ",
    # Row 23
    "DK CD CD CD HL WH MB CB CD CD CD CD CD CD CD CD "
    "DK CD CD CD HL WH SP WH WH SP WH HL CD CD CD CD "
    "MB CB DB DK DK DB CB MB DK DK DK DK DK DK DK DK "
    "DK DK DK DK DK DK DK DK .. .. .. .. .. .. .. .. ",
    # Row 24
    "HL SP WH HL HL MB CB DB HL WH SP HL DB DK CD CD "
    "DK CD CD CD HL WH SP WH WH SP WH HL CD CD CD CD "
    "HL SP WH MB MB WH SP HL .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",
    # Row 25
    "SP WH HL MB CB DB DK CD CB DB DK CD CD CD CD CD "
    "DB DK CD CD WH SP WH HL HL WH SP WH DK CD CD CD "
    "SP WH HL MB MB HL WH SP .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",
    # Row 26
    "HL WH MB CB HL WH MB CB CB DB DK CD DK CD CD CD "
    "MB CB DB DK HL WH MB CB CB MB WH HL DB DK CD CD "
    "WH HL CB DB DB CB HL WH .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",
    # Row 27
    "WH HL CB DB WH HL CB DB DB DK CD CD CD CD CD CD "
    "CB DB DK CD WH HL SP WH WH SP HL WH DK CD CD CD "
    "CB DB DK CD CD DK DB CB .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",
    # Row 28
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "DB DK CD CD HL WH MB CB CB MB WH HL CD CD CD CD "
    "DB DK CD CD CD CD DK DB .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",
    # Row 29
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "DK CD CD CD MB CB DB DK DK DB CB MB CD CD CD CD "
    "DK CD CD CD CD CD CD DK .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",
    # Row 30
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "CD CD CD CD CB DB DK CD CD DK DB CB CD CD CD CD "
    "CD CD CD CD CD CD CD CD .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",
    # Row 31
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "DK DK CD CD DB CB DK WH SP WH DK CB DB DK CD CD "
    "DK DK CD CD CD CD DK DK .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",
]

def build_mithril_sheet():
    sheet = []
    for row_str in MITHRIL_SHEET_GRID:
        tokens = row_str.strip().split()
        sheet.append([MITHRIL_PALETTE[tok] for tok in tokens])
    return sheet

NETHER_PALETTE = {
    'SP': (255, 218, 196, 255),  # #ffdac4 Searing white-hot volcanic spark apex
    'MP': (226, 115, 113, 255),  # #e27371 Molten incandescent pink-amber core heat
    'MH': (218,  43,  22, 255),  # #da2b16 Blazing incandescent scarlet lava/fire
    'MM': (181,  42,  26, 255),  # #b52a1a Saturated incandescent crimson vein
    'MD': (121,  24,  12, 255),  # #79180c Deep glowing magma ember
    'MS': ( 80,  27,  27, 255),  # #501b1b Smoldering cinder root
    'BP': (106,  96, 110, 255),  # #6a606e Specular basalt stone rim glint
    'BH': ( 76,  68,  78, 255),  # #4c444e Chiseled basalt bevel highlight
    'BM': ( 54,  49,  56, 255),  # #363138 Core basalt dark plate
    'BS': ( 36,  33,  38, 255),  # #242126 Deep basalt shadow
    'BD': ( 22,  21,  23, 255),  # #161517 Deepest obsidian black / crevice / seam
    '..': (  0,   0,   0,   0),
}

NETHER_SHEET_GRID = [
    # Row 00
    "BH BP MH .. .. .. .. .. .. .. .. .. .. MH BP BD "
    ".. .. .. .. BH BP MH BH BH BP MH BH .. .. .. .. "
    ".. .. .. .. .. .. .. .. BD BH BP MH MH BP BH BD "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",
    # Row 01
    "BP MH MM MD BM BS BD BD BD BD BS BM MD MM MH BD "
    ".. .. .. .. BP MH MM BS BP MH MM BS .. .. .. .. "
    ".. .. .. .. .. .. .. .. BH MH MM MD MD MM MH BH "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",
    # Row 02
    "MH MM BM BS BD BD BD BD BD BD BD BD BS BM MM BD "
    ".. .. .. .. BH BM BS BD BH BM BS BD .. .. .. .. "
    ".. .. .. .. .. .. .. .. BP BH BS BD BD BS BH BP "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",
    # Row 03
    "MM BM BS BD BH MM MD BS BS MD MM BH BD BS BM BD "
    ".. .. .. .. BM BS BD BD BM BS BD BD .. .. .. .. "
    ".. .. .. .. .. .. .. .. BS MM MH MM MM MH MM BS "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",
    # Row 04
    "BM BS BD BD BM MM MH MH MH MH MM BM BD BD BS BD "
    "BS BM BD BD BH BP MH BM BH BP MH BM BS BD BD BD "
    ".. .. .. .. .. .. .. .. BM MH MP SP SP MP MH BM "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",
    # Row 05
    "BS BD MM BS MM MH MH MP MP MH MH MM BS MM BD BD "
    "BM BD BD BD BP MH MM BS BP MH MM BS BD BD BD BD "
    ".. .. .. .. .. .. .. .. BP BH BS BD BD BS BH BP "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",
    # Row 06
    "BD BD BS MM MH MH MP SP SP MP MH MH MM BS BD BD "
    "BD BD BD BD BH BM BS BD BH BM BS BD BD BD BD BD "
    ".. .. .. .. .. .. .. .. BH MH MM MD MD MM MH BH "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",
    # Row 07
    "BD BS MM MH MH MP SP SP SP SP MP MH MH MM BS BD "
    "BD BD BD BD BH MH MM BD BH MH MM BD BD BD BD BD "
    ".. .. .. .. .. .. .. .. BD BH BP MH MH BP BH BD "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",
    # Row 08
    "BD BS MD MM MH MP SP SP SP SP MP MH MM MD BS BD "
    "BD BD BD BD BH MH MM BD BH MH MM BD BD BD BD BD "
    "BD BP BH BP MH BP BH BD BP BH BP MH BP BH BP BD "
    "BD BP BH BP MH BP BH BD BD BS BD BD BD BD BS BD ",
    # Row 09
    "BD BD BS MM MH MH MP SP SP MP MH MH MM BS BD BD "
    "BD BD BD BD BH MH MM BD BH MH MM BD BD BD BD BD "
    "BH BP BM BS BS BM BP BH BP MH MH MP MP MH MH BP "
    "BH BP BM BS BS BM BP BH BM BS BD BD BD BD BS BM ",
    # Row 10
    ".. BD MM BS MM MH MH MP MP MH MH MM BS MM BD .. "
    "BD BS BD BD BD BD BD BD BD BD BD BD BD BS BD BD "
    "BP BH BM BS BD BD BD BD BH BP MH MM MM MH BP BH "
    "BP BH BM BS BD BD BD BD BS BM BD BD BD BD BD BS ",
    # Row 11
    ".. BD BS BD BM MM MH MH MH MH MM BM BD BS BD .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "BH BM BS BD BD BD BD BD BH .. .. BP MH .. .. BD "
    "BH BM BS BD BD BD BD BD BS BD BD BD BD BD BD BD ",
    # Row 12
    ".. .. BD BS BM MM MH MH MH MH MM BM BS BD .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "BM BS BD BD BD BD BD BD BM .. .. BH BM .. .. BD "
    "BM BS BD BD BD BD BD BD BD BD BD BD BD BD BD BD ",
    # Row 13
    ".. .. .. BD BS BM MM MM MM MM BM BS BD .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "BS BD BD BD BD BD BD BD BS .. .. .. .. .. .. BD "
    "BS BD BD BD BD BD BD BD BD BD BD BD BD BD BD BD ",
    # Row 14
    ".. .. .. .. BD BS BM BM BM BM BS BD .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. BD BP BH MH BH BD .. ",
    # Row 15
    ".. .. .. .. .. .. BD BS BS BD .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",
    # Row 16
    ".. .. .. .. BH BP MH BH .. .. .. .. .. .. .. .. "
    ".. .. .. .. BH BP MH BH BH BP MH BH BH BP MH BH "
    "BH BP MH BH .. .. .. .. .. .. .. .. BH BP MH BH "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",
    # Row 17
    ".. .. .. .. BP MH MM BS .. .. .. .. .. .. .. .. "
    ".. .. .. .. BP MH MM BS BP MH MM BS BP MH MM BS "
    "BP MH MM BS .. .. .. .. .. .. .. .. BP MH MM BS "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",
    # Row 18
    ".. .. .. .. BH BM BS BD .. .. .. .. .. .. .. .. "
    ".. .. .. .. BH BM .. .. .. .. BS BD BH BM BS BD "
    "BH BM BS BD .. .. .. .. .. .. .. .. BH BM BS BD "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",
    # Row 19
    ".. .. .. .. BM BS BD BD .. .. .. .. .. .. .. .. "
    ".. .. .. .. BM BS .. .. .. .. BD BD BM BS BD BD "
    "BM BS BD BD .. .. .. .. .. .. .. .. BM BS BD BD "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",
    # Row 20
    "BM BS BD BD BP BH BM BS BS BD BD BD BD BD BD BD "
    "BM BS BD BD BP BH .. .. .. .. BH BP BD BD BD BD "
    "BH MH MM BS BS MM MH BH BH MH MM BS BS MM MH BH "
    "BM BS BD BD BD BD BD BD .. .. .. .. .. .. .. .. ",
    # Row 21
    "BS BD BD BD BH MH MM BS BD BD BD BD BD BD BD BD "
    "BS BD BD BD BH MH MM .. .. MM MH BH BD BD BD BD "
    "MH MP SP MM MM SP MP MH MH MP SP MM MM SP MP MH "
    "BS BD BD BD BD BD BD BD .. .. .. .. .. .. .. .. ",
    # Row 22
    "BD BD BD BD BP MH MM BH BD BD BD BD BD BD BD BD "
    "BD BD BD BD BP MH MM BH BH MM MH BP BD BD BD BD "
    "BP BH BS BD BD BS BH BP BP BH BS BD BD BS BH BP "
    "BD BD BD BD BD BD BD BD .. .. .. .. .. .. .. .. ",
    # Row 23
    "BD BD BD BD BH MH MM BM BD BD BD BD BD BD BD BD "
    "BD BD BD BD BH MH MP MM MM MP MH BH BD BD BD BD "
    "BM BS BD BD BD BD BS BM BD BD BD BD BD BD BD BD "
    "BD BD BD BD BD BD BD BD .. .. .. .. .. .. .. .. ",
    # Row 24
    "BH MH MM BH BH BM BS BD BH MH MM BH BD BD BD BD "
    "BD BD BD BD MH MP SP MP MP SP MP MH BD BD BD BD "
    "BH MH MM BS BS MM MH BH .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",
    # Row 25
    "MH MP MM BS BM BS BD BD BM BS BD BD BD BD BD BD "
    "BD BD BD BD BP MH MM BH BH MM MH BP BD BD BD BD "
    "MH MP SP MM MM SP MP MH .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",
    # Row 26
    "BH MH MM BM BH MH MM BM BS BD BD BD BD BD BD BD "
    "BM BS BD BD BH MH MM BM BM MM MH BH BD BD BD BD "
    "BP BH BS BD BD BS BH BP .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",
    # Row 27
    "BP MH BS BD BP MH BS BD BD BD BD BD BD BD BD BD "
    "BS BD BD BD BP BH MH MM MM MH BH BP BD BD BD BD "
    "BS BD BD BD BD BD BD BS .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",
    # Row 28
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "BD BD BD BD BH MM MH MP MP MH MM BH BD BD BD BD "
    "BD BD BD BD BD BD BD BD .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",
    # Row 29
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "BD BD BD BD BM BS MM MH MH MM BS BM BD BD BD BD "
    "BD BD BD BD BD BD BD BD .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",
    # Row 30
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "BD BD BD BD BS BM BS MM MM BS BM BS BD BD BD BD "
    "BD BD BD BD BD BD BD BD .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",
    # Row 31
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "BD BD BD BD BD BS BM MH MH BM BS BD BD BD BD BD "
    "BD BD BD BD BD BD BD BD .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",
]

def build_nether_sheet():
    sheet = []
    for row_str in NETHER_SHEET_GRID:
        tokens = row_str.strip().split()
        sheet.append([NETHER_PALETTE[tok] for tok in tokens])
    return sheet

STEEL_PALETTE = {
    'SP': (246, 250, 254, 255),  # #f6fafe Specular apex glint / rivet highlight / visor glint
    'WH': (222, 232, 238, 255),  # #dee8ee High-polish steel highlight / top bevel rim
    'BH': (194, 206, 212, 255),  # #c2ced4 Bright brushed steel / inner bevel
    'MH': (164, 176, 184, 255),  # #a4b0b8 Polished steel plate face
    'MM': (134, 146, 154, 255),  # #86929a Core steel midtone
    'MS': (106, 118, 126, 255),  # #6a767e Shaded steel plate / ambient shadow
    'DS': ( 78,  90,  98, 255),  # #4e5a62 Deep steel shadow / lower bevel
    'DB': ( 54,  64,  72, 255),  # #364048 Dark recessed steel groove / plate under-edge
    'DK': ( 34,  40,  46, 255),  # #22282e Steel plate seam / crevice / outline
    'CD': ( 18,  22,  26, 255),  # #12161a Deepest crease / visor slit / sole bottom
    'OH': (154, 172, 178, 255),  # #9aacb2 Outer frame light bevel (cool slate-steel)
    'OM': (110, 126, 132, 255),  # #6e7e84 Outer frame midtone
    'OD': ( 52,  62,  68, 255),  # #343e44 Outer frame dark shadow
    'LT': ( 58,  44,  36, 255),  # #3a2c24 Dark leather strap / under-arm lining
    'BK': (196, 164,  92, 255),  # #c4a45c Brass/bronze buckle accent / strap pin
    '..': (  0,   0,   0,   0),  # Transparent
}

STEEL_SHEET_GRID = [
    # Row 00
    "OH SP WH .. .. .. .. .. .. .. .. .. .. OM OD DK "  # Shield top corners (0..15: cols 0..2 & 13..15)
    ".. .. .. .. OH WH SP WH BH OM OD DK .. .. .. .. "  # Boots top cuff (16..31: cols 20..27)
    ".. .. .. .. .. .. .. .. DK OH WH SP SP WH OM DK .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ", # Helmet crown back (32..63: cols 40..47)

    # Row 01
    "SP WH BH OH OH OM OM OM OM OM OM OM OM OD DB DK "  # Shield upper outer frame
    ".. .. .. .. OH BH MH MM MM MS DS DK .. .. .. .. "  # Boots cuff inner
    ".. .. .. .. .. .. .. .. OH WH SP WH WH SP WH OM .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 02
    "WH BH DK DK DK DK DK DK DK DK DK DK DK DK DS DK "  # Shield upper dark crevice groove
    ".. .. .. .. MH MM MM MS DS DB DK CD .. .. .. .. "
    ".. .. .. .. .. .. .. .. OH WH SP SP SP SP WH OM .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 03
    "WH DK WH WH WH WH WH WH WH WH WH WH WH DS DB DK "  # Shield inner top bevel highlight
    ".. .. .. .. MM MM MS DS DB DK DK CD .. .. .. .. "
    ".. .. .. .. .. .. .. .. BH WH SP SP SP SP WH MM .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 04
    "WH DK WH BH MH MM MM MM MM MH BH WH SP DS DB DK "  # Shield diagonal sheen beam (10..12)
    "OH WH BH OM OH SP WH BH MM OM OD DK OM OD DK CD "  # Boots ankle joint cuff (16..31 full)
    ".. .. .. .. .. .. .. .. BH MH WH SP SP WH MH MM .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 05
    "WH DK WH MH MM MM MM MM MH BH WH SP BH DS DB DK "  # Shield diagonal sheen beam (9..11)
    "OH BH MH MM OH BH MH MM MM MS DS DK OM OD DK CD "  # Boots upper shin
    ".. .. .. .. .. .. .. .. MH MM WH SP SP WH MM MS .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 06
    "BH DK WH MM MM MM MM MH BH WH SP BH MM DS DB DK "  # Shield diagonal sheen beam (8..10)
    "OH BH MH MM OH SP MH MM MM MS DS DK OM OD DK CD "  # Boots shin with rivet
    ".. .. .. .. .. .. .. .. MM MS BH WH WH BH MS DS .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 07
    "BH DK WH MM MM MM MH BH WH SP BH MM MM DS DB DK "  # Shield diagonal sheen beam (7..9)
    "OH MH MM MS OH BH MM MS MS DS DB DK OD DK CD CD "  # Boots lower shin
    ".. .. .. .. .. .. .. .. MS DS MM BH BH MM DS DB .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 08
    "BH DK WH MM MM MH BH WH SP BH MM MM MM DS DB DK "  # Shield diagonal sheen beam (6..8)
    "OH MH MM MS OH SP MH MM MS DS DB DK OD DK CD CD "  # Boots instep
    "DK OH WH BH MM MS DS DK DK SP WH BH MM MS DS DK DK OH WH BH MM MS DS DK DK BH MM MS DS DB DK DK ", # Helmet brow band (32..63: 32 active)

    # Row 09
    "MH DK WH MM MH BH WH SP BH MM MM MM MM DS DB DK "  # Shield diagonal sheen beam (5..7)
    "OH MM MS DS WH BH MM MS DS DB DK CD OD DK CD CD "  # Boots ball of foot
    "DK WH BH SP WH MM MS DK WH SP SP WH BH MM MS DK DK WH BH SP WH MM MS DK DK MM MS DS DB DK CD CD ", # Helmet visor roof / brow

    # Row 10
    ".. DK WH MH BH WH SP BH MM MM MM DS DS DB DK .. "  # Shield diagonal sheen beam (cols 1..14)
    "OH MM MS DS WH SP WH MM MS DS DB DK OD DK CD CD "  # Boots toe cap + sole
    "DK BH MH MM MS DS DB DK CD CD CD DK DK CD CD DK DK BH MH MM MS DS DB DK DK MS DS DB DK CD CD CD ", # Helmet visor slit with nasal bridge

    # Row 11
    ".. DK WH BH WH SP BH MM MM MM DS DS DS DB DK .. "  # Shield diagonal sheen beam (cols 1..14)
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "DK MM MS DS DB DK DK DK WH .. .. BH WH .. .. DK DK MM MS DS DB DK DK DK DK DS DB DK CD CD CD CD ", # Helmet cheeks & breath openings

    # Row 12
    ".. .. DK WH SP BH MM MM MM DS DS DS DB DK .. .. "  # Shield lower left diagonal beam (cols 2..13)
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "DK MS DS DB DK DK CD CD WH .. .. SP MM .. .. DK DK MS DS DB DK DK CD CD DK DB DK CD CD CD CD CD ", # Helmet visor lower keel

    # Row 13
    ".. .. .. DK WH BH MM MM DS DS DS DB DK .. .. .. "  # Shield lower taper (cols 3..12)
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "DK DS DB DK CD CD CD CD WH .. .. .. .. .. .. DK DK DS DB DK CD CD CD CD DK DK CD CD CD CD CD CD ", # Helmet chin apex

    # Row 14
    ".. .. .. .. DK WH BH MM DS DS DB DK .. .. .. .. "  # Shield tip bevel (cols 4..11)
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. DK OH WH BH OM DK .. ", # Helmet lower back neck lames

    # Row 15
    ".. .. .. .. .. .. DK WH DS DK .. .. .. .. .. .. "  # Shield reinforced tip apex
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 16
    ".. .. .. .. OH WH BH OM .. .. .. .. .. .. .. .. "  # Leggings right hip (cols 4..7)
    ".. .. .. .. DK OH WH BH BH WH OH DK DK OH WH DK "  # Chestplate gorget / collar (cols 20..31 active)
    "DK OH WH BH .. .. .. .. .. .. .. .. OH WH BH DK .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ", # Shoulder caps (cols 32..35 & 44..47 active)

    # Row 17
    ".. .. .. .. WH SP MH OM .. .. .. .. .. .. .. .. "
    ".. .. .. .. OH WH SP WH WH SP WH OM OH WH SP OM "  # Chestplate upper collar bevel
    "OH WH SP BH .. .. .. .. .. .. .. .. WH SP WH OD .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 18
    ".. .. .. .. BH MH MM OD .. .. .. .. .. .. .. .. "
    ".. .. .. .. WH BH .. .. .. .. BH OM OH BH MH OD "  # Neck opening (cols 22..25 empty)
    "BH MH MM OD .. .. .. .. .. .. .. .. BH MM MS DK .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 19
    ".. .. .. .. MM MS DS DK .. .. .. .. .. .. .. .. "
    ".. .. .. .. BH OM .. .. .. .. OM OD BH MH MM DK "
    "MM MS DS DK .. .. .. .. .. .. .. .. MM DS DB DK .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 20
    "OH WH BH OM OM OD DK CD OH WH BH OM OM OD DK CD "  # Leggings thighs top (cols 0..15 active)
    "DK OH WH BH MH MM .. .. .. .. BH MH MM MS OD DK "  # Chestplate collar rim (cols 16..21 & 26..31 active)
    "DK OH WH BH MH MM MS DK DK OH WH BH MH MM MS DK OH WH BH MM MS DS DB DK .. .. .. .. .. .. .. .. ", # Chest back + pauldrons (32..55 active)

    # Row 21
    "WH SP MH MM MS DS DB DK WH SP MH MM MS DS DB DK "
    "OH WH SP BH MH MM MS .. .. MS MH MM BH SP WH OD "  # Breastplate upper collar & keel start
    "DK WH SP BH MH MM MS DK DK WH SP BH MH MM MS DK WH SP BH MH MM MS DS DK .. .. .. .. .. .. .. .. ",

    # Row 22
    "BH MH MM MS DS DB DK CD BH MH MM MS DS DB DK CD "  # Leggings mid-thigh
    "DK OH WH SP WH MM MS OD DK OH WH SP MM MS OD DK "  # Breastplate central keel ridge at col 23..24
    "DK BH MH MM MS DS DB DK DK BH MH MM MS DS DB DK BH MH MM MS DS DB DK CD .. .. .. .. .. .. .. .. ",

    # Row 23
    "MH MM MS DS DB DK DK CD MH MM MS DS DB DK DK CD "
    "OH WH BH SP WH MM MS DS OH WH BH MM MS DS DB DK "  # Diagonal brushed highlight across chest
    "DK MM MS DS DB DK CD CD DK MM MS DS DB DK CD CD MM MS DS DB DK CD CD CD .. .. .. .. .. .. .. .. ",

    # Row 24
    "OH WH SP BH MM MS DS DK OH WH SP BH MM MS DS DK "  # Leggings knee cop top
    "OH BH MH SP WH MS DS DB OH BH MM MS MS DS DB DK "  # Chestplate plackart
    "DK OH WH BH MM MS DS DK .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ", # Backplate upper spine (cols 32..39 active)

    # Row 25
    "WH SP WH MH MM DS DB DK WH SP WH MH MM DS DB DK "  # Leggings knee cop boss + specular
    "OH BH SP WH MH MS DS DB OH BH MH MM MS DS DB DK "  # Diagonal brushed highlight across chest
    "DK WH SP WH MM MS DS DK .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 26
    "BH MH MM MS DS DB DK CD BH MH MM MS DS DB DK CD "  # Leggings knee cop lower bevel
    "OH MH MM MM MS DS DB DK OH MH MM MM MS DS DB DK "
    "DK BH MH MM MS DS DB DK .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 27
    "MM MS DS DB DK DK CD CD MM MS DS DB DK DK CD CD "  # Leggings greave / shin
    "DK OH BH MH MM MS DS DK DK OH BH MM MS DS DB DK "  # Plackart lower rim with side rivets
    "DK MM MS DS DB DK CD CD .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 28
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "DK DB DS MH SP MH DS DK DK DB DS MH SP MH DS DK "  # Tempered steel harness belt with polished buckle
    "DK DB DS MH SP MH DS DK .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 29
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "DK OH WH BH BH WH OH DK DK OH WH BH BH WH OH DK "  # Fauld lame 1 top bevel
    "DK OH WH BH BH WH OH DK .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 30
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "OH WH SP MH MM SP WH OD OH WH SP MH MM SP WH OD "  # Fauld lame 1 body with rivets
    "OH WH SP MH MM SP WH OD .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 31
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "DK OM MS DS DS MS OD DK DK OM MS DS DS MS OD DK "  # Fauld lame 1 lower rim shadow
    "DK OM MS DS DS MS OD DK .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",
]

def build_steel_sheet():
    sheet = []
    for row_str in STEEL_SHEET_GRID:
        tokens = row_str.strip().split()
        sheet.append([STEEL_PALETTE[tok] for tok in tokens])
    return sheet

# -------------------------------------------------------------------------
# WOOD PALETTE & CHARACTER SHEET
# Reference-accurate warm golden-amber oak planks with rich grain swirls,
# beveled plank seams, dark crevice grooves, and forged iron reinforcement bands/rivets.
# -------------------------------------------------------------------------
WOOD_PALETTE = {
    # Reference Wood Tones (Warm golden-amber oak planks with rich grain swirls)
    "SP": (244, 218, 178, 255),  # #f4dab2 Specular wood glint / sunlit grain apex
    "WH": (218, 178, 134, 255),  # #dab286 Bright golden-amber plank top bevel highlight
    "BH": (192, 150, 108, 255),  # #c0966c Warm honey-oak plank face
    "MH": (164, 122,  84, 255),  # #a47a54 Primary rich oak heartwood
    "MM": (136,  98,  66, 255),  # #886242 Core medium wood midtone
    "MS": (108,  76,  50, 255),  # #6c4c32 Shaded wood grain / knot ring
    "DS": ( 84,  58,  38, 255),  # #543a26 Deep wood shadow / plank lower bevel
    "DB": ( 60,  40,  26, 255),  # #3c281a Dark recessed wood groove / seam between planks
    "DK": ( 38,  26,  18, 255),  # #261a12 Darkest plank boundary / wood crevice / outline
    "CD": ( 22,  14,  10, 255),  # #160e0a Deepest crease / visor slit / sole bottom

    # Timber Frame / Structural Tones
    "OB": (116,  84,  58, 255),  # #74543a Outer vertical frame beam highlight
    "OD": ( 72,  50,  34, 255),  # #483222 Outer vertical frame shadow

    # Forged Iron / Steel Reinforcements
    "IH": (230, 238, 244, 255),  # #e6eef4 Brightest forged iron highlight / crest apex
    "IR": (196, 208, 216, 255),  # #c4d0d8 Forged iron highlight / rivet dome
    "IS": (142, 154, 164, 255),  # #8e9aa4 Forged iron midtone
    "ID": ( 84,  94, 102, 255),  # #545e66 Forged iron shadow
    "IB": ( 44,  52,  58, 255),  # #2c343a Forged iron dark crevice
    "IK": ( 24,  30,  34, 255),  # #181e22 Darkest forged iron rim outline
    "LT": ( 74,  46,  30, 255),  # #4a2e1e Dark leather harness strap / backing
    "..": (  0,   0,   0,   0),  # Transparent
}

WOOD_SHEET_GRID = [
    # Row 00
    "IH IR IS .. .. .. .. .. .. .. .. .. .. IS ID IK "  # Shield top corners (0..15)
    ".. .. .. .. DK WH BH MM MH DS DB DK .. .. .. .. "  # Boots top cuff (16..31: cols 20..27)
    ".. .. .. .. .. .. .. .. DK OB WH SP SP WH OD DK .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ", # Helmet crown back (32..63: cols 40..47)

    # Row 01
    "IR IS ID IH IH IS IS IS IS IS IS ID ID IB IK IK "  # Shield arched iron top band
    ".. .. .. .. OB WH BH MM MM MS DS DK .. .. .. .. "  # Boots cuff inner
    ".. .. .. .. .. .. .. .. OB WH SP WH WH SP WH OD .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 02
    "IR ID IB IB IB IB IB IB IB IB IB IB IB IB ID IK "  # Shield iron inner rim groove
    ".. .. .. .. MH MM MM MS DS DB DK CD .. .. .. .. "
    ".. .. .. .. .. .. .. .. OB WH SP SP SP SP WH OD .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 03
    "IR IB WH WH WH WH WH WH WH WH WH WH WH DS IB IK "  # Shield plank 1 top bevel (golden oak)
    ".. .. .. .. MM MM MS DS DB DK DK CD .. .. .. .. "
    ".. .. .. .. .. .. .. .. BH WH SP SP SP SP WH MM .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 04
    "IR IB WH BH BH IR IS MH BH WH IR IS MH DS IB IK "  # Shield plank 1 face with iron rivets at 4 & 11
    "DK WH BH MM DK IR IS IR MH MM DS DK OD DB DK CD "  # Boots ankle joint with iron rivet
    ".. .. .. .. .. .. .. .. BH MH WH SP SP WH MH MM .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 05
    "IS IB WH BH MH MM MS DB DS MM MH BH SP DS IB IK "  # Shield plank 1 knot swirl apex & sunlit gleam
    "DK BH MH MM DK BH MH MM MM MS DS DK OD DB DK CD "  # Boots upper shin
    ".. .. .. .. .. .. .. .. MH MM WH SP SP WH MM MS .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 06
    "IS IB WH BH MH MS DB CD DB MS MH BH MH DS IB IK "  # Shield plank 1 knot core with deep ring
    "DK BH MH MM DK IR IS MM MM MS DS DK OD DB DK CD "  # Boots shin with iron rivet
    ".. .. .. .. .. .. .. .. MM MS BH WH WH BH MS DS .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 07
    "IS IB WH BH MH MM MS DB DS MM MH BH MH DS IB IK "  # Shield plank 1 knot swirl bottom
    "DK MH MM MS DK BH MM MS MS DS DB DK OD DK CD CD "  # Boots lower shin
    ".. .. .. .. .. .. .. .. MS DS MM BH BH MM DS DB .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 08
    "IS IB WH BH IR IS MM MS DS MM IR IS MH DS IB IK "  # Shield plank 1 lower face with iron rivets
    "DK MH MM MS DK IR IS MM MS DS DB DK OD DK CD CD "  # Boots instep with iron stud
    "DK OB WH BH MM MS DS DK DK IR IS IR MM MS DS DK DK OB WH BH MM MS DS DK DK BH MM MS DS DB DK DK ", # Helmet brow band with iron rivets (32..63: 32 active)

    # Row 09
    "IS IB DB DB DS DB DB DB DB DB DS DB DB DS IB IK "  # Shield plank seam 1-2 (contained in rim)
    "OB MM MS DS WH BH MM MS DS DB DK CD OD DK CD CD "  # Boots ball of foot
    "DK WH BH SP WH MM MS DK IR IS ID IS IR MM MS DK DK WH BH SP WH MM MS DK DK MM MS DS DB DK CD CD ", # Helmet visor brow with iron band

    # Row 10
    ".. IB WH WH WH WH WH WH WH WH WH WH WH DS IB .. "  # Shield plank 2 top bevel (cols 1..14)
    "OB MM MS DS WH SP WH MM MS DS DB DK OD DK CD CD "  # Boots toe cap + sole
    "DK BH MH MM MS DS DB DK CD CD CD DK DK CD CD DK DK BH MH MM MS DS DB DK DK MS DS DB DK CD CD CD ", # Helmet visor slit with timber nasal bridge

    # Row 11
    ".. IB WH BH IR IS MM MM MS DS IR IS BH DS IB .. "  # Shield plank 2 face with iron rivets
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "DK MM MS DS DB DK DK DK WH .. .. BH WH .. .. DK DK MM MS DS DB DK DK DK DK DS DB DK CD CD CD CD ", # Helmet cheeks & breath openings

    # Row 12
    ".. .. IB WH BH MH MM MS DB DS MM MH DS IB .. .. "  # Shield plank 2 lower (cols 2..13)
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "DK MS DS DB DK DK CD CD WH .. .. SP MM .. .. DK DK MS DS DB DK DK CD CD DK DB DK CD CD CD CD CD ", # Helmet visor lower keel

    # Row 13
    ".. .. .. IB WH BH MH MM DS DB DS DS IB .. .. .. "  # Shield plank 2 lower taper (cols 3..12)
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "DK DS DB DK CD CD CD CD WH .. .. .. .. .. .. DK DK DS DB DK CD CD CD CD DK DK CD CD CD CD CD CD ", # Helmet chin apex

    # Row 14
    ".. .. .. .. IB WH BH MM DS DB DS IB .. .. .. .. "  # Shield plank 2 tip (cols 4..11)
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. DK OB WH BH OD DK .. ", # Helmet lower back neck lames (cols 57..62)

    # Row 15
    ".. .. .. .. .. .. IB IS ID IK .. .. .. .. .. .. "  # Shield reinforced iron chape apex (cols 6..9)
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 16
    ".. .. .. .. OB WH BH OD .. .. .. .. .. .. .. .. "  # Leggings right hip (cols 4..7)
    ".. .. .. .. DK OB WH BH BH WH OB DK DK OB WH DK "  # Chestplate gorget / collar (cols 20..31 active)
    "DK OB WH BH .. .. .. .. .. .. .. .. OB WH BH DK .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ", # Shoulder caps (cols 32..35 & 44..47 active)

    # Row 17
    ".. .. .. .. WH SP MH OD .. .. .. .. .. .. .. .. "
    ".. .. .. .. OB WH SP WH WH SP WH OD OB WH SP OD "  # Chestplate upper collar bevel
    "OB WH SP BH .. .. .. .. .. .. .. .. WH SP WH OD .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 18
    ".. .. .. .. BH MH MM OD .. .. .. .. .. .. .. .. "
    ".. .. .. .. BH MH .. .. .. .. MH MM BH MH MM OD "  # Collar neck cutout (cols 22..25 empty)
    "BH MH MM MS .. .. .. .. .. .. .. .. BH MH MM MS .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 19
    ".. .. .. .. MM MS DS DK .. .. .. .. .. .. .. .. "
    ".. .. .. .. BH OD .. .. .. .. OD DK BH MH MM DK "
    "MM MS DS DK .. .. .. .. .. .. .. .. MM DS DB DK .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 20
    "OB WH BH MM MS DS DB DK OB WH BH MM MS DS DB DK "  # Leggings thighs top splints (cols 0..15 active)
    "DK OB WH BH MH MM .. .. .. .. BH MH MM MS OD DK "  # Chestplate collar rim (cols 16..21 & 26..31 active)
    "DK OB WH BH MH MM MS DK DK OB WH BH MH MM MS DK OB WH BH MM MS DS DB DK .. .. .. .. .. .. .. .. ", # Chest back + pauldrons (32..55 active)

    # Row 21
    "WH SP MH MM MS DS DB DK WH SP MH MM MS DS DB DK "
    "OB WH SP BH MH MM MS .. .. MS MH MM BH SP WH OD "  # Breastplate plank 1 top bevel & keel
    "DK WH SP BH MH MM MS DK DK WH SP BH MH MM MS DK WH SP BH MH MM MS DS DK .. .. .. .. .. .. .. .. ",

    # Row 22
    "BH MH MM MS DS DB DK CD BH MH MM MS DS DB DK CD "  # Leggings mid-thigh splints
    "DK OB WH SP WH MM MS OD DK OB WH SP MM MS OD DK "  # Breastplate plank 1 heartwood with central keel
    "DK BH MH MM MS DS DB DK DK BH MH MM MS DS DB DK BH MH MM MS DS DB DK CD .. .. .. .. .. .. .. .. ",

    # Row 23
    "MH MM MS DS DB DK DK CD MH MM MS DS DB DK DK CD "
    "OB WH BH DB DS MM MS OD OB WH BH DB DS MM MS OD "  # Breastplate plank 1 lower grain & subtle seam
    "DK MM MS DS DB DK CD CD DK MM MS DS DB DK CD CD MM MS DS DB DK CD CD CD .. .. .. .. .. .. .. .. ",

    # Row 24
    "OB WH IR IS MM MS DS DK OB WH IR IS MM MS DS DK "  # Leggings knee cop with iron rivet stud
    "OB WH BH MH MM MS DS DB OB WH BH MM MS MS DS DK "  # Breastplate plank 2 top bevel (bright amber)
    "DK OB WH BH MM MS DS DK .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ", # Backplate upper spine (cols 32..39 active)

    # Row 25
    "WH SP IR ID MM DS DB DK WH SP IR ID MM DS DB DK "  # Leggings knee cop boss + iron rivet
    "OB BH SP WH MH MS DS DB OB BH MH MM MS DS DB DK "  # Breastplate plank 2 heartwood with grain swirl
    "DK WH SP WH MM MS DS DK .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 26
    "BH MH MM MS DS DB DK CD BH MH MM MS DS DB DK CD "  # Leggings knee cop lower bevel
    "OB MM DS DB DS DS DB OD OB MM DS DB DS DS DB OD "  # Breastplate plank 2 lower grain & subtle seam
    "DK BH MH MM MS DS DB DK .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 27
    "MM MS DS DB DK DK CD CD MM MS DS DB DK DK CD CD "  # Leggings greave splints on shins
    "DK OB BH MH MM MS DS DK DK OB BH MM MS DS DB DK "  # Lower plackart plank with iron side rivets
    "DK MM MS DS DB DK CD CD .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 28
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "DK LT LT IS IR IS LT DK DK LT LT IS IR IS LT DK "  # Leather harness belt with iron buckle
    "DK LT LT IS IR IS LT DK .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 29
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "DK OB WH BH BH WH OB DK DK OB WH BH BH WH OB DK "  # Wooden fauld slat top bevel
    "DK OB WH BH BH WH OB DK .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 30
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "OB WH IR MH MM IR WH OD OB WH IR MH MM IR WH OD "  # Wooden fauld slat body with iron rivets
    "OB WH IR MH MM IR WH OD .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 31
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "DK OD MS DS DS MS OD DK DK OD MS DS DS MS OD DK "  # Wooden fauld slat lower rim shadow
    "DK OD MS DS DS MS OD DK .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",
]

def build_wood_sheet():
    sheet = []
    for row_str in WOOD_SHEET_GRID:
        tokens = row_str.strip().split()
        sheet.append([WOOD_PALETTE[tok] for tok in tokens])
    return sheet

ADMIN_PALETTE = {
    # Specular / Apex Highlights
    'SP': (255, 255, 255, 255),  # Pure celestial star gleam / diamond apex
    'WH': (244, 252, 254, 255),  # Ultra-light pearl / top bevel highlight

    # Reference Block Prismatic Iridescence (exact 5 colors from media_1791471196347.png)
    'CY': (212, 243, 252, 255),  # Luminous ethereal cyan / ice white (#d4f3fc)
    'MT': (201, 240, 229, 255),  # Soft prismatic seafoam / mint green (#c9f0e5)
    'BL': (219, 234, 252, 255),  # Prismatic celestial sky blue (#dbeafc)
    'PW': (204, 195, 221, 255),  # Shimmering periwinkle / soft orchid (#ccc3dd)
    'LV': (192, 170, 191, 255),  # Delicate divine lilac / mauve lavender (#c0aabf)

    # Shaded / Twilight Harmonics (deepened wave colors preserving iridescent flow)
    'BC': (172, 212, 226, 255),  # Shaded ethereal cyan / soft azure (#acd4e2)
    'BM': (160, 206, 190, 255),  # Shaded seafoam mint (#a0cebe)
    'BB': (170, 194, 226, 255),  # Shaded celestial sky blue (#aac2e2)
    'BP': (168, 154, 194, 255),  # Shaded periwinkle / soft violet (#a89ac2)
    'BV': (156, 132, 158, 255),  # Shaded mauve lavender (#9c849e)

    # Plate Depth, Crevices & Dimensional Borders
    'SH': (128, 106, 136, 255),  # Soft celestial amethyst shadow (#806a88)
    'DS': ( 92,  72, 102, 255),  # Deep amethyst plate shadow (#5c4866)
    'DB': ( 64,  48,  74, 255),  # Rich obsidian amethyst crevice (#40304a)
    'DK': ( 36,  26,  46, 255),  # Dark silhouette outline / armor border (#241a2e)
    'CD': ( 22,  16,  30, 255),  # Deepest occlusion slit / inner contour (#16101e)

    # Celestial Star / Divine Gold Accents
    'GL': (255, 242, 150, 255),  # Radiant divine star highlight (#fff296)
    'GO': (240, 194,  48, 255),  # Pure celestial gold filigree (#f0c230)
    'GD': (176, 128,  26, 255),  # Deep antique gold shadow (#b0801a)

    # Divine Cyan Pulse (Admin Visor & Star Core)
    'CR': ( 72, 230, 248, 255),  # Radiant divine cyan neon (#48e6f8)
    'CW': (200, 250, 255, 255),  # White-hot cyan core (#c8faff)

    '..': EMPTY,
}

ADMIN_SHEET_GRID = [
    # Row 00
    "WH SP CY .. .. .. .. .. .. .. .. .. .. BP DS DK "  # Shield top corners (0..15)
    ".. .. .. .. DK WH CY MT BL PW DS DK .. .. .. .. "  # Boots top cuff (16..31: cols 20..27)
    ".. .. .. .. .. .. .. .. DK WH SP CY MT BL DS DK .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ", # Helmet crown back (32..63: cols 40..47)

    # Row 01
    "SP WH CY MT BL PW LV BC BM BP BV SH DS DB DK DK "  # Shield arched top rim
    ".. .. .. .. WH SP CY MT BL PW LV DS .. .. .. .. "  # Boots cuff inner
    ".. .. .. .. .. .. .. .. WH SP CY MT BL PW LV BP .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 02
    "SP WH CY MT BL PW LV BC BM BP BV SH DS DB DK DK "  # Shield upper plate diagonal wave
    ".. .. .. .. SP CY MT BL PW LV BP BV .. .. .. .. "
    ".. .. .. .. .. .. .. .. SP WH CY MT BL PW BP BV .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 03
    "SP CY MT BL PW LV CY MT BC BM BP BV SH DS DB DK "  # Shield wave
    ".. .. .. .. CY MT BL PW LV BP BV SH .. .. .. .. "
    ".. .. .. .. .. .. .. .. WH CY MT BL PW BP BV SH .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 04
    "CY MT BL PW LV GL GO GD BC BM BP BV SH DS DB DK "  # Shield wave with top of celestial star
    "DK WH CY MT DK GL GO GD BL PW DS DK DS DB DK CD "  # Boots ankle joint with gold star rivet
    ".. .. .. .. .. .. .. .. CY MT BL PW BP BV SH DS .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 05
    "MT BL PW LV GL GO SP GO GL BP BV SH DS DB DK DK "  # Shield star upper rays & core apex (cols 4..8)
    "DK CY MT BL DK CY MT BL PW LV DS DK DS DB DK CD "  # Boots upper shin
    ".. .. .. .. .. .. .. .. MT BL PW BP BV SH DS DB .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 06
    "BL PW LV GL GO SP CW CW SP GO GL BV SH DS DB DK "  # Shield star horizontal core (cols 3..9)
    "DK MT BL PW DK GL GO GD PW LV SH DK DS DB DK CD "  # Boots shin with star stud
    ".. .. .. .. .. .. .. .. BL PW BP BV SH DS DB DK .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 07
    "PW LV GL GO SP CW CR CR CW SP GO GL SH DS DB DK "  # Shield celestial star core pulse
    "DK BL PW LV DK MT BL PW LV SH DS DK DS DB DK CD "  # Boots lower shin
    ".. .. .. .. .. .. .. .. DK PW BV SH DS DB DK CD .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 08
    "LV CY MT GL GO SP CW CW SP GO GL BV SH DS DB DK "  # Shield star lower rays
    "DK PW LV SH DK GL GO GD SH DS DB DK DS DB DK CD "  # Boots instep with star stud
    "DK WH CY MT BL PW DS DK GO GL GO SP SP GO GL GO DK WH CY MT BL PW DS DK DK PW LV BV SH DS DB DK ", # Helmet brow band with central gold star jewel (32..63: 32 active)

    # Row 09
    "CY MT BL PW LV GD GO GL GD BC BP BV SH DS DB DK "  # Shield star bottom ray
    "WH CY MT BL PW LV SH DS DS DB DK CD DS DK CD CD "  # Boots ball of foot
    "DK WH SP CY MT BL PW DK DK GO GL SP SP GL GO DK DK WH SP CY MT BL PW DK DK BL PW LV BV SH DB CD ", # Helmet visor brow with radiant gem

    # Row 10
    ".. DK CY MT BL PW LV BC BM BP BV SH DS DB DK .. "  # Shield taper (cols 1..14)
    "DK CD CD CD CD CD CD CD CD CD CD CD CD CD CD DK "  # Boots soles
    "DK CY MT BL PW LV DS DK DK DB CD CD CD CD DB DK DK CY MT BL PW LV DS DK DK MT BL PW LV SH DB CD ", # Helmet visor brow shadow

    # Row 11
    ".. DK MT BL PW LV BP BC BM BP BV SH DS DB DK .. "  # Shield taper
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "DK MT BL PW LV SH DK DK DK .. .. CR CW .. .. DK DK MT BL PW LV SH DK DK DK LV BV SH DB CD CD CD ", # Helmet eye slits & cyan nasal glow

    # Row 12
    ".. .. DK BL PW LV BC BM BP BV SH DS DB DK .. .. "  # Shield taper (cols 2..13)
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "DK BL PW LV SH DK DK CD DK .. .. CY MT .. .. DK DK BL PW LV SH DK DK CD DK BV SH DB CD CD CD CD ", # Helmet lower keel

    # Row 13
    ".. .. .. DK PW LV BC BM BP BV SH DS DK .. .. .. "  # Shield taper (cols 3..12)
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "DK PW LV SH DS DK CD CD DK .. .. .. .. .. .. DK DK PW LV SH DS DK CD CD DK DK SH DB CD CD CD CD ", # Helmet chin apex

    # Row 14
    ".. .. .. .. DK SH DS DS DS DS DS DK .. .. .. .. "  # Shield tip bevel (cols 4..11)
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. DK WH CY MT BL DK .. ", # Helmet lower neck lames (cols 57..62)

    # Row 15
    ".. .. .. .. .. .. GL GO GO GD .. .. .. .. .. .. "  # Shield divine gold tip chape (cols 6..9)
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 16
    ".. .. .. .. WH CY MT BL .. .. .. .. .. .. .. .. "  # Leggings right hip (cols 4..7)
    ".. .. .. .. DK WH CY MT MT CY WH DK DK WH CY DK "  # Chestplate gorget / collar (cols 20..31 active)
    "DK WH CY MT .. .. .. .. .. .. .. .. WH CY MT DK .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ", # Shoulder caps (cols 32..35 & 44..47 active)

    # Row 17
    ".. .. .. .. SP WH CY MT .. .. .. .. .. .. .. .. "
    ".. .. .. .. WH SP CY MT MT CY SP WH WH SP CY BL "  # Chestplate collar bevel
    "WH SP CY MT .. .. .. .. .. .. .. .. SP CY MT BL .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 18
    ".. .. .. .. CY MT BL PW .. .. .. .. .. .. .. .. "
    ".. .. .. .. CY MT .. .. .. .. MT BL CY MT BL PW "  # Collar neck cutout (cols 22..25 empty)
    "CY MT BL PW .. .. .. .. .. .. .. .. CY MT BL PW .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 19
    ".. .. .. .. MT BL PW DS .. .. .. .. .. .. .. .. "
    ".. .. .. .. MT BL .. .. .. .. BL PW MT BL PW DS "
    "MT BL PW DS .. .. .. .. .. .. .. .. MT BL PW DS .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 20
    "WH CY MT BL PW LV SH DK WH CY MT BL PW LV SH DK "  # Leggings thighs top (cols 0..15 active)
    "DK WH CY MT BL PW .. .. .. .. PW LV BP BV SH DK "  # Chestplate collar rim (cols 16..21 & 26..31 active)
    "DK WH CY MT BL PW DS DK DK WH CY MT BL PW DS DK WH CY MT BL PW LV SH DK .. .. .. .. .. .. .. .. ", # Chest back + pauldrons (32..55 active)

    # Row 21
    "SP WH CY MT BL PW LV DK SP WH CY MT BL PW LV DK "
    "WH SP CY MT BL PW LV .. .. LV BP BV SH DS DB DK "  # Breastplate diagonal wave start
    "DK WH SP CY MT BL PW DK DK WH SP CY MT BL PW DK WH SP CY MT BL PW LV DK .. .. .. .. .. .. .. .. ",

    # Row 22
    "CY MT BL PW LV BV SH DK CY MT BL PW LV BV SH DK "  # Leggings mid-thigh
    "DK WH CY MT BL PW LV GL GL LV BP BV SH DS DB DK "  # Breastplate with star top tip (cols 23..24: GL GL)
    "DK CY MT BL PW LV SH DK DK CY MT BL PW LV SH DK CY MT BL PW LV BV SH DK .. .. .. .. .. .. .. .. ",

    # Row 23
    "MT BL PW LV BV SH DS DK MT BL PW LV BV SH DS DK "
    "WH CY MT BL PW LV GO SP SP GO BP BV SH DS DB DK "  # Breastplate star upper rays & core (cols 22..25)
    "DK MT BL PW LV BV SH DK DK MT BL PW LV BV SH DK MT BL PW LV BV SH DS DK .. .. .. .. .. .. .. .. ",

    # Row 24
    "WH CY MT BL DK GL GO DK PW LV BP BV SH DS DB DK "  # Leggings front knee star apex (cols 4..7)
    "CY MT BL PW LV GL GO SP CW GO GL BP SH DS DB DK "  # Breastplate horizontal star beam & core (cols 21..26)
    "DK WH CY MT BL PW DS DK .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ", # Backplate upper spine (cols 32..39 active)

    # Row 25
    "SP WH CY MT GL SP CW GO BL PW LV BP SH DS DB DK "  # Leggings front knee star radiant core
    "MT BL PW LV PW LV GO SP SP GO BP BV SH DS DB DK "  # Breastplate star lower rays & core (cols 22..25)
    "DK WH SP CY MT BL DS DK .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 26
    "CY MT BL PW DK GD GD DK LV BP BV SH DS DB DK CD "  # Leggings front knee star bottom
    "BL PW LV BV BL PW LV GD GD LV BP BV SH DS DB DK "  # Breastplate star bottom tip (cols 23..24: GD GD)
    "DK CY MT BL PW LV DS DK .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 27
    "MT BL PW LV SH DS DB DK MT BL PW LV SH DS DB DK "  # Leggings greave / shin
    "PW LV BV SH CY MT BL PW LV BP BV SH DS DB DK CD "  # Plackart lower plate
    "DK MT BL PW LV SH DS DK .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 28
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "  # Leggings empty
    "DK GL GO GD GL GO GL SP SP GL GO GD GD GO GL DK "  # Torso celestial gold belt with star buckle (16..31: all active)
    "DK GL GO GD GL GO GD DK .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ", # Sleeves cuff gold band (cols 32..39 active)

    # Row 29
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "DK GO GD GD GO GD GO GL GL GO GD GD GD GD GO DK "  # Gold belt shadow / lower bevel
    "DK GO GD GD GD GD GO DK .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ",

    # Row 30
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "WH CY MT BL CY MT BL PW LV BP BV SH DS DB DK CD "  # Torso tassets / skirt below belt
    "DK WH CY MT BL PW DS DK .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ", # Sleeves wrist

    # Row 31
    ".. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. "
    "DK MT BL PW DK MT BL PW LV BP SH DK DS DB DK CD "  # Torso skirt hem
    "DK MT BL PW LV SH DS DK .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ", # Sleeves wrist hem
]

def build_admin_sheet():
    sheet = []
    for row_str in ADMIN_SHEET_GRID:
        tokens = row_str.strip().split()
        sheet.append([ADMIN_PALETTE[tok] for tok in tokens])
    return sheet

# 64x32 CHARACTER SHEET BUILDER
def build_character_sheet(mat):
    if mat == "diamond":
        return build_diamond_sheet()
    elif mat == "bronze":
        return build_bronze_sheet()
    elif mat == "cactus":
        return build_cactus_sheet()
    elif mat == "crystal":
        return build_crystal_sheet()
    elif mat == "gold":
        return build_gold_sheet()
    elif mat == "mithril":
        return build_mithril_sheet()
    elif mat == "nether":
        return build_nether_sheet()
    elif mat == "steel":
        return build_steel_sheet()
    elif mat == "wood":
        return build_wood_sheet()
    elif mat == "admin":
        return build_admin_sheet()
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
        if mat == "mithril":
            alt_path = os.path.join(textures_dir, "x_player_armor_mithril_alt.png")
            write_png_rgba(alt_path, 64, 32, sheet)
            print(f"  [Sheet 64x32] {os.path.basename(alt_path)}")

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
