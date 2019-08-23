The concept of 'nudging' in the context of systems administration is to give the user every opportunity to do the right
thing to achieve your desired outcome, and only after every opportunity has been given taking a more aggressive approach to achieve the desired outcome.

**Nudge_macOS Updates** is a way of applying this concept to macOS updates. It gives the user the opportunity to perform updates on their own time, right or later.

*'Later' might never come.*

*So...*

**The Particulars**

***All scripts assume Jamf Pro as the management environment.***

1. Upload the extension attribute to your own JPS and create a smart group based on its value.
*"More than X Days Ago"* with a value of the number of days after which you want to start nudging the client more aggressively.

2. Create a policy that runs the "Updates_Notify User of Pending Updates with Option to Defer" script at some regular interval.
I'd strongly suggest creating a smart group using criteria *"Number of Available Updates is Greater Than 1"* to scope the policy to.
Because macOS may perform updates between Jamf inventory updates the script will check to see if any updates are actually available
and only if they are will the user be presented with any kind of notification.

3. Create a policy that runs the *"Updates_Start Countdown Timer for Eventual Forced macOS Update Installation"* script at some regular interval.
I'd strongly suggest creating a smart group using criteria "Number of Available Updates is Greater Than 1" to scope the policy to.
Because macOS may perform updates between Jamf inventory updates the script will check to see if any updates are actually available
and only if they are will the macOS client be timestamped.

4. Create a policy that runs the *"Updates_Install all Outstanding Updates_softwareupdate"* script at some regular interval. Think hard about when this should happen.
I'd suggest either early morning or after lunch. Scope this policy to the group you created in step 1.

**Extra Credit**

Because macOS clients will be receiving updates more or less automatically and because we'll be nudging users to do the right thing,
I'd also suggest creating a default deferral of at least seven days for all macOS updates released by Apple. Jamf Pro provides
a payload to do this in their 'Restrictions' payload.

In order to ensure that all macOS clients are checking for, downloading, and installing updates consistently, I'd also suggest
creating a Configuration Profile to manage the com.apple.SoftwareUpdate preference domain.

    <key>AutomaticCheckEnabled</key>
	<true/>
	<key>AutomaticDownload</key>
	<true/>
	<key>AutomaticallyInstallMacOSUpdates</key>
	<true/>
	<key>ConfigDataInstall</key>
	<true/>
	<key>CriticalUpdateInstall</key>
	<true/>

This configuration profile can be scoped only to macOS clients that meet the criteria
of the group you created in step 1.
