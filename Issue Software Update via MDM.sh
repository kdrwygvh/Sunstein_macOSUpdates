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
jamfAPIAccount="$4"
jamfAPIPassword="$5"
if [[ "$jamfAPIAccount" = "" ]] || [[ "$jamfAPIPassword" = "" ]]; then
  echo "Jamf variables are not yet, bailing for now..."
  exit 1
fi
jamfManagementURL=$(defaults read /Library/Preferences/com.jamfsoftware.jamf jss_url)
jamfAuthorizationBase64="$(printf "$jamfAPIAccount:$jamfAPIPassword" | iconv -t ISO-8859-1 | base64 -i -)"
jamfComputerID=$(curl -H 'Content-Type: application/xml' -H "Authorization: Basic $jamfAuthorizationBase64" ""$jamfManagementURL"JSSResource/computers/udid/$hardwareUUID/subset/General" | xmllint --xpath "string(//id)" -)

## POST Software Update MDM Command. Will only work on ABM enrolled devices.
curl -s -f -X "POST" "$jamfManagementURL""JSSResource/computercommands/command/ScheduleOSUpdate/action/install/id/$jamfComputerID" \
     -H "Authorization: Basic $jamfAuthorizationBase64" \
     -H 'Cache-Control: no-cache'

