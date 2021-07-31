#!/bin/bash

# Title         :macOS Download Upgrade Reinstall Erase.sh
# Description   :Performs an upgrade, reinstall, or erase of macOS based on Jamf variables
# Author        :John Hutchison
# Date          :2021-05-18
# Contact       :john@randm.ltd, john.hutchison@floatingorchard.com
# Version       :1.3.2.1
# Notes         : Updated to support disk spce checking on HFS+ filesystems
#                 Updated to use custom installer paths
#                 Updated to do variable free space checks based target upgrade OS
#                 Updated to allow for download of macOS in the absence of an interactive login
#                 Updated to account for multiple copies of macOS Install.app on disk
#                 Added Do Not Disturb checks

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
# NO EXPRESS OR IMPLIED LICENSES TO ANY PARTY'S PATENT RIGHTS ARE GRANTED BY
# THIS LICENSE. THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
# CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR Ax`
# PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
# BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
# IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

# WARNING: If you regularly package macOS Installers using Packages, Composer etc... you
# probably do not want to use this tool on yourself. It will delete any outdated installers
# it finds in favor of the version specified during script execution. Use responsibly.

# Notes on Bundle Versions of the macOS Installer App
# Additional info for Big Sur Installers available at
# https://mrmacintosh.com/macos-big-sur-full-installer-database-download-directly-from-apple/

# 14.6.06 -eq 10.14.6
# 15.6.00 -eq 10.15.6
# 15.7.03 -eq 10.15.7
#
# 16.4.06 -eq 11.2.1
# 16.4.07 -eq 11.2.2
# 16.4.08 -eq 11.2.3
# 16.5.01 -eq 11.3
# 16.5.02 -eq 11.3.1
# 16.6.01 -eq 11.4
# 16.7.01 -eq 11.5
# 16.7.02 -eq 11.5.1
# 17.0.11 -eq 12.0 public beta (21A5268h)

# Jamf Variable Label names

# $4 -eq Installer Name (e.g. Install macOS Big Sur)
# $5 -eq Preferred Installer Version (e.g. 16.5.01)
# $6 -eq Installer Download Version from Apple CDN (e.g. 11.3)
# $7 -eq Installer Download Jamf Event (10.14 and Prior)
# $8 -eq Install Action (downloadonly, upgrade, reinstall, erase)
# $9 -eq Suppress all Notifications (true/false)
# $10 -eq Custom Logo Path for Notifications
# $11 -eq Perform Network Link Evaluation (true/false)

# Certain security products, network proxies, or filters may prevent some or all of the
# network link tests from passing while allowing software updates in general. Test.

# Installer Variables
installerName="$4" # Required
macOSPreferredBundleVersion="$5" # Required
macOSDownloadVersion="$6" # Required
macOSInstallAppJamfEvent="$7" # Optional
installAction="$8" # Required
runHeadless="$9" # Required
logoPath=${10} # Optional
networkLinkEvaluation=${11} # Required true/false

# Check required variables

if [[ "$installerName" = "" ]]; then echo "Installer Name was not set, bailing"; exit 2; fi
if [[ "$macOSDownloadVersion" = "" ]]; then echo "Installer Download Version was not set, bailing"; exit 2; fi
if [[ "$installAction" = "" ]]; then echo "Install Action was not set, bailing"; exit 2; fi
if [[ "$runHeadless" = "" ]]; then echo "Headless preference was not set, bailing"; exit 2; fi
if [[ "$networkLinkEvaluation" = "" ]]; then echo "Network Link Evaluation preference was not set, bailing"; exit 2; fi

# jamfHelper path
jamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"

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

# Convert POSIX path of logoPATH icon to Mac path for AppleScript.
logoPath_POSIX="$(/usr/bin/osascript -e 'tell application "System Events" to return POSIX file "'"$logoPath"'" as text')"

# Collecting current user attributes ###
currentUser=$(/bin/ls -l /dev/console | /usr/bin/awk '{print $3}')
currentUserUID=$(/usr/bin/id -u "$currentUser")
currentUserHomeDirectoryPath="$(dscl . -read /Users/$currentUser NFSHomeDirectory | awk -F ': ' '{print $2}')"

