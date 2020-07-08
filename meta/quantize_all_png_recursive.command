#!/bin/sh

newPath=`echo $0 | awk '{split($0, a, ";"); split(a[1], b, "/"); for(x = 2; x < length(b); x++){printf("/%s", b[x]);} print "";}'`
cd "$newPath"

cd ../Assets

for file in `find . -regex ".*\.png$" -maxdepth 10 -print 2>/dev/null`
do
	base=`echo ${file:2} | sed "s/.png//g"`

	# use sips to convert it to a normal png (incase it is iphone optimized png)
	sips -s format png -s formatOptions best --out "$base-new.png" "$file"

	rm -f "$base.png"

	# use pngquant to make it small
	../Meta/pngquant --speed 1 "$base-new.png" --output "$base.png" --skip-if-larger
	#pngnq -s 1 -n 256 -Q 10 "$base-new.png"

	rm -f "$base-new.png"

done

cd ../MadSteward

for file in `find . -regex ".*\.png$" -maxdepth 10 -print 2>/dev/null`
do
	base=`echo ${file:2} | sed "s/.png//g"`

	# use sips to convert it to a normal png (incase it is iphone optimized png)
	sips -s format png -s formatOptions best --out "$base-new.png" "$file"

	rm -f "$base.png"

	# use pngquant to make it small
	../Meta/pngquant --speed 1 "$base-new.png" --output "$base.png" --skip-if-larger
	#pngnq -s 1 -n 256 -Q 10 "$base-new.png"

	rm -f "$base-new.png"

done
