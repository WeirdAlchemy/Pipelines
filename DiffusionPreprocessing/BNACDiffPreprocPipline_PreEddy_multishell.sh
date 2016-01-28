log_Msg "Invoking Pre-Eddy Steps"
${HCPPIPEDIR}/DiffusionPreprocessing/DiffPreprocPipeline_PreEddy.sh \
  --path=${StudyFolder} \
  --subject=${Subject} \
  --dwiname=${DWIName} \
  --PEdir=${PEdir} \
  --posData=${PosInputImages} \
  --negData=${NegInputImages} \
  --echospacing=${echospacing} \
  --b0maxbval=${b0maxbval} \
  --printcom="${runcmd}"
