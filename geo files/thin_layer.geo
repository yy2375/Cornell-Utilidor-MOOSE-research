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
t  = 0.1;
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

// Dynamic layer heights, from second-code logic
layer_top_h = d / 5;
layer_bot_h = (h + ci) / 10;

// ==========================================
// 2. BUILD SOIL CONTINUUM AND BACKFILL LAYERS
// ==========================================
Rectangle(1) = {-far_x, by, 0, 2*far_x, -by};

Rectangle(101) = {tx1, 0, 0, tw_total, -layer_top_h};
Rectangle(102) = {tx1, -layer_top_h, 0, tw_total, -layer_top_h};
Rectangle(103) = {tx1, -2*layer_top_h, 0, tw_total, -layer_top_h};
Rectangle(104) = {tx1, -3*layer_top_h, 0, tw_total, -layer_top_h};
Rectangle(105) = {tx1, -4*layer_top_h, 0, tw_total, -layer_top_h};

Rectangle(106) = {tx1, -d, 0, tw_total, -layer_bot_h};
Rectangle(107) = {tx1, -d - layer_bot_h, 0, tw_total, -layer_bot_h};
Rectangle(108) = {tx1, -d - 2*layer_bot_h, 0, tw_total, -layer_bot_h};
Rectangle(109) = {tx1, -d - 3*layer_bot_h, 0, tw_total, -layer_bot_h};
Rectangle(110) = {tx1, -d - 4*layer_bot_h, 0, tw_total, -layer_bot_h};
Rectangle(111) = {tx1, -d - 5*layer_bot_h, 0, tw_total, -layer_bot_h};
Rectangle(112) = {tx1, -d - 6*layer_bot_h, 0, tw_total, -layer_bot_h};
Rectangle(113) = {tx1, -d - 7*layer_bot_h, 0, tw_total, -layer_bot_h};
Rectangle(114) = {tx1, -d - 8*layer_bot_h, 0, tw_total, -layer_bot_h};
Rectangle(115) = {tx1, -d - 9*layer_bot_h, 0, tw_total, -layer_bot_h};

BooleanFragments{
  Surface{1, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115};
  Delete;
}{}

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
layer_1[] = Surface In BoundingBox{tx1-eps, -layer_top_h-eps, -eps, tx2+eps, eps, eps};
layer_1[] -= concrete_surfs[];
layer_1[] -= interface_surfs[];
Physical Surface("layer_1", 101) = layer_1[];

layer_2[] = Surface In BoundingBox{tx1-eps, -2*layer_top_h-eps, -eps, tx2+eps, -layer_top_h+eps, eps};
layer_2[] -= concrete_surfs[];
layer_2[] -= interface_surfs[];
Physical Surface("layer_2", 102) = layer_2[];

layer_3[] = Surface In BoundingBox{tx1-eps, -3*layer_top_h-eps, -eps, tx2+eps, -2*layer_top_h+eps, eps};
layer_3[] -= concrete_surfs[];
layer_3[] -= interface_surfs[];
Physical Surface("layer_3", 103) = layer_3[];

layer_4[] = Surface In BoundingBox{tx1-eps, -4*layer_top_h-eps, -eps, tx2+eps, -3*layer_top_h+eps, eps};
layer_4[] -= concrete_surfs[];
layer_4[] -= interface_surfs[];
Physical Surface("layer_4", 104) = layer_4[];

layer_5[] = Surface In BoundingBox{tx1-eps, -5*layer_top_h-eps, -eps, tx2+eps, -4*layer_top_h+eps, eps};
layer_5[] -= concrete_surfs[];
layer_5[] -= interface_surfs[];
Physical Surface("layer_5", 105) = layer_5[];

layer_6[] = Surface In BoundingBox{tx1-eps, -d-layer_bot_h-eps, -eps, tx2+eps, -d+eps, eps};
layer_6[] -= concrete_surfs[];
layer_6[] -= interface_surfs[];
Physical Surface("layer_6", 106) = layer_6[];

layer_7[] = Surface In BoundingBox{tx1-eps, -d-2*layer_bot_h-eps, -eps, tx2+eps, -d-layer_bot_h+eps, eps};
layer_7[] -= concrete_surfs[];
layer_7[] -= interface_surfs[];
Physical Surface("layer_7", 107) = layer_7[];

layer_8[] = Surface In BoundingBox{tx1-eps, -d-3*layer_bot_h-eps, -eps, tx2+eps, -d-2*layer_bot_h+eps, eps};
layer_8[] -= concrete_surfs[];
layer_8[] -= interface_surfs[];
Physical Surface("layer_8", 108) = layer_8[];

layer_9[] = Surface In BoundingBox{tx1-eps, -d-4*layer_bot_h-eps, -eps, tx2+eps, -d-3*layer_bot_h+eps, eps};
layer_9[] -= concrete_surfs[];
layer_9[] -= interface_surfs[];
Physical Surface("layer_9", 109) = layer_9[];

layer_10[] = Surface In BoundingBox{tx1-eps, -d-5*layer_bot_h-eps, -eps, tx2+eps, -d-4*layer_bot_h+eps, eps};
layer_10[] -= concrete_surfs[];
layer_10[] -= interface_surfs[];
Physical Surface("layer_10", 110) = layer_10[];

