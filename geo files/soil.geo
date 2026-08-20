// Multi-Layer NYC Utilidor: ZONED CONTACT MESH
// Configuration: 2D Thin Shell Rebar (Separated Topology)
// Kernel: OpenCASCADE

SetFactory("OpenCASCADE");
Geometry.Tolerance = 1e-4;
Geometry.ToleranceBoolean = 1e-4;
Mesh.Algorithm = 6; 

// ==========================================
// 1. PARAMETERS
// ==========================================
d        = 5.0;  // depth to utilidor roof
h        = 2.0;  // utilidor height
w        = 2.0;  // utilidor width
trench_w = 4.0;  // Total width of excavated trench (leaves 1m of CLSM on each side)

t        = 0.2;  // concrete wall thickness
c        = 0.05; // concrete cover
by       = -30.5; // native domain bottom boundary
ts       = 0.02; // steel rebar thickness

bx       = w/2 + 5*w; // 11.0m half-width
eps      = 1e-3; 

// ==========================================
// 2. BUILD SOIL CONTINUUM & TRENCH ZONES
// ==========================================
// Base Native Soil (Full domain from surface to bottom)
Rectangle(1) = {-bx, 0, 0, 2*bx, by}; 

// Dummy Trench Void to punch a hole in native soil
Rectangle(999) = {-trench_w/2, 0, 0, trench_w, -(d+h)};
BooleanDifference(2) = {Surface{1}; Delete;}{Surface{999}; Delete;};

// Build Top Fill Layers (101 to 110) - Granular
top_h = d / 10;
For i In {1:10}
  y_top = -(i-1)*top_h;
  Rectangle(100+i) = {-trench_w/2, y_top, 0, trench_w, -top_h};
EndFor

// Build Side Fill Layers (111 to 115) - CLSM
side_h = h / 5;
For i In {1:5}
  y_top = -d - (i-1)*side_h;
  // Left side column
  Rectangle(200+i) = {-trench_w/2, y_top, 0, (trench_w-w)/2, -side_h};
  // Right side column
  Rectangle(300+i) = {w/2, y_top, 0, (trench_w-w)/2, -side_h};
EndFor

// Fragment all soil zones together to create a continuous matrix
// This naturally leaves a perfect 2x2 void in the center for the utilidor
BooleanFragments{ Surface{2, 101:110, 201:205, 301:305}; Delete; }{}

// ==========================================
// 3. DEFINE SOIL CONTACT BOUNDARY
// ==========================================
// Grab the curves forming the void in the soil matrix BEFORE concrete is added
soil_left  = Curve In BoundingBox{-w/2-eps, -(d+h)-eps, -eps, -w/2+eps, -d+eps, eps};
soil_right = Curve In BoundingBox{w/2-eps, -(d+h)-eps, -eps, w/2+eps, -d+eps, eps};
soil_top   = Curve In BoundingBox{-w/2-eps, -d-eps, -eps, w/2+eps, -d+eps, eps};
soil_bot   = Curve In BoundingBox{-w/2-eps, -(d+h)-eps, -eps, w/2+eps, -(d+h)+eps, eps};

soil_inner_wall[] = {soil_left[], soil_right[], soil_top[], soil_bot[]};
Physical Curve("soil_inner_wall", 20) = soil_inner_wall[];

// ==========================================
// 4. BUILD UTILIDOR & 2D STEEL SHELLS
// ==========================================
Rectangle(10) = {-w/2, -(d+h), 0, w, h}; 
Rectangle(11) = {-w/2+t, -(d+h)+t, 0, w-2*t, h-2*t}; 

Rectangle(12) = {-w/2+c-ts/2, -(d+h)+c-ts/2, 0, w-2*c+ts, h-2*c+ts};
Rectangle(13) = {-w/2+c+ts/2, -(d+h)+c+ts/2, 0, w-2*c-ts, h-2*c-ts};
Rectangle(14) = {-w/2+t-c-ts/2, -(d+h)+t-c-ts/2, 0, w-2*t+2*c+ts, h-2*t+2*c+ts};
Rectangle(15) = {-w/2+t-c+ts/2, -(d+h)+t-c+ts/2, 0, w-2*t+2*c-ts, h-2*t+2*c-ts};

BooleanDifference(20) = {Surface{10}; Delete;}{Surface{11}; Delete;}; 
BooleanDifference(21) = {Surface{12}; Delete;}{Surface{13}; Delete;};
BooleanDifference(22) = {Surface{14}; Delete;}{Surface{15}; Delete;};

// Fragment ONLY the concrete and steel. Do NOT include the soil.
BooleanFragments{ Surface{20, 21, 22}; Delete; }{}

// ==========================================
// 5. DEFINE CONCRETE CONTACT BOUNDARY
// ==========================================
// Grab all lines at the interface (grabs both soil and concrete nodes)
all_left  = Curve In BoundingBox{-w/2-eps, -(d+h)-eps, -eps, -w/2+eps, -d+eps, eps};
all_right = Curve In BoundingBox{w/2-eps, -(d+h)-eps, -eps, w/2+eps, -d+eps, eps};
all_top   = Curve In BoundingBox{-w/2-eps, -d-eps, -eps, w/2+eps, -d+eps, eps};
all_bot   = Curve In BoundingBox{-w/2-eps, -(d+h)-eps, -eps, w/2+eps, -(d+h)+eps, eps};

