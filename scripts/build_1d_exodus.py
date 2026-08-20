import gmsh
import sys
import numpy as np

gmsh.initialize()
gmsh.model.add("utilidor_1d")

gmsh.option.setNumber("Geometry.Tolerance", 1e-4)
gmsh.option.setNumber("Mesh.CharacteristicLengthMin", 0.02) 
gmsh.option.setNumber("Mesh.CharacteristicLengthMax", 1.0)

d, h, w, t, c = 5.0, 2.0, 2.0, 0.2, 0.05
bx, by, H_fill = w/2 + 5*w, -30.5, 4.0
eps = 0.02 

earth = gmsh.model.occ.addRectangle(-bx, 0, 0, 2*bx, by)
concrete = gmsh.model.occ.addRectangle(-w/2, -d, 0, w, -h)
void = gmsh.model.occ.addRectangle(-w/2+t, -d-t, 0, w-2*t, -(h-2*t))
gmsh.model.occ.cut([(2, concrete)], [(2, void)])

p100 = gmsh.model.occ.addPoint(-bx, -H_fill, 0)
p101 = gmsh.model.occ.addPoint(bx, -H_fill, 0)
slicer = gmsh.model.occ.addLine(p100, p101)

gmsh.model.occ.fragment([(2, earth), (2, concrete)], [(1, slicer)])

p20 = gmsh.model.occ.addPoint(-w/2+c, -d-c, 0)
p21 = gmsh.model.occ.addPoint(w/2-c, -d-c, 0)
p22 = gmsh.model.occ.addPoint(w/2-c, -d-h+c, 0)
p23 = gmsh.model.occ.addPoint(-w/2+c, -d-h+c, 0)
outer_rebar = [gmsh.model.occ.addLine(p20, p21), gmsh.model.occ.addLine(p21, p22), gmsh.model.occ.addLine(p22, p23), gmsh.model.occ.addLine(p23, p20)]

p30 = gmsh.model.occ.addPoint(-w/2+t-c, -d-t+c, 0)
p31 = gmsh.model.occ.addPoint(w/2-t+c, -d-t+c, 0)
p32 = gmsh.model.occ.addPoint(w/2-t+c, -d-h+t-c, 0)
p33 = gmsh.model.occ.addPoint(-w/2+t-c, -d-h+t-c, 0)
inner_rebar = [gmsh.model.occ.addLine(p30, p31), gmsh.model.occ.addLine(p31, p32), gmsh.model.occ.addLine(p32, p33), gmsh.model.occ.addLine(p33, p30)]

gmsh.model.occ.removeAllDuplicates()
gmsh.model.occ.synchronize()

def get_surfs(xmin, ymin, zmin, xmax, ymax, zmax):
    return [e[1] for e in gmsh.model.getEntitiesInBoundingBox(xmin, ymin, zmin, xmax, ymax, zmax, 2)]

concrete_surfs = get_surfs(-w/2-eps, -d-h-eps, -eps, w/2+eps, -d+eps, eps)
fill_surfs_all = get_surfs(-bx-eps, -H_fill-eps, -eps, bx+eps, eps, eps)
fill_surfs = [s for s in fill_surfs_all if s not in concrete_surfs]
native_surfs_all = get_surfs(-bx-eps, by-eps, -eps, bx+eps, -H_fill+eps, eps)
native_surfs = [s for s in native_surfs_all if s not in concrete_surfs]

gmsh.model.addPhysicalGroup(2, concrete_surfs, tag=1, name="concrete")
gmsh.model.addPhysicalGroup(2, fill_surfs, tag=2, name="fill")
gmsh.model.addPhysicalGroup(2, native_surfs, tag=3, name="native")

def get_curves(xmin, ymin, zmin, xmax, ymax, zmax):
    return [e[1] for e in gmsh.model.getEntitiesInBoundingBox(xmin, ymin, zmin, xmax, ymax, zmax, 1)]

outer_rebar_final = get_curves(-w/2+c-eps, -d-h+c-eps, -eps, w/2-c+eps, -d-c+eps, eps)
inner_rebar_final = get_curves(-w/2+t-c-eps, -d-h+t-c-eps, -eps, w/2-t+c+eps, -d-t+c+eps, eps)

gmsh.model.addPhysicalGroup(1, outer_rebar_final, tag=4, name="rebar_outer")
gmsh.model.addPhysicalGroup(1, inner_rebar_final, tag=5, name="rebar_inner")

for c_surf in concrete_surfs:
    gmsh.model.mesh.embed(1, outer_rebar_final + inner_rebar_final, 2, c_surf)

fine_mesh_points = gmsh.model.getEntitiesInBoundingBox(-w/2-eps, -d-h-eps, -eps, w/2+eps, -d+eps, eps, 0)
gmsh.model.mesh.setSize(fine_mesh_points, 0.05)
gmsh.model.mesh.generate(2)
gmsh.model.mesh.removeDuplicateNodes()
gmsh.option.setNumber("Mesh.Optimize", 1)
gmsh.write("utilidor_1d.msh")
gmsh.finalize()

# 6. EXODUS CONVERSION WITH DEGENERATE ELEMENT FILTER
try:
    import meshio
    print("\n--- Filtering and Mapping Exodus Blocks ---")
    msh = meshio.read("utilidor_1d.msh")

    target_tags = [1, 2, 3, 4, 5]
    tag_names = {1: "Concrete", 2: "Fill", 3: "Native", 4: "Rebar Outer", 5: "Rebar Inner"}
    
    new_cells = []
    current_block = 1
    
    for tag in target_tags:
        for i, cell_block in enumerate(msh.cells):
            if "gmsh:physical" not in msh.cell_data:
                continue
            phys_data = msh.cell_data["gmsh:physical"][i]
            mask = (phys_data == tag)
            if np.any(mask):
                elements = cell_block.data[mask]
                
                # ARRAY FILTER: Permanently drop zero-area elements with duplicate node IDs
                if cell_block.type == "triangle":
                    valid_mask = (elements[:, 0] != elements[:, 1]) & \
                                 (elements[:, 1] != elements[:, 2]) & \
                                 (elements[:, 0] != elements[:, 2])
                    elements = elements[valid_mask]
                elif cell_block.type == "line":
                    valid_mask = (elements[:, 0] != elements[:, 1])
                    elements = elements[valid_mask]
                
                if len(elements) > 0:
                    new_cells.append(meshio.CellBlock(cell_block.type, elements))
                    print(f"Mapped {tag_names[tag]:<15} -> Exodus Block ID: {current_block} (Valid elements: {len(elements)})")
                    current_block += 1
                
    clean_mesh = meshio.Mesh(points=msh.points, cells=new_cells)
    meshio.write("utilidor_1d.e", clean_mesh)
    print("Exodus file 'utilidor_1d.e' generated successfully. Degenerate topological slivers completely purged.")
except ImportError:
    print("Error: meshio not installed.")
    sys.exit(1)