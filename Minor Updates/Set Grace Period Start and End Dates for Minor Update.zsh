#!/bin/zsh

# Title         :Set Grace Period Start and End Dates for Minor Update.zsh
# Description   :Sets the future date after which user flexibility for OS updates will close
# Author        :John Hutchison
# Date          :2021-07-22
# Contact       :john@randm.ltd, john.hutchison@floatingorchard.com
# Version       :1.2.1.2
# Notes         :Added absolute deadline logic

# The Clear BSD License
#
# Copyright (c) [2020] [John Hutchison of Russell & Manifold ltd.]
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted (subject to the limitations in the disclaimer
# below) provided that the following conditions are met:
#
#      * Redistributions of source code must retain the above copyright notice,
#      this list of conditions and the following disclaimer.
#
#      * Redistributions in binary form must reproduce the above copyright
#      notice, this list of conditions and the following disclaimer in the
#      documentation and/or other materials provided with the distribution.
#
#      * Neither the name of the copyright holder nor the names of its
#      contributors may be used to endorse or promote products derived from this
#      software without specific prior written permission.
#
# NO EXPRESS OR IMPLIED LICENSES TO ANY PARTY'S PATENT RIGHTS ARE GRANTED BY
# THIS LICENSE. THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
# CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
# PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
# BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
# IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

plistBuddy="/usr/libexec/PlistBuddy"
preferenceDomain=$4 # Required
macOSSoftwareUpdateGracePeriodinDays=$5 # Required
macOSSoftwareUpdateAbsoluteDeadlineAfterGracePeriodinDays=$6 # Optional
dateMacBecameAwareOfUpdates="$(/bin/date "+%F")"
dateMacBecameAwareOfUpdatesNationalRepresentation="$(/bin/date "+%A, %B %e")"
dateMacBecameAwareOfUpdatesSeconds="$(/bin/date +%s)"
gracePeriodWindowClosureDate="$(/bin/date -v +"$macOSSoftwareUpdateGracePeriodinDays"d "+%Y-%m-%d")"
gracePeriodWindowClosureDateNationalRepresentation="$(/bin/date -v +"$macOSSoftwareUpdateGracePeriodinDays"d "+%A, %B %e")"
softwareUpdatePreferenceFile="/Library/Preferences/$preferenceDomain.SoftwareUpdatePreferences.plist"
softwareUpdatePreferenceFileVersion="2"

if [[ "$macOSSoftwareUpdateAbsoluteDeadlineAfterGracePeriodinDays" != "" ]]; then
  wayOutsideGracePeriodDeadlineinDays="$((macOSSoftwareUpdateGracePeriodinDays+macOSSoftwareUpdateAbsoluteDeadlineAfterGracePeriodinDays))"
  wayOutsideGracePeriodAgeOutinSeconds="$(/bin/date -v +"$wayOutsideGracePeriodDeadlineinDays"d +'%s')"
fi

if [[ $4 == "" ]]; then
  echo "Preference Domain was not set, bailing"
  exit 2
fi
if [[ $5 == "" ]]; then
  echo "Software Update Grace Period was not set, bailing"
  exit 2
fi

# if [[ $($plistBuddy -c 'Print:softwareUpdatePreferenceFileVersion' $softwareUpdatePreferenceFile) -lt "2" ]] && [[ -e "$softwareUpdatePreferenceFile" ]]; then
#   echo "software update preference version is not correct, resetting"
#   defaults delete "$softwareUpdatePreferenceFile"
#   rm "$softwareUpdatePreferenceFile"
# fi

setSoftwareUpdateReleaseDate()

{
  $plistBuddy -c "Add:macOSSoftwareUpdateGracePeriodinDays integer $macOSSoftwareUpdateGracePeriodinDays" "$softwareUpdatePreferenceFile"
  if [[ $($plistBuddy -c "Print:gracePeriodWindowCloseDate" "$softwareUpdatePreferenceFile") = "" ]]; then
    $plistBuddy -c "Add:softwareUpdatePreferenceFileVersion integer 2" "$softwareUpdatePreferenceFile"
    $plistBuddy -c "Add:dateMacBecameAwareOfUpdates string $dateMacBecameAwareOfUpdates" "$softwareUpdatePreferenceFile"
    $plistBuddy -c "Add:dateMacBecameAwareOfUpdatesNationalRepresentation string $dateMacBecameAwareOfUpdatesNationalRepresentation" "$softwareUpdatePreferenceFile"
    $plistBuddy -c "Add:gracePeriodWindowCloseDate string $gracePeriodWindowClosureDate" "$softwareUpdatePreferenceFile"
    $plistBuddy -c "Add:gracePeriodWindowCloseDateNationalRepresentation string $gracePeriodWindowClosureDateNationalRepresentation" "$softwareUpdatePreferenceFile"
    $plistBuddy -c "Add:dateMacBecameAwareOfUpdatesSeconds integer $dateMacBecameAwareOfUpdatesSeconds" "$softwareUpdatePreferenceFile"
    $plistBuddy -c "Add:wayOutsideGracePeriodDeadlineinDays integer $wayOutsideGracePeriodDeadlineinDays" "$softwareUpdatePreferenceFile"
    $plistBuddy -c "Add:wayOutsideGracePeriodAgeOutinSeconds integer $wayOutsideGracePeriodAgeOutinSeconds" "$softwareUpdatePreferenceFile"
    echo "New Software Update grace period window is in place and datestamped $($plistBuddy -c 'Print:gracePeriodWindowCloseDate' $softwareUpdatePreferenceFile)"
  else
    echo "grace period window is already in place, continuing..."
  fi
}

availableUpdateManifest=$(/usr/libexec/mdmclient AvailableOSUpdates)
availableConfigDataUpdates=$(grep -c "IsConfigDataUpdate = 1" <<<$availableUpdateManifest)
availableFirmwareUpdates=$(grep -c "IsFirmwareUpdate = 1" <<<$availableUpdateManifest)
availableUpdateRequiresRestart=$(grep -c "RestartRequired = 1" <<<$availableUpdateManifest)
availableRecommendedUpdates=$(grep -c "RestartRequired = 0" <<<$availableUpdateManifest)
availableCriticalUpdates=$(grep -c "IsCritical = 1" <<<$availableUpdateManifest)
numberofDeferredUpdates=$(grep -c "DeferredUntil" <<<$availableUpdateManifest)
deferredUpdateAvailabilityDate=$(grep "DeferredUntil" <<<$availableUpdateManifest | awk '{print $3}' | sed 's/\"//')

if [[ $availableUpdateRequiresRestart -eq "0" ]] && [[ $availableRecommendedUpdates -eq "0" ]]; then
  echo "Client seems to be up to date"
  if [[ -e "$softwareUpdatePreferenceFile" ]]; then
    defaults delete "$softwareUpdatePreferenceFile"
    rm "$softwareUpdatePreferenceFile"
  fi
else
  setSoftwareUpdateReleaseDate
fi
