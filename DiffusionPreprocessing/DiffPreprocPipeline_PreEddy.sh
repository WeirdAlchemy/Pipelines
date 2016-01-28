#!/bin/bash
#~ND~FORMAT~MARKDOWN~
#~ND~START~
#
# # DiffPreprocPipeline_PreEddy.sh
#
# ## Copyright Notice
#
# Copyright (C) 2012-2014 The Human Connectome Project
# 
# * Washington University in St. Louis
# * University of Minnesota
# * Oxford University
#
# ## Author(s)
#
# * Stamatios Sotiropoulos, FMRIB Analysis Group, Oxford University
# * Saad Jbabdi, FMRIB Analysis Group, Oxford University
# * Jesper Andersson, FMRIB Analysis Group, Oxford University
# * Matthew F. Glasser, Department of Anatomy and Neurobiology, Washington University in St. Louis
# * Timothy B. Brown, Neuroinformatics Research Group, Washington University in St. Louis
#
# ## Product
#
# [Human Connectome Project][HCP] (HCP) Pipeline Tools
#
# ## License
#
# See the [LICENSE](https://github.com/Washington-University/Pipelines/blob/master/LICENCE.md) file
#
# ## Description
#
# This script, DiffPreprocPipeline_PreEddy.sh, implements the first part of the 
# Preprocessing Pipeline for diffusion MRI describe in [Glasser et al. 2013][GlasserEtAl].
# The entire Preprocessing Pipeline for diffusion MRI is split into pre-eddy, eddy,
# and post-eddy scripts so that the running of eddy processing can be submitted 
# to a cluster scheduler to take advantage of running on a set of GPUs without forcing
# the entire diffusion preprocessing to occur on a GPU enabled system.  This particular
# script implements the pre-eddy part of the diffusion preprocessing.
#
# ## Prerequisite Installed Software for the Diffusion Preprocessing Pipeline
#
# * [FSL][FSL] - FMRIB's Software Library (version 5.0.6)
#   
#   FSL's environment setup script must also be sourced
#
# * [FreeSurfer][FreeSurfer] (version 5.3.0-HCP)
#
# * [HCP-gradunwarp][HCP-gradunwarp] - (HCP version 1.0.2)
#
# ## Prerequisite Environment Variables
#
# See output of usage function: e.g. $ ./DiffPreprocPipeline_PreEddy.sh --help
# 
# <!-- References -->
# [HCP]: http://www.humanconnectome.org
# [GlasserEtAl]: http://www.ncbi.nlm.nih.gov/pubmed/23668970
# [FSL]: http://fsl.fmrib.ox.ac.uk
# [FreeSurfer]: http://freesurfer.net
# [gradunwarp]: https://github.com/ksubramz/gradunwarp.git
#
#~ND~END~

# Setup this script such that if any command exits with a non-zero value, the 
# script itself exits and does not attempt any further processing.
set -e

# Load Function Libraries
source ${HCPPIPEDIR}/global/scripts/log.shlib     # log_ functions
source ${HCPPIPEDIR}/global/scripts/version.shlib # version_ functions

