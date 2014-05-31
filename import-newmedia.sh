#!/opt/bin/bash
# -------------------------------------------------------------------------------
# Name:         import-newmedia.sh
# Description:  Takes media from a Source repository and imports it on a Target
#               media repository.
# Author:       Carlos Veira Lorenzo - cveira [at] thinkinbig.org
# Version:      0.3b
# Date:         2014/05/29
# -------------------------------------------------------------------------------
# Usage:        import-newmedia.sh <ConfigProfileName> [-refresh] [-NoSync]
# -------------------------------------------------------------------------------
# Dependencies: ls, cat, awk, grep, sed, cp, tr, tail, head, cut, dirname, wc,
#               mkdir, mv, mkfifo, find, rm, tee, sort
#               7z, sublimininal, python 2.7
#               import-newmedia-<ConfigProfileName>.conf
# -------------------------------------------------------------------------------
# Notes:
#   Tested under Bash + BusyBox
#   Works under Synology NAS
# -------------------------------------------------------------------------------

export PATH=/opt/bin:/opt/sbin:/opt/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/usr/syno/sbin:/usr/syno/bin:/usr/local/sbin:/usr/local/bin

BinDir=/opt/bin
InstallDir=/volume1/jobs/scripts
LogsDir=/volume1/jobs/logs
TmpDir=/volume1/jobs/tmp

STATUS_OK=0
STATUS_ON=1
STATUS_OFF=0

SIZE_1GB=1073741824
SIZE_2GB=2147483648

UNKNOWN_FOLDER="_unclassified"
TVSHOWS_FOLDER="tv shows"
MOVIES_FOLDER="movies"
WORKAREA="_workarea"

ConfigurationProfile="$1"
CLI_RefreshSubtitles="-refresh"
CLI_NoSync="-NoSync"

RefreshSubtitles=$STATUS_OFF
NoSync=$STATUS_OFF

