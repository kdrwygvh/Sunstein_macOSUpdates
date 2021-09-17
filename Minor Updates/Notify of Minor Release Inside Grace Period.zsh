#!/bin/zsh

# Title         :Notify of Minor Release Inside Grace Period.zsh
# Description   :Update notifications via the jamfHelper
# Author        :John Hutchison
# Date          :2021-07-22
# Contact       :john@randm.ltd, john.hutchison@floatingorchard.com
# Version       :1.2.1.2
# Notes         :Updated for compatibility with Big Sur. Support for High Sierra removed

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

# Jamf Pro Usage
# Build a Jamf Pro Smart Group using the "Grace Period Window Start Date" attribute with
# "less than" the number of days you're specifying as the grace period duration

companyPreferenceDomain=$4 # Required
customBrandingImagePath=$5 # Optional
updateAttitude=$6 # Optional passive or aggressive
mdmSoftwareUpdateEvent=$7 # Required
respectDNDApplications=$8 # Required
softwareUpdatePreferenceFile="/Library/Preferences/$companyPreferenceDomain.SoftwareUpdatePreferences.plist"
jamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
dateMacBecameAwareOfUpdatesNationalRepresentation="$(defaults read $softwareUpdatePreferenceFile dateMacBecameAwareOfUpdatesNationalRepresentation)"
gracePeriodWindowCloseDateNationalRepresentation="$(defaults read $softwareUpdatePreferenceFile gracePeriodWindowCloseDateNationalRepresentation)"
macOSSoftwareUpdateGracePeriodinDays="$(defaults read $softwareUpdatePreferenceFile macOSSoftwareUpdateGracePeriodinDays)"
currentUser=$(/bin/ls -l /dev/console | /usr/bin/awk '{print $3}')
currentUserUID=$(/usr/bin/id -u "$currentUser")
currentUserHomeDirectoryPath="$(dscl . -read /Users/$currentUser NFSHomeDirectory | awk -F ': ' '{print $2}')"

# macOSVersionMarketingCompatible is the commerical version number of macOS (10.x, 11.x)
# macOSVersionEpoch is the major version number and is meant to draw a line between Big Sur and all prior versions of macOS
# macOSVersionMajor is the current dot releaes of macOS (15 in 10.15)
macOSVersionMarketingCompatible="$(sw_vers -productVersion)"
macOSVersionEpoch="$(awk -F '.' '{print $1}' <<<"$macOSVersionMarketingCompatible")"
macOSVersionMajor="$(awk -F '.' '{print $2}' <<<"$macOSVersionMarketingCompatible")"

doNotDisturbAppBundleIDs=(
  "us.zoom.xos"
  "com.microsoft.teams"
  "com.cisco.webexmeetingsapp"
  "com.webex.meetingmanager"
  "com.apple.FaceTime"
  "com.apple.iWork.Keynote"
  "com.microsoft.Powerpoint"
  "com.apple.FinalCut"
  "com.apple.TV"
)

doNotDisturbAppBundleIDsArray=(${=doNotDisturbAppBundleIDs})

if [[ "$customBrandingImagePath" != "" ]]; then
  dialogImagePath="$customBrandingImagePath"
elif [[ "$customBrandingImagePath" = "" ]]; then
  if [[ -f "/System/Library/PreferencePanes/SoftwareUpdate.prefPane/Contents/Resources/SoftwareUpdate.icns" ]]; then
    dialogImagePath="/System/Library/PreferencePanes/SoftwareUpdate.prefPane/Contents/Resources/SoftwareUpdate.icns"
  else
    dialogImagePath="/Applications/App Store.app/Contents/Resources/AppIcon.icns"
  fi
fi

