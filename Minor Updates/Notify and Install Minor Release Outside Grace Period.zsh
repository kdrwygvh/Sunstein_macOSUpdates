#!/bin/zsh

# Title         :Notify and Install Minor Release Outside Grace Period.zsh
# Description   :
# Author        :John Hutchison
# Date          :2021-07-22
# Contact       :john@randm.ltd, john.hutchison@floatingorchard.com
# Version       :1.2.1.2
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

plistBuddy="/usr/libexec/PlistBuddy"
companyPreferenceDomain=$4 # Required
customBrandingImagePath=$5 # Optional
mdmSoftwareUpdateEvent=$6 # Required
notificationTitle="$7" #Optional
updateAttitude=$8 # Optional passive or aggressive, defaults to passive
aggressiveUpdateIdleTimeinMinutes=$9 # Required if aggressive attitude is set
respectDNDApplications=${10} # Required
currentUser=$(/bin/ls -l /dev/console | /usr/bin/awk '{print $3}')
currentUserUID=$(/usr/bin/id -u "$currentUser")
currentUserHomeDirectoryPath="$(dscl . -read /Users/"$currentUser" NFSHomeDirectory | awk -F ': ' '{print $2}')"
jamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
jamfNotificationHelper="/Library/Application Support/JAMF/bin/Management Action.app/Contents/MacOS/Management Action"
softwareUpdatePreferenceFile="/Library/Preferences/$companyPreferenceDomain.SoftwareUpdatePreferences.plist"
dateMacBecameAwareOfUpdatesSeconds=$($plistBuddy -c "Print:dateMacBecameAwareOfUpdatesSeconds" "$softwareUpdatePreferenceFile")
wayOutsideGracePeriodAgeOutinSeconds=$($plistBuddy -c "Print:wayOutsideGracePeriodAgeOutinSeconds" "$softwareUpdatePreferenceFile")
currentDateinSeconds=$(/bin/date +%s)

# macOSVersionMarketingCompatible is the commerical version number of macOS (10.x, 11.x)
# macOSVersionEpoch is the major version number and is meant to draw a line between Big Sur and all prior versions of macOS
# macOSVersionMajor is the current dot releaes of macOS (15 in 10.15)
macOSVersionMarketingCompatible="$(sw_vers -productVersion)"
macOSVersionEpoch="$(awk -F '.' '{print $1}' <<<"$macOSVersionMarketingCompatible")"
macOSVersionMajor="$(awk -F '.' '{print $2}' <<<"$macOSVersionMarketingCompatible")"

