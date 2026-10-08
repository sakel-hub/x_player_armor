#!/usr/bin/env python3
"""
Automated Model Pipeline for x_player_armor
Extracts modular armor pieces from 3d_armor_character.blend with exact bone-local pivots,
assigns pixel-perfect UV maps and material texture setups, and exports production .blend and .glb files:
  - x_player_armor_helmet.blend / .glb
  - x_player_armor_chestplate.blend / .glb
  - x_player_armor_sleeve_l.blend / .glb
  - x_player_armor_sleeve_r.blend / .glb
  - x_player_armor_leggings_l.blend / .glb
  - x_player_armor_leggings_r.blend / .glb
  - x_player_armor_boot_l.blend / .glb
  - x_player_armor_boot_r.blend / .glb
  - x_player_armor_shield.blend / .glb
  - x_player_armor_preview.blend / .glb
  - x_player_armor_stand.blend / .glb

Executed via Blender headless CLI:
/Applications/Blender\\ 5.app/Contents/MacOS/Blender --factory-startup --background --python assets/scripts/build_models.py
"""

import os
import bpy
import bmesh

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
MOD_DIR = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))
ASSETS_DIR = os.path.join(MOD_DIR, "assets")
MODELS_DIR = os.path.join(MOD_DIR, "models")
MINETEST_MODS = os.path.abspath(os.path.join(MOD_DIR, ".."))

ARMOR_BLEND = os.path.join(MINETEST_MODS, "3d_armor", "3d_armor", "models", "3d_armor_character.blend")
STAND_SRC = os.path.join(MINETEST_MODS, "3d_armor", "3d_armor_stand", "models", "3d_armor_stand.obj")

os.makedirs(ASSETS_DIR, exist_ok=True)
os.makedirs(MODELS_DIR, exist_ok=True)


def setup_material_texture(mat, rel_tex_path, blend_dir):
    """
    Configures a Principled BSDF shader with an Image Texture node set to Closest (pixel-art) interpolation
    and ALPHA CLIP transparency mode with glTF alphaMode MASK compatibility.
    """
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    node_out = nodes.new(type="ShaderNodeOutputMaterial")
    node_out.location = (350, 0)

    node_bsdf = nodes.new(type="ShaderNodeBsdfPrincipled")
    node_bsdf.location = (50, 0)
    node_bsdf.inputs["Roughness"].default_value = 0.9

    node_tex = nodes.new(type="ShaderNodeTexImage")
    node_tex.location = (-350, 0)
    node_tex.interpolation = "Closest"  # Crisp pixel art rendering in Blender

    node_round = nodes.new(type="ShaderNodeMath")
    node_round.location = (-120, -120)
    node_round.operation = "ROUND"

    abs_path = os.path.normpath(os.path.join(blend_dir, rel_tex_path))
    if os.path.exists(abs_path):
        img_name = os.path.basename(abs_path)
        existing = bpy.data.images.get(img_name)
        if existing and existing.size[0] > 0 and existing.size[1] > 0:
            img = existing
        else:
            if existing:
                bpy.data.images.remove(existing)
            img = bpy.data.images.load(filepath=abs_path)
        node_tex.image = img

    links.new(node_tex.outputs["Color"], node_bsdf.inputs["Base Color"])
    links.new(node_tex.outputs["Alpha"], node_round.inputs[0])
    links.new(node_round.outputs[0], node_bsdf.inputs["Alpha"])
    links.new(node_bsdf.outputs["BSDF"], node_out.inputs["Surface"])

    mat.blend_method = "CLIP"
    if hasattr(mat, "alpha_threshold"):
        mat.alpha_threshold = 0.5


def set_viewport_material_shading():
    """
    Sets the active 3D Viewport in Blender to Material Preview mode so textures appear immediately on opening.
    """
    for window in bpy.context.window_manager.windows:
        for area in window.screen.areas:
            if area.type == "VIEW_3D":
                for space in area.spaces:
                    if space.type == "VIEW_3D":
                        space.shading.type = "MATERIAL"


def extract_and_export_piece(name, faces_data, rel_tex_path, transform_fn):
    """
    Creates a clean .blend and .glb containing only this armor piece with exact UVs and texture mapping,
    transformed to match canonical Luanti character skeletal proportions and bone pivots.
    """
    # Initialize empty factory scene
    bpy.ops.wm.read_homefile(use_empty=True)

    new_mesh = bpy.data.meshes.new(name)
    new_obj = bpy.data.objects.new(name, new_mesh)
    bpy.context.scene.collection.objects.link(new_obj)

    verts = []
    faces = []
    all_uvs = []

    for v_cos, loop_uvs in faces_data:
        base_idx = len(verts)
        for co in v_cos:
            verts.append(transform_fn(co))
        faces.append([base_idx + i for i in range(len(v_cos))])
        all_uvs.append(loop_uvs)

    new_mesh.from_pydata(verts, [], faces)
    new_mesh.update()

    uv_layer = new_mesh.uv_layers.new(name="UVMap")
    for p, loop_uvs in zip(new_mesh.polygons, all_uvs):
        p.use_smooth = False
        for l_idx, uv in zip(p.loop_indices, loop_uvs):
            uv_layer.data[l_idx].uv = uv

    # Configure material and texture
    mat = bpy.data.materials.new(name="Armor")
    setup_material_texture(mat, rel_tex_path, ASSETS_DIR)
    new_obj.data.materials.append(mat)

    set_viewport_material_shading()

    # Save dedicated .blend file with relative paths
    blend_path = os.path.join(ASSETS_DIR, f"{name}.blend")
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    bpy.ops.file.make_paths_relative()
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)

    # Export production .glb file
    glb_path = os.path.join(MODELS_DIR, f"{name}.glb")
    bpy.ops.export_scene.gltf(
        filepath=glb_path,
        export_format="GLB",
        export_materials="EXPORT",
        export_yup=True,
    )
    patch_glb_materials(glb_path)
    print(f"Built {name}: blend={os.path.getsize(blend_path)}B, glb={os.path.getsize(glb_path)}B ({len(faces)} polygons)")


