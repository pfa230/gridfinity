

// ===== INFORMATION ===== //
/*
 IMPORTANT: rendering will be better for analyzing the model if fast-csg is enabled. As of writing, this feature is only available in the development builds and not the official release of OpenSCAD, but it makes rendering only take a couple seconds, even for comically large bins. Enable it in Edit > Preferences > Features > fast-csg

https://github.com/kennetek/gridfinity-rebuilt-openscad

*/

// ===== PARAMETERS ===== //

/* [Setup Parameters] */
$fa = 8;
$fs = 0.25;

/* [General Settings] */
// What to generate
what = 0; // [0: baseplate, 1: support spacer]

// number of units along x-axis
gridx = 1;
// number of units along y-axis
gridy = 1;

/* [Fit to Drawer] */
// minimum length of baseplate along x (leave zero to ignore, will automatically fill area if gridx is zero)
distancex = 0;
// minimum length of baseplate along y (leave zero to ignore, will automatically fill area if gridy is zero)
distancey = 0;

// where to align extra space along x
fitx = 0; // [-1:0.1:1]
// where to align extra space along y
fity = 0; // [-1:0.1:1]

module __Customizer_Limit__ () {}  // Hide following assignments from Customizer.

// Length of a grid unit
GRID_UNIT_SIZE = 42;

// Tolerance to make sure cuts don't leave a sliver behind,
// and that items are properly connected to each other.
TOLERANCE = 0.01;


BASEPLATE_OUTSIDE_RADIUS = 8 / 2;
// Overall height of the baseplate.
BASEPLATE_HEIGHT = 5;
// Width of the top and bottom surfaces that stack on each other.
// This is for single, e.g. outside wall. On inside walls it will be double that.
MATING_WIDTH = 0.5;
// Thickness of a single, e.g. outside wall. Inside walls will be double that.
BASEPLATE_WALL_THICKNESS = 2.15;
// Thickness of a spacer between stacked plates, usually one print layer.
SPACER_HEIGHT = 0.2;

SLOPE_SPAN = BASEPLATE_WALL_THICKNESS - MATING_WIDTH;
// Polygon describing the raw baseplate lip.
BASEPLATE_LIP = [
    [SLOPE_SPAN, 0], 
    [0, SLOPE_SPAN], 
    [0, BASEPLATE_HEIGHT - SLOPE_SPAN], 
    [SLOPE_SPAN, BASEPLATE_HEIGHT], 
    [BASEPLATE_WALL_THICKNESS, BASEPLATE_HEIGHT], 
    [BASEPLATE_WALL_THICKNESS, 0], 
    [SLOPE_SPAN, 0] 
];

SPACER_LIP = [
    [0, 0], 
    [MATING_WIDTH, 0], 
    [MATING_WIDTH, SPACER_HEIGHT], 
    [0, SPACER_HEIGHT], 
    [0, 0]
];

color("tomato")
if (what == 0) {
    generate(BASEPLATE_LIP, BASEPLATE_WALL_THICKNESS, BASEPLATE_HEIGHT, [gridx, gridy], [distancex, distancey], [fitx, fity]);
} else if (what == 1) {
    generate(SPACER_LIP, MATING_WIDTH, SPACER_HEIGHT, [gridx, gridy], [distancex, distancey], [fitx, fity]);
}

// ===== CONSTRUCTION ===== //

/**
 * @brief Create a baseplate.
 * @param lip_polygon polygon representing a lip section profile
 * @param wall_thickness - max thickness of the wall in mm
 * @param height height of the profile to generate
 * @param grid_size_units Number of Gridfinity units along both axes.
 *        2d Vector. [x, y].
 *        Set to [0, 0] to auto calculate using min_size_mm.
 * @param min_size_mm Minimum size of the baseplate. [x, y]
 *                    Extra space is filled with solid material.
 *                    Enables "Fit to Drawer."
 * @param fit_offset Determines where padding is added.
 */
module generate(lip_polygon, wall_thickness, height, grid_size_units, min_size_mm, fit_offset = [0, 0]) {

    assert(is_list(grid_size_units) && len(grid_size_units) == 2,
        "grid_size_bases must be a 2d list");
    assert(is_list(min_size_mm) && len(min_size_mm) == 2,
        "min_size_mm must be a 2d list");
    assert(is_list(fit_offset) && len(fit_offset) == 2,
        "fit_offset must be a 2d list");
    assert(grid_size_units.x > 0 || min_size_mm.x > 0,
        "Must have positive x grid amount!");
    assert(grid_size_units.y > 0 || min_size_mm.y > 0,
        "Must have positive y grid amount!");

    // Final size in number of units
    actual_grid_size_units = [for (i = [0:1])
        grid_size_units[i] == 0 ? floor(min_size_mm[i] / GRID_UNIT_SIZE) : grid_size_units[i]];

