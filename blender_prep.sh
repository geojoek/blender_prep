#!/bin/bash

###Prepare DEM(s) for Blender###
##Requirements##
# GDAL/OGR, preferably 3.x based off of Python 3. Recommend running in a separate conda environment. See https://www.gdal.org for how to install on your machine.
# modified from https://github.com/nunderwood6/blender_prep

# clips raster, downsamples to target resolution, and then converts to stretched 16 bit raster for use in blender
# shapefile aspect ratio in units must match ratio of target resolution
# make sure you've prepared your data as described at https://somethingaboutmaps.wordpress.com/blender-relief-tutorial-getting-set-up/

#----------------------------------------------------------

# defining variables and your parameters

target_srs="EPSG:6346" # The project coordinate system you want your map to be in
clipping_mask="" # The shapefile containing the area you want to clip your source DEM by
input_DEM="" # your source DEM
output_DEM="" # the name of the output DEM this script will produce
target_x_width="" # target x width, in pixels, of the file to go into Blender

# target_Y_resolution="10800" # unused in this in script but useful for reference

# Get extents of clipping-mask and calculate resulting pixel size to plug into gdalwarp for resampling
clippingmask_nametrim=$(find $clipping_mask | cut -d "." -f 1)
clip_xmin=`ogrinfo -ro "$clipping_mask" "$clippingmask_nametrim" | sed -ne 's/.*Extent: (//p' | tr -d ' ' | cut -d "," -f 1` # using deprecated single quote for variable definition here because of parantheses in commands
clip_xmax=`ogrinfo -ro "$clipping_mask" "$clippingmask_nametrim" | sed -ne 's/.*Extent: (.*(//p' | tr -d ' ' | cut -d "," -f 1`
x_extent=$(echo "$clip_xmax" "-" "$clip_xmin" | bc -l) # pipes to bc to do floating point calculations
map_units_perpixel=$(echo "$x_extent" "/" "$target_x_width" | bc -l) # gives target resolution to plug into gdal_warp

# clips and downsamples your DEM to target resolution
gdalwarp "$input_DEM" "$output_DEM" \
-cutline "$clipping_mask" \
-cl "$clippingmask_nametrim" \
-crop_to_cutline \
-t_srs "$target_srs" \
-tr "$map_units_perpixel" "$map_units_perpixel" \
-r bilinear \
-multi \
-co BLOCKXSIZE=2048 \
-co BLOCKYSIZE=2048 \
-co TILED=YES \
-co INTERLEAVE=PIXEL \
-co COMPRESS=LZW \
-co BIGTIFF=YES \
-wo NUM_THREADS=ALL_CPUS \
-co NUM_THREADS=ALL_CPUS \

# creates external pyramids of your clipped raster for faster loading in QGIS
gdaladdo -ro \
--config INTERLEAVE_OVERVIEW PIXEL \
--config COMPRESS_OVERVIEW LZW \
--config BIGTIFF_OVERVIEW YES \
--config NUM_THREADS ALL_CPUS \
--config GDAL_TIFF_OVR_BLOCKSIZE 2048 \
-r average "$output_DEM"

# get min/max values from raster
min=$(gdalinfo -mm "$output_DEM" | sed -ne 's/.*Computed Min\/Max=//p'| tr -d ' ' | cut -d "," -f 1 | cut -d . -f 1)
max=$(gdalinfo -mm "$output_DEM" | sed -ne 's/.*Computed Min\/Max=//p'| tr -d ' ' | cut -d "," -f 2 | cut -d . -f 1)

# stretching the raster to 16 bit so Blender can read it
gdal_translate -scale "$min" "$max" 0 65535 \
-of Gtiff \
-ot UInt16 \
-a_nodata -9999 \
-co TILED=YES \
-co INTERLEAVE=PIXEL \
-co COMPRESS=LZW \
-co BIGTIFF=YES \
-co NUM_THREADS=ALL_CPUS \
-co TFW=YES \
-co BLOCKXSIZE=2048 \
-co BLOCKYSIZE=2048 \
"$output_DEM" blender_ready_"$output_DEM"