// Multi-Layer NYC Utilidor: BONDED CONTINUUM WITH THIN FILLETED INTERFACE LAYER
// Configuration: Filleted concrete utilidor + thin continuum interface + layered backfill
// Kernel: OpenCASCADE

SetFactory("OpenCASCADE");
Geometry.Tolerance = 1e-4;
Geometry.ToleranceBoolean = 1e-4;
Mesh.Algorithm = 6;

// ==========================================
// 1. PARAMETERS
// ==========================================
d  = 1.0;    // cover depth
h  = 2.0;    // utilidor outer height
w  = 2.0;    // utilidor outer width
t  = 0.2;    // concrete wall thickness
by = -30.5;  // bottom of model
far_x = 15.0;

r_fillet = 0.15; // concrete OUTER corner radius
ci = 0.05;       // thin bonded interface thickness

eps = 1e-3;

// Trench/backfill width
ws = 0.5;
tx1 = -w/2 - ws;
tx2 =  w/2 + ws;
tw_total = tx2 - tx1;

// Concrete outer envelope
cx1 = -w/2;
cx2 =  w/2;
cy_top = -d;
cy_bot = -d - h;

// Interface outer envelope
ix1 = cx1 - ci;
ix2 = cx2 + ci;
iy_top = cy_top + ci;
iy_bot = cy_bot - ci;
iw = ix2 - ix1;
ih = iy_top - iy_bot;
r_interface = r_fillet + ci;

// ==========================================
// 2. BUILD SOIL CONTINUUM AND BACKFILL LAYERS
// ==========================================
Rectangle(1) = {-far_x, by, 0, 2*far_x, -by};

layer_top_h = 1.05 / 5;
layer_bot_h = 1.95 / 10;

For i In {1:15}
  If (i <= 5)
    layer_h = layer_top_h;
    y_start = -(i-1) * layer_h;
  Else
    layer_h = layer_bot_h;
    y_start = -1.05 - (i-6) * layer_h;
  EndIf

  Rectangle(100+i) = {tx1, y_start, 0, tw_total, -layer_h};
EndFor

BooleanFragments{ Surface{1, 101:115}; Delete; }{}

// Punch hole for concrete + thin interface layer
Rectangle(900) = {ix1, iy_top, 0, iw, -ih, r_interface};

soil_precut[] = Surface In BoundingBox{-far_x-eps, by-eps, -eps, far_x+eps, eps, eps};
BooleanDifference{ Surface{soil_precut[]}; Delete; }{ Surface{900}; Delete; }

// ==========================================
// 3. BUILD THIN FILLETED INTERFACE LAYER
// ==========================================
Rectangle(920) = {ix1, iy_top, 0, iw, -ih, r_interface};
Rectangle(921) = {cx1, cy_top, 0, w, -h, r_fillet};

BooleanDifference(1200) = { Surface{920}; Delete; }{ Surface{921}; Delete; };

// ==========================================
// 4. BUILD FILLETED HOLLOW UTILIDOR CONCRETE
// ==========================================
Rectangle(2) = {cx1, cy_top, 0, w, -h, r_fillet};

// Inner void is kept rectangular here. If you also want inner fillets,
// add a small radius as the last Rectangle argument.
Rectangle(3) = {cx1+t, cy_top-t, 0, w-2*t, -(h-2*t)};

BooleanDifference(11) = { Surface{2}; Delete; }{ Surface{3}; Delete; };

// Final fragment makes bonded/shared-node interfaces
model_surfs[] = Surface In BoundingBox{-far_x-eps, by-eps, -eps, far_x+eps, eps, eps};
BooleanFragments{ Surface{model_surfs[]}; Delete; }{}

// ==========================================
// 5. PHYSICAL SURFACES
// ==========================================

// Concrete
concrete_surfs[] = Surface In BoundingBox{cx1-eps, cy_bot-eps, -eps, cx2+eps, cy_top+eps, eps};
Physical Surface("concrete", 1) = concrete_surfs[];

