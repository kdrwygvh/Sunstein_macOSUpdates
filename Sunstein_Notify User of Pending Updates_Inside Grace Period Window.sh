#!/usr/bin/env zsh

# Title         :Updates_Notify User of Pending Updates with Option to Defer.sh
# Description   :Update notifications via the jamfHeloper
# Author        :John Hutchison
# Date          :2021-03-25
# Contact       :john@randm.ltd, john.hutchison@floatingorchard.com
# Version       :1.2.1
# Notes         :Updated for compatibility with Big Sur. Support for High Sierra removed
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
# Build a Jamf Pro Smart Group using the "Grace Period Window Start Date" attribute with "less than" the number of days you're specifying as the grace period duration.

### Enter your organization's preference domain as a Jamf parameter 4 ###
companyPreferenceDomain=$4
##########################################################################################
### Enter the length of the flexibility window in days. This should match the flexibility
### window in days set in Updates_Set OS Software Update Flexibilty Window Closure Date
macOSSoftwareUpdateGracePeriodinDays=$5
##########################################################################################
### Use Custom Self Service Branding for dialogs as true/false Jamf Parameter $6 ###
customBrandingImagePath=$6
##########################################################################################
### Collecting current user attributes ###
currentUser=$(/bin/ls -l /dev/console | /usr/bin/awk '{print $3}')
currentUserUID=$(/usr/bin/id -u "$currentUser")
currentUserHomeDirectoryPath="$(dscl . -read /Users/$currentUser NFSHomeDirectory | awk -F ': ' '{print $2}')"
##########################################################################################
### Logic to remove a flexibility window if the client is already up to date
if [[ "$(defaults read /Library/Preferences/com.apple.SoftwareUpdate.plist LastUpdatesAvailable)" -eq 0 ]]; then
  echo "Client is up to date, exiting"
  if [[ -f /Library/Preferences/$companyPreferenceDomain.SoftwareUpdatePreferences.plist ]]; then
    echo "Flexibility window preference in Place, removing"
    rm -fv /Library/Preferences/$companyPreferenceDomain.SoftwareUpdatePreferences.plist
  fi
  /usr/local/bin/jamf recon
  exit 0
fi

if [[ ! -f /Library/Preferences/$companyPreferenceDomain.SoftwareUpdatePreferences.plist ]]; then
	echo "Software Update Preferences not yet un place, bailing for now"
	/usr/local/bin/jamf recon
	exit 0
fi
##########################################################################################
### two conditions for which we'll not display the software update notification
### if the Mac is at the login window or if the user has enabled 'do not disturb'
##########################################################################################
if [[ "$currentUser" = "root" ]]; then
  echo "User is not in session, not bothering with presenting the software update notification this time around"
  exit 0
elif [[ "$currentUser" != "root" ]]; then
  doNotDisturbState="$(defaults read $currentUserHomeDirectoryPath/Library/Preferences/ByHost/com.apple.notificationcenterui.plist doNotDisturb)"
  if [[ ${doNotDisturbState} -eq 1 ]]; then
    echo "User has enabled Do Not Disturb, not bothering with presenting the software update notification this time around"
    exit 0
  else
    echo "Do not disturb is disabled, safe to proceed with software update notification"
  fi
fi
##########################################################################################
### Construct the jamfHelper Notification Window
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
  dateMacBecameAwareOfUpdatesNationalRepresentation="$(defaults read /Library/Preferences/$companyPreferenceDomain.SoftwareUpdatePreferences.plist dateMacBecameAwareOfUpdatesNationalRepresentation)"
  gracePeriodWindowCloseDateNationalRepresentation="$(defaults read /Library/Preferences/$companyPreferenceDomain.SoftwareUpdatePreferences.plist gracePeriodWindowCloseDateNationalRepresentation)"
  userUpdateChoice=$("/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper" \
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
    -timeout 300
  )
}

softwareUpdateNotification
##########################################################################################
### User update choice logic. The appropriate software update preference pane will open
### based on the macOS version
if [ "$userUpdateChoice" -eq "2" ]; then
  echo "User chose to defer to a later date, exiting"
  defaults write /Library/Preferences/$companyPreferenceDomain.SoftwareUpdatePreferences.plist UserDeferralDate "$(date "+%Y-%m-%d")"
  exit 0
elif [ "$userUpdateChoice" -eq "0" ]; then
	if [[ $(pgrep "System Preferences") != "" ]]; then
		killall "System Preferences"
	fi
	/bin/launchctl asuser "$currentUserUID" /usr/bin/open "/System/Library/CoreServices/Software Update.app"
fi
