#*------v Function Load-LMSPlug v------
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
if(!(test-path function:load-LMS -ea 0 )){set-alias -name 'load-LMS' -value 'Load-LMSPlug'} ;