declare -a doNotDisturbAppBundleIDs=(
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

if [[ "$customBrandingImagePath" != "" ]]; then
  dialogImagePath="$customBrandingImagePath"
elif [[ "$customBrandingImagePath" = "" ]]; then
  if [[ -f "/System/Library/PreferencePanes/SoftwareUpdate.prefPane/Contents/Resources/SoftwareUpdate.icns" ]]; then
    dialogImagePath="/System/Library/PreferencePanes/SoftwareUpdate.prefPane/Contents/Resources/SoftwareUpdate.icns"
  else
    dialogImagePath="/Applications/App Store.app/Contents/Resources/AppIcon.icns"
  fi
fi

softwareUpdateNotification() {

  "$jamfHelper" \
    -windowType utility \
    -windowPosition ur \
    -title "$notificationTitle" \
    -description "Updates are available which we'd suggest installing today at your earliest convenience.

You'll be presented with available updates to install after clicking 'Review'" \
  	-alignDescription left \
  	-icon "$dialogImagePath" \
  	-button1 "Review" \
  	-defaultButton 0 \
  	-timeout 300 \
    -startlaunchd &
  wait $!
}

aggressiveAttitudeNotification() {

  "$jamfHelper" \
    -windowType utility \
    -windowPosition ur \
    -title "$notificationTitle" \
    -description "System updates must be applied now
which will restart your Mac in about 15 minutes. Please stand by..." \
    -alignDescription left \
    -icon "$dialogImagePath" \
    -button1 "OK" \
    -defaultButton 0 \
    -timeout 300 \
    -startlaunchd &
}

if [[ $4 == "" ]]; then
  echo "Preference Domain was not set, bailing"
  exit 2
fi

if [[ $6 == "" ]]; then
  echo "Policy event to trigger MDM update not set, bailing"
  exit 2
fi

if [[ $8 == "" ]]; then
  echo "Update attitude not set, assuming passive operation"
  updateAttitude="passive"
fi

if [[ $9 != "" ]]; then
	echo "Converting idle time in minutes to seconds"
	aggressiveUpdateIdleTimeinSeconds=$(($aggressiveUpdateIdleTimeinMinutes*60))
elif [[ $9 == "" && $updateAttitude = "aggressive" ]]; then
	echo "aggressive update attitude set but no idle time in minutes is set, bailing"
	exit 2
fi

if [[ ! -f "$softwareUpdatePreferenceFile" ]]; then
  echo "Software Update Preferences not yet in place, bailing for now"
  exit 0
fi

availableUpdateManifest=$(/usr/libexec/mdmclient AvailableOSUpdates)
availableConfigDataUpdates=$(grep -c "IsConfigDataUpdate = 1" <<<$availableUpdateManifest)
availableFirmwareUpdates=$(grep -c "IsFirmwareUpdate = 1" <<<$availableUpdateManifest)
availableUpdateRequiresRestart=$(grep -c "RestartRequired = 1" <<<$availableUpdateManifest)
availableRecommendedUpdates=$(grep -c "RestartRequired = 0" <<<$availableUpdateManifest)
availableCriticalUpdates=$(grep -c "IsCritical = 1" <<<$availableUpdateManifest)
numberofDeferredUpdates=$(grep -c "DeferredUntil" <<<$availableUpdateManifest)
deferredUpdateAvailabilityDate=$(grep "DeferredUntil" <<<$availableUpdateManifest | awk '{print $3}' | sed 's/\"//')

if [[ $availableUpdateRequiresRestart -eq "0" ]] && [[ $availableRecommendedUpdates -eq "0" ]]; then
  echo "Client is up to date or has not yet identified needed updates, exiting"
  if [[ -e "$softwareUpdatePreferenceFile" ]]; then
  	defaults delete "$softwareUpdatePreferenceFile"
  	rm "$softwareUpdatePreferenceFile"
  	exit 0
  fi
fi

if [[ "$availableRecommendedUpdates" -gt "0" ]]; then
  echo "No updates found which require a restart, but we'll run softwareupdate to install any other outstanding updates."
  softwareupdate --install --recommended --verbose
  exit 0
fi
if [[ "$currentUser" = "root" ]]; then
  echo "User is not in session, safe to perform all updates and restart now if required"
  if [[ "$availableUpdateRequiresRestart" -ge "1" ]]; then
    echo "Updates found which require restart. Installing and restarting...but only on Intel based systems"
    if [[ "$(arch)" = "arm64" ]]; then
      echo "Command line updates are not supported on Apple Silicon, falling back to installation via MDM event"
      /usr/local/bin/jamf policy -event "$mdmSoftwareUpdateEvent" -verbose
    else
      softwareupdate --install --all --restart --verbose
      exit 0
    fi
  else
  	echo "No updates to apply, exiting"
  	exit 0
  fi
else
  for doNotDisturbAppBundleID in ${doNotDisturbAppBundleIDs[@]}; do
    frontAppASN="$(lsappinfo front)"
    frontAppBundleID="$(lsappinfo info -app $frontAppASN | grep bundleID | awk -F '=' '{print $2}' | sed 's/\"//g')"
    if [[ "$frontAppBundleID" = "$doNotDisturbAppBundleID" ]] && [[ "$respectDNDApplications" = "true" ]]; then
      echo "Do not disturb app $frontAppBundleID is frontmost, not displaying notification"
      exit 0
    fi
  done
  if [[ $(ioreg -c IOHIDSystem | awk '/HIDIdleTime/ {print int($NF/1000000000)}') -ge "$aggressiveUpdateIdleTimeinSeconds" && "$updateAttitude" == "aggressive" ]]; then
    echo "User has been idle for $aggressiveUpdateIdleTimeinSeconds seconds and aggressive attitude is set, updating and restarting now"
    aggressiveAttitudeNotification
    if [[ "$(arch)" = "arm64" ]]; then
      echo "Command line updates are not supported on Apple Silicon, falling back to installation via MDM event"
      /usr/local/bin/jamf policy -event "$mdmSoftwareUpdateEvent" -verbose
      "$jamfNotificationHelper" -message "Automatic updates will be applied now and your Mac will restart"
    else
      if softwareupdate --install --all --restart --verbose; then
      	echo "software updates were successfully applied, notifying user and restarting"
      	"$jamfNotificationHelper" -message "Automatic updates were applied on $(/bin/date "+%A, %B %e")"
      	exit 0
      else
      	echo "something went wrong with applying the software update, notifying the user"
      	"$jamfNotificationHelper" -message "Update has been stopped due to a problem. We'll try again later..."
      	killall "jamfHelper"
      	exit 1
      fi
    fi
  fi
  if [[ "$currentDateinSeconds" -gt "$wayOutsideGracePeriodAgeOutinSeconds" ]] && [[ "$updateAttitude" == "aggressive" ]]; then
    echo "Mac is way outside the defined grace period and aggressive attitude is set, updating and restarting now"
    aggressiveAttitudeNotification
    if [[ "$(arch)" = "arm64" ]]; then
      echo "Command line updates are not supported on Apple Silicon, falling back to installation via MDM event"
      /usr/local/bin/jamf policy -event "$mdmSoftwareUpdateEvent" -verbose
      "$jamfNotificationHelper" -message "Automatic updates were applied on $(/bin/date "+%A, %B %e")"
    else
      if softwareupdate --install --all --restart --verbose; then
      	echo "software updates were successfully applied, notifying user and restarting"
      	"$jamfNotificationHelper" -message "Automatic updates were applied on $(/bin/date "+%A, %B %e")"
      	exit 0
      else
      	echo "something went wrong with applying the software update, notifying the user"
      	"$jamfNotificationHelper" -message "Update has been stopped due to a problem. We'll try again later..."
      	killall "jamfHelper"
      	exit 1
      fi
    fi
  fi
  if [[ "$updateAttitude" = "passive" ]]; then
    softwareUpdateNotification
    if [[ "$macOSVersionEpoch" -ge "11" || "$macOSVersionMajor" -ge "14" ]]; then
      echo "Opening Software Update Preference Pane for user review"
      /bin/launchctl asuser "$currentUserUID" pkill "System Preferences"
      sleep 5
      /bin/launchctl asuser "$currentUserUID" /usr/bin/open "x-apple.systempreferences:com.apple.preferences.softwareupdate"
    elif [[ "$macOSVersionMajor" -le "13" ]]; then
      echo "opening Mac App Store Update Pane for user review"
      /bin/launchctl asuser "$currentUserUID" pkill "App Store"
      sleep 5
      /bin/launchctl asuser "$currentUserUID" /usr/bin/open "macappstore://showUpdatesPage"
    fi
  fi
fi

