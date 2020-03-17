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
    $LyncConnectionURI  = "https://$($LyncFE)/OcsPowershell"  ;
    If (Test-Connection $LyncFE -count 1) {
        write-verbose -verbose:$true  "$((get-date).ToString("yyyyMMdd HH:mm:ss")):Adding LMS (connecting to $($LyncFE))..." ;
        # splat to open a session - # stock 'PSLanguageMode=Restricted' powershell IIS Webpool

        $sesOpts = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck ;
        $LMSsplat=@{ConnectionURI=$LyncConnectionURI; name='Lync2013';SessionOption=$sesOpts};

        # 12/8/2016 add  credential support
        if($Credential){
            $LMSsplat.Add("Credential",$Credential) ;
        } elseif($global:SIDcred) {
            $LMSsplat.Add("Credential",$global:SIDcred);
        } else {
            Get-AdminCred ;
        } ;  ;
        # -Authentication Basic only if specif needed: for Ex configured to connect via IP vs hostname)
        if($Global:L13Sess = New-PSSession @LMSSplat){
            write-verbose -verbose:$true  "$((get-date).ToString('HH:mm:ss')):Importing Lync 2013 Module" ;
            if($CommandPrefix){
                write-verbose -verbose:$true  "$((get-date).ToString("HH:mm:ss")):Note: Prefixing this Modules Cmdlets as [verb]-$($CommandPrefix)[noun]" ;
                $Global:L13Mod = Import-Module (Import-PSSession $Global:L13Sess -DisableNameChecking -Prefix $CommandPrefix -AllowClobber) -Global -Prefix $CommandPrefix -PassThru -DisableNameChecking   ;
            } else {
                $Global:L13Mod = Import-Module (Import-PSSession $Global:L13Sess -DisableNameChecking -AllowClobber) -Global -PassThru -DisableNameChecking   ;
            } ;
            # add titlebar tag
            Add-PSTitleBar $sTitleBarTag ;
            $Global:L13IsDehydrated=$true ;
            write-verbose -verbose:$true "$(($Global:L13Sess | select ComputerName,Availability,State,ConfigurationName | format-table -auto |out-string).trim())" ;
            # drop returning an object; we're using a global variable now
        } else {
            write-host -foregroundcolor red "$((get-date).ToString('HH:mm:ss')):Unable to open PSSession w`n$(($LMSSplat|out-string).trim())" ;
        } ;
    } else {
        throw "Unable to ping:$($LyncFE)! ABORTING!" ;
    } ;
} ; #*------^ END Function Connect-L13 ^------
if(!(get-alias cl13 -ea 0)){ set-alias -name cl13 -value Connect-L13 } ; 
#*------^ Connect-L13.ps1 ^------
