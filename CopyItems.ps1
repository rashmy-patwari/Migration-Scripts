$parameters = @(
    @{ Name = "sourceNode"; Title = "Source Item Path"; Tooltip = "Enter the source item to start"; Editor = "droptree"; DefaultValue = "/sitecore/content/Home" },
    @{ Name = "destinationNode"; Title = "Destination Item Path"; Tooltip = "Enter the destination item"; Editor = "droptree"; DefaultValue = "/sitecore/content/Home" }
)

# Show Read-Variable dialog
$result = Read-Variable -Parameters $parameters -Description "Select options to copy roots" -Title "Fetch Sitecore Item Details" -Width 450 -Height 250 -OkButtonName "Proceed" -CancelButtonName "Cancel"

if ($result -ne "ok") {
    # User cancelled the dialog, exit the script
    return
}

    # Initialize an array to store the list of copied items
    $copiedItems = @()
    
     # Copy the source item itself
    Copy-Item -Path $sourceNode.ItemPath -Destination $destinationNode.ItemPath -Recurse
    $copiedItems += $destinationNode.FullPath

<#     # Copy all children from the source item to the destination item
    Get-ChildItem -Path $sourceItem.FullPath|
        ForEach-Object {
            Copy-Item -Path $_.ItemPath -Destination $destinationItem.ItemPath -Recurse
            $childDestPath = $_.FullPath -replace $sourceItem.FullPath, $destinationItem.FullPath
            $copiedItems += $childDestPath
        }

 #>
    Write-Host "List of copied items:"

    $copiedItems | ForEach-Object { Write-Host $_ }

