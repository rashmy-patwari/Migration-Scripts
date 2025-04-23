function Copy-SitecoreItemRecursively {
    param(
        [Parameter(Mandatory=$true)]
        [Sitecore.Data.Items.Item]$sourceItem,
        [Parameter(Mandatory=$true)]
        [Sitecore.Data.Items.Item]$destItem,
        [bool]$CreateSrcItem = $true
    )

    Write-Host $CreateSrcItem
    if (-not $sourceItem) {
        Write-Host "Source item not found: $sourceItem.FullPath"
        return
    }

    if (-not $destItem) {
        Write-Host "Destination item not found: $destItem.FullPath"
        return
    }

    # This array will collect all newly created items
    $itemsCreated = New-Object System.Collections.ArrayList



    function Copy-OneItem {
        param(
            [Sitecore.Data.Items.Item]$src,
            [Sitecore.Data.Items.Item]$destParent,
            [System.Collections.ArrayList]$itemsCreated
        )

        $newItem = New-Item -Path $destParent.ItemPath -Name $src.Name -ItemType $src.TemplateID
        if ($newItem) {
            $itemsCreated.Add($newItem) | Out-Null

            $newItem.Editing.BeginEdit()
            foreach ($field in $src.Fields) {
                $newItem[$field.Name] = $field.Value
            }
            $newItem.Editing.EndEdit()

            foreach ($childItem in $src.Children) {
                Copy-OneItem -src $childItem -destParent $newItem -itemsCreated $itemsCreated
            }
        }
    }

    if($CreateSrcItem){
        Copy-OneItem -src $sourceItem -destParent $destItem -itemsCreated $itemsCreated
    }
    else{
        foreach ($childItem in $sourceItem.Children) {
            Copy-OneItem -src $childItem -destParent $destItem -itemsCreated $itemsCreated
        }
    }

    Write-Host "Created items:"
    $itemsCreated | ForEach-Object { Write-Host $_.ItemPath }

    # Return the array for further use if desired
    return $itemsCreated
}

$parameters = @(
    @{ Name = "sourceItem"; Title = "Source Item Path"; Tooltip = "Enter the source item to start"; Editor = "droptree"; DefaultValue = "/sitecore/content/Home" },
    @{ Name = "destinationItem"; Title = "Destination Item Path"; Tooltip = "Enter the destination item"; Editor = "droptree"; DefaultValue = "/sitecore/content/Home" },
    @{ Name = "createRootItem"; Title = "Create Root Item"; Tooltip = "Create the Root Item?"; Editor = "checkbox"; DefaultValue = $true }
)

# Show Read-Variable dialog
$result = Read-Variable -Parameters $parameters -Description "Select options to copy roots" -Title "Fetch Sitecore Item Details" -Width 450 -Height 250 -OkButtonName "Proceed" -CancelButtonName "Cancel"

if ($result -ne "ok") {
    # User cancelled the dialog, exit the script
    return
}

<# Checkbox not reliable, so just directly set CreateSrcItem value.
E.g. For Home set it to true so that it does not dump everything without a Home Page, For Most others, it's false #>

$createSrcItem = [bool]$createRootItem
#Copy-SitecoreItemRecursively -sourceItem $sourceItem -destItem $destinationItem -CreateSrcItem $false 
Copy-SitecoreItemRecursively -sourceItem $sourceItem -destItem $destinationItem -CreateSrcItem $createSrcItem
