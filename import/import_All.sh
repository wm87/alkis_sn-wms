#!/bin/bash

cd /bigdata/alkis_sn/
rm /bigdata/alkis_sn/*

wget -O ./aaa_alkis_sn.zip "https://geocloud.landesvermessung.sachsen.de/public.php/dav/files/kSCYk4FYbdj558d/alkis_sn.zip"

filelist=$HOME/alkis_sn/filelists/nas_sn.lst

echo "PG:dbname=alkis_sn user=postgres password=postgres" >$filelist
echo "epsg 25833" >>$filelist
echo "create" >>$filelist
echo "temp /bigdata/tmp/alkis" >>$filelist
echo "avoiddupes on" >>$filelist
echo "historie off" >>$filelist
echo "usecopy yes" >>$filelist
#echo "skipfailuresregex .*" >>$filelist
echo "jobs 6" >>$filelist

echo "log $HOME/alkis_sn/filelists/logs/sn.log" >>$filelist

while [ "$(find . -type f -name '*.zip' | wc -l)" -gt 0 ]; do
	find . -type f -name "*.zip" -exec unzip -- '{}' \; -exec rm -- '{}' \;
done

#Use this for compression
ls ./*.xml | parallel --gnu -j-0 --eta \
	'gzip {}'

for j in *.xml.gz; do
	path="$PWD"
	echo ${path}"/"$j >>$filelist
done

echo "postprocess" >>$filelist
