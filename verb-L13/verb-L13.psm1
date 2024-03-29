﻿# verb-l13.psm1


  <#
  .SYNOPSIS
  verb-L13 - Powershell Lync 2013 generic functions module
  .NOTES
  Version     : 1.0.13.0.0.0.0.0.0.0
  Author      : Todd Kadrie
  Website     :	https://www.toddomation.com
  Twitter     :	@tostka
  CreatedDate : 3/16/2020
  FileName    : verb-L13.psm1
  License     : MIT
  Copyright   : (c) 3/16/2020 Todd Kadrie
  Github      : https://github.com/tostka
  AddedCredit : REFERENCE
  AddedWebsite:	REFERENCEURL
  AddedTwitter:	@HANDLE / http://twitter.com/HANDLE
  REVISIONS
  * 4:59 PM 3/16/2020 1.0.0.0public cleanup
  * 11:38 AM 12/30/2019 ran vsc alias-expan
  * 10:14 AM 11/20/2019 rl13: added cred support
  * 3:16 PM 5/14/2019 added lab lyncadminpool support
  * 12:16 PM 5/6/2019 shfited to leverage this and added cl13,rl13 & dl13 aliases.
  * 3:03 PM 5/14/2019 add lab pool spec
  * 3:04 PM 3/4/2019 rough-in a full set of connect/disconnect/reconnect-l13()'s  NON-FUNCTIONAL, SID profile.ps1 IS SETTING INCLUDE DIR TO PROFILE SID DIR, INSTEAD OF C:\USR\WORK\EXCH\SCRIPTS\.
  * 1:02 PM 11/7/2018 updated Disconnect-PssBroken
  # 10:37 AM 9/12/2018 initial port (thot I had it done before - it's in profile)
  .DESCRIPTION
  verb-L13 - Powershell Lync 2013 generic functions module
  .LINK
  https://github.com/tostka/verb-L13
  #>


$script:ModuleRoot = $PSScriptRoot ;
$script:ModuleVersion = (Import-PowerShellDataFile -Path (get-childitem $script:moduleroot\*.psd1).fullname).moduleversion ;

#*======v FUNCTIONS v======



#*------v Add-LMSRemote.ps1 v------
Function Add-LMSRemote {
    <#
    .SYNOPSIS
    Add-LMSRemote - Remote Lync Mgmt Shell
    .NOTES
    Hybrid of dsolodow's & my remote code
    Author: Todd Kadrie
    Website:	https://www.toddomation.com
    Twitter:	https://twitter.com/tostka
    REVISIONS   :
    # 10:47 AM 9/12/2018 grabbed from tsksid-incl-ServerApp.ps1
    # 1:19 PM 4/6/2016 get-admincred now outputs to $global:SIDcred, updated splat
    # 1:16 PM 8/19/2015
    .LINK
    https://github.com/dsolodow/IndyPoSH/blob/master/Profile.ps1
    #>
    # provide a fault-tolerant pool connection for LMS
    switch ($env:USERDOMAIN){
        "$($TORMeta['legacyDomain'])" {$LyncAdminPool=$TORMeta['LyncAdminPool'] }
        "$($TOLMeta['legacyDomain'])" {$LyncAdminPool=$TOLMeta['LyncAdminPool'] }
    } ;
    if(test-connection $LyncAdminPool -count 1 -quiet){
      $LyncFE = $LyncAdminPool ;
    } else {
      $LyncFE = (Get-LyncServerInSite) ;
    } ;
    $LyncConnectionURI  = "https://$($LyncFE)/OcsPowershell"  ;
    If ( (!(Get-PSSession -Name 'Lync2013' -ErrorAction SilentlyContinue)) -AND (Test-Connection $LyncFE -count 1)) {
        #1:38 PM 8/19/2015 only prompt if it's not running SID
        $sesOpts = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck ;
        $LMSsplat=@{ConnectionURI=$LyncConnectionURI; name='Lync2013';SessionOption=$sesOpts};
        Get-AdminCred ;
        $LMSsplat.Add("Credential",$global:SIDcred);
        Add-PSTitleBar 'LMS' ;
        # set color scheme to White text on Black
        $HOST.UI.RawUI.BackgroundColor = "Black" ; $HOST.UI.RawUI.ForegroundColor = "White" ;
        write-host "Adding LMS (connecting to $($LyncConnectionURI))..."
        $Session = New-PSSession @LMSSplat
        Import-PSSession $Session ;
        $Session | Select-Object ComputerName,Availability | format-table -auto |out-default;
    } ;
}

#*------^ Add-LMSRemote.ps1 ^------

