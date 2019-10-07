#!/usr/bin/env zsh

### Enter your organization's preference domain below ###

companyDomain=$4
administratorDefinedDeferralinDays=$5

#########################################################

### Collect the number of available updates the host OS thinks it needs ###

numberofAvailableUpdates=$(defaults read /Library/Preferences/com.apple.SoftwareUpdate LastUpdatesAvailable)

#########################################################

### Sanity check to ensure that user defined variables are populated ###

if [[ $4 == "" ]]; then
	echo "Preference Domain not defined as part of the currently running policy, bailing"
    exit 1
fi

#########################################################

if [[ ${numberofAvailableUpdates} -eq 0 ]]; then

	echo "Client is Completely up to Date"
	if [[ -f /Library/Preferences/$companyDomain.SoftwareUpdatePreferences.plist ]]; then
		echo "Software Update Countdown Timer in Place, Removing"
		rm -v /Library/Preferences/$companyDomain.SoftwareUpdatePreferences.plist
    /usr/local/bin/jamf recon
	fi
fi

if [[ ${numberofAvailableUpdates} -gt 0 ]]; then

	if [[ -f /Library/Preferences/$companyDomain.SoftwareUpdatePreferences.plist ]]; then
		echo "Software Update Countdown Already in Place and datestamped $(defaults read /Library/Preferences/$companyDomain.SoftwareUpdatePreferences.plist StartDate)"
	else
		managedDeferredInstallDelay=$(defaults read defaults read "/Library/Managed Preferences/com.apple.SoftwareUpdate" ManagedDeferredInstallDelay)
		if [[ $managedDeferredInstallDelay =~ [[:digit:]] ]]; then
			defaults write /Library/Preferences/$companyDomain.SoftwareUpdatePreferences.plist StartDate $(date -v +"$managedDeferredInstallDelay"d "+%Y-%m-%d")
			defaults write /Library/Preferences/$companyDomain.SoftwareUpdatePreferences.plist NationalRepresentationStartDate $(/bin/date -v +"$managedDeferredInstallDelay"d "+%A, %B %e")
			echo "Software Update Countdown in Place and datestamped $(defaults read /Library/Preferences/$companyDomain.SoftwareUpdatePreferences.plist StartDate)"
		else
			echo "Setting the Jamf variable defined deferral as deferral doesn't appear to be managed via MDM"
			defaults write /Library/Preferences/$companyDomain.SoftwareUpdatePreferences.plist StartDate $(/bin/date -v +"$administratorDefinedDeferralinDays"d "+%Y-%m-%d")
			defaults write /Library/Preferences/$companyDomain.SoftwareUpdatePreferences.plist NationalRepresentationStartDate $(/bin/date -v +"$managedDeferredInstallDelay"d "+%A, %B %e")
			echo "Software Update Countdown in Place and datestamped $(defaults read /Library/Preferences/$companyDomain.SoftwareUpdatePreferences.plist StartDate)"
		fi
	fi
fi
