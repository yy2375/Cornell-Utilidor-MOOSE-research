// Multi-Layer NYC Utilidor: CONTACT MECHANICS MESH
// Configuration: Rigid Steel Trench (Scenario B) + Shallow Trench / Deep Subgrade
// Kernel: OpenCASCADE

SetFactory("OpenCASCADE");
Geometry.Tolerance = 1e-4;        
Geometry.ToleranceBoolean = 1e-4; 
Mesh.Algorithm = 6;

// ==========================================
// 1. PARAMETERS
// ==========================================
d  = 1.0;  // cover depth (Total trench depth = d + h = 3.0m)
h  = 2.0;  // utilidor height
w  = 2.0;  // utilidor width
t  = 0.2;  // concrete thickness
by = -30.5; // Deep subgrade invert
far_x = 15.0; // Far-field lateral boundary

r_fillet = 0.15; // Fillet radius for the OUTER corners of the concrete box

eps = 1e-3; 

// Trench boundaries
ws = 0.5; 
tx1 = -w/2 - ws; 
tx2 = w/2 + ws;  
tw_total = tx2 - tx1; 

// ==========================================
// 2. BUILD SOIL CONTINUUM & PUNCH HOLE
// ==========================================
// Native soil block (Ground surface down to deep invert)
Rectangle(1) = {-far_x, by, 0, 2*far_x, -by};

// Sequential Backfill Layers (Offset to prevent collinearity)
layer_top_h = 1.05 / 5;  // Layers 1-5: 0.21m thick
layer_bot_h = 1.95 / 10; // Layers 6-15: 0.195m thick

For i In {1:15}
  If (i <= 5)
    layer_h = layer_top_h;
    y_start = -(i-1) * layer_h;
  Else
    layer_h = layer_bot_h;
    y_start = -1.05 - (i-6) * layer_h;
  EndIf
  Rectangle(100+i) = {tx1, y_start, 0, tw_total, -layer_h};
EndFor

// Fragment everything together (Embeds the trench layers into the soil block)
BooleanFragments{ Surface{1, 101:115}; Delete; }{}

// Punch the hole for the concrete utilidor (Using r_fillet)
Rectangle(999) = {-w/2, -d, 0, w, -h, r_fillet};
soil_surfs[] = Surface In BoundingBox{-far_x-eps, by-eps, -eps, far_x+eps, eps, eps};
BooleanDifference{ Surface{soil_surfs[]}; Delete; }{ Surface{999}; Delete; }

// ==========================================
// 3. DEFINE SOIL CONTACT BOUNDARY
// ==========================================
soil_left  = Curve In BoundingBox{-w/2-eps, -d-h-eps, -eps, -w/2+eps, -d+eps, eps};
soil_right = Curve In BoundingBox{w/2-eps, -d-h-eps, -eps, w/2+eps, -d+eps, eps};
soil_top   = Curve In BoundingBox{-w/2-eps, -d-eps, -eps, w/2+eps, -d+eps, eps};
soil_bot   = Curve In BoundingBox{-w/2-eps, -d-h-eps, -eps, w/2+eps, -d-h+eps, eps};

// Capture the 4 soil-side fillet arcs
feps = r_fillet + eps;
soil_fillet_BL[] = Curve In BoundingBox{-w/2-eps,  -d-feps,   -eps, -w/2+feps, -d+eps,    eps};
soil_fillet_BR[] = Curve In BoundingBox{ w/2-feps, -d-feps,   -eps,  w/2+eps,  -d+eps,    eps};
soil_fillet_TL[] = Curve In BoundingBox{-w/2-eps,  -d-h-eps,  -eps, -w/2+feps, -d-h+feps, eps};
soil_fillet_TR[] = Curve In BoundingBox{ w/2-feps, -d-h-eps,  -eps,  w/2+eps,  -d-h+feps, eps};
soil_fillet_arcs[] = {soil_fillet_BL[], soil_fillet_BR[], soil_fillet_TL[], soil_fillet_TR[]};

soil_inner_wall[] = {soil_left[], soil_right[], soil_top[], soil_bot[], soil_fillet_arcs[]};
Physical Curve("soil_inner_wall", 20) = soil_inner_wall[];

// ==========================================
// 4. BUILD UTILIDOR (Plain Concrete)
// ==========================================
Rectangle(2) = {-w/2, -d, 0, w, -h, r_fillet}; 
Rectangle(3) = {-w/2+t, -d-t, 0, w-2*t, -(h-2*t)}; 

BooleanDifference(11) = {Surface{2}; Delete;}{Surface{3}; Delete;};

// ==========================================
// 5. DEFINE CONCRETE CONTACT BOUNDARY
// ==========================================
all_left  = Curve In BoundingBox{-w/2-eps, -d-h-eps, -eps, -w/2+eps, -d+eps, eps};
all_right = Curve In BoundingBox{w/2-eps, -d-h-eps, -eps, w/2+eps, -d+eps, eps};
all_top   = Curve In BoundingBox{-w/2-eps, -d-eps, -eps, w/2+eps, -d+eps, eps};
all_bot   = Curve In BoundingBox{-w/2-eps, -d-h-eps, -eps, w/2+eps, -d-h+eps, eps};

all_trench_curves[] = {all_left[], all_right[], all_top[], all_bot[]};

