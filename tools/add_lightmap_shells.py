"""Wire the meshes from tools/bake_csg_shells.gd into scenes/world.tscn:
stop each CSG shell from drawing (render layers 0, no shadow; it keeps its
collision and its children stay visible, which `visible = false` would hide)
and add a MeshInstance3D twin with the baked UV2 mesh. Idempotent; run once after adding a shell."""
import re, random, sys

SCENE = "scenes/world.tscn"
SHELLS = [
    "celing", "celing2", "hallway", "studio", "gallery", "hall of fame",
    "AssistantStudio/CSGCombiner3D", "hvac group/CSGCombiner3D", "greenhouse/CSGCombiner3D",
    "gallery/NavigationRegion3D/floor", "gallery/NavigationRegion3D/pedestal",
    "gallery/NavigationRegion3D/pedestal2", "gallery/NavigationRegion3D/pedestal3",
    "gallery/NavigationRegion3D/CSGBox3D", "gallery/NavigationRegion3D/wall south",
    "gallery/NavigationRegion3D/wall g2 south", "gallery/NavigationRegion3D/wall g2 south3",
    "gallery/NavigationRegion3D/wall g2 south4", "gallery/NavigationRegion3D/wall west",
    "gallery/NavigationRegion3D/wall east", "gallery/NavigationRegion3D/wall north",
]

lines = open(SCENE).read().split("\n")

def find_block(path):
    parent, _, name = path.rpartition("/")
    parent = parent or "."
    pat = re.compile(r'^\[node name="%s" type="CSG\w+" parent="%s"' % (re.escape(name), re.escape(parent)))
    for i, l in enumerate(lines):
        if pat.match(l):
            j = i + 1
            while j < len(lines) and lines[j].strip() != "" and not lines[j].startswith("["):
                j += 1
            return i, j
    sys.exit("not found: " + path)

new_ext, new_nodes = [], []
for path in SHELLS:
    fname = path.replace("/", "_").replace(" ", "_")
    rid = "lm_" + fname
    mesh_name = path.rpartition("/")[2] + " (baked)"
    parent = path.rpartition("/")[0] or "."
    if any(('id="%s"' % rid) in l for l in lines):
        continue
    i, j = find_block(path)
    block = lines[i + 1:j]
    xf = next((l for l in block if l.startswith("transform = ")), None)
    for prop in ("layers = 0", "cast_shadow = 0"):
        if not any(l.startswith(prop.split(" =")[0] + " = ") for l in block):
            lines.insert(j, prop)
    new_ext.append('[ext_resource type="ArrayMesh" path="res://scenes/world_lightmap/%s.res" id="%s"]' % (fname, rid))
    node = ['[node name="%s" type="MeshInstance3D" parent="%s" unique_id=%d]' % (mesh_name, parent, random.randint(10**8, 2 * 10**9))]
    if xf:
        node.append(xf)
    node += ['mesh = ExtResource("%s")' % rid, ""]
    new_nodes += node

if new_ext:
    last_ext = max(i for i, l in enumerate(lines) if l.startswith("[ext_resource"))
    lines[last_ext + 1:last_ext + 1] = new_ext
    first_tail = next(i for i, l in enumerate(lines) if l.startswith("[connection") or l.startswith("[editable"))
    lines[first_tail:first_tail] = new_nodes
open(SCENE, "w").write("\n".join(lines))
print("added", len(new_ext), "shells")
