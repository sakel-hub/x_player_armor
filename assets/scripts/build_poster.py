#!/usr/bin/env python3
"""
Automated Poster Scene Builder for x_player_armor
Creates a showcase studio scene featuring:
  - Hero player character in Diamond Armor with Diamond Shield & Diamond Sword in an epic hero pose.
  - Armor stand displaying a Gold Armor set with Gold Shield & Steel Sword.
  - Dual-pedestal display dais with glowing tier-colored accent rings (Diamond Cyan & Gold).
  - Smooth 95-unit wide studio cyclorama backdrop.
  - 6-point studio lighting rig with sun key, directional area lights, cool fill, dual rim lights, and tier floor accents.
  - 1920x1080 cinematic camera setup with 44mm focal length, generous headroom/footroom, and subtle depth of field.
  - Crisp pixel-art texture filtering with PBR metallic/roughness material shaders.

Saves:
  - assets/x_player_armor_poster.blend
  - assets/x_player_armor_poster.png (1920x1080 promotional poster render)
"""

import os
import math
import bpy
import bmesh
from mathutils import Vector, Euler

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
MOD_DIR = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))
ASSETS_DIR = os.path.join(MOD_DIR, "assets")
TEXTURES_DIR = os.path.join(MOD_DIR, "textures")

PREVIEW_BLEND = os.path.join(ASSETS_DIR, "x_player_armor_preview.blend")
STAND_BLEND = os.path.join(ASSETS_DIR, "x_player_armor_stand.blend")
POSTER_BLEND = os.path.join(ASSETS_DIR, "x_player_armor_poster.blend")
POSTER_PNG = os.path.join(ASSETS_DIR, "x_player_armor_poster.png")


def create_pbr_material(name, tex_path, metallic=0.0, roughness=0.5, specular=0.5, alpha_clip=True, is_transparent=False, emissive_color=None, emissive_strength=0.0):
    """
    Creates a PBR material with Closest interpolation for crisp pixel art,
    accurate metallic/roughness response, and proper alpha cutout / transparency.
    """
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    node_out = nodes.new(type="ShaderNodeOutputMaterial")
    node_out.location = (400, 0)

    node_bsdf = nodes.new(type="ShaderNodeBsdfPrincipled")
    node_bsdf.location = (50, 0)

    if "Metallic" in node_bsdf.inputs:
        node_bsdf.inputs["Metallic"].default_value = metallic
    if "Roughness" in node_bsdf.inputs:
        node_bsdf.inputs["Roughness"].default_value = roughness
    if "Specular IOR Level" in node_bsdf.inputs:
        node_bsdf.inputs["Specular IOR Level"].default_value = specular
    elif "Specular" in node_bsdf.inputs:
        node_bsdf.inputs["Specular"].default_value = specular

    if emissive_color and emissive_strength > 0.0:
        if "Emission Color" in node_bsdf.inputs:
            node_bsdf.inputs["Emission Color"].default_value = emissive_color
        elif "Emission" in node_bsdf.inputs:
            node_bsdf.inputs["Emission"].default_value = emissive_color
        if "Emission Strength" in node_bsdf.inputs:
            node_bsdf.inputs["Emission Strength"].default_value = emissive_strength

    if is_transparent:
        if "Alpha" in node_bsdf.inputs:
            node_bsdf.inputs["Alpha"].default_value = 0.0
        mat.blend_method = "CLIP"
        if hasattr(mat, "alpha_threshold"):
            mat.alpha_threshold = 0.5
        links.new(node_bsdf.outputs["BSDF"], node_out.inputs["Surface"])
        return mat

    if tex_path and os.path.exists(tex_path):
        img_name = os.path.basename(tex_path)
        existing = bpy.data.images.get(img_name)
        if existing and existing.size[0] > 0 and existing.size[1] > 0:
            img = existing
        else:
            if existing:
                bpy.data.images.remove(existing)
            img = bpy.data.images.load(filepath=tex_path)

        node_tex = nodes.new(type="ShaderNodeTexImage")
        node_tex.location = (-350, 0)
        node_tex.image = img
        node_tex.interpolation = "Closest"  # Crisp pixel art preservation

        links.new(node_tex.outputs["Color"], node_bsdf.inputs["Base Color"])

        if alpha_clip and "Alpha" in node_tex.outputs and "Alpha" in node_bsdf.inputs:
            node_round = nodes.new(type="ShaderNodeMath")
            node_round.location = (-120, -120)
            node_round.operation = "ROUND"
            links.new(node_tex.outputs["Alpha"], node_round.inputs[0])
            links.new(node_round.outputs[0], node_bsdf.inputs["Alpha"])
            mat.blend_method = "CLIP"
            if hasattr(mat, "alpha_threshold"):
                mat.alpha_threshold = 0.5
    else:
        if "Base Color" in node_bsdf.inputs:
            node_bsdf.inputs["Base Color"].default_value = (0.8, 0.8, 0.8, 1.0)

    links.new(node_bsdf.outputs["BSDF"], node_out.inputs["Surface"])
    return mat


