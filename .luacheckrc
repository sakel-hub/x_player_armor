std = "lua51"
globals = {
    "x_player_armor",
    "armor",
    "shields",
}
read_globals = {
    "core",
    "minetest",
    "ItemStack",
    "vector",
    "PcgRandom",
    "PseudoRandom",
    "SecureRandom",
    "DIR_DELIM",
    "PLATFORM",
    "dump",
    "dump2",
    "Raycast",
    "Settings",
    "AreaStore",
    "VoxelManip",
    "VoxelArea",
    "PerlinNoise",
    "PerlinNoiseMap",
    "default",
    "player_api",
    "x_player_api",
    "sfinv",
    "unified_inventory",
    "i3",
    "player_monoids",
    "pova",
    "playerphysics",
    "bones",
    table = {
        fields = {
            "copy",
            "indexof",
            "insert_all",
            "key_value_swap",
        },
    },
    string = {
        fields = {
            "split",
            "trim",
        },
    },
}
exclude_files = {
    "tests/**",
    "assets/scripts/**",
}
max_line_length = 160
