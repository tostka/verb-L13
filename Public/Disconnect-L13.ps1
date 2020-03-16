#*------v Function Disconnect-L13 v------
Function Disconnect-L13 {
    <#
    .SYNOPSIS
    Disconnect-L13 - Clear Remote L13 Mgmt Shell connection
    .NOTES
    Author: Todd Kadrie
    Website:	http://toddomation.com
    Twitter:	http://twitter.com/tostka
    Based on idea by: ExactMike Perficient, Global Knowl... (Partner)
    Website:	https://social.technet.microsoft.com/Forums/msonline/en-US/f3292898-9b8c-482a-86f0-3caccc0bd3e5/exchange-powershell-monitoring-remote-sessions?forum=onlineservicesexchange
    REVISIONS   :
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
    $Global:L13Mod | Remove-Module -Force ;
    $Global:L13Sess | Remove-PSSession ;
    # 7:56 AM 11/1/2017 remove titlebar tag
    Remove-PSTitlebar 'LMS' ;
    # kill any other sessions using my distinctive name; add verbose, to ensure they're echo'd that they were missed
    Get-PSSession |Where-Object {$_.name -eq 'Lync2013'} | Remove-PSSession -verbose ;
    Disconnect-PssBroken ;
} ; #*------^ END Function Disconnect-L13 ^------
# 11:55 AM 5/6/2019 alias to purge script from tsksid-incl-ServerApp.ps1
if(!(get-alias Disconnect-LMSR -ea 0)){ set-alias -name Disconnect-LMSR -value Disconnect-L13 } ;
# 12:14 PM 5/6/2019
if(!(get-alias dl13 -ea 0)){ set-alias -name dl13 -value Disconnect-L13 } ;