#*------v Function Connect-L13 v------
Function Connect-L13 {
    <#
    .SYNOPSIS
    Connect-L13 - Setup Remote Exch2010 Mgmt Shell connection
    .NOTES
    Author: Todd Kadrie
    Website:	http://toddomation.com
    Twitter:	http://twitter.com/tostka
    Based on idea by: ExactMike Perficient, Global Knowl... (Partner)
    Website:
    REVISIONS   :
    * # 7:54 AM 11/1/2017 add titlebar tag & updated example to test for pres of Add-PSTitleBar
    * 12:09 PM 12/9/2016 implented and debugged as part of verb-L13 set
    * 2:37 PM 12/6/2016 ported to local LMSRemote
    * 2/10/14 posted version
    $Credential can leverage a global: $Credential = $global:SIDcred
    .DESCRIPTION
    Connect-L13 - Setup Remote Exch2010 Mgmt Shell connection
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

    Param(
        [Parameter(HelpMessage='Credential object')][System.Management.Automation.PSCredential]$Credential
    )  ;

    # set the below to OP to prefix mounted commands like: get-OLMailbox == local get-Mailbox command
    # set to $null/blank to not perform prefixing
    $CommandPrefix = $null ;
    # "OP"
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
            Add-PSTitleBar 'LMS' ;
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
# 12:14 PM 5/6/2019
if(!(get-alias cl13 -ea 0)){ set-alias -name cl13 -value Connect-L13 } ;