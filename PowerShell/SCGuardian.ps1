<#
    .SYNOPSIS
        Set of functions to perform various tasks in the capacity of examining
        the online relationship between the ScreenConnect host and client.   

    .DESCRIPTION
        The core function, Start-Guardian, will check reachability of the configured
        ScreenConnect host by first running an ICMP (ping) test followed by a direct
        TCP connection to the host on the configured relay port. As the server is up
        and running the client should be connected correct?  Not always.  The name of
        the game with remote access is making sure you have remote access.  Make a request 
        to the ScreenConnect Guardian Extension (installed on the SC Server) to request 
        the online status of the client via GUID to determine the online status at the 
        console.  If the server is showing the client as offline, restart the service to 
        reestablish the connection relationship.    

    .NOTES
        File Name  : SCGuardian.ps1
        Author     : Justin Lyric - jlyric@outlook.com
        Requires   : PowerShell Version 2.0
        Tested     : PowerShell Version 5.0

    .PARAMETER check
        Will fire the Start-Guardian function to test reachability and client connection
        status at the server level.  If the server is reachable at the client but the client
        is showing as offline at the server, the script will restart the ScreenConnect service
        in an attempt to reestablish connection.

    .PARAMETER stop
        Stop the ScreenConnect Client Servce

    .PARAMETER start
        Start the ScreenConnect Client Service 

    .PARAMETER restart
        Restart the ScreenConnect Client Service

    .PARAMETER register
        Set a Windows Scheduled Task to run the Start-Guardian function every 5 minutes.  Time is configurable
        by editing the TimeSpan variable within the function.  TODO: Make the Scheduled Task options more
        configurable.
    
    .PARAMETER recovery
        By default the ScreenConnect Client service does not have employ Automatic Service Recovery.  Run the script
        with this argument to set the ScreenConnect Client service recovery options to Restart/Restart/Take No Action.


    .EXAMPLE
        C:\PS> ./SCGuardian.ps1 -check
        Run the Set-Guardian Function

    .EXAMPLE
        C:\PS> ./SCGuardian.ps1 -recovery -register
        Set the Automatic Service Recovery Options and Register a Scheduled Task

    .EXAMPLE
        C:\PS> ./SCGuardian.ps1 -restart -check
        Restart the ScreenConnect Client Service and run Start-Guardian

    .LINK
        http://github.com/jlyric/scguardian

    .LINK
        Start-Guardian
#>
[Cmdletbinding()]
param(
   [switch]$check = $false, 
   [switch]$stop = $false,
   [switch]$start = $false,
   [switch]$restart = $false,
   [switch]$delayedstart = $false,
   [switch]$register = $false,
   [switch]$recovery = $false
)

#TODO:  What about an -install flag which transfers the file to the ScreenConnect directory?

Set-ExecutionPolicy ByPass;

$strServerSettings = @{}
$strServerSettings = @{
    # ScreenConnect Server Web Protocol
    "SSL" = "true";
    # ScreenConnect Server Web Port
    "Port" = 443;
    # ScreenConnect Extensions Folder 
    "ExtDir" = "App_Extensions";
    # GUID of ScreenConnect Guardian Companion Extension
    "ExtGUID" = "de9b663e-1025-46dc-b16f-e9e00785f4d1";
    # ScreenConnect Gurdian EndPoint
    "EndPoint" = "Service.ashx";
    # ScreenConnect Integration Key
    "Secret" = "sup3rs3cr3t";
    # Method Checking Client Console Status 
    "Method" = "ConsoleConnectionStatus";  
}
$strClientSettings = @{
    # ScreenConnect Client Relay Port (Script will update based on client settings!)
    "RelayPort" = 8041
    # Logging Directory
    "LogDir" = (Split-Path $script:MyInvocation.MyCommand.Path)
    # Logging FileName
    "LogFileName" = "scguardian.log.txt";
}
$strClientSettings = @{
    # Do Not Edit
    "LogFile" = ([string]$strClientSettings['LogDir']) + "\" + ([string]$strClientSettings['LogFileName']);
}