// Subtract the known soil lines to isolate the concrete curves
conc_left[] = all_left[];   conc_left[] -= soil_left[];
conc_right[] = all_right[]; conc_right[] -= soil_right[];
conc_top[] = all_top[];     conc_top[] -= soil_top[];
conc_bot[] = all_bot[];     conc_bot[] -= soil_bot[];

concrete_outer_wall[] = {conc_left[], conc_right[], conc_top[], conc_bot[]};
Physical Curve("concrete_outer_wall", 21) = concrete_outer_wall[];

// ==========================================
// 6. PHYSICAL ENTITY MAPPING (Surfaces)
// ==========================================
// Extract concrete & steel components
box_concrete_out[]    = Surface In BoundingBox{-w/2-eps, -(d+h)-eps, -eps, w/2+eps, -d+eps, eps};
box_steel_outer_out[] = Surface In BoundingBox{-w/2+c-ts/2-eps, -(d+h)+c-ts/2-eps, -eps, w/2-c+ts/2+eps, -d-c+ts/2+eps, eps};
box_steel_outer_in[]  = Surface In BoundingBox{-w/2+c+ts/2-eps, -(d+h)+c+ts/2-eps, -eps, w/2-c-ts/2+eps, -d-c-ts/2+eps, eps};
box_steel_inner_out[] = Surface In BoundingBox{-w/2+t-c-ts/2-eps, -(d+h)+t-c-ts/2-eps, -eps, w/2-t+c+ts/2+eps, -d-t+c+ts/2+eps, eps};
box_steel_inner_in[]  = Surface In BoundingBox{-w/2+t-c+ts/2-eps, -(d+h)+t-c+ts/2-eps, -eps, w/2-t+c-ts/2+eps, -d-t+c-ts/2+eps, eps};

outer_cover[]   = box_concrete_out[];    outer_cover[]   -= box_steel_outer_out[];
outer_steel[]   = box_steel_outer_out[]; outer_steel[]   -= box_steel_outer_in[];
core_concrete[] = box_steel_outer_in[];  core_concrete[] -= box_steel_inner_out[];
inner_steel[]   = box_steel_inner_out[]; inner_steel[]   -= box_steel_inner_in[];
inner_cover[]   = box_steel_inner_in[];  

all_concrete[] = {outer_cover[], core_concrete[], inner_cover[]};
Physical Surface("concrete", 1)    = all_concrete[];
Physical Surface("rebar_outer", 4) = outer_steel[];
Physical Surface("rebar_inner", 5) = inner_steel[];

// Map Top Fill Layers (101 to 110)
For i In {1:10}
  y_top = -(i-1)*top_h;
  surfs[] = Surface In BoundingBox{-trench_w/2-eps, y_top-top_h-eps, -eps, trench_w/2+eps, y_top+eps, eps};
  Physical Surface(Sprintf("layer_%g", i), 100+i) = surfs[];
EndFor

// Map Side Fill Layers (111 to 115)
For i In {1:5}
  y_top = -d - (i-1)*side_h;
  left_surfs[] = Surface In BoundingBox{-trench_w/2-eps, y_top-side_h-eps, -eps, -w/2+eps, y_top+eps, eps};
  right_surfs[] = Surface In BoundingBox{w/2-eps, y_top-side_h-eps, -eps, trench_w/2+eps, y_top+eps, eps};
  Physical Surface(Sprintf("layer_%g", i+10), 110+i) = {left_surfs[], right_surfs[]};
EndFor

// Map Native Base (Explicitly grabs everything outside the trench)
native_surfs[] = Surface In BoundingBox{-bx-eps, by-eps, -eps, bx+eps, eps, eps};
trench_all_surfs[] = Surface In BoundingBox{-trench_w/2-eps, -(d+h)-eps, -eps, trench_w/2+eps, eps, eps};
native_surfs[] -= trench_all_surfs[];
Physical Surface("native_soil", 6) = native_surfs[];

// Map Dirichlet Boundaries
Physical Curve("top", 10)    = Curve In BoundingBox{-bx-eps, -eps, -eps, bx+eps, eps, eps};
Physical Curve("bottom", 11) = Curve In BoundingBox{-bx-eps, by-eps, -eps, bx+eps, by+eps, eps};
Physical Curve("left", 12)   = Curve In BoundingBox{-bx-eps, by-eps, -eps, -bx+eps, eps, eps};
Physical Curve("right", 13)  = Curve In BoundingBox{bx-eps, by-eps, -eps, bx+eps, eps, eps};

// ==========================================
// 7. MESH ADAPTIVITY CONTROLS
// ==========================================
Mesh.MshFileVersion = 2.2; 
Mesh.ElementOrder = 2;     

Mesh.MeshSizeExtendFromBoundary = 0;
Mesh.MeshSizeFromPoints = 0;
Mesh.MeshSizeFromCurvature = 0;

lc_steel = 0.02;
lc_soil  = 1.5;

Field[1] = Distance;
Field[1].SurfacesList = {outer_steel[], inner_steel[]};

Field[2] = Threshold;
Field[2].IField = 1;
Field[2].LcMin = lc_steel;
Field[2].LcMax = lc_soil;
Field[2].DistMin = ts;
Field[2].DistMax = 3.0;

Background Field = 2;
Mesh.Optimize = 1;
// CRITICAL: Do NOT execute Coherence;