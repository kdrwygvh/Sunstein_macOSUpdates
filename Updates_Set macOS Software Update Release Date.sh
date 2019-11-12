#!/usr/bin/env zsh

### Enter your organization's preference domain below ###

companyDomain=$4

### If you are not managing macOS deferred updates via the 'ManagedDeferredInstallDelay' preference key, set the number of deferral days here. ###

administratorDefinedDeferralinDays=$5

#########################################################

### Collect the number of available updates the host OS thinks it needs ###

numberofAvailableUpdates=$(defaults read /Library/Preferences/com.apple.SoftwareUpdate LastUpdatesAvailable)

#########################################################

### Sanity check to ensure that the preference domain has been set. ###

if [[ $4 == "" ]]; then
	echo "Organization Preference Domain not defined as part of the currently running policy, bailing"
    exit 1
fi

#########################################################

### If the client has updated itself since the last time a Jamf inventory update occurred,
### clean up and reset the Software Update Releate Date Window

if [[ ${numberofAvailableUpdates} -eq 0 ]]; then

	echo "Client is Completely up to Date"
	if [[ -f /Library/Preferences/$companyDomain.SoftwareUpdatePreferences.plist ]]; then
		echo "Software Update Countdown Timer in Place, Removing"
		rm -v /Library/Preferences/$companyDomain.SoftwareUpdatePreferences.plist
    /usr/local/bin/jamf recon
	fi
fi

#########################################################

if [[ ${numberofAvailableUpdates} -gt 0 ]]; then

	if [[ -f /Library/Preferences/$companyDomain.SoftwareUpdatePreferences.plist ]]; then
		echo "Software Update Release Date in Place and datestamped $(defaults read /Library/Preferences/$companyDomain.SoftwareUpdatePreferences.plist StartDate)"
	else
		managedDeferredInstallDelay=$(defaults read "/Library/Managed Preferences/com.apple.SoftwareUpdate" ManagedDeferredInstallDelay)
		if [[ $managedDeferredInstallDelay =~ [[:digit:]] ]]; then
			defaults write /Library/Preferences/$companyDomain.SoftwareUpdatePreferences.plist DateMacBecameAwareOfUpdates $(date "+%Y-%m-%d")
			defaults write /Library/Preferences/$companyDomain.SoftwareUpdatePreferences.plist StartDate $(date -v +"$managedDeferredInstallDelay"d "+%Y-%m-%d")
			defaults write /Library/Preferences/$companyDomain.SoftwareUpdatePreferences.plist NationalRepresentationStartDate "$(/bin/date -v +"$managedDeferredInstallDelay"d "+%A, %B %e")"
			echo "Software Update Release Date in Place and datestamped $(defaults read /Library/Preferences/$companyDomain.SoftwareUpdatePreferences.plist StartDate)"
		else
			echo "Setting the Jamf variable defined deferral as deferral doesn't appear to be managed via MDM"
			defaults write /Library/Preferences/$companyDomain.SoftwareUpdatePreferences.plist DateMacBecameAwareOfUpdates $(date "+%Y-%m-%d")
			defaults write /Library/Preferences/$companyDomain.SoftwareUpdatePreferences.plist StartDate $(/bin/date -v +"$administratorDefinedDeferralinDays"d "+%Y-%m-%d")
			defaults write /Library/Preferences/$companyDomain.SoftwareUpdatePreferences.plist NationalRepresentationStartDate "$(/bin/date -v +"$managedDeferredInstallDelay"d "+%A, %B %e")"
			echo "Software Update Release Date in Place and datestamped $(defaults read /Library/Preferences/$companyDomain.SoftwareUpdatePreferences.plist StartDate)"
		fi
	fi
fi
