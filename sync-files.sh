#!/opt/bin/bash
# -------------------------------------------------------------------------------
# Name:         sync-files.sh
# Description:  Synchronizes files and folders via lftp
# Author:       Carlos Veira Lorenzo - cveira [at] thinkinbig.org
# Version:      0.3b
# Date:         2014/05/29
# -------------------------------------------------------------------------------
# Usage:        sync-files.sh <ConfigProfileName> [-ForceSync]
# -------------------------------------------------------------------------------
# Dependencies: ls, cp, mv, rm, cat, awk, grep, sed, tr, lftp, 7z, tee, mkfifo
#               sync-files-<ConfigProfileName>.conf
#               sync-files-<ConfigProfileName>-OnCompletion.sh
#               lftp-<ConfigProfileName>.conf
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
InitMode="-ForceSync"

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

echo
echo "-------------------------------------------------------------------------------------------"
echo "Sync-Files                                                                                 "
echo "Carlos Veira Lorenzo - [http://thinkinbig.org]                                             "
echo "-------------------------------------------------------------------------------------------"
echo "Sync-Files v0.3b, Copyright (C) 2014 Carlos Veira Lorenzo.                                 "
echo "This software come with ABSOLUTELY NO WARRANTY. This is free                               "
echo "software under GPL 2.0 license terms and conditions.                                       "
echo "-------------------------------------------------------------------------------------------"
echo


if [ ! -f $InstallDir/"sync-files-$ConfigurationProfile.conf" ] ; then
  echo "+ ERROR: Can't find a Configuration Profile named $ConfigurationProfile"
  exit 1
fi

echo "+ Loading configuration ..."
echo

mkfifo $TmpDir/pipe-SyncFiles-$CurrentSessionId
cat $InstallDir/"sync-files-$ConfigurationProfile.conf" | grep -v "#" | grep . > $TmpDir/pipe-SyncFiles-$CurrentSessionId &

while read ConfigurationItem ; do
  PropertyName=`echo $ConfigurationItem    | awk -F "=" '{ print $1 }'`
  PropertyValue=`echo "$ConfigurationItem" | awk -F "=" '{ print $2 }'`

  if [ $PropertyName == $UserName                    ] ; then UserName="$PropertyValue"                    ; fi
  if [ $PropertyName == $Password                    ] ; then Password="$PropertyValue"                    ; fi
  if [ $PropertyName == $ConnectionSettingsName      ] ; then ConnectionSettingsName="$PropertyValue"      ; fi
  if [ $PropertyName == $RemotePath                  ] ; then RemotePath="$PropertyValue"                  ; fi
  if [ $PropertyName == $LocalPath                   ] ; then LocalPath="$PropertyValue"                   ; fi
  if [ $PropertyName == $TargetUrl                   ] ; then TargetUrl="$PropertyValue"                   ; fi
  if [ $PropertyName == $ParallelJobs                ] ; then ParallelJobs="$PropertyValue"                ; fi
  if [ $PropertyName == $ParallelChunksPerFile       ] ; then ParallelChunksPerFile="$PropertyValue"       ; fi
  if [ $PropertyName == $BandwidthRateLimit          ] ; then BandwidthRateLimit="$PropertyValue"          ; fi
  if [ $PropertyName == $TimeOut                     ] ; then TimeOut="$PropertyValue"                     ; fi
  if [ $PropertyName == $MaxRetries                  ] ; then MaxRetries="$PropertyValue"                  ; fi
  if [ $PropertyName == $ReconnectIntervalBase       ] ; then ReconnectIntervalBase="$PropertyValue"       ; fi
  if [ $PropertyName == $ReconnectIntervalMultiplier ] ; then ReconnectIntervalMultiplier="$PropertyValue" ; fi
  if [ $PropertyName == $ReconnectIntervalMax        ] ; then ReconnectIntervalMax="$PropertyValue"        ; fi
  if [ $PropertyName == $VerifyTransfer              ] ; then VerifyTransfer="$PropertyValue"              ; fi
  if [ $PropertyName == $VerifySslCertificate        ] ; then VerifySslCertificate="$PropertyValue"        ; fi
  if [ $PropertyName == $OnStart                     ] ; then OnStart="$PropertyValue"                     ; fi
  if [ $PropertyName == $OnCompletion                ] ; then OnCompletion="$PropertyValue"                ; fi
