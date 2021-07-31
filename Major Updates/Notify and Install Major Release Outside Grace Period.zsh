#!/bin/zsh

# Title         :Notify and Install Major Release Outside Grace Period.zsh
# Description   :
# Author        :John Hutchison
# Date          :2021-05-18
# Contact       :john@randm.ltd, john.hutchison@floatingorchard.com
# Version       :1.2.1.1
# Notes         :Updated for Big Sur compatibility. Support for High Sierra Removed

# The Clear BSD License
#
# Copyright (c) [2021] [John Hutchison of Russell & Manifold ltd.]
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
# NO EXPRESS OR IMPLIED LICENSES TO ANY PARTY\'S PATENT RIGHTS ARE GRANTED BY
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
# Build a Jamf Pro Smart Group using the "Grace Period Window Start Date" attribute with "more than"
# the number of days you're specifying as the grace period duration

companyPreferenceDomain=$4 # required
customBrandingImagePath=$5 # optional
notificationTitle="$6" # optional
updateAttitude=$7 # passive/aggressive, defaults to passive
macOSPassiveUpdateEvent=$8 # required
macOSAggressiveUpdateEvent=$9 # optional
offermacOSUpdateviaSystemPreferences="${10}" #true/false
currentUser=$(/bin/ls -l /dev/console | /usr/bin/awk '{print $3}')
currentUserUID=$(/usr/bin/id -u "$currentUser")
currentUserHomeDirectoryPath="$(dscl . -read /Users/"$currentUser" NFSHomeDirectory | awk -F ': ' '{print $2}')"
jamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
jamfNotificationHelper="/Library/Application Support/JAMF/bin/Management Action.app/Contents/MacOS/Management Action"
softwareUpdatePreferenceFile="/Library/Preferences/$preferenceDomain.majorOSSoftwareUpdatePreferences.plist"
doNotDisturbApplePlistID='com.apple.ncprefs'
doNotDisturbApplePlistKey='dnd_prefs'
doNotdisturbApplePlistLocation="$currentUserHomeDirectoryPath/Library/Preferences/$doNotDisturbApplePlistID.plist"
dateMacBecameAwareOfUpdatesSeconds="$(defaults read $softwareUpdatePreferenceFile dateMacBecameAwareOfUpdatesSeconds)"
wayOutsideGracePeriodAgeOutinSeconds="$(defaults read $softwareUpdatePreferenceFile wayOutsideGracePeriodAgeOutinSeconds)"

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
)

doNotDisturbAppBundleIDsArray=(${=doNotDisturbAppBundleIDs})

getNestedDoNotDisturbPlist(){
  plutil -extract $2 xml1 -o - $1 | \
    xmllint --xpath "string(//data)" - | base64 --decode | plutil -convert xml1 - -o -
}

getDoNotDisturbStatus(){
  getNestedDoNotDisturbPlist $doNotdisturbApplePlistLocation $doNotDisturbApplePlistKey | \
    xmllint --xpath 'boolean(//key[text()="userPref"]/following-sibling::dict/key[text()="enabled"])' -
}

if [[ "$customBrandingImagePath" != "" ]]; then
  dialogImagePath="$customBrandingImagePath"
elif [[ "$customBrandingImagePath" = "" ]]; then
  if [[ -f "/System/Library/PreferencePanes/SoftwareUpdate.prefPane/Contents/Resources/SoftwareUpdate.icns" ]]; then
    dialogImagePath="/System/Library/PreferencePanes/SoftwareUpdate.prefPane/Contents/Resources/SoftwareUpdate.icns"
  else
    dialogImagePath="/Applications/App Store.app/Contents/Resources/AppIcon.icns"
  fi
else
  echo "jamfHelper icon branding not set, continuing anyway as the error is purly cosmetic"
fi