// Thin interface layer
interface_surfs[] = Surface In BoundingBox{ix1-eps, iy_bot-eps, -eps, ix2+eps, iy_top+eps, eps};
interface_surfs[] -= concrete_surfs[];
Physical Surface("interface", 2) = interface_surfs[];

// Backfill layers
For i In {1:15}
  If (i <= 5)
    layer_h = layer_top_h;
    y_top = -(i-1) * layer_h;
    y_bot = -i * layer_h;
  Else
    layer_h = layer_bot_h;
    y_top = -1.05 - (i-6) * layer_h;
    y_bot = -1.05 - (i-5) * layer_h;
  EndIf

  layer_surfs[] = Surface In BoundingBox{tx1-eps, y_bot-eps, -eps, tx2+eps, y_top+eps, eps};
  layer_surfs[] -= concrete_surfs[];
  layer_surfs[] -= interface_surfs[];

  Physical Surface(Sprintf("layer_%g", i), 100+i) = layer_surfs[];
EndFor

// Native soil
base_surfs[] = Surface In BoundingBox{-far_x-eps, by-eps, -eps, far_x+eps, eps, eps};
base_surfs[] -= concrete_surfs[];
base_surfs[] -= interface_surfs[];

For i In {1:15}
  If (i <= 5)
    layer_h = layer_top_h;
    y_top = -(i-1) * layer_h;
    y_bot = -i * layer_h;
  Else
    layer_h = layer_bot_h;
    y_top = -1.05 - (i-6) * layer_h;
    y_bot = -1.05 - (i-5) * layer_h;
  EndIf

  base_surfs[] -= Surface In BoundingBox{tx1-eps, y_bot-eps, -eps, tx2+eps, y_top+eps, eps};
EndFor

Physical Surface("native_soil", 6) = base_surfs[];

// ==========================================
// 6. BOUNDARY CURVES
// ==========================================
top_trench[] = Curve In BoundingBox{tx1-eps, -eps, -eps, tx2+eps, eps, eps};
ground_L[]   = Curve In BoundingBox{-far_x-eps, -eps, -eps, tx1+eps, eps, eps};
ground_R[]   = Curve In BoundingBox{tx2-eps, -eps, -eps, far_x+eps, eps, eps};

Physical Curve("top", 10) = {top_trench[], ground_L[], ground_R[]};

Physical Curve("bottom", 11) =
  Curve In BoundingBox{-far_x-eps, by-eps, -eps, far_x+eps, by+eps, eps};

Physical Curve("left", 15) =
  Curve In BoundingBox{-far_x-eps, by-eps, -eps, -far_x+eps, eps, eps};

Physical Curve("right", 16) =
  Curve In BoundingBox{far_x-eps, by-eps, -eps, far_x+eps, eps, eps};

// Interface-soil outer boundary
iface_soil_left[]  = Curve In BoundingBox{ix1-eps, iy_bot-eps, -eps, ix1+eps, iy_top+eps, eps};
iface_soil_right[] = Curve In BoundingBox{ix2-eps, iy_bot-eps, -eps, ix2+eps, iy_top+eps, eps};
iface_soil_top[]   = Curve In BoundingBox{ix1-eps, iy_top-eps, -eps, ix2+eps, iy_top+eps, eps};
iface_soil_bot[]   = Curve In BoundingBox{ix1-eps, iy_bot-eps, -eps, ix2+eps, iy_bot+eps, eps};

feps_interface = r_interface + eps;
iface_soil_fillet_BL[] = Curve In BoundingBox{ix1-eps, iy_top-feps_interface, -eps, ix1+feps_interface, iy_top+eps, eps};
iface_soil_fillet_BR[] = Curve In BoundingBox{ix2-feps_interface, iy_top-feps_interface, -eps, ix2+eps, iy_top+eps, eps};
iface_soil_fillet_TL[] = Curve In BoundingBox{ix1-eps, iy_bot-eps, -eps, ix1+feps_interface, iy_bot+feps_interface, eps};
iface_soil_fillet_TR[] = Curve In BoundingBox{ix2-feps_interface, iy_bot-eps, -eps, ix2+eps, iy_bot+feps_interface, eps};