    // Final size of the base before padding. In mm.
    grid_size_mm = concat(actual_grid_size_units * GRID_UNIT_SIZE, [BASEPLATE_HEIGHT]);

    // Final size, including padding. In mm.
    final_size_mm = [
        max(grid_size_mm.x, min_size_mm.x),
        max(grid_size_mm.y, min_size_mm.y),
        height
    ];

    // Amount of padding needed to fit to a specific drawer size. In mm.
    padding_mm = final_size_mm - grid_size_mm;

    is_padding_needed = padding_mm != [0, 0, 0];

    //Convert the fit offset to percent of how much will be added to the positive axes.
    // -1 : 1 -> 0 : 1
    fit_percent_positive = [for (i = [0:1]) (fit_offset[i] + 1) / 2];

    padding_start_point = -grid_size_mm/2 -
        [
            padding_mm.x * (1 - fit_percent_positive.x),
            padding_mm.y * (1 - fit_percent_positive.y),
            -grid_size_mm.z/2
        ];

    corner_points = [
        padding_start_point + [final_size_mm.x, final_size_mm.y, 0],
        padding_start_point + [0, final_size_mm.y, 0],
        padding_start_point,
        padding_start_point + [final_size_mm.x, 0, 0],
    ];

    echo(str("Number of Grids per axes (X, Y)]: ", actual_grid_size_units));
    echo(str("Final size (in mm): ", final_size_mm));
    if (is_padding_needed) {
        echo(str("Padding +X (in mm): ", padding_mm.x * fit_percent_positive.x));
        echo(str("Padding -X (in mm): ", padding_mm.x * (1 - fit_percent_positive.x)));
        echo(str("Padding +Y (in mm): ", padding_mm.y * fit_percent_positive.y));
        echo(str("Padding -Y (in mm): ", padding_mm.y * (1 - fit_percent_positive.y)));
    }

    difference() {
        union() {
            // Baseplate itself
            pattern_linear(actual_grid_size_units.x, actual_grid_size_units.y, GRID_UNIT_SIZE) {
                // Single Baseplate piece
                difference() {
                    square_lip(lip_polygon, height, wall_thickness);
                }
            }

            // Padding
            if (is_padding_needed) {
                render()
                difference() {
                    translate(padding_start_point)
                    cube(final_size_mm);

                    translate([
                        -grid_size_mm.x/2,
                        -grid_size_mm.y/2,
                        0
                    ])
                    cube(grid_size_mm);
                }
            }
        }

        // Round the outside corners (Including Padding)
        for(i = [0:len(corner_points) - 1]) {
                point = corner_points[i];
                translate([
                point.x + (BASEPLATE_OUTSIDE_RADIUS * -sign(point.x)),
                point.y + (BASEPLATE_OUTSIDE_RADIUS * -sign(point.y)),
                0
            ])
            rotate([0, 0, i*90])
            square_corner(height, true);
        }
    }
}

/**
 * @brief Added or removed from the baseplate to square off or round the corners.
 * @param height Height of the plate being generated
 * @param subtract If the corner should be scaled to allow subtraction.
 */
module square_corner(height, subtract=false) {
    assert(is_bool(subtract));

    subtract_amount = subtract ? TOLERANCE : 0;

    translate([0, 0, -subtract_amount])
    linear_extrude(height + (2 * subtract_amount))
    difference() {
        square(BASEPLATE_OUTSIDE_RADIUS + subtract_amount , center=false);
        // TOLERANCE needed to prevent a gap
        circle(r=BASEPLATE_OUTSIDE_RADIUS - TOLERANCE);
    }
}

/**
 * @brief Outer edge/lip of the baseplate.
 * @details Includes clearance to ensure the base touches the lip
 *          instead of the bottom.
 * @param lip_polygon polygon representing a lip section profile
 * @param wall_thickness - max thickness of the wall in mm
 */
module lip(lip_polygon, wall_thickness) {
    // How far, in the +x direction,
    // the lip needs to be from it's [0, 0] point
    // such that when swept by 90 degrees to produce a corner,
    // the outside edge has the desired radius.
    translation_x = BASEPLATE_OUTSIDE_RADIUS - wall_thickness;

    sweep_rounded(GRID_UNIT_SIZE - 2 * BASEPLATE_OUTSIDE_RADIUS, GRID_UNIT_SIZE - 2 * BASEPLATE_OUTSIDE_RADIUS)
    translate([translation_x, 0, 0])
    polygon(concat(lip_polygon, [
        [0, 0],
        [wall_thickness, 0],
        [wall_thickness, 0]
    ]));
}