# 
# Function Description
#  Show usage information for this script
#
usage()
{
	local scriptName=$(basename ${0})
	echo ""
	echo "  Perform the Pre-Eddy steps of the HCP Diffusion Preprocessing Pipeline"
	echo ""
	echo "  Usage: ${scriptName} <options>"
	echo ""
	echo "  Options: [ ] = optional; < > = user supplied value"
	echo ""
	echo "    [--help] : show usage information and exit with non-zero return code"
	echo ""
	echo "    [--version] : show version information and exit with 0 as return code"
	echo ""
	echo "    --path=<study-path>"
	echo "    : path to subject's data folder"
	echo ""
	echo "    --subject=<subject-id>"
	echo "    : Subject ID"
	echo ""
	echo "    --shell1Data=<shell-1-data>"
	echo "    : data with smaller b value encoding"
	echo ""
	echo "    --shell2Data=<shell-2-data>"
	echo "    : data with larger b value encoding"
	echo ""	
	echo "    --supb0=<supplementary b=0 image>"
	echo "    : supplementary b=0 image for field mapping with topup"
	echo ""
	echo "    --supb0rev=<supplementary b=0 phase-reversed image>"
	echo "    : supplementary b=0 reversed image for field mapping with topup"
	echo ""
	echo "    --echospacing=<echo-spacing>"
	echo "    : Echo spacing in msecs"
	echo ""
	echo "    [--dwiname=<DWIname>]"
	echo "    : name to give DWI output directories"
	echo "      defaults to Diffusion"
	echo ""
	echo "    [--printcom=<print-command>]"
	echo "    : Use the specified <print-command> to echo or otherwise output the commands"
	echo "      that would be executed instead of actually running them"
	echo "      --printcom=echo is intended for testing purposes"
	echo ""
	echo "  Return Code:"
	echo ""
	echo "    0 if help was not requested, all parameters were properly formed, and processing succeeded"
	echo "    Non-zero otherwise - malformed parameters, help requested, or processing failure was detected"
	echo ""
	echo "  Required Environment Variables:"
	echo ""
	echo "    HCPPIPEDIR"
	echo ""
	echo "      The home directory for the version of the HCP Pipeline Tools product"
	echo "      being used."
	echo ""
	echo "      Example value: /nrgpackages/tools.release/hcp-pipeline-tools-3.0"
	echo ""
	echo "    HCPPIPEDIR_dMRI"
	echo ""
	echo "      Location of Diffusion MRI sub-scripts that are used to carry out some of the"
	echo "      steps of the Diffusion Preprocessing Pipeline"
	echo ""
	echo "      Example value: ${HCPPIPEDIR}/DiffusionPreprocessing/scripts"
	echo ""
	echo "    FSLDIR"
	echo ""
	echo "      The home directory for FSL"
	echo ""
}

#
# Function Description
#  Get the command line options for this script
#
# Global Output Variables
#  ${StudyFolder}		- Path to subject's data folder
#  ${Subject}			- Subject ID
#  ${PEdir}				- Phase Encoding Direction, 1=RL/LR, 2=PA/AP
#  ${Shell1Data}	- data with smaller b value encoding
#  ${Shell2Data}	- data with larger b value encoding
#  ${Supb0}				- supplementary b=0 image for field mapping with topup
#  ${Supb0rev}		- supplementary b=0 reversed image for field mapping with topup
#  ${echospacing}		- echo spacing in msecs
#  ${DWIName}			- Name to give DWI output directories
#  ${runcmd}			- Set to a user specifed command to use if user has requested
#						  that commands be echo'd (or printed) instead of actually executed.
#						  Otherwise, set to empty string.
#

echo "    --shell1Data=<shell-1-data>"
echo "    : data with smaller b value encoding"
echo ""
echo "    --shell2Data=<shell-2-data>"
echo "    : data with larger b value encoding"
echo ""	
echo "    --supb0=<supplementary b=0 image>"
echo "    : supplementary b=0 image for field mapping with topup"
echo ""
echo "    --supb0rev=<supplementary b=0 phase-reversed image>"
echo "    : supplementary b=0 reversed image for field mapping with topup"


