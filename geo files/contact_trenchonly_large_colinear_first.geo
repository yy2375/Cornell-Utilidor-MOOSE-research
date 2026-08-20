// Multi-Layer NYC Utilidor: CONTACT MECHANICS MESH

// Configuration: Rigid Steel Trench (Scenario B) + Shallow Trench / Deep Subgrade

// Kernel: OpenCASCADE



SetFactory("OpenCASCADE");

Mesh.Algorithm = 6;



// ==========================================

// 1. PARAMETERS

// ==========================================

d  = 1.0;  // cover depth (Total trench depth = d + h = 3.0m)

h  = 2.0;  // utilidor height

w  = 2.0;  // utilidor width

t  = 0.2;  // concrete thickness

by = -30.5; // Restored: Deep subgrade invert

far_x = 15.0; // Far-field lateral boundary



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



// Sequential Backfill Layers

layer_h = (d + h) / 15;

For i In {1:15}

  y_start = -(i-1) * layer_h;

  Rectangle(100+i) = {tx1, y_start, 0, tw_total, -layer_h};

EndFor



// Fragment everything together (Embeds the trench layers into the soil block)

BooleanFragments{ Surface{1, 101:115}; Delete; }{}



// Punch the hole for the concrete utilidor

Rectangle(999) = {-w/2, -d, 0, w, -h};

soil_surfs[] = Surface In BoundingBox{-far_x-eps, by-eps, -eps, far_x+eps, eps, eps};

BooleanDifference{ Surface{soil_surfs[]}; Delete; }{ Surface{999}; Delete; }



// ==========================================

// 3. DEFINE SOIL CONTACT BOUNDARY

// ==========================================

// Fixed: Restricted X-coordinates to strictly bound the utilidor hole (-w/2 to w/2)

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



// ==========================================

// 5. DEFINE CONCRETE CONTACT BOUNDARY

// ==========================================

all_left  = Curve In BoundingBox{-w/2-eps, -d-h-eps, -eps, -w/2+eps, -d+eps, eps};

all_right = Curve In BoundingBox{w/2-eps, -d-h-eps, -eps, w/2+eps, -d+eps, eps};

all_top   = Curve In BoundingBox{-w/2-eps, -d-eps, -eps, w/2+eps, -d+eps, eps};

all_bot   = Curve In BoundingBox{-w/2-eps, -d-h-eps, -eps, w/2+eps, -d-h+eps, eps};



all_trench_curves[] = {all_left[], all_right[], all_top[], all_bot[]};



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



// Map Expanded Native Subgrade

base_surfs[] = Surface In BoundingBox{-far_x-eps, by-eps, -eps, far_x+eps, eps, eps};

base_surfs[] -= {11};

For i In {1:15}

  base_surfs[] -= Surface In BoundingBox{tx1-eps, -i*layer_h-eps, -eps, tx2+eps, -(i-1)*layer_h+eps, eps};

EndFor

Physical Surface("native_soil", 6) = base_surfs[];



// 1. Top Surface (The combination of trench top and ground surface)

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



Field[1] = Box;

Field[1].VIn = 0.04;      // The ultra-dense size locked INSIDE the box

Field[1].VOut = 1.0;      // The coarse size OUTSIDE the transition

Field[1].XMin = tx1;      // Left edge of trench

Field[1].XMax = tx2;      // Right edge of trench

Field[1].YMin = -(d+h);   // Bottom of trench

Field[1].YMax = 0.0;      // Top of ground

Field[1].Thickness = 3.0; // The width of the transition zone (in meters)



Background Field = 1;

Mesh.Optimize = 1; 

