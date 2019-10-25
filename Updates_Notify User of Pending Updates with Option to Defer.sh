#!/usr/bin/env zsh

### Enter your organization's preference domain below ###

companyDomain=$4
softwareUpdateGracePeriodinDays=$5

#########################################################

### Collecting the major.minor version of the host OS to present Software Update.app in one of two ways ###

OSMajorVersion="$(/usr/bin/sw_vers -productVersion | /usr/bin/cut -d '.' -f 2)"
OSMinorVersion="$(/usr/bin/sw_vers -productVersion | /usr/bin/cut -d '.' -f 3)"

#########################################################

### Collecting the number of updates currently available to the host OS just in case it's updated while we haven't been looking ###

numberofAvailableUpdates=$(defaults read /Library/Preferences/com.apple.SoftwareUpdate LastUpdatesAvailable)

#########################################################

### Collecting the logged in user's UserName attribute to sudo as he/she for various commands ###

currentUser=$(/bin/ls -l /dev/console | /usr/bin/awk '{ print $3 }')

#########################################################

### Logic to remove a Software Update Preference if the client is already up to date ###

if [[ ${numberofAvailableUpdates} -eq 0 ]]; then
 echo "Client is Completely up to Date, Exiting"
 if [[ -f /Library/Preferences/$companyDomain.SoftwareUpdatePreferences.plist ]]; then
  echo "Software Update Countdown Timer in Place, Removing"
  rm -v /Library/Preferences/$companyDomain.SoftwareUpdatePreferences.plist
 fi
fi

########################################################################################

if [[ ${numberofAvailableUpdates} -gt 0 ]]; then

softwareUpdateInstallDeadlineNationalRepresentation=$(defaults read /Library/Preferences/$companyDomain.SoftwareUpdatePreferences.plist NationalRepresentationStartDate)

######### Notify the User about pending Updates ##########
### Edit the forward date (+7d below) to your preferred number of days after which nudging kicks in. ###

	userUpdateChoice=$("/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper" \
	-windowType utility \
	-windowPosition ur \
	-title Updates Available \
	-description "macOS Updates are available as of $softwareUpdateInstallDeadlineNationalRepresentation". \
	"These updates will start to be auto installed in about $softwareUpdateGracePeriodinDays Days."\
	-alignDescription left \
	-icon "/System/Library/CoreServices/Software Update.app/Contents/Resources/SoftwareUpdate.icns" \
	-iconSize 120 \
	-button1 "Update Now" \
	-button2 "Dismiss" \
	-defaultButton 0 \
	-cancelButton 1 \
	-timeout 300
	)

 if [ "$userUpdateChoice" -eq 2 ]; then
  echo "User chose to defer to a later date, exiting"
  exit 0
 elif [ "$userUpdateChoice" -eq 0 ]; then
  if [[ "$OSMajorVersion" -ge 14 && "$currentUser" != "root" ]]; then
   sudo -u "$currentUser" /usr/bin/open "/System/Library/CoreServices/Software Update.app"
  elif [[ "$OSMajorVersion" -ge 8 ]] && [[ "$OSMajorVersion" -le 13 && "$currentUser" != "root" ]]; then
   sudo -u "$currentUser" /usr/bin/open macappstore://showUpdatesPage
  fi
 fi
fi
