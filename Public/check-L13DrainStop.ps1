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
} ; 
#*------^ check-L13DrainStop.ps1 ^------
