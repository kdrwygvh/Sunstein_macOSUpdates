#!/bin/zsh

# Title         :Issue Software Update via MDM.zsh
# Description   :
# Author        :John Hutchison
# Date          :2021-07-22
# Contact       :john@randm.ltd, john.hutchison@floatingorchard.com
# Version       :1.0.2
# Notes         :Added logic to check for Jamf Pro supervision status

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

# The API account to issue MDM commands must have the minimum Jamf Pro privileges;
# Computer - Create Read Update
# Jamf Pro Server Actions - Send Computer Remote Command to Download and Install macOS Update

jamfAPIAccount="$4" # Required
jamfAPIPassword="$5" # Required
logoPath="$6" # Optional
hardwareUUID="$(system_profiler SPHardwareDataType | grep "Hardware UUID" | awk '{print $3}')"
currentUser=$(/bin/ls -l /dev/console | /usr/bin/awk '{print $3}')
currentUserUID=$(/usr/bin/id -u "$currentUser")
currentUserHomeDirectoryPath="$(dscl . -read /Users/$currentUser NFSHomeDirectory | awk -F ': ' '{print $2}')"
jamfManagementURL="$(defaults read /Library/Preferences/com.jamfsoftware.jamf jss_url)"

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

if [[ "$currentUser" = "root" ]]; then
  echo "User is not logged into GUI, console, or remote session"
  userLoggedInStatus=0
else
  userLoggedInStatus=1
fi

if [[ "$jamfAPIAccount" = "" ]]; then
  echo "Jamf API Account not set, bailing"
  exit 2
fi

if [[ "$jamfAPIPassword" = "" ]]; then
  echo "Jamf API Password not set, bailing"
  exit 2
fi

if [[ "$(arch)" = "arm64" ]]; then
  echo "checking bootstrap token escrow status"
  if [[ "$(profiles status -type bootstraptoken | grep "Bootstrap Token escrowed to server" | awk -F ': ' '{print $3}')" != "YES" ]]; then
    echo "Software updates via MDM cannot contine, bootstrap token not escrowed to MDM server, bailing"
    exit 2
  else
    echo "bootstrap token is escrowed, continuing"
  fi
fi

jamfAuthorizationBase64=$(printf "$jamfAPIAccount:$jamfAPIPassword" | iconv --to-code ISO-8859-1 | /usr/bin/base64 --input -)
jamfComputerGeneralInfoXML=$(curl -H 'Content-Type: application/xml' -H "Authorization: Basic $jamfAuthorizationBase64" ""$jamfManagementURL"JSSResource/computers/udid/$hardwareUUID/subset/General")
jamfComputerID=$(echo "$jamfComputerGeneralInfoXML" | xmllint --xpath "string(//id)" -)
jamfSupervisionStatus=$(echo "$jamfComputerGeneralInfoXML" | xmllint --xpath "string(//supervised)" -)

if [[ "$jamfSupervisionStatus" = "false" ]]; then
  echo "software updates via MDM cannot continue, system is not supervised in Jamf Pro. Possible PI PI-008666 or PI-007833"
  exit 1
fi

if [[ -z "$logoPath" ]] || [[ ! -f "$logoPath" ]]; then
  /bin/echo "No logo path provided or no logo exists at specified path, using standard application icon"
  if [[ -f "/System/Library/PreferencePanes/SoftwareUpdate.prefPane/Contents/Resources/SoftwareUpdate.icns" ]]; then
    logoPath="/System/Library/PreferencePanes/SoftwareUpdate.prefPane/Contents/Resources/SoftwareUpdate.icns"
  else
    logoPath="/Applications/App Store.app/Contents/Resources/AppIcon.icns"
  fi
fi

echo "Determining if any updates are available that require a restart"
numberofUpdatesRequringRestart=$(/usr/sbin/softwareupdate --list --no-scan | /usr/bin/grep -i -c 'restart')
if [[ "$numberofUpdatesRequringRestart" -eq "0" ]]; then
  echo "No updates found which require a restart, suppressing notifications"
elif [[ "$numberofUpdatesRequringRestart" -ge "1" ]]; then
  echo "Updates that require a restart were found, checking for do not disturb apps"
  if [[ "$userLoggedInStatus" -eq "1" ]]; then
    for doNotDisturbAppBundleID in ${doNotDisturbAppBundleIDsArray[@]}; do
      frontAppASN="$(lsappinfo front)"
      frontAppBundleID="$(lsappinfo info -app $frontAppASN | grep bundleID | awk -F '=' '{print $2}' | sed 's/\"//g')"
      if [[ "$frontAppBundleID" = "$doNotDisturbAppBundleID" ]]; then
        echo "Do not disturb app $frontAppBundleID is frontmost, not displaying notification and bailing"
        exit 0
      fi
    done
  fi
fi

# workaround for PI-009722

/usr/libexec/mdmclient AvailableOSUpdates

## POST Software Update MDM Command. Will only work on ABM enrolled devices or Big Sur Devices that are supervised with a user approved MDM enrollment profile and escrowed bootstrap token
curl -s -f -X "POST" "$jamfManagementURL""JSSResource/computercommands/command/ScheduleOSUpdate/action/install/id/$jamfComputerID" \
  -H "Authorization: Basic $jamfAuthorizationBase64" \
  -H 'Cache-Control: no-cache'
