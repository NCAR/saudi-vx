########################################################################
##
##   Name: merge_nc_mask.R
##
##   Description:
##
##   Usage:
##      Rscript merge_nc_mask.R nc_file_list
##
##   Arguments:
##
##   Details:
##
##   Examples:
##      Rscript merge_nc_mask.R out/d02_*.nc -out d02_saudi_provinces.nc
##   Author:
##      John Halley Gotway (johnhg@ucar.edu), NCAR-RAL/JNT
##      11/08/2012 
##
########################################################################

########################################################################
#
# Constants.
#
########################################################################

########################################################################
#
# Handle the arguments.
#
########################################################################

# Retreive the arguments
args = commandArgs(TRUE)

# Check the number of arguments
if(length(args) < 1) {
   cat("Usage: merge_nc_mask.R\n")
   cat("         nc_file_list\n")
   cat("         [-out name]\n")
   cat("         [-name string]\n")
   cat("         [-ivar i]\n")
   cat("         [-save]\n")
   cat("         where \"nc_file_list\" is one or more NetCDF mask files.\n")
   cat("               \"-out name\"    specifies an output NetCDF file name.\n")
   cat("               \"-name string\" specifies the NetCDF variable mask name.\n")
   cat("               \"-ivar i\"      specifies the i-th variable should be used.\n")
   cat("               \"-save\"        calls save.image() before exiting R.\n\n")
   quit()
}

# Load libraries
#library(fields)
library(RNetCDF)

# Initialize
save = FALSE
file_list = c()
ivar = 2
out_file = "merge_nc_mask_out.nc"
var_name = "mask"

# Parse the arguments
i=1
while(i <= length(args)) {

  # Check optional arguments
  if(args[i] == "-save") {

    save = TRUE

  } else if(args[i] == "-out") {

    # Set the output file name
    out_file = args[i+1]
    i = i+1

  } else if(args[i] == "-name") {

    # Set the masking variable name
    var_name = args[i+1]
    i = i+1

  } else if(args[i] == "-ivar") {

    ivar = args[i+1] 
    i = i+1

  } else {

    # Add input file to the file list
    file_list = c(file_list, args[i])
  }

  # Increment i
  i = i+1
}

########################################################################
#
# Read the input files and merge the values.
#
########################################################################

# Remove the mask file if it already exists
SYS_CMD <- paste("rm -f ", out_file, sep="")
system(SYS_CMD)

# Make a copy of the first NetCDF file in the list
SYS_CMD <- paste("cp", file_list[1], out_file)
system(SYS_CMD)

cat(paste("Creating", out_file, "\n"))
cat(paste("Reading", length(file_list), "poly mask files...\n"))

# Open the output NetCDF file for writing
nc_out <- open.nc(out_file, write=TRUE)

# Rename the variable
var.rename.nc(nc_out, ivar, var_name)

# Reset the long_name
att.put.nc(nc_out, ivar, "long_name", "NC_CHAR", "Polyline masking regions")

# Reset all of the values to 0
nc_var   <- var.get.nc(nc_out, ivar)
nc_var[] <- 0

# Read each of the input NetCDF files and merge the values
for(i in 1:length(file_list)) {

   cat(paste("Reading[", i , "]: ", as.character(file_list[i]), "\n", sep=""))

   # Open the NetCDF file
   nc_tmp <- open.nc(as.character(file_list[i]))

   # Retrieve the name of the masking region
   mask_name <- var.inq.nc(nc_tmp, ivar)$name

   # Add an attribute for each masking region 
   att.put.nc(nc_out, ivar, paste(mask_name, "value", sep="_"), "NC_INT", as.numeric(i))

   # Get the variable and merge the values
   nc_val <- var.get.nc(nc_tmp, ivar)
   ind    <- nc_val > 0

   # Check for any non-zero values being over-written
   if(sum(nc_var[ind] > 0)) {
      cat(paste("Warning:", sum(nc_var[ind] > 0), "points appear in multiple masks.\n"))
   }

   # Write the values for the current mask
   nc_var[ind] <- i 

   # Close the NetCDF file
   close.nc(nc_tmp)
}

# Write out the masking variable
var.put.nc(nc_out, ivar, nc_var)

# Close the output NetCDF file
close.nc(nc_out)

# Optionally, save all of the data to an .RData file
if(save) {
   save.image()
} 
