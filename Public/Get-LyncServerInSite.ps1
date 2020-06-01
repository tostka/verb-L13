  #*------v Function Get-LyncServerInSite v------
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
} #*------^ END Function Get-LyncServerInSite ^------ ;