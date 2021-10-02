#!/bin/zsh

# Title         :Set Grace Period Start and End Dates for Major OS Upgrade.zsh
# Description   :Sets the future date after which user flexibility for Major OS updates will close
# Author        :John Hutchison
# Date          :2021-04-02
# Contact       :john@randm.ltd, john.hutchison@floatingorchard.com
# Version       :1.0
# Notes         :

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
macOSTargetVersion=$7 # Required
macOSTargetVersionEpoch="$(awk -F '.' '{print $1}' <<<"$macOSTargetVersion")"
macOSTargetVersionMajor="$(awk -F '.' '{print $2}' <<<"$macOSTargetVersion")"
dateMacBecameAwareOfUpdates="$(/bin/date)"
dateMacBecameAwareOfUpdatesNationalRepresentation="$(/bin/date "+%A, %B %e")"
dateMacBecameAwareOfUpdatesSeconds="$(/bin/date +%s)"
gracePeriodWindowClosureDate="$(/bin/date -v +"$macOSSoftwareUpdateGracePeriodinDays"d)"
gracePeriodWindowClosureDateNationalRepresentation="$(/bin/date -v +"$macOSSoftwareUpdateGracePeriodinDays"d "+%A, %B %e")"
softwareUpdatePreferenceFile="/Library/Preferences/$preferenceDomain.majorOSSoftwareUpdatePreferences.plist"
softwareUpdatePreferenceFileVersion="2"

if [[ "$macOSSoftwareUpdateAbsoluteDeadlineAfterGracePeriodinDays" != "" ]]; then
  wayOutsideGracePeriodDeadlineinDays="$((macOSSoftwareUpdateGracePeriodinDays+macOSSoftwareUpdateAbsoluteDeadlineAfterGracePeriodinDays))"
  wayOutsideGracePeriodAgeOutinSeconds="$(/bin/date -v -"$wayOutsideGracePeriodDeadlineinDays"d +'%s')"
fi
if [[ "$preferenceDomain" == "" ]]; then
  echo "Preference Domain not set as a jamf variable, bailing"
  exit 2
fi
if [[ "$macOSSoftwareUpdateGracePeriodinDays" = "" ]]; then
  echo "Grace Period not set as a jamf variable, bailing"
  exit 2
fi
if [[ "$macOSTargetVersion" == "" ]]; then
  echo "macOS target version not set, bailing"
  exit 2
fi

if [[ $($plistBuddy -c 'Print:softwareUpdatePreferenceFileVersion' $softwareUpdatePreferenceFile ) -lt "2" ]] && [[ -e "$softwareUpdatePreferenceFile" ]]; then
  echo "software update preference version is not correct, resetting"
  defaults delete "$softwareUpdatePreferenceFile"
  rm "$softwareUpdatePreferenceFile"
fi

setSoftwareUpdateReleaseDate()

{
  $plistBuddy -c "Add:macOSSoftwareUpdateGracePeriodinDays integer $macOSSoftwareUpdateGracePeriodinDays" "$softwareUpdatePreferenceFile"
  if [[ $($plistBuddy -c "Print:gracePeriodWindowCloseDate" "$softwareUpdatePreferenceFile") = "" ]]; then
    $plistBuddy -c "Add:softwareUpdatePreferenceFileVersion integer 2" "$softwareUpdatePreferenceFile"
    $plistBuddy -c "Add:dateMacBecameAwareOfUpdates date $dateMacBecameAwareOfUpdates" "$softwareUpdatePreferenceFile"
    $plistBuddy -c "Add:dateMacBecameAwareOfUpdatesNationalRepresentation string $dateMacBecameAwareOfUpdatesNationalRepresentation" "$softwareUpdatePreferenceFile"
    $plistBuddy -c "Add:dateMacBecameAwareOfUpdatesSeconds integer $dateMacBecameAwareOfUpdatesSeconds" "$softwareUpdatePreferenceFile"
    $plistBuddy -c "Add:gracePeriodWindowCloseDate date $gracePeriodWindowClosureDate" "$softwareUpdatePreferenceFile"
    $plistBuddy -c "Add:gracePeriodWindowCloseDateNationalRepresentation string $gracePeriodWindowClosureDateNationalRepresentation" "$softwareUpdatePreferenceFile"
    $plistBuddy -c "Add:macOSTargetVersion string $macOSTargetVersion" "$softwareUpdatePreferenceFile"
    $plistBuddy -c "Add:wayOutsideGracePeriodDeadlineinDays integer $wayOutsideGracePeriodDeadlineinDays" "$softwareUpdatePreferenceFile"
    $plistBuddy -c "Add:wayOutsideGracePeriodAgeOutinSeconds integer $wayOutsideGracePeriodAgeOutinSeconds" "$softwareUpdatePreferenceFile"
    echo "New Software Update Grace Period Closure Date in Place and datestamped $($plistBuddy -c 'Print:gracePeriodWindowCloseDate' $softwareUpdatePreferenceFile)"
  else
    echo "Software Update grace period is already in place, continuing..."
  fi
}

macOSVersionMarketingCompatible="$(sw_vers -productVersion)"
macOSVersionEpoch="$(awk -F '.' '{print $1}' <<<"$macOSVersionMarketingCompatible")"
macOSVersionMajor="$(awk -F '.' '{print $2}' <<<"$macOSVersionMarketingCompatible")"

if [[ "$macOSVersionEpoch" -lt "$macOSTargetVersionEpoch" ]]; then
  echo "We are in the iOS style versioning epoch and client requires a major update, setting software update preferences"
elif [[ "$macOSVersionEpoch" -eq "10" ]] && [[ "$macOSVersionMajor" -lt "$macOSTargetVersionMajor" ]]; then
  echo "We are in the OS X style versioning epoch and client requires a major update, setting software update preferences"
else
  echo "Client seems to be up to date"
  defaults delete "$softwareUpdatePreferenceFile"
  rm "$softwareUpdatePreferenceFile"
  exit 0
fi
setSoftwareUpdateReleaseDate