get_options()
{
	local scriptName=$(basename ${0})
	local arguments=($@)
	
	# initialize global output variables
	unset StudyFolder
	unset Subject
	unset Shell1Data
	unset Shell2Data
	unset Supb0
	unset Supb0rev
	unset echospacing
	DWIName="Diffusion"
	runcmd=""
	
	# parse arguments
	local index=0
	local numArgs=${#arguments[@]}
	local argument
	
	while [ ${index} -lt ${numArgs} ]
	do
		argument=${arguments[index]}
		
		case ${argument} in
			--help)
				usage
				exit 1
				;;
			--version)
				version_show $@
				exit 0
				;;
			--path=*)
				StudyFolder=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--subject=*)
				Subject=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--shell1Data=*)
				Shell1Data=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--shell2Data=*)
				Shell2Data=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--supb0=*)
				Supb0=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--supb0rev=*)
				Supb0rev=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--dwiname=*)
				DWIName=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--echospacing=*)
				echospacing=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--printcom=*)
				runcmd=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			*)
				usage
				echo "ERROR: Unrecognized Option: ${argument}"
				exit 1
				;;
		esac
	done
	
	# check required parameters
	if [ -z ${StudyFolder} ]
	then
		usage
		echo "ERROR: <study-path> not specified"
		exit 1
	fi
	
	if [ -z ${Subject} ]
	then
		usage
		echo "ERROR: <subject-id> not specified"
		exit 1
	fi
		
	if [ -z ${Shell1Data} ]
	then
		usage
		echo "ERROR: <shell-1-data> not specified"
		exit 1
	fi
	
	if [ -z ${Shell2Data} ]
	then
		usage
		echo "ERROR: <shell-2-data> not specified"
		exit 1
	fi

	if [ -z ${Supb0} ]
	then
		usage
		echo "ERROR: <supb0> not specified"
		exit 1
	fi

	if [ -z ${Supb0rev} ]
	then
		usage
		echo "ERROR: <supb0rev> not specified"
		exit 1
	fi


	if [ -z ${echospacing} ]
	then
		usage
		echo "ERROR: <echo-spacing> not specified"
		exit 1
	fi
	
	
	if [ -z ${DWIName} ]
	then
		usage
		echo "ERROR: <DWIName> not specified"
		exit 1
	fi
	
	# report options
	echo "-- ${scriptName}: Specified Command-Line Options - Start --"
	echo "   StudyFolder: ${StudyFolder}"
	echo "   Subject: ${Subject}"
	echo "   Shell1Data: ${Shell1Data}"
	echo "   Shell2Data: ${Shell2Data}"
	echo "   Supb0: ${Supb0}"
	echo "   Supb0rev: ${Supb0rev}"	
	echo "   echospacing: ${echospacing}"
	echo "   DWIName: ${DWIName}"
	echo "   runcmd: ${runcmd}"
	echo "-- ${scriptName}: Specified Command-Line Options - End --"
}

# 
# Function Description
#  Validate necessary environment variables
#
validate_environment_vars() {
	local scriptName=$(basename ${0})
	# validate
	
	if [ -z ${HCPPIPEDIR_dMRI} ]
	then
		usage
		echo "ERROR: HCPPIPEDIR_dMRI environment variable not set"
		exit 1
	fi
	
	if [ ! -e ${HCPPIPEDIR_dMRI}/basic_preproc.sh ]
	then
		usage
		echo "ERROR: HCPPIPEDIR_dMRI/basic_preproc.sh not found"
		exit 1
	fi
	
	if [ ! -e ${HCPPIPEDIR_dMRI}/run_topup.sh ]
	then
		usage
		echo "ERROR: HCPPIPEDIR_dMRI/run_topup.sh not found"
		exit 1
	fi
	
	if [ -z ${FSLDIR} ]
	then
		usage
		echo "ERROR: FSLDIR environment variable not set"
		exit 1
	fi
	
	# report
	echo "-- ${scriptName}: Environment Variables Used - Start --"
	echo "   HCPPIPEDIR_dMRI: ${HCPPIPEDIR_dMRI}"
	echo "   FSLDIR: ${FSLDIR}"
	echo "-- ${scriptName}: Environment Variables Used - End --"
}

#
# Function Description
#  find the min between two numbers
#
min()
{
	if [ $1 -le $2 ]
	then
		echo $1
	else
		echo $2
	fi
}

