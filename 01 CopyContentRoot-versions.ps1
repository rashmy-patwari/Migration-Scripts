# filepath: /c:/Projects/Avanade XM Migration/Scripts/01 CopyContentRoot-versions.ps1
$global:sourceItemPath = ""
$global:destinationItemPath = ""
$global:createSrcItem = $true

New-UsingBlock (New-Object Sitecore.Data.BulkUpdateContext) {

    $parameters = @(
        @{ Name = "sourceNode"; Title = "Source Item Path"; Editor = "droptree"; DefaultValue = "/sitecore/content/Home" },
        @{ Name = "destinationNode"; Title = "Destination Item Path"; Editor = "droptree"; DefaultValue = "/sitecore/content/Home" }
    )

    $result = Read-Variable -Parameters $parameters -Description "Select options to copy roots" -Title "Copy Roots" -Width 450 -Height 250 -OkButtonName "Proceed" -CancelButtonName "Cancel"

    if ($result -ne "ok") {
        return
    }
    else {
        $global:sourceItemPath      = $sourceNode.ID
        $global:destinationItemPath = $destinationNode.ID
    }

    $itemsCreated = New-Object System.Collections.ArrayList

    if($createSrcItem) {
        $copied = Copy-Item -Path $global:sourceItemPath -Destination $global:destinationItemPath -Recurse -PassThru -Force

        if ($copied) {
            $copied | ForEach-Object { $itemsCreated.Add($_) | Out-Null }
        }
    }
    else {
        $children = Get-ChildItem -Path "master:" -ID $global:sourceItemPath
        foreach($child in $children) {
            $copiedChildren = $child | Copy-Item -Destination $global:destinationItemPath -Recurse -PassThru -Force

            if ($copiedChildren) {
                $copiedChildren | ForEach-Object { $itemsCreated.Add($_) | Out-Null }
            }
        }
    }
    Write-Host "Created items:"
    $itemsCreated | ForEach-Object { Write-Host $_.ItemPath }
}