#*------v check-L13DrainStop.ps1 v------
Function check-L13DrainStop {
    <#
    .SYNOPSIS
    check-L13DrainStop - Dawdleloop to monitor CSWindowsServices for Draining ServiceStatus
    .NOTES
    Author: Todd Kadrie
    Website:	http://www.toddomation.com
    Twitter:	@tostka / http://twitter.com/tostka
    AddedCredit : Inspired by concept code by ExactMike Perficient, Global Knowl... (Partner)
    AddedWebsite:	https://social.technet.microsoft.com/Forums/msonline/en-US/f3292898-9b8c-482a-86f0-3caccc0bd3e5/exchange-powershell-monitoring-remote-sessions?forum=onlineservicesexchange
    Version     : 1.0.0
    CreatedDate : 2020-11-03
    FileName    : check-L13DrainStop
    License     : MIT License
    Copyright   : (c) 2020 Todd Kadrie
    Github      : https://github.com/tostka/verb-L13
    Tags        : Powershell,Lync,Lync2013,Skype
    Website:    : toddomation.com
    REVISIONS   :
    * 11:31 AM 11/3/2020 init version
    .DESCRIPTION
    check-L13DrainStop - Dawdleloop to monitor CSWindowsServices for Draining ServiceStatus
    .INPUTS
    None. Does not accepted piped input.
    .OUTPUTS
    None. Returns no objects or output.
    .EXAMPLE
    # initiate a graceful stop-cswindowsservice
    Stop-CsWindowsService -Graceful -whatif ; 
    # monitor the draining with this script:
    check-L13DrainStop -wait 30 ; 
    Drainstops local server, and runs the monitoring script with a 30second wait between passes
    .LINK
    https://github.com/tostka/verb-L13
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Position=0,HelpMessage="Dawdle wait interval (defaults 15secs)[-wait 15]")]
        $Wait=15
    )  ;
    
    $verbose = ($VerbosePreference -eq "Continue") ; 
    $1F=$false ;
    Do {
        write-host -foregroundcolor green "$((get-date).ToString('HH:mm:ss')):Still Draining" ; 
        if($1F){Sleep -s $Wait} ;  $1F=$true ; 
        $drainsvc = Get-CsWindowsService|?{$_.ServiceStatus -eq 'Draining'} ; 
        write-host -foregroundcolor green "$((get-date).ToString('HH:mm:ss')):Draining Services `n$(($drainsvc | fl Name,ActivityLevel,ServiceStatus |out-string).trim())" ; 
    } Until (($drainsvc|measure).count -eq 0) ;
    write-host "`a" ;
    write-host "`a" ;
    write-host "`a" ;
    write-host -foregroundcolor YELLOW "$((get-date).ToString('HH:mm:ss')):DONE!" ; 
    Get-CsWindowsService ; 
}

#*------^ check-L13DrainStop.ps1 ^------

