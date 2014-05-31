#!/opt/bin/bash
# -------------------------------------------------------------------------------
# Name:         refresh-SyncFilesConfig.sh
# Description:  It updates the NoResync configuration file used by sync-files.sh
#               It is useful when you do manual updates to the last .uniques file
# Author:       Carlos Veira Lorenzo - cveira [at] thinkinbig.org
# Version:      0.3b
# Date:         2014/05/29
# -------------------------------------------------------------------------------
# Usage:        refresh-SyncFilesConfig.sh <ConfigProfileName>
# -------------------------------------------------------------------------------
# Dependencies: ls, cp, mv, rm, cat, awk, grep, sed, tr, tee, mkfifo
#               sync-files-<ConfigProfileName>.conf
# -------------------------------------------------------------------------------
# Notes:
#   Tested under Bash + BusyBox
#   Works under Synology NAS
# -------------------------------------------------------------------------------

export PATH=/opt/bin:/opt/sbin:/opt/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/usr/syno/sbin:/usr/syno/bin:/usr/local/sbin:/usr/local/bin

InstallDir=/volume1/jobs/scripts
LogsDir=/volume1/jobs/logs
TmpDir=/volume1/jobs/tmp

WORKAREA="_workarea"

OriginalDir="$PWD"
ConfigurationProfile="$1"

SourcePath="SourcePath"
DestinationPath="DestinationPath"

UserName="UserName"
Password="Password"
ConnectionSettingsName="ConnectionSettingsName"
RemotePath="RemotePath"
LocalPath="LocalPath"
TargetUrl="TargetUrl"
ParallelJobs="ParallelJobs"
ParallelChunksPerFile="ParallelChunksPerFile"
BandwidthRateLimit="BandwidthRateLimit"
TimeOut="TimeOut"
MaxRetries="MaxRetries"
ReconnectIntervalBase="ReconnectIntervalBase"
ReconnectIntervalMultiplier="ReconnectIntervalMultiplier"
ReconnectIntervalMax="ReconnectIntervalMax"
VerifyTransfer="VerifyTransfer"
VerifySslCertificate="VerifySslCertificate"
OnStart="OnStart"
OnCompletion="OnCompletion"

CurrentDate=$(date +%Y%m%d)
CurrentSequenceId=$(ls -1AB $LogsDir/*$CurrentDate* 2> /dev/null | wc -l)
CurrentSessionId="$CurrentDate-$CurrentSequenceId"


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


echo
echo "-------------------------------------------------------------------------------------------"
echo "Refresh-SyncFilesConfig                                                                    "
echo "Carlos Veira Lorenzo - [http://thinkinbig.org]                                             "
echo "-------------------------------------------------------------------------------------------"
echo "Sync-Files v0.3b, Copyright (C) 2014 Carlos Veira Lorenzo.                                 "
echo "This software come with ABSOLUTELY NO WARRANTY. This is free                               "
echo "software under GPL 2.0 license terms and conditions.                                       "
echo "-------------------------------------------------------------------------------------------"
echo

if [ ! -f $InstallDir/"import-newmedia-$ConfigurationProfile.conf" ] ; then
  echo "+ ERROR: Can't find a Configuration Profile named $ConfigurationProfile"
  exit 1
fi

if [ ! -f $InstallDir/"sync-files-$ConfigurationProfile.conf" ] ; then
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


echo "+ Saving previous state ..."                                                     | tee -a "$LogsDir/RefreshSyncFilesConfig-$ConfigurationProfile-$CurrentSessionId.log"

if [ -f "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.raw" ] ; then
	echo "  + Saving last list of RAW elements to exclude from future transfers ..."     | tee -a "$LogsDir/RefreshSyncFilesConfig-$ConfigurationProfile-$CurrentSessionId.log"

	cp "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.raw" "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.raw.$CurrentSessionId"
fi

if [ -f "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-ForceResync.raw" ] ; then
	echo "  + Saving last list of RAW elements that failed last time ..."                | tee -a "$LogsDir/RefreshSyncFilesConfig-$ConfigurationProfile-$CurrentSessionId.log"

	cp "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-ForceResync.raw" "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-ForceResync.raw.$CurrentSessionId"
fi

if [ -f "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques" ] ; then
	echo "  + Saving last list of unique elements to exclude from future transfers ..."  | tee -a "$LogsDir/RefreshSyncFilesConfig-$ConfigurationProfile-$CurrentSessionId.log"

	cp "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques" "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.uniques.$CurrentSessionId"
fi

if [ -f "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.patterns" ] ; then
	echo "  + Saving last list of patterns to exclude from future transfers ..."         | tee -a "$LogsDir/RefreshSyncFilesConfig-$ConfigurationProfile-$CurrentSessionId.log"

	mv "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.patterns" "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.patterns.$CurrentSessionId"
fi


if [ -f "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.conf" ] ; then
	echo "  + Saving last exclusion settings ..."                                        | tee -a "$LogsDir/RefreshSyncFilesConfig-$ConfigurationProfile-$CurrentSessionId.log"

	mv "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.conf" "$SourcePath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.conf.$CurrentSessionId"
fi

echo "  + Generating new exclusion settings ..."                                       | tee -a "$LogsDir/RefreshSyncFilesConfig-$ConfigurationProfile-$CurrentSessionId.log"

BuildExclusionSettings

# Make one copy of the session log available to users
cp "$LogsDir/RefreshSyncFilesConfig-$ConfigurationProfile-$CurrentSessionId.log" "$LocalPath/$WORKAREA/$ConfigurationProfile/logs" 2> /dev/null