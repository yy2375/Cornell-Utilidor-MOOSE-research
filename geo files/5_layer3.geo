// 5-Layer NYC Utilidor (Fill, Sand, Clay, Till, Schist + Concrete)
// Location: Beekman Street Baseline
// Kernel: OpenCASCADE (Top-Down Constructive Solid Geometry)

SetFactory("OpenCASCADE");

// --- 1. Robustness Controls ---
Geometry.Tolerance = 1e-4;
Geometry.ToleranceBoolean = 1e-4;
Mesh.Algorithm = 6; // Frontal-Delaunay (Optimal for 2D interfaces)

// --- 2. Parameters ---
depth = DefineNumber[ 5.0, Name "Parameters/d" ];
height = DefineNumber[ 2.0, Name "Parameters/h" ];
width = DefineNumber[ 2.0, Name "Parameters/w" ];
thickness = DefineNumber[ 0.2, Name "Parameters/t" ];

// Stratigraphic Interfaces (Aligned with Langan Engineering Borings)
H_fill = DefineNumber[ 6.1, Name "Parameters/H_fill" ];
H_sand = DefineNumber[ 13.7, Name "Parameters/H_sand" ];
H_clay = DefineNumber[ 21.3, Name "Parameters/H_clay" ];
H_till = DefineNumber[ 30.5, Name "Parameters/H_till" ];

// Optimal 5x Multiplier for Lateral Boundaries
bound_x = (width / 2.0) + (5 * width);

// Bedrock floor set to 35 meters to match Manhattan Schist depth
bound_y = -35.0;

// --- 3. Master Geometries ---
// Create the whole Earth block (0 down to -35.0)
Rectangle(1) = {-bound_x, 0, 0, 2*bound_x, bound_y}; 

// Create the solid concrete utilidor block
Rectangle(2) = {-width/2, -depth, 0, width, -height}; 

// Create the inner void block
Rectangle(3) = {-width/2+thickness, -depth-thickness, 0, width-2*thickness, -(height-2*thickness)};

// --- 4. Boolean Operations (The Slicer Method) ---
// Cut the solid concrete shell completely out of the Earth
BooleanDifference(4) = {Surface{1}; Delete;}{Surface{2}; };

// Cut the void out of the solid shell to hollow it
BooleanDifference(5) = {Surface{2}; Delete;}{Surface{3}; Delete;};

// Create horizontal slicer lines for every soil boundary
Point(100) = {-bound_x, -H_fill, 0};
Point(101) = {bound_x, -H_fill, 0};
Line(100) = {100, 101};

Point(102) = {-bound_x, -H_sand, 0};
Point(103) = {bound_x, -H_sand, 0};
Line(101) = {102, 103};

Point(104) = {-bound_x, -H_clay, 0};
Point(105) = {bound_x, -H_clay, 0};
Line(102) = {104, 105};

Point(106) = {-bound_x, -H_till, 0};
Point(107) = {bound_x, -H_till, 0};
Line(103) = {106, 107};

// Fragment the Earth and Shell using all Slicer Lines simultaneously
BooleanFragments{ Surface{4, 5}; Delete; }{ Curve{100, 101, 102, 103}; Delete; }

// --- 5. Dynamic Physical Group Assignment ---
// 5cm tolerance to catch minor OpenCASCADE bounding inflation
eps = 0.05; 

surf_concrete[] = Surface In BoundingBox{-width/2-eps, -depth-height-eps, -eps, width/2+eps, -depth+eps, eps};

// Identify surfaces by their vertical domains
surf_fill_all[]   = Surface In BoundingBox{-bound_x-eps, -H_fill-eps, -eps, bound_x+eps, eps, eps};
surf_sand_all[]   = Surface In BoundingBox{-bound_x-eps, -H_sand-eps, -eps, bound_x+eps, -H_fill+eps, eps};
surf_clay_all[]   = Surface In BoundingBox{-bound_x-eps, -H_clay-eps, -eps, bound_x+eps, -H_sand+eps, eps};
surf_till_all[]   = Surface In BoundingBox{-bound_x-eps, -H_till-eps, -eps, bound_x+eps, -H_clay+eps, eps};
surf_schist_all[] = Surface In BoundingBox{-bound_x-eps, bound_y-eps, -eps, bound_x+eps, -H_till+eps, eps};

// Subtract concrete to prevent double-assignment if utilidor is fully within one layer
surf_fill[] = surf_fill_all[];     surf_fill[] -= surf_concrete[];
surf_sand[] = surf_sand_all[];     surf_sand[] -= surf_concrete[];
surf_clay[] = surf_clay_all[];     surf_clay[] -= surf_concrete[];
surf_till[] = surf_till_all[];     surf_till[] -= surf_concrete[];
surf_schist[] = surf_schist_all[]; surf_schist[] -= surf_concrete[];

// Assign Material Blocks for MOOSE
Physical Surface("fill") = surf_fill[];
Physical Surface("sand") = surf_sand[];
Physical Surface("clay") = surf_clay[];
Physical Surface("till") = surf_till[];
Physical Surface("schist") = surf_schist[];
Physical Surface("concrete") = surf_concrete[];

// Assign Boundary Conditions
Physical Curve("top") = Curve In BoundingBox{-bound_x-eps, -eps, -eps, bound_x+eps, eps, eps};
Physical Curve("bottom") = Curve In BoundingBox{-bound_x-eps, bound_y-eps, -eps, bound_x+eps, bound_y+eps, eps};
Physical Curve("left") = Curve In BoundingBox{-bound_x-eps, bound_y-eps, -eps, -bound_x+eps, eps, eps};
Physical Curve("right") = Curve In BoundingBox{bound_x-eps, bound_y-eps, -eps, bound_x+eps, eps, eps};

// Inner wall for MOOSE postprocessor extraction
Physical Curve("wall") = Curve In BoundingBox{-width/2+thickness-eps, -depth-height+thickness-eps, -eps, width/2-thickness+eps, -depth-thickness+eps, eps};

// --- 6. Mesh Density Controls (Distance & Threshold) ---

// 1. Capture every line segment making up the concrete shell
crv_concrete[] = Curve In BoundingBox{-width/2-eps, -depth-height-eps, -eps, width/2+eps, -depth+eps, eps};

// 2. Calculate the exact distance from the soil to the concrete walls
Field[1] = Distance;
Field[1].CurvesList = {crv_concrete[]}; // CORRECTED: Curly brackets unpack the array
Field[1].NumPointsPerCurve = 100;       // Forces high-resolution distance calculation

// 3. Apply a Threshold to grade the mesh size based on that distance
Field[2] = Threshold;
Field[2].InField = 1;
Field[2].SizeMin = 0.08;  // Strict 8cm elements
Field[2].SizeMax = 1.0;   // 1.0m elements in the far-field

// 4. Define the physical transition boundaries
Field[2].DistMin = 0.0;   // Start growing the mesh instantly away from the concrete walls
Field[2].DistMax = 1.5;   // Reach the maximum 1.0m element size at 1.5 meters away

// Set this as the master controller for the mesher
Background Field = 2;
Mesh.MeshSizeExtendFromBoundary = 0;
Mesh.MeshSizeFromPoints = 0;
Mesh.MeshSizeFromCurvature = 0;