#
# Function Description
#  Main processing of script
#
#  Gets user specified command line options, runs Pre-Eddy steps of Diffusion Preprocessing
#
main()
{
	# Hard-Coded variables for the pipeline
	MissingFileFlag="EMPTY"  # String used in the input arguments to indicate that a complete series is missing
	b0dist=45                # Minimum distance in volums between b0s considered for preprocessing
	
	# Get Command Line Options
	#
	# Global Variables Set
	#  ${StudyFolder}		- Path to subject's data folder
	#  ${Subject}			- Subject ID
	#  ${PosInputImages}	- @ symbol separated list of data with positive phase encoding direction
	#  ${echospacing}		- echo spacing in msecs
	#  ${DWIName}			- Name to give DWI output directories
	#  ${runcmd}			- Set to a user specifed command to use if user has requested
	#						  that commands be echo'd (or printed) instead of actually executed.
	#						  Otherwise, set to empty string.
	get_options $@
	
	# Validate environment variables
	validate_environment_vars $@
	
	# Establish tool name for logging
	log_SetToolName "DiffPreprocPipeline_PreEddy.sh"
	
	# Establish output directory paths
	outdir=${StudyFolder}/${Subject}/${DWIName}
	outdirT1w=${StudyFolder}/${Subject}/T1w/${DWIName}
	
	# Delete any existing output sub-directories
	if [ -d ${outdir} ]
	then
		${runcmd} rm -rf ${outdir}/rawdata
		${runcmd} rm -rf ${outdir}/topup
		${runcmd} rm -rf ${outdir}/eddy
		${runcmd} rm -rf ${outdir}/data
		${runcmd} rm -rf ${outdir}/reg
	fi
	
	# Make sure output directories exist
	${runcmd} mkdir -p ${outdir}
	${runcmd} mkdir -p ${outdirT1w}
	
	log_Msg "outdir: ${outdir}"
	${runcmd} mkdir ${outdir}/rawdata
	${runcmd} mkdir ${outdir}/topup
	${runcmd} mkdir ${outdir}/eddy
	${runcmd} mkdir ${outdir}/data
	${runcmd} mkdir ${outdir}/reg
	
	
	log_Msg "Copying raw data to working directory"
	
	basedti="dti"
	
	# Copy shell 1
	absname=`${FSLDIR}/bin/imglob ${Shell1Data}`
	${runcmd} ${FSLDIR}/bin/imcp ${absname} ${outdir}/rawdata/${basedti}_s1
	${runcmd} cp ${absname}.bval ${outdir}/rawdata/${basedti}_s1.bval
	${runcmd} cp ${absname}.bvec ${outdir}/rawdata/${basedti}_s1.bvec
		
	# Copy shell 2
	absname=`${FSLDIR}/bin/imglob ${Shell2Data}`
	${runcmd} ${FSLDIR}/bin/imcp ${absname} ${outdir}/rawdata/${basedti}_s2
	${runcmd} cp ${absname}.bval ${outdir}/rawdata/${basedti}_s2.bval
	${runcmd} cp ${absname}.bvec ${outdir}/rawdata/${basedti}_s2.bvec

	# Copy sup b=0
	absname=`${FSLDIR}/bin/imglob ${Supb0}`
	${runcmd} ${FSLDIR}/bin/imcp ${absname} ${outdir}/rawdata/${basedti}_supb0

	# Copy sup b=0 rev
	absname=`${FSLDIR}/bin/imglob ${Supb0rev}`
	${runcmd} ${FSLDIR}/bin/imcp ${absname} ${outdir}/rawdata/${basedti}_supb0rev

	log_Msg "Running Basic Preprocessing"
	${runcmd} ${HCPPIPEDIR_dMRI}/basic_preproc.sh ${outdir} ${echospacing} ${b0dist}
	
	log_Msg "Running Topup"
	${runcmd} ${HCPPIPEDIR_dMRI}/run_topup.sh ${outdir}/topup
	
	log_Msg "Completed"
	exit 0
}

#
# Invoke the main function to get things started
#
main $@
