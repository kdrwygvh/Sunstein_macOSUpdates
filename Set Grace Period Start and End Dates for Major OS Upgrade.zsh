#!/bin/zsh

# Title         :Updates_Set OS Major Software Update Flexibility Window Closure Date.sh
# Description   :Sets the future date after which user flexibility for Major OS updates will close
# Author        :John Hutchison
# Date          :2021-04-02
# Contact       :john@randm.ltd, john.hutchison@floatingorchard.com
# Version       :1.0
# Notes         :

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

preferenceDomain=$4 # Required
macOSSoftwareUpdateGracePeriodinDays=$5 # Required
dateMacBecameAwareOfUpdates="$(/bin/date "+%Y-%m-%d")"
dateMacBecameAwareOfUpdatesNationalRepresentation="$(/bin/date "+%A, %B %e")"
gracePeriodWindowClosureDate="$(/bin/date -v +"$macOSSoftwareUpdateGracePeriodinDays"d "+%Y-%m-%d")"
gracePeriodWindowClosureDateNationalRepresentation="$(/bin/date -v +"$macOSSoftwareUpdateGracePeriodinDays"d "+%A, %B %e")"
softwareUpdatePreferenceFile="/Library/Preferences/$preferenceDomain.majorOSSoftwareUpdatePreferences.plist"
appleSoftwareUpdatePreferenceFile="/Library/Preferences/com.apple.SoftwareUpdate.plist"

if [[ $4 == "" ]]; then
  echo "Preference Domain was not set, bailing"
  exit 2
fi

if [[ $5 == "" ]]; then
  echo "Grace period in days was not set, bailing"
  exit 2
fi

setSoftwareUpdateReleaseDate ()

{
  defaults write $softwareUpdatePreferenceFile macOSSoftwareUpdateGracePeriodinDays -int "$macOSSoftwareUpdateGracePeriodinDays"
  if [[ "$(defaults read $softwareUpdatePreferenceFile gracePeriodWindowCloseDate)" = "" ]]; then
		defaults write $softwareUpdatePreferenceFile dateMacBecameAwareOfUpdates "$dateMacBecameAwareOfUpdates"
		defaults write $softwareUpdatePreferenceFile dateMacBecameAwareOfUpdatesNationalRepresentation "$dateMacBecameAwareOfUpdatesNationalRepresentation"
		defaults write $softwareUpdatePreferenceFile gracePeriodWindowCloseDate "$gracePeriodWindowClosureDate"
		defaults write $softwareUpdatePreferenceFile gracePeriodWindowCloseDateNationalRepresentation "$gracePeriodWindowClosureDateNationalRepresentation"
  	echo "New Software Update Grace Period Closure Date in Place and datestamped $(defaults read $softwareUpdatePreferenceFile gracePeriodWindowCloseDate)"
  else
  	echo "Software Update Flexibility is already in place, continuing..."
  fi
}

if [[ "$preferenceDomain" == "" ]]; then
	echo "Preference Domain not set as a jamf variable, bailing"
	exit 2
fi
if [[ "$macOSSoftwareUpdateGracePeriodinDays" = "" ]]; then
	echo "Grace Period not set as a jamf variable, bailing"
	exit 2
fi

if [[ "$majorOSUpgradeID" = "" ]]; then
  echo "Client seems to be up to date"
  if [[ -f "$softwareUpdatePreferenceFile" ]]; then
    echo "Software Update Release Date Window preferences are stale, removing"
    rm -fv "$softwareUpdatePreferenceFile"
    /usr/local/bin/jamf recon
  fi
  exit 0
else
	setSoftwareUpdateReleaseDate
fi
