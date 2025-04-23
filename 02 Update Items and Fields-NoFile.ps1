# Global variables for source and destination nodes
$global:sourceNodePath = ""
$global:destinationNodePath = ""
$global:destinationMediaLibraryPath = ""
$global:updatedFields = 0;

function Update-RenderingsForLayoutType {
    param (
        [Parameter(Mandatory = $true)][Sitecore.Data.Items.Item]$item,
        [Parameter(Mandatory = $true)][bool]$isFinalLayout
    )

    if ($isFinalLayout) {
        $renderingInstances = Get-Rendering -Item $item -FinalLayout
    }
    else {
        $renderingInstances = Get-Rendering -Item $item
    }

    try {

        $item.Editing.BeginEdit()
        foreach ($renderingInstance in $renderingInstances) {
        ## Update datasource 

        if ($renderingInstance.Datasource -and 
            -not ($renderingInstance.Datasource -match "^local:/") -and
            -not ($renderingInstance.Datasource -match "^query:") -and
            ($renderingInstance.Datasource -match "^/sitecore" -or $renderingInstance.Datasource -match "^[{].*[}]$")) {

            Write-Host "RenderingInstance: $($renderingInstance.Name) Datasource: $($renderingInstance.Datasource)"

            $renderingDatasource = $null

            if($renderingInstance.Datasource -match "^\{.*\}$") {
                $renderingDatasource = Get-Item -ID $renderingInstance.Datasource -Path "master:/" -ErrorAction SilentlyContinue
            }
            else{
                $renderingDatasource = Get-Item -Path $renderingInstance.Datasource -ErrorAction SilentlyContinue
            }


            $newDatasourcePath = ""

            if ($renderingDatasource -and $renderingDatasource.FullPath -match "sitecore/content/") {
                $newDatasourcePath  = $renderingDatasource.Paths.FullPath -replace $global:sourceNodePath, $global:destinationNodePath
                write-host "New Datasource Path: $newDatasourcePath"
            }

            if($newDatasourcePath){

                 $newDatasource = Get-Item $newDatasourcePath -ErrorAction SilentlyContinue

                if ($newDatasource) {
                    Write-Host "Setting new datasource to item ID: $($newDatasource.ID)"
                    # Update rendering's datasource to the new item’s ID
                    $renderingInstance.Datasource = $newDatasource.ID.ToString()
                    Set-Rendering -Item $item -Instance $renderingInstance -FinalLayout:$isFinalLayout
                    Write-Host "Updated Datasource to $($renderingInstance.DataSource)"
                }
                else {
                    Write-Host "No changes to $($renderingInstance.Name) the Datasource:" $newDatasourcePath
                }
            }
        }
    }
}
catch {
    Write-Host "Error updating renderings: $($_.Exception.Message)"
}
finally {
    $item.Editing.EndEdit()
}
}

function Remap-DestinationPath {
    param(
        [string]$sourcePath
    )
    return $sourcePath -replace $global:sourceNodePath, $global:destinationNodePath
}

function Remap-LinkedItemId {
    param (
        [string]$ItemId
    )
    if ([Sitecore.Data.ID]::IsID($ItemId)) {
        try {
            $linkedItem = Get-Item -Path "master:" -ID $ItemId -ErrorAction SilentlyContinue
            if ($linkedItem) {
                $newLinkedItemPath = Remap-DestinationPath -sourcePath $linkedItem.Paths.FullPath
                Write-Host "Remap-LinkedItemId : New linked item path: $newLinkedItemPath"
                $newLinkedItem = Get-Item -Path "master:$newLinkedItemPath" -ErrorAction SilentlyContinue
                if ($newLinkedItem) {
                    return $newLinkedItem.ID.ToString()
                }
            }
        }
        catch {
            Write-Host "Warning: Unable to find or remap linked item with ID $ItemId"
        }
    }
    else {
        Write-Host "Invalid GUID format or broken link for ID: $ItemId"
    }
    return $ItemId
}