def assign_materials_safely(obj, new_materials):
    """
    Assigns new materials to an object while preserving existing polygon material indices.
    Never calls materials.clear(), which would reset all polygon material indices to 0.
    """
    for i, mat in enumerate(new_materials):
        if i < len(obj.material_slots):
            obj.material_slots[i].material = mat
        else:
            obj.data.materials.append(mat)


def build_poster_scene():
    print("Initializing poster scene...")
    bpy.ops.wm.read_homefile(use_empty=True)

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1920
    scene.render.resolution_y = 1080
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"

    # Color management: Rich dynamic range with subtle punch
    scene.display_settings.display_device = "sRGB"
    transforms = [v.name for v in scene.view_settings.bl_rna.properties["view_transform"].enum_items]
    if "AgX" in transforms:
        scene.view_settings.view_transform = "AgX"
    elif "Filmic" in transforms:
        scene.view_settings.view_transform = "Filmic"

    looks = [l.name for l in scene.view_settings.bl_rna.properties["look"].enum_items]
    if "Medium Contrast" in looks:
        scene.view_settings.look = "Medium Contrast"
    elif "None" in looks:
        scene.view_settings.look = "None"
    scene.view_settings.exposure = -0.10

    # World background: Deep dark atmospheric navy studio gradient
    world = bpy.data.worlds.new("Poster_World")
    scene.world = world
    world.use_nodes = True
    wnodes = world.node_tree.nodes
    wlinks = world.node_tree.links
    wnodes.clear()
    w_out = wnodes.new("ShaderNodeOutputWorld")
    w_bg = wnodes.new("ShaderNodeBackground")
    w_bg.inputs["Color"].default_value = (0.012, 0.016, 0.028, 1.0)
    w_bg.inputs["Strength"].default_value = 0.35
    wlinks.new(w_bg.outputs["Background"], w_out.inputs["Surface"])

    # Master collections
    coll_hero = bpy.data.collections.new("Hero_Player")
    coll_stand = bpy.data.collections.new("Armor_Stand")
    coll_stage = bpy.data.collections.new("Stage_Environment")
    coll_lights = bpy.data.collections.new("Lighting_Rig")
    coll_cam = bpy.data.collections.new("Cameras")

    scene.collection.children.link(coll_hero)
    scene.collection.children.link(coll_stand)
    scene.collection.children.link(coll_stage)
    scene.collection.children.link(coll_lights)
    scene.collection.children.link(coll_cam)

    # ---------------------------------------------------------
    # 1. LOAD HERO CHARACTER (Diamond Armor + Shield + Sword)
    # ---------------------------------------------------------
    print("Loading Hero Character from preview.blend...")
    with bpy.data.libraries.load(PREVIEW_BLEND, link=False) as (df, dt):
        dt.objects = [o for o in df.objects if o in ("Armature", "Player")]
        dt.armatures = df.armatures
        dt.meshes = df.meshes

    hero_arm = None
    hero_player = None
    for obj in dt.objects:
        if obj.name == "Armature":
            hero_arm = obj
            hero_arm.name = "Hero_Armature"
            coll_hero.objects.link(hero_arm)
        elif obj.name == "Player":
            hero_player = obj
            hero_player.name = "Hero_Player"
            coll_hero.objects.link(hero_player)

    hero_player.parent = hero_arm
    for mod in hero_player.modifiers:
        if mod.type == "ARMATURE":
            mod.object = hero_arm

    # Textures
    tex_char = os.path.join(TEXTURES_DIR, "x_player_armor_character.png")
    tex_diamond = os.path.join(TEXTURES_DIR, "x_player_armor_diamond.png")
    tex_sword = os.path.join(ASSETS_DIR, "default_tool_diamondsword.png")
    if not os.path.exists(tex_sword):
        tex_sword = os.path.join(TEXTURES_DIR, "x_player_armor_diamond.png")

    mat_hero_body = create_pbr_material("Hero_Body", tex_char, metallic=0.0, roughness=0.75, specular=0.3)
    mat_hero_helmet = create_pbr_material("Hero_Helmet", tex_diamond, metallic=0.70, roughness=0.42, specular=0.5)
    mat_hero_torso = create_pbr_material("Hero_Chestplate", tex_diamond, metallic=0.70, roughness=0.42, specular=0.5)
    mat_hero_legs = create_pbr_material("Hero_Leggings", tex_diamond, metallic=0.70, roughness=0.42, specular=0.5)
    mat_hero_feet = create_pbr_material("Hero_Boots", tex_diamond, metallic=0.70, roughness=0.42, specular=0.5)
    mat_hero_shield = create_pbr_material("Hero_Shield", tex_diamond, metallic=0.70, roughness=0.42, specular=0.5)
    mat_hero_tower = create_pbr_material("Hero_Tower_Shield", None, is_transparent=True)
    mat_hero_sword = create_pbr_material("Hero_Sword", tex_sword, metallic=0.80, roughness=0.38, specular=0.6)

    hero_mats = [
        mat_hero_body,      # 0 Body
        mat_hero_helmet,    # 1 Head
        mat_hero_torso,     # 2 Torso
        mat_hero_legs,      # 3 Legs
        mat_hero_feet,      # 4 Feet
        mat_hero_shield,    # 5 Shield_Standard
        mat_hero_tower,     # 6 Shield_Tower (transparent)
        mat_hero_sword,     # 7 Wielditem (Diamond Sword)
    ]
    assign_materials_safely(hero_player, hero_mats)

    # Hero Pose & Placement: Left side of camera view (+X in world), forward in Y
    hero_pos = Vector((6.0, 1.2, 10.9))
    hero_arm.location = hero_pos
    # Face slightly towards center (+Y and slightly towards -X)
    hero_arm.rotation_euler = Euler((0.0, 0.0, math.radians(-10)), "XYZ")
    hero_arm.data.pose_position = "POSE"

    pb = hero_arm.pose.bones
    for name in ("Body", "Head", "Arm_Left", "Arm_Right", "Leg_Left", "Leg_Right"):
        pb[name].rotation_mode = "XYZ"

    # Torso: proud, upright stance
    pb["Body"].rotation_euler = Euler((math.radians(1), 0.0, math.radians(-3)), "XYZ")
    # Head: confident, direct hero gaze towards camera
    pb["Head"].rotation_euler = Euler((math.radians(-3), math.radians(1), math.radians(8)), "XYZ")
    # Left Arm (Shield): angled slightly lower and outward, revealing chestplate while presenting diamond shield
    pb["Arm_Left"].rotation_euler = Euler((math.radians(16), math.radians(48), math.radians(16)), "XYZ")
    # Right Arm (Sword): angled down-back and outward, displaying diamond sword
    pb["Arm_Right"].rotation_euler = Euler((math.radians(-16), math.radians(10), math.radians(-12)), "XYZ")
    # Legs: wide, solid hero stance
    pb["Leg_Left"].rotation_euler = Euler((math.radians(-4), 0.0, math.radians(-3)), "XYZ")
    pb["Leg_Right"].rotation_euler = Euler((math.radians(6), 0.0, math.radians(4)), "XYZ")

    print(f"Hero loaded and posed at {hero_arm.location}.")

    # ---------------------------------------------------------
    # 2. LOAD ARMOR STAND (Wooden Stand + Gold Armor Mannequin)
    # ---------------------------------------------------------
    print("Loading Armor Stand from stand.blend...")
    with bpy.data.libraries.load(STAND_BLEND, link=False) as (df, dt):
        dt.objects = [o for o in df.objects if o == "x_player_armor_stand"]
        dt.meshes = df.meshes

    stand_obj = dt.objects[0]
    stand_obj.name = "Showcase_Stand"
    coll_stand.objects.link(stand_obj)

    tex_stand_wood = os.path.join(TEXTURES_DIR, "x_player_armor_stand_shared.png")
    mat_stand = create_pbr_material("Stand_Wood", tex_stand_wood, metallic=0.0, roughness=0.85, specular=0.25)
    stand_obj.data.materials.clear()
    stand_obj.data.materials.append(mat_stand)

    # Stand position: Right side of camera view (-X in world), slightly back in Y
    stand_pos = Vector((-5.8, -0.6, 5.0))
    stand_obj.location = stand_pos
    # Stand rotated 18 degrees towards center and camera
    stand_obj.rotation_euler = Euler((math.pi / 2, 0.0, math.radians(180 + 18)), "XYZ")

    # Load second preview mannequin for the armor stand
    print("Loading Stand Mannequin from preview.blend...")
    with bpy.data.libraries.load(PREVIEW_BLEND, link=False) as (df, dt):
        dt.objects = [o for o in df.objects if o in ("Armature", "Player")]
        dt.armatures = df.armatures
        dt.meshes = df.meshes

    stand_arm = None
    stand_mannequin = None
    for obj in dt.objects:
        if obj.name.startswith("Armature"):
            stand_arm = obj
            stand_arm.name = "Stand_Armature"
            coll_stand.objects.link(stand_arm)
        elif obj.name.startswith("Player"):
            stand_mannequin = obj
            stand_mannequin.name = "Stand_Mannequin"
            coll_stand.objects.link(stand_mannequin)

    stand_mannequin.parent = stand_arm
    for mod in stand_mannequin.modifiers:
        if mod.type == "ARMATURE":
            mod.object = stand_arm

    # Materials for Stand: Gold Armor + Steel Sword + Transparent Body
    tex_gold = os.path.join(TEXTURES_DIR, "x_player_armor_gold.png")
    tex_steel_sword = os.path.join(ASSETS_DIR, "default_tool_steelsword.png")
    if not os.path.exists(tex_steel_sword):
        tex_steel_sword = os.path.join(TEXTURES_DIR, "x_player_armor_steel.png")

    mat_stand_body = create_pbr_material("Stand_Body_Clear", None, is_transparent=True)
    mat_stand_helmet = create_pbr_material("Stand_Helmet_Gold", tex_gold, metallic=0.82, roughness=0.40, specular=0.6)
    mat_stand_torso = create_pbr_material("Stand_Torso_Gold", tex_gold, metallic=0.82, roughness=0.40, specular=0.6)
    mat_stand_legs = create_pbr_material("Stand_Legs_Gold", tex_gold, metallic=0.82, roughness=0.40, specular=0.6)
    mat_stand_feet = create_pbr_material("Stand_Feet_Gold", tex_gold, metallic=0.82, roughness=0.40, specular=0.6)
    mat_stand_shield = create_pbr_material("Stand_Shield_Gold", tex_gold, metallic=0.82, roughness=0.40, specular=0.6)
    mat_stand_tower = create_pbr_material("Stand_Tower_Clear", None, is_transparent=True)
    mat_stand_sword = create_pbr_material("Stand_Sword_Steel", tex_steel_sword, metallic=0.80, roughness=0.42, specular=0.5)

    stand_mats = [
        mat_stand_body,     # 0 Body (Transparent - reveals wooden frame!)
        mat_stand_helmet,   # 1 Head
        mat_stand_torso,    # 2 Torso
        mat_stand_legs,     # 3 Legs
        mat_stand_feet,     # 4 Feet
        mat_stand_shield,   # 5 Shield_Standard
        mat_stand_tower,    # 6 Shield_Tower (Transparent)
        mat_stand_sword,    # 7 Wielditem (Steel Sword)
    ]
    assign_materials_safely(stand_mannequin, stand_mats)

    # Adjust wield item mesh on Stand Mannequin so sword emerges cleanly from the wooden hand:
    # The wooden stand arm is narrower in depth than the player character arm and pitched downward,
    # so shift Slot 7 wield vertices forward along +Y and down in Z to match the wooden hand's grip position.
    wield_v_indices = set()
    for p in stand_mannequin.data.polygons:
        if p.material_index == 7:
            for v in p.vertices:
                wield_v_indices.add(v)

    delta_stand_wield = Vector((0.0, 1.20, -0.25))
    for i in wield_v_indices:
        stand_mannequin.data.vertices[i].co += delta_stand_wield
    stand_mannequin.data.update()

    # Align mannequin exactly with stand base slab (slab top Z = 5.0 - 4.375 = 0.625)
    stand_arm.location = Vector((-5.8, -0.6, 0.625 + 10.9))
    stand_arm.rotation_euler = Euler((0.0, 0.0, math.radians(18)), "XYZ")
    stand_arm.data.pose_position = "POSE"

    pb_s = stand_arm.pose.bones
    for name in ("Body", "Head", "Arm_Left", "Arm_Right", "Leg_Left", "Leg_Right"):
        pb_s[name].rotation_mode = "XYZ"

    # Upright museum display posture for stand
    pb_s["Body"].rotation_euler = Euler((0.0, 0.0, 0.0), "XYZ")
    pb_s["Head"].rotation_euler = Euler((0.0, 0.0, 0.0), "XYZ")
    # Left Arm: angle shield slightly forward to catch the light
    pb_s["Arm_Left"].rotation_euler = Euler((math.radians(14), math.radians(35), math.radians(8)), "XYZ")
    # Right Arm: angled slightly forward holding the steel sword
    pb_s["Arm_Right"].rotation_euler = Euler((math.radians(-8), 0.0, 0.0), "XYZ")
    pb_s["Leg_Left"].rotation_euler = Euler((0.0, 0.0, 0.0), "XYZ")
    pb_s["Leg_Right"].rotation_euler = Euler((0.0, 0.0, 0.0), "XYZ")

    print(f"Stand and mannequin loaded at {stand_pos}.")

    # ---------------------------------------------------------
    # 3. STAGE ENVIRONMENT (Wide Beveled Podium & Backdrop)
    # ---------------------------------------------------------
    print("Constructing Stage Environment...")

    # Main Podium: Wide elliptical display plinth
    mesh_podium = bpy.data.meshes.new("Stage_Podium")
    obj_podium = bpy.data.objects.new("Stage_Podium", mesh_podium)
    coll_stage.objects.link(obj_podium)

    bm_podium = bmesh.new()
    rad_x_base, rad_y_base = 22.0, 14.0
    rad_x_top, rad_y_top = 21.0, 13.0
    h_podium = 0.90
    segments = 48

    b_verts = []
    t_verts = []
    for i in range(segments):
        ang = (2 * math.pi * i) / segments
        bx = rad_x_base * math.cos(ang)
        by = rad_y_base * math.sin(ang)
        tx = rad_x_top * math.cos(ang)
        ty = rad_y_top * math.sin(ang)
        b_verts.append(bm_podium.verts.new((bx, by, -h_podium)))
        t_verts.append(bm_podium.verts.new((tx, ty, 0.0)))

    vc_bot = bm_podium.verts.new((0.0, 0.0, -h_podium))
    vc_top = bm_podium.verts.new((0.0, 0.0, 0.0))

    for i in range(segments):
        i_next = (i + 1) % segments
        bm_podium.faces.new((vc_bot, b_verts[i_next], b_verts[i]))
        bm_podium.faces.new((vc_top, t_verts[i], t_verts[i_next]))
        bm_podium.faces.new((b_verts[i], b_verts[i_next], t_verts[i_next], t_verts[i]))

    bm_podium.to_mesh(mesh_podium)
    mesh_podium.update()
    bm_podium.free()

    mat_podium = bpy.data.materials.new("Stage_Slate")
    mat_podium.use_nodes = True
    p_nodes = mat_podium.node_tree.nodes
    p_links = mat_podium.node_tree.links
    p_nodes.clear()
    p_out = p_nodes.new("ShaderNodeOutputMaterial")
    p_bsdf = p_nodes.new("ShaderNodeBsdfPrincipled")
    p_bsdf.inputs["Base Color"].default_value = (0.045, 0.05, 0.07, 1.0)
    p_bsdf.inputs["Roughness"].default_value = 0.45
    p_bsdf.inputs["Metallic"].default_value = 0.20
    p_links.new(p_bsdf.outputs["BSDF"], p_out.inputs["Surface"])
    obj_podium.data.materials.append(mat_podium)

    # Glowing Accent Pedestal Rings
    def create_accent_ring(name, center_x, center_y, radius, color):
        m = bpy.data.meshes.new(name)
        o = bpy.data.objects.new(name, m)
        coll_stage.objects.link(o)
        bm = bmesh.new()
        r_inner = radius * 0.94
        r_outer = radius
        seg = 36
        v_in, v_out = [], []
        for i in range(seg):
            a = (2 * math.pi * i) / seg
            v_in.append(bm.verts.new((center_x + r_inner * math.cos(a), center_y + r_inner * math.sin(a), 0.02)))
            v_out.append(bm.verts.new((center_x + r_outer * math.cos(a), center_y + r_outer * math.sin(a), 0.02)))
        for i in range(seg):
            i_n = (i + 1) % seg
            bm.faces.new((v_in[i], v_out[i], v_out[i_n], v_in[i_n]))
        bm.to_mesh(m)
        m.update()
        bm.free()

        mat = create_pbr_material(f"{name}_Mat", None, metallic=0.0, roughness=0.3, emissive_color=color, emissive_strength=3.0)
        if "Base Color" in mat.node_tree.nodes["Principled BSDF"].inputs:
            mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = color
        o.data.materials.append(mat)
        return o

    # Hero cyan accent ring (radius 5.6) & Stand gold accent ring (radius 7.2)
    create_accent_ring("Hero_Accent_Ring", 6.0, 1.2, 5.6, (0.2, 0.8, 1.0, 1.0))
    create_accent_ring("Stand_Accent_Ring", -5.8, -0.6, 7.2, (1.0, 0.82, 0.25, 1.0))

    # Cyclorama Curved Studio Backdrop (95 units wide, fully filling widescreen FOV)
    mesh_cyc = bpy.data.meshes.new("Studio_Cyclorama")
    obj_cyc = bpy.data.objects.new("Studio_Cyclorama", mesh_cyc)
    coll_stage.objects.link(obj_cyc)

    bm_cyc = bmesh.new()
    width_cyc = 95.0
    cyc_points = []
    cyc_subdivs = 28
    for i in range(cyc_subdivs + 1):
        t = i / cyc_subdivs
        y_pos = -8.0 - 22.0 * t
        z_pos = 45.0 * (t ** 2.2)
        v_left = bm_cyc.verts.new((-width_cyc / 2, y_pos, z_pos))
        v_right = bm_cyc.verts.new((width_cyc / 2, y_pos, z_pos))
        cyc_points.append((v_left, v_right))

    for i in range(cyc_subdivs):
        v_l0, v_r0 = cyc_points[i]
        v_l1, v_r1 = cyc_points[i + 1]
        bm_cyc.faces.new((v_l0, v_r0, v_r1, v_l1))

    bm_cyc.to_mesh(mesh_cyc)
    mesh_cyc.update()
    bm_cyc.free()

    for p in mesh_cyc.polygons:
        p.use_smooth = True

    mat_cyc = bpy.data.materials.new("Studio_Backdrop")
    mat_cyc.use_nodes = True
    c_nodes = mat_cyc.node_tree.nodes
    c_links = mat_cyc.node_tree.links
    c_nodes.clear()
    c_out = c_nodes.new("ShaderNodeOutputMaterial")
    c_bsdf = c_nodes.new("ShaderNodeBsdfPrincipled")
    c_bsdf.inputs["Base Color"].default_value = (0.012, 0.016, 0.028, 1.0)
    c_bsdf.inputs["Roughness"].default_value = 0.95
    c_bsdf.inputs["Metallic"].default_value = 0.0
    c_links.new(c_bsdf.outputs["BSDF"], c_out.inputs["Surface"])
    obj_cyc.data.materials.append(mat_cyc)

    # ---------------------------------------------------------
    # 4. LIGHTING RIG (Studio Sun + Key + Fill + Dual Rim + Overhead)
    # ---------------------------------------------------------
    print("Setting up professional lighting rig...")

    # Sun Light: Soft ambient key illumination (subtle warm directional fill)
    light_sun_data = bpy.data.lights.new("Sun_Key", type="SUN")
    light_sun_data.energy = 1.0
    light_sun_data.color = (1.0, 0.98, 0.95)
    light_sun_data.angle = math.radians(16.0)
    obj_sun = bpy.data.objects.new("Sun_Key", light_sun_data)
    coll_lights.objects.link(obj_sun)
    obj_sun.location = Vector((8.0, 24.0, 26.0))
    dir_sun = Vector((-0.25, -0.85, -0.55))
    obj_sun.rotation_euler = dir_sun.to_track_quat("-Z", "Y").to_euler()

    # Key Area Light: Balanced soft illumination on Hero Diamond armor
    light_key_data = bpy.data.lights.new("Key_Hero", type="AREA")
    light_key_data.energy = 4500.0
    light_key_data.color = (1.0, 0.98, 0.95)
    light_key_data.size = 12.0
    light_key_data.shape = "RECTANGLE"
    light_key_data.size_y = 12.0
    obj_key = bpy.data.objects.new("Key_Hero", light_key_data)
    coll_lights.objects.link(obj_key)
    obj_key.location = Vector((16.0, 26.0, 20.0))
    dir_key = Vector((6.0, 1.2, 10.0)) - obj_key.location
    obj_key.rotation_euler = dir_key.to_track_quat("-Z", "Y").to_euler()

    # Fill Area Light: Soft gentle warm fill illuminating the Gold stand
    light_fill_data = bpy.data.lights.new("Fill_Stand", type="AREA")
    light_fill_data.energy = 3200.0
    light_fill_data.color = (1.0, 0.96, 0.92)
    light_fill_data.size = 14.0
    light_fill_data.size_y = 14.0
    obj_fill = bpy.data.objects.new("Fill_Stand", light_fill_data)
    coll_lights.objects.link(obj_fill)
    obj_fill.location = Vector((-16.0, 24.0, 18.0))
    dir_fill = Vector((-5.8, -0.6, 9.5)) - obj_fill.location
    obj_fill.rotation_euler = dir_fill.to_track_quat("-Z", "Y").to_euler()

    # Hero Rim Light: Crisp sparkling diamond rim from back-left
    light_rim1_data = bpy.data.lights.new("Hero_Rim", type="AREA")
    light_rim1_data.energy = 4800.0
    light_rim1_data.color = (0.88, 0.96, 1.0)
    light_rim1_data.size = 8.0
    light_rim1_data.size_y = 10.0
    obj_rim1 = bpy.data.objects.new("Hero_Rim", light_rim1_data)
    coll_lights.objects.link(obj_rim1)
    obj_rim1.location = Vector((14.0, -14.0, 16.0))
    dir_rim1 = Vector((6.0, 1.2, 11.0)) - obj_rim1.location
    obj_rim1.rotation_euler = dir_rim1.to_track_quat("-Z", "Y").to_euler()

    # Stand Rim Light: Warm golden rim from back-right
    light_rim2_data = bpy.data.lights.new("Stand_Rim", type="AREA")
    light_rim2_data.energy = 3800.0
    light_rim2_data.color = (1.0, 0.90, 0.70)
    light_rim2_data.size = 8.0
    light_rim2_data.size_y = 10.0
    obj_rim2 = bpy.data.objects.new("Stand_Rim", light_rim2_data)
    coll_lights.objects.link(obj_rim2)
    obj_rim2.location = Vector((-14.0, -14.0, 15.0))
    dir_rim2 = Vector((-5.8, -0.6, 9.5)) - obj_rim2.location
    obj_rim2.rotation_euler = dir_rim2.to_track_quat("-Z", "Y").to_euler()

    # Plinth Accent: Subtle ground bounce under the pedestal
    light_accent_data = bpy.data.lights.new("Plinth_Accent", type="POINT")
    light_accent_data.energy = 500.0
    light_accent_data.color = (0.35, 0.75, 1.0)
    obj_accent = bpy.data.objects.new("Plinth_Accent", light_accent_data)
    coll_lights.objects.link(obj_accent)
    obj_accent.location = Vector((0.0, 2.0, 1.2))

    # Overhead Soft Fill: Gentle, non-burning top illumination
    light_top_data = bpy.data.lights.new("Overhead_Fill", type="AREA")
    light_top_data.energy = 1000.0
    light_top_data.color = (0.92, 0.96, 1.0)
    light_top_data.size = 28.0
    light_top_data.size_y = 28.0
    obj_top = bpy.data.objects.new("Overhead_Fill", light_top_data)
    coll_lights.objects.link(obj_top)
    obj_top.location = Vector((0.0, 0.0, 26.0))
    dir_top = Vector((0.0, 0.0, -1.0))
    obj_top.rotation_euler = dir_top.to_track_quat("-Z", "Y").to_euler()

    # ---------------------------------------------------------
    # 5. CAMERA & CINEMATICS (1920x1080 44mm Showcase Lens)
    # ---------------------------------------------------------
    print("Configuring Poster Camera...")
    cam_data = bpy.data.cameras.new("Poster_Camera")
    cam_data.lens = 44.0  # Perfect showcase focal length, flattering 1920x1080 framing
    cam_data.sensor_width = 36.0
    cam_data.sensor_height = 20.25  # 16:9 native sensor

    # Depth of Field: Focused right on hero diamond chestplate
    cam_data.dof.use_dof = True
    cam_data.dof.focus_distance = 48.0
    cam_data.dof.aperture_fstop = 5.6

    cam_obj = bpy.data.objects.new("Poster_Camera", cam_data)
    coll_cam.objects.link(cam_obj)
    scene.camera = cam_obj

    # Position: Elevated portrait angle framing both hero and stand with generous headroom & plinth base
    cam_pos = Vector((0.0, 48.0, 11.2))
    target_pos = Vector((0.0, 0.0, 9.6))
    cam_obj.location = cam_pos
    dir_cam = target_pos - cam_pos
    cam_obj.rotation_euler = dir_cam.to_track_quat("-Z", "Y").to_euler()

    # Empty Focus Target for easy user adjustment in Blender GUI
    focus_empty = bpy.data.objects.new("Camera_Focus_Target", None)
    focus_empty.empty_display_type = "SPHERE"
    focus_empty.empty_display_size = 0.5
    focus_empty.location = Vector((6.0, 1.2, 10.5))
    coll_cam.objects.link(focus_empty)
    cam_data.dof.focus_object = focus_empty

    # ---------------------------------------------------------
    # 6. WORKSPACE VIEWPORT CONFIGURATION
    # ---------------------------------------------------------
    for window in bpy.context.window_manager.windows:
        for area in window.screen.areas:
            if area.type == "VIEW_3D":
                for space in area.spaces:
                    if space.type == "VIEW_3D":
                        space.shading.type = "MATERIAL"
                        space.region_3d.view_perspective = "CAMERA"

    # Save clean standalone .blend file
    print(f"Saving poster scene to {POSTER_BLEND}...")
    bpy.ops.wm.save_as_mainfile(filepath=POSTER_BLEND)
    bpy.ops.file.make_paths_relative()
    bpy.ops.wm.save_as_mainfile(filepath=POSTER_BLEND)

    blend_size = os.path.getsize(POSTER_BLEND)
    print(f"Poster blend file successfully created: {POSTER_BLEND} ({blend_size} bytes)")

    # ---------------------------------------------------------
    # 7. HIGH-RESOLUTION POSTER RENDER (1920x1080 PNG)
    # ---------------------------------------------------------
    print(f"Rendering 1920x1080 promotional screenshot to {POSTER_PNG}...")
    scene.render.filepath = POSTER_PNG
    bpy.ops.render.render(write_still=True)

    png_size = os.path.getsize(POSTER_PNG)
    print(f"Promotional poster screenshot rendered successfully: {POSTER_PNG} ({png_size} bytes)")


if __name__ == "__main__":
    build_poster_scene()
