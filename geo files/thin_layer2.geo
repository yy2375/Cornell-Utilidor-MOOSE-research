// Multi-Layer NYC Utilidor: BONDED CONTINUUM WITH THIN INTERFACE LAYER
// Configuration: Rigid Steel Trench Scenario B + Shallow Trench / Deep Subgrade
// Kernel: OpenCASCADE

SetFactory("OpenCASCADE");
Mesh.Algorithm = 6;

// ==========================================
// 1. PARAMETERS
// ==========================================
d  = 1.0;
h  = 2.0;
w  = 2.0;
t  = 0.2;
by = -30.5;
far_x = 15.0;

ci = 0.05; // thin bonded continuum interface thickness

eps = 1e-3;

ws = 0.5;
tx1 = -w/2 - ws;
tx2 =  w/2 + ws;
tw_total = tx2 - tx1;

// Interface outer envelope
ix1 = -w/2 - ci;
ix2 =  w/2 + ci;
iy_top = -d + ci;
iy_bot = -d - h - ci;
iw = ix2 - ix1;
ih = iy_top - iy_bot;

// ==========================================
// 2. BUILD SOIL CONTINUUM AND BACKFILL LAYERS
// ==========================================
Rectangle(1) = {-far_x, by, 0, 2*far_x, -by};

// Make backfill depth dynamic so it aligns with the bottom of the utilidor interface
layer_top_h = d / 5;
layer_bot_h = (h + ci) / 10;

For i In {1:15}
  If (i <= 5)
    layer_h = layer_top_h;
    y_start = -(i-1) * layer_h;
  Else
    layer_h = layer_bot_h;
    y_start = -d - (i-6) * layer_h;
  EndIf
  Rectangle(100+i) = {tx1, y_start, 0, tw_total, -layer_h};
EndFor

BooleanFragments{ Surface{1, 101:115}; Delete; }{}

// Punch a larger hole for concrete + interface
Rectangle(900) = {ix1, iy_top, 0, iw, -ih};
soil_precut[] = Surface In BoundingBox{-far_x-eps, by-eps, -eps, far_x+eps, eps, eps};
BooleanDifference{ Surface{soil_precut[]}; Delete; }{ Surface{900}; Delete; }

// ==========================================
// 3. BUILD THIN INTERFACE LAYER
// ==========================================
Rectangle(920) = {ix1, iy_top, 0, iw, -ih};
Rectangle(921) = {-w/2, -d, 0, w, -h};
BooleanDifference(1200) = { Surface{920}; Delete; }{ Surface{921}; Delete; };

// ==========================================
// 4. BUILD UTILIDOR CONCRETE
// ==========================================
Rectangle(2) = {-w/2, -d, 0, w, -h};
Rectangle(3) = {-w/2+t, -d-t, 0, w-2*t, -(h-2*t)};
BooleanDifference(11) = { Surface{2}; Delete; }{ Surface{3}; Delete; };

// Final fragment makes bonded/shared-node interfaces
model_surfs[] = Surface In BoundingBox{-far_x-eps, by-eps, -eps, far_x+eps, eps, eps};
BooleanFragments{ Surface{model_surfs[]}; Delete; }{}

// ==========================================
// 5. PHYSICAL SURFACES
// ==========================================
concrete_surfs[] = Surface In BoundingBox{-w/2-eps, -d-h-eps, -eps, w/2+eps, -d+eps, eps};
Physical Surface("concrete", 1) = concrete_surfs[];

interface_surfs[] = Surface In BoundingBox{ix1-eps, iy_bot-eps, -eps, ix2+eps, iy_top+eps, eps};
interface_surfs[] -= concrete_surfs[];
Physical Surface("interface", 2) = interface_surfs[];

// Backfill layers
For i In {1:15}
  If (i <= 5)
    layer_h = layer_top_h;
    y_top = -(i-1) * layer_h;
    y_bot = -i * layer_h;
  Else
    layer_h = layer_bot_h;
    y_top = -d - (i-6) * layer_h;
    y_bot = -d - (i-5) * layer_h;
  EndIf

  layer_surfs[] = Surface In BoundingBox{tx1-eps, y_bot-eps, -eps, tx2+eps, y_top+eps, eps};
  layer_surfs[] -= concrete_surfs[];
  layer_surfs[] -= interface_surfs[];
  Physical Surface(Sprintf("layer_%g", i), 100+i) = layer_surfs[];
EndFor

// Native soil
base_surfs[] = Surface In BoundingBox{-far_x-eps, by-eps, -eps, far_x+eps, eps, eps};
base_surfs[] -= concrete_surfs[];
base_surfs[] -= interface_surfs[];

