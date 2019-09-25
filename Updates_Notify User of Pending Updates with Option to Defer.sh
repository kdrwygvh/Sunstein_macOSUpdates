#!/usr/bin/env zsh

### Enter your organization's preference domain below ###

companyDomain=$4

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

if [[ ${numberofAvailableUpdates} -eq 0 ]]; then

	echo "Client is Completely up to Date, Exiting"
	if [[ -f /Library/Preferences/$companyDomain.SoftwareUpdatePreferences.plist ]]; then
		echo "Software Update Countdown Timer in Place, Removing"
		rm -v /Library/Preferences/$companyDomain.SoftwareUpdatePreferences.plist
	fi

fi

if [[ ${numberofAvailableUpdates} -gt 0 ]]; then

	if [[ -f /Library/Preferences/$companyDomain.SoftwareUpdatePreferences.plist ]]; then
		echo "Software Update Countdown Already in Place and datestamped $(defaults read /Library/Preferences/$companyDomain.SoftwareUpdatePreferences.plist StartDate)"
		softwareUpdateInstallDeadline=$(defaults read /Library/Preferences/$companyDomain.SoftwareUpdatePreferences.plist StartDate)
	else
		managedDeferredInstallDelay=$(defaults read /Library/Managed\ Preferences/com.apple.SoftwareUpdate ManagedDeferredInstallDelay)
		if [[ $managedDeferredInstallDelay =~ [[:digit:]] ]]; then
			softwareUpdateInstallDeadline=$(/bin/date -v +"$managedDeferredInstallDelay"d "+%Y-%m-%d")
			defaults write /Library/Preferences/$companyDomain.SoftwareUpdatePreferences.plist StartDate $(/bin/date -v +"$managedDeferredInstallDelay"d "+%Y-%m-%d")
			echo "Software Update Countdown in Place and datestamped $(defaults read /Library/Preferences/$companyDomain.SoftwareUpdatePreferences.plist StartDate)"
		else
			echo "Setting a default user facing deferral date of 7 days as deferral doesn't appear to be managed via MDM"
			softwareUpdateInstallDeadline=$(/bin/date -v +7d "+%Y-%m-%d")
			defaults write /Library/Preferences/$companyDomain.SoftwareUpdatePreferences.plist StartDate $(/bin/date -v +7d "+%Y-%m-%d")
			echo "Software Update Countdown in Place and datestamped $(defaults read /Library/Preferences/$companyDomain.SoftwareUpdatePreferences.plist StartDate)"
		fi
	fi

	######### Notify the User about pending Updates ##########
	### Edit the forward date (+7d below) to your preferred number of days after which nudging kicks in. ###

	userUpdateChoice=$("/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper" \
	-windowType utility \
	-windowPosition ur \
	-title Updates Available \
	-description "macOS Updates are available and will start to be installed automatically on or after "$softwareUpdateInstallDeadline". \
	You may run any updates that you're notified about prior to the deadline at your convenience." \
	-alignDescription left \
	-icon "/System/Library/CoreServices/Software Update.app/Contents/Resources/SoftwareUpdate.icns" \
	-iconSize 150 \
	-button1 Update \
	-button2 Dismiss \
	-defaultButton 0 \
	-cancelButton 1
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