def build_armor_models():
    print(f"Reading character blend: {ARMOR_BLEND}")
    bpy.ops.wm.open_mainfile(filepath=ARMOR_BLEND)

    player_obj = bpy.data.objects["Player"]
    player_mesh = player_obj.data
    uv_layer = player_mesh.uv_layers.active.data

    # Canonical Luanti skeletal scaling factors (matching engine character.b3d / character.glb):
    # Lateral (X) and Depth (Y): 4.2 canonical width / 4.0 legacy width = 1.05
    # Height (Z) for torso and limbs: 6.3 canonical height / 6.75 legacy height = 0.93333
    # Height (Z) for head: 4.2 canonical height / 4.0 legacy height = 1.05
    scale_xy = 1.05
    scale_z_body = 6.3 / 6.75
    scale_z_head = 1.05

    pieces_config = {
        "x_player_armor_helmet": {
            "range": range(54, 60),
            "transform": lambda co: (co[0] * scale_xy, co[1] * scale_xy, (co[2] - 13.5) * scale_z_head),
            "texture": "../textures/x_player_armor_steel.png",
        },
        "x_player_armor_chestplate": {
            "range": range(48, 54),
            "transform": lambda co: (co[0] * scale_xy, co[1] * scale_xy, (co[2] - 6.75) * scale_z_body),
            "texture": "../textures/x_player_armor_steel.png",
        },
        "x_player_armor_sleeve_l": {
            "range": range(60, 66),
            "transform": lambda co: ((co[0] + 3.0) * scale_xy, co[1] * scale_xy, (co[2] - 12.5) * scale_z_body),
            "texture": "../textures/x_player_armor_steel.png",
        },
        "x_player_armor_sleeve_r": {
            "range": range(66, 72),
            "transform": lambda co: ((co[0] - 3.0) * scale_xy, co[1] * scale_xy, (co[2] - 12.5) * scale_z_body),
            "texture": "../textures/x_player_armor_steel.png",
        },
        "x_player_armor_leggings_r": {
            "range": range(72, 78),
            "transform": lambda co: ((co[0] - 1.0) * scale_xy, co[1] * scale_xy, max(-6.30, (co[2] - 6.75) * scale_z_body)),
            "texture": "../textures/x_player_armor_steel.png",
        },
        "x_player_armor_leggings_l": {
            "range": range(78, 84),
            "transform": lambda co: ((co[0] + 1.0) * scale_xy, co[1] * scale_xy, max(-6.30, (co[2] - 6.75) * scale_z_body)),
            "texture": "../textures/x_player_armor_steel.png",
        },
        "x_player_armor_boot_l": {
            "range": range(84, 90),
            "transform": lambda co: ((co[0] + 1.0) * 1.08, co[1] * 1.08, -7.20 if co[2] <= 1.0 else -3.10),
            "texture": "../textures/x_player_armor_steel.png",
        },
        "x_player_armor_boot_r": {
            "range": range(90, 96),
            "transform": lambda co: ((co[0] - 1.0) * 1.08, co[1] * 1.08, -7.20 if co[2] <= 1.0 else -3.10),
            "texture": "../textures/x_player_armor_steel.png",
        },
    }

    # Extract polygon coordinates and loop UVs for each piece
    extracted_data = {}
    for name, cfg in pieces_config.items():
        faces_data = []
        for p_idx in cfg["range"]:
            p = player_mesh.polygons[p_idx]
            v_cos = [player_mesh.vertices[v].co[:] for v in p.vertices]
            loop_uvs = [uv_layer[l].uv[:] for l in p.loop_indices]
            faces_data.append((v_cos, loop_uvs))
        extracted_data[name] = faces_data

    # Build individual clean .blend and .glb for every armor piece
    for name, cfg in pieces_config.items():
        extract_and_export_piece(name, extracted_data[name], cfg["texture"], cfg["transform"])

    # Build solid low-poly beveled shield model (S2) for in-world attached entity
    build_solid_shield_model()

    # Build clean standalone x_player_armor_preview.blend and .glb (7 material slots)
    build_preview_model()