# Collect the OS version in various formats
# macOSVersionMarketingCompatible is the commerical version number of macOS (10.x, 11.x)
# macOSVersionEpoch is the major version number and is meant to draw a line between Big Sur and all prior versions of macOS
# macOSVersionMajor is the current dot releaes of macOS (15 in 10.15)

macOSVersionMarketingCompatible="$(sw_vers -productVersion)"
macOSVersionEpoch="$(awk -F '.' '{print $1}' <<<"$macOSVersionMarketingCompatible")"
macOSVersionMajor="$(awk -F '.' '{print $2}' <<<"$macOSVersionMarketingCompatible")"

# Do Not Disturb variables and functions
doNotDisturbApplePlistID='com.apple.ncprefs'
doNotDisturbApplePlistKey='dnd_prefs'
doNotdisturbApplePlistLocation="$currentUserHomeDirectoryPath/Library/Preferences/$doNotDisturbApplePlistID.plist"

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

# Function declarations

# checkBatteryStatus checks the charge on the battery if battery is the power source. If we're at below 25% we throw the user an error
# checkavailableDiskSpaceAPFS checks the available free space in bytes on APFS volumes. It's recommended to use Jamf smart groups to find clients with enough free space but we can accurately collect this dynamically as long as the underlying filesystem is APFS
# downloadOSInstaller will check for a current version of the OS installer on disk and download a fresh copy from either Apple or JamfCloud
# passwordpromptAppleSilicon prompts the user for their credential to authenticate software installs on Aople Silicon
# startOSInstaller starts the startosinstall process with all arguments collected during the rest of this script execution

preUpgradeJamfPolicies ()
{
  jamfPolicyEvents=(
    ""
  )

  if [[ "${jamfPolicyEvents[*]}" = "" ]]; then
    echo "No Jamf policies specified, continuing"
  else
    for jamfPolicy in "${jamfPolicyEvents[@]}"; do
      echo "Running Jamf policy with event name $jamfPolicy prior to macOS Install"
      /usr/local/bin/jamf policy -event "$jamfPolicy" -verbose
    done
  fi
}

resetIgnoredUpdates ()
{
  ignoredUpdates=$(defaults read /Library/Preferences/com.apple.SoftwareUpdate.plist InactiveUpdates)
  if [[ "$ignoredUpdates" =~ "macOS" ]]; then
    echo "at least one major upgrade is being ignored, resetting now to guarantee successful download from Appple CDN"
    softwareupdate --reset-ignored
  fi
}

