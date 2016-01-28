EXAMID=$1
cd $SUBJECTSDIR/$EXAMID/T1w/$EXAMID
freeview -v mri/T1.mgz \
mri/brainmask.mgz \
-f surf/lh.white:edgecolor=yellow \
surf/lh.pial:edgecolor=red \
surf/rh.white:edgecolor=yellow \
surf/rh.pial:edgecolor=red
