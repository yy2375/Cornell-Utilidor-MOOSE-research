// Gmsh project created on Wed May 20 18:18:54 2026
SetFactory("OpenCASCADE");
//+
Point(1) = {-10, 0, 0, 1.0};
//+
Point(3) = {-10, 0, 0, 1.0};
//+
Point(4) = {10, 0, 0, 1.0};
//+
Point(5) = {10, -10, 0, 1.0};
//+
Point(6) = {-10, -10, 0, 1.0};
//+
Point(7) = {0, -3, 0, 0.05};
//+
Point(8) = {0, -5, 0, 0.05};
//+
Point(9) = {-1, -4, 0, 0.05};
//+
Point(10) = {1, -4, 0, 0.05};
//+
Point(11) = {0.8, -4, 0, 0.05};
//+
Point(12) = {-0.8, -4, 0, 0.05};
//+
Point(13) = {0, -3.2, 0, 0.05};
//+
Point(14) = {0, -4.8, 0, 0.05};
//+
Line(1) = {1, 4};
//+
Line(2) = {4, 5};
//+
Line(3) = {5, 6};
//+
Line(4) = {6, 1};
//+
Circle(5) = {7, 8, 10};
//+
Circle(5) = {8, 7, 10};
//+
Point(15) = {-0, -4, 0, 0.05};
//+
Circle(5) = {12, 15, 11};
//+
Circle(6) = {11, 15, 12};
//+
Circle(7) = {9, 15, 10};
//+
Circle(8) = {10, 15, 9};
//+
Curve Loop(1) = {1, 2, 3, 4};
//+
Curve Loop(2) = {7, 8};
//+
Plane Surface(1) = {1, 2};
//+
Curve Loop(3) = {7, 8};
//+
Curve Loop(4) = {5, 6};
//+
Plane Surface(2) = {3, 4};
//+
Curve Loop(5) = {7, 8};
//+
Curve Loop(6) = {5, 6};
//+
Plane Surface(3) = {5, 6};
//+
Curve Loop(7) = {5, 6};
//+
Curve Loop(8) = {7, 8};
//+
Curve Loop(9) = {7, 8};
//+
Curve Loop(10) = {5, 6};
//+
Plane Surface(4) = {9, 10};
//+
Physical Curve("top", 11) = {1};
//+
Physical Curve("left", 12) = {4};
//+
Physical Curve("bottom", 13) = {3};
//+
Physical Curve("right", 14) = {2};
//+
Physical Curve("wall", 15) = {5, 6};
//+
Physical Surface("ground", 16) = {1};
//+
Physical Surface("concrete", 17) = {2};
