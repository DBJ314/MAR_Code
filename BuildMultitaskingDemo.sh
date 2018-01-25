DIRECTORY=`dirname $0`
cd $DIRECTORY
mdef() {
	cat "$1" >> MAREqus.s
	echo >>  MAREqus.s
	echo "$1"
}
mdat() {
	cat "$1" >> MARDat.s
	echo >>  MARDat.s
	echo "$1"
}
mcode() {
	cat "$1" >> MARCode.s
	echo >>  MARCode.s
	echo "$1"
}
echo -n > MAREqus.s
echo ".data" > MARDat.s
echo ".text" > MARCode.s
echo -n > MultitaskingDemo.s

# Multitasking (must go first)
mdef Multitasking/MultitaskingEqus.s
mdat Multitasking/MultitaskingData.s
mcode Multitasking/MultitaskingCode.s

mcode Multitasking/MultitaskingDemoCode.s

mcode HardwareCode.s

mdef Pathfinding/PathfindingEqus.s

#must go last
mcode ExternalSources/HeapCode.s
cat MAREqus.s MARDat.s MARCode.s > MultitaskingDemo.s
rm MARDat.s
rm MARCode.s
rm MAREqus.s