done < $TmpDir/pipe-SyncFiles-$CurrentSessionId
rm -f $TmpDir/pipe-SyncFiles-$CurrentSessionId

if [ "$2" == "$InitMode" ] ; then
  ConnectionSettingsName="${ConnectionSettingsName}Init"
fi

if [ ! -f $InstallDir/"lftp-$ConnectionSettingsName.conf" ] ; then
  echo "+ ERROR: Can't find an lftp settings file named lftp-$ConnectionSettingsName.conf"
  exit 1
fi


cp $InstallDir/"lftp-$ConnectionSettingsName.conf" $TmpDir/"lftp-$ConnectionSettingsName-$CurrentSessionId.conf"

EscapedInstallDir=$(echo "$InstallDir" | sed 's/\//\\\//g')
EscapedLogsDir=$(echo "$LogsDir" | sed 's/\//\\\//g')
EscapedRemotePath=$(echo "$RemotePath" | sed 's/\//\\\//g')
EscapedLocalPath=$(echo "$LocalPath" | sed 's/\//\\\//g')
EscapedTargetUrl=$(echo "$TargetUrl" | sed 's/\//\\\//g')

sed -i "s/{InstallDir}/$EscapedInstallDir/g"                            $TmpDir/"lftp-$ConnectionSettingsName-$CurrentSessionId.conf"
sed -i "s/{LogsDir}/$EscapedLogsDir/g"                                  $TmpDir/"lftp-$ConnectionSettingsName-$CurrentSessionId.conf"
sed -i "s/{SessionId}/$CurrentSessionId/g"                              $TmpDir/"lftp-$ConnectionSettingsName-$CurrentSessionId.conf"
sed -i "s/{ConfigurationProfile}/$ConfigurationProfile/g"               $TmpDir/"lftp-$ConnectionSettingsName-$CurrentSessionId.conf"

sed -i "s/{RemotePath}/$EscapedRemotePath/g"                            $TmpDir/"lftp-$ConnectionSettingsName-$CurrentSessionId.conf"
sed -i "s/{LocalPath}/$EscapedLocalPath/g"                              $TmpDir/"lftp-$ConnectionSettingsName-$CurrentSessionId.conf"

sed -i "s/{ParallelJobs}/$ParallelJobs/g"                               $TmpDir/"lftp-$ConnectionSettingsName-$CurrentSessionId.conf"
sed -i "s/{ParallelChunksPerFile}/$ParallelChunksPerFile/g"             $TmpDir/"lftp-$ConnectionSettingsName-$CurrentSessionId.conf"
sed -i "s/{BandwidthRateLimit}/$BandwidthRateLimit/g"                   $TmpDir/"lftp-$ConnectionSettingsName-$CurrentSessionId.conf"
sed -i "s/{TimeOut}/$TimeOut/g"                                         $TmpDir/"lftp-$ConnectionSettingsName-$CurrentSessionId.conf"
sed -i "s/{MaxRetries}/$MaxRetries/g"                                   $TmpDir/"lftp-$ConnectionSettingsName-$CurrentSessionId.conf"
sed -i "s/{ReconnectIntervalBase}/$ReconnectIntervalBase/g"             $TmpDir/"lftp-$ConnectionSettingsName-$CurrentSessionId.conf"
sed -i "s/{ReconnectIntervalMultiplier}/$ReconnectIntervalMultiplier/g" $TmpDir/"lftp-$ConnectionSettingsName-$CurrentSessionId.conf"
sed -i "s/{ReconnectIntervalMax}/$ReconnectIntervalMax/g"               $TmpDir/"lftp-$ConnectionSettingsName-$CurrentSessionId.conf"
sed -i "s/{VerifyTransfer}/$VerifyTransfer/g"                           $TmpDir/"lftp-$ConnectionSettingsName-$CurrentSessionId.conf"
sed -i "s/{VerifySslCertificate}/$VerifySslCertificate/g"               $TmpDir/"lftp-$ConnectionSettingsName-$CurrentSessionId.conf"

sed -i "s/{UserName}/$UserName/g"                                       $TmpDir/"lftp-$ConnectionSettingsName-$CurrentSessionId.conf"
sed -i "s/{Password}/$Password/g"                                       $TmpDir/"lftp-$ConnectionSettingsName-$CurrentSessionId.conf"
sed -i "s/{TargetUrl}/$EscapedTargetUrl/g"                              $TmpDir/"lftp-$ConnectionSettingsName-$CurrentSessionId.conf"


