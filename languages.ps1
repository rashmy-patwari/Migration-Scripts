$itemPath = "{E206A31F-6D7B-4900-952E-6E101336DA18}"

Get-ChildItem -Path $itemPath -Language * -Version * -Recurse | ForEach-Object {
        if($_.Language -eq ""){
           Write-Host "Deleting item: $($_.FullPath) Language: $($_.Language)"
           Remove-ItemVersion $_
    }
}

Write-Host "Done"
