// Multi-Layer NYC Utilidor: VARIABLE CONTACT MESH
// Configuration: Divided Topology for Layer-Specific Contact
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
// 2. BUILD SOIL CONTINUUM
// ==========================================
Rectangle(1) = {-bx, -(d+h), 0, 2*bx, by+(d+h)}; 
layer_h = (d + h) / 15;

For i In {1:15}
  y_start = -(i-1) * layer_h;
  Rectangle(100+i) = {-bx, y_start, 0, 2*bx, -layer_h};
EndFor

// Fragment surfaces to ensure topological separation at layer boundaries
BooleanFragments{ Surface{1, 101:115}; Delete; }{}

Rectangle(999) = {-w/2, -d, 0, w, -h};
soil_surfs[] = Surface In BoundingBox{-bx-eps, by-eps, -eps, bx+eps, eps, eps};
BooleanDifference{ Surface{soil_surfs[]}; Delete; }{ Surface{999}; Delete; }

// ==========================================
// 3. SEGMENTED SOIL CONTACT BOUNDARIES
// (Must be defined BEFORE concrete is generated to isolate IDs)
// ==========================================
all_soil_curves[] = {}; // Master list for subtraction later

For i In {1:15}
  y_top = -(i-1)*layer_h;
  y_bot = -i*layer_h;

  s_left[] = Curve In BoundingBox{-w/2-eps, y_bot-eps, -eps, -w/2+eps, y_top+eps, eps};
  s_right[] = Curve In BoundingBox{w/2-eps, y_bot-eps, -eps, w/2+eps, y_top+eps, eps};
  
  Physical Curve(Sprintf("soil_inner_wall_layer_%g", i)) = {s_left[], s_right[]};
  
  // Append to master list
  all_soil_curves[] += s_left[];
  all_soil_curves[] += s_right[];
EndFor

// ==========================================
// 4. BUILD UTILIDOR
// ==========================================
Rectangle(2) = {-w/2, -d, 0, w, -h}; 
Rectangle(3) = {-w/2+t, -d-t, 0, w-2*t, -(h-2*t)}; 
BooleanDifference(11) = {Surface{2}; Delete;}{Surface{3}; Delete;}; 

// ==========================================
// 5. SEGMENTED CONCRETE CONTACT BOUNDARIES
// ==========================================
For i In {1:15}
  y_top = -(i-1)*layer_h;
  y_bot = -i*layer_h;

  // This bounding box grabs BOTH soil and concrete curves
  c_left[] = Curve In BoundingBox{-w/2-eps, y_bot-eps, -eps, -w/2+eps, y_top+eps, eps};
  c_right[] = Curve In BoundingBox{w/2-eps, y_bot-eps, -eps, w/2+eps, y_top+eps, eps};
  
  // Subtract the known soil curves to leave only the concrete curves
  c_left[] -= all_soil_curves[];
  c_right[] -= all_soil_curves[];
  
  Physical Curve(Sprintf("concrete_outer_wall_layer_%g", i)) = {c_left[], c_right[]};
EndFor

// ==========================================
// 6. PHYSICAL ENTITY MAPPING (Layers & Native)
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
// 7. MESH ADAPTIVITY
// ==========================================
Mesh.MshFileVersion = 2.2; 
Mesh.ElementOrder = 2;     
Field[1] = Box;
Field[1].VIn = 0.05;
Field[1].VOut = 1.5;
Field[1].XMin = -w/2;
Field[1].XMax =  w/2;
Field[1].YMin = -d - h;
Field[1].YMax = -d;
Field[1].Thickness = 1.0; 
Background Field = 1;
Mesh.Optimize = 1;