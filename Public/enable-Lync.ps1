#*------v Function enable-Lync v------
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
} #*------^ END Function enable-Lync ^------