networkLinkEvaluation ()
{
  if [[ "$networkLinkEvaluation" = "false" ]]; then
    echo "Network link evaluation set to false, skipping"
  elif [[ ! -f /usr/bin/sysdiagnose ]]; then
    echo "sysdiagnose is not present, skipping network evaluation"
  else
    /bin/launchctl asuser "$currentUserUID" "$jamfHelper" -windowType "utility" \
    -icon "$logoPath" \
    -title "Checking Network" \
    -description "Performing initial network check. If the network is slow or fails certain reachability checks you'll be asked to try another Wi-Fi network..." \
    -startlaunchd &
    sysdiagnose -v -A sysdiagnose.preInstall."$(date "+%m.%d.%y")" -n -F -S -u -Q -b -g -R
    # Gather Network State Details
    diagnosticsConfiguration="/var/tmp/sysdiagnose.preInstall.$(date "+%m.%d.%y")/WiFi/diagnostics-configuration.txt"
    wifiSignalState=$(grep "Poor Wi-Fi Signal" "$diagnosticsConfiguration" | grep -c "Yes")
    legacyWifiState=$(grep "Legacy Wi-Fi Rates (802.11b)" "$diagnosticsConfiguration" | grep -c "Yes")
    iosHotspotState=$(grep "iOS Personal Hotspot" "$diagnosticsConfiguration" | grep -c "Yes")
    # Gather Network Reachability Details
    diagnosticsConnectivity="/var/tmp/sysdiagnose.preInstall.$(date "+%m.%d.%y")/WiFi/diagnostics-connectivity.txt"
    appleCurlResult=$(grep "Curl Apple" "$diagnosticsConfiguration" | grep -c "No")
    appleReachabilityResult=$(grep "Reach Apple" "$diagnosticsConfiguration" | grep -c "No")
    dnsResolutionResult=$(grep "Resolve DNS" "$diagnosticsConfiguration" | grep -c "No")
    wanPingResult=$(head -1 "$diagnosticsConfiguration" | grep "Ping WAN" "$diagnosticsConfiguration" | grep -c "No")
    lanPingResult=$(head -1 "$diagnosticsConfiguration" | grep "Ping LAN" "$diagnosticsConfiguration" | grep -c "No")
    # Gather Network Congestion Details
    diagnosticsEnvironment="/var/tmp/sysdiagnose.preInstall.$(date "+%m.%d.%y")/WiFi/diagnostics-environment.txt"
    congestedNetworkResult=$(grep "Congested Wi-Fi Channel" "$diagnosticsEnvironment" | grep -c "Yes")
    # Echo all results
    echo "Wi-Fi Signal Result=$wifiSignalState"
    echo "Legacy Wi-Fi Result=$legacyWifiState"
    echo "iOS Hotspot Result=$iosHotspotState"
    echo "captive.apple.com curl Result=$appleCurlResult"
    echo "apple.com reachability Result=$appleReachabilityResult"
    echo "DNS Resolution Result=$dnsResolutionResult"
    echo "WAN Ping Result=$wanPingResult"
    echo "LAN Ping Result=$lanPingResult"
    echo "Congested Network Result=$congestedNetworkResult"
    chown -R root:admin /var/tmp/sysdiagnose.preInstall."$(date "+%m.%d.%y")"
    chmod -R 700 /var/tmp/sysdiagnose.preInstall."$(date "+%m.%d.%y")"
    # Kill the previous jamfHelper window if it's still up
    killall jamfHelper
    if [[ "$currentUser" = "root" ]]; then
      echo "Nobody logged in, suppressing network link results"
    else
      if [[ "$congestedNetworkResult" -eq 1 ]]; then
        echo "Network link is congested, suggest to the user they close the distance between them and the Wi-fi router"
        /bin/launchctl asuser "$currentUserUID" "$jamfHelper" -windowType "utility" \
        -icon "$logoPath" \
        -title "Network" \
        -description "Your current Wi-Fi network appears to be congested. Please move as close as possible to your Wi-Fi router for the duration of the upgrade" \
        -button1 "OK" \
        -defaultButton 1 \
        -startlaunchd &>/dev/null
      fi
      if [[ "$wifiSignalState" -eq 1 ]]; then
        echo "Network link is weak, suggest to the user that they move as close as possible to the Wi-Fi source"
        /bin/launchctl asuser "$currentUserUID" "$jamfHelper" -windowType "utility" \
        -icon "$logoPath" \
        -title "Network" \
        -description "Your current Wi-Fi signal appears to be weaker than normal. Please move as close as possible to your Wi-Fi router for the duration of the upgrade" \
        -button1 "OK" \
        -defaultButton 1 \
        -startlaunchd &>/dev/null
      fi
      if [[ "$iosHotspotState" -eq 1 ]]; then
        echo "Network link is a hotspot, warning the user to try again later"
        /bin/launchctl asuser "$currentUserUID" "$jamfHelper" -windowType "utility" \
        -icon "$logoPath" \
        -title "Network" \
        -description "OS Upgrades are not supported on personal hotspot networks. Please try again later on another Wi-Fi network" \
        -button1 "Stop" \
        -defaultButton 1 \
        -startlaunchd &>/dev/null
        exit 2
      fi
      if [[ "$appleCurlResult" -eq 1 ]] || [[ "$appleReachabilityResult" -eq 1 ]] || [[ "$dnsResolutionResult" -eq 1 ]]; then
        echo "Connectivity to Apple's servers and/or DNS resolution tests failed on this network, suggesting to the user they try again later on a different network"
        /bin/launchctl asuser "$currentUserUID" "$jamfHelper" -windowType "utility" \
        -icon "$logoPath" \
        -title "Network" \
        -description "This network doesn't appear to support Apple software updates, please try another Wi-Fi network" \
        -button1 "Stop" \
        -defaultButton 1 \
        -startlaunchd &>/dev/null
        exit 2
      fi
    fi
  fi
}