def build_solid_shield_model():
    """
    Builds a clean, solid, low-poly beveled shield model (S2) with front face,
    back face, side rim walls, and arm straps. Replaces legacy stacked planes.
    """
    print("Building solid 3D shield model for in-world entity...")
    bpy.ops.wm.read_homefile(use_empty=True)

    name = "x_player_armor_shield"
    mesh = bpy.data.meshes.new(name)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)

    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.new("UVMap")

    # Local coordinates for shield mounted on Arm_Left:
    p_fb = bmesh.types.BMVert and None # dummy for typing
    from mathutils import Vector
    p_fb = Vector((-1.57, -2.24, -8.05))  # Front-bottom
    p_ft = Vector((-2.75, -1.89, -1.96))  # Front-top
    p_bt = Vector((-0.43,  4.67, -1.90))  # Back-top
    p_bb = Vector(( 0.75,  4.33, -7.98))  # Back-bottom

    v_u = p_fb - p_bb
    v_v = p_bt - p_bb
    normal = v_u.cross(v_v).normalized()
    thickness = 0.35
    dn = normal * thickness

    vf0 = bm.verts.new(p_bb)
    vf1 = bm.verts.new(p_fb)
    vf2 = bm.verts.new(p_ft)
    vf3 = bm.verts.new(p_bt)

    vb0 = bm.verts.new(p_bb - dn)
    vb1 = bm.verts.new(p_fb - dn)
    vb2 = bm.verts.new(p_ft - dn)
    vb3 = bm.verts.new(p_bt - dn)

    u0, v0, u1, v1 = 0.0, 0.5, 0.25, 1.0
    uc = (u0 + u1) / 2.0

    # Front face (+normal)
    f_front = bm.faces.new((vf0, vf1, vf2, vf3))
    f_front.loops[0][uv_layer].uv = (u0, v0)
    f_front.loops[1][uv_layer].uv = (u1, v0)
    f_front.loops[2][uv_layer].uv = (u1, v1)
    f_front.loops[3][uv_layer].uv = (u0, v1)

    # Back face (-normal)
    f_back = bm.faces.new((vb3, vb2, vb1, vb0))
    f_back.loops[0][uv_layer].uv = (u0, v1)
    f_back.loops[1][uv_layer].uv = (u1, v1)
    f_back.loops[2][uv_layer].uv = (u1, v0)
    f_back.loops[3][uv_layer].uv = (u0, v0)

    # Rim perimeter faces (Top, Bottom, Front, Back)
    rim_uv = (uc, 0.98)
    for fverts in [
        (vf3, vf2, vb2, vb3),  # Top
        (vf1, vf0, vb0, vb1),  # Bottom
        (vf2, vf1, vb1, vb2),  # Front edge
        (vf0, vf3, vb3, vb0),  # Back edge
    ]:
        f = bm.faces.new(fverts)
        for l in f.loops:
            l[uv_layer].uv = rim_uv

    # Arm Straps wrapping around Arm_Left
    for strap_z in [-3.5, -6.5]:
        sw = 0.4
        s_shield = (p_bb - dn).lerp(p_bt - dn, 0.7 if strap_z == -3.5 else 0.2)
        p0 = Vector((s_shield.x, s_shield.y, strap_z - sw / 2))
        p1 = Vector((0.3, s_shield.y, strap_z - sw / 2))
        p2 = Vector((0.3, -0.8, strap_z - sw / 2))
        p3 = Vector((s_shield.x, -0.8, strap_z - sw / 2))

        p0_top = Vector((p0.x, p0.y, strap_z + sw / 2))
        p1_top = Vector((p1.x, p1.y, strap_z + sw / 2))
        p2_top = Vector((p2.x, p2.y, strap_z + sw / 2))
        p3_top = Vector((p3.x, p3.y, strap_z + sw / 2))

        vs = [bm.verts.new(p) for p in [p0, p1, p2, p3, p0_top, p1_top, p2_top, p3_top]]
        for q in [
            (vs[0], vs[1], vs[5], vs[4]),
            (vs[1], vs[2], vs[6], vs[5]),
            (vs[2], vs[3], vs[7], vs[6]),
        ]:
            sf = bm.faces.new(q)
            for l in sf.loops:
                l[uv_layer].uv = (0.1, 0.6)

    bm.to_mesh(mesh)
    bm.free()

    mat = bpy.data.materials.new(name="Armor")
    setup_material_texture(mat, "../textures/x_player_armor_steel.png", ASSETS_DIR)
    obj.data.materials.append(mat)

    set_viewport_material_shading()

    blend_path = os.path.join(ASSETS_DIR, f"{name}.blend")
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    bpy.ops.file.make_paths_relative()
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)

    glb_path = os.path.join(MODELS_DIR, f"{name}.glb")
    bpy.ops.export_scene.gltf(
        filepath=glb_path,
        export_format="GLB",
        export_materials="EXPORT",
        export_yup=True,
    )
    patch_glb_materials(glb_path)
    print(f"Built solid {name}: blend={os.path.getsize(blend_path)}B, glb={os.path.getsize(glb_path)}B ({len(mesh.polygons)} polygons)")


