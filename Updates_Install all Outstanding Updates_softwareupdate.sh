#!/usr/bin/env zsh

### Collecting the logged in user's UserName attribute to sudo as he/she for various commands ###

CurrentUser=$(/bin/ls -l /dev/console | /usr/bin/awk '{ print $3 }')

#########################################################

### Collecting the major.minor version of the host OS to present Software Update.app in one of two ways ###

OSMajorVersion="$(/usr/bin/sw_vers -productVersion | /usr/bin/cut -d '.' -f 2)"
OSMinorVersion="$(/usr/bin/sw_vers -productVersion | /usr/bin/cut -d '.' -f 3)"

#########################################################

### Function to present our more forceful software update notification via the jamfHelper ###

function presentUserWithUpdateNotification ()

{

 "/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper" \
  -windowType utility \
  -windowPosition ur \
  -title "macOS Updates Required" \
  -description "Updates are available which we'd suggest installing today at your earliest opportunity. You'll be presented with available updates to install after clicking 'Update Now.' Updates not installed by you will be automatically installed in the evening." \
  -alignDescription left \
  -icon "/System/Library/CoreServices/Software Update.app/Contents/Resources/SoftwareUpdate.icns" \
  -iconSize 120 \
  -button1 "Update Now" \
  -defaultButton 0 \
  -lockHUD
}

#########################################################

### If a user is not logged in, run softwareupdate in one of two ways determined by macOS version. ###

if [[ "$CurrentUser" = "root" ]]; then
  echo "User is not in session, safe to perform all updates and restart now"
  if [[ "$OSMajorVersion" -ge 14 ]]; then
    softwareupdate -i -a -R --verbose
  elif [[ "$OSMajorVersion" -ge 8 ]] && [[ "$OSMajorVersion" -le 13 ]]; then
    /usr/sbin/softwareupdate -l | /usr/bin/grep -i "restart"
    if [[ $(/bin/echo "$?") == 1 ]]; then
      echo "No updates found which require a restart, but we'll run softwareupdate to install any other outstanding updates."
      softwareupdate -i -a
    else
      softwareupdate -i -a
      /usr/local/bin/jamf reboot -immediately -background
    fi
  else
    echo "macOS Version could not be determined, exiting"
  exit 1
 fi
fi

#########################################################

doNotDisturbState=$(sudo -u $currentUser defaults read /Users/$currentUser/Library/Preferences/ByHost/com.apple.notificationcenterui.plist doNotDisturb)

if [[ ${doNotDisturbState} -eq 1 ]]; then
  echo "User has enabled Do Not Disturb, not bothering with presenting the software update notification this time around"
  exit 0
fi

### If a user is logged in, present the update notification to them ###

if [[ "$OSMajorVersion" -ge 14 && "$CurrentUser" != "root" ]]; then
  presentUserWithUpdateNotification
  sudo -u "$CurrentUser" /usr/bin/open "/System/Library/CoreServices/Software Update.app"
elif [[ "$OSMajorVersion" -ge 8 ]] && [[ "$OSMajorVersion" -le 13 && "$CurrentUser" != "root" ]]; then
  presentUserWithUpdateNotification
  sudo -u "$CurrentUser" /usr/bin/open macappstore://showUpdatesPage
fi