checkBatteryStatus ()
{
  currentPowerDrawStatus=$(pmset -g batt | head -n 1)
  if [[ "$currentPowerDrawStatus" =~ "Now drawing from 'Battery Power'" ]]; then
    batteryMaximumCapacity=$(ioreg -r -c "AppleSmartBattery" | grep '"MaxCapacity"' | tail -n 1 | awk -F ' = ' '{print $2}')
    batteryCurrentCapacity=$(ioreg -r -c "AppleSmartBattery" | grep '"CurrentCapacity"' | tail -n 1 | awk -F ' = ' '{print $2}')
    batteryPercentage=$(echo "scale=4; ($batteryCurrentCapacity / $batteryMaximumCapacity) * 100" | bc | awk -F '.' '{print $1}')

    if [ "$batteryPercentage" -lt 50 ]; then
      echo "Aborting installation as battery level is too low to proceed safely"
      if [[ "$currentUser" = "root" ]]; then
        echo "Nobody logged in, suppressing battery results"
      else
        /bin/launchctl asuser "$currentUserUID" "$jamfHelper" -windowType "utility" \
        -icon "$logoPath" \
        -title "Battery" \
        -description "Not enough charge remains in your battery to continue. Please plug your Mac into a wall outlet and try again" \
        -button1 "Stop" \
        -defaultButton 1 \
        -startlaunchd &>/dev/null
        exit 1
      fi
    else
      echo "Battery level currently at $batteryPercentage, proceeding"
    fi
  fi
}

checkAvailableDiskSpace ()
{
  availableDiskSpaceBytes=$(diskutil info / | grep -E 'Container Free Space|Volume Free Space' | awk '{print $6}' | sed "s/(//")
  availableDiskSpaceMeasure=$(diskutil info / | grep -E 'Container Free Space|Volume Free Space' | awk '{print $5}')
  if [[ "$availableDiskSpaceMeasure" = "TB" ]]; then
    echo "at least 1 TB of space is available, continuing"
  elif [[ "$availableDiskSpaceMeasure" = "GB" && "$availableDiskSpaceBytes" -ge "48000000000" ]]; then
    echo "at least 48 GB of space is available, enough free space for any OS upgrade, continuing"
  elif [[ "$installerName" = "Install macOS Catalina" && "$macOSVersionMajor" -le "10" ]]; then
    echo "Yosemite or earlier requires at least 19GB of free space + the 10GB needed for the installer, checking"
    if [[ "$availableDiskSpaceBytes" -ge "29000000000" ]]; then
      echo "at least 29GB of space is available, continuing"
    else
      echo "not enough free disk space to perform the upgrade, letting the user know and exiting"
      willNotifyDiskSpaceWarning="true"
    fi
  elif [[ "$installerName" = "Install macOS Catalina" && "$macOSVersionMajor" -ge "11" ]]; then
    echo "El Capitan or greater requires at least 13GB of free space + the 10GB needed for the installer, checking"
    if [[ "$availableDiskSpaceBytes" -ge "23000000000" ]]; then
      echo "at least 23GB of space is available, continuing"
    else
      echo "not enough free disk space to perform the upgrade, letting the user know and exiting"
      willNotifyDiskSpaceWarning="true"
    fi
  elif [[ "$installerName" = "Install macOS Big Sur" && "$macOSVersionMajor" -ge "12" ]]; then
    echo "Sierra or greater requires at least 36GB of free space + the 12GB needed for the installer, checking"
    if [[ "$availableDiskSpaceBytes" -ge "48000000000" ]]; then
      echo "at least 48GB of space is available, continuing"
    else
      echo "not enough free disk space to perform the upgrade, letting the user know and exiting"
      willNotifyDiskSpaceWarning="true"
    fi
  elif [[ "$installerName" = "Install macOS Big Sur" && "$macOSVersionMajor" -lt "12" ]]; then
    echo "El Capitan or earlier requires at least 45GB of free space + the 12GB needed for the installer, checking"
    if [[ "$availableDiskSpaceBytes" -ge "57000000000" ]]; then
      echo "at least 57GB of space is available, continuing"
    else
      echo "not enough free disk space to perform the upgrade, letting the user know and exiting"
      willNotifyDiskSpaceWarning="true"
    fi
  fi
  if [[ "$willNotifyDiskSpaceWarning" = "true" ]]; then
    /bin/launchctl asuser "$currentUserUID" "$jamfHelper" -windowType "utility" \
    -icon "$logoPath" \
    -title "Disk Space" \
    -description "Not enough disk space remains to perform the upgrade. You can review your space from the Apple Menu -> About this Mac -> Storage -> Manage. Try to free up at least 25 GB for Catalina and 30-40 GB for Big Sur" \
    -button1 "Review Storage" \
    -defaultButton 1 \
    -timeout 300 \
    -startlaunchd &>/dev/null &
    wait $!
    if [[ -d "/System/Library/CoreServices/Applications/Storage Management.app" ]]; then
      /bin/launchctl asuser "$currentUserUID" open -a "/System/Library/CoreServices/Applications/Storage Management.app"
    else
      /bin/launchctl asuser "$currentUserUID" open "https://support.apple.com/en-us/HT206996#manually"
    fi
  fi
}