def add_voxel_extruder_to_bm(bm, uv_layer, dvert_lay, base, axis_u, axis_v, axis_n, thickness, uv_rect, mat_idx, vg_idx):
    """
    Builds a 16x16 grid of 3D cuboid cells (256 voxels) with solid perimeter edge walls.
    UV mapping maps front/back faces to the cell rectangle and edge walls to the pixel center.
    Assigns all vertices to the specified material slot and vertex group.
    """
    u_min, v_min, u_max, v_max = uv_rect
    du = axis_u / 16.0
    dv = axis_v / 16.0
    dn = axis_n.normalized() * (thickness / 2.0)
    delta_u = u_max - u_min
    delta_v = v_max - v_min
    step_u = delta_u / 16.0
    step_v = delta_v / 16.0

    flip = (axis_u.cross(axis_v)).dot(axis_n) < 0

    for iy in range(16):
        for ix in range(16):
            c0 = base + ix * du + iy * dv
            c1 = c0 + du
            c2 = c1 + dv
            c3 = c0 + dv

            cu0 = u_min + ix * step_u
            cu1 = cu0 + step_u
            cv0 = v_min + iy * step_v
            cv1 = cv0 + step_v
            cuc = cu0 + step_u * 0.5
            cvc = cv0 + step_v * 0.5

            verts_front = [
                bm.verts.new(c0 + dn),
                bm.verts.new(c1 + dn),
                bm.verts.new(c2 + dn),
                bm.verts.new(c3 + dn),
            ]
            verts_back = [
                bm.verts.new(c0 - dn),
                bm.verts.new(c1 - dn),
                bm.verts.new(c2 - dn),
                bm.verts.new(c3 - dn),
            ]
            for v in verts_front + verts_back:
                v[dvert_lay][vg_idx] = 1.0

            if not flip:
                # Front face (+normal along +axis_n)
                ff = bm.faces.new(verts_front)
                ff.material_index = mat_idx
                ff.loops[0][uv_layer].uv = (cu0, cv0)
                ff.loops[1][uv_layer].uv = (cu1, cv0)
                ff.loops[2][uv_layer].uv = (cu1, cv1)
                ff.loops[3][uv_layer].uv = (cu0, cv1)

                # Back face (-normal along -axis_n)
                fb = bm.faces.new((verts_back[3], verts_back[2], verts_back[1], verts_back[0]))
                fb.material_index = mat_idx
                fb.loops[0][uv_layer].uv = (cu0, cv1)
                fb.loops[1][uv_layer].uv = (cu1, cv1)
                fb.loops[2][uv_layer].uv = (cu1, cv0)
                fb.loops[3][uv_layer].uv = (cu0, cv0)

                # Perimeter side edge walls (Top, Bottom, Right, Left)
                sides = [
                    (verts_front[3], verts_front[2], verts_back[2], verts_back[3]),  # Top (+v)
                    (verts_front[1], verts_front[0], verts_back[0], verts_back[1]),  # Bottom (-v)
                    (verts_front[2], verts_front[1], verts_back[1], verts_back[2]),  # Right (+u)
                    (verts_front[0], verts_front[3], verts_back[3], verts_back[0]),  # Left (-u)
                ]
            else:
                # Front face (+normal along +axis_n)
                ff = bm.faces.new((verts_front[0], verts_front[3], verts_front[2], verts_front[1]))
                ff.material_index = mat_idx
                ff.loops[0][uv_layer].uv = (cu0, cv0)
                ff.loops[1][uv_layer].uv = (cu0, cv1)
                ff.loops[2][uv_layer].uv = (cu1, cv1)
                ff.loops[3][uv_layer].uv = (cu1, cv0)

                # Back face (-normal along -axis_n)
                fb = bm.faces.new((verts_back[0], verts_back[1], verts_back[2], verts_back[3]))
                fb.material_index = mat_idx
                fb.loops[0][uv_layer].uv = (cu0, cv0)
                fb.loops[1][uv_layer].uv = (cu1, cv0)
                fb.loops[2][uv_layer].uv = (cu1, cv1)
                fb.loops[3][uv_layer].uv = (cu0, cv1)

                # Perimeter side edge walls (Top, Bottom, Right, Left)
                sides = [
                    (verts_front[2], verts_front[3], verts_back[3], verts_back[2]),  # Top (+v)
                    (verts_front[0], verts_front[1], verts_back[1], verts_back[0]),  # Bottom (-v)
                    (verts_front[1], verts_front[2], verts_back[2], verts_back[1]),  # Right (+u)
                    (verts_front[3], verts_front[0], verts_back[0], verts_back[3]),  # Left (-u)
                ]

            for sverts in sides:
                sf = bm.faces.new(sverts)
                sf.material_index = mat_idx
                for l in sf.loops:
                    l[uv_layer].uv = (cuc, cvc)


SKINSDB_BLEND = os.path.join(MINETEST_MODS, "skinsdb", "models", "skinsdb_3d_armor_character_5.blend")
if not os.path.exists(SKINSDB_BLEND):
    SKINSDB_BLEND = os.path.join(MINETEST_MODS, "x_player_bridge", "assets", "skinsdb_3d_armor_character_5.blend")


def patch_glb_materials(glb_path):
    """
    Patches the exported glTF binary to:
    1. Ensure all materials have alphaMode: MASK with alphaCutoff: 0.5.
    2. Ensure each material i (0..N-1) has a dedicated baseColorTexture with index i,
       and the textures array has N entries with sampler 0. This guarantees Luanti's
       CGLTFMeshFileLoader sets getTextureSlot(meshbufNr) = i for 1-to-1 texture slot mapping.
    3. Completely strip embedded images and image sources from glTF, eliminating
       Luanti's 'embedded images are not supported' warning and ensuring all textures
       are bound dynamically at runtime via Luanti object properties.
    """
    import struct
    import json
    with open(glb_path, "rb") as f:
        data = f.read()
    magic, version, _ = struct.unpack_from("<4sII", data, 0)
    chunk_len, chunk_type = struct.unpack_from("<II", data, 12)
    json_bytes = data[20:20+chunk_len]
    json_data = json.loads(json_bytes.decode("utf-8"))

    materials = json_data.get("materials", [])
    num_materials = len(materials)

    # Ensure default sampler is present for nearest-neighbor / clamp wrapping
    samplers = json_data.get("samplers", [])
    if not samplers:
        samplers = [{"magFilter": 9728, "minFilter": 9728, "wrapS": 10497, "wrapT": 10497}]
        json_data["samplers"] = samplers

    # Map each material 1-to-1 to its corresponding texture slot
    json_data["textures"] = [{"sampler": 0} for _ in range(num_materials)]

    for i, mat in enumerate(materials):
        mat["alphaMode"] = "MASK"
        mat["alphaCutoff"] = 0.5
        pbr = mat.setdefault("pbrMetallicRoughness", {})
        pbr["baseColorTexture"] = {"index": i}

    # Completely strip embedded images so Luanti never warns or falls back to baked pixels
    if "images" in json_data:
        del json_data["images"]

    new_json_str = json.dumps(json_data, separators=(",", ":"))
    new_json_bytes = new_json_str.encode("utf-8")
    pad_len = (4 - (len(new_json_bytes) % 4)) % 4
    new_json_bytes += b" " * pad_len
    new_chunk_len = len(new_json_bytes)

    bin_chunk = data[20+chunk_len:]
    new_total_len = 12 + 8 + new_chunk_len + len(bin_chunk)
    new_header = struct.pack("<4sII", magic, version, new_total_len)
    new_chunk_header = struct.pack("<II", new_chunk_len, chunk_type)

    with open(glb_path, "wb") as f:
        f.write(new_header)
        f.write(new_chunk_header)
        f.write(new_json_bytes)
        f.write(bin_chunk)
    print(f"Patched {glb_path}: {num_materials} slot(s), stripped images, alphaMode: MASK")


