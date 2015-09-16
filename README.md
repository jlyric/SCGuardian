ScreenConnect Guardian
================================

    dev           jlyric@outlook.com - https://github.com/jlyric
    build-ver     v0.0.1
    build-date    September 16th, 2015
    build-sha     91bbab1b8343cd52b6f7b34f6181ad2f7b0efb3e
    license       GNU General Public License v3.0

Getting Started
-------------------------------------------
The ScreenConnect Guardian is a set of functions to perform various tasks in the capacity of examining the online relationship between the ScreenConnect host and client.  ScreenConnect Guardian is akin to the LogMeIn Guardian in that the script performs various checks and tasks with the shared goal of keeping the ScreenConnect Client online and connected with the ScreenConnect Server.

Guardian PowerShell Script & ScreenConnect Extension
---------------------------------------------------
The ScreenConnect Guardian is comprised of two different parts.  The first, a PowerShell script, is built specifically to run on the client machines.  The second, a ScreenConnect extension, contains a small helper function which is called by the PowerShell script.

The core PowerShell function, Start-Guardian, will check reachability of the configured ScreenConnect host by first running an ICMP (ping) test followed by a direct TCP connection to the host on the configured relay port. As the server is up and running the client should be connected, correct?  Not always.  The name of the game with remote access is making sure you have remote access.  The script will make a request to the ScreenConnect Guardian Extension for online status of the client at the server console to determine the current online relationship and act accordingly.  If the server is showing the client as offline, but reachability is good from the client to host -- restart the client service to reestablish the connection relationship.

Requirements
-------------
##### Extension
* Windows only?

The extension has been tested on ScreenConnect Servers running Microsoft variants.  I'm not sure what the extension architecture looks like on other operating systems.  When time is available I will spin up a Linux VM and quickly setup a vanilla ScreenConnect installation to take a look and report back.

##### PowerShell Script
* Windows only.
* PowerShell v2.0+ (XP [KB968930], Vista [KB968930], 7, 8, 8.1, 10)
* Administrative Client Rights through ScreenConnect

Most of the forum reports and my own testing are having trouble keeping ScreenConnect clients connected with machines running Windows Vista and above.  The PowerShell script will run on machines with PowerShell 2.0 and greater.  Functions and Cmdlets were chosen to target the lowest possible version of PowerShell to open the door to a greater number of clients.