downloadOSInstaller ()
{
    installerCount="$(mdfind -name "$installerName" | grep -v '\.bom\|\.plist' | wc -l | sed "s/^[ \t]*//")"
    if [[ "$installerCount" -eq "0" ]]; then
      echo "No installers present, downloading a fresh copy"
      installerPath="/Applications/$installerName.app"
      startOSInstall="$installerPath"/Contents/Resources/startosinstall
      willDownload="true"
    elif [[ "$installerCount" -ge "1" ]]; then
      installerPaths="$(mdfind -name "$installerName" -0 | xargs -I {} -0 echo {} | grep -v '\.bom\|\.plist')"
      echo "Found installers at "$installerPaths", checking version"
      IFS=$'\n'
      for installer in $installerPaths; do
        macOSInstallerCurrentBundleVersion=$(/usr/libexec/PlistBuddy -c "Print:CFBundleShortVersionString" "$installer"/Contents/Info.plist)
        if [[ "$macOSInstallerCurrentBundleVersion" != "$macOSPreferredBundleVersion" ]]; then
          echo "Version on disk does not match, removing"
          rm -rdf "$installer"
          installerPath="/Applications/$installerName.app"
          startOSInstall="$installerPath"/Contents/Resources/startosinstall
          willDownload="true"
        else
          echo "Version of installer at $installer matches the preferred version"
          installerPath="$installer"
          startOSInstall="$installerPath"/Contents/Resources/startosinstall
          willDownload="false"
          networkLinkEvaluation="false"
        fi
      done
    fi
    unset IFS
    if [[ "$macOSVersionMajor" -ge "15" ]] || [[ "$macOSVersionEpoch" -ge "11" ]] && [[ "$willDownload" = "true" ]]; then
      echo "Installer will be requested from Apple CDN, checking if network link evaluations are allowed"
      networkLinkEvaluation
      echo "macOS version eligible for Install macOS App via softwareupdate, attempting download now..."
      if [[ "$currentUser" = "root" || "$runHeadless" = "true" ]]; then
        echo "Suppressing download notification"
      else
        /bin/launchctl asuser "$currentUserUID" "$jamfHelper" -windowType "utility" \
        -icon "$logoPath" \
        -title "Downloading macOS" \
        -description "Downloading a new copy of macOS. This can take some time. You can close this window and we'll let you know when it's ready" \
        -button1 "OK" \
        -startlaunchd &
      fi
      if softwareupdate --fetch-full-installer --full-installer-version "$macOSDownloadVersion"; then
        echo "Download from Apple CDN was successful"
      else
        isMajorOSUpdateDeferred=$(system_profiler SPConfigurationProfileDataType | grep -c enforcedSoftwareUpdateMajorOSDeferredInstallDelay)
        if [[ "$isMajorOSUpdateDeferred" -ge "1" ]]; then
          echo "Major OS Update Deferral is in effect, are you sure you're requesting an installer outside your deferral window?"
        fi
        echo "Download from Apple CDN was not successfull, falling back to Jamf download if available"
        if [[ "$macOSInstallAppJamfEvent" != "" ]]; then
          if ! /usr/local/bin/jamf policy -event "$macOSInstallAppJamfEvent"; then
            echo "Installer could not be downloaded from Jamf, bailing now"
            exit 1
          fi
        else
          echo "Download from Apple CDN and Jamf repositories were not successfull, bailing"
          exit 1
        fi
      fi
    fi
    if [[ "$macOSVersionMajor" -lt "15" ]] && [[ "$macOSVersionEpoch" -lt "11" ]] && [[ "$willDownload" = "true" ]]; then
      echo "Installer will be requested from Jamf CDN, checking if Jamf event variable is populated"
      if [[ "$macOSInstallAppJamfEvent" = "" ]]; then
        echo "Jamf Event is not defined in policy, bailing"
        exit 2
      fi
      echo "Checking if network link evaluations are allowed"
      networkLinkEvaluation
      echo "macOS version must be downloaded via Jamf Policy, attempting download now..."
      if [[ "$currentUser" = "root" ]]; then
        echo "Nobody logged in, suppressing download notification"
      else
        /bin/launchctl asuser "$currentUserUID" "$jamfHelper" -windowType "utility" \
        -icon "/System/Library/PreferencePanes/SoftwareUpdate.prefPane/Contents/Resources/SoftwareUpdate.icns" \
        -title "Downloading macOS" \
        -description "Downloading a new copy of macOS. This can take some time. You can close this window and we'll let you know when it's ready" \
        -button1 "OK" \
        -startlaunchd &>/dev/null &
        if /usr/local/bin/jamf policy -event "$macOSInstallAppJamfEvent"; then
            echo "Installer successfully downloadef from Jamf repository"
        else
            echo "Installer could not be downloaded from Jamf, bailing now"
            exit 1
        fi
      fi
    fi
  }

