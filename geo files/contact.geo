// Multi-Layer NYC Utilidor: CONTACT MECHANICS MESH
// Configuration: 2D Thin Shell Rebar (Separated Topology)
// Kernel: OpenCASCADE

SetFactory("OpenCASCADE");
Geometry.Tolerance = 1e-4;
Geometry.ToleranceBoolean = 1e-4;
Mesh.Algorithm = 6; 

// ==========================================
// 1. PARAMETERS
// ==========================================
d        = DefineNumber[ 5.0,  Name "Parameters/1. Structural/depth (d)" ];
h        = DefineNumber[ 2.0,  Name "Parameters/1. Structural/height (h)" ];
w        = DefineNumber[ 2.0,  Name "Parameters/1. Structural/width (w)" ];
t        = 0.2; 
c        = 0.05; 
by       = -30.5; 
ts       = 0.02; 

bx = w/2 + 5*w;
eps = 1e-3; 

// ==========================================
// 2. BUILD SOIL CONTINUUM & TRENCH VOID
// ==========================================
Rectangle(1) = {-bx, -(d+h), 0, 2*bx, by+(d+h)}; 

layer_h = (d + h) / 15;
For i In {1:15}
  y_start = -(i-1) * layer_h;
  Rectangle(100+i) = {-bx, y_start, 0, 2*bx, -layer_h};
EndFor

// Create a dummy surface representing the trench
Rectangle(999) = {-w/2, -d, 0, w, -h};

// Fragment the soil and the trench void to ensure the 15 layers align perfectly
BooleanFragments{ Surface{1, 101:115, 999}; Delete; }{}

// Delete the trench void surfaces, leaving a perfect hole in the soil
void_surfs[] = Surface In BoundingBox{-w/2-eps, -d-h-eps, -eps, w/2+eps, -d+eps, eps};
Delete { Surface{void_surfs[]}; }

// ==========================================
// 3. DEFINE SOIL CONTACT BOUNDARY
// ==========================================
// Because the utilidor doesn't exist yet, these bounding boxes will ONLY grab soil curves
soil_left  = Curve In BoundingBox{-w/2-eps, -d-h-eps, -eps, -w/2+eps, -d+eps, eps};
soil_right = Curve In BoundingBox{w/2-eps, -d-h-eps, -eps, w/2+eps, -d+eps, eps};
soil_top   = Curve In BoundingBox{-w/2-eps, -d-eps, -eps, w/2+eps, -d+eps, eps};
soil_bot   = Curve In BoundingBox{-w/2-eps, -d-h-eps, -eps, w/2+eps, -d-h+eps, eps};

soil_inner_wall[] = {soil_left[], soil_right[], soil_top[], soil_bot[]};
Physical Curve("soil_inner_wall", 20) = soil_inner_wall[];

// ==========================================
// 4. BUILD UTILIDOR & 2D STEEL SHELLS
// ==========================================
Rectangle(2) = {-w/2, -d, 0, w, -h}; 
Rectangle(3) = {-w/2+t, -d-t, 0, w-2*t, -(h-2*t)}; 

Rectangle(4) = {-w/2+c-ts/2, -d-c+ts/2, 0, w-2*c+ts, -(h-2*c+ts)};
Rectangle(5) = {-w/2+c+ts/2, -d-c-ts/2, 0, w-2*c-ts, -(h-2*c-ts)};
Rectangle(6) = {-w/2+t-c-ts/2, -d-t+c+ts/2, 0, w-2*t+2*c+ts, -(h-2*t+2*c+ts)};
Rectangle(7) = {-w/2+t-c+ts/2, -d-t+c-ts/2, 0, w-2*t+2*c-ts, -(h-2*t+2*c-ts)};

BooleanDifference(11) = {Surface{2}; Delete;}{Surface{3}; Delete;}; 
BooleanDifference(12) = {Surface{4}; Delete;}{Surface{5}; Delete;};
BooleanDifference(13) = {Surface{6}; Delete;}{Surface{7}; Delete;};

