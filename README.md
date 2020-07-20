**Sunstein** is (yet another way) of attempting to give a Mac user some flexibility on when updates are performed while also meeting requirements set by their employer. Sunstein gives the user the opportunity to perform updates on their own time (to a point.)
Standard Apple notifications and macOS's internal scheduling algorithms are relied on as much as possible.

**The Particulars**

Credit to bp88 for inspiration on calling the Software Update.app on different macOS versions and for power assertion function code.

***All scripts assume Jamf Pro as the management environment.***
***You must be collecting availble software updates in Jamf Pro's Inventory Management Settings for these scripts to work as designed.***
***macOS 10.14+ has been tested. Other versions of macOS haven't been very much.***

1. Create two new extension attributes for Flexibility start date and Flexibility end date using the included scripts.

2. Create two smart groups based on the values returned from those scripts. For clients inside the flexibility window the
critera should for the attribute containing your flexibility window start date should be *"less than x days ago"* where x is the length of your desired flexibility window in days.

A similar smart group should be made for clients outside the flexibility window; the flexibility window start date with a criteria of *"more than x days ago"* where x is the length of your desired flexibility window in days.

3. Create a policy that runs the "Updates_Notify User of Pending Updates with Option to Defer" script at some regular interval.
I'd strongly suggest creating a smart group using criteria *"Number of Available Updates is Greater Than 0"* to scope the policy to.
Because macOS may perform updates between Jamf inventory updates the script will check to see if any updates are actually available
and only if they are will the user be presented with a notification.

4. Create a policy that runs the *"Updates_Set OS Software Update Flexibilty Window Closure Date"* script at some regular interval.
Because macOS may perform updates between Jamf inventory updates the script will check to see if any updates are actually available
and only if they are will the macOS client be stamped with a flexibility window start date.

5. Create a policy that runs the *"Updates_Install all Outstanding Updates_Outside Flexibility Window"* script at some regular interval. Think hard about what time of day this should happen.
Scope this policy to the smart group which includes clients outside the flexibility window.


Also included in this project are two scripts for setting the com.apple.SoftwareUpdate preference keys. For clients inside the flexibility window only basic checking and downloading of updates is performed. For clients outside the flexibility window all automatic updates are turned on. I'm currently using a script based approach rather than MDM for these keys because of the flexibility scripts offer but MDM profiles would work just as well.
