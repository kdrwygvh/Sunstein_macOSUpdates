﻿#!/usr/bin/env zsh

### Enter your organization's preference domain below ###

companyDomain=$4

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
	
	echo "Client is Completely up to Date, Exiting"
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
		defaults write /Library/Preferences/$companyDomain.SoftwareUpdatePreferences.plist StartDate $(date "+%Y-%m-%d")
		echo "Software Update Countdown in Place and datestamped $(defaults read /Library/Preferences/$companyDomain.SoftwareUpdatePreferences.plist StartDate)"
        /usr/local/bin/jamf recon
	fi
fi


