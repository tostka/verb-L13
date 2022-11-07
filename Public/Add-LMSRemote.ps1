#*------v Function Add-LMSRemote v------
Function Add-LMSRemote {
    <#
    .SYNOPSIS
    Add-LMSRemote - Remote Lync Mgmt Shell
    .NOTES
    Hybrid of dsolodow's & my remote code
    Author: Todd Kadrie
    Website:	https://www.toddomation.com
    Twitter:	https://twitter.com/tostka
    REVISIONS   :
    # 10:47 AM 9/12/2018 grabbed from tsksid-incl-ServerApp.ps1
    # 1:19 PM 4/6/2016 get-admincred now outputs to $global:SIDcred, updated splat
    # 1:16 PM 8/19/2015
    .LINK
    https://github.com/dsolodow/IndyPoSH/blob/master/Profile.ps1
    #>
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
    If ( (!(Get-PSSession -Name 'Lync2013' -ErrorAction SilentlyContinue)) -AND (Test-Connection $LyncFE -count 1)) {
        #1:38 PM 8/19/2015 only prompt if it's not running SID
        $sesOpts = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck ;
        $LMSsplat=@{ConnectionURI=$LyncConnectionURI; name='Lync2013';SessionOption=$sesOpts};
        Get-AdminCred ;
        $LMSsplat.Add("Credential",$global:SIDcred);
        Add-PSTitleBar 'LMS' ;
        # set color scheme to White text on Black
        $HOST.UI.RawUI.BackgroundColor = "Black" ; $HOST.UI.RawUI.ForegroundColor = "White" ;
        write-host "Adding LMS (connecting to $($LyncConnectionURI))..."
        $Session = New-PSSession @LMSSplat
        Import-PSSession $Session ;
        $Session | Select-Object ComputerName,Availability | format-table -auto |out-default;
    } ;
}#*------^ END Function Add-LMSRemote ^------ ;
