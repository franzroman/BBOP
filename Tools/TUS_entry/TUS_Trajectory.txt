TUS_trajectory = function(target, transducer) {

	######################
	### Load functions ###
	######################

	require(oro.nifti)

	nii_to_df = function(arr) {
		values = as.vector(arr)
		indices = expand.grid(x=1:dim(arr)[1], y=1:dim(arr)[2], z=1:dim(arr)[3])
		df = data.frame(indices, val=values)
		return(df)
	}

	normalize <- function(v) v / sqrt(sum(v^2))
		cross <- function(a, b) {
 			c(
    			a[2]*b[3] - a[3]*b[2],
    			a[3]*b[1] - a[1]*b[3],
    			a[1]*b[2] - a[2]*b[1]
  			)
		}


	###############################
	###           RUN           ###
	###############################

	target_df = nii_to_df(target@.Data)
	target_df = subset(target_df, val != 0)
	target_df = colMeans(target_df)
	target_df = translateCoordinate(c(target_df[1], target_df[2], target_df[3]),target)
	target_df = c(x = target_df[1], y = target_df[2], z = target_df[3])

	transducer_df = nii_to_df(transducer@.Data)
	transducer_df = subset(transducer_df, val != 0)
	transducer_df = colMeans(transducer_df)
	transducer_df = translateCoordinate(c(transducer_df[1], transducer_df[2], transducer_df[3]),transducer)
	transducer_df = c(x = transducer_df[1], y = transducer_df[2], z = transducer_df[3])

	toolZ <- transducer_df - target_df
	toolZ <- normalize(toolZ)

	world_up <- c(0, 0, 1)
	if (abs(sum(toolZ * world_up)) > 0.99) {
  		world_up <- c(0, 1, 0)
	}

	toolX <- cross(world_up, toolZ)
	toolX <- normalize(toolX)
	toolY <- cross(toolZ, toolX)

	M <- cbind(toolX, toolY, toolZ)

	cat(
		"# Version: 14",
		"\n# Coordinate system: NIfTI:S:Scanner",
		"\n# Created by: R",
		"\n# Units: millimetres, degrees, milliseconds, and microvolts",
		"\n# Encoding: UTF-8",
		"\n# Notes: Each column is delimited by a tab. Each value within a column is delimited by a semicolon.",
		"\n# Target Name\tLoc. X\tLoc. Y\tLoc. Z\tm0n0\tm0n1\tm0n2\tm1n0\tm1n1\tm1n2\tm2n0\tm2n1\tm2n2",
		"\nTarget\t", target_df[1], "\t", target_df[2], "\t", target_df[3], "\t", M[1,1], "\t", M[2,1], "\t", M[3,1], "\t", M[1,2], "\t", M[2,2], "\t", M[3,2], "\t", M[1,3], "\t", M[2,3], "\t", M[3,3],
	sep = "")


}