// Capture the 4 concrete-side fillet arcs
fillet_BL[] = Curve In BoundingBox{-w/2-eps,      -d-feps,   -eps, -w/2+feps, -d+eps,    eps}; 
fillet_BR[] = Curve In BoundingBox{ w/2-feps,     -d-feps,   -eps,  w/2+eps,  -d+eps,    eps}; 
fillet_TL[] = Curve In BoundingBox{-w/2-eps,      -d-h-eps,  -eps, -w/2+feps, -d-h+feps, eps}; 
fillet_TR[] = Curve In BoundingBox{ w/2-feps,     -d-h-eps,  -eps,  w/2+eps,  -d-h+feps, eps}; 

fillet_arcs[] = {fillet_BL[], fillet_BR[], fillet_TL[], fillet_TR[]};
all_trench_curves[] += fillet_arcs[];

concrete_outer_wall[] = all_trench_curves[];
concrete_outer_wall[] -= soil_inner_wall[];
Physical Curve("concrete_outer_wall", 21) = concrete_outer_wall[];

// ==========================================
// 6. PHYSICAL ENTITY MAPPING
// ==========================================
Physical Surface("concrete", 1) = {11};

// Map Backfill Layers
For i In {1:15}
  If (i <= 5)
    layer_h = layer_top_h;
    y_top = -(i-1) * layer_h;
    y_bot = -i * layer_h;
  Else
    layer_h = layer_bot_h;
    y_top = -1.05 - (i-6) * layer_h;
    y_bot = -1.05 - (i-5) * layer_h;
  EndIf
  
  layer_surfs[] = Surface In BoundingBox{tx1-eps, y_bot-eps, -eps, tx2+eps, y_top+eps, eps};
  layer_surfs[] -= {11}; 
  Physical Surface(Sprintf("layer_%g", i), 100+i) = layer_surfs[];
EndFor

// Map Expanded Native Subgrade
base_surfs[] = Surface In BoundingBox{-far_x-eps, by-eps, -eps, far_x+eps, eps, eps};
base_surfs[] -= {11};

For i In {1:15}
  If (i <= 5)
    layer_h = layer_top_h;
    y_top = -(i-1) * layer_h;
    y_bot = -i * layer_h;
  Else
    layer_h = layer_bot_h;
    y_top = -1.05 - (i-6) * layer_h;
    y_bot = -1.05 - (i-5) * layer_h;
  EndIf
  base_surfs[] -= Surface In BoundingBox{tx1-eps, y_bot-eps, -eps, tx2+eps, y_top+eps, eps};
EndFor
Physical Surface("native_soil", 6) = base_surfs[];

// 1. Top Surface
top_trench[] = Curve In BoundingBox{tx1-eps, -eps, -eps, tx2+eps, eps, eps};
ground_L[]   = Curve In BoundingBox{-far_x-eps, -eps, -eps, tx1+eps, eps, eps};
ground_R[]   = Curve In BoundingBox{tx2-eps, -eps, -eps, far_x+eps, eps, eps};
Physical Curve("top", 10) = {top_trench[], ground_L[], ground_R[]};

// 2. Bottom Bedrock
Physical Curve("bottom", 11) = Curve In BoundingBox{-far_x-eps, by-eps, -eps, far_x+eps, by+eps, eps};

// 3. Far-field Side Boundaries
Physical Curve("left", 15)  = Curve In BoundingBox{-far_x-eps, by-eps, -eps, -far_x+eps, eps, eps};
Physical Curve("right", 16) = Curve In BoundingBox{far_x-eps, by-eps, -eps, far_x+eps, eps, eps};

// ==========================================
// 7. MESH ADAPTIVITY CONTROLS
// ==========================================
Mesh.MshFileVersion = 2.2; 
Mesh.ElementOrder = 1;
Mesh.HighOrderOptimize = 2; 

coarse_size = 2.0; 

Field[1] = Box;
Field[1].VIn = 0.08;      
Field[1].VOut = coarse_size;      
Field[1].XMin = tx1;      
Field[1].XMax = tx2;      
Field[1].YMin = -(d+h);   
Field[1].YMax = 0.0;      
Field[1].Thickness = 3.0; 

// Local refinement around the fillet corners
fillet_size = r_fillet / 3;
tangent_pts[] = {};
corner_x[] = {-w/2, w/2};
corner_y[] = {-d, -d-h};
For ix In {0:1}
  For iy In {0:1}
    cx = corner_x[ix];
    cy = corner_y[iy];
    px_h = (ix == 0) ? cx + r_fillet : cx - r_fillet;
    py_v = (iy == 0) ? cy - r_fillet : cy + r_fillet;
    pts_h[] = Point In BoundingBox{px_h-eps, cy-eps, -eps, px_h+eps, cy+eps, eps};
    pts_v[] = Point In BoundingBox{cx-eps, py_v-eps, -eps, cx+eps, py_v+eps, eps};
    tangent_pts[] += pts_h[];
    tangent_pts[] += pts_v[];
  EndFor
EndFor
MeshSize{ tangent_pts[] } = fillet_size;

Field[2] = Distance;
Field[2].CurvesList = {fillet_arcs[], soil_fillet_arcs[]};
Field[2].Sampling = 100;

Field[3] = Threshold;
Field[3].InField = 2;
Field[3].SizeMin = fillet_size;
Field[3].SizeMax = coarse_size; 
Field[3].DistMin = r_fillet / 2;
Field[3].DistMax = r_fillet * 3;

Field[4] = Min;
Field[4].FieldsList = {1, 3};

Background Field = 4;
Mesh.Optimize = 1;
// CRITICAL: Do NOT execute Coherence;