// Multi-Layer NYC Utilidor: CONTACT MECHANICS MESH
// Configuration: Trench Excavation with Native Soil Walls
// Kernel: OpenCASCADE

SetFactory("OpenCASCADE");
Geometry.Tolerance = 1e-6;        // Lower tolerance to 1 micron
Geometry.ToleranceBoolean = 1e-6; // Lower boolean tolerance to 1 micron
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

// Trench boundaries
ws = 0.5; // Working space on each side of the utilidor
tx1 = -w/2 - ws; // Left trench wall
tx2 = w/2 + ws;  // Right trench wall
tw_total = tx2 - tx1; // Total excavated width

// ==========================================
// 2. BUILD SOIL CONTINUUM & PUNCH HOLE
// ==========================================
// Base native soil below the trench
Rectangle(1) = {-bx, -(d+h), 0, 2*bx, by+(d+h)}; 

// Undisturbed Native Soil Walls (Left and Right)
Rectangle(201) = {-bx, 0, 0, bx + tx1, -(d+h)};
Rectangle(202) = {tx2, 0, 0, bx - tx2, -(d+h)};

// Sequential Backfill Layers (Confined to the trench)
layer_h = (d + h) / 15;
For i In {1:15}
  y_start = -(i-1) * layer_h;
  Rectangle(100+i) = {tx1, y_start, 0, tw_total, -layer_h};
EndFor

// Fragment everything together to share nodes at interfaces
BooleanFragments{ Surface{1, 201, 202, 101:115}; Delete; }{}

// Punch the hole for the concrete utilidor
Rectangle(999) = {-w/2, -d, 0, w, -h};
soil_surfs[] = Surface In BoundingBox{-bx-eps, by-eps, -eps, bx+eps, eps, eps};
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
// Introduce a 0.1mm gap to prevent OpenCASCADE from auto-gluing the top/bottom curves
gap = 1e-4; 

// Concrete outer boundary (shrunk by 'gap' on all sides)
Rectangle(2) = {-w/2 + gap, -d - gap, 0, w - 2*gap, -h + 2*gap}; 

// Concrete inner boundary (remains the same relative thickness)
Rectangle(3) = {-w/2+t, -d-t, 0, w-2*t, -(h-2*t)}; 

BooleanDifference(11) = {Surface{2}; Delete;}{Surface{3}; Delete;};// ==========================================
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

// Map Backfill Layers
For i In {1:15}
  y_top = -(i-1)*layer_h;
  y_bot = -i*layer_h;
  layer_surfs[] = Surface In BoundingBox{tx1-eps, y_bot-eps, -eps, tx2+eps, y_top+eps, eps};
  layer_surfs[] -= {11}; 
  Physical Surface(Sprintf("layer_%g", i), 100+i) = layer_surfs[];
EndFor

// Map Native Soil (Base + Left Wall + Right Wall)
base_surfs[] = Surface In BoundingBox{-bx-eps, by-eps, -eps, bx+eps, -(d+h)+eps, eps};
left_surfs[] = Surface In BoundingBox{-bx-eps, -(d+h)-eps, -eps, tx1+eps, eps, eps};
right_surfs[] = Surface In BoundingBox{tx2-eps, -(d+h)-eps, -eps, bx+eps, eps, eps};

native_surfs[] = base_surfs[];
native_surfs[] += left_surfs[];
native_surfs[] += right_surfs[];
native_surfs[] -= {11};
Physical Surface("native_soil", 6) = native_surfs[];

// Global Boundaries
Physical Curve("top", 10)    = Curve In BoundingBox{-bx-eps, -eps, -eps, bx+eps, eps, eps};
Physical Curve("bottom", 11) = Curve In BoundingBox{-bx-eps, by-eps, -eps, bx+eps, by+eps, eps};
Physical Curve("left", 12)   = Curve In BoundingBox{-bx-eps, by-eps, -eps, -bx+eps, eps, eps};
Physical Curve("right", 13)  = Curve In BoundingBox{bx-eps, by-eps, -eps, bx+eps, eps, eps};

// ==========================================
// 7. MESH ADAPTIVITY CONTROLS (Hybrid Halo + Interface)
// ==========================================
Mesh.MshFileVersion = 2.2; 
Mesh.ElementOrder = 2;

// Field 1 & 2: Distance Halo around the Utilidor
Field[1] = Distance;
Field[1].CurvesList = {soil_inner_wall[]};
Field[1].NumPointsPerCurve = 100;

Field[2] = Threshold;
Field[2].InField = 1;
Field[2].SizeMin = 0.06;   
Field[2].SizeMax = 1.5;    
Field[2].DistMin = 0.3;    
Field[2].DistMax = 1.5;    

// Field 3 & 4: Strict boxes over the Trench Wall interfaces
Field[3] = Box;
Field[3].VIn = 0.06;
Field[3].VOut = 1.5;
Field[3].XMin = tx1 - 0.2; // 20cm box straddling the left trench wall
Field[3].XMax = tx1 + 0.2;
Field[3].YMin = -(d+h);
Field[3].YMax = 0.0;
Field[3].Thickness = 0.8;

Field[4] = Box;
Field[4].VIn = 0.06;
Field[4].VOut = 1.5;
Field[4].XMin = tx2 - 0.2; // 20cm box straddling the right trench wall
Field[4].XMax = tx2 + 0.2;
Field[4].YMin = -(d+h);
Field[4].YMax = 0.0;
Field[4].Thickness = 0.8;

// Field 5: Minimum field (Takes the smallest element size from all fields)
Field[5] = Min;
Field[5].FieldsList = {2, 3, 4};

Background Field = 5;
Mesh.Optimize = 1;