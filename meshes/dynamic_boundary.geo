
    depth = 5.0; height = 2.0; thickness = 0.2; width = 2.0;
    Point(1) = {-35.0, 0, 0, 1.0}; Point(2) = {35.0, 0, 0, 1.0};
    Point(3) = {35.0, -41.0, 0, 1.0}; Point(4) = {-35.0, -41.0, 0, 1.0};
    Point(5) = {-width/2, -depth, 0, 0.05}; Point(6) = {width/2, -depth, 0, 0.05};
    Point(7) = {width/2, -depth-height, 0, 0.05}; Point(8) = {-width/2, -depth-height, 0, 0.05};
    Point(9) = {-width/2+thickness, -depth-thickness, 0, 0.05};
    Point(10) = {width/2-thickness, -depth-thickness, 0, 0.05};
    Point(11) = {width/2-thickness, -depth-height+thickness, 0, 0.05};
    Point(12) = {-width/2+thickness, -depth-height+thickness, 0, 0.05};

    Line(1)={1,4}; Line(2)={4,3}; Line(3)={3,2}; Line(4)={2,1};
    Line(5)={6,7}; Line(6)={7,8}; Line(7)={8,5}; Line(8)={5,6};
    Line(9)={10,11}; Line(10)={11,12}; Line(11)={12,9}; Line(12)={9,10};

    Curve Loop(1)={4,1,2,3}; Curve Loop(2)={8,5,6,7}; Curve Loop(3)={12,9,10,11};
    Plane Surface(1)={1,2}; Plane Surface(2)={2,3};
    Physical Surface("ground")={1}; Physical Surface("concrete")={2};
    Physical Curve("left")={1}; Physical Curve("bottom")={2}; 
    Physical Curve("right")={3}; Physical Curve("top")={4}; 
    Physical Curve("wall")={9,10,11,12};

    Coherence;
    Physical Surface("ground", 1) += {1}; Physical Surface("concrete", 2) += {2};
    