layer_11[] = Surface In BoundingBox{tx1-eps, -d-6*layer_bot_h-eps, -eps, tx2+eps, -d-5*layer_bot_h+eps, eps};
layer_11[] -= concrete_surfs[];
layer_11[] -= interface_surfs[];
Physical Surface("layer_11", 111) = layer_11[];

layer_12[] = Surface In BoundingBox{tx1-eps, -d-7*layer_bot_h-eps, -eps, tx2+eps, -d-6*layer_bot_h+eps, eps};
layer_12[] -= concrete_surfs[];
layer_12[] -= interface_surfs[];
Physical Surface("layer_12", 112) = layer_12[];

layer_13[] = Surface In BoundingBox{tx1-eps, -d-8*layer_bot_h-eps, -eps, tx2+eps, -d-7*layer_bot_h+eps, eps};
layer_13[] -= concrete_surfs[];
layer_13[] -= interface_surfs[];
Physical Surface("layer_13", 113) = layer_13[];

layer_14[] = Surface In BoundingBox{tx1-eps, -d-9*layer_bot_h-eps, -eps, tx2+eps, -d-8*layer_bot_h+eps, eps};
layer_14[] -= concrete_surfs[];
layer_14[] -= interface_surfs[];
Physical Surface("layer_14", 114) = layer_14[];

layer_15[] = Surface In BoundingBox{tx1-eps, -d-10*layer_bot_h-eps, -eps, tx2+eps, -d-9*layer_bot_h+eps, eps};
layer_15[] -= concrete_surfs[];
layer_15[] -= interface_surfs[];
Physical Surface("layer_15", 115) = layer_15[];

// Native soil
base_surfs[] = Surface In BoundingBox{-far_x-eps, by-eps, -eps, far_x+eps, eps, eps};
base_surfs[] -= concrete_surfs[];
base_surfs[] -= interface_surfs[];

base_surfs[] -= Surface In BoundingBox{tx1-eps, -layer_top_h-eps, -eps, tx2+eps, eps, eps};
base_surfs[] -= Surface In BoundingBox{tx1-eps, -2*layer_top_h-eps, -eps, tx2+eps, -layer_top_h+eps, eps};
base_surfs[] -= Surface In BoundingBox{tx1-eps, -3*layer_top_h-eps, -eps, tx2+eps, -2*layer_top_h+eps, eps};
base_surfs[] -= Surface In BoundingBox{tx1-eps, -4*layer_top_h-eps, -eps, tx2+eps, -3*layer_top_h+eps, eps};
base_surfs[] -= Surface In BoundingBox{tx1-eps, -5*layer_top_h-eps, -eps, tx2+eps, -4*layer_top_h+eps, eps};

base_surfs[] -= Surface In BoundingBox{tx1-eps, -d-layer_bot_h-eps, -eps, tx2+eps, -d+eps, eps};
base_surfs[] -= Surface In BoundingBox{tx1-eps, -d-2*layer_bot_h-eps, -eps, tx2+eps, -d-layer_bot_h+eps, eps};
base_surfs[] -= Surface In BoundingBox{tx1-eps, -d-3*layer_bot_h-eps, -eps, tx2+eps, -d-2*layer_bot_h+eps, eps};
base_surfs[] -= Surface In BoundingBox{tx1-eps, -d-4*layer_bot_h-eps, -eps, tx2+eps, -d-3*layer_bot_h+eps, eps};
base_surfs[] -= Surface In BoundingBox{tx1-eps, -d-5*layer_bot_h-eps, -eps, tx2+eps, -d-4*layer_bot_h+eps, eps};
base_surfs[] -= Surface In BoundingBox{tx1-eps, -d-6*layer_bot_h-eps, -eps, tx2+eps, -d-5*layer_bot_h+eps, eps};
base_surfs[] -= Surface In BoundingBox{tx1-eps, -d-7*layer_bot_h-eps, -eps, tx2+eps, -d-6*layer_bot_h+eps, eps};
base_surfs[] -= Surface In BoundingBox{tx1-eps, -d-8*layer_bot_h-eps, -eps, tx2+eps, -d-7*layer_bot_h+eps, eps};
base_surfs[] -= Surface In BoundingBox{tx1-eps, -d-9*layer_bot_h-eps, -eps, tx2+eps, -d-8*layer_bot_h+eps, eps};
base_surfs[] -= Surface In BoundingBox{tx1-eps, -d-10*layer_bot_h-eps, -eps, tx2+eps, -d-9*layer_bot_h+eps, eps};

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

Mesh.MeshSizeFromPoints = 0;
Mesh.MeshSizeFromCurvature = 0;
Mesh.MeshSizeExtendFromBoundary = 0;
Mesh.MeshSizeMin = ci/4;
Mesh.MeshSizeMax = 2.0;

Field[1] = Box;
Field[1].VIn = ci/2;
Field[1].VOut = 1.0;
Field[1].XMin = ix1 - 0.01;
Field[1].XMax = ix2 + 0.01;
Field[1].YMin = iy_bot - 0.01;
Field[1].YMax = iy_top + 0.01;
Field[1].Thickness = 0.1;

Field[2] = Box;
Field[2].VIn = 0.08;
Field[2].VOut = 1.0;
Field[2].XMin = tx1 - 0.01;
Field[2].XMax = tx2 + 0.01;
Field[2].YMin = iy_bot - 0.5;
Field[2].YMax = 0.01;
Field[2].Thickness = 1.0;

Field[3] = Min;
Field[3].FieldsList = {1, 2};

Background Field = 3;
Mesh.Optimize = 1;