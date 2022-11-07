#*-----v Function load-LMS v-----
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
} #*-----^END Function load-LMS ^-----