For i In {1:15}
  If (i <= 5)
    layer_h = layer_top_h;
    y_top = -(i-1) * layer_h;
    y_bot = -i * layer_h;
  Else
    layer_h = layer_bot_h;
    y_top = -d - (i-6) * layer_h;
    y_bot = -d - (i-5) * layer_h;
  EndIf
  base_surfs[] -= Surface In BoundingBox{tx1-eps, y_bot-eps, -eps, tx2+eps, y_top+eps, eps};
EndFor

Physical Surface("native_soil", 6) = base_surfs[];

// ==========================================
// 6. BOUNDARY CURVES
// ==========================================
top_trench[] = Curve In BoundingBox{tx1-eps, -eps, -eps, tx2+eps, eps, eps};
ground_L[]   = Curve In BoundingBox{-far_x-eps, -eps, -eps, tx1+eps, eps, eps};
ground_R[]   = Curve In BoundingBox{tx2-eps, -eps, -eps, far_x+eps, eps, eps};
Physical Curve("top", 10) = {top_trench[], ground_L[], ground_R[]};

Physical Curve("bottom", 11) = Curve In BoundingBox{-far_x-eps, by-eps, -eps, far_x+eps, by+eps, eps};
Physical Curve("left", 15)  = Curve In BoundingBox{-far_x-eps, by-eps, -eps, -far_x+eps, eps, eps};
Physical Curve("right", 16) = Curve In BoundingBox{far_x-eps, by-eps, -eps, far_x+eps, eps, eps};

// Optional named bonded internal boundaries for checking/postprocessing
iface_soil_left[]  = Curve In BoundingBox{ix1-eps, iy_bot-eps, -eps, ix1+eps, iy_top+eps, eps};
iface_soil_right[] = Curve In BoundingBox{ix2-eps, iy_bot-eps, -eps, ix2+eps, iy_top+eps, eps};
iface_soil_top[]   = Curve In BoundingBox{ix1-eps, iy_top-eps, -eps, ix2+eps, iy_top+eps, eps};
iface_soil_bot[]   = Curve In BoundingBox{ix1-eps, iy_bot-eps, -eps, ix2+eps, iy_bot+eps, eps};
Physical Curve("interface_soil_boundary", 22) =
  {iface_soil_left[], iface_soil_right[], iface_soil_top[], iface_soil_bot[]};

iface_conc_left[]  = Curve In BoundingBox{-w/2-eps, -d-h-eps, -eps, -w/2+eps, -d+eps, eps};
iface_conc_right[] = Curve In BoundingBox{ w/2-eps, -d-h-eps, -eps,  w/2+eps, -d+eps, eps};
iface_conc_top[]   = Curve In BoundingBox{-w/2-eps, -d-eps, -eps, w/2+eps, -d+eps, eps};
iface_conc_bot[]   = Curve In BoundingBox{-w/2-eps, -d-h-eps, -eps, w/2+eps, -d-h+eps, eps};
Physical Curve("interface_concrete_boundary", 23) =
  {iface_conc_left[], iface_conc_right[], iface_conc_top[], iface_conc_bot[]};

// ==========================================
// 7. MESH CONTROLS
// ==========================================
Mesh.MshFileVersion = 2.2;
Mesh.ElementOrder = 1;

// Force Gmsh 4+ to strictly obey the Box fields and ignore geometric corner points
Mesh.MeshSizeFromPoints = 0;
Mesh.MeshSizeFromCurvature = 0;
Mesh.MeshSizeExtendFromBoundary = 0;
Mesh.MeshSizeMin = ci/4;
Mesh.MeshSizeMax = 2.0;

// Field 1: Ultra-dense mesh for the thin interface
// Box tied to the interface envelope (iy_bot..iy_top), not the ground surface,
// so ci/2 only applies around the utilidor ring, not through the backfill above it.
Field[1] = Box;
Field[1].VIn = ci/2;
Field[1].VOut = 1.0;
Field[1].XMin = ix1 - 0.01;
Field[1].XMax = ix2 + 0.01;
Field[1].YMin = iy_bot - 0.01;
Field[1].YMax = iy_top + 0.01;
Field[1].Thickness = 0.1;

// Field 2: Moderate density for the full backfill trench and utilidor
Field[2] = Box;
Field[2].VIn = 0.08; 
Field[2].VOut = 1.0;
Field[2].XMin = tx1 - 0.01;
Field[2].XMax = tx2 + 0.01;
Field[2].YMin = iy_bot - 0.5;
Field[2].YMax = 0.01;
Field[2].Thickness = 1.0;

// Field 3: Apply the minimum element size from both fields
Field[3] = Min;
Field[3].FieldsList = {1, 2};

Background Field = 3;
Mesh.Optimize = 1;