function Start-Guardian {
<#
    .SYNOPSIS 
        Helper ScreenConnect "Guardian" function which checks the ScreenConnect server/client 
        online relationship and acts accordingly.

    .DESCRIPTION
        When executed the function will test the reachability of the ScreenConnect host 
        followed by checking with the Guardian Extension at the server-level to verify 
        the server sees the client as connected. The reachability test is an ICMP (ping)
        test for troubleshooting followed by a direct TCP connection to the configured
        Relay Port.  If the server is reachable, the Guardian extension is called with the
        client GUID to check the status at the console.  If the server reports back that
        the client appears "offline" the script will restart the ScreenConnect client in an
        attempt to re-establish connection.

    .INPUTS
        None. You cannot pipe objects to Start-Guardian.

    .OUTPUTS
        System.Boolean. True = OK, False = Trouble.

    .EXAMPLE
        C:\PS> ./SCGuardian.ps1 -check
        True

    .LINK
        http://github.com/jlyric/

    .LINK
        Start-Guardian
#>
    Write-Log ("(Start-Guardian): Initializing!");
   
    # Each installation has a unique 'ThumbPrint' which we use in later functions.  
    # Looking at your services -> ScreenConnect Client (This is the ThumbPrint)
    # This is NOT the client GUID.
    $strThumbPrint = Get-Thumbprint;

    if(-not $strThumbPrint) {

        Write-Log ("Problem determining thumbprint!  Is the ScreenConnect Client Installed?");
        return $false
    }


    # Armed with the ThumbPrint we can grab the ImagePath from the registry.
    # The ImagePath contains installation, client and server details.
    $strImagePath = Get-ImagePath -strThumbPrint $strThumbPrint

    if(-not $strImagePath) {

        Write-Log ("ImagePath variables were not retrievable from the registry! Is the ScreenConnect Client Installed?");
        return $false

    }

    # The ImagePath is a string which we need to parse.
    # You can find details of this transaction in the $strClientSettings Array
    # Get-ClientSession contains more details on the strClietnSettings String Array
    $objSession = Get-ClientSession -strImagePath $strImagePath;
 
    if(-not $strClientSettings['SessionID']) { # ScreenConnect Client is likely not installed.
        Write-Log ("Parsing client/server details failed!  Unable to determine the necessary GUID.");            
        return $false;
    } else {
        $strClientSettings.GetEnumerator() | Sort-Object Name | ForEach-Object { "[" + (Get-Date) + "]: {0}: {1}" -f $_.Name, $_.Value} | Add-Content $strClientSettings['LogFile']
    }

    $test = Test-Reachability;

    if($test) { # Host Reachable

        Write-Log ("Host @ " + $strClientSettings['Host'] + " is reachable! Checking Server Console...");
       
        # Check if the Screen Connect Server is showing this client as connected...
        [boolean]$blnConsole = Get-ConsoleStatus;

        if( $blnConsole ) { # OK

            Write-Log ("Host @ " + $strClientSettings['Host'] + " is reachable and console is showing us as connected!");

            return $true

        } else { # Showing as offline, let's restart the ScreenConnect Client service

           Write-Log ("Host @ " + $strClientSettings['Host'] + " is reachable but console is showing us as offline!  Initiating Service Restart!");

           $blnRestart = Service-Restart

           if($blnRestart) {
                return $true
           } else {
                return $false
           }
       }
  
   } else { # Host Unreachable

       Write-Log ("Host @ " + $strClientSettings['Host'] + " is currently unreachable from this location!  Check the ping test above!");
       return $false
   }

   Write-Log ("(Start-Guardian): Check Complete!");
}
function Test-Reachability {
<#
    .SYNOPSIS 
        Checks if the ScreenConnect Host is online and available.

    .DESCRIPTION
        First the function will run a simple ICMP (ping) test primarily
        for troubleshooting purposes.  Next, it will try to establish a
        direct TCP connection to the host at the relay port.  

    .INPUTS
        None. You cannot pipe objects to Test-Reachability.

    .OUTPUTS
        System.Boolean. True = Reachable, False = Unreachable.

    .EXAMPLE
        C:\PS> $test = Test-Reachability;
        C:\PS> $test
        True

    .LINK
        http://github.com/jlyric/

    .LINK
        Test-Reachability
#>  
   if(-not $strClientSettings['Host']) { return $false; } # Bullshit Validation

    # TODO: Allow this function to accept alternative hosts and ports so we can call this directly.
    # TODO: Better error handling.

   try {

        Write-Log ("ICMP (Ping) Reachability to ScreenConnect Server @ " + $strClientSettings['Host'] + ".  Reachability results included in next line:");

        $icmp = Test-Connection -ComputerName $strClientSettings['Host'] -Count 4 -ErrorAction Stop;

        Write-Log ($icmp);


        Write-Log ("Testing direct TCP connection @ " + $strClientSettings['Host'] + ":" + $strClientSettings['RelayPort'] + "...");

        $t = New-Object Net.Sockets.TcpClient $strClientSettings['Host'], $strClientSettings['RelayPort']

        if($t.Connected) 
        {
            Write-Log ("Direct connection from client to ScreenConnect Server @ " + $strClientSettings['Host'] + ":" + $strClientSettings['RelayPort'] + " was successful!");
            return $true;
        } else {
            Write-Log ("Direct connection from client to ScreenConnect Server @ " + $strClientSettings['Host'] + ":" + $strClientSettings['RelayPort'] + " failed!");
            return $false;
        }

   } catch {

        Write-Log ($_.Exception.Message);
        return $false;
   }
}
function Get-Thumbprint {
<#
    .SYNOPSIS 
        Retrieves the 16-digit Public Key Thumbprint of the ScreenConnect Client installation.

    .DESCRIPTION
        "...Derived from the asymmetric cryptography, the public key thumbprint can be 
        used to identify a remote Access client to a specific ScreenConnect server after 
        it has been installed. This 16-character long string appears in a few places on 
        the client side, but the easiest location to find it is in the client's installation 
        folder (C:\Program Files (x86)\ScreenConnect Client (xxxxxxxxxxxxxxxx) on Windows 
        and /opt/screenconnect-xxxxxxxxxxxxxxxx on Mac and Linux, the x's denote the 
        thumbprint)..."

        FYI - This script checks Services instead of the installation directory.  I find this
        is a more reliable way to decide of the client is actually "installed" instead of just
        a previous installation left behind.

    .INPUTS
        None. You cannot pipe objects to Get-Thumbprint.

    .OUTPUTS
        System.String. Get-Thumbprint will return the 16-digit public key thumbprint.

    .EXAMPLE
        C:\PS> $print = Get-Thumbprint;
        C:\PS> $print
        3560909876132514

    .LINK
        http://github.com/jlyric/scguardian

    .LINK
        Get-Thumbprint
#>
    Write-Log ("Determining ScreenConnect Client Thumbprint...");

    $strService = Get-Service | Where-Object {$_.name -like "*ScreenConnect Client*"};

    if($strService) {

        $strThumbPrint = $strService.DisplayName.Split("(")[1].Split(")")[0];
        Write-Log ("Client Thumbprint successfully parsed as - " + $strThumbPrint);

        return $strThumbPrint

    } else {

        Write-Log ("Client Thumbprint was not found.  Is the ScreenConnect Client Installed?");
        return $false

    }
}
function Get-ImagePath {
<#
    .SYNOPSIS 
        Retrieves the ScreenConnect Client ImagePath key from the registry. 

    .DESCRIPTION
        The ImagePath key contains server, client and installation details.  This helps 
        us setup muchnof the script with the necessary information.
    
    .PARAMETER strThumbPrint
        ScreenConnect Client Thumbprint usually provided by Get-Thumbprint

    .INPUTS
        None. You cannot pipe objects to Get-ImagePath.

    .OUTPUTS
        System.String. Get-ImagePath returns the ImagePath registry key value.

    .EXAMPLE
        C:\PS> $imgpath = Get-ImagePath -strThumbprint 93erf82312kiu312;
        C:\PS> $imgpath;
        "C:\Program Files (x86)\ScreenConnect Client (93erf82312kiu312)\ScreenConnect.ClientService.exe" "?e=Access&y=Guest&h=host.yourserver.com&p=8041&s=76512309-42gb-a8z2-a46e-e08aufoi7321&k=[NOPE!]&t=WS%20-%20PC231-NYC&c=NYC&c=&c=Workstation&c=&c=&c=&c=&c="

    .LINK
        http://github.com/jlyric/scguardian

    .LINK
        Get-ImagePath

#>
    param([string]$strThumbPrint);

    # TODO: Setup an Alias for strThumbprint

    Write-Log ("Retrieving the ImagePath from the registry...");

    if($strThumbPrint) {

        $strKey = 'HKLM:\SYSTEM\CurrentControlSet\Services\ScreenConnect Client (' + $strThumbPrint + ')';
        $strImagePath = (Get-ItemProperty -Path $strKey -Name ImagePath).ImagePath;
        Write-Log ("ImagePath: " + $strImagePath);

        return $strImagePath;

    } else {

        Write-Log ("Unable to parse the ImagePath.  Registry permissions?  Is the ScreenConnect Client Installed?");

        return $false
    }
}
function Get-ClientSession {
<#
    .SYNOPSIS 
        Parses an ImagePath string into an array which contains client, server and
        installation details.

    .DESCRIPTION
        The ImagePath string contains variables necessary for the script to perform 
        various tasks such as the SessoinID (GUID).  This function will parse those 
        details into an array which can easily be accessed throughout the script.  

    .PARAMETER strImagePath
        The ImagePath string usually retrieved via Get-ImagePath.

    .INPUTS
        None. You cannot pipe objects to Get-ClientSession.

    .OUTPUTS
        System.Boolean.  True = Parse OK, False = Trouble

    .EXAMPLE
        C:\PS> $imgpath = Get-ImagePath -strThumbprint 93erf82312kiu312;
        C:\PS> Get-ClientSession -strImagePath $imgpath;
        C:\PS> $strClientSettings['SessionID']
        76512309-42gb-a8z2-a46e-e08aufoi7321

    .EXAMPLE
        C:\PS> $bool = Get-ClientSession -strImagePath $imgPath;
        True

    .LINK
        http://github.com/jlyric/scguardian

    .LINK
        Get-ClientSession
#>
    param([string]$strImagePath);
    
    # TODO:  Alias the strThumbprint Parameter

    if($strImagePath) {

        Write-Log ("Parsing the ImagePath for client/server session details...");

        $strQuery = $strImagePath -split '"\s"' 
        $intCount = 1;

        $strQuery[1].split('"?')[1].split('&')  | ForEach {
    
            $strPair = $_.split("=")
            $strKey = $strPair[0]
            $strValue = $strPair[1]

        switch ($strKey)
        {
            "e" { $strClientSettings.Add('SessionType', $strValue ) } # SessionType
            "y" { $strClientSettings.Add('ProcessType', $strValue ) } # ProcessType
            "h" { $strClientSettings.Add('Host', $strValue ) } # Host
            "p" { $strClientSettings.Add('RelayPort', $strValue ) } # RelayPort
            "s" { $strClientSettings.Add('SessionID', $strValue ) } # SessionID
            "k" { $strClientSettings.Add('AsymmetricKey', $strValue ) } # AsymmetricKey
            "i" { $strClientSettings.Add('SessionName', $strValue ) } # SessionName
            "c" { $strClientSettings.Add('CustomProperty' + $intCount, $strValue ); $intCount++ } # CustomProperties
            "t" { $strClientSettings.Add('NameCallBackFormat', $strValue ) } # NameCallBackFormat
            default { } # Borked

        }
     }

      return $true;

   } else {
        return $false;
   }

}
function Get-ConsoleStatus {
<#
    .SYNOPSIS 
        Get the ScreenConnect Server status of the supplied Client (GUID)

    .DESCRIPTION
        The function will initiate a request to the ScreenConnect Guardian
        Extension installed on the ScreenConnect Server.  The request will
        check to see if the supplied client is showing as connected or not.
        Currently this function should only be run after the $strClientSettings
        variable has been populated.

    .INPUTS
        None. You cannot pipe objects to Get-ConsoleStatus.

    .OUTPUTS
        System.Boolean True = Connected, False = Not Connected

    .EXAMPLE
        C:\PS> Get-ConsoleStatus
        True

    .LINK
        http://github.com/jlyric/scguardian

    .LINK
        Get-ConsoleStatus
#>
    $strProtocol = switch($strServerSettings['ssl']) { "true" { "https://"} default { "http://" } }

    # TODO: Many parameter overrides should be available here.  Primarily the ability
    # to specify an alternate client SessionID (GUID).

    # Setup the API Endpoint with GUID
    $strAPI = $strProtocol + $strClientSettings['Host'] + ":" + $strServerSettings['Port'] + "/" + $strServerSettings['ExtDir'] + "/" + $strServerSettings['ExtGUID'] + "/" + $strServerSettings['Endpoint'] + "/" + $strServerSettings['Method']  + "/" + $strServerSettings['Secret'] + "/" + $strClientSettings['SessionID'];
    #$strAPI = $strProtocol + $strClientSettings['Host'] + ":" + $strServerSettings['Port'] + "/" + $strServerSettings['ExtDir'] + "/" + $strServerSettings['ExtGUID'] + "/" + $strServerSettings['Endpoint'] + "/" + $strServerSettings['Method']  + "/" + $strServerSettings['Secret'] + "/fe56cdb5-8a54-4456-9e28-de302d90e212";
    Write-Log ("Checking client connection status at the ScreenConnect console for client " + $strClientSettings['SessionID'] + "...");

    try {

        $objRequest = [System.Net.HTTPWebRequest]::Create($strAPI)
        $objRequest.Method = "get"
        $objRequest.ContentType = "application/json"
        $objRequestStream = $objRequest.GetResponse().GetResponseStream()
        $objReadStream = New-Object System.IO.StreamReader $objRequestStream
        $strData = $objReadStream.ReadToEnd()
        $objReadStream.Dispose();
        $objReadStream.Close();
    
        switch($strData) {
            "true" {  # Online

                Write-Log ("ScreenConnect console status for client " + $strClientSettings['SessionID'] + ": ONLINE");
                return $true 

            }
            "false" {  # Offline

                Write-Log ("ScreenConnect console status for client " + $strClientSettings['SessionID'] + ": OFFLINE");
                return $false 

            }
            default {  # Unexpected Results

                Write-Log ("ScreenConnect console status for client " + $strClientSettings['SessionID'] + ": UNEXPECTED");
                return $false 

            }
        } 

    } catch { # Failure during Request

        Write-Log ("Unable to successfully communicate with the ScreenConnect server.  Is the SCGuardian Extension installed server-side?  Is the server reachable?");
        Write-Log ($strAPI);
        return $false
    }
}
function Service-Stop { 
<#
    .SYNOPSIS 
        Stop the ScreenConnect Client

    .DESCRIPTION
        Stop the ScreenConnect Client

    .INPUTS
        None. You cannot pipe objects to Service-Stop.

    .OUTPUTS
        System.Boolean True = Stopped, False = Trouble

    .EXAMPLE
        C:\PS> ./SCGuardian.ps1 -stop
        True

    .LINK
        http://github.com/jlyric/scguardian

    .LINK
        Service-Stop
#>    
    $strSVC = "ScreenConnect Client (" + (Get-Thumbprint) + ")";
    Write-Log ("Trying to stop service - " + $strSVC);

    try {
        Stop-Service $strSVC
        Write-Log ($strSVC + " - was successfully stopped!");

        return $true

    } catch {
        Write-Log ($_.Exception.Message);

        return $false
    }
}
function Service-Start {
<#
    .SYNOPSIS 
        Start the ScreenConnect Client

    .DESCRIPTION
        Start the ScreenConnect Client

    .INPUTS
        None. You cannot pipe objects to Service-Start.

    .OUTPUTS
        System.Boolean. Service-Start returns a boolean based on success or failure.

    .EXAMPLE
        C:\PS> ./SCGuardian.ps1 -start
        True

    .LINK
        http://github.com/jlyric/scguardian

    .LINK
        Service-Start
#>
    $strSVC = "ScreenConnect Client (" + (Get-Thumbprint) + ")";
    Write-Log ("Trying to start service - " + $strSVC);
    try {
        Start-Service $strSVC
        Write-Log ($strSVC + " - was successfully started!");

        return $true

    } catch {
        Write-Log ($_.Exception.Message);

        return $false
    }
}
function Service-Restart {
<#
    .SYNOPSIS 
        Restart the ScreenConnect Client

    .DESCRIPTION
        Restart the ScreenConnect Client

    .INPUTS
        None. You cannot pipe objects to Service-Restart.

    .OUTPUTS
        System.Boolean. Service-Restart returns a boolean based on success or failure.

    .EXAMPLE
        C:\PS> ./SCGuardian.ps1 -restart
        True

    .LINK
        http://github.com/jlyric/scguardian

    .LINK
        Service-Restart
#>
    $strSVC = "ScreenConnect Client (" + (Get-Thumbprint) + ")";
    Write-Log ("Trying to restart service - " + $strSVC);

    try {
        Restart-Service -DisplayName $strSVC -ErrorAction Stop
        Write-Log ($strSVC + " - was successfully restarted!");

        return $true

    } catch {
        Write-Log ($_.Exception.Message);
        return $false
    }
}
function Set-Recovery-Options {
<#
    .SYNOPSIS 
        Set Automatic Service Recovery options for the
        ScreenConnect Client.

    .DESCRIPTION
        Often times the ScreenConnect client will have trouble starting or delayed due
        to slow starts.  This function will set the Automatic Service Recovery options
        to the following:

        First Failure: Restart the Service
        Second Failure: Restart the Service
        Subsequent Failures: Take No Action

    .INPUTS
        None. You cannot pipe objects to Set-Recovery-Options.

    .OUTPUTS
        System.Boolean. Set-Recovery-Options returns a boolean depending on success or failure.

    .EXAMPLE
        C:\PS> ./SCGuardian.ps1 -recovery
        True

    .LINK
        http://github.com/jlyric/scguardian

    .LINK
        Set-Recovery-Options
#> 
    $strSVC = "ScreenConnect Client (" + (Get-Thumbprint) + ")";
    # TODO: Allow for user defined scenarios via parameters. 
    Write-Log ("Trying to set service recovery options for " + $strSVC + ": Restart/Restart/Take No Action...");
    try {
        $strServices = Get-WMIObject win32_service | Where-Object { $_.name -imatch "ScreenConnect" -and $_.startmode -eq "Auto" }; 
        foreach ($strService in $strServices){sc.exe failure $strService.name reset= 86400 actions= restart/5000/restart/5000/""/5000 }
        Write-Log ($strSVC + " - recovery options successfully set!");

        return $true

    } catch {
        Write-Log ($_.Exception.Message);

        return $false
    }
}
function Set-Delayed-Start {
<#
    .SYNOPSIS 
        Set the ScreenConnect Client Service to Delayed Start.

    .DESCRIPTION
        Slow or problematic machines can create service timeout scenarios.
        I've been using this on all of my machines with success.

    .INPUTS
        None. You cannot pipe objects to Set-Delayed-Start.

    .OUTPUTS
        System.Boolean. Set-Recovery-Options returns a boolean depending on success or failure.

    .EXAMPLE
        C:\PS> ./SCGuardian.ps1 -delayedstart 
        True

    .LINK
        http://github.com/jlyric/scguardian

    .LINK
        Set-Delayed-Start
#>
    $strSVC = "ScreenConnect Client (" + (Get-Thumbprint) + ")";
    # TODO: Allow for user defined scenarios via the startup types
    #       Automatic (Delayed Start), Automatic, Manual, Disabled.  
    Write-Log ("Trying to set service - " + $strSVC + " for a Delayed Start...");
    try {
        $strServices = Get-WMIObject win32_service | Where-Object { $_.name -imatch "ScreenConnect" -and $_.startmode -eq "Auto" }; 
        foreach ($strService in $strServices){sc.exe config $strService.name start= delayed-auto}
        Write-Log ($strSVC + " - Startup type set to Delayed!");

        return $true

    } catch {
        Write-Log ($_.Exception.Message);

        return $false
    }
}
function Set-Guardian-Task { 
<#
    .SYNOPSIS 
        Adds a scheduled task to run the Guardian.

    .DESCRIPTION
        Register a scheduled task to run this script every 5 minutes.  
        The path will be set to the location of the script.  It's the
        equivalent of running -check every 5 minutes.  Accounts for
        old-style PowerShell 2.0 tasks and newer PowerShell 3.0-style
        tasks.

    .INPUTS
        None. You cannot pipe objects to Set-Guardian-Task.

    .OUTPUTS
        System.Boolean. Set-Guardian-Task returns a boolean based on success or failure.

    .EXAMPLE
        C:\PS> ./SCGuardian.ps1 -register
        True

    .LINK
        http://github.com/jlyric/scguardian

    .LINK
        Set-Guardian-Task
#>
    Write-Log ("Setting a scheduled task for the ScreenConnect Guardian...");

    # TODO: Lots of area for user defined configuration via parameters.

    $strExecutable = "powershell.exe"
    $strTaskName = "ScreenConnect Guardian"
    $strDescription = "The SCGuardian monitors the ScreenConnect client from various angles to try and keep the client connected.  It also offers various functions in this capacity."
    $strExecution = $script:MyInvocation.MyCommand.Path;

    try {
        
        if( $PSVersionTable.PSVersion.Major -gt 2 ) {
            $objAction = New-ScheduledTaskAction -execute $strExecutable -argument $strArguments
            $strRepeatTimeSpan = New-TimeSpan -Minutes 5;
            $strDurationTimeSpan = New-TimeSpan -Days 1000;
            $strAt = $(Get-Date) + $strRepeatTimeSpan;
            $objTrigger = New-ScheduledTaskTrigger -Once -At $strAt -RepetitionInterval $strRepeatTimeSpan -RepetitionDuration $strDurationTimeSpan;
            $objSettings = New-ScheduledTaskSettingsSet -StartWhenAvailable
            Register-ScheduledTask -TaskName $strTaskName -Trigger $objTrigger -Action $objAction -Setting $objSettings -description $strDescription -User "NT AUTHORITY\SYSTEM" -RunLevel 1
        } else {
            schtasks /create /sc minute /mo 5 /tn "$strTaskName" /tr "$strExecutable -file '$($strExecution)' -check" /it /rl highest /ru system 
        }

        Write-Log ("The scheduled task for ScreenConnect Guardian has been successfully created!");
        return $true

    } catch {
        Write-Log ($_.Exception.Message);

        return $false
    }
}
function Write-Log {
<#
    .SYNOPSIS 
        Writes an entry to the log file defined in the configuration.

    .DESCRIPTION
        Will make an entry into a defined log file with a timestamp.
        Enter a blank entry and the timestamp is not included.

    .PARAMETER strEntry
        What is to be written to the file

    .INPUTS
        None. You cannot pipe objects to Write-Log.

    .OUTPUTS
        None. 

    .EXAMPLE
        C:\PS> Write-Log("Write to the log please.");

    .EXAMPLE
        C:\PS> Write-Log -strEntry "Write to the log please."

    .LINK
        http://github.com/jlyric/scguardian

    .LINK
        Write-Log
#>
    param ([string]$strEntry)

    #TODO: Parameters for more customization is necessary.
    #TODO: Alias strEntry

    if($strEntry) {
        $strAdd = "[" + (Get-Date) + "]: " + $strEntry;
    } else {
        $strAdd = $strEntry;
    }

    Write-Host $strAdd;
    Add-Content $strClientSettings['LogFile'] -value $strAdd

}

Write-Log ("********************************");
Write-Log ("ScreenConnect Guardian v0.0.1");
Write-Log ("Running @ " + (Get-Date -Format F));

if ($check) { 
    Write-Log ("Check flag specified...");
    $( Start-Guardian ); 
}
if ($stop) { 
    Write-Log ("Stop service flag set...");
    Service-Stop 
} 
if ($start) { 
    Write-Log ("Start service flag set...");
    Service-Start 
} 
if ($restart) { 
    Write-Log ("Restart service flag set...");
    Service-Restart 
} 
if ($delayedstart) {
    Write-Log ("Delayed Start service flag set...");
    Set-Delayed-Start
}
if ($register) { 
    Write-Log ("Register task flag set...");
    Set-Guardian-Task 
} 
if ($recovery) {
    Write-Log ("Set service recovery options flag set...");
    Set-Recovery-Options 
}

Write-Log ("Complete @ " + (Get-Date -Format F));
Write-Log ("=================================");
Write-Log ("");
