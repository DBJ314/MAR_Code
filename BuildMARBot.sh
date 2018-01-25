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
echo -n > MARBot.s

# Multitasking (must go first)
mdef Multitasking/MultitaskingEqus.s
mdat Multitasking/MultitaskingData.s
mcode Multitasking/MultitaskingCode.s

mdef Misc/MiscEqus.s
mdat Misc/MiscData.s
mcode Misc/MiscCode.s

mcode HardwareCode.s

mdef Pathfinding/PathfindingEqus.s
mdat PathFinding/PathfindingData.s
mcode Pathfinding/PathfindingCode.s

mdef Text/TextEqus.s
mdat Text/TextData.s
mcode Text/TextCode.s

#must go last
mcode ExternalSources/HeapCode.s
cat MAREqus.s MARDat.s MARCode.s > MARBot.s
rm MARDat.s
rm MARCode.s
rm MAREqus.s