Installing the ScreenConnect Guardian Extension
-------------------------
* Download the latest version the ScreenConnect Guardian Package
* Unzip and copy the contents of the Extension folder to your App_Extensions directory on your ScreenConnect Server.  Your directory structure should look something like the following:

  `C:\Program Files (x86)\ScreenConnect\App_Extensions\de9b663e-1025-46dc-b16f-e9e00785f4d1\`
* The default extension GUID is `de9b663e-1025-46dc-b16f-e9e00785f4d1`, should you change this GUID you will need to make adjustments in the PowerShell script outlined a bit later in the document.
* The ScreenConnect Guardian should now be showing in the Admin area of your ScreenConnect Server.
* Click the <b>Options</b> menu and select <b>Edit Settings</b>.
* In the settings window, change the IntegrationKey to something different if you desire.  Remember the IntegrationKey as you will need to update the PowerShell script should you change it.
* Done!

###### In the end, I'm not sure this Extension may even be necessary.  Perhaps someone speaks up with a simple `native` API call to achieve our goal of getting the client online-status at the server-level.

Installing the ScreenConnect PowerShell Script
--------------------------
* Download the latest version of the ScreenConnect Guardian Package
* Unzip and within the PowerShell folder you will find `SCGuardian.ps1` which is the client script.
* Make adjustments to the necessary configuration options outlined in the table below.
* Place in your ScreenConnect Toolbox for easy access and transfer.
* Transfer SCGuardian.ps1 to your client and move the script if you do not like where ScreenConnect drops it on the client machine.  `-install` flag anyone?
* Execute the following commands in the Command section of your ScreenConnect console.

  `powershell -file "c:\users\demo\files\SCGuardian.ps1" -register -recovery -delayedstart`

##### Command above will perform the following --
* Register a task to run the script every 5 minutes with the `-check` flag.
* Set client service auto-recovery settings to Restart/Restart/Take No Action.
* Set the ScreenConnect Client service to Automatic (Delayed Start)

SCGuardian.ps1 - Configuration Settings
---------------------------------------
The script will handle finding the necessary information needed to peform its job based on various factors.  However, the settings below revolve around changes outside of the client so adjustments to the script based on your needs may be necessary.  For example, does your ScreenConnect Server run SSL?  Non-standard HTTP and/or Relay Port?

###### $strServerSettings
<table>
<tr>
  <td>SSL</td>
  <td>Set to <b>True</b> if your ScreenConnect Server is running SSL</td>
</tr>
<tr>
  <td>Port</td>
  <td>Set to <b>443</b> if running SSL, otherwise set to Port running the SC web service.</td>
</tr>
<tr>
  <td>ExtDir</td>
  <td>Leave set <b>App_Extensions</b> unless you have a customized installation.</td>
</tr>
<tr>
  <td>ExtGUID</td>
  <td>If the <b>Extension GUID</b> of the Guardian Extension is different on your server, change this value.</td>
</tr>
<tr>
  <td>EndPoint</td>
  <td><b>Service.ashx</b> - ScreenConnect Guardian Extension Endpoint</td>
</tr>
<tr>
  <td>Secret</td>
  <td><b>IntegrationKey</b> - The IntegrationKey which was set in the Extension settings.</td>
</tr>
<tr>
  <td>Method</td>
  <td><b>ConsoleConnectionStatus</b> - Method the script will call to check a client GUID.</td>
</tr>
</table>

###### $strClientSettings
<table>
<tr>
  <td>RelayPort</td>
  <td><b>8041</b> - If configured differently at your server, update this value.</td>
</tr>
<tr>
  <td>LogDir</td>
  <td>Set your Logging Directory.  By default, logs are saved to the script directory.</td>
</tr>
<tr>
  <td>LogFileName</td>
  <td>Set the name of the log file.</td>
</tr>
</table>

SCGuardian.ps1 - Switch Flags
---------------------------------------
##### -check
`./SCGuardian.ps1 -check`

When executed, the Start-Guardian function will test the reachability of the ScreenConnect host followed by checking with the Guardian Extension at the server-level to verify the server sees the client as connected. The reachability test is an ICMP (ping) test for troubleshooting followed by a direct TCP connection to the configured Relay Port.  If the server is reachable, the Guardian Extension is called with the client GUID to check the status at the console.  If the server reports back that the client appears "offline" the script will restart the ScreenConnect Client in an attempt to reestablish connection.

##### -delayedstart
`./SCGuardian.ps1 -delayedstart`

Slow or problematic machines, specifically during startup, can create timeout scenarios with the client service.  Having said that, running this flag will set the ScreenConnect Client Service to Automatic (Delayed Start) to try and ease the issue.

##### -register
`./SCGuardian.ps1 -register`

This flag will register a scheduled task at 5 minute intervals to run the `-check` flag.  A separate function has been provided for "old school" scheduled tasks via SCHTASKS to support PowerShell 2.0 as well as the newer PowerShell 3.0+ functions to create tasks.

##### -recovery
`./SCGuardian.ps1 -recovery`

Running this flag will set the ScreenConnect Client service Automatic Recovery Options.  The options will be set to First Failure - Restart, Second Failure - Restart, Subsequent Failures - Take No Action.

##### -stop
`./SCGuardian.ps1 -stop`

Stop the ScreenConnect Client Service.

##### -start
`./SCGuardian.ps1 -start`

Start the ScreenConnect Client Service.

##### -restart
`./SCGuardian.ps1 -restart`

Restart the ScreenConnect Client Service.

Contribute
-------------------------------
* Fork it!
* Create your feature branch: `git checkout -b my-new-feature`
* Commit your changes: `git commit -am 'my new feature'`
* Push to the branch: `git push origin my-new-feature`
* Submit a pull request `:D`

History
-------------------------------
Release and Revision History
1. `v0.0.1   Alpha as Fuck`

Credits
-------------------------------
* My Muse AZ
* LogMeIn Business Practices
* Reno 911!
* Guys & Gals in the ScreenConnect Forums

License
-------------------------------
GNU General Public License v3.0