softwareUpdateNotification (){

  userUpdateChoice=$("$jamfHelper" \
    -windowType utility \
    -windowPosition ur \
    -title "Updates Available" \
    -description "System Updates are available as of
"$dateMacBecameAwareOfUpdatesNationalRepresentation"

You have "$macOSSoftwareUpdateGracePeriodinDays" days to defer before they are auto installed

Auto Installation will start on or about
"$gracePeriodWindowCloseDateNationalRepresentation"" \
    -icon "$dialogImagePath" \
    -button1 "Review" \
    -button2 "Dismiss" \
    -defaultButton 0 \
    -cancelButton 1 \
    -timeout 300 \
    -startlaunchd &
    wait $!
  )
}

if [[ $4 == "" ]]; then
  echo "Preference Domain was not set, bailing"
  exit 2
fi

if [[ $6 == "" ]]; then
  echo "Update attitude not set, assuming passive operation"
  updateAttitude="passive"
fi

if [[ "$(softwareupdate --list --no-scan | grep -c '*')" -eq 0 ]]; then
  echo "Client is up to date, exiting"
  defaults delete "$softwareUpdatePreferenceFile" &> /dev/null
  rm "$softwareUpdatePreferenceFile" &> /dev/null
  exit 0
fi

if [[ ! -f "$softwareUpdatePreferenceFile" ]]; then
  echo "Software Update Preferences not yet in place, bailing for now"
  exit 0
fi

if [[ "$currentUser" = "root" ]]; then
  echo "User is not in session, not bothering with presenting the software update notification this time around but checking update attitude"
  numberofUpdatesRequringRestart="$(softwareupdate --list --no-scan | /usr/bin/grep -i -c 'restart')"
  if [[ "$updateAttitude" == "aggressive" && "$numberofUpdatesRequringRestart" -ge "1" ]]; then
    echo "Aggressive attitude is set and user is not logged in, performing all updates and restarting now"
    if [[ "$(arch)" = "arm64" ]]; then
      echo "Command line updates are not supported on Apple Silicon, falling back to installation via MDM event"
      /usr/local/bin/jamf policy -event "$mdmSoftwareUpdateEvent" -verbose
    else
      softwareupdate --install --all --restart --verbose
      exit 0
    fi
  elif [[ "$updateAttitude" == "passive" && "$numberofUpdatesRequringRestart" -ge "1" ]]; then
  	echo "Passive mode set, exiting"
  	exit 0
  fi
elif [[ "$currentUser" != "root" ]] && [[ "$respectDNDApplications" != "false" ]]; then
  frontAppASN="$(lsappinfo front)"
  for doNotDisturbAppBundleID in ${doNotDisturbAppBundleIDsArray[@]}; do
    frontAppBundleID="$(lsappinfo info -app "$frontAppASN" | grep bundleID | awk -F '=' '{print $2}' | sed 's/\"//g')"
    if [[ "$frontAppBundleID" = "$doNotDisturbAppBundleID" ]]; then
      echo "Do not disturb app $frontAppBundleID is frontmost, not displaying notification"
      exit 0
    fi
  done
fi

softwareUpdateNotification

if [ "$userUpdateChoice" -eq "2" ]; then
  echo "User chose to defer to a later date, exiting"
  exit 0
elif [ "$userUpdateChoice" -eq "0" ]; then
  if [[ "$macOSVersionEpoch" -ge "11" || "$macOSVersionMajor" -ge "14" ]]; then
    echo "opening Software Update Preference Pane for user review"
    /bin/launchctl asuser "$currentUserUID" pkill "System Preferences"
    sleep 5
    /bin/launchctl asuser "$currentUserUID" /usr/bin/open "x-apple.systempreferences:com.apple.preferences.softwareupdate"
  elif [[ "$macOSVersionMajor" -le "13" ]]; then
    echo "opening Mac App Store Update Pane for user review"
    /bin/launchctl asuser "$currentUserUID" pkill "App Store"
    sleep 5
    /bin/launchctl asuser "$currentUserUID" /usr/bin/open "macappstore://showUpdatesPage"
  fi
fi
