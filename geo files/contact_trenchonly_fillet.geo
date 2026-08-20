// Multi-Layer NYC Utilidor: CONTACT MECHANICS MESH
// Configuration: Rigid Steel Trench (Scenario B) + Deep Subgrade + 0.0mm Topological Gap
// Kernel: OpenCASCADE
// MOD: Outer (soil-facing) corners of the concrete utilidor are now filleted.
//      Radius is parameterized as `r_fillet` below.

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
by = -30.5; // Deep subgrade invert

// NEW: Fillet radius for the OUTER (soil-contact) corners of the concrete box.
// Must satisfy r_fillet < min(w,h)/2 (OCC will error on Rectangle() otherwise).
r_fillet = DefineNumber[ 0.15, Name "Parameters/1. Structural/outer fillet radius (r_fillet)" ];

eps = 1e-3; 

// Trench boundaries
ws = 0.5; // Working space
tx1 = -w/2 - ws; // Left trench wall
tx2 = w/2 + ws;  // Right trench wall
tw_total = tx2 - tx1; // Total excavated width

// ==========================================
// 2. BUILD SOIL CONTINUUM & PUNCH HOLE
// ==========================================
// Subgrade (Native soil below utilidor)
Rectangle(1) = {tx1, by, 0, tw_total, -(d+h) - by};

// Sequential Backfill Layers
layer_h = (d + h) / 15;
For i In {1:15}
  y_start = -(i-1) * layer_h;
  Rectangle(100+i) = {tx1, y_start, 0, tw_total, -layer_h};
EndFor

// Fragment everything together to share nodes
BooleanFragments{ Surface{1, 101:115}; Delete; }{}

// Punch the hole for the concrete utilidor (Exact dimension, MATCHING fillet)
// The soil-side excavation uses the SAME rounded-rectangle profile (same
// r_fillet) as the concrete outer profile in Section 4. If the soil hole
// were left sharp-cornered while the concrete corner is rounded, a
// crescent-shaped gap appears between the two surfaces at every corner --
// breaking the 0.0mm topological gap exactly where the fillet is. Matching
// the profile here closes that gap while keeping the two surfaces
// topologically separate (not fragmented together) for contact mechanics.
Rectangle(999) = {-w/2, -d, 0, w, -h, r_fillet};
soil_surfs[] = Surface In BoundingBox{tx1-eps, by-eps, -eps, tx2+eps, eps, eps};
BooleanDifference{ Surface{soil_surfs[]}; Delete; }{ Surface{999}; Delete; }

// ==========================================
// 3. DEFINE SOIL CONTACT BOUNDARY
// ==========================================
// Bounding box using standard eps (1e-3) because the gap is 0.0mm
soil_left  = Curve In BoundingBox{-w/2-eps, -d-h-eps, -eps, -w/2+eps, -d+eps, eps};
soil_right = Curve In BoundingBox{w/2-eps, -d-h-eps, -eps, w/2+eps, -d+eps, eps};
soil_top   = Curve In BoundingBox{-w/2-eps, -d-eps, -eps, w/2+eps, -d+eps, eps};
soil_bot   = Curve In BoundingBox{-w/2-eps, -d-h-eps, -eps, w/2+eps, -d-h+eps, eps};

// NEW: the soil hole is now rounded too (matching r_fillet), so its four
// corner fillet arcs need to be captured the same way as the concrete's
// (see Section 5). Small per-corner boxes sized to r_fillet.
feps = r_fillet + eps;
soil_fillet_BL[] = Curve In BoundingBox{-w/2-eps,  -d-feps,   -eps, -w/2+feps, -d+eps,    eps};
soil_fillet_BR[] = Curve In BoundingBox{ w/2-feps, -d-feps,   -eps,  w/2+eps,  -d+eps,    eps};
soil_fillet_TL[] = Curve In BoundingBox{-w/2-eps,  -d-h-eps,  -eps, -w/2+feps, -d-h+feps, eps};
soil_fillet_TR[] = Curve In BoundingBox{ w/2-feps, -d-h-eps,  -eps,  w/2+eps,  -d-h+feps, eps};
soil_fillet_arcs[] = {soil_fillet_BL[], soil_fillet_BR[], soil_fillet_TL[], soil_fillet_TR[]};

soil_inner_wall[] = {soil_left[], soil_right[], soil_top[], soil_bot[], soil_fillet_arcs[]};
Physical Curve("soil_inner_wall", 20) = soil_inner_wall[];