echo "+ Execution parameters:"                                                                              | tee -a "$LogsDir/SyncFiles-$ConfigurationProfile-$CurrentSessionId.log"
echo "  + UserName:                    $UserName"                                                           | tee -a "$LogsDir/SyncFiles-$ConfigurationProfile-$CurrentSessionId.log"
echo "  + TargetUrl:                   $TargetUrl"                                                          | tee -a "$LogsDir/SyncFiles-$ConfigurationProfile-$CurrentSessionId.log"
echo "  + RemotePath:                  $RemotePath"                                                         | tee -a "$LogsDir/SyncFiles-$ConfigurationProfile-$CurrentSessionId.log"
echo "  + LocalPath:                   $LocalPath"                                                          | tee -a "$LogsDir/SyncFiles-$ConfigurationProfile-$CurrentSessionId.log"
echo "  + MainLogFile:                 $LogsDir/SyncFiles-$ConfigurationProfile-$CurrentSessionId.log"      | tee -a "$LogsDir/SyncFiles-$ConfigurationProfile-$CurrentSessionId.log"
echo "  + LftpLogFile:                 $LogsDir/SyncFiles-$ConfigurationProfile-$CurrentSessionId-lftp.log" | tee -a "$LogsDir/SyncFiles-$ConfigurationProfile-$CurrentSessionId.log"
echo "  + ConnectionSettingsFile:      $TmpDir/lftp-$ConnectionSettingsName-$CurrentSessionId.conf"         | tee -a "$LogsDir/SyncFiles-$ConfigurationProfile-$CurrentSessionId.log"
echo "  + ParallelJobs:                $ParallelJobs"                                                       | tee -a "$LogsDir/SyncFiles-$ConfigurationProfile-$CurrentSessionId.log"
echo "  + ParallelChunksPerFile:       $ParallelChunksPerFile"                                              | tee -a "$LogsDir/SyncFiles-$ConfigurationProfile-$CurrentSessionId.log"
echo "  + BandwidthRateLimit:          $BandwidthRateLimit"                                                 | tee -a "$LogsDir/SyncFiles-$ConfigurationProfile-$CurrentSessionId.log"
echo "  + TimeOut:                     $TimeOut"                                                            | tee -a "$LogsDir/SyncFiles-$ConfigurationProfile-$CurrentSessionId.log"
echo "  + MaxRetries:                  $MaxRetries"                                                         | tee -a "$LogsDir/SyncFiles-$ConfigurationProfile-$CurrentSessionId.log"
echo "  + ReconnectIntervalBase:       $ReconnectIntervalBase"                                              | tee -a "$LogsDir/SyncFiles-$ConfigurationProfile-$CurrentSessionId.log"
echo "  + ReconnectIntervalMultiplier: $ReconnectIntervalMultiplier"                                        | tee -a "$LogsDir/SyncFiles-$ConfigurationProfile-$CurrentSessionId.log"
echo "  + ReconnectIntervalMax:        $ReconnectIntervalMax"                                               | tee -a "$LogsDir/SyncFiles-$ConfigurationProfile-$CurrentSessionId.log"
echo "  + VerifyTransfer:              $VerifyTransfer"                                                     | tee -a "$LogsDir/SyncFiles-$ConfigurationProfile-$CurrentSessionId.log"
echo "  + VerifySslCertificate:        $VerifySslCertificate"                                               | tee -a "$LogsDir/SyncFiles-$ConfigurationProfile-$CurrentSessionId.log"
echo "  + OnStart:                     $OnStart"                                                            | tee -a "$LogsDir/SyncFiles-$ConfigurationProfile-$CurrentSessionId.log"
echo "  + OnCompletion:                $OnCompletion"                                                       | tee -a "$LogsDir/SyncFiles-$ConfigurationProfile-$CurrentSessionId.log"
echo                                                                                                        | tee -a "$LogsDir/SyncFiles-$ConfigurationProfile-$CurrentSessionId.log"


if [ ! -d "$LocalPath/$WORKAREA/$ConfigurationProfile/logs" ]; then
  mkdir -p "$LocalPath/$WORKAREA/$ConfigurationProfile/logs"
fi


# let's include the exclusion list into the configuration