def build_preview_model():
    print(f"Building 9-material universal 3D preview model from {ARMOR_BLEND} and {SKINSDB_BLEND}...")

    from mathutils import Vector

    scale_xy = 1.05
    scale_z_body = 6.3 / 6.75
    scale_z_head = 1.05

    def transform_f18(co):
        x = co.x * scale_xy
        y = co.y * scale_xy
        if co.z <= 0.0:
            z = 0.0
        elif co.z <= 13.5:
            z = co.z * scale_z_body
        else:
            z = 12.6 + (co.z - 13.5) * scale_z_head
        return (x, y, z)

    # 1. Extract 72 Format 1.8 faces (36 base body + 36 3D outer layers) from skinsdb model
    f18_data = []
    if os.path.exists(SKINSDB_BLEND):
        print(f"Extracting Format 1.8 3D meshes from {SKINSDB_BLEND}...")
        bpy.ops.wm.open_mainfile(filepath=SKINSDB_BLEND)
        s_player = bpy.data.objects.get("Player")
        if s_player and s_player.data:
            s_mesh = s_player.data
            s_uv = s_mesh.uv_layers.active.data
            vg_names = {vg.index: vg.name for vg in s_player.vertex_groups}

            for p in s_mesh.polygons:
                if p.material_index == 1:
                    v_cos = [transform_f18(s_mesh.vertices[v].co) for v in p.vertices]
                    loop_uvs = [s_uv[l].uv[:] for l in p.loop_indices]
                    v_weights = []
                    for v in p.vertices:
                        w_dict = {}
                        for g in s_mesh.vertices[v].groups:
                            gname = vg_names.get(g.group)
                            if gname:
                                w_dict[gname] = g.weight
                        v_weights.append(w_dict)
                    f18_data.append((v_cos, loop_uvs, v_weights))
            print(f"Extracted {len(f18_data)} Format 1.8 faces with 3D outer layers.")

    # 2. Open base 3d_armor blend file
    bpy.ops.wm.open_mainfile(filepath=ARMOR_BLEND)

    # Clean out non-essential objects (lights, cameras, extra meshes)
    for obj in list(bpy.data.objects):
        if obj.name not in ("Armature", "Player"):
            bpy.data.objects.remove(obj, do_unlink=True)

    player_obj = bpy.data.objects.get("Player")
    player_mesh = player_obj.data

    # Exact polygon classification:
    # 0 = Body (Format 1.0, 64x32)
    # 1 = Body18 (Format 1.8, 64x64, inserted via bmesh)
    # 2 = Head (Helmet)
    # 3 = Torso (Chestplate + Sleeves)
    # 4 = Legs (Leggings)
    # 5 = Feet (Boots)
    # -1 = Delete (cape 42..47, legacy stacked shield 96..157, legacy stacked sword 158..219)
    poly_mat = {}
    for p in player_mesh.polygons:
        idx = p.index
        if idx in range(42, 48) or idx >= 96:
            poly_mat[idx] = -1  # Delete cape (42..47) and legacy stacked planes
        elif idx < 42:
            poly_mat[idx] = 0   # Base character body (Format 1.0)
        elif idx in range(48, 54):
            poly_mat[idx] = 3   # Chestplate -> Torso
        elif idx in range(54, 60):
            poly_mat[idx] = 2   # Helmet -> Head
        elif idx in range(60, 72):
            poly_mat[idx] = 3   # Sleeves Left/Right -> Torso
        elif idx in range(72, 84):
            poly_mat[idx] = 4   # Leggings Left/Right (including bottom caps 73 & 83) -> Legs
        elif idx in range(84, 96):
            poly_mat[idx] = 5   # Boots Left/Right -> Feet

    # Assign 9 dedicated material slots
    mat_configs = [
        ("Body", "../textures/x_player_armor_character.png"),
        ("Body18", "../textures/blank.png"),
        ("Head", "../textures/x_player_armor_steel.png"),
        ("Torso", "../textures/x_player_armor_steel.png"),
        ("Legs", "../textures/x_player_armor_steel.png"),
        ("Feet", "../textures/x_player_armor_steel.png"),
        ("Shield_Standard", "../textures/x_player_armor_steel.png"),
        ("Shield_Tower", "../textures/x_player_armor_shield_enhanced_cactus.png"),
        ("Wielditem", "../textures/x_player_armor_character.png"),
    ]

    player_obj.data.materials.clear()
    for m in list(bpy.data.materials):
        bpy.data.materials.remove(m, do_unlink=True)
    for mname, mtex in mat_configs:
        mat = bpy.data.materials.new(name=mname)
        setup_material_texture(mat, mtex, ASSETS_DIR)
        player_obj.data.materials.append(mat)

    bpy.context.view_layer.objects.active = player_obj
    bpy.ops.object.mode_set(mode="EDIT")
    bm = bmesh.from_edit_mesh(player_mesh)

    faces_to_del = []
    for f in bm.faces:
        target = poly_mat.get(f.index, 0)
        if target == -1:
            faces_to_del.append(f)
        else:
            f.material_index = target

    bmesh.ops.delete(bm, geom=faces_to_del, context="FACES_ONLY")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bmesh.update_edit_mesh(player_mesh)
    bpy.ops.object.mode_set(mode="OBJECT")

    # Identify boot vertices (material_index == 5)
    boot_vert_indices = set()
    for f in player_mesh.polygons:
        if f.material_index == 5:
            for v_idx in f.vertices:
                boot_vert_indices.add(v_idx)

    scale_xy_boot = 1.08
    for v in player_mesh.vertices:
        if v.index in boot_vert_indices:
            v.co.x *= scale_xy_boot
            v.co.y *= scale_xy_boot
            v.co.z = -0.90 if v.co.z <= 1.5 else 3.20
        else:
            v.co.x *= scale_xy
            v.co.y *= scale_xy
            if v.co.z <= 0.0:
                v.co.z = 0.0
            elif v.co.z <= 13.5:
                v.co.z *= scale_z_body
            else:
                v.co.z = 12.6 + (v.co.z - 13.5) * scale_z_head

    # Generate 3D Voxel Extruder Grid for Standard Shield (Slot 6), Tower Shield (Slot 7), and Wielditem (Slot 8)
    # and append Format 1.8 faces to Body18 (Slot 1)
    bpy.ops.object.mode_set(mode="EDIT")
    bm = bmesh.from_edit_mesh(player_mesh)
    uv_layer = bm.loops.layers.uv.active
    dvert_lay = bm.verts.layers.deform.verify()

    arm_l_idx = player_obj.vertex_groups["Arm_Left"].index
    arm_r_idx = player_obj.vertex_groups["Arm_Right"].index

    # Append Format 1.8 geometry (Slot 1)
    vg_indices = {vg.name: vg.index for vg in player_obj.vertex_groups}
    for v_cos, loop_uvs, v_weights in f18_data:
        verts = [bm.verts.new(co) for co in v_cos]
        for v, w_dict in zip(verts, v_weights):
            for gname, weight in w_dict.items():
                if gname in vg_indices:
                    v[dvert_lay][vg_indices[gname]] = weight
        face = bm.faces.new(verts)
        face.material_index = 1  # Body18
        for l, uv in zip(face.loops, loop_uvs):
            l[uv_layer].uv = uv

    # 1. Shield Standard (Slot 6) on Arm_Left (Medium heater/buckler shield)
    shield_base = Vector((-2.40, 4.33, 3.68))
    shield_axis_u = Vector((-2.32, -6.57, -0.07))
    shield_axis_v = Vector((-1.18, 0.34, 6.08))
    shield_axis_n = Vector((-0.925, 0.329, -0.198))
    shield_uv_rect = (0.0, 0.5, 0.25, 1.0)
    add_voxel_extruder_to_bm(bm, uv_layer, dvert_lay, shield_base, shield_axis_u, shield_axis_v, shield_axis_n, 0.35, shield_uv_rect, 6, arm_l_idx)

    # 2. Shield Tower (Slot 7) on Arm_Left (Tall boots-to-neckline tower shield)
    # Raised bottom to Z=1.80 (mid-boot / ankle level) to prevent ground clipping while preserving neckline coverage
    shield_base_tower = Vector((-2.46, 4.68, 1.80))
    shield_axis_u_tower = Vector((-2.40, -6.80, -0.07))
    shield_axis_v_tower = Vector((-2.00, 0.58, 10.70))
    shield_axis_n_tower = Vector((-0.925, 0.329, -0.198))
    add_voxel_extruder_to_bm(bm, uv_layer, dvert_lay, shield_base_tower, shield_axis_u_tower, shield_axis_v_tower, shield_axis_n_tower, 0.35, shield_uv_rect, 7, arm_l_idx)

    # 3. Wielditem (Slot 8) on Arm_Right (Universal 16x16 Extruder)
    # Canonical Luanti wield orientation:
    # Diagonal tool axis extends horizontally forward (+Y) from hand (base Y=-0.15 -> tip Y=+7.60 at Z=7.35)
    # Grip sits comfortably in palm/fingers (Y=+0.88..+1.92), crossguard emerges in front of hand (Y=+1.92..+3.80)
    # Sharp side of axe / cutting edge (uv 0,1) points DOWN towards Z=3.22
    # Back/butt of tool (uv 1,0) points UP towards Z=11.48
    wield_base = Vector((3.15, -0.15, 7.35))
    wield_axis_u = Vector((0.0, 4.14, 4.13))
    wield_axis_v = Vector((0.0, 4.13, -4.13))
    wield_axis_n = Vector((1.0, 0.0, 0.0))   # +X normal (facing outward)
    wield_uv_rect = (0.0, 0.0, 1.0, 1.0)
    add_voxel_extruder_to_bm(bm, uv_layer, dvert_lay, wield_base, wield_axis_u, wield_axis_v, wield_axis_n, 0.35, wield_uv_rect, 8, arm_r_idx)

    bmesh.update_edit_mesh(player_mesh)
    bpy.ops.object.mode_set(mode="OBJECT")

    # Update Armature edit bones to canonical Luanti skeletal dimensions
    arm = bpy.data.objects["Armature"]
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones
    if "Body" in eb:
        eb["Body"].head = (-1.2488968970103542e-08, 0.0, 6.3)
        eb["Body"].tail = (-1.2488968970103542e-08, 0.0, 12.6)
    if "Head" in eb:
        eb["Head"].head = (-1.2488968970103542e-08, 0.0, 12.6)
        eb["Head"].tail = (-1.2488968970103542e-08, 0.0, 16.8)
    if "Arm_Left" in eb:
        eb["Arm_Left"].head = (-3.15, 0.0, 11.55)
        eb["Arm_Left"].tail = (-3.15, 0.0, 6.3)
    if "Arm_Right" in eb:
        eb["Arm_Right"].head = (3.15, 0.0, 11.55)
        eb["Arm_Right"].tail = (3.15, 0.0, 6.3)
    if "Leg_Right" in eb:
        eb["Leg_Right"].head = (1.05, 0.0, 6.3)
        eb["Leg_Right"].tail = (1.05, 0.0, 0.0)
    if "Leg_Left" in eb:
        eb["Leg_Left"].head = (-1.05, 0.0, 6.3)
        eb["Leg_Left"].tail = (-1.05, 0.0, 0.0)
    if "Cape" in eb:
        eb.remove(eb["Cape"])
    bpy.ops.object.mode_set(mode="OBJECT")

    # Reset Armature pose to symmetric upright REST pose
    if arm.animation_data:
        arm.animation_data_clear()

    for pb in arm.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_euler = (0, 0, 0)
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.scale = (1, 1, 1)

    arm.data.pose_position = "REST"
    bpy.context.view_layer.update()

    set_viewport_material_shading()

    # Save clean multi-material standalone preview .blend
    preview_blend = os.path.join(ASSETS_DIR, "x_player_armor_preview.blend")
    bpy.ops.wm.save_as_mainfile(filepath=preview_blend)
    bpy.ops.file.make_paths_relative()
    bpy.ops.wm.save_as_mainfile(filepath=preview_blend)

    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    player_obj.select_set(True)
    bpy.context.view_layer.objects.active = arm
    preview_glb = os.path.join(MODELS_DIR, "x_player_armor_preview.glb")
    bpy.ops.export_scene.gltf(
        filepath=preview_glb,
        export_format="GLB",
        use_selection=True,
        export_materials="EXPORT",
        export_animations=False,
        export_skins=True,
        export_yup=True,
    )
    print(f"Exported multi-material preview: blend={os.path.getsize(preview_blend)}B, glb={os.path.getsize(preview_glb)}B ({len(player_mesh.polygons)} polygons, {len(player_obj.material_slots)} materials)")
    patch_glb_materials(preview_glb)

    # Reset preview blend file UI to modern default Blender factory workspaces and layout
    # (replaces legacy screen layouts inherited from 3d_armor_character.blend)
    import math
    from mathutils import Euler

    bpy.ops.wm.read_homefile(use_empty=False)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()

    with bpy.data.libraries.load(preview_blend, link=False) as (data_from, data_to):
        data_to.objects = data_from.objects
        data_to.materials = data_from.materials
        data_to.armatures = data_from.armatures
        data_to.meshes = data_from.meshes
        data_to.actions = data_from.actions

    for lib in list(bpy.data.libraries):
        bpy.data.libraries.remove(lib)

    for obj in data_to.objects:
        if obj:
            bpy.context.scene.collection.objects.link(obj)

    arm_saved = bpy.data.objects.get("Armature")
    player_saved = bpy.data.objects.get("Player")
    if arm_saved and player_saved:
        player_saved.parent = arm_saved
        for mod in player_saved.modifiers:
            if mod.type == "ARMATURE":
                mod.object = arm_saved

    set_viewport_material_shading()
    for area in bpy.context.screen.areas:
        if area.type == "VIEW_3D":
            for space in area.spaces:
                if space.type == "VIEW_3D":
                    r3d = space.region_3d
                    r3d.view_location = (0.0, 0.0, 8.4)
                    r3d.view_distance = 28.0
                    r3d.view_rotation = Euler((math.radians(65), 0, math.radians(-35)), "XYZ").to_quaternion()

    bpy.ops.wm.save_as_mainfile(filepath=preview_blend)
    bpy.ops.file.make_paths_relative()
    bpy.ops.wm.save_as_mainfile(filepath=preview_blend)