// Fragment ONLY the concrete and steel together. Do NOT include the soil.
BooleanFragments{ Surface{11, 12, 13}; Delete; }{}

// ==========================================
// 5. DEFINE CONCRETE CONTACT BOUNDARY
// ==========================================
// Grab all lines occupying the trench boundary (this will grab BOTH soil and concrete lines)
trench_left  = Curve In BoundingBox{-w/2-eps, -d-h-eps, -eps, -w/2+eps, -d+eps, eps};
trench_right = Curve In BoundingBox{w/2-eps, -d-h-eps, -eps, w/2+eps, -d+eps, eps};
trench_top   = Curve In BoundingBox{-w/2-eps, -d-eps, -eps, w/2+eps, -d+eps, eps};
trench_bot   = Curve In BoundingBox{-w/2-eps, -d-h-eps, -eps, w/2+eps, -d-h+eps, eps};

all_trench_curves[] = {trench_left[], trench_right[], trench_top[], trench_bot[]};

// Subtract the known soil lines from the list. What remains must be the concrete lines.
concrete_outer_wall[] = all_trench_curves[];
concrete_outer_wall[] -= soil_inner_wall[];
Physical Curve("concrete_outer_wall", 21) = concrete_outer_wall[];

// ==========================================
// 6. PHYSICAL ENTITY MAPPING (Surfaces)
// ==========================================
box_concrete_out[]    = Surface In BoundingBox{-w/2-eps, -d-h-eps, -eps, w/2+eps, -d+eps, eps};
box_steel_outer_out[] = Surface In BoundingBox{-w/2+c-ts/2-eps, -d-h+c-ts/2-eps, -eps, w/2-c+ts/2+eps, -d-c+ts/2+eps, eps};
box_steel_outer_in[]  = Surface In BoundingBox{-w/2+c+ts/2-eps, -d-h+c+ts/2-eps, -eps, w/2-c-ts/2+eps, -d-c-ts/2+eps, eps};
box_steel_inner_out[] = Surface In BoundingBox{-w/2+t-c-ts/2-eps, -d-h+t-c-ts/2-eps, -eps, w/2-t+c+ts/2+eps, -d-t+c+ts/2+eps, eps};
box_steel_inner_in[]  = Surface In BoundingBox{-w/2+t-c+ts/2-eps, -d-h+t-c+ts/2-eps, -eps, w/2-t+c-ts/2+eps, -d-t+c-ts/2+eps, eps};

outer_cover[]   = box_concrete_out[];    outer_cover[]   -= box_steel_outer_out[];
outer_steel[]   = box_steel_outer_out[]; outer_steel[]   -= box_steel_outer_in[];
core_concrete[] = box_steel_outer_in[];  core_concrete[] -= box_steel_inner_out[];
inner_steel[]   = box_steel_inner_out[]; inner_steel[]   -= box_steel_inner_in[];
inner_cover[]   = box_steel_inner_in[];  

all_concrete[] = {outer_cover[], core_concrete[], inner_cover[]};
Physical Surface("concrete", 1)    = all_concrete[];
Physical Surface("rebar_outer", 4) = outer_steel[];
Physical Surface("rebar_inner", 5) = inner_steel[];

// Isolate 15 Soil Layers
For i In {1:15}
  y_top = -(i-1)*layer_h;
  y_bot = -i*layer_h;
  layer_surfs[] = Surface In BoundingBox{-bx-eps, y_bot-eps, -eps, bx+eps, y_top+eps, eps};
  layer_surfs[] -= all_concrete[];
  layer_surfs[] -= outer_steel[];
  layer_surfs[] -= inner_steel[];
  Physical Surface(Sprintf("layer_%g", i), 100+i) = layer_surfs[];
EndFor

// Isolate Native Base
native_surfs[] = Surface In BoundingBox{-bx-eps, by-eps, -eps, bx+eps, -(d+h)+eps, eps};
native_surfs[] -= all_concrete[];
Physical Surface("native_soil", 6) = native_surfs[];

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