if [ -f "$LocalPath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.conf" ]; then
  ExclusionList=`cat "$LocalPath/$WORKAREA/$ConfigurationProfile/sync-files-NoReSync.conf" | tr "\n" " "`
  sed -i "s/{ExclusionList}/$ExclusionList/g" $TmpDir/"lftp-$ConnectionSettingsName-$CurrentSessionId.conf"
else
  echo "+ WARNING: No exclusion list found. Every file on the remote server will be synchronized!"          | tee -a "$LogsDir/SyncFiles-$ConfigurationProfile-$CurrentSessionId.log"
  echo                                                                                                      | tee -a "$LogsDir/SyncFiles-$ConfigurationProfile-$CurrentSessionId.log"

  sed -i "s/{ExclusionList}//g"               $TmpDir/"lftp-$ConnectionSettingsName-$CurrentSessionId.conf"
fi


cd "$LocalPath"

echo "=============================================================================================="   | tee -a "$LogsDir/SyncFiles-$ConfigurationProfile-$CurrentSessionId.log"
echo $(date '+%Y/%m/%d %k:%M:%S')                                                                       | tee -a "$LogsDir/SyncFiles-$ConfigurationProfile-$CurrentSessionId.log"
echo "----------------------------------------------------------------------------------------------"   | tee -a "$LogsDir/SyncFiles-$ConfigurationProfile-$CurrentSessionId.log"
echo

if [ ! "$OnStart" == "OnStart" ] ; then
  echo "OnStart Tasks"                                                                                  | tee -a "$LogsDir/SyncFiles-$ConfigurationProfile-$CurrentSessionId.log"
  echo "----------------------------------------------------------------------------------------------" | tee -a "$LogsDir/SyncFiles-$ConfigurationProfile-$CurrentSessionId.log"
  echo

  $OnStart                                                                                              | tee -a "$LogsDir/SyncFiles-$ConfigurationProfile-$CurrentSessionId.log"

  echo "----------------------------------------------------------------------------------------------" | tee -a "$LogsDir/SyncFiles-$ConfigurationProfile-$CurrentSessionId.log"
  echo                                                                                                  | tee -a "$LogsDir/SyncFiles-$ConfigurationProfile-$CurrentSessionId.log"
fi


lftp -f $TmpDir/"lftp-$ConnectionSettingsName-$CurrentSessionId.conf"                                   | tee -a "$LogsDir/SyncFiles-$ConfigurationProfile-$CurrentSessionId.log"

rm -rf $TmpDir/"lftp-$ConnectionSettingsName-$CurrentSessionId.conf" > /dev/null


if [ ! "$OnCompletion" == "OnCompletion" ] ; then
  echo                                                                                                  | tee -a "$LogsDir/SyncFiles-$ConfigurationProfile-$CurrentSessionId.log"
  echo "----------------------------------------------------------------------------------------------" | tee -a "$LogsDir/SyncFiles-$ConfigurationProfile-$CurrentSessionId.log"
  echo "OnCompletion Tasks"                                                                             | tee -a "$LogsDir/SyncFiles-$ConfigurationProfile-$CurrentSessionId.log"
  echo "----------------------------------------------------------------------------------------------" | tee -a "$LogsDir/SyncFiles-$ConfigurationProfile-$CurrentSessionId.log"
  echo                                                                                                  | tee -a "$LogsDir/SyncFiles-$ConfigurationProfile-$CurrentSessionId.log"

  $OnCompletion                                                                                         | tee -a "$LogsDir/SyncFiles-$ConfigurationProfile-$CurrentSessionId.log"
fi

echo
echo "----------------------------------------------------------------------------------------------"   | tee -a "$LogsDir/SyncFiles-$ConfigurationProfile-$CurrentSessionId.log"
echo $(date '+%Y/%m/%d %k:%M:%S')                                                                       | tee -a "$LogsDir/SyncFiles-$ConfigurationProfile-$CurrentSessionId.log"
echo "=============================================================================================="   | tee -a "$LogsDir/SyncFiles-$ConfigurationProfile-$CurrentSessionId.log"


# Make one copy of the session log available to users
cp "$LogsDir/SyncFiles-$ConfigurationProfile-$CurrentSessionId.log" "$LocalPath/$WORKAREA/$ConfigurationProfile/logs" 2> /dev/null

cd "$OriginalDir"