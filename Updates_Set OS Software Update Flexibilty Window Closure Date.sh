#!/usr/bin/env zsh

# Title         :Updates_Set OS Software Update Flexibility Window Closure Date.sh
# Description   :Sets the future date after which user flexibility for OS updates will close
# Author        :John Hutchison
# Date          :2020.04.21
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


### Enter your organization's preference domain as script parameter $4 ###
companyPreferenceDomain=$4
##########################################################################################
### Enter the number of days flexibility a user has to perform their own updates as script parameter $5 ###
macOSSoftwareUpdateGracePeriodinDays=$5
##########################################################################################

### Determine the major macOS version Number ###
macOSMajorVersion=$(sw_vers -productVersion | awk -F '.' '{print $2}')
##########################################################################################
### Sanity check to ensure that Jamf variables have been set
if [[ $4 == "" || $5 == "" ]]; then
  echo "Jamf variables 4 or 5 are not defined as part of the currently running policy, bailing"
  exit 1
fi

### Function to set the flexibility window open and close dates with both parsable and human
### readable date formats set for the jamfHelper dialogs
function setSoftwareUpdateReleaseDate ()
{
  defaults write /Library/Preferences/$companyPreferenceDomain.SoftwareUpdatePreferences.plist macOSSoftwareUpdateGracePeriodinDays -int "$macOSSoftwareUpdateGracePeriodinDays"

  defaults write /Library/Preferences/$companyPreferenceDomain.SoftwareUpdatePreferences.plist numberofAvailableUpdates -int "$numberofAvailableUpdates"

  defaults write /Library/Preferences/$companyPreferenceDomain.SoftwareUpdatePreferences.plist DateMacBecameAwareOfUpdates "$(date "+%Y-%m-%d")"

  defaults write /Library/Preferences/$companyPreferenceDomain.SoftwareUpdatePreferences.plist DateMacBecameAwareOfUpdatesNationalRepresentation "$(/bin/date "+%A, %B %e")"

  defaults write /Library/Preferences/$companyPreferenceDomain.SoftwareUpdatePreferences.plist GracePeriodWindowCloseDate $(/bin/date -v +"$macOSSoftwareUpdateGracePeriodinDays"d "+%Y-%m-%d")

  defaults write /Library/Preferences/$companyPreferenceDomain.SoftwareUpdatePreferences.plist GracePeriodWindowCloseDateNationalRepresentation "$(/bin/date -v +"$macOSSoftwareUpdateGracePeriodinDays"d "+%A, %B %e")"

  echo "Software Update Grace Period Window Closure Date in Place and Datestamped $(defaults read /Library/Preferences/$companyPreferenceDomain.SoftwareUpdatePreferences.plist GracePeriodWindowCloseDate)"
}

### check for the number of ramped updates. If there are none and if there is a flexibility
### window end date in effect, remove it.
numberofAvailableUpdates=$(find /Library/Updates -name "???-?????" | grep -c '/')
if [[ ${numberofAvailableUpdates} -eq 0 ]]; then
  echo "Client has updates available but updates have not yet been cached, leaving timer unchanged"
  if [[ -f /Library/Preferences/$companyPreferenceDomain.SoftwareUpdatePreferences.plist ]]; then
    echo "Software Update Release Date Window preferences are stale, removing"
    rm -v /Library/Preferences/$companyPreferenceDomain.SoftwareUpdatePreferences.plist
    /usr/local/bin/jamf recon
  fi
fi

### check for the number of ramped updates. If there are any, check how many there are. If
### additional updates have been ramped since the last check, reset the flexibility window
### end date
if [[ ${numberofAvailableUpdates} -gt 0 ]]; then
  if [[ -f /Library/Preferences/$companyPreferenceDomain.SoftwareUpdatePreferences.plist ]]; then
    echo "Software Update Release Date in Place, checking number of available updates against last known number"
    if [[ ${numberofAvailableUpdates} -gt $(defaults read /Library/Preferences/$companyPreferenceDomain.SoftwareUpdatePreferences.plist numberofAvailableUpdates) ]]; then
      echo "Additional updates have become available since last check, resetting flexibility window dates"
      setSoftwareUpdateReleaseDate
    fi
    echo "Flexibility window dates are in place"
  elif [[ ${macOSSoftwareUpdateGracePeriodinDays} =~ [[:digit:]] ]]; then
    setSoftwareUpdateReleaseDate
  else
    echo "'$macOSSoftwareUpdateGracePeriodinDays' may not be set to a number, check your variables"
  fi
fi