CurrentDate=$(date +%Y%m%d)
CurrentSequenceId=$(ls -1AB $LogsDir/*$CurrentDate* 2> /dev/null | wc -l)
CurrentSessionId="$CurrentDate-$CurrentSequenceId"

# Escaped Regular Expressions to use with the 'find' command
ARCHIVE_FORMATS=".*\(zip\|rar\|tgz\|gz\|7z\)$"
VIDEO_FORMATS=".*\(avi\|mp4\|mpeg\|m1v\|m2v\|m4v\|mkv\|wmv\|asf\|mov\|ogg\|svi\|flv\|swf\|dat\)$"
FILES_TO_KEEP=".*\(log\|conf\|srt\|avi\|mp4\|mpeg\|m1v\|m2v\|m4v\|mkv\|wmv\|asf\|mov\|ogg\|svi\|flv\|swf\|dat\)$"
EXTENSIONS_TO_REMOVE="s/\.(sfv|nfo|diz|r[ar0-9]+|z[ip0-9]+|7[z0-9]+|tgz|gz|avi|mp4|mpeg|m1v|m2v|m4v|mkv|wmv|asf|mov|ogg|svi|flv|swf|dat)$//"

# Regular Expressions to use with the 'sed' command
NORMALIZE_DIR_VIDEO_FORMATS="(avi|mp4|mpeg|m1v|m2v|m4v|mkv|wmv|asf|mov|ogg|svi|flv|swf|dat)$"
NORMALIZE_DIR_VIDEO_QUALITY="(BDRip|BDRIP|bdrip|BluRay|BLURAY|bluray|HDRip|HDRIP|hdrip|DVDRip|DVDRIP|dvdrip|XViD|XviD|XVID|xvid|DivX|DIVX|divx|[^\w]*CAM[^\w]*|[^\w]*cam[^\w]*|[^\w]*TS[^\w]*|[^\w]*ts[^\w]*|[^\w]*TC[^\w]*|[^\w]*tc[^\w]*|[^\w]*Scr[^\w]*|[^\w]*SCR[^\w]*|DVDScr|DVDSCR|R5|TVRip|TVRIP|tvrip|WEBRip|WEBRIP|webrip|PROPER|REPACK|720p|1080p|HD|SD|DVD|TV|NoTV|HDTV|x264|H264)"
NORMALIZE_DIR_SOUNDTRACK="(Dual|DUAL|dual|LINE|Dts|DTS|dts|Ac3|AC3|ac3|5.1|Sub[^\w]*|Subs[^\w]*|ESP|esp|ENG|eng|Spanish|SPANISH|spanish|English|ENGLISH|english|Spa-Eng|Ingl[eé]s|INGL[EÉ]S|ingl[eé]s|Espa[ñn]ol|ESPA[Ñn]OL|espa[ñn]ol)"
NORMALIZE_DIR_OTHERS="(CD1|cd1|CD2|cd2)$"
NORMALIZE_DIR_GROUPS="(LOL|lol|EVOLVE|evolve|DiMENSION|DIMENSION|dimension|ASAP|asap|GrupoHDS|GECKOS|2HD|2hd|KiLLERS|KILLERS|killers|EXCELLENCE|excellence|FOV|fov|HDiTunes|FQM|fqm|HDiT|HDiTunes|FEVER|fever|INMERSE|inmerse)"

SHOWCODE_PATTERN1="^[Ss]{1}[0-9]{1,2}[Ee]{1}[0-9]{1,2}$"
SHOWCODE_PATTERN2="^[0-9]{1,2}[Xx][0-9]{1,2}$"
SHOWCODE_PATTERN3="^[0-9]{3}$"

SourcePath="SourcePath"
DestinationPath="DestinationPath"


case "$2" in
  "$CLI_RefreshSubtitles") RefreshSubtitles=$STATUS_ON ;;
  "$CLI_NoSync")           NoSync=$STATUS_ON           ;;
esac

case "$3" in
  "$CLI_RefreshSubtitles") RefreshSubtitles=$STATUS_ON ;;
  "$CLI_NoSync")           NoSync=$STATUS_ON           ;;
esac


function BuildExclusionSettings {
  if [ -f "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques" ] ; then
    # let's exclude file types we always want to exclude

    echo "--exclude \"^_.*$|^.*\\.nfo$|^.*\\.diz$|^.*\\.lnk$|^.*\\.db$|^.*watchdir_rtorrent$\""          >> "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.conf"

    # let's build the lftp exclusion settings file. Characters that also happen to be elementso of RegEx syntax must be escaped.

    sed -r "s/\./\\\./g"    "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques"    >> "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques0"
    sed -r "s/\[/\\\[/g"    "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques0"   >> "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques1"
    sed -r "s/\]/\\\]/g"    "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques1"   >> "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques2"
    sed -r "s/\(/\\\(/g"    "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques2"   >> "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques3"
    sed -r "s/\)/\\\)/g"    "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques3"   >> "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques4"
    sed -r "s/\{/\\\{/g"    "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques4"   >> "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques5"
    sed -r "s/\}/\\\}/g"    "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques5"   >> "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques6"
    sed -r "s/\|/\\\|/g"    "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques6"   >> "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques7"
    sed -r "s/\^/\\\^/g"    "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques7"   >> "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques8"
    sed -r "s/\\\$/\\\\$/g" "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques8"   >> "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques9"
    sed -r "s/\+/\\\+/g"    "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques9"   >> "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques10"

    mv "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques10" "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.patterns"
    rm -f "$SourcePath/$WORKAREA/$ConfigurationProfile"/*.uniques[0-9]

    cat "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.patterns" | awk '{ print "--exclude \"^.*" $0 ".*$\"" }' >> "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.conf0"
    cat "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.conf0"    | tr "\n" " "                                  >> "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.conf"
    rm -f "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.conf0"
  fi
}


function NormalizeParentDir () {
  ParentDir=`echo "$1"         | sed -r "s/\./ /g"`

  ParentDir=`echo "$ParentDir" | sed -r "s/$NORMALIZE_DIR_VIDEO_FORMATS//g"`
  ParentDir=`echo "$ParentDir" | sed -r "s/$NORMALIZE_DIR_GROUPS//g"`
  ParentDir=`echo "$ParentDir" | sed -r "s/$NORMALIZE_DIR_OTHERS//g"`
  ParentDir=`echo "$ParentDir" | sed -r "s/$NORMALIZE_DIR_SOUNDTRACK//g"`
  ParentDir=`echo "$ParentDir" | sed -r "s/$NORMALIZE_DIR_VIDEO_QUALITY//g"`

  ParentDir=`echo "$ParentDir" | sed -r "s/\{(.*)\}//g"`
  ParentDir=`echo "$ParentDir" | sed -r "s/\[(.*)\]//g"`
  ParentDir=`echo "$ParentDir" | sed -r "s/\^(.*)\^//g"`
  ParentDir=`echo "$ParentDir" | sed -r "s/-(.*)-//g"`
  ParentDir=`echo "$ParentDir" | sed -r "s/\+(.*)\+//g"`
  ParentDir=`echo "$ParentDir" | sed -r "s/\[//g"`
  ParentDir=`echo "$ParentDir" | sed -r "s/\]//g"`
  ParentDir=`echo "$ParentDir" | sed -r "s/\{//g"`
  ParentDir=`echo "$ParentDir" | sed -r "s/\}//g"`
  ParentDir=`echo "$ParentDir" | sed -r "s/\|//g"`
  ParentDir=`echo "$ParentDir" | sed -r "s/\^//g"`
  ParentDir=`echo "$ParentDir" | sed -r "s/\\\$//g"`
  ParentDir=`echo "$ParentDir" | sed -r "s/\+//g"`
  ParentDir=`echo "$ParentDir" | sed -r "s/_//g"`
  ParentDir=`echo "$ParentDir" | sed -r "s/[ ]+/ /g"`

  echo "$ParentDir"
}


echo
echo "-------------------------------------------------------------------------------------------"
echo "Import-NewMedia                                                                            "
echo "Carlos Veira Lorenzo - [http://thinkinbig.org]                                             "
echo "-------------------------------------------------------------------------------------------"
echo "Import-NewMedia v0.1b, Copyright (C) 2014 Carlos Veira Lorenzo.                            "
echo "This software come with ABSOLUTELY NO WARRANTY. This is free                               "
echo "software under GPL 2.0 license terms and conditions.                                       "
echo "-------------------------------------------------------------------------------------------"
echo

if [ ! -f $InstallDir/"import-newmedia-$ConfigurationProfile.conf" ] ; then
  echo "+ ERROR: Can't find a Configuration Profile named $ConfigurationProfile"
  exit 1
fi

echo "+ Loading configuration ..."
echo

mkfifo $TmpDir/pipe-ImportMedia-$CurrentSessionId
cat $InstallDir/"import-newmedia-$ConfigurationProfile.conf" | grep -v "#" | grep . > $TmpDir/pipe-ImportMedia-$CurrentSessionId &

while read ConfigurationItem ; do
  PropertyName=`echo $ConfigurationItem    | awk -F "=" '{ print $1 }'`
  PropertyValue=`echo "$ConfigurationItem" | awk -F "=" '{ print $2 }'`

  if [ $PropertyName == $SourcePath        ] ; then SourcePath="$PropertyValue"      ; fi
  if [ $PropertyName == $DestinationPath   ] ; then DestinationPath="$PropertyValue" ; fi
done < $TmpDir/pipe-ImportMedia-$CurrentSessionId
rm -f $TmpDir/pipe-ImportMedia-$CurrentSessionId


if [ ! -d "$SourcePath/$WORKAREA/$ConfigurationProfile/logs" ]; then
  mkdir -p "$SourcePath/$WORKAREA/$ConfigurationProfile/logs"
fi


echo "=============================================================================================="   | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
echo $(date '+%Y/%m/%d %k:%M:%S')                                                                       | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
echo "----------------------------------------------------------------------------------------------"   | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
echo


if [ "$NoSync" == "$STATUS_OFF" ]; then
  echo "+ Saving previous state ..."                                                     | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"

  if [ -f "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.raw" ] ; then
    echo "  + Saving last list of RAW elements to exclude from future transfers ..."     | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"

    mv "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.raw" "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.raw.$CurrentSessionId"
  fi

  if [ -f "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-ForceResync.raw" ] ; then
    echo "  + Saving last list of RAW elements that failed last time ..."                | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"

    mv "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-ForceResync.raw" "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-ForceResync.raw.$CurrentSessionId"
  fi

  if [ -f "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques" ] ; then
    echo "  + Saving last list of unique elements to exclude from future transfers ..."  | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"

    mv "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques" "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques.$CurrentSessionId"
  fi

  if [ -f "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.patterns" ] ; then
    echo "  + Saving last list of patterns to exclude from future transfers ..."         | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"

    mv "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.patterns" "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.patterns.$CurrentSessionId"
  fi


  if [ -f "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.conf" ] ; then
    echo "  + Saving last exclusion settings ..."                                        | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"

    mv "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.conf" "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.conf.$CurrentSessionId"
  fi

  echo                                                                                                         | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
  echo "==================================================================================================="   | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
  echo                                                                                                         | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
  echo "+ Excluding transfered files from future downloads ..."                                                | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"

  find "$SourcePath"/ -depth -type f -print | grep -v "$WORKAREA/$ConfigurationProfile" | sort      >> "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.raw"

  echo "  + Updating the list of unique elements to exclude ..."                         | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"

  # extract the filename (last item), remove extentions and get the unique elements
  cat "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.raw"      | awk -F "/" '{ print $NF }'  | sed -r "$EXTENSIONS_TO_REMOVE" >> "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques0"
  cat "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques0" | sort -u                                                      >> "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques"

  rm -f "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques0"

  # let's include the last list of unique items in the new exclusion list
  if [ -f "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques.$CurrentSessionId" ] && [ -f "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques" ]; then
    cat "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques.$CurrentSessionId" >> "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques0"
    cat "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques"                   >> "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques0"

    cat "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques0" | sort -u        >> "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques"
    rm -f "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques0"
  fi

  echo "  + Generating new exclusion settings ..."

  BuildExclusionSettings
fi


echo                                                                                                         | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
echo "==================================================================================================="   | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
echo                                                                                                         | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
echo "+ Decompressing files ..."                                                                             | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
echo                                                                                                         | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"

mkfifo $TmpDir/pipe-ImportMedia-$CurrentSessionId
find "$SourcePath/" -depth -type f -size +10000k -regex "$ARCHIVE_FORMATS" -print > $TmpDir/pipe-ImportMedia-$CurrentSessionId &
while read FullPath ; do
  FileName=`echo "$FullPath" | tr "/" "\n" | grep -v "^$" | tail -1`
  FilePath=`dirname "$FullPath"`

  CurrentPath="$PWD"
  cd "$FilePath"

  echo                                                                                                       | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
  echo "  -------------------------------------------------------------------------------------------------" | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
  echo                                                                                                       | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
  echo "  + Processing File: $FullPath"                                                                      | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
  echo                                                                                                       | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"

  7z x -y "$FileName"                                                                  | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"

  if [ $? -eq $STATUS_OK ] ; then
    echo                                                                               | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
    echo "  + SUCCESS: Decompression finisehd correctly."                              | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
    echo "    + FullPath: $FullPath"                                                   | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
    echo "    + Cleaning unneeded files ..."                                           | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
    echo                                                                               | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"

    find "$FilePath"/ -type f \( ! -regex $FILES_TO_KEEP \) -print -exec rm -f '{}' \; | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
  else
    echo                                                                               | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
    echo "  + ERROR: Decompression failed."                                            | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
    echo "    + FullPath: $FullPath"                                                   | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
    echo                                                                               | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"

    if [ "$NoSync" == "$STATUS_OFF" ]; then
      echo "$FullPath" >> "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-ForceResync.raw"
    fi
  fi

  cd "$CurrentPath"
done < $TmpDir/pipe-ImportMedia-$CurrentSessionId
rm -f $TmpDir/pipe-ImportMedia-$CurrentSessionId


if [ "$NoSync" == "$STATUS_OFF" ]; then
  if [ -f "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-ForceResync.raw" ] && [ -f "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques" ]; then
    echo "  + Removing failed items from exclusion settings ..."                       | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
    echo "    + Updating NoReSync file"                                                | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"

    # extract the filename (last item), remove extentions and get the unique elements that have failed.
    cat "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-ForceResync.raw"      | awk -F "/" '{ print $NF }' | sed -r "$EXTENSIONS_TO_REMOVE" >> "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-ForceResync.uniques0"
    cat "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-ForceResync.uniques0" | sort -u                                                     >> "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-ForceResync.uniques"

    rm -f "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-ForceResync.uniques0"
    mv    "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-ForceResync.raw" "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-ForceResync.raw.$CurrentSessionId"

    # Getting a unique exclusion list
    mv      "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques" "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques0"
    grep -f "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-ForceResync.uniques" -v "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques0"    >> "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques"
    rm -f   "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques0"

    echo "    + Generating new exclusion settings ..."                                 | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
    echo                                                                               | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"

    BuildExclusionSettings
  fi
fi


if [ "$SourcePath" != "$DestinationPath" ]; then
  echo                                                                                                         | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
  echo "==================================================================================================="   | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
  echo                                                                                                         | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
  echo "+ Moving files to their target destinations ..."                                                       | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
  echo                                                                                                         | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"

  SourceParentDir=`echo "$SourcePath" | tr "/" "\n" | grep -v "^$" | tail -1`

  mkfifo $TmpDir/pipe-ImportMedia-$CurrentSessionId
  find "$SourcePath/" -depth -type f -regex "$VIDEO_FORMATS" -print > $TmpDir/pipe-ImportMedia-$CurrentSessionId &
  while read FullPath ; do
    ShowCodeNotFound=false

    FileName=`echo "$FullPath" | tr "/" "\n" | grep -v "^$" | tail -1`
    FilePath=`dirname "$FullPath"`

    ChapterName=`echo "$FilePath" | tr "/" "\n" | grep -v "^$" | tail -1`
    ShowCode=`echo $ChapterName | tr "." "\n" | grep -v "^$" | grep -E $SHOWCODE_PATTERN1`

    if [ "$ShowCode" == "" ]; then
      ShowCode=`echo $ChapterName | tr "." "\n" | grep -v "^$" | grep -E $SHOWCODE_PATTERN2`

      if [ "$ShowCode" == "" ]; then
        ShowCode=`echo $ChapterName | tr "." "\n" | grep -v "^$" | grep -E $SHOWCODE_PATTERN3`

        if [ "$ShowCode" == "" ]; then
          ShowCodeNotFound=true
        else
          SeasonId=${ShowCode:0:1}
        fi
      else
        SeasonId=`echo $ShowCode | tr "X|x" "\n" | head -1`
      fi
    else
      SeasonId=`echo $ShowCode | tr "E|e" "\n" | head -1`

      if [ "${SeasonId:0:1}" == "S" ] || [ "${SeasonId:0:1}" == "s" ]; then
        SeasonId=${SeasonId:1:2}
      fi
    fi


    if [ "$ShowCodeNotFound" == true ]; then
      FileSize=`wc -c "$FullPath" | cut --delimiter=" " -f1`

      if [ "$FileSize" -gt "$SIZE_1GB" ]; then
        echo                                                                                               | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
        echo "  + INFO: MOVIE detected."                                                                   | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
        echo "  +   File:        $FullPath"                                                                | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"

        if [ "$ChapterName" == "$SourceParentDir" ]; then
          ParentDir=`NormalizeParentDir "$FileName"`

          echo "  +   Destination: $DestinationPath/$MOVIES_FOLDER/$ParentDir/$FileName"                   | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
          echo                                                                                             | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"

          mkdir -p "$DestinationPath/$MOVIES_FOLDER/$ParentDir"
          mv -f "$FullPath" "$DestinationPath/$MOVIES_FOLDER/$ParentDir/$FileName"
        else
          echo "  +   Destination: $DestinationPath/$MOVIES_FOLDER/$ChapterName/$FileName"                 | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
          echo                                                                                             | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"

          mkdir -p "$DestinationPath/$MOVIES_FOLDER/$ChapterName"
          mv -f "$FullPath" "$DestinationPath/$MOVIES_FOLDER/$ChapterName/$FileName"
        fi
      else
        echo                                                                                               | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
        echo "  + WARNING: UNKNOWN MEDIA TYPE detected."                                                   | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
        echo "  +   File:        $FullPath"                                                                | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
        echo "  +   Destination: $DestinationPath/$UNKNOWN_FOLDER/$ChapterName/$FileName"                  | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
        echo                                                                                               | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"

        mkdir -p "$DestinationPath/$UNKNOWN_FOLDER/$ChapterName/$FileName"
        mv -f "$FullPath" "$DestinationPath/$UNKNOWN_FOLDER/$ChapterName/$FileName"
      fi
    else
      ShowName=`echo $ChapterName | sed "s/$ShowCode/\n/g" | head -1 | tr "." " " | sed "s/ *$//"`

      echo                                                                                                 | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
      echo "  + INFO: TV SHOW detected."                                                                   | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
      echo "  +   File:        $FullPath"                                                                  | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
      echo "  +   Destination: $DestinationPath/$TVSHOWS_FOLDER/$ShowName/Season $SeasonId/$FileName"      | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
      echo                                                                                                 | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"

      if [ -d "$DestinationPath/$TVSHOWS_FOLDER/$ShowName/" ]; then
        if [ -d "$DestinationPath/$TVSHOWS_FOLDER/$ShowName"/"Season $SeasonId/" ]; then
          mv -f "$FullPath" "$DestinationPath/$TVSHOWS_FOLDER/$ShowName"/"Season $SeasonId/$FileName"
        else
          mkdir -p "$DestinationPath/$TVSHOWS_FOLDER/$ShowName"/"Season $SeasonId"
          mv -f "$FullPath" "$DestinationPath/$TVSHOWS_FOLDER/$ShowName"/"Season $SeasonId/$FileName"
        fi
      else
        mkdir -p "$DestinationPath/$TVSHOWS_FOLDER/$ShowName"/"Season $SeasonId"
        mv -f "$FullPath" "$DestinationPath/$TVSHOWS_FOLDER/$ShowName"/"Season $SeasonId/$FileName"
      fi
    fi

  done < $TmpDir/pipe-ImportMedia-$CurrentSessionId
  rm -f $TmpDir/pipe-ImportMedia-$CurrentSessionId


  echo "  + Removing empty folders ..."                                                                    | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"

  find "$SourcePath/" -depth -type d -print | grep -v "$WORKAREA/$ConfigurationProfile" | grep -v "^$SourcePath/$" | sort -r | xargs rmdir 2> /dev/null
fi


echo                                                                                                         | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
echo "==================================================================================================="   | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
echo                                                                                                         | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
echo "+ Downloading subtitles ..."                                                                           | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
echo                                                                                                         | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"


mkfifo $TmpDir/pipe-ImportMedia-$CurrentSessionId
find "$DestinationPath/" -depth -type f -regex "$VIDEO_FORMATS" -print > $TmpDir/pipe-ImportMedia-$CurrentSessionId &
while read FullPath ; do
  FilePath=`dirname "$FullPath"`

  echo                                                                                                       | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
  echo "  -------------------------------------------------------------------------------------------------" | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
  echo                                                                                                       | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
  echo "  + Processing File: $FullPath"                                                                      | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
  echo                                                                                                       | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"

  # call 'ls' with full path to bypass any alias definition
  if [ -f  "$($BinDir/ls -1 "$FilePath"/*.srt 2> /dev/null | head -1)" ]; then
    if [ "$RefreshSubtitles" == "$STATUS_ON" ]; then
      subliminal -f -l en es -c $TmpDir/subliminal.cache.dbm "$FullPath"                                     | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"

      if [ $? -eq $STATUS_OK ] ; then
        echo                                                                                                 | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
        echo "  + SUCCESS: Subtitles downloaded correctly."                                                  | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
        echo "    + FullPath: $FullPath"                                                                     | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
      else
        echo                                                                                                 | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
        echo "  + ERROR: Subtitles download failed."                                                         | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
        echo "    + FullPath: $FullPath"                                                                     | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
      fi
    else
        echo                                                                                                 | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
        echo "  + SKIPPING: Subtitles already downloaded."                                                   | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
        echo                                                                                                 | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
    fi
  else
    subliminal -f -l en es -c $TmpDir/subliminal.cache.dbm "$FullPath"                                       | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"

    if [ $? -eq $STATUS_OK ] ; then
      echo                                                                                                   | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
      echo "  + SUCCESS: Subtitles downloaded correctly."                                                    | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
      echo "    + FullPath: $FullPath"                                                                       | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
    else
      echo                                                                                                   | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
      echo "  + ERROR: Subtitles download failed."                                                           | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
      echo "    + FullPath: $FullPath"                                                                       | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
    fi
  fi
done < $TmpDir/pipe-ImportMedia-$CurrentSessionId
rm -f $TmpDir/pipe-ImportMedia-$CurrentSessionId


echo
echo "----------------------------------------------------------------------------------------------"   | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
echo $(date '+%Y/%m/%d %k:%M:%S')                                                                       | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"
echo "=============================================================================================="   | tee -a "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log"


# Make one copy of the session log available to users
cp "$LogsDir/ImportNewMedia-$ConfigurationProfile-$CurrentSessionId.log" "$SourcePath/$WORKAREA/$ConfigurationProfile/logs" 2> /dev/null