Physical Curve("interface_soil_boundary", 22) =
  {iface_soil_left[], iface_soil_right[], iface_soil_top[], iface_soil_bot[],
   iface_soil_fillet_BL[], iface_soil_fillet_BR[], iface_soil_fillet_TL[], iface_soil_fillet_TR[]};

// Interface-concrete inner boundary
iface_conc_left[]  = Curve In BoundingBox{cx1-eps, cy_bot-eps, -eps, cx1+eps, cy_top+eps, eps};
iface_conc_right[] = Curve In BoundingBox{cx2-eps, cy_bot-eps, -eps, cx2+eps, cy_top+eps, eps};
iface_conc_top[]   = Curve In BoundingBox{cx1-eps, cy_top-eps, -eps, cx2+eps, cy_top+eps, eps};
iface_conc_bot[]   = Curve In BoundingBox{cx1-eps, cy_bot-eps, -eps, cx2+eps, cy_bot+eps, eps};

feps_conc = r_fillet + eps;
iface_conc_fillet_BL[] = Curve In BoundingBox{cx1-eps, cy_top-feps_conc, -eps, cx1+feps_conc, cy_top+eps, eps};
iface_conc_fillet_BR[] = Curve In BoundingBox{cx2-feps_conc, cy_top-feps_conc, -eps, cx2+eps, cy_top+eps, eps};
iface_conc_fillet_TL[] = Curve In BoundingBox{cx1-eps, cy_bot-eps, -eps, cx1+feps_conc, cy_bot+feps_conc, eps};
iface_conc_fillet_TR[] = Curve In BoundingBox{cx2-feps_conc, cy_bot-eps, -eps, cx2+eps, cy_bot+feps_conc, eps};

Physical Curve("interface_concrete_boundary", 23) =
  {iface_conc_left[], iface_conc_right[], iface_conc_top[], iface_conc_bot[],
   iface_conc_fillet_BL[], iface_conc_fillet_BR[], iface_conc_fillet_TL[], iface_conc_fillet_TR[]};

// ==========================================
// 7. MESH CONTROLS
// ==========================================
Mesh.MshFileVersion = 2.2;
Mesh.ElementOrder = 1;
Mesh.HighOrderOptimize = 2;

coarse_size = 2.0;
interface_size = ci / 2;
fillet_size = r_fillet / 3;

// Dense field only over the layered trench ground + utilidor depth.
// This follows the original fillet-contact script.
Field[1] = Box;
Field[1].VIn = interface_size;
Field[1].VOut = coarse_size;
Field[1].XMin = tx1;
Field[1].XMax = tx2;
Field[1].YMin = iy_bot;
Field[1].YMax = 0.0;
Field[1].Thickness = 3.0;

// Extra refinement around filleted concrete/interface curves
all_fillet_arcs[] = {
  iface_soil_fillet_BL[], iface_soil_fillet_BR[], iface_soil_fillet_TL[], iface_soil_fillet_TR[],
  iface_conc_fillet_BL[], iface_conc_fillet_BR[], iface_conc_fillet_TL[], iface_conc_fillet_TR[]
};

Field[2] = Distance;
Field[2].CurvesList = {all_fillet_arcs[]};
Field[2].Sampling = 100;

Field[3] = Threshold;
Field[3].InField = 2;
Field[3].SizeMin = fillet_size;
Field[3].SizeMax = coarse_size;
Field[3].DistMin = r_fillet / 2;
Field[3].DistMax = r_fillet * 3;

Field[4] = Min;
Field[4].FieldsList = {1, 3};

Background Field = 4;

Mesh.Optimize = 1;
// Do not execute Coherence;