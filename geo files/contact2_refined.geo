// Multi-Layer NYC Utilidor: CONTACT MECHANICS MESH
// Configuration: Plain Concrete Box (Separated Topology)
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
by = -30.5; 

bx = w/2 + 5*w; 
eps = 1e-3; 

// ==========================================
// 2. BUILD SOIL CONTINUUM & PUNCH HOLE
// ==========================================
Rectangle(1) = {-bx, -(d+h), 0, 2*bx, by+(d+h)}; 

layer_h = (d + h) / 15;
For i In {1:15}
  y_start = -(i-1) * layer_h;
  Rectangle(100+i) = {-bx, y_start, 0, 2*bx, -layer_h};
EndFor

BooleanFragments{ Surface{1, 101:115}; Delete; }{}

Rectangle(999) = {-w/2, -d, 0, w, -h};
soil_surfs[] = Surface In BoundingBox{-bx-eps, by-eps, -eps, bx+eps, eps, eps};

// Cut the void completely out of the soil matrix
BooleanDifference{ Surface{soil_surfs[]}; Delete; }{ Surface{999}; Delete; }

// ==========================================
// 3. DEFINE SOIL CONTACT BOUNDARY
// ==========================================
soil_left  = Curve In BoundingBox{-w/2-eps, -d-h-eps, -eps, -w/2+eps, -d+eps, eps};
soil_right = Curve In BoundingBox{w/2-eps, -d-h-eps, -eps, w/2+eps, -d+eps, eps};
soil_top   = Curve In BoundingBox{-w/2-eps, -d-eps, -eps, w/2+eps, -d+eps, eps};
soil_bot   = Curve In BoundingBox{-w/2-eps, -d-h-eps, -eps, w/2+eps, -d-h+eps, eps};

soil_inner_wall[] = {soil_left[], soil_right[], soil_top[], soil_bot[]};
Physical Curve("soil_inner_wall", 20) = soil_inner_wall[];

// ==========================================
// 4. BUILD UTILIDOR (Plain Concrete)
// ==========================================
Rectangle(2) = {-w/2, -d, 0, w, -h}; 
Rectangle(3) = {-w/2+t, -d-t, 0, w-2*t, -(h-2*t)}; 

BooleanDifference(11) = {Surface{2}; Delete;}{Surface{3}; Delete;}; 

// DO NOT FRAGMENT SURFACE 11. 
// This keeps the concrete topologically separated from the soil for contact mechanics.

// ==========================================
// 5. DEFINE CONCRETE CONTACT BOUNDARY
// ==========================================
all_left  = Curve In BoundingBox{-w/2-eps, -d-h-eps, -eps, -w/2+eps, -d+eps, eps};
all_right = Curve In BoundingBox{w/2-eps, -d-h-eps, -eps, w/2+eps, -d+eps, eps};
all_top   = Curve In BoundingBox{-w/2-eps, -d-eps, -eps, w/2+eps, -d+eps, eps};
all_bot   = Curve In BoundingBox{-w/2-eps, -d-h-eps, -eps, w/2+eps, -d-h+eps, eps};

all_trench_curves[] = {all_left[], all_right[], all_top[], all_bot[]};

// Subtract known soil lines to isolate concrete lines
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
  layer_surfs[] = Surface In BoundingBox{-bx-eps, y_bot-eps, -eps, bx+eps, y_top+eps, eps};
  layer_surfs[] -= {11}; 
  Physical Surface(Sprintf("layer_%g", i), 100+i) = layer_surfs[];
EndFor

native_surfs[] = Surface In BoundingBox{-bx-eps, by-eps, -eps, bx+eps, -(d+h)+eps, eps};
native_surfs[] -= {11};
Physical Surface("native_soil", 6) = native_surfs[];

Physical Curve("top", 10)    = Curve In BoundingBox{-bx-eps, -eps, -eps, bx+eps, eps, eps};
Physical Curve("bottom", 11) = Curve In BoundingBox{-bx-eps, by-eps, -eps, bx+eps, by+eps, eps};
Physical Curve("left", 12)   = Curve In BoundingBox{-bx-eps, by-eps, -eps, -bx+eps, eps, eps};
Physical Curve("right", 13)  = Curve In BoundingBox{bx-eps, by-eps, -eps, bx+eps, eps, eps};

// ==========================================
// 7. MESH ADAPTIVITY CONTROLS (Spatial Box Field)
// ==========================================
Mesh.MshFileVersion = 2.2; 
Mesh.ElementOrder = 2;     

// Bounding box snapped precisely to the utilidor's outer perimeter
Field[1] = Box;
Field[1].VIn = 0.025;
Field[1].VOut = 1;
Field[1].XMin = -w/2;
Field[1].XMax =  w/2;
Field[1].YMin = -d - h;
Field[1].YMax = -d;
Field[1].Thickness = 1.0; // Shrink transition zone to 1.0m to prevent excess bleed

Background Field = 1;
Mesh.Optimize = 1;
// CRITICAL: Do NOT execute Coherence;