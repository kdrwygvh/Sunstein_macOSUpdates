#!/bin/zsh

# Title         :Notify of Major Release Inside Grace Period.zsh
# Description   :Update notifications via the jamfHelper
# Author        :John Hutchison
# Date          :2021-05-18
# Contact       :john@randm.ltd, john.hutchison@floatingorchard.com
# Version       :1.0.1
# Notes         :Updated for compatibility with Big Sur. Support for High Sierra removed

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
majorOSUpdateInsideGracePeriodEvent=$6 # Required
softwareUpdatePreferenceFile="/Library/Preferences/$companyPreferenceDomain.majorSoftwareUpdatePreferences.plist"
macOSTargetVersion=$(defaults read "$softwareUpdatePreferenceFile" macOSTargetVersion)
macOSTargetVersionEpoch="$(awk -F '.' '{print $1}' <<<"$macOSTargetVersion")"
macOSTargetVersionMajor="$(awk -F '.' '{print $2}' <<<"$macOSTargetVersion")"
jamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
dateMacBecameAwareOfUpdatesNationalRepresentation="$(defaults read "$softwareUpdatePreferenceFile" dateMacBecameAwareOfUpdatesNationalRepresentation)"
gracePeriodWindowCloseDateNationalRepresentation="$(defaults read "$softwareUpdatePreferenceFile" gracePeriodWindowCloseDateNationalRepresentation)"
macOSSoftwareUpdateGracePeriodinDays="$(defaults read "$softwareUpdatePreferenceFile" macOSSoftwareUpdateGracePeriodinDays)"
macOSVersionMarketingCompatible="$(sw_vers -productVersion)"
macOSVersionEpoch="$(awk -F '.' '{print $1}' <<<"$macOSVersionMarketingCompatible")"
macOSVersionMajor="$(awk -F '.' '{print $2}' <<<"$macOSVersionMarketingCompatible")"
currentUser=$(/bin/ls -l /dev/console | /usr/bin/awk '{print $3}')
currentUserHomeDirectoryPath="$(dscl . -read /Users/"$currentUser" NFSHomeDirectory | awk -F ': ' '{print $2}')"
doNotDisturbApplePlistID='com.apple.ncprefs'
doNotDisturbApplePlistKey='dnd_prefs'
doNotdisturbApplePlistLocation="$currentUserHomeDirectoryPath/Library/Preferences/$doNotDisturbApplePlistID.plist"

if [[ $4 == "" ]]; then
  echo "Preference Domain was not set, bailing"
  exit 2
fi

if [[ $6 == "" ]]; then
  echo "Major Update Jamf event not set, bailing"
  exit 2
fi

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
    -iconSize 100 \
    -button1 "Update Now" \
    -button2 "Dismiss" \
    -defaultButton 0 \
    -cancelButton 1 \
    -timeout 300 \
    -startlaunchd &>/dev/null &
		wait $!
  )
}

if [[ "$macOSVersionEpoch" -ge "11" ]]; then
  echo "current OS is in iOS style versioning epoch, using epoch number for further evaluation"
  if [[ "$macOSVersionEpoch" -eq "$macOSTargetVersionEpoch" ]]; then
    echo "Client is up to date, exiting"
    if [[ -f "$softwareUpdatePreferenceFile" ]]; then
      echo "Grace period window preference in Place, removing"
      rm -fv "$softwareUpdatePreferenceFile"
      exit 0
    fi
  fi
elif [[ "$macOSVersionEpoch" -eq "10" ]]; then
  echo "current OS is in the OS X versioning epoch, using major OS version number for further evaluation"
  if [[ "$macOSVersionMajor" -ge "$macOSTargetVersionMajor" ]]; then
    echo "Client is up to date or newer than the version we're expecting, exiting"
    if [[ -f "$softwareUpdatePreferenceFile" ]]; then
      echo "Grace period window preference in Place, removing"
      rm -fv "$softwareUpdatePreferenceFile"
    fi
    exit 0
  fi
fi

if [[ "$currentUser" = "root" ]]; then
  echo "User is not in session, not bothering with presenting the software update notification this time around"
  exit 0
elif [[ "$currentUser" != "root" ]]; then
  for doNotDisturbAppBundleID in ${doNotDisturbAppBundleIDsArray[@]}; do
    frontAppASN="$(lsappinfo front)"
    frontAppBundleID="$(lsappinfo info -app $frontAppASN | grep bundleID | awk -F '=' '{print $2}' | sed 's/\"//g')"
    if [[ "$frontAppBundleID" = "$doNotDisturbAppBundleID" ]]; then
      echo "Do not disturb app $frontAppBundleID is frontmost, not displaying notification"
      exit 0
    fi
  done
elif [[ $(getDoNotDisturbStatus) = "true" ]]; then
  echo "User has enabled Do Not Disturb, not bothering with presenting the software update notification this time around"
  exit 0
else
  echo "Do not disturb is disabled, safe to proceed with software update notification"
fi

softwareUpdateNotification

if [[ "$userUpdateChoice" -eq "2" ]]; then
  echo "User chose to defer to a later date, exiting"
  exit 0
elif [[ "$userUpdateChoice" -eq "0" ]]; then
  /usr/local/bin/jamf policy -event "$majorOSUpdateInsideGracePeriodEvent" -verbose
fi