// ==========================================
// 4. BUILD UTILIDOR (Plain Concrete)
// ==========================================
// OUTER profile: drawn at the soil boundaries, with OCC's native rounded-
// rectangle corner support. Rectangle(x,y,z,dx,dy,roundedRadius) fillets all
// 4 corners by r_fillet. (OCC kernel only -- this argument is ignored/invalid
// under the built-in kernel, which is why SetFactory("OpenCASCADE") above is
// required.)
Rectangle(2) = {-w/2, -d, 0, w, -h, r_fillet};

// INNER cavity stays sharp-cornered (purely an internal/mechanical boundary,
// not the soil-contact face the request asked for).
Rectangle(3) = {-w/2+t, -d-t, 0, w-2*t, -(h-2*t)}; 

BooleanDifference(11) = {Surface{2}; Delete;}{Surface{3}; Delete;};

// DO NOT FRAGMENT SURFACE 11. 
// This keeps the concrete topologically separated from the soil for contact mechanics.

// ==========================================
// 5. DEFINE CONCRETE CONTACT BOUNDARY
// ==========================================
// Grab BOTH the soil lines and the newly drawn concrete lines occupying the exact same space.
// NOTE: With filleted corners, the straight edges of the concrete outer
// profile are inset by r_fillet at each end, but they still lie exactly on
// the nominal box faces (x = -w/2, x = +w/2, y = -d, y = -d-h), so the same
// thin BoundingBox slabs used for the soil boundary still capture them.
all_left  = Curve In BoundingBox{-w/2-eps, -d-h-eps, -eps, -w/2+eps, -d+eps, eps};
all_right = Curve In BoundingBox{w/2-eps, -d-h-eps, -eps, w/2+eps, -d+eps, eps};
all_top   = Curve In BoundingBox{-w/2-eps, -d-eps, -eps, w/2+eps, -d+eps, eps};
all_bot   = Curve In BoundingBox{-w/2-eps, -d-h-eps, -eps, w/2+eps, -d-h+eps, eps};

all_trench_curves[] = {all_left[], all_right[], all_top[], all_bot[]};

// NEW: the four quarter-circle fillet arcs live entirely inside small
// (r_fillet x r_fillet) boxes tucked into each corner of the outer profile.
// They are NOT captured by the thin straight-edge slabs above, so grab them
// explicitly with a small bounding box at each corner. (feps already
// defined in Section 3.)
fillet_BL[] = Curve In BoundingBox{-w/2-eps,      -d-feps,   -eps, -w/2+feps, -d+eps,    eps}; // bottom-left  (top face, near x=-w/2)
fillet_BR[] = Curve In BoundingBox{ w/2-feps,     -d-feps,   -eps,  w/2+eps,  -d+eps,    eps}; // bottom-right (top face, near x=+w/2)
fillet_TL[] = Curve In BoundingBox{-w/2-eps,      -d-h-eps,  -eps, -w/2+feps, -d-h+feps, eps}; // top-left     (bottom face, near x=-w/2)
fillet_TR[] = Curve In BoundingBox{ w/2-feps,     -d-h-eps,  -eps,  w/2+eps,  -d-h+feps, eps}; // top-right    (bottom face, near x=+w/2)

fillet_arcs[] = {fillet_BL[], fillet_BR[], fillet_TL[], fillet_TR[]};
all_trench_curves[] += fillet_arcs[];

// Subtract the soil curves (straight edges AND soil-side fillet arcs, both
// now included in soil_inner_wall) to isolate exactly the concrete curves.
// Soil and concrete arcs sit at the same location but are distinct curve
// entities (different tags, since the two surfaces are not fragmented
// together), so this subtraction works the same way it always did.
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
  layer_surfs[] = Surface In BoundingBox{tx1-eps, y_bot-eps, -eps, tx2+eps, y_top+eps, eps};
  layer_surfs[] -= {11}; 
  Physical Surface(Sprintf("layer_%g", i), 100+i) = layer_surfs[];
EndFor

// Map Native Subgrade
base_surfs[] = Surface In BoundingBox{tx1-eps, by-eps, -eps, tx2+eps, -(d+h)+eps, eps};
base_surfs[] -= {11};
Physical Surface("native_soil", 6) = base_surfs[];

