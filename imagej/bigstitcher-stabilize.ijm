/*************************************************************
 * USER DEFINES
 ************************************************************/
input_dir = getDirectory("Choose TimeLapse Directory");

Dialog.create("BigStitcher Setup");
Dialog.addString("Image Directory:", input_dir, 64);
Dialog.addString("Output Directory Name:", "bigstitcher", 32);
Dialog.addString("ROI Name:", "roi_1");
Dialog.addNumber("Voxel Size xy:", 0.104);
Dialog.addNumber("Voxel Size z:", 0.26348);
Dialog.show();

input_dir = Dialog.getString();
output_dir_name = Dialog.getString();
roi_dir_name = Dialog.getString();
voxel_size_xy = Dialog.getNumber();
voxel_size_z = Dialog.getNumber();

root_dir = File.getParent(input_dir) + File.separator;
proj_str = File.getName(root_dir);
date_dir = File.getName(File.getParent(root_dir));
project_name = date_dir + "_" + proj_str;

output_dir = root_dir + output_dir_name + File.separator;
roi_output_dir = output_dir + roi_dir_name + File.separator;
output_data_name = output_dir + project_name;

print("Input dir: " + input_dir + "\nOutput dir: " + output_dir + "\nROI dir: " + roi_output_dir + "\nProject Name: " + project_name + "\nOutput Data Name: " + output_data_name + "\nVoxel Size: (" + voxel_size_xy + "x, " + voxel_size_xy + "y, " + voxel_size_z + "z)\n\n");
/************************************************************
************************************************************/

// make output directory if it doesn't already exist
if (!File.isDirectory(output_dir))
{
	File.makeDirectory(output_dir);
}
if (!File.isDirectory(roi_output_dir))
{
	File.makeDirectory(roi_output_dir);
}

// Convert data from tiff files to HDF5 for interactive viewing in BigDataViewer
run("Define dataset ...",
	"define_dataset=[Automatic Loader (Bioformats based)] " +
	"project_filename=" + project_name + ".xml " + 
	"path=" + input_dir + " " +
	"exclude=10 " +
	"pattern_0=Channels " +
	"pattern_1=TimePoints " + 
	"modify_voxel_size? " +
	"voxel_size_x=" + voxel_size_xy + 
	" voxel_size_y=" + voxel_size_xy + 
	" voxel_size_z=" + voxel_size_z + 
	" voxel_size_unit=um " + 
	"move_tiles_to_grid_(per_angle)?=[Do not move Tiles to Grid (use Metadata if available)] " + 
	"how_to_load_images=[Re-save as multiresolution HDF5] " + 
	"dataset_save_path=" + output_dir + " " +
	"subsampling_factors=[{ {1,1,1}, {2,2,1}, {4,4,2} }] " +
	"hdf5_chunk_sizes=[{ {32,16,8}, {16,16,16}, {16,16,16} }] " +
	"timepoints_per_partition=1 " +
	"setups_per_partition=0 " + 
	"use_deflate_compression " +
	"export_path=" + output_data_name
);

// Calculate the intrest points
run("Detect Interest Points for Registration",
	"browse=" + output_dir + " " +
	"select=" + output_data_name + ".xml " +
	"process_angle=[All angles] " +
	"process_channel=[Single channel (Select from List)] " +
	"process_illumination=[All illuminations] " +
	"process_tile=[All tiles] " +
	"process_timepoint=[All Timepoints] " +
	"processing_channel=[channel 1] " +
	"type_of_interest_point_detection=Difference-of-Gaussian " +
	"label_interest_points=edges " +
	"subpixel_localization=[3-dimensional quadratic fit] " +
	"interest_point_specification=[Advanced ...] " +
	"downsample_xy=[Match Z Resolution (less downsampling)] downsample_z=1x " +
	"sigma=6.5 " +
	"threshold=0.019 " +
	"find_maxima " +
	"compute_on=[CPU (Java)]"
);

// Register between intrest points
run("Register Dataset based on Interest Points",
	"select=" + output_data_name + ".xml " +
	"process_angle=[All angles] " +
	"process_channel=[Single channel (Select from List)] " +
	"process_illumination=[All illuminations] " +
	"process_tile=[All tiles] " +
	"process_timepoint=[All Timepoints] " +
	"processing_channel=[channel 1] " +
	"registration_algorithm=[Precise descriptor-based (translation invariant)] " +
	"registration_over_time=[All-to-all timepoints matching (global optimization)] " +
	"registration_in_between_views=[Only compare overlapping views (according to current transformations)] " +
	"interest_points=edges " +
	"consider_each_timepoint_as_rigid_unit " +
	"fix_views=[Fix first view] " +
	"map_back_views=[Do not map back (use this if views are fixed)] " +
	"transformation=Translation " +
	"number_of_neighbors=3 " +
	"redundancy=1 " +
	"significance=3 " +
	"allowed_error_for_ransac=7 " +
	"ransac_iterations=Normal " +
	"show_timeseries_statistics " +
	"interestpoint_grouping=[Group interest points (simply combine all in one virtual view)] " +
	"interest=5"
);

// Duplicate Transformations
run("Duplicate Transformations",
	"apply=[One channel to other channels] " +
	"select=" + output_data_name + ".xml " + 
	"apply_to_angle=[All angles] " +
	"apply_to_illumination=[All illuminations] " +
	"apply_to_tile=[All tiles] " +
	"apply_to_timepoint=[All Timepoints] " +
	"source=1 target=[All Channels] " +
	"duplicate_which_transformations=[Replace all transformations]"
);

// create a bounding box
run("Define Bounding Box",
	"select=" + output_data_name + ".xml " +
	"process_angle=[All angles] " +
	"process_channel=[All channels] " +
	"process_illumination=[All illuminations] " +
	"process_tile=[All tiles] " +
	"process_timepoint=[All Timepoints] " +
	"bounding_box=[Define using the BigDataViewer interactively] "+
	"bounding_box_name=" + roi_dir_name
);

// export the ROI defined by the bounding box
run("Fuse",
	"select=" + output_data_name + ".xml " +
	"process_angle=[All angles] " +
	"process_channel=[All channels] " +
	"process_illumination=[All illuminations] " +
	"process_tile=[All tiles] " +
	"process_timepoint=[All Timepoints] " +
	"bounding_box=" + roi_dir_name + " " +
	"downsampling=1 " +
	"pixel_type=[16-bit unsigned integer] " +
	"interpolation=[Linear Interpolation] " +
	"image=[Precompute Image] " +
	"interest_points_for_non_rigid=[-= Disable Non-Rigid =-] " +
	"blend preserve_original " +
	"produce=[Each timepoint & channel] " +
	"fused_image=[Save as (compressed) TIFF stacks] " +
	"output_file_directory=" + roi_output_dir + " " +
	"filename_addition=[]"
);
