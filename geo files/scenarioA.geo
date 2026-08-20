// Multi-Layer NYC Utilidor: SCENARIO A (No Contact, No Steel, Fully Bonded)
// Configuration: Elastic macro-layers (Blocks 1, 2, 3, 6)
// Kernel: OpenCASCADE

SetFactory("OpenCASCADE");
Geometry.Tolerance = 1e-4;
Geometry.ToleranceBoolean = 1e-4;
Mesh.Algorithm = 6; 

// ==========================================
// 1. PARAMETERS
// ==========================================
d  = 5.0;  // Depth to roof
h  = 2.0;  // Utilidor height
w  = 2.0;  // Utilidor width
t  = 0.2;  // Wall thickness
by = -30.5; // Bottom boundary

bx = w/2 + 5*w; 
eps = 1e-3; 

// ==========================================
// 2. BUILD MACRO-LAYER GEOMETRY
// ==========================================
// Native Soil (Block 6)
Rectangle(1) = {-bx, -(d+h), 0, 2*bx, by+(d+h)}; 

// Side Fill - Left and Right (Block 2)
Rectangle(2) = {-bx, -d, 0, bx - w/2, -h}; 
Rectangle(3) = {w/2, -d, 0, bx - w/2, -h}; 

// Top Fill (Block 3)
Rectangle(4) = {-bx, 0, 0, 2*bx, -d}; 

// Concrete Utilidor Wall (Block 1)
Rectangle(5) = {-w/2, -d, 0, w, -h}; 
Rectangle(6) = {-w/2+t, -d-t, 0, w-2*t, -(h-2*t)}; 
BooleanDifference(11) = {Surface{5}; Delete;}{Surface{6}; Delete;}; 

// ==========================================
// 3. FUSE TOPOLOGY (Creates Shared Nodes / No Contact)
// ==========================================
// Fragmenting all intersecting geometry ensures perfectly conforming elements
// across boundaries without any overlapping or detached nodes.
BooleanFragments{ Surface{1, 2, 3, 4, 11}; Delete; }{}

// ==========================================
// 4. PHYSICAL ENTITY MAPPING
// ==========================================
conc_surfs[] = Surface In BoundingBox{-w/2-eps, -d-h-eps, -eps, w/2+eps, -d+eps, eps};
Physical Surface("concrete", 1) = conc_surfs[];

side_left[]  = Surface In BoundingBox{-bx-eps, -d-h-eps, -eps, -w/2+eps, -d+eps, eps};
side_right[] = Surface In BoundingBox{w/2-eps, -d-h-eps, -eps, bx+eps, -d+eps, eps};
// Subtract concrete from side boxes to prevent accidental overlapping assignment
side_left[]  -= conc_surfs[];
side_right[] -= conc_surfs[];
Physical Surface("side_fill", 2) = {side_left[], side_right[]};

top_surfs[] = Surface In BoundingBox{-bx-eps, -d-eps, -eps, bx+eps, eps, eps};
Physical Surface("top_fill", 3) = top_surfs[];

native_surfs[] = Surface In BoundingBox{-bx-eps, by-eps, -eps, bx+eps, -(d+h)+eps, eps};
Physical Surface("native_soil", 6) = native_surfs[];

// Native Sideset Assignments (Replaces ParsedGenerateSideset in MOOSE)
Physical Curve("top", 10)    = Curve In BoundingBox{-bx-eps, -eps, -eps, bx+eps, eps, eps};
Physical Curve("bottom", 11) = Curve In BoundingBox{-bx-eps, by-eps, -eps, bx+eps, by+eps, eps};
Physical Curve("left", 12)   = Curve In BoundingBox{-bx-eps, by-eps, -eps, -bx+eps, eps, eps};
Physical Curve("right", 13)  = Curve In BoundingBox{bx-eps, by-eps, -eps, bx+eps, eps, eps};

// ==========================================
// 5. MESH ADAPTIVITY CONTROLS
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
Field[1].Thickness = 0.3; 

Background Field = 1;
Mesh.Optimize = 1;

// Coherence removes all duplicate nodes left over by geometric intersections.
// This guarantees perfect continuous elastic transmission across soil/concrete.
Coherence;