softwareUpdateNotification(){

  "$jamfHelper" \
  -windowType utility \
  -windowPosition ur \
  -title "$notificationTitle" \
  -description "Updates are available which we'd suggest installing today at your earliest convenience.

You'll be presented with available updates to install after clicking 'Update Now'" \
  -alignDescription left \
  -icon "$dialogImagePath" \
  -iconSize 120 \
  -button1 "Review" \
  -defaultButton 0 \
  -timeout 300 \
  -startlaunchd &>/dev/null &
	wait $!
}

if [[ $4 == "" ]]; then
  echo "Preference Domain was not set, bailing"
  exit 2
fi

if [[ $7 == "" ]]; then
  echo "update attitude not set, defaulting to passive"
  updateAttitude="passive"
fi

if [[ $8 == "" ]]; then
  echo "Passive update Jamf event not set, bailing"
  exit 2
fi

if [[ $9 == "" ]]; then
  echo "Aggressive update Jamf event not set, defaulting to passive"
  updateAttitude="passive"
fi

if [[ ! -f "$softwareUpdatePreferenceFile" ]]; then
  echo "Software Update Preferences not yet in place, bailing for now"
  exit 0
fi

for doNotDisturbAppBundleID in ${doNotDisturbAppBundleIDsArray[@]}; do
  frontAppASN="$(lsappinfo front)"
  frontAppBundleID="$(lsappinfo info -app $frontAppASN | grep bundleID | awk -F '=' '{print $2}' | sed 's/\"//g')"
  if [[ "$frontAppBundleID" = "$doNotDisturbAppBundleID" ]]; then
    echo "Do not disturb app $frontAppBundleID is frontmost, not displaying notification"
    exit 0
  fi
done
if [[ "$macOSVersionEpoch" -ge "11" ]]; then
  if [[ $(getDoNotDisturbStatus) = "true" ]]; then
    echo "User has enabled Do Not Disturb, not bothering with presenting the software update notification this time around"
    exit 0
  fi
fi
if [[ $(ioreg -c IOHIDSystem | awk '/HIDIdleTime/ {print int($NF/1000000000)}') -ge "3600" && "$updateAttitude" == "aggressive" ]]; then
  echo "User has been idle for at least one hour and aggressive attitude is set, updating and restarting now"
  /usr/local/bin/jamf policy -event "$macOSAggressiveUpdateEvent" -verbose
  "$jamfNotificationHelper" -message "Automatic updates were applied on $(/bin/date "+%A, %B %e")"
  exit 0
fi
if [[ "$dateMacBecameAwareOfUpdatesSeconds" -lt "$wayOutsideGracePeriodAgeOutinSeconds" ]] && [[ "$updateAttitude" == "aggressive" ]]; then
  echo "Mac is way outside the defined grace period and aggressive attitude is set, updating and restarting now"
  /usr/local/bin/jamf policy -event "$macOSAggressiveUpdateEvent" -verbose
  "$jamfNotificationHelper" -message "Automatic updates were applied on $(/bin/date "+%A, %B %e")"
  exit 0
fi

softwareUpdateNotification

if [[ "$macOSVersionEpoch" -ge "11" || "$macOSVersionMajor" -ge "14" && "$offermacOSUpdateviaSystemPreferences" == "true" ]]; then
  echo "Opening Software Update Preference Pane for user review"
  /bin/launchctl asuser "$currentUserUID" pkill "System Preferences"
  sleep 5
  /bin/launchctl asuser "$currentUserUID" /usr/bin/open "x-apple.systempreferences:com.apple.preferences.softwareupdate"
  exit 0
elif [[ "$macOSVersionMajor" -le "13" && "$offermacOSUpdateviaSystemPreferences" == "true" ]]; then
  echo "opening Mac App Store Update Pane for user review"
  /bin/launchctl asuser "$currentUserUID" pkill "App Store"
  sleep 5
  /bin/launchctl asuser "$currentUserUID" /usr/bin/open "macappstore://showUpdatesPage"
else
	echo "running macOS software update passive event"
  /usr/local/bin/jamf policy -event "$macOSPassiveUpdateEvent" -verbose
  exit 0
fi