passwordPromptAppleSilicon ()
{
  if [[ "$currentUser" = "root" ]]; then
    echo "macOS on Apple Silicon cannot be upgraded without an active login, bailing"
    exit 0
  else
    echo "Prompting $currentUser for their new password..."
    promptTitle="Attention"
    userPassword="$(/bin/launchctl asuser "$currentUserUID" /usr/bin/osascript -e 'display dialog "Please enter your password to proceed with the software update" default answer "" with title "'"${promptTitle//\"/\\\"}"'" giving up after 86400 with text buttons {"OK","Cancel"} default button 1 with hidden answer with icon file "'"${logoPath_POSIX//\"/\\\"}"'"' -e 'return text returned of result')"
    # Check the user's password against the local Open Directory store
    TRY=1
    while ! /usr/bin/dscl /Search -authonly "$currentUser" "$userPassword"; do
      ((TRY++))
      echo "Prompting $currentUser for their Mac password again attempt $TRY..."
      userPassword="$(/bin/launchctl asuser "$currentUserUID" /usr/bin/osascript -e 'display dialog "Please re-type your password" default answer "" with title "'"${promptTitle//\"/\\\"}"'" giving up after 86400 with text buttons {"OK"} default button 1 with hidden answer with icon file "'"${logoPath_POSIX//\"/\\\"}"'"' -e 'return text returned of result')"
      if ! /usr/bin/dscl /Search -authonly "$currentUser" "$userPassword"; then
        if (( $TRY >= 2 )); then
          echo "[ERROR] Password prompt unsuccessful after 2 attempts. Displaying \"forgot password\" message..."
          /bin/launchctl asuser "$currentUserUID" "$jamfHelper" -windowType "utility" \
          -icon "$logoPath" \
          -title "Authentication" \
          -description "Your password seems to be incorrect. Verify that you are using the correct password for Mac authentication and try again..." \
          -button1 'Stop' \
          -defaultButton 1 \
          -startlaunchd &>/dev/null &
          exit 1
        fi
      fi
    done
  fi
}