module pattern_linear(x = 1, y = 1, sx = 0, sy = 0) {
    yy = sy <= 0 ? sx : sy;
    translate([-(x-1)*sx/2,-(y-1)*yy/2,0])
    for (i = [1:ceil(x)])
    for (j = [1:ceil(y)])
    translate([(i-1)*sx,(j-1)*yy,0])
    children();
}

/**
 * @brief Outer edge/lip of the baseplate, with square corners.
 * @param lip_polygon polygon representing a lip section profile
 * @param height - height of the profile to generate
 * @param wall_thickness - max thickness of the wall in mm
 * @details Needed to prevent gaps when joining multiples together.
 */
module square_lip(lip_polygon, height, wall_thickness) {
    corner_center_distance = GRID_UNIT_SIZE/2 - BASEPLATE_OUTSIDE_RADIUS;

    render(convexity = 2) // Fixes ghosting in preview
    union() {
        lip(lip_polygon, wall_thickness);
        pattern_circular(4)
        translate([corner_center_distance, corner_center_distance, 0])
        square_corner(height);
    }
}

function affine_translate(vector) = [
    [1, 0, 0, vector.x],
    [0, 1, 0, vector.y],
    [0, 0, 1, vector.z],
    [0, 0, 0, 1]
];


/**
 * @brief Create a rectangle with rounded corners by sweeping a 2d object along a path.
 *        Centered on origin.
 */
module sweep_rounded(width, length) {
    assert(width > 0 && length > 0);

    half_width = width/2;
    half_length = length/2;
    path_points = [
        [-half_width, half_length],  //Start
        [half_width, half_length], // Over
        [half_width, -half_length], //Down
        [-half_width, -half_length], // Back over
        [-half_width, half_length]  // Up to start
    ];
    path_vectors = [
        path_points[1] - path_points[0],
        path_points[2] - path_points[1],
        path_points[3] - path_points[2],
        path_points[4] - path_points[3],
    ];
    // These contain the translations, but not the rotations
    // OpenSCAD requires this hacky for loop to get accumulate to work!
    first_translation = affine_translate([path_points[0].y, 0,path_points[0].x]);
    affine_translations = concat([first_translation], [
        for (i = 0, a = first_translation;
            i < len(path_vectors);
            a=a * affine_translate([path_vectors[i].y, 0, path_vectors[i].x]), i=i+1)
        a * affine_translate([path_vectors[i].y, 0, path_vectors[i].x])
    ]);

    // Bring extrusion to the xy plane
    affine_matrix = affine_rotate([90, 0, 90]);

    walls = [
        for (i = [0 : len(path_vectors) - 1])
        affine_matrix * affine_translations[i]
        * affine_rotate([0, atanv(path_vectors[i]), 0])
    ];

    union()
    {
        for (i = [0 : len(walls) - 1]){
            multmatrix(walls[i])
            linear_extrude(vector_magnitude(path_vectors[i]))
            children();

            // Rounded Corners
            multmatrix(walls[i] * affine_rotate([-90, 0, 0]))
            rotate_extrude(angle = 90, convexity = 4)
            children();
        }
    }
}


function _affine_rotate_x(angle_x) = [
    [1,  0, 0, 0],
    [0, cos(angle_x), -sin(angle_x), 0],
    [0, sin(angle_x), cos(angle_x), 0],
    [0, 0, 0, 1]
];

function _affine_rotate_y(angle_y) = [
    [cos(angle_y),  0, sin(angle_y), 0],
    [0, 1, 0, 0],
    [-sin(angle_y), 0, cos(angle_y), 0],
    [0, 0, 0, 1]
];

function _affine_rotate_z(angle_z) = [
    [cos(angle_z), -sin(angle_z), 0, 0],
    [sin(angle_z), cos(angle_z), 0, 0],
    [0, 0, 1, 0],
    [0, 0, 0, 1]
];


/**
 * @brief Affine transformation matrix equivalent of `rotate`
 * @param angle_vector @see `rotate`
 * @details Equivalent to `rotate([0, angle, 0])`
 * @returns An affine transformation matrix for use with `multmatrix()`
 */
function affine_rotate(angle_vector) =
    _affine_rotate_z(angle_vector.z) * _affine_rotate_y(angle_vector.y) * _affine_rotate_x(angle_vector.x);

function atanv(vector) = atan2(vector.y, vector.x);

/**
 * @brief Get the magnitude of a 2d or 3d vector
 * @param vector A 2d or 3d vectorm
 * @returns Magnitude of the vector.
 */
function vector_magnitude(vector) =
    sqrt(vector.x^2 + vector.y^2 + (len(vector) == 3 ? vector.z^2 : 0));

module pattern_circular(n=2) {
    for (i = [1:n])
    rotate(i*360/n)
    children();
}
