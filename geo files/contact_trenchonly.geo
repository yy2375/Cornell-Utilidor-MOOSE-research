// Multi-Layer NYC Utilidor: CONTACT MECHANICS MESH
// Configuration: Rigid Steel Trench (Scenario B) + Deep Subgrade + 0.0mm Topological Gap
// Kernel: OpenCASCADE

SetFactory("OpenCASCADE");
Geometry.Tolerance = 1e-4;        
Geometry.ToleranceBoolean = 1e-4; 
Mesh.Algorithm = 6;

// ==========================================
// 1. PARAMETERS
// ==========================================
d  = DefineNumber[ 5.0,  Name "Parameters/1. Structural/depth (d)" ];
h  = DefineNumber[ 2.0,  Name "Parameters/1. Structural/height (h)" ];
w  = DefineNumber[ 2.0,  Name "Parameters/1. Structural/width (w)" ];
t  = 0.2; 
by = -30.5; // Deep subgrade invert

eps = 1e-3; 

// Trench boundaries
ws = 0.5; // Working space
tx1 = -w/2 - ws; // Left trench wall
tx2 = w/2 + ws;  // Right trench wall
tw_total = tx2 - tx1; // Total excavated width

// ==========================================
// 2. BUILD SOIL CONTINUUM & PUNCH HOLE
// ==========================================
// Subgrade (Native soil below utilidor)
Rectangle(1) = {tx1, by, 0, tw_total, -(d+h) - by};

// Sequential Backfill Layers
layer_h = (d + h) / 15;
For i In {1:15}
  y_start = -(i-1) * layer_h;
  Rectangle(100+i) = {tx1, y_start, 0, tw_total, -layer_h};
EndFor

// Fragment everything together to share nodes
BooleanFragments{ Surface{1, 101:115}; Delete; }{}

// Punch the hole for the concrete utilidor (Exact dimension)
Rectangle(999) = {-w/2, -d, 0, w, -h};
soil_surfs[] = Surface In BoundingBox{tx1-eps, by-eps, -eps, tx2+eps, eps, eps};
BooleanDifference{ Surface{soil_surfs[]}; Delete; }{ Surface{999}; Delete; }

// ==========================================
// 3. DEFINE SOIL CONTACT BOUNDARY
// ==========================================
// Bounding box using standard eps (1e-3) because the gap is 0.0mm
soil_left  = Curve In BoundingBox{-w/2-eps, -d-h-eps, -eps, -w/2+eps, -d+eps, eps};
soil_right = Curve In BoundingBox{w/2-eps, -d-h-eps, -eps, w/2+eps, -d+eps, eps};
soil_top   = Curve In BoundingBox{-w/2-eps, -d-eps, -eps, w/2+eps, -d+eps, eps};
soil_bot   = Curve In BoundingBox{-w/2-eps, -d-h-eps, -eps, w/2+eps, -d-h+eps, eps};

soil_inner_wall[] = {soil_left[], soil_right[], soil_top[], soil_bot[]};
Physical Curve("soil_inner_wall", 20) = soil_inner_wall[];

// ==========================================
// 4. BUILD UTILIDOR (Plain Concrete)
// ==========================================
// Drawn exactly at the soil boundaries (No gap)
Rectangle(2) = {-w/2, -d, 0, w, -h}; 
Rectangle(3) = {-w/2+t, -d-t, 0, w-2*t, -(h-2*t)}; 

BooleanDifference(11) = {Surface{2}; Delete;}{Surface{3}; Delete;};

// DO NOT FRAGMENT SURFACE 11. 
// This keeps the concrete topologically separated from the soil for contact mechanics.

// ==========================================
// 5. DEFINE CONCRETE CONTACT BOUNDARY
// ==========================================
// Grab BOTH the soil lines and the newly drawn concrete lines occupying the exact same space
all_left  = Curve In BoundingBox{-w/2-eps, -d-h-eps, -eps, -w/2+eps, -d+eps, eps};
all_right = Curve In BoundingBox{w/2-eps, -d-h-eps, -eps, w/2+eps, -d+eps, eps};
all_top   = Curve In BoundingBox{-w/2-eps, -d-eps, -eps, w/2+eps, -d+eps, eps};
all_bot   = Curve In BoundingBox{-w/2-eps, -d-h-eps, -eps, w/2+eps, -d-h+eps, eps};

all_trench_curves[] = {all_left[], all_right[], all_top[], all_bot[]};

// Subtract known soil lines from the array to perfectly isolate the concrete lines
concrete_outer_wall[] = all_trench_curves[];
concrete_outer_wall[] -= soil_inner_wall[];
Physical Curve("concrete_outer_wall", 21) = concrete_outer_wall[];

// ==========================================
// 6. PHYSICAL ENTITY MAPPING
// ==========================================
Physical Surface("concrete", 1) = {11};

For i In {1:15}
  y_top = -(i-1)*layer_h;
  y_bot = -i*layer_h;
  layer_surfs[] = Surface In BoundingBox{tx1-eps, y_bot-eps, -eps, tx2+eps, y_top+eps, eps};
  layer_surfs[] -= {11}; 
  Physical Surface(Sprintf("layer_%g", i), 100+i) = layer_surfs[];
EndFor

// Map Native Subgrade
base_surfs[] = Surface In BoundingBox{tx1-eps, by-eps, -eps, tx2+eps, -(d+h)+eps, eps};
base_surfs[] -= {11};
Physical Surface("native_soil", 6) = base_surfs[];

// Global Boundaries mapped strictly to the trench extents + subgrade depth
Physical Curve("top", 10)    = Curve In BoundingBox{tx1-eps, -eps, -eps, tx2+eps, eps, eps};
Physical Curve("bottom", 11) = Curve In BoundingBox{tx1-eps, by-eps, -eps, tx2+eps, by+eps, eps};
Physical Curve("left", 12)   = Curve In BoundingBox{tx1-eps, by-eps, -eps, tx1+eps, eps, eps};
Physical Curve("right", 13)  = Curve In BoundingBox{tx2-eps, by-eps, -eps, tx2+eps, eps, eps};

// ==========================================
// 7. MESH ADAPTIVITY CONTROLS
// ==========================================
Mesh.MshFileVersion = 2.2; 
Mesh.ElementOrder = 2;

// Dense mesh for the backfill and utilidor pressure bulb, coarse for deep subgrade
Field[1] = Box;
Field[1].VIn = 0.08; 
Field[1].VOut = 1.0; 
Field[1].XMin = tx1 - eps;
Field[1].XMax = tx2 + eps;
Field[1].YMin = -(d+h) - 2.5; 
Field[1].YMax = eps;
Field[1].Thickness = 1.5;

Background Field = 1;
Mesh.Optimize = 1;
// CRITICAL: Do NOT execute Coherence;