startOSInstaller ()
{
  if [[ -d /Volumes/InstallESD ]]; then
    echo "Unmounting InstallESD in preparation for new install"
    diskutil unmount /Volumes/InstallESD
  fi
  if [[ -d /Volumes/"Shared Support" ]]; then
    echo "Unmounting Shared Support in preparation for new install"
    diskutil unmount /Volumes/"Shared Support"
  fi
  if [[ "$currentUser" = "root" ]]; then
    echo "Nobody logged in, install cannot continue, bailing"
    exit 0
  fi
  /bin/launchctl asuser "$currentUserUID" "$jamfHelper" -windowType "utility" \
  -icon "$logoPath" \
  -title "Preparing macOS Install" \
  -description "Your macOS installation is being prepared. You can continue working and we'll notify you when it's time to restart..." \
  -startlaunchd &>/dev/null &
    if [[ "$installAction" = "erase" ]] && [[ "$(arch)" = "arm64" ]]; then
      echo "$userPassword" | "$startOSInstall" --eraseinstall --newvolumename 'Macintosh HD' --pidtosignal $(pgrep jamfHelper) --agreetolicense --rebootdelay "60" --user "$currentUser" --stdinpass &
    elif [[ "$installAction" = "reinstall" ]] || [[ "$installAction" = "upgrade" ]] && [[ "$(arch)" = "arm64" ]]; then
      echo "$userPassword" | "$startOSInstall" --agreetolicense --pidtosignal $(pgrep jamfHelper) --rebootdelay "60" --user "$currentUser" --stdinpass &
    elif [[ "$installAction" = "erase" ]] && [[ "$(arch)" != "arm64" ]]; then
      "$startOSInstall" --eraseinstall --newvolumename 'Macintosh HD' --pidtosignal $(pgrep jamfHelper) --agreetolicense --rebootdelay "60" &
    elif [[ "$installAction" = "reinstall" ]] || [[ "$installAction" = "upgrade" ]] && [[ "$(arch)" != "arm64" ]]; then
      "$startOSInstall" --agreetolicense --pidtosignal $(pgrep jamfHelper) --rebootdelay "60" &
    fi
    wait $(pgrep jamfHelper)
    /bin/launchctl asuser "$currentUserUID" "$jamfHelper" -windowType "utility" \
    -icon "$logoPath" \
    -title "Restarting Now" \
    -description "Your Mac will reboot now to start the update process. Your screen may turn on and off several times during the update. This is normal. Please do not press the power button during the update." \
    -button1 "OK" \
    -defaultButton 1 \
    -timeout 60 \
    -startlaunchd &>/dev/null &
    wait $!
    if pgrep "Self Service"; then
    	echo "Self Service is open, killing now to prevent a reboot delay"
    	pkill "Self Service"
    fi
  }

startOSInstallerHeadless ()
{
  if [[ -d /Volumes/InstallESD ]]; then
    echo "Unmounting InstallESD in preparation for new install"
    diskutil unmount /Volumes/InstallESD
  fi
  if [[ -d /Volumes/"Shared Support" ]]; then
    echo "Unmounting Shared Support in preparation for new install"
    diskutil unmount /Volumes/"Shared Support"
  fi
  if [[ "$currentUser" = "root" ]]; then
    echo "Nobody logged in, install cannot continue, bailing"
    exit 0
  fi
  if [[ "$installAction" = "erase" ]] && [[ "$(arch)" = "arm64" ]]; then
    echo "$userPassword" | "$startOSInstall" --eraseinstall --newvolumename 'Macintosh HD' --agreetolicense --pidtosignal startosinstall --nointeraction --forcequitapps --user "$currentUser" --stdinpass &
  elif [[ "$installAction" = "reinstall" ]] || [[ "$installAction" = "upgrade" ]] && [[ "$(arch)" = "arm64" ]]; then
    echo "$userPassword" | "$startOSInstall" --agreetolicense --pidtosignal startosinstall --nointeraction --forcequitapps --user "$currentUser" --stdinpass &
  elif [[ "$installAction" = "erase" ]] && [[ "$(arch)" != "arm64" ]]; then
    "$startOSInstall" --eraseinstall --newvolumename 'Macintosh HD' --pidtosignal startosinstall --agreetolicense --forcequitapps --nointeraction &
  elif [[ "$installAction" = "reinstall" ]] || [[ "$installAction" = "upgrade" ]] && [[ "$(arch)" != "arm64" ]]; then
    "$startOSInstall" --agreetolicense --pidtosignal startosinstall --rebootdelay "60" --nointeraction --forcequitapps &
  fi
}

