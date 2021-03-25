**Sunstein** provides the user with a grace period window within which they can choose to perform OS level updates.
Inside the grace period window, the user may receive notifications about pending updates and be given an option to defer them.
Outside the grace period window, the user may receive more urgent notifications about pending updates and be provided a shortcut to System Preferences to review and install updates.
A script is also included that leverages the Jamf API to send the 'Update macOS' MDM command which can be scoped to systems outside the grace period window.

**The Particulars**

***All scripts assume Jamf Pro as the management environment.***
***You must be collecting availble software updates in Jamf Pro's Inventory Management Settings for these scripts to work as designed.***
***macOS 10.14+ has been tested. Other versions of macOS haven't been very much.***

1. Create two new extension attributes for Grace Period Window Start Date and Grace Period Window End Date using the included scripts.

2. Create two smart groups based on the values returned from those scripts. For clients inside the grace period window the
critera should for the attribute containing your grace period window start date should be *"less than x days ago"* where x is the length of your desired grace period window in days.

A similar smart group should be made for clients outside the grace period window; the grace period window start date with a criteria of *"more than x days ago"* where x is the length of your desired grace period window in days.

3. Create a policy that runs the *"Sunstein_Set OS Software Update Grace Period Window Closure Date"* script at some regular interval.
I'd strongly suggest creating a smart group using criteria *"Number of Available Updates is Greater Than 0"* to scope the policy to.
Because macOS may perform updates between Jamf inventory updates the script will check to see if any updates are actually available
and only if they are will the macOS client be stamped with grace period window start and end dates.

4. Create a policy that runs the *"Sunstein_Notify User of Pending Updates_Inside Grace Period Window"* script at some regular interval.
This policy should be scoped to the smart group you created in step two for systems within the grace period window.
This policy should also only run during business hours. If a notification pops up in the middle of the night and nobody is there to see it, did it happen?
Because macOS may perform updates between Jamf inventory updates the script will check to see if any updates are actually available
and only if they are will the user be presented with a notification.

5. Create a policy that runs the *"Sunstein_Install all Outstanding Updates_Outside Grace Period Window"* script at some regular interval.
This policy should also only run during business hours. If a notification pops up in the middle of the night and nobody is there to see it, did it happen?
This policy should be scoped to the smart group you created in step two for systems outside of the grace period window.


Also included in this project are two scripts for setting the com.apple.SoftwareUpdate preference keys. They're in 'Extras.' For clients inside the flexibility window only basic checking and downloading of updates is performed. For clients outside the flexibility window all automatic updates are turned on. I'm currently using a script based approach rather than MDM for these keys because of the flexibility scripts offer but MDM profiles would work just as well.