function Update-LinkFields {
    param (
        [Parameter(Mandatory = $true)][string]$SourceContentItemPath
    )

    $item = Get-Item -Path "master:$SourceContentItemPath" -ErrorAction SilentlyContinue

    if ($item) {
        $newContentItemPath = Remap-DestinationPath -sourcePath $item.Paths.FullPath
        Write-Host "Update-LinkFields : New content Item: $newContentItemPath"

        $ContentItem = Get-Item -Path "master:$newContentItemPath" -ErrorAction SilentlyContinue

        if ($ContentItem) {
            foreach ($field in $ContentItem.Fields) {
                if ($field -and ![string]::IsNullOrWhiteSpace($field.Value) -and 
                    !$field.InnerItem.Paths.FullPath.StartsWith("/sitecore/templates/system", 'CurrentCultureIgnoreCase')) {

                    if ($field.Type -eq "General Link") {
                        Write-Host "Processing General Link field: $($field.Name)"
                        [Sitecore.Data.Fields.LinkField]$linkField = $ContentItem.Fields[$field.Name]
                        if ($linkField.LinkType -eq "internal" -and [Sitecore.Data.ID]::IsID($linkField.TargetID)) {
                            $newLinkedItemId = Remap-LinkedItemId -itemId $linkField.TargetID
                            if ([Sitecore.Data.ID]::IsID($newLinkedItemId)) {
                                $ContentItem.Editing.BeginEdit()
                                $linkField.TargetID = $newLinkedItemId
                                $ContentItem.Editing.EndEdit() > $null
                                $global:updatedFields++
                            }
                        }
                    }
                    elseif ($field.Type -in @("Droplink", "Droptree")) {
                        if ([Sitecore.Data.ID]::IsID($field.Value)) {
                            $newLinkedItemId = Remap-LinkedItemId -itemId $field.Value
                            $ContentItem.Editing.BeginEdit()
                            $field.Value = $newLinkedItemId
                            $ContentItem.Editing.EndEdit()
                            $global:updatedFields++
                        }
                    }
                    elseif ($field.Type -in @("Multilist", "Treelist")) {
                        $ids = $field.Value -split '\|'
                        $newIds = @()
                        foreach ($id in $ids) {
                            if ([Sitecore.Data.ID]::IsID($id)) {
                                $newIds += Remap-LinkedItemId -itemId $id
                            }
                        }
                        if ($newIds) {
                            $ContentItem.Editing.BeginEdit()
                            $field.Value = ($newIds -join '|')
                            $ContentItem.Editing.EndEdit()
                            $global:updatedFields++
                        }
                    }
                    elseif ($field.Type -eq "Image") {
                        [Sitecore.Data.Fields.ImageField] $imageField = $field
                        $mediaItem = Get-Item -Path "master:" -ID $imageField.MediaID
                        if ($mediaItem) {
                            $newMediaItemId = Find-NewImageId -Name $mediaItem.Name
                            if ([Sitecore.Data.ID]::IsID($newMediaItemId.ItemId)) {
                                $ContentItem.Editing.BeginEdit()
                                $imageField.MediaID = $newMediaItemId.ItemId
                                $ContentItem.Editing.EndEdit() > $null
                                $global:updatedFields++
                            }
                        }
                    }
                }
            }

            # Update Insert Options
            $insertOptionsField = $ContentItem.Fields["__Masters"]
            if ($insertOptionsField -and $insertOptionsField.HasValue) {
                $ids = $insertOptionsField.Value -split '\|'
                $newIds = @()
                foreach ($id in $ids) {
                    $newIds += Remap-LinkedItemId -itemId $id
                }
                if ($newIds) {
                    $ContentItem.Editing.BeginEdit()
                    $insertOptionsField.Value = $newIds -join "|"
                    $ContentItem.Editing.EndEdit()
                }
            }
        }
        else {
            Write-Host "Could not find content item at path: $newContentItemPath"
        }
    }
}

Function Find-NewImageId {
    param(
        [string]$Name
    )
    $criteria = @(
        @{Filter = "Contains"; Field = "_fullpath"; Value = "$global:destinationNodePath" }
        @{Filter = "Equals"; Field = "_name"; Value = "$Name" }
    )
    $props = @{
        Index    = "sitecore_master_index"
        Criteria = $criteria
    }
    return Find-Item @props | Select-Object -Property ItemId -First 1
}

################################################
# Main Code Block: read source node's descendants
################################################

New-UsingBlock (New-Object Sitecore.Data.BulkUpdateContext) {
    Set-Location -Path "master:/"

    $parameters = @(
        @{ Name = "sourceNode"; Title = "Source Website Node"; Tooltip = "Enter the source website node"; Editor = "droptree"; DefaultValue = "/sitecore/content/contosomvc" },
        @{ Name = "destinationNode"; Title = "Destination Website Node"; Tooltip = "Enter the destination website node"; Editor = "droptree"; DefaultValue = "/sitecore/content/DemoHeadlesstenant/sxawebsite" },
        @{ Name = "sourceMediaLibrary"; Title = "Source Media Library Folder"; Source = "Datasource=/sitecore/media library/"; Tooltip = "Enter the source media library folder"; Editor = "droptree"; DefaultValue = "/sitecore/media library" },
        @{ Name = "destinationMediaLibrary"; Title = "Destination Media Library Folder"; Source = "Datasource=/sitecore/media library/"; Tooltip = "Enter the destination media library folder"; Editor = "droptree"; DefaultValue = "/sitecore/media library" },
        @{ Name = "newHomepage"; Title = "Start Item Website Home Page"; Tooltip = "Enter the website's homepage"; Editor = "droptree"; DefaultValue = "/sitecore/content/DemoHeadlesstenant/sxawebsite/Homepage" }
    )

    $result = Read-Variable -Parameters $parameters -Description "Select source, destination node" -Title "Configuration" -Width 500 -Height 500 -OkButtonName "Proceed" -CancelButtonName "Cancel" -ShowHints

    if ($result -eq "cancel") {
        Write-Host "Please select source, destination node"
        Exit
    }
    else {
        $global:sourceNodePath = $sourceNode.Parent.Name + "/" + $sourceNode.Name
        $global:destinationNodePath = $destinationNode.Parent.Name + "/" + $destinationNode.Name
        $global:destinationMediaLibraryPath = $destinationMediaLibrary.FullPath
    }

    # Gather all descendants under the source node (including the node itself if you wish)
    # To exclude the node itself, remove -WithParent
    $allDescendants = Get-ChildItem -Path $destinationNode.FullPath -Recurse

    foreach ($descendant in $allDescendants) {
        Write-Host "Processing descendant: $($descendant.FullPath)"

        # Update Final Layout Renderings
        #Update-RenderingsForLayoutType -item $descendant -isFinalLayout $true

        # Update Shared Layout Renderings
        #Update-RenderingsForLayoutType -item $descendant -isFinalLayout $false

        Update-LinkFields -SourceContentItemPath $descendant.FullPath
    }

    Write-Host "Number of fields updated: $global:updatedFields"
}