#*------v Connect-L13.ps1 v------
Function Connect-L13 {
    <#
    .SYNOPSIS
    Connect-L13 - Setup Remote Exch2010 Mgmt Shell connection
    .NOTES
    Author: Todd Kadrie
    Website:	http://www.toddomation.com
    Twitter:	@tostka / http://twitter.com/tostka
    AddedCredit : Inspired by concept code by ExactMike Perficient, Global Knowl... (Partner)
    AddedWebsite:	https://social.technet.microsoft.com/Forums/msonline/en-US/f3292898-9b8c-482a-86f0-3caccc0bd3e5/exchange-powershell-monitoring-remote-sessions?forum=onlineservicesexchange
    Version     : 1.0.0
    CreatedDate : 2020-03-17
    FileName    : Connect-L13
    License     : MIT License
    Copyright   : (c) 2020 Todd Kadrie
    Github      : https://github.com/tostka/verb-L13
    Tags        : Powershell,Lync,Lync2013,Skype
    Based on idea by: ExactMike Perficient, Global Knowl... (Partner)
    Website:
    REVISIONS   :
    * 7:13 AM 7/22/2020 replaced codeblock w get-TenantTag()
    * 5:15 PM 7/21/2020 add ven supp
    * 8:28 AM 6/1/2020 fixed fundemental break on jumpboxes, shifted constants to infra file values, split out failing import-module import-pssession combo, into 2-step (latency issue when 1-linered)
    * 12:20 PM 5/27/2020 moved aliases: cl13 win func
    * 8:20 AM 3/17/2020 Connect-L13: reworked for Meta infra obj use, defaulting cred
    * 7:54 AM 11/1/2017 add titlebar tag & updated example to test for pres of Add-PSTitleBar
    * 12:09 PM 12/9/2016 implented and debugged as part of verb-L13 set
    * 2:37 PM 12/6/2016 ported to local LMSRemote
    * 2/10/14 posted version
    .DESCRIPTION
    Connect-L13 - Setup Remote Exch2010 Mgmt Shell connection
    .PARAMETER Pool
    Lync server/Pool to Remote to [-Pool ucpool.DOMAIN.COM]
    .PARAMETER CommandPrefix
    "[verb]-PREFIX[command] PREFIX string for clearly marking cmdlets sourced in this connection [-CommandPrefix tag]
    .PARAMETER  Credential
    Credential object
    .INPUTS
    None. Does not accepted piped input.
    .OUTPUTS
    None. Returns no objects or output.
    .EXAMPLE
    # -----------
    try{
        $reqMods="connect-L13;Reconnect-L13;Disconnect-L13;Disconnect-PssBroken;Add-PSTitleBar".split(";") ;
        $reqMods | % {if( !(test-path function:$_ ) ) {write-error "$((get-date).ToString("yyyyMMdd HH:mm:ss")):Missing $($_) function. EXITING." } } ;
        Reconnect-L13 ;
    } Catch {
        $msg=": Error Details: $($_)";
        Write-Error "$((get-date).ToString('yyyyMMdd HH:mm:ss')): FAILURE!" ;
        Write-Error "$((get-date).ToString('yyyyMMdd HH:mm:ss')): Error in $($_.InvocationInfo.ScriptName)." ;
        Write-Error "$((get-date).ToString('yyyyMMdd HH:mm:ss')): -- Error information" ;
        Write-Error "$((get-date).ToString('yyyyMMdd HH:mm:ss')): Line Number: $($_.InvocationInfo.ScriptLineNumber)" ;
        Write-Error "$((get-date).ToString('yyyyMMdd HH:mm:ss')): Offset: $($_.InvocationInfo.OffsetInLine)" ;
        Write-Error "$((get-date).ToString('yyyyMMdd HH:mm:ss')): Command: $($_.InvocationInfo.MyCommand)" ;
        Write-Error "$((get-date).ToString('yyyyMMdd HH:mm:ss')): Line: $($_.InvocationInfo.Line)" ;
        Write-Error  "$((get-date).ToString('yyyyMMdd HH:mm:ss')): $($msg)";
        Cleanup ;
        #Exit ;
    } ;
    .LINK
    #>
    [CmdletBinding()]
    [Alias('cl13')]
    Param(
        [Parameter(HelpMessage = "Lync server/Pool to Remote to [-Pool ucpool.DOMAIN.COM]")][string]$Pool,
        [Parameter(HelpMessage = "[verb]-PREFIX[command] PREFIX string for clearly marking cmdlets sourced in this connection [-CommandPrefix tag]")][string]$CommandPrefix,
        [Parameter(HelpMessage = "Credential to use for this connection [-credential [credential obj variable]")][System.Management.Automation.PSCredential]$Credential = $credTORSID,
        [Parameter(HelpMessage = "Debugging Flag [-showDebug]")]
        [switch] $showDebug
    )  ;
    $verbose = ($VerbosePreference -eq "Continue") ; 
    
    $LyncAdminPool = $Pool ; 
    # set the below to OP to prefix mounted commands like: get-OLMailbox == local get-Mailbox command
    # set to $null/blank to not perform prefixing
    $CommandPrefix = $null ;

    $sTitleBarTag = "LMS" ;
    
    # use credential domain to determine target org
    $rgxLegacyLogon = '\w*\\\w*' ; 
    if($Credential.username -match $rgxLegacyLogon){
        $credDom =$Credential.username.split('\')[0] ; 
    } elseif ($Credential.username.contains('@')){
        $credDom = ($Credential.username.split("@"))[1] ;
    } else {
        write-warning "$((get-date).ToString('HH:mm:ss')):UNRECOGNIZED CREDENTIAL!:$($Credential.Username)`nUNABLE TO RESOLVE DEFAULT L13SERVER FOR CONNECTION!" ;
    } ;
    $LyncAdminPool=$null ; 
    $Metas=(get-variable *meta|?{$_.name -match '^\w{3}Meta$'}) ; 
    foreach ($Meta in $Metas){
            if( ($credDom -eq $Meta.value.legacyDomain) -OR ($credDom -eq $Meta.value.o365_TenantDomain) -OR ($credDom -eq $Meta.value.o365_OPDomain)){
                $LyncAdminPool = $Meta.value.LyncAdminPool ; 
                break ; 
            } ; 
    } ;
    # force unresolved to dyn 
    if(!$LyncAdminPool){
        $LyncAdminPool = 'dynamic' ; 
    } ;

    if($LyncAdminPool -eq 'dynamic'){
        $LyncAdminPool = Get-LyncServerInSite ; 
    } ; 
    $LyncConnectionURI  = "https://$($LyncAdminPool)/OcsPowershell"  ;
    If (Test-Connection $LyncAdminPool -count 1) {
        write-verbose -verbose:$true  "$((get-date).ToString("yyyyMMdd HH:mm:ss")):Adding LMS (connecting to $($LyncAdminPool))..." ;
        # splat to open a session - # stock 'PSLanguageMode=Restricted' powershell IIS Webpool
        $pltSOpts=@{SkipCACheck=$true ;SkipCNCheck=$true ;SkipRevocationCheck=$true ;} ; 
        write-verbose -verbose:$verbose "$((get-date).ToString('HH:mm:ss')):New-PSSessionOption w`n$(($pltSOpts|out-string).trim())" ; 
        $sesOpts = New-PSSessionOption @pltSOpts ;
        $LMSsplat=@{ConnectionURI=$LyncConnectionURI; name='Lync2013';SessionOption=$sesOpts};
        if($Credential){
            $LMSsplat.Add("Credential",$Credential) ;
        } elseif($global:SIDcred) {
            $LMSsplat.Add("Credential",$global:SIDcred);
        } else {
            Get-AdminCred ;
        } ;  ;
        # -Authentication Basic only if specif needed: for Ex configured to connect via IP vs hostname)
        write-verbose -verbose:$verbose "$((get-date).ToString('HH:mm:ss')):New-PSSession w`n$(($LMSSplat|out-string).trim())" ;
        if($Global:L13Sess = New-PSSession @LMSSplat){
            write-verbose -verbose:$true  "$((get-date).ToString('HH:mm:ss')):Importing Lync 2013 Module" ;
            $pltISess=@{Session = $Global:L13Sess ;DisableNameChecking=$true ;Prefix=$CommandPrefix ;AllowClobber=$true ;} ; 
            $pltIMod=@{Global=$true; PassThru=$true; DisableNameChecking=$true;} ; 
            if($CommandPrefix){
                #$pltIMod.Add('Prefix',$CommandPrefix)
                write-verbose -verbose:$true  "$((get-date).ToString("HH:mm:ss")):Note: Prefixing this Modules Cmdlets as [verb]-$($CommandPrefix)[noun]" ;
                # tried using -PSSession for the import-PSSession spec - doesn't work (was unparam'd before)
                #$Global:L13Mod = Import-Module -Name (Import-PSSession @pltISess) -Global -Prefix $CommandPrefix -PassThru -DisableNameChecking   ;
                $Global:ImportedPSS = Import-PSSession $Global:L13Sess -DisableNameChecking -AllowClobber ; 
                $Global:L13Mod = Import-Module $Global:ImportedPSS -Global -PassThru -DisableNameChecking -Prefix $CommandPrefix ;
            } else {
                #$Global:L13Mod = Import-Module -Name (Import-PSSession $Global:L13Sess -DisableNameChecking -AllowClobber) -Global -PassThru -DisableNameChecking   ;
                <# Import-Module : The specified module 'tmp_3yci04ik.be1' was not loaded because no valid module file was found in any module directory.
                #>
                # could be latency issue, split them out 2-step
                $Global:ImportedPSS = Import-PSSession $Global:L13Sess -DisableNameChecking -AllowClobber ; 
                $Global:L13Mod = Import-Module $Global:ImportedPSS -Global -PassThru -DisableNameChecking ;
            } ;
            #write-verbose -verbose:$verbose "$((get-date).ToString('HH:mm:ss')):Import-PSSession w`n$(($pltISess|out-string).trim())" ;
            #write-verbose -verbose:$verbose "$((get-date).ToString('HH:mm:ss')):Import-Module w`n$(($pltIMod|out-string).trim())" ;
            # 7:34 AM 6/1/2020 for some reason the splats w below keep triggering Cannot validate argument on parameter 'Prefix', even when it's not in either splat!, revert to the hybrid commandline above
            #$Global:L13Mod = Import-Module @pltIMod -PSSession (Import-PSSession @pltISess) ;
            # add titlebar tag
            Add-PSTitleBar $sTitleBarTag ;
            $Global:L13IsDehydrated=$true ;
            write-verbose -verbose:$true "$(($Global:L13Sess | select ComputerName,Availability,State,ConfigurationName | format-table -auto |out-string).trim())" ;
            # drop returning an object; we're using a global variable now
        } else {
            write-host -foregroundcolor red "$((get-date).ToString('HH:mm:ss')):Unable to open PSSession w`n$(($LMSSplat|out-string).trim())" ;
        } ;
    } else {
        throw "Unable to ping:$($LyncAdminPool)! ABORTING!" ;
    } ;
}

#*------^ Connect-L13.ps1 ^------

#*------v Disconnect-L13.ps1 v------
Function Disconnect-L13 {
    <#
    .SYNOPSIS
    Disconnect-L13 - Clear Remote L13 Mgmt Shell connection
    .NOTES
    Author: Todd Kadrie
    Website:	http://toddomation.com
    Twitter     :	@tostka / http://twitter.com/tostka
    AddedCredit : Inspired by concept code by ExactMike Perficient, Global Knowl... (Partner)
    AddedWebsite:	https://social.technet.microsoft.com/Forums/msonline/en-US/f3292898-9b8c-482a-86f0-3caccc0bd3e5/exchange-powershell-monitoring-remote-sessions?forum=onlineservicesexchange
    Version     : 1.1.0
    CreatedDate : 2020-02-24
    FileName    : Connect-Ex2010()
    License     : MIT License
    Copyright   : (c) 2020 Todd Kadrie
    Github      : https://github.com/tostka
    Tags        : Powershell
    REVISIONS   :
    * 8:29 AM 6/1/2020 added if/then on the globals (suppress error when missing), added -or'd removal on generic name and computername, added verbose to outputs, to echo details when run verbose
    * 12:20 PM 5/27/2020 updated cbh ;  moved aliases: Disconnect-LMSR','dl13 win func
    * 8:01 AM 11/1/2017 added Remove-PSTitlebar 'LMS', and Disconnect-PssBroken to the bottom - to halt growth of unrepaired broken connections. Updated example to pretest for reqMods
    * 12:54 PM 12/9/2016 cleaned up, add pshelp
    * 12:09 PM 12/9/2016 implented and debugged as part of verb-L13 set
    * 2:37 PM 12/6/2016 ported to local LMSRemote
    * 2/10/14 posted version
    .DESCRIPTION
    Disconnect-L13 - Clear Remote L13 Mgmt Shell connection
    .INPUTS
    None. Does not accepted piped input.
    .OUTPUTS
    None. Returns no objects or output.
    .EXAMPLE
    $reqMods="Remove-PSTitlebar".split(";") ;
    $reqMods | % {if( !(test-path function:$_ ) ) {write-error "$((get-date).ToString("yyyyMMdd HH:mm:ss")):Missing $($_) function. EXITING." } } ;
    Disconnect-L13 ;
    .LINK
    #>
    [CmdletBinding()]
    [Alias('Disconnect-LMSR','dl13')]
    Param () ;
    $verbose = ($VerbosePreference -eq "Continue") ; 
    # remove sessions & modules tagged with the global varis
    if($Global:L13Mod){$Global:L13Mod | Remove-Module -Force -verbose:$verbose ; } ; 
    if($Global:L13Sess){$Global:L13Sess | Remove-PSSession -verbose:$verbose  ;} ; 
    # kill any other sessions with distinctive name or computername ; add verbose, to ensure they're echo'd that they were missed
    Get-PSSession |Where-Object {$_.name -eq 'Lync2013' -OR $_.ComputerName -eq $TORMeta['LyncAdminPool']} | Remove-PSSession -verbose:$verbose ;
    Remove-PSTitlebar 'LMS' ;
    Disconnect-PssBroken ;
}

#*------^ Disconnect-L13.ps1 ^------

#*------v enable-Lync.ps1 v------
function enable-Lync {
  <#
  .SYNOPSIS
  enable-Lync - obsolete Lync-enable function, subsuemed by enable-luser.ps1 by 7:37 AM 4/30/2015
  .NOTES
  Author: Todd Kadrie
  Website:	https://www.toddomation.com
  Twitter:	https://twitter.com/tostka

  REVISIONS   :
  * 11:42 AM 9/16/2021 string
  * 7:38 AM 4/30/2015 not sure of the origin date, but by 7:38 AM 4/30/2015 it's not the current enable-luser.ps1 version
  .PARAMETER  uid
  User SamAccountName or UPN
  .INPUTS
  None. Does not accepted piped input.
  .OUTPUTS
  None. Returns no objects or output.
  .EXAMPLE
  enable-Lync -uid LOGON -whatif
  .LINK
  #>
  PARAM(
  [parameter(Mandatory=$true)]
  [alias("u")]
  [string] $uid=$(Read-Host -prompt "Specfify UID to be Lync-enabled[SameAccountName]")
  ) ;

  $UCsettings=@{
    registrarpool=$TORMeta['o365_OPDomain'] ; 
    sipaddresstype="EmailAddress" ; 
    sipdomain=$TORMeta['o365_OPDomain'] ; 
  } ; 
  $user=(get-aduser $uid).userprincipalname.tostring() ;
  $user;
  if ($user) {
    $error.clear() ;
    enable-csuser -identity "$user" @Ucsettings -whatif;
    if($error.count -eq 0) {
          write-verbose -verbose:$true "Enabling $user...";
          enable-csuser -identity "$user" @Ucsettings #-whatif ;
          write-verbose -verbose:$true "$user Settings:";
          $luser = get-csuser $uid ;
          $luser| Select-Object DisplayName,LineURI,SamAccountName,WindowsEmailAddress,HomeServer| Format-List;
          write-verbose -verbose:$true "$user EffectivePolicy...:";
         $luser | Get-CsEffectivePolicy ;
         write-verbose -verbose:$true "$user PoolmachinesOrder...:";
          $luser | Get-CsUserPoolInfo | Select-Object -Expand PrimaryPoolMachinesInPreferredOrder ;

    } else {
      Throw "Whatif test failed,`n$error.`nRecheck your specification!. Exiting..." ;
    };
  } else {
    write-warning "$uid is not a vaild samacctname. Exiting..." ;
    exit
  } ;
}

#*------^ enable-Lync.ps1 ^------

#*------v Get-LyncServerInSite.ps1 v------
Function Get-LyncServerInSite {
  <#
  .SYNOPSIS
  Get-LyncServerInSite - function uses an ADSI DirectorySearcher to search the current Active Directory site for Lync servers. Returns all local servers
  .NOTES
  Author: Flaphead
  Website:	http://blog.flaphead.com/?s=get-lyncserver

  REVISIONS   :

  2/28/2012 - web version

  .INPUTS
  None. Does not accepted piped input.
  .OUTPUTS
  Returns a ConnectionURL to a random local Lync FrontEnd server (in the local AD site?).
  What it's doing is grabbing the AD group named 'RTCHSUniversalServices', which contains the DN to the local Lync FEs
  .EXAMPLE
  .\Get-LyncServerInSite
  Return a list of all local Exchange 2010 servers
  .EXAMPLE
  .\ping (Get-LyncServerInSite)[0].fqdn
  Ping the first server on the returned list
  .LINK
  #>
    # building our way toward grabbing the AD group named 'RTCHSUniversalServices', which contains the DN to the local Lync FEs, queried using ADSI LDAP qry
    $currentdom= [System.DirectoryServices.ActiveDirectory.Domain]::getcurrentdomain() ;
    $Forest= $currentdom.Forest.ToString() ;
    $ForestDomain= $Forest ;
    $Forest = $Forest.Replace(".", ",DC=") ;
    $Forest= "DC=" + $Forest ;
    $Dom= "LDAP://" ;
    $Dom+= $Forest ;
    $Root= New-Object DirectoryServices.DirectoryEntry $Dom ;
    $Filter= "(&(ObjectCategory=group)(name=*RTCHSUniversalServices*))" ;
    $selector= New-Object DirectoryServices.DirectorySearcher $Filter ;
    $selector.PageSize   = 1000 ;
    $selector.SearchRoot = $root ;
    $objs= $selector.findall() ;
    $tmpGroup= $objs | Select-Object Path -First 1 ;
    $Group= [ADSI]$tmpGroup.Path ;
    $GrpMembers= $Group.Member ;
    <# 1:52 PM 8/24/2015 at this point, the hosting dom is in the member DN's:
   $grpmembers
      CN=FENAME,OU=Lync 2013,OU=Prod,OU=Servers,OU=OUNAME,DC=SUBDOM,DC=SUB,DC=DOMAIN,DC=com
      CN=FENAME,OU=Lync 2013,OU=Prod,OU=Servers,OU=OUNAME,DC=SUBDOM,DC=SUB,DC=DOMAIN,DC=com
      CN=FENAME,OU=Lync 2013,OU=Prod,OU=Servers,OU=OUNAME,DC=SUBDOM,DC=SUB,DC=DOMAIN,DC=com
    #>
    $UserDom=$($env:userdnsdomain).tolower ;
    $LyncDom=($grpmembers | get-random).split(",")[5,6,7,8] -join "." -replace "DC=",""
    $grpCnt= $GrpMembers.Count ;
    $LyncServerList = @() ;
    ForEach($tmpMember in $GrpMembers){
      $tmpADSI = "LDAP://" + $tmpMember ;
      $tmpA    = [ADSI]$tmpADSI ;
      If($tmpA.objectClass -contains "computer"){$LyncServerList += $tmpA.Name} ;
    }  ;
    $LyncServerList = $LyncServerList | Sort-Object ;
    $tmpNumber = Get-Random -Minimum 0 -Maximum $LyncServerList.Count ;
    $LyncServer = $LyncServerList[$tmpNumber] ;
    if(test-connection $($LyncServer + "." + $ForestDomain) -Count 1 -quiet) {
        $LyncServer = $LyncServer + "." + $ForestDomain ;
    } elseif(test-connection $($LyncServer + "." + $LyncDom ) -Count 1 -quiet) {
        $LyncServer = $LyncServer + "." + $LyncDom ;
    } else {
        write-error "Failed to locate Domain for $LyncServer" ;
    }  ;
    
    write-output $LyncServer ;
}

#*------^ Get-LyncServerInSite.ps1 ^------

#*------v load-LMS.ps1 v------
function load-LMS {
  <#
  .SYNOPSIS
  Checks local machine for registred Lync LMS, and then loads found
  .NOTES
  Author: Todd Kadrie
  Website:	http://tinstoys.blogspot.com
  Twitter:	http://twitter.com/tostka
  REVISIONS   :
  vers: 10:43 AM 1/14/2015 fixed return & syntax expl to true/false
  vers: 10:20 AM 12/10/2014 moved commentblock into function
  vers: 11:40 AM 11/25/2014 adapted to Lync
  ers: 2:05 PM 7/19/2013 typo fix in 2013 code
  vers: 1:46 PM 7/19/2013
  .INPUTS
  None.
  .OUTPUTS
  Outputs Lync Revision
  .EXAMPLE
  $LMSLoaded = load-LMS ; Write-Debug "`$LMSLoaded: $LMSLoaded" ;
  #>
  # check registred v loaded ;
  $ModsReg=Get-Module -ListAvailable;
  $ModsLoad=Get-Module;
  if ($ModsReg | Where-Object {$_.Name -eq "Lync"}) {
    if (!($ModsLoad | Where-Object {$_.Name -eq "Lync"})) {
      Import-Module Lync -ErrorAction Stop ;return $TRUE;
    } else {
      return $TRUE;
    }
  } else {
    Write-Error {"$((get-date).ToString('HH:mm:ss')):($env:computername) does not have Lync Admin Tools installed!";};
    return $FALSE
  }
}

#*------^ load-LMS.ps1 ^------

#*------v Load-LMSPlug.ps1 v------
function Load-LMSPlug {
    <#
    .SYNOPSIS
    Checks local machine for registred Lync2013 LMS, and loads the component
    .NOTES
    Author: Todd Kadrie
    Website:	http://toddomation.com
    Twitter:	http://twitter.com/tostka

    REVISIONS   :
    vers: 10:41 AM 9/12/2018 ported load-LMSSnap -> Load-LMS
    vers: 9:39 AM 8/12/2015: retool into generic switched version to support both modules & snappins with same basic code
    vers: 9:25 AM 8/12/2015 building a stock LMS version (vs the fancier Load-LMSPlugLatest)
    vers: 10:43 AM 1/14/2015 fixed return & syntax expl to true/false
    vers: 10:20 AM 12/10/2014 moved commentblock into function
    vers: 11:40 AM 11/25/2014 adapted to Lync
    ers: 2:05 PM 7/19/2013 typo fix in 2013 code
    vers: 1:46 PM 7/19/2013
    .INPUTS
    None.
    .OUTPUTS
    Outputs $true if successful. $false if failed.
    .EXAMPLE
    $LMSLoaded = Load-LMSPlug ; Write-Debug "`$LMSLoaded: $LMSLoaded" ;
    Stock free-standing Exchange Mgmt Shell load
    .EXAMPLE
    $LMSLoaded = Load-LMSPlug ; Write-Debug "`$LMSLoaded: $LMSLoaded" ; get-exchangeserver | out-null ;
    Example utilizing a workaround for bug in LMS, where loading ADMS causes Powershell/ISE to crash if ADMS is loaded after LMS, before LMS has executed any commands
    .EXAMPLE
    TRY {
        if(($host.version.major -lt 3) -AND (get-service rtc* -ea SilentlyContinue)){
            write-verbose -verbose:$bshowVerbose  "$((get-date).ToString("yyyyMMdd HH:mm:ss")):Using Local Server Lync13 Snapin" ;
            $sName="Lync"; if (!(Get-Module| where{$_.Name -eq "Lync")) {Import-Module $sName -ea Stop} ;
        } else {
             write-verbose -verbose:$bshowVerbose  "$((get-date).ToString("yyyyMMdd HH:mm:ss")):Initiating RLMS connection" ;
            $reqMods="connect-L13;Disconnect-L13;".split(";") ;
            $reqMods | % {if( !(test-path function:$_ ) ) {write-error "$((get-date).ToString("yyyyMMdd HH:mm:ss")):Missing $($_) function. EXITING." } } ;
            Reconnect-L13 ;
        } ;
    }
    CATCH {
        $PassStatus="ERROR" ;
        $msg=": Error Details: $($_)" ;
        Write-Error "$(get-date -format "HH:mm:ss"): FAILURE!" ;
        Write-Error "$(get-date -format "HH:mm:ss"): Error in $($_.InvocationInfo.ScriptName)." ;
        Write-Error "$(get-date -format "HH:mm:ss"): -- Error information" ;
        Write-Error "$(get-date -format "HH:mm:ss"): Line Number: $($_.InvocationInfo.ScriptLineNumber)" ;
        Write-Error "$(get-date -format "HH:mm:ss"): Offset: $($_.InvocationInfo.OffsetInLine)" ;
        Write-Error "$(get-date -format "HH:mm:ss"): Command: $($_.InvocationInfo.MyCommand)" ;
        Write-Error "$(get-date -format "HH:mm:ss"): Line: $($_.InvocationInfo.Line)" ;
        #Write-Error "$(get-date -format "HH:mm:ss"): Error Details: $($_)" ;
        $msg=": Error Details: $($_)" ;
        Write-Error  "$(get-date -format "HH:mm:ss"): $($msg)" ;
        set-AdServerSettings -ViewEntireForest $false ;
        Exit ;
    } ;
    Example demo'ing check for local psv2 & ADtopo svc to defer
    #>

    # check registred v loaded ;
    # style of plugin we want to test/load
    $PlugStyle="Module"
    #"Snapin"; # for Exch EMS
    #"Module" ; # for Lync/ADMS
    #$PlugName="Microsoft.Exchange.Management.PowerShell.E2010" ;
    $PlugName="Lync" ;

    switch ($PlugStyle) {
        "Module" {
            # module-style (for LMS or ADMS
            $PlugsReg=Get-Module -ListAvailable;
            $PlugsLoad=Get-Module;
        }
        "Snapin"{
            $PlugsReg=Get-PSSnapin -Registered ;
            $PlugsLoad=Get-PSSnapin ;
        }
    } # switch-E

    TRY {
        if ($PlugsReg | Where-Object {$_.Name -eq $PlugName}) {
          if (!($PlugsLoad | Where-Object {$_.Name -eq $PlugName})) {
              #
              switch ($PlugStyle) {
                  "Module" {
                      #Import-Module $PlugName -ErrorAction Stop ;return $TRUE;
                      Import-Module $PlugName -ErrorAction Stop ;write-output $TRUE;
                  }
                  "Snapin"{
                      #Add-PSSnapin $PlugName -ErrorAction Stop ; return $TRUE
                      Add-PSSnapin $PlugName -ErrorAction Stop ; write-output $TRUE
                  }
              } # switch-E

          } else {
              # already loaded
              #return $TRUE;
              write-output $TRUE;
          } # if-E
        } else {
          Write-Error {"$(Get-TimeStamp):($env:computername) does not have $PlugName installed!";};
          #return $FALSE ;
          write-output $FALSE ;
        } # if-E ;
    } CATCH {
        Write-Error "$(Get-TimeStamp): FAILED TO LOAD $PLUGNAME" ;
        Write-Error "$(Get-TimeStamp): Error in $($_.InvocationInfo.ScriptName)." ;
        Write-Error "$(Get-TimeStamp): -- Error information" ;
        Write-Error "$(Get-TimeStamp): Line Number: $($_.InvocationInfo.ScriptLineNumber)" ;
        Write-Error "$(Get-TimeStamp): Offset: $($_.InvocationInfo.OffsetInLine)" ;
        Write-Error "$(Get-TimeStamp): Command: $($_.InvocationInfo.MyCommand)" ;
        Write-Error "$(Get-TimeStamp): Line: $($_.InvocationInfo.Line)" ;
        #Write-Error ("$(Get-TimeStamp): Error Details: $($_)") ;
        $msg=": Error Details: $($_)" ;
        Write-Error  "$(Get-TimeStamp): " + $msg; ;
    };   # try/catch-E

} #*------^END Function Load-LMSPlug ^------
if(!(test-path function:load-LMS -ea 0 )){set-alias -name 'load-LMS' -value 'Load-LMSPlug'}

#*------^ Load-LMSPlug.ps1 ^------

#*------v Reconnect-L13.ps1 v------
Function Reconnect-L13 {
    <#
    .SYNOPSIS
    Reconnect-L13 - Reconnect Remote Exch2010 Mgmt Shell connection
    .NOTES
Author: Todd Kadrie
    Website:	http://toddomation.com
    Twitter     :	@tostka / http://twitter.com/tostka
    AddedCredit : Inspired by concept code by ExactMike Perficient, Global Knowl... (Partner)
    AddedWebsite:	https://social.technet.microsoft.com/Forums/msonline/en-US/f3292898-9b8c-482a-86f0-3caccc0bd3e5/exchange-powershell-monitoring-remote-sessions?forum=onlineservicesexchange
    Version     : 1.1.0
    CreatedDate : 2020-02-24
    FileName    : Connect-Ex2010()
    License     : MIT License
    Copyright   : (c) 2020 Todd Kadrie
    Github      : https://github.com/tostka
    Tags        : Powershell,Lync,Lync2013
    REVISIONS   :
    * 12:20 PM 5/27/2020 moved aliases: rl13 win func
    * 10:14 AM 11/20/2019 rl13: added cred support
    * 8:09 AM 11/1/2017 updated example to pretest for reqMods
    * 1:26 PM 12/9/2016 split no-session and reopen code, to suppress notfound errors
    * 12:54 PM 12/9/2016 cleaned up, add pshelp
    * 12:09 PM 12/9/2016 implented and debugged as part of verb-L13 set
    * 2:37 PM 12/6/2016 ported to local LMSRemote
    * 2/10/14 posted version
    .DESCRIPTION
    Reconnect-L13 - Reconnect Remote Exch2010 Mgmt Shell connection
    .PARAMETER  Credential
    Credential object
    .INPUTS
    None. Does not accepted piped input.
    .OUTPUTS
    None. Returns no objects or output.
    .EXAMPLE
    $reqMods="connect-L13;Disconnect-L13;".split(";") ;
    $reqMods | % {if( !(test-path function:$_ ) ) {write-error "$((get-date).ToString("yyyyMMdd HH:mm:ss")):Missing $($_) function. EXITING." } } ;
    Reconnect-L13 ;
    .LINK
    #>

    Param(
        [Parameter(HelpMessage='Credential object')][System.Management.Automation.PSCredential]$Credential
    )  ;

    # 10:55 AM 12/9/2016 issue here is that disconnect-L13 leaves $L13Sess populated, but State closed and Availability None, wich doesn't trigger the above disc/reconn
    # what we want is to validate the sess is State 'Opened' & Availability 'Available'
    #if($L13Sess.state -ne 'Opened' -OR $L13Sess.Availability -ne 'Available' -OR !$L13Sess) { Disconnect-L13 ;Start-Sleep -s 3;Connect-L13 ;} ;
    # 1:26 PM 12/9/2016: spread it out, getting not-found errors, don't run removals unless it's not there
    if(!$L13Sess){
        if(!$Credential){
            Disconnect-L13 ;Start-Sleep -S 3;
            Connect-L13
        } else {
            Disconnect-L13 -Credential:$($Credential) ; Disconnect-PssBroken ;Start-Sleep -Seconds 3;
            Connect-L13 -Credential:$($Credential) ;
        } ;
    }
    elseif($L13Sess.state -ne 'Opened' -OR $L13Sess.Availability -ne 'Available' ) {
        Disconnect-L13 ;Start-Sleep -S 3;Connect-L13 ;
        if(!$Credential){
            Disconnect-L13 ;Start-Sleep -S 3;
            Connect-L13
        } else {
            Disconnect-L13 -Credential:$($Credential) ; Disconnect-PssBroken ;Start-Sleep -Seconds 3;
            Connect-L13 -Credential:$($Credential) ;
        } ;
    } ;
}

#*------^ Reconnect-L13.ps1 ^------

#*======^ END FUNCTIONS ^======

Export-ModuleMember -Function Add-LMSRemote,check-L13DrainStop,Connect-L13,Disconnect-L13,enable-Lync,Get-LyncServerInSite,load-LMS,Load-LMSPlug,Reconnect-L13 -Alias *


# SIG # Begin signature block
# MIIELgYJKoZIhvcNAQcCoIIEHzCCBBsCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUrnIdKAUHxDCVfzvkF3CPUf34
# K8GgggI4MIICNDCCAaGgAwIBAgIQWsnStFUuSIVNR8uhNSlE6TAJBgUrDgMCHQUA
# MCwxKjAoBgNVBAMTIVBvd2VyU2hlbGwgTG9jYWwgQ2VydGlmaWNhdGUgUm9vdDAe
# Fw0xNDEyMjkxNzA3MzNaFw0zOTEyMzEyMzU5NTlaMBUxEzARBgNVBAMTClRvZGRT
# ZWxmSUkwgZ8wDQYJKoZIhvcNAQEBBQADgY0AMIGJAoGBALqRVt7uNweTkZZ+16QG
# a+NnFYNRPPa8Bnm071ohGe27jNWKPVUbDfd0OY2sqCBQCEFVb5pqcIECRRnlhN5H
# +EEJmm2x9AU0uS7IHxHeUo8fkW4vm49adkat5gAoOZOwbuNntBOAJy9LCyNs4F1I
# KKphP3TyDwe8XqsEVwB2m9FPAgMBAAGjdjB0MBMGA1UdJQQMMAoGCCsGAQUFBwMD
# MF0GA1UdAQRWMFSAEL95r+Rh65kgqZl+tgchMuKhLjAsMSowKAYDVQQDEyFQb3dl
# clNoZWxsIExvY2FsIENlcnRpZmljYXRlIFJvb3SCEGwiXbeZNci7Rxiz/r43gVsw
# CQYFKw4DAh0FAAOBgQB6ECSnXHUs7/bCr6Z556K6IDJNWsccjcV89fHA/zKMX0w0
# 6NefCtxas/QHUA9mS87HRHLzKjFqweA3BnQ5lr5mPDlho8U90Nvtpj58G9I5SPUg
# CspNr5jEHOL5EdJFBIv3zI2jQ8TPbFGC0Cz72+4oYzSxWpftNX41MmEsZkMaADGC
# AWAwggFcAgEBMEAwLDEqMCgGA1UEAxMhUG93ZXJTaGVsbCBMb2NhbCBDZXJ0aWZp
# Y2F0ZSBSb290AhBaydK0VS5IhU1Hy6E1KUTpMAkGBSsOAwIaBQCgeDAYBgorBgEE
# AYI3AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwG
# CisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBTVnn6y
# 7Dld0trEGYRRX4VqN5uG0jANBgkqhkiG9w0BAQEFAASBgGryp4lkPMXnb2GoAG+K
# 01UBuCVf+L2DLes/fbpaG8X8r01354qZ+DBK/j7pim+e/eqxPa81hGbkEUeKN+V4
# w8Zk3qGk2MmQ4sAWTziP0KBsEha7SWIe7hVSrBDvcYDUjj3WQD2ot5GSnQ+YGzMt
# z5CSJYHoA0mr+TlbBZXV2tyo
# SIG # End signature block
