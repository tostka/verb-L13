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
        switch ($credDom){
            "$($TORMeta['legacyDomain'])" {
                $LyncAdminPool = $TORMeta['LyncAdminPool'] ; 
            }
            "$($TOLMeta['legacyDomain'])" {
                $LyncAdminPool = $TOLMeta['LyncAdminPool'] ; 
            }
            "$CMWMeta['legacyDomain'])" {
                $LyncAdminPool = $CMWMeta['LyncAdminPool'] ; 
            }
            default {
                $LyncAdminPool = 'dynamic' ; 
            } ;
        } ; 
    } elseif ($Credential.username.contains('@')){
        $credDom = ($Credential.username.split("@"))[1] ;
        switch ($credDom){
            "$($TORMeta['o365_OPDomain'])" {
                $LyncAdminPool = $TORMeta['LyncAdminPool'] ;  ; 
            }
            "$($TOLMeta['o365_OPDomain'])" {
                $LyncAdminPool = $TOLMeta['LyncAdminPool'] ; 
            }
            "$CMWMeta['o365_OPDomain'])" {
                $LyncAdminPool = $CMWMeta['LyncAdminPool'] ; 
            }
            default {
                $LyncAdminPool = 'dynamic' ; 
            } ;
        } ; 
    } else {
        write-warning "$((get-date).ToString('HH:mm:ss')):UNRECOGNIZED CREDENTIAL!:$($Credential.Username)`nUNABLE TO RESOLVE DEFAULT LYNCADMINPOOL FOR CONNECTION!" ;
    }  ;  
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