// Global Boundaries mapped strictly to the trench extents + subgrade depth
Physical Curve("top", 10)    = Curve In BoundingBox{tx1-eps, -eps, -eps, tx2+eps, eps, eps};
Physical Curve("bottom", 11) = Curve In BoundingBox{tx1-eps, by-eps, -eps, tx2+eps, by+eps, eps};
Physical Curve("left", 12)   = Curve In BoundingBox{tx1-eps, by-eps, -eps, tx1+eps, eps, eps};
Physical Curve("right", 13)  = Curve In BoundingBox{tx2-eps, by-eps, -eps, tx2+eps, eps, eps};

// ==========================================
// 7. MESH ADAPTIVITY CONTROLS
// ==========================================
Mesh.MshFileVersion = 2.2; 
Mesh.ElementOrder = 2;
// Repairs invalid/near-degenerate curved elements that can appear when
// 2nd-order elevation meets a sharp local mesh-size gradient -- exactly the
// situation at the fillet tangent points below.
Mesh.HighOrderOptimize = 2;

// Dense mesh for the backfill and utilidor pressure bulb, coarse for deep subgrade.
// VIn applies down to YMin (y = -9.5, i.e. 2.5m below the utilidor base) --
// unchanged from before. Below that, Thickness controls how gradually the
// element size grows from VIn to VOut: stretched from 1.5m to most of the
// remaining native-soil depth (down to by = -30.5) so the transition is a
// slow taper rather than an abrupt jump to coarse size.
coarse_size = 1.0; // shared target size for the deep/far-field region (used
                    // by both the Box taper below and the fillet Threshold
                    // field's SizeMax, so the fillet field's far-field value
                    // doesn't silently override the Box taper through Min()).
Field[1] = Box;
Field[1].VIn = 0.08; 
Field[1].VOut = coarse_size; 
Field[1].XMin = tx1 - eps;
Field[1].XMax = tx2 + eps;
Field[1].YMin = -(d+h) - 2.5; 
Field[1].YMax = eps;
Field[1].Thickness = -by - ((d+h) + 2.5); // taper over the rest of the subgrade depth, down to y = by

// NEW: local refinement around the fillet corners. The global Box field
// above (VIn = 0.08) is coarse relative to r_fillet, and the soil-side
// fillet arcs additionally get split by the backfill layer boundaries that
// cross through that radius. Left alone, this produces sliver elements
// right where the straight inset edges meet the fillet arcs (a curvature
// discontinuity that curvature-adaptive sizing alone does not resolve,
// since the straight side has zero curvature). The reliable fix is to set
// an explicit small mesh size directly on the 8 tangent points (4 corners x
// 2 tangent points each) where straight meets arc, on both the concrete
// and the soil profile.
fillet_size = r_fillet / 3;
tangent_pts[] = {};
corner_x[] = {-w/2, w/2};
corner_y[] = {-d, -d-h};
For ix In {0:1}
  For iy In {0:1}
    cx = corner_x[ix];
    cy = corner_y[iy];
    // tangent point on the horizontal (top/bottom) straight edge
    px_h = (ix == 0) ? cx + r_fillet : cx - r_fillet;
    // tangent point on the vertical (left/right) straight edge
    py_v = (iy == 0) ? cy - r_fillet : cy + r_fillet;
    pts_h[] = Point In BoundingBox{px_h-eps, cy-eps, -eps, px_h+eps, cy+eps, eps};
    pts_v[] = Point In BoundingBox{cx-eps, py_v-eps, -eps, cx+eps, py_v+eps, eps};
    tangent_pts[] += pts_h[];
    tangent_pts[] += pts_v[];
  EndFor
EndFor
MeshSize{ tangent_pts[] } = fillet_size;

// Also size the arcs themselves so the corner stays smoothly resolved,
// tapering back out to the Box field's size away from the corners.
Field[2] = Distance;
Field[2].CurvesList = {fillet_arcs[], soil_fillet_arcs[]};
Field[2].Sampling = 100;

Field[3] = Threshold;
Field[3].InField = 2;
Field[3].SizeMin = fillet_size;
Field[3].SizeMax = coarse_size; // matches the Box field's coarse value -- otherwise
                                 // Field[3]'s SizeMax (imposed everywhere beyond
                                 // DistMax) silently overrides the Box taper via Min()
Field[3].DistMin = r_fillet / 2;
Field[3].DistMax = r_fillet * 3;

Field[4] = Min;
Field[4].FieldsList = {1, 3};

Background Field = 4;
Mesh.Optimize = 1;
// CRITICAL: Do NOT execute Coherence;