frontAppASN="$(lsappinfo front)"
for doNotDisturbAppBundleID in ${doNotDisturbAppBundleIDsArray[@]}; do
  frontAppBundleID="$(lsappinfo info -app $frontAppASN | grep bundleID | awk -F '=' '{print $2}' | sed 's/\"//g')"
  if [[ "$frontAppBundleID" = "$doNotDisturbAppBundleID" ]]; then
    echo "Do not disturb app $frontAppBundleID is frontmost, bailing out"
    exit 0
  fi
done

if [[ "$currentUser" = "root" ]]; then
  echo "Nobody is logged in, assume runheadless and proceed as far as we can without an interactive session"
  runHeadless="true"
fi

if [[ "$runHeadless" = "true" ]]; then
  preUpgradeJamfPolicies
  resetIgnoredUpdates
  downloadOSInstaller
else
  checkBatteryStatus
  checkAvailableDiskSpace
  preUpgradeJamfPolicies
  resetIgnoredUpdates
  downloadOSInstaller
fi

# Check which install action was set by Jamf Policy and change the notification language
# appropriately

if [[ "$installAction" = "erase" ]]; then
  rebootActionTitle="Erase and Install macOS"
  rebootActionDescription="Your Mac will be erased and re-installed. Please do so only after performing a backup of your important files."
elif [[ "$installAction" = "reinstall" || "$installAction" = "" ]]; then
  rebootActionTitle="Re-install macOS"
  rebootActionDescription="Your Mac will have a new copy of macOS installed. All of your files and settings will be preserved. Expected install time is approximately 20-30 minutes..."
elif [[ "$installAction" = "upgrade" ]]; then
  rebootActionTitle="Upgrade macOS"
  rebootActionDescription="Your Mac will be upgraded to the latest version of macOS. All of your files and settings will be preserved. Expected upgrade time is approximately 20-40 minutes..."
elif [[ "$installAction" = "downloadonly" ]]; then
  echo "Download only was selected, bailing out"
  exit 0
fi

if [[ "$currentUser" = "root" ]]; then
  echo "Nobody logged in, install cannot continue"
  exit 0
else
  if [[ "$runHeadless" = "true" ]]; then
    echo "skipping reboot notification as we are running headless"
    if [[ "$(arch)" = "arm64" ]]; then
      passwordPromptAppleSilicon
      startOSInstallerHeadless
    else
      startOSInstallerHeadless
    fi
  else
    rebootAction=$(/bin/launchctl asuser "$currentUserUID" "$jamfHelper" -windowType "utility" \
    -icon "$logoPath" \
    -title "$rebootActionTitle" \
    -description "$rebootActionDescription" \
    -button1 "Start" \
    -button2 "Cancel" \
    -defaultButton 1 \
    -timeout 300 \
    -startlaunchd )
    if [[ "$rebootAction" -eq 2 ]]; then
      echo "user chose to cancel, bailing now"
      exit 0
    elif [[ "$rebootAction" -eq 0 ]]; then
      echo "user chose to continue with installation, checking cpu architecture"
      if [[ "$(arch)" = "arm64" ]]; then
        passwordPromptAppleSilicon
        startOSInstaller
      else
        startOSInstaller
      fi
    fi
  fi
fi
