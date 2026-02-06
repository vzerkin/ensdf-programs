#!/bin/bash

# Author:  Viktor Zerkin <v.zerkin@gmail.com>
# Created: November 25, 2025
# License: MIT

outWelcome() {
    cat <<-EOF
	   +-----------------------------------------+
	   |  Set modification time of ENSDF files   |
	   | from the latest update date of Datasets.|
	   |  Genarate summary and distribution of   |
	   |   ENSDF files and Datasets by years     |
	   +-----------------------------------------+
	   | Program: setdate2ensdf.sh, v.2025-12-07 |
	   |       /by V.Zerkin, Vienna, 2025/       |
	   +-----------------------------------------+
	EOF
}
outPlatform() {
    cat <<-EOF
	   Platform: `uname -s -m -r`
	   Computer: `uname -n`
	   Shell:    `bash --version|head -n 1`
	   Bash-ver: $BASH_VERSION
	   Script:   $0
	   Now Dir:  `pwd`
	EOF
}
outHelp() {
    cat <<-EOF
	
	----------------------Help----------------------
	Run:
	    $ [bash] [scriptdir]setdate2ensdf.sh [{options|files}]
	Options:
	   -c        show command setting new time
	   -o        show old timestamp of ENSDF file
	   -d:<day>  set day in a month (1-28)
	   -t:<time> set time, for example: -t:15:30:45
	   -help     display this text
	Files:
	    files  ENSDF file or files; e.g: dir1/ensdf.*
	    dir    dir with ENSDF backup files ensdf.???; e.g. ensdf_251201/
	Examples:
	    $ bash setdate2ensdf.sh
	    $ ./setdate2ensdf.sh --help
	    $ ~/bin/setdate2ensdf.sh ensdf_251103/ensdf.*
	    $ bash setdate2ensdf.sh ensdf.016 ensdf.100 ensdf.123
	    $ ~/bin/setdate2ensdf.sh ensdf.12?
	    $ setdate2ensdf.sh ensdf.00? -co -t:15:30:50 -d:5
	    $ bash setdate2ensdf.sh G:\\ensdf\\ensdf_251201
	EOF
}

myos=`uname -s`
getTimestampOfFile() {
    local t=0
    if [ "$myos" = "Darwin" ] ; then
	t="`stat -l -t '%F %T %z' "$1"|awk '{ print $6$7 }'`"
    else
	t="`ls -l --time-style=full-iso "$1"|awk '{ print $6$7 }'|cut -c 1-18`"
    fi
    t="${t//[^0-9]/}"
    eval $2=$t
}
itime2str() {
    local s="$1"
    s="${s//[^0-9]/}"
    s="${s:0:4}-${s:4:2}-${s:6:2}T${s:8:2}:${s:10:2}:${s:12:2}"
    eval $2="$s"
}


#---global flags and default parameters
showCmd=0
showOld=0
setDay="01"
setTim="1200.00" #hhmm.ss
dir00=""
names0="ensdf.???"
#---files to store statistics
dsout="/tmp/datasets"
sumout="/tmp/summary"
report="/tmp/report"

declare -a dscounts	#datasets(year)
declare -a flcounts     #files(year)
declare -a files	#ENSDF files
nf=0; txfiles=""

initData() {
    #---prepare arrays to collect statistics
    for i in {1900..2100}; do
	dscounts[i]=0
	flcounts[i]=0
    done
    #---create tmp files
    if [ -f $dsout  ]; then rm -f $dsout ; fi; touch $dsout
    if [ -f $sumout ]; then rm -f $sumout; fi; touch $sumout
    if [ -f $report ]; then rm -f $report; fi; touch $report
}

