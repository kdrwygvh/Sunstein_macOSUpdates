#!/bin/zsh

# Title         :Updates_Install all Outstanding Updates_softwareupdate.sh
# Description   :
# Author        :John Hutchison
# Date          :2021-05-18
# Contact       :john@randm.ltd, john.hutchison@floatingorchard.com
# Version       :1.2.1
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

companyPreferenceDomain=$4 # Required
customBrandingImagePath=$5 # Optional
mdmSoftwareUpdateEvent=$6 # Required
notificationTitle="$7" #Optional
currentUser=$(/bin/ls -l /dev/console | /usr/bin/awk '{print $3}')
currentUserUID=$(/usr/bin/id -u "$currentUser")
currentUserHomeDirectoryPath="$(dscl . -read /Users/"$currentUser" NFSHomeDirectory | awk -F ': ' '{print $2}')"
jamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
softwareUpdatePreferenceFile="/Library/Preferences/$companyPreferenceDomain.SoftwareUpdatePreferences.plist"
appleSoftwareUpdatePreferenceFile="/Library/Preferences/com.apple.SoftwareUpdate.plist"

if [[ $4 == "" ]]; then
  echo "Preference Domain was not set, bailing"
  exit 2
fi

if [[ $6 == "" ]]; then
  echo "Policy event to trigger MDM update not set, bailing"
  exit 2
fi

if [[ ! -f "$softwareUpdatePreferenceFile" ]]; then
	echo "Software Update Preferences not yet in place, bailing for now"
	exit 0
fi

if [[ "$(defaults read $appleSoftwareUpdatePreferenceFile LastUpdatesAvailable)" -eq "0" ]]; then
  echo "Client is up to date or has not yet identified needed updates, exiting"
  if [[ -f "$softwareUpdatePreferenceFile" ]]; then
    echo "Grace Period window in Place, removing"
    rm -fv "$softwareUpdatePreferenceFile"
  fi
  /usr/local/bin/jamf recon
  exit 0
fi

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
	-description "Updates are available which we'd suggest installing today at your earliest opportunity.

You'll be presented with available updates to install after clicking 'Update Now'" \
	-alignDescription left \
	-icon "$dialogImagePath" \
	-iconSize 120 \
	-button1 "Update Now" \
	-defaultButton 0 \
	-timeout 300
}

if [[ "$currentUser" = "root" ]]; then
  echo "User is not in session, safe to perform all updates and restart now if required"
  numberofUpdatesRequringRestart="$(/usr/sbin/softwareupdate -l | /usr/bin/grep -i -c 'restart')"
  if [[ "$numberofUpdatesRequringRestart" -eq "0" ]]; then
    echo "No updates found which require a restart, but we'll run softwareupdate to install any other outstanding updates."
    softwareupdate --install --all --verbose
  elif [[ "$numberofUpdatesRequringRestart" -ge "1" ]]; then
    echo "Updates found which require restart. Installing and restarting...but only on Intel based systems"
    if [[ "$(arch)" = "arm64" ]]; then
    	echo "Command line updates are not supported on Apple Silicon, falling back to installation via MDM event"
    	/usr/local/bin/jamf policy -event "$mdmSoftwareUpdateEvent" -verbose
    else
    	softwareupdate --install --all --restart --verbose
    fi
  fi
fi

doNotDisturbState="$(defaults read "$currentUserHomeDirectoryPath"/Library/Preferences/ByHost/com.apple.notificationcenterui.plist doNotDisturb)"
if [[ ${doNotDisturbState} -eq 1 ]]; then
  echo "User has enabled Do Not Disturb, not bothering with presenting the software update notification this time around"
  exit 0
fi
softwareUpdateNotification
if [[ $(pgrep "System Preferences") != "" ]]; then
  killall "System Preferences"
fi
/bin/launchctl asuser "$currentUserUID" /usr/bin/open "/System/Library/CoreServices/Software Update.app"
