#!/usr/bin/env zsh

# Title         :Updates_Set OS Software Update Flexibility Window Closure Date.sh
# Description   :Sets the future date after which user flexibility for OS updates will close
# Author        :John Hutchison
# Date          :2021-03-25
# Contact       :john@randm.ltd, john.hutchison@floatingorchard.com
# Version       :1.2.1
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
dateMacBecameAwareOfUpdatesNationalRepresentation="$(/bin/date "+%A, %B %e")"
gracePeriodWindowClosureDate="$(/bin/date -v +"$macOSSoftwareUpdateGracePeriodinDays"d "+%Y-%m-%d")"
gracePeriodWindowClosureDateNationalRepresentation="$(/bin/date -v +"$macOSSoftwareUpdateGracePeriodinDays"d "+%A, %B %e")"
softwareUpdatePreferenceFile="/Library/Preferences/$preferenceDomain.SoftwareUpdatePreferences.plist"
##########################################################################################

### Sanity checks to ensure that Jamf variables have been set
if [[ $4 == "" ]]; then
  echo "Preference Domain was not set, bailing"
  exit 2
fi
if [[ $5 == "" ]]; then
  echo "Software Update Grace Period was not set, bailing"
  exit 2
fi
if [[ ${macOSSoftwareUpdateGracePeriodinDays} != [[:digit:]] ]]; then
	echo "Grace Period in Days doesn't appear to be an integer, bailing"
	exit 2
fi

### Function to set the flexibility window open and close dates with both parsable and human
### readable date formats set for the jamfHelper dialogs
setSoftwareUpdateReleaseDate ()

	{
		defaults write $softwareUpdatePreferenceFile macOSSoftwareUpdateGracePeriodinDays -int "$macOSSoftwareUpdateGracePeriodinDays"
		if [[ "$(defaults read $softwareUpdatePreferenceFile gracePeriodWindowCloseDate)" = "" ]]; then
			defaults write $softwareUpdatePreferenceFile dateMacBecameAwareOfUpdates "$dateMacBecameAwareOfUpdates"
			defaults write $softwareUpdatePreferenceFile dateMacBecameAwareOfUpdatesNationalRepresentation "$dateMacBecameAwareOfUpdatesNationalRepresentation"
			defaults write $softwareUpdatePreferenceFile gracePeriodWindowCloseDate "$gracePeriodWindowClosureDate"
			defaults write $softwareUpdatePreferenceFile gracePeriodWindowCloseDateNationalRepresentation "$gracePeriodWindowClosureDateNationalRepresentation"
			echo "New Software Update Flexibility Window Closure Date in Place and datestamped $(defaults read $softwareUpdatePreferenceFile GracePeriodWindowCloseDate)"
		else
			echo "Software Update Flexibility is already in place, continuing..."
		fi
	}

### Check for the number of available updates. If none are found, assume the current
### timers are stale and remove them
##########################################################################################
if [[ "$(defaults read /Library/Preferences/com.apple.SoftwareUpdate LastUpdatesAvailable)" -eq "0" ]]; then
  echo "Client seems to be up to date"
  if [[ -f /Library/Preferences/$preferenceDomain.SoftwareUpdatePreferences.plist ]]; then
    echo "Software Update Release Date Window preferences are stale, removing"
    rm -fv /Library/Preferences/$preferenceDomain.SoftwareUpdatePreferences.plist
    /usr/local/bin/jamf recon
  fi
else
	setSoftwareUpdateReleaseDate
fi