#---parse arguments from commamd line
getArgs() {
#    echo "---getArgs: $*"
    local i=1
    local d t
    for arg in "$@" ; do
#	echo "-------------arg$i: [$arg]"
	i=$(($i + 1))
	if [ -d "$arg" ]; then
	    dir00="$arg"
	    pushd "$arg" >/dev/null
	    dir00="`pwd`"
	    popd >/dev/null
	    continue
	fi
	if [ -f "$arg" ]; then
	    files[$nf]="$arg"
	    nf=$(($nf + 1))
	    if [ $nf -eq 1 ]; then
		DR=$(dirname "${arg}")
		dir00="$DR"
		pushd "$dir00" >/dev/null
		dir00="`pwd`"
		popd >/dev/null
		txfiles=" dir=${dir00}/"
	    fi
	    if [ $nf -lt 4 ]; then
		nam=${arg//\\/\\/}
		nam=${nam##*/}
		txfiles="$txfiles $nam"
	    else
		if [ $nf -eq 4 ]; then txfiles="$txfiles ..."; fi
	    fi
	    continue
	fi
	if [ "${arg:0:3}" = "-d:" ]; then
	    d="${arg:3}"; d="${d//[^0-9]/}";
	    d=$((10#$d))
	    if [ $d -ge 1 ]; then
		if [ $d -le 31 ]; then
		    printf -v setDay "%02d" $d
#		    echo "---set-day:[$setDay]"
		fi
	    fi
	fi
	if [ "${arg:0:3}" = "-t:" ]; then
	    t="${arg:3}"; t="${t//[^0-9]/}"; ll=${#t}
	    if [ $ll -eq 6 ]; then
		setTim="${t:0:2}${t:2:2}.${t:4:2}"
#		echo "---set-time:[$t]"
	    fi
	fi
	if [ "${arg:0:1}" = "-" ]; then
	    if [[ $arg =~ [c] ]]; then showCmd=1; fi
	    if [[ $arg =~ [o] ]]; then showOld=1; fi
	fi
    done
}

main() {

#---starting main program: Welcome, Help+exit
    outWelcome
    if [ "$1" = "--help" ] ; then outHelp; exit; fi
    if [ "$1" = "-help"  ] ; then outHelp; exit; fi
    if [ "$1" = "-h"     ] ; then outHelp; exit; fi
    outPlatform

    getArgs "$@"

#---if ENSDF files are not given in command-line
#   try find backup ENSDF files in current dir
    if [ $nf -le 0 ]; then
	if [ "${dir00}" = "" ]; then
	    filenames=${names0}
	    dir00="`pwd`"
	else
	    filenames="${dir00}/${names0}"
	fi
	txfiles="$filenames";
	nf=0
	for name in ${filenames}; do 
	    nf=$(($nf + 1))
	    files[$nf]="$name"
	done
    fi

    initData #init arrays, clean files

#---starting report
    cat >$report <<-EOF
	---ENSDF files statistics.
	---Generated: `date +'%F,%T'`
	---Computer:  `uname -n`
	---Directory: ${dir00}
	
	----------ENSDF-files----------
	EOF

#---show input parameters and starting time
    echo "   in-files: #$nf:${txfiles}"
    echo "   out-tmp:  $dsout"
    echo "   DayTime:  $setDay$setTim # DDHHMM.SS"
    echo "---Start:    `date +'%F,%T'`"

#---main loop: read ENSDF files and set modfication-time
    t00=`date +%s`
    ifile=0; nDatasets=0; totSize=0; totLines=0; totMax=0; totMin=0
    for name in "${files[@]}"; do
	if [ -f $name ]; then
	    ifile=$(($ifile+1))
	    nam=${name##*/}
#	    printf "%5d) %-18s %s \r" $ifile ${name} `date +%F,%T`
	    echo -en "#$ifile ${name}\r"
	    ids=0
	    iln=0
	    mindat=0
	    maxdat=0
	    while IFS= read -r str0; do
		iln=$(($iln+1))
#		echo "--$iln [$str0]"
		str1="${str0// /}"
		if [ "$str1" = "" ]; then
		    iln=0
		    continue
		fi
		if [ $iln -eq 1 ]; then
		    dat="${str0:74:6}"
		    ds=${str0:9:30}
		    year="${dat:0:4}"
		    dat="${dat// /}"
		    dat=$(($dat+0))
		    ids=$(($ids+1))
		    nDatasets=$(($nDatasets+1))
		    if [ $dat -gt 0 ]; then
			year=$(($year+0))
			nn=${dscounts[$year]}; nn=$(($nn+1)); dscounts[$year]=$nn
			if [ $totMax -eq 0 ]; then totMax=$dat; totMin=$dat; fi
			if [ $maxdat -eq 0 ]; then maxdat=$dat; mindat=$dat; fi
			if [ $dat -gt $maxdat ]; then maxdat=$dat; fi
			if [ $dat -lt $mindat ]; then mindat=$dat; fi
			if [ $dat -gt $totMax ]; then totMax=$dat; fi
			if [ $dat -lt $totMin ]; then totMin=$dat; fi
		    fi
		    echo -en "#$ifile $nam $ids:[$ds] dat:[$dat][$mindat-$maxdat]\r"
		    echo "$str0" >>$dsout
		fi
	    done < $name
	    ln=`cat "$name"|wc -l`
	    totLines=$(($totLines+$ln))
	    size=`ls -l "$name" |awk '{ print $5 }'`
	    totSize=$(($totSize+$size))
	    printf "%4d  %-10s [%6s-%6s]  size:%-8s lines:%-6d datasets:%-4d \x1b[0K\n" \
	    $ifile "$nam" "$mindat" "$maxdat" "$size" $ln $ids
	    printf >>$report "%4d  %-10s [%6s-%6s]  size:%-8s lines:%-6d datasets:%-4d\n" \
	    $ifile "$nam" "$mindat" "$maxdat" "$size" $ln $ids
	    if [ $maxdat -gt 190000 ]; then
		year="${maxdat}"
		year="${year:0:4}"
		year=$(($year+0))
		nn=${flcounts[$year]}; nn=$(($nn+1)); flcounts[$year]=$nn
#		ftime="${maxdat}011200.00" #noon=12:00:00
		ftime="${maxdat}${setDay}${setTim}" #noon=12:00:00
		if [ $showOld -ne 0 ]; then
		    itime2str "$ftime" newt
		    getTimestampOfFile "$name" otime
		    itime2str "$otime" oldt
		    echo "	#old time: ${oldt//T/ }"
		    echo "	#new time: ${newt//T/ }"
		fi
		if [ $showCmd -ne 0 ]; then
		    echo "	$ touch -t $ftime $name"
		fi
		touch -t "$ftime" "$name"
	    fi
#tst	    if [ $ifile -ge 40 ]; then break; fi
	fi
    done

    t11=`date +%s`; dt=$(($t11-$t00))
    printf -v minsec "%02d:%02d" $((dt/60)) $((dt%60))
    echo "---Finish:   `date +'%F,%T'`"
    echo "---Program successfully completed---------------------------${minsec}=${dt}sec"

    nNucl=`cat $dsout|cut -b1-6|grep -v "   "|sort -u|wc -l`
    nMassChn=`cat $dsout|cut -b1-3|grep -v "   "|sort -u|wc -l`

    sizeMB=$((((totSize+1023)/1024+1023)/1024))
    cat >>$sumout <<-EOF
	
	-------Summary of ENSDF files-------
	  Files:       $ifile
	  Size:        $totSize(~${sizeMB}M)
	  Lines:       $totLines
	  Mass Chains: $nMassChn
	  Nuclides:    $nNucl
	  Datasets:    $nDatasets
	  Dates:       $totMin-$totMax
	
	EOF

    echo >>$sumout "--------Summary of updating--------"
    echo >>$sumout "--Year  #Datasets #Files"
    for (( year=2100; year>1900; year-- )); do
	nnds=${dscounts[$year]}
	nnfl=${flcounts[$year]}
	nn=$(($nnds+$nnfl))
	if [ $nn -gt 0 ]; then
#	    echo "$year: $nnds"
	    if [ $nnfl -gt 0 ]; then
		printf -v ss "%*s" $nnfl ""
		ss="${ss// /|}"
		printf >>$sumout "  %4d  %-9d %-3d %s\n" $year ${nnds} ${nnfl} "${ss}"
	    else
		printf >>$sumout "  %4d  %-9d -\n" $year ${nnds}
	    fi
	fi
    done
    echo >>$sumout ""

#---Generate histogram
    echo >>$sumout "---#Datasets by types---"
    nReac=`cat $dsout|cut -b10-39|grep "("|grep -v DECAY|wc -l`
    nDecay=`cat $dsout|cut -b10-39|grep "DECAY"|wc -l`
    printf >>$sumout "%7d #Reactions#\n" $nReac
    printf >>$sumout "%7d #Decay#\n" $nDecay
    cat $dsout|cut -b10-39|grep -v "("|grep -v '^[0-9]'|sort|uniq -c|sort -gr>>$sumout
    echo >>$sumout ""

    cat $sumout
    cat $sumout>>$report

    lastdir="${dir00##*/}"
    if [ "${lastdir//./}" = "" ]; then lastdir=`date +'%Y%m%d'`; fi
    mv "$dsout"  "${dsout}-$lastdir.txt"
    mv "$sumout" "${sumout}-$lastdir.txt"
    mv "$report" "${report}-$lastdir.txt"
    #rm -i "$dsout"
    #rm -i "$sumout"
}

main "$@"
