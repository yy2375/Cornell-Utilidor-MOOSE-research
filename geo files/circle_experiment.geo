// Gmsh project created on Wed May 20 19:14:10 2026
SetFactory("OpenCASCADE");
//+
Point(1) = {-10, 0, 0, 1};
//+
Point(2) = {10, 0, 0, 1};
//+
Point(3) = {10, -10, 0, 1};
//+
Point(4) = {-10, -10, 0, 1};
//+
Point(5) = {0, -3.2, 0, 0.05};
//+
Point(6) = {0, -4.8, 0, 0.05};
//+
Point(7) = {0.8, -4, 0, 0.05};
//+
Point(8) = {0, -4, 0, 0.05};
//+
Point(9) = {-0.8, -4, 0, 0.05};
//+
Circle(1) = {9, 8, 7};
//+
Circle(2) = {7, 8, 9};
//+
Line(3) = {1, 2};
//+
Line(4) = {3, 2};
//+
Line(5) = {3, 4};
//+
Line(6) = {4, 1};
//+
Curve Loop(1) = {3, -4, 5, 6};
//+
Curve Loop(2) = {1, 2};
//+
Plane Surface(1) = {1, 2};
//+
Physical Curve("top", 7) = {3};
//+
Physical Curve("left", 8) = {6};
//+
Physical Curve("right", 9) = {4};
//+
Physical Curve("bottom", 10) = {5};
//+
Physical Curve("wall", 11) = {1, 2};
//+
Physical Surface("ground", 12) = {1};
