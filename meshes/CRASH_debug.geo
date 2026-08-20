// Multi-Layer NYC Utilidor
// Kernel: OpenCASCADE (Top-Down Constructive Solid Geometry)

SetFactory("OpenCASCADE");

// --- 1. Robustness Controls ---
// Force OpenCASCADE to snap microscopic gaps to prevent Delaunay meshing loops
Geometry.Tolerance = 1e-4;
Geometry.ToleranceBoolean = 1e-4;
Mesh.Algorithm = 6; // Frontal-Delaunay (Optimal for 2D interfaces)

// --- 2. Parameters (Must match Python replacement strings exactly) ---
depth = 7.465836324729025;
height = 2.669461281504482;
width = 2.891728708986193;
thickness = 0.4448949086014181;
H_fill = 4.471735548228025;

// Optimal 5x Multiplier for Lateral Boundaries
bound_x = (width / 2.0) + (5 * width);

// Depth fixed to Beekman St bedrock validation
bound_y = -30.5;

// --- 3. Master Geometries ---
// Create the whole Earth block (0 down to -30.5)
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

// Create a horizontal slicer line at the exact fill depth
Point(100) = {-bound_x, -H_fill, 0};
Point(101) = {bound_x, -H_fill, 0};
Line(100) = {100, 101};

// Fragment the Earth and Shell using the Slicer Line.
// This splits the soil exactly at the boundary without overlapping errors.
BooleanFragments{ Surface{4, 5}; Delete; }{ Curve{100}; Delete; }

// --- 5. Dynamic Physical Group Assignment ---
// 5cm tolerance to catch minor OpenCASCADE bounding inflation
eps = 0.05; 

surf_concrete[] = Surface In BoundingBox{-width/2-eps, -depth-height-eps, -eps, width/2+eps, -depth+eps, eps};
surf_fill_all[] = Surface In BoundingBox{-bound_x-eps, -H_fill-eps, -eps, bound_x+eps, eps, eps};
surf_native_all[] = Surface In BoundingBox{-bound_x-eps, bound_y-eps, -eps, bound_x+eps, -H_fill+eps, eps};

// Subtract concrete to prevent double-assignment if utilidor is fully within one layer
surf_fill[] = surf_fill_all[];
surf_fill[] -= surf_concrete[];

surf_native[] = surf_native_all[];
surf_native[] -= surf_concrete[];

// Assign Material Blocks for MOOSE
Physical Surface("fill") = surf_fill[];
Physical Surface("native") = surf_native[];
Physical Surface("concrete") = surf_concrete[];

// Assign Boundary Conditions
Physical Curve("top") = Curve In BoundingBox{-bound_x-eps, -eps, -eps, bound_x+eps, eps, eps};
Physical Curve("bottom") = Curve In BoundingBox{-bound_x-eps, bound_y-eps, -eps, bound_x+eps, bound_y+eps, eps};
Physical Curve("left") = Curve In BoundingBox{-bound_x-eps, bound_y-eps, -eps, -bound_x+eps, eps, eps};
Physical Curve("right") = Curve In BoundingBox{bound_x-eps, bound_y-eps, -eps, bound_x+eps, eps, eps};

// Inner wall for MOOSE postprocessor extraction
Physical Curve("wall") = Curve In BoundingBox{-width/2+thickness-eps, -depth-height+thickness-eps, -eps, width/2-thickness+eps, -depth-thickness+eps, eps};

// --- 6. Mesh Density Controls (Point-Based) ---

// 1. Set the global bounds (Outside is 1.0, finest allowed is 0.05)
Mesh.MeshSizeMax = 1.0;
Mesh.MeshSizeMin = 0.05;

// 2. Ensure Gmsh calculates mesh sizes from points (Default Built-in behavior)
Mesh.MeshSizeFromPoints = 1;
Mesh.MeshSizeExtendFromBoundary = 1;
Mesh.MeshSizeFromCurvature = 0;

// 3. Dynamically locate all points on the utilidor (corners and intersection nodes)
eps = 0.05;
pts_concrete[] = Point In BoundingBox{-width/2-eps, -depth-height-eps, -eps, width/2+eps, -depth+eps, eps};

// 4. Force the mesh size exclusively on those points
MeshSize { pts_concrete[] } = 0.05;