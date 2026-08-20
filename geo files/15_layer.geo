// Multi-Layer NYC Utilidor
// Configuration: 2D Thin Shell Rebar (Manifold Topology)
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
t        = DefineNumber[ 0.2,  Name "Parameters/1. Structural/concrete thickness (t)" ];
c        = DefineNumber[ 0.05, Name "Parameters/1. Structural/concrete cover (c)" ];
by       = DefineNumber[ -30.5,Name "Parameters/2. Geotechnical/Domain Base (by)" ];
ts       = DefineNumber[ 0.02, Name "Parameters/3. Steel Shells/Rebar Thickness (ts)" ];

bx = w/2 + 5*w;

// ==========================================
// 2. BASE CONTINUUM GEOMETRY & 15 LAYERS
// ==========================================
Rectangle(1) = {-bx, -(d+h), 0, 2*bx, by+(d+h)}; 

layer_h = (d + h) / 15;
For i In {1:15}
  y_start = -(i-1) * layer_h;
  Rectangle(100+i) = {-bx, y_start, 0, 2*bx, -layer_h};
EndFor

Rectangle(2) = {-w/2, -d, 0, w, -h}; 
Rectangle(3) = {-w/2+t, -d-t, 0, w-2*t, -(h-2*t)}; 

// ==========================================
// 3. 2D STEEL SHELLS
// ==========================================
Rectangle(4) = {-w/2+c-ts/2, -d-c+ts/2, 0, w-2*c+ts, -(h-2*c+ts)};
Rectangle(5) = {-w/2+c+ts/2, -d-c-ts/2, 0, w-2*c-ts, -(h-2*c-ts)};
Rectangle(6) = {-w/2+t-c-ts/2, -d-t+c+ts/2, 0, w-2*t+2*c+ts, -(h-2*t+2*c+ts)};
Rectangle(7) = {-w/2+t-c+ts/2, -d-t+c-ts/2, 0, w-2*t+2*c-ts, -(h-2*t+2*c-ts)};

// ==========================================
// 4. BOOLEAN MANIFOLD OPERATIONS
// ==========================================
BooleanDifference(11) = {Surface{2}; Delete;}{Surface{3}; }; 
BooleanDifference(12) = {Surface{4}; Delete;}{Surface{5}; Delete;};
BooleanDifference(13) = {Surface{6}; Delete;}{Surface{7}; Delete;};

BooleanFragments{ Surface{1, 101:115}; Delete; }{ Surface{11, 12, 13, 3}; Delete; }

// ==========================================
// 5. PHYSICAL ENTITY MAPPING
// ==========================================
eps = 1e-3; 

// A. Physically delete the void shards
box_void[] = Surface In BoundingBox{-w/2+t-eps, -d-h+t-eps, -eps, w/2-t+eps, -d-t+eps, eps};
Delete { Surface{box_void[]}; }

// B. Isolate Utilidor Components
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

// C. Isolate 15 Soil Layers Parametrically
For i In {1:15}
  y_top = -(i-1)*layer_h;
  y_bot = -i*layer_h;
  layer_surfs[] = Surface In BoundingBox{-bx-eps, y_bot-eps, -eps, bx+eps, y_top+eps, eps};
  layer_surfs[] -= all_concrete[];
  layer_surfs[] -= outer_steel[];
  layer_surfs[] -= inner_steel[];
  Physical Surface(Sprintf("layer_%g", i), 100+i) = layer_surfs[];
EndFor

// D. Isolate Native Base
native_surfs[] = Surface In BoundingBox{-bx-eps, by-eps, -eps, bx+eps, -(d+h)+eps, eps};
native_surfs[] -= all_concrete[];
Physical Surface("native_soil", 6) = native_surfs[];

// E. Structural Boundary SideSets
Physical Curve("top", 10)    = Curve In BoundingBox{-bx-eps, -eps, -eps, bx+eps, eps, eps};
Physical Curve("bottom", 11) = Curve In BoundingBox{-bx-eps, by-eps, -eps, bx+eps, by+eps, eps};
Physical Curve("left", 12)   = Curve In BoundingBox{-bx-eps, by-eps, -eps, -bx+eps, eps, eps};
Physical Curve("right", 13)  = Curve In BoundingBox{bx-eps, by-eps, -eps, bx+eps, eps, eps};

// ==========================================
// 6. MESH ADAPTIVITY CONTROLS
// ==========================================
Mesh.MshFileVersion = 2.2; 
Mesh.ElementOrder = 2;     

Mesh.MeshSizeExtendFromBoundary = 0;
Mesh.MeshSizeFromPoints = 0;
Mesh.MeshSizeFromCurvature = 0;

lc_steel = DefineNumber[ 0.02, Name "Parameters/4. Mesh/Min Element Size near Steel (LcMin)" ];
lc_soil  = DefineNumber[ 1.5,  Name "Parameters/4. Mesh/Max Element Size far field (LcMax)" ];

Field[1] = Distance;
Field[1].SurfacesList = {outer_steel[], inner_steel[]};

Field[2] = Threshold;
Field[2].IField = 1;
Field[2].LcMin = lc_steel;
Field[2].LcMax = lc_soil;
Field[2].DistMin = ts;
Field[2].DistMax = 3.0;

Background Field = 2;

Coherence; 
Mesh.Optimize = 1;