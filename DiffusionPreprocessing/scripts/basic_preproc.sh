#!/bin/bash
set -e
scriptName="basic_preproc.sh"
echo -e "\n START: ${scriptName}"

workingdir=$1
echo_spacing=$2
b0dist=$3

echo "${scriptName}: Input Parameter: workingdir: ${workingdir}"
echo "${scriptName}: Input Parameter: echo_spacing: ${echo_spacing}"
echo "${scriptName}: Input Parameter: b0dist: ${b0dist}"

isodd(){
	echo "$(( $1 % 2 ))"
}

rawdir=${workingdir}/rawdata
topupdir=${workingdir}/topup
eddydir=${workingdir}/eddy
basePos="PA"
baseNeg="AP"


#Compute Total_readout in secs with up to 6 decimal places
any=`ls ${rawdir}/*s1.nii* |head -n 1`
dimP=`${FSLDIR}/bin/fslval ${any} dim2`
nPEsteps=$(($dimP - 1))                         #If GRAPPA is used this needs to include the GRAPPA factor!
#Total_readout=Echo_spacing*(#of_PE_steps-1)   
ro_time=`echo "${echo_spacing} * ${nPEsteps}" | bc -l`
ro_time=`echo "scale=6; ${ro_time} / 1000" | bc -l`
echo "${scriptName}: Total readout time is $ro_time secs"


################################################################################################
## Intensity Normalisation across Series 
################################################################################################

b0maxbval=50

echo "${scriptName}: Rescaling series to ensure consistency across baseline intensities"
entry_cnt=0
for entry in ${rawdir}/*_s1.nii.* ${rawdir}/*_s2.nii.*  #For each series, get the mean b0 and rescale to match the first series baseline
do
	basename=`imglob ${entry}`
	echo "${scriptName}: Processing $basename"
	
	echo "${scriptName}: About to fslmaths ${entry} -Xmean -Ymean -Zmean ${basename}_mean"
	${FSLDIR}/bin/fslmaths ${entry} -Xmean -Ymean -Zmean ${basename}_mean
	if [ ! -e ${basename}_mean.nii.gz ] ; then
		echo "${scriptName}: ERROR: Mean file: ${basename}_mean.nii.gz not created"
		exit 1
	fi
	
	echo "${scriptName}: Getting Posbvals from ${basename}.bval"
	Posbvals=`cat ${basename}.bval`
	echo "${scriptName}: Posbvals: ${Posbvals}"
	
	mcnt=0
	for i in ${Posbvals} #extract all b0s for the series
	do
		echo "${scriptName}: Posbvals i: ${i}"
		cnt=`$FSLDIR/bin/zeropad $mcnt 4`
		echo "${scriptName}: cnt: ${cnt}"
		if [ $i -lt ${b0maxbval} ]; then
			echo "${scriptName}: About to fslroi ${basename}_mean ${basename}_b0_${cnt} ${mcnt} 1"
			$FSLDIR/bin/fslroi ${basename}_mean ${basename}_b0_${cnt} ${mcnt} 1
		fi
		mcnt=$((${mcnt} + 1))
	done
	
	echo "${scriptName}: About to fslmerge -t ${basename}_mean `echo ${basename}_b0_????.nii*`"
	${FSLDIR}/bin/fslmerge -t ${basename}_mean `echo ${basename}_b0_????.nii*`
	
	echo "${scriptName}: About to fslmaths ${basename}_mean -Tmean ${basename}_mean"
	${FSLDIR}/bin/fslmaths ${basename}_mean -Tmean ${basename}_mean #This is the mean baseline b0 intensity for the series
	${FSLDIR}/bin/imrm ${basename}_b0_????
	if [ ${entry_cnt} -eq 0 ]; then      #Do not rescale the first series
		rescale=`fslmeants -i ${basename}_mean`
	else
		scaleS=`fslmeants -i ${basename}_mean`
		${FSLDIR}/bin/fslmaths ${basename} -mul ${rescale} -div ${scaleS} ${basename}_new
		${FSLDIR}/bin/imrm ${basename}   #For the rest, replace the original dataseries with the rescaled one
		${FSLDIR}/bin/immv ${basename}_new ${basename}
	fi
	entry_cnt=$((${entry_cnt} + 1))
	${FSLDIR}/bin/imrm ${basename}_mean
done


echo "Move files to appropriate directories"

# readOutTime = echoSpacing * ((matrixLines*partialFourier/accelerationFactor)-1)
# (604  * ((104/2)-1) )  / 1000000
# TODO unclear whether
echo "0 1 0 0.062212" > ${topupdir}/acqparams.txt
echo "0 1 0 0.062212" >> ${topupdir}/acqparams.txt
echo "0 1 0 0.062212" >> ${topupdir}/acqparams.txt
echo "0 -1 0 0.062212" >> ${topupdir}/acqparams.txt
echo "0 -1 0 0.062212" >> ${topupdir}/acqparams.txt
echo "0 -1 0 0.062212" >> ${topupdir}/acqparams.txt


${FSLDIR}/bin/fslmerge -t ${topupdir}/Pos_Neg_b0_odd ${rawdir}/dti_supb0 ${rawdir}/dti_supb0rev 
${FSLDIR}/bin/fslroi ${topupdir}/Pos_Neg_b0_odd ${topupdir}/Pos_Neg_b0_firstslice 0 -1 0 -1 0 1
${FSLDIR}/bin/fslmerge -z ${topupdir}/Pos_Neg_b0 ${topupdir}/Pos_Neg_b0_firstslice ${topupdir}/Pos_Neg_b0_odd
${FSLDIR}/bin/imrm ${topupdir}/Pos_Neg_b0_odd ${topupdir}/Pos_Neg_b0_firstslice

${FSLDIR}/bin/fslroi ${topupdir}/Pos_Neg_b0 ${topupdir}/Pos_b0 0 3
${FSLDIR}/bin/fslroi ${topupdir}/Pos_Neg_b0 ${topupdir}/Neg_b0 3 3

cp ${topupdir}/acqparams.txt ${eddydir}

echo "" > ${eddydir}/index.txt
echo "" > ${eddydir}/series_index.txt

${FSLDIR}/bin/fslmerge -t ${eddydir}/Pos_Neg_odd ${rawdir}/dti_s1.nii.gz ${rawdir}/dti_s2.nii.gz

${FSLDIR}/bin/fslroi ${eddydir}/Pos_Neg_odd ${eddydir}/Pos_Neg_odd_firstslice 0 -1 0 -1 0 1
${FSLDIR}/bin/fslmerge -z ${eddydir}/Pos_Neg ${eddydir}/Pos_Neg_odd_firstslice ${eddydir}/Pos_Neg_odd
${FSLDIR}/bin/imrm ${eddydir}/Pos_Neg_odd ${eddydir}/Pos_Neg_odd_firstslice

paste -d " " ${rawdir}/dti_s1.bval ${rawdir}/dti_s2.bval > ${eddydir}/Pos_Neg.bvals
paste -d " " ${rawdir}/dti_s1.bvec ${rawdir}/dti_s2.bvec > ${eddydir}/Pos_Neg.bvecs

echo -e "\n END: basic_preproc"
