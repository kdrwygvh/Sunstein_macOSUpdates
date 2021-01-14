#!/usr/bin/env zsh

# Title         :Updates_Set OS Software Update Flexibility Window Closure Date.sh
# Description   :Sets the future date after which user flexibility for OS updates will close
# Author        :John Hutchison
# Date          :2020-08-07
# Contact       :john@randm.ltd, john.hutchison@floatingorchard.com
# Version       :1.1
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
preferenceDomain=$4
##########################################################################################
### Enter the number of days flexibility a user has to perform their own updates as script parameter $5 ###
macOSSoftwareUpdateGracePeriodinDays=$5
##########################################################################################
dateMacBecameAwareOfUpdates="$(/bin/date "+%Y-%m-%d")"
dateMacBecameAwareOfUpdatesNationalRepresentation="$(/bin/date "+%A, %B%e")"
flexibilityWindowClosureDate="$(/bin/date -v +"$macOSSoftwareUpdateGracePeriodinDays"d "+%Y-%m-%d")"
flexibilityWindowClosureDateNationalRepresentation="$(/bin/date -v +"$macOSSoftwareUpdateGracePeriodinDays"d "+%A, %B %e")"
softwareUpdatePreferenceFile="/Library/Preferences/$preferenceDomain.SoftwareUpdatePreferences.plist"
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
  defaults write $softwareUpdatePreferenceFile macOSSoftwareUpdateGracePeriodinDays -int "$macOSSoftwareUpdateGracePeriodinDays"
  defaults write $softwareUpdatePreferenceFile DateMacBecameAwareOfUpdates "$dateMacBecameAwareOfUpdates"
  defaults write $softwareUpdatePreferenceFile DateMacBecameAwareOfUpdatesNationalRepresentation "$dateMacBecameAwareOfUpdatesNationalRepresentation"
  defaults write $softwareUpdatePreferenceFile GracePeriodWindowCloseDate "$flexibilityWindowClosureDate"
  defaults write $softwareUpdatePreferenceFile GracePeriodWindowCloseDateNationalRepresentation "$flexibilityWindowClosureDateNationalRepresentation"
  echo "Software Update Flexibility Window Closure Date in Place and datestamped $(defaults read $softwareUpdatePreferenceFile GracePeriodWindowCloseDate)"
}

### Check for the number of ramped updates. A ramped update is one that macOS had downloaded
### and stashed for future installation. If there are no ramped updates and if there is a
### flexibility window preference in effect, remove it as we require updates to be cached first.
##########################################################################################
if [[ "$(defaults read /Library/Preferences/com.apple.SoftwareUpdate LastUpdatesAvailable)" -eq "0" ]]; then
  echo "Client seems to be up to date"
  if [[ -f /Library/Preferences/$preferenceDomain.SoftwareUpdatePreferences.plist ]]; then
    echo "Software Update Release Date Window preferences are stale, removing"
    rm -fv /Library/Preferences/$preferenceDomain.SoftwareUpdatePreferences.plist
    /usr/local/bin/jamf recon
  fi
fi

### check for the number of ramped updates. If there are any, check how many there are. If
### additional updates have been ramped since the last check, reset the flexibility window
### end date
##########################################################################################
if [[ ${macOSSoftwareUpdateGracePeriodinDays} =~ [[:digit:]] ]]; then
  setSoftwareUpdateReleaseDate
else
  echo "'$macOSSoftwareUpdateGracePeriodinDays' is probably not set to an integer, recheck your variables"
fi
