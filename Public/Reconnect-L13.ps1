#*------v Function Reconnect-L13 v------
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
} ;
#*------^ END Function Reconnect-L13 ^------ ;

