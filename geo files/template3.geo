// Multi-Layer NYC Utilidor
// Configuration: Monolithic Box, Sharp Corners, Explicit 1D Dual-Mat Rebar
// Kernel: OpenCASCADE (Top-Down Constructive Solid Geometry)

SetFactory("OpenCASCADE");

// --- 1. Robustness Controls ---
Geometry.Tolerance = 1e-4;
Geometry.ToleranceBoolean = 1e-4;
Mesh.Algorithm = 6; 

// --- 2. Parameters ---
depth = DefineNumber[ 5.0, Name "Parameters/d" ];
height = DefineNumber[ 2.0, Name "Parameters/h" ];
width = DefineNumber[ 2.0, Name "Parameters/w" ];
thickness = DefineNumber[ 0.2, Name "Parameters/t" ];
H_fill = DefineNumber[ 4.0, Name "Parameters/H_fill" ];

// Concrete Cover (Distance from concrete face to center of rebar)
c = 0.05; // 50mm cover

bound_x = (width / 2.0) + (5 * width);
bound_y = -30.5;

// --- 3. Master 2D Geometries ---
Rectangle(1) = {-bound_x, 0, 0, 2*bound_x, bound_y}; // Earth
Rectangle(2) = {-width/2, -depth, 0, width, -height}; // Concrete Outer bounds
Rectangle(3) = {-width/2+thickness, -depth-thickness, 0, width-2*thickness, -(height-2*thickness)}; // Void

// --- 4. Define 1D Steel Rebar Cages ---
// Outer Mat Points
Point(20) = {-width/2+c, -depth-c, 0};
Point(21) = {width/2-c, -depth-c, 0};
Point(22) = {width/2-c, -depth-height+c, 0};
Point(23) = {-width/2+c, -depth-height+c, 0};
// Outer Mat Lines
Line(20) = {20,21}; Line(21) = {21,22}; Line(22) = {22,23}; Line(23) = {23,20};

// Inner Mat Points
Point(30) = {-width/2+thickness-c, -depth-thickness+c, 0};
Point(31) = {width/2-thickness+c, -depth-thickness+c, 0};
Point(32) = {width/2-thickness+c, -depth-height+thickness-c, 0};
Point(33) = {-width/2+thickness-c, -depth-height+thickness-c, 0};
// Inner Mat Lines
Line(30) = {30,31}; Line(31) = {31,32}; Line(32) = {32,33}; Line(33) = {33,30};

// --- 5. Boolean Operations ---
// 1. Cut the solid shell out of the earth
BooleanDifference(10) = {Surface{1}; Delete;}{Surface{2};};
// 2. Hollow out the concrete shell
BooleanDifference(11) = {Surface{2}; Delete;}{Surface{3}; Delete;};

// 3. The Stratigraphy Slicer
Point(100) = {-bound_x, -H_fill, 0};
Point(101) = {bound_x, -H_fill, 0};
Line(100) = {100, 101};

// 4. THE MASTER FRAGMENT
// This single command embeds the 1D rebar into the 2D concrete AND slices the soil.
// It will split the concrete shell into 3 concentric rings (outer cover, core, inner cover)
// that perfectly share all nodes with the rebar grid.
BooleanFragments{ Surface{10, 11}; Delete; }{ Curve{100, 20,21,22,23, 30,31,32,33}; Delete; }

// --- 6. Dynamic Physical Group Assignment ---
eps = 0.01; // Tight 10mm tolerance to isolate specific rebar lines

// Re-group the 3 concentric concrete rings back into one block for MOOSE
surf_concrete[] = Surface In BoundingBox{-width/2-eps, -depth-height-eps, -eps, width/2+eps, -depth+eps, eps};
Physical Surface("concrete") = surf_concrete[];

// Assign Outer Rebar Grid (Isolating the 4 walls)
c_out_t[] = Curve In BoundingBox{-width/2-eps, -depth-c-eps, -eps, width/2+eps, -depth-c+eps, eps};
c_out_b[] = Curve In BoundingBox{-width/2-eps, -depth-height+c-eps, -eps, width/2+eps, -depth-height+c+eps, eps};
c_out_l[] = Curve In BoundingBox{-width/2+c-eps, -depth-height-eps, -eps, -width/2+c+eps, -depth+eps, eps};
c_out_r[] = Curve In BoundingBox{width/2-c-eps, -depth-height-eps, -eps, width/2-c+eps, -depth+eps, eps};
Physical Curve("rebar_outer") = {c_out_t[], c_out_b[], c_out_l[], c_out_r[]};

// Assign Inner Rebar Grid
c_in_t[] = Curve In BoundingBox{-width/2-eps, -depth-thickness+c-eps, -eps, width/2+eps, -depth-thickness+c+eps, eps};
c_in_b[] = Curve In BoundingBox{-width/2-eps, -depth-height+thickness-c-eps, -eps, width/2+eps, -depth-height+thickness-c+eps, eps};
c_in_l[] = Curve In BoundingBox{-width/2+thickness-c-eps, -depth-height-eps, -eps, -width/2+thickness-c+eps, -depth+eps, eps};
c_in_r[] = Curve In BoundingBox{width/2-thickness-c-eps, -depth-height-eps, -eps, width/2-thickness-c+eps, -depth+eps, eps};
Physical Curve("rebar_inner") = {c_in_t[], c_in_b[], c_in_l[], c_in_r[]};

// Soil Groups
surf_fill_all[] = Surface In BoundingBox{-bound_x-eps, -H_fill-eps, -eps, bound_x+eps, eps, eps};
surf_fill[] = surf_fill_all[]; surf_fill[] -= surf_concrete[]; 
Physical Surface("fill") = surf_fill[];

surf_native_all[] = Surface In BoundingBox{-bound_x-eps, bound_y-eps, -eps, bound_x+eps, -H_fill+eps, eps};
surf_native[] = surf_native_all[]; surf_native[] -= surf_concrete[];
Physical Surface("native") = surf_native[];

// External Boundaries
Physical Curve("top") = Curve In BoundingBox{-bound_x-eps, -eps, -eps, bound_x+eps, eps, eps};
Physical Curve("bottom") = Curve In BoundingBox{-bound_x-eps, bound_y-eps, -eps, bound_x+eps, bound_y+eps, eps};
Physical Curve("left") = Curve In BoundingBox{-bound_x-eps, bound_y-eps, -eps, -bound_x+eps, eps, eps};
Physical Curve("right") = Curve In BoundingBox{bound_x-eps, bound_y-eps, -eps, bound_x+eps, eps, eps};

// --- 7. Mesh Density Controls ---
Mesh.MeshSizeMax = 1.0;  
Mesh.MeshSizeMin = 0.04; 
Mesh.MeshSizeFromPoints = 1;
Mesh.MeshSizeExtendFromBoundary = 1;

pts_concrete[] = Point In BoundingBox{-width/2-eps, -depth-height-eps, -eps, width/2+eps, -depth+eps, eps};
MeshSize { pts_concrete[] } = 0.04;