def build_stand_models():
    # 1. Stand node model (clean 10-cuboid geometry with non-overlapping pixel-perfect UV mapping)
    bpy.ops.wm.read_homefile(use_empty=True)
    
    mesh = bpy.data.meshes.new("x_player_armor_stand")
    stand_obj = bpy.data.objects.new("x_player_armor_stand", mesh)
    bpy.context.scene.collection.objects.link(stand_obj)

    # Stand model stands upright in Z axis in Blender (Euler X = 90 deg, scale 1.0)
    import math
    stand_obj.rotation_euler = (math.pi / 2, 0, 0)

    bm = bmesh.new()
    uv_lay = bm.loops.layers.uv.new("UVMap")

    def add_cuboid(bm, uv_lay, bounds, uv_dict):
        xmin, xmax, ymin, ymax, zmin, zmax = bounds
        v = [
            bm.verts.new((xmin, ymin, zmin)),  # 0: back-left-bottom
            bm.verts.new((xmax, ymin, zmin)),  # 1: back-right-bottom
            bm.verts.new((xmax, ymax, zmin)),  # 2: back-right-top
            bm.verts.new((xmin, ymax, zmin)),  # 3: back-left-top
            bm.verts.new((xmin, ymin, zmax)),  # 4: front-left-bottom
            bm.verts.new((xmax, ymin, zmax)),  # 5: front-right-bottom
            bm.verts.new((xmax, ymax, zmax)),  # 6: front-right-top
            bm.verts.new((xmin, ymax, zmax)),  # 7: front-left-top
        ]
        faces_def = [
            # front (+Z local -> -Y world, facing South in Luanti, matching chestplate front)
            ("front",  (v[4], v[5], v[6], v[7]), ((0, 0), (1, 0), (1, 1), (0, 1))),
            # back (-Z local -> +Y world, facing North in Luanti)
            ("back",   (v[1], v[0], v[3], v[2]), ((0, 0), (1, 0), (1, 1), (0, 1))),
            # right (+X local -> +X world)
            ("right",  (v[5], v[1], v[2], v[6]), ((0, 0), (1, 0), (1, 1), (0, 1))),
            # left (-X local -> -X world)
            ("left",   (v[0], v[4], v[7], v[3]), ((0, 0), (1, 0), (1, 1), (0, 1))),
            # top (+Y local -> +Z world, Up)
            ("top",    (v[7], v[6], v[2], v[3]), ((0, 1), (1, 1), (1, 0), (0, 0))),
            # bottom (-Y local -> -Z world, Down)
            ("bottom", (v[4], v[0], v[1], v[5]), ((0, 1), (0, 0), (1, 0), (1, 1))),
        ]
        for name, face_verts, uv_corners in faces_def:
            if name in uv_dict:
                x0, y0, x1, y1 = uv_dict[name]
                u0, v0, u1, v1 = x0 / 64.0, y0 / 64.0, x1 / 64.0, y1 / 64.0
                f = bm.faces.new(face_verts)
                for l, (uc, vc) in zip(f.loops, uv_corners):
                    u = u0 if uc == 0 else u1
                    v_coord = v0 if vc == 0 else v1
                    l[uv_lay].uv = (u, v_coord)

    # 10 stand cuboid parts matching character sizing and posture:
    parts = [
        # 1. Base slab (16x1x16 px)
        ("base", (-5.0, 5.0, -5.0, -4.375, -5.0, 5.0), {
            "top":    (0, 48, 16, 64),
            "bottom": (16, 48, 32, 64),
            "front":  (0, 46, 16, 48),
            "right":  (16, 46, 32, 48),
            "back":   (32, 46, 48, 48),
            "left":   (48, 46, 64, 48),
        }),
        # 2. Left Leg post (2x9x2 px)
        ("left_leg", (-1.875, -0.625, -4.375, 1.25, -0.625, 0.625), {
            "front":  (0, 2, 2, 11),
            "right":  (2, 2, 4, 11),
            "back":   (4, 2, 6, 11),
            "left":   (6, 2, 8, 11),
            "bottom": (0, 0, 2, 2),
        }),
        # 3. Right Leg post (2x9x2 px)
        ("right_leg", (0.625, 1.875, -4.375, 1.25, -0.625, 0.625), {
            "front":  (10, 2, 12, 11),
            "right":  (12, 2, 14, 11),
            "back":   (14, 2, 16, 11),
            "left":   (16, 2, 18, 11),
            "bottom": (10, 0, 12, 2),
        }),
        # 4. Hip Crossbar (6x2x2 px)
        ("hip", (-1.875, 1.875, 1.25, 2.50, -0.625, 0.625), {
            "front":  (30, 38, 36, 40),
            "back":   (36, 38, 42, 40),
            "top":    (30, 40, 36, 42),
            "bottom": (36, 40, 42, 42),
            "left":   (42, 38, 44, 40),
            "right":  (44, 38, 46, 40),
        }),
        # 5. Left Torso post (2x7x2 px)
        ("left_torso", (-1.875, -0.625, 2.50, 6.875, -0.625, 0.625), {
            "front":  (10, 28, 12, 35),
            "right":  (12, 28, 14, 35),
            "back":   (14, 28, 16, 35),
            "left":   (16, 28, 18, 35),
        }),
        # 6. Right Torso post (2x7x2 px)
        ("right_torso", (0.625, 1.875, 2.50, 6.875, -0.625, 0.625), {
            "front":  (20, 28, 22, 35),
            "right":  (22, 28, 24, 35),
            "back":   (24, 28, 26, 35),
            "left":   (26, 28, 28, 35),
        }),
        # 7. Shoulder Crossbar (12x2x2 px)
        ("shoulder", (-3.750, 3.750, 6.875, 8.125, -0.625, 0.625), {
            "front":  (0, 38, 12, 40),
            "back":   (12, 38, 24, 40),
            "top":    (0, 40, 12, 42),
            "bottom": (12, 40, 24, 42),
            "left":   (24, 38, 26, 40),
            "right":  (26, 38, 28, 40),
        }),
        # 8. Neck / Head Peg (2x7x2 px)
        ("neck", (-0.625, 0.625, 8.125, 12.50, -0.625, 0.625), {
            "front":  (0, 28, 2, 35),
            "right":  (2, 28, 4, 35),
            "back":   (4, 28, 6, 35),
            "left":   (6, 28, 8, 35),
            "top":    (0, 35, 2, 37),
        }),
        # 9. Left Arm Stick (2x8x2 px)
        ("left_arm", (-3.750, -2.500, 1.875, 6.875, -0.625, 0.625), {
            "front":  (0, 16, 2, 24),
            "right":  (2, 16, 4, 24),
            "back":   (4, 16, 6, 24),
            "left":   (6, 16, 8, 24),
            "bottom": (0, 24, 2, 26),
        }),
        # 10. Right Arm Stick (2x8x2 px)
        ("right_arm", (2.500, 3.750, 1.875, 6.875, -0.625, 0.625), {
            "front":  (10, 16, 12, 24),
            "right":  (12, 16, 14, 24),
            "back":   (14, 16, 16, 24),
            "left":   (16, 16, 18, 24),
            "bottom": (10, 24, 12, 26),
        }),
    ]

    for _, bounds, uvs in parts:
        add_cuboid(bm, uv_lay, bounds, uvs)

    bm.to_mesh(mesh)
    mesh.update()
    bm.free()

    for p in mesh.polygons:
        p.use_smooth = False

    mat = bpy.data.materials.new(name="Stand")
    setup_material_texture(mat, "../textures/x_player_armor_stand_shared.png", ASSETS_DIR)
    stand_obj.data.materials.append(mat)

    set_viewport_material_shading()
    from mathutils import Euler
    for area in bpy.context.screen.areas:
        if area.type == "VIEW_3D":
            for space in area.spaces:
                if space.type == "VIEW_3D":
                    r3d = space.region_3d
                    r3d.view_location = (0.0, 0.0, 3.75)
                    r3d.view_distance = 25.0
                    r3d.view_rotation = Euler((math.radians(65), 0, math.radians(-35)), "XYZ").to_quaternion()

    stand_blend = os.path.join(ASSETS_DIR, "x_player_armor_stand.blend")
    bpy.ops.wm.save_as_mainfile(filepath=stand_blend)
    bpy.ops.file.make_paths_relative()
    bpy.ops.wm.save_as_mainfile(filepath=stand_blend)

    stand_glb = os.path.join(MODELS_DIR, "x_player_armor_stand.glb")
    bpy.ops.export_scene.gltf(filepath=stand_glb, export_format="GLB", export_yup=True)
    patch_glb_materials(stand_glb)
    print(f"Exported stand: blend={os.path.getsize(stand_blend)}B, glb={os.path.getsize(stand_glb)}B ({len(mesh.polygons)} polygons)")


if __name__ == "__main__":
    build_armor_models()
    build_stand_models()
    print("All individual 3D models and Blender source files successfully built.")
