#!/usr/bin/env zsh

# Title         :Updates_Issue Software Update Command via MDM.sh
# Description   :
# Author        :John Hutchison
# Date          :2020.08.01
# Contact       :john@randm.ltd, john.hutchison@floatingorchard.com
# Version       :1.0
# Notes         :
# shell_version :zsh 5.8 (x86_64-apple-darwin19.3.0)

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

# The API account to issue MDM commands must have the minimum Jamf Pro privileges
# Computer - Create Read Update
# Jamf Pro Server Actions - Send Computer Remote Command to Download and Install macOS Update

hardwareUUID=$(system_profiler SPHardwareDataType | grep "Hardware UUID" | awk '{print $3}')

currentUser=$(/bin/ls -l /dev/console | /usr/bin/awk '{print $3}')
currentUserUID=$(/usr/bin/id -u "$currentUser")
currentUserHomeDirectoryPath="$(dscl . -read /Users/$currentUser NFSHomeDirectory | awk -F ': ' '{print $2}')"
if [[ "$currentUser" = "root" ]]; then
	echo "User is not logged into GUI, console, or remote session"
	userLoggedInStatus=0
else
	userLoggedInStatus=1
fi

jamfAPIAccount="$4"
jamfAPIPassword="$5"
logoPath="$6" # Optional
jamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"

if [[ "$jamfAPIAccount" = "" ]] || [[ "$jamfAPIPassword" = "" ]]; then
  echo "Jamf variables are not yet, bailing for now..."
  exit 1
fi

# Validate logoPATH file. If no logoPATH is provided or if the file cannot be found at
# specified path, default to either the Software Update or App Store Icon.
if [[ -z "$logoPath" ]] || [[ ! -f "$logoPath" ]]; then
  /bin/echo "No logo path provided or no logo exists at specified path, using standard application icon"
  if [[ -f "/System/Library/PreferencePanes/SoftwareUpdate.prefPane/Contents/Resources/SoftwareUpdate.icns" ]]; then
    logoPath="/System/Library/PreferencePanes/SoftwareUpdate.prefPane/Contents/Resources/SoftwareUpdate.icns"
  else
    logoPath="/Applications/App Store.app/Contents/Resources/AppIcon.icns"
  fi
fi

jamfManagementURL=$(defaults read /Library/Preferences/com.jamfsoftware.jamf jss_url)
jamfAuthorizationBase64="$(printf "$jamfAPIAccount:$jamfAPIPassword" | iconv -t ISO-8859-1 | base64 -i -)"
jamfComputerID=$(curl -H 'Content-Type: application/xml' -H "Authorization: Basic $jamfAuthorizationBase64" ""$jamfManagementURL"JSSResource/computers/udid/$hardwareUUID/subset/General" | xmllint --xpath "string(//id)" -)

echo "Determining if any updates are available that require a restart"
numberofUpdatesRequringRestart="$(/usr/sbin/softwareupdate -l | /usr/bin/grep -i -c 'restart')"
if [[ "$numberofUpdatesRequringRestart" -eq 0 ]]; then
  echo "No updates found which require a restart, but we'll run softwareupdate to install any other outstanding updates."
elif [[ "$numberofUpdatesRequringRestart" -ge 1 ]]; then
  echo "Updates that require a restart were found, notifying user"
  if [[ "$userLoggedInStatus" -eq "1" ]]; then
		/bin/launchctl asuser "$currentUserUID" "$jamfHelper" -windowType "utility" \
		-icon "$logoPath" \
		-title "Downloading macOS" \
		-description "An update for your Mac is being applied and will reboot your computer to complete. Your work will be preserved." \
		-button1 "OK" \
		-startlaunchd &
	fi
fi

## POST Software Update MDM Command. Will only work on ABM enrolled devices or Big Sur Devices that are supervised with a user approved MDM enrollment profile
curl -s -f -X "POST" "$jamfManagementURL""JSSResource/computercommands/command/ScheduleOSUpdate/action/install/id/$jamfComputerID" \
     -H "Authorization: Basic $jamfAuthorizationBase64" \
     -H 'Cache-Control: no-cache'
