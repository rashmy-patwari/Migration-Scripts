# Global variables for source and destination nodes
# Global variables for source and destination nodes
$global:sourceNodePath = ""
$global:destinationNodePath = ""
$global:destinationMediaLibraryPath = ""
$global:updatedFields = 0;

# Function to replace the path segment
function Remap-DestinationPath {
    param(
        [string]$sourcePath
    )
    return $sourcePath -replace $global:sourceNodePath, $global:destinationNodePath
}

function Update-LinkFields {
    param (
        [Parameter(Mandatory = $true)][string]$SourceContentItemPath
    )

    $item = Get-Item -Path "master:$SourceContentItemPath" -ErrorAction SilentlyContinue
    if ($item) {
     
        $newContentItemPath = Remap-DestinationPath -sourcePath $item.Paths.FullPath
        Write-Host "New content Item: "$newContentItemPath
        $ContentItem = Get-Item -Path "master:$newContentItemPath" -ErrorAction SilentlyContinue

        if ($ContentItem) {
            foreach ($field in $ContentItem.Fields) {
                if ($field -and ![string]::IsNullOrWhiteSpace($field.Value) -and !$field.InnerItem.Paths.FullPath.StartsWith("/sitecore/templates/system", 'CurrentCultureIgnoreCase')) {
                    # $fieldValue = $field.Value
                    if ($field.Type -eq "General Link") {
                        Write-Host "General Links"

                        [Sitecore.Data.Fields.LinkField]$linkField = $ContentItem.Fields[$field.Name]
                        if ($linkField -and $linkField.LinkType -eq "internal" -and [Sitecore.Data.ID]::IsID($linkField.TargetID)) {
                            $newLinkedItemId = Remap-LinkedItemId -itemId $linkField.TargetID
                            if ([Sitecore.Data.ID]::IsID($newLinkedItemId)) {
                                $ContentItem.Editing.BeginEdit()
                                $linkField.TargetID = $newLinkedItemId
                                $ContentItem.Editing.EndEdit() > $null
                                $global:updatedFields++
                            }
                        }
               
                    }
                    #Droplink and Droptree field values are the same so we are using the same functionality
  
                    elseif ($field.Type -eq "Droplink" -or $field.Type -eq "Droptree") {
                        Write-Host "Droplinks"

                        if ([Sitecore.Data.ID]::IsID($field.Value)) {
                            $newLinkedItemId = Remap-LinkedItemId -itemId $field.Value
                            $ContentItem.Editing.BeginEdit()
                            $field.Value = $newLinkedItemId
                            $ContentItem.Editing.EndEdit()
                            $global:updatedFields++
                        }
                    }
                    elseif ($field.Type -eq "Multilist" -or $field.Type -eq "Treelist") {
                        # Split the IDs, remap them, and then join back
                        Write-Host "Multilist"

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
                    elseif ($field.Type -eq "Image" ) {
                        # Use ImageField as variable type
                        [Sitecore.Data.Fields.ImageField] $imageField = $field
                        Write-Host "Got imagefield value: "$imageField.MediaID
                
                        $mediaItem = Get-Item -Path "master:" -ID $imageField.MediaID                
                        $newMediaItemId = Find-NewImageId -Name $mediaItem.Name
                
                        Write-Host "New Media ID  : "$newMediaItemId

                        if ([Sitecore.Data.ID]::IsID($newMediaItemId.ItemId)) {
                            Write-Host "Updating imagefield to: "$newMediaItemId.ItemId
                            $ContentItem.Editing.BeginEdit()
                            $imageField.MediaID = $newMediaItemId.ItemId
                            $ContentItem.Editing.EndEdit() > $null
                            $global:updatedFields++
                        }
                    }
                }          
            } 


            # Update Insert Options (__Masters field)
            $insertOptionsField = $ContentItem.Fields["__Masters"]
            if ($insertOptionsField -and $insertOptionsField.HasValue) {
                $newIds = @()
                $ids = $insertOptionsField.Value -split '\|'

                Write-Host "Insert Options"
                foreach ($id in $ids) {
                    $remappedId = Remap-LinkedItemId -itemId $id
                    $newIds += $remappedId
                }
 
                if ($newIds) {

                    $ContentItem.Editing.BeginEdit()
                    $insertOptionsField.Value = $newIds -join "|"
                    $ContentItem.Editing.EndEdit()
                    Write-Host "Updated Insert Options for item: $newContentItemPath"
                }
            }
        }
        else {
            Write-Host "Could not find content item at path: $newContentItemPath"
        }
    }
}

function Remap-LinkedItemId {
    param (
        [string]$ItemId
    )

    # Check if $ItemId is a valid GUID
    if ([Sitecore.Data.ID]::IsID($ItemId)) {
        try {
            $linkedItem = Get-Item -Path "master:" -ID $ItemId -ErrorAction SilentlyContinue
            if ($linkedItem) {
                $newLinkedItemPath = Remap-DestinationPath -sourcePath $linkedItem.Paths.FullPath
                $newLinkedItem = Get-Item -Path "master:$newLinkedItemPath" -ErrorAction SilentlyContinue
                if ($newLinkedItem) {
                    return $newLinkedItem.ID.ToString()
                }
            }
        }
        catch {
            # Handle errors or invalid GUID formats gracefully
            Write-Host "Warning: Unable to find or remap linked item with ID $ItemId"
        }
    }
    else {
        Write-Host "Invalid GUID format or broken link for ID: $ItemId"
    }
    # Return original ItemId if the ID is not valid or if no new linked item was found
    return $ItemId
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
    return Find-Item @props  | Select-Object -Property ItemId -First 1
}


function Update-RenderingItems {
    param (
        [Parameter(Mandatory = $true)][string]$renderingItemId
    )
    $renderingItem = Get-Item -Path "master:$renderingItemId"

    # Proceed only if the rendering item exists
    if ($renderingItem) {
        
        # Step 1: Copy Rendering Item to new rendering path for headless
        try {
            $newRenderingPath = Remap-DestinationPath -sourcePath  $renderingItem.Parent.Paths.FullPath 
           

            $existingItem = Get-Item -Path "$newRenderingPath/$($renderingItem.Name)" -ErrorAction SilentlyContinue
            if ($existingItem) {
                $existingItem.Editing.BeginEdit()


                #Replace rendering names that has spaces with dash(-)
                $existingItem.Name = $renderingItem.Name.Replace(" ", "-") 
                
                #adding value to the field as it is needed for our new rendering JSS
                $existingItem["ComponentName"] = $existingItem.Name
              
                $existingItem.Editing.EndEdit()
            }
          
        }
        catch {

            Write-Host "Failed to copy item: $($_.Exception.Message)"

        }
        

        
          
    }

}

function Update-SiteGroupingStartItem {
    param (
        [string]$SiteGroupingPath = "",
        [string]$SiteGroupingTemplateId = "{E46F3AF2-39FA-4866-A157-7017C4B2A40C}",
        [string]$NewStartItemId
    )

    # Get all child items of the specified path with the given template ID
    $siteGroupingItems = Get-ChildItem -Path "master:$SiteGroupingPath" -Recurse | Where-Object { $_.TemplateID -eq $SiteGroupingTemplateId }

    foreach ($item in $siteGroupingItems) {
        # Check if the item is in editing mode, if not, begin editing
        if (-not $item.Editing.IsEditing) {
            $item.Editing.BeginEdit()
        }

        try {
            # Update the "Start item" field
            $item.Fields["Startitem"].Value = $NewStartItemId

            # End editing and submit changes
            $item.Editing.EndEdit() | Out-Null
            Write-Host "Updated 'Start item' for $($item.Paths.FullPath)"
        }
        catch {
            # If an error occurs, cancel editing and show the error
            $item.Editing.CancelEdit()
            Write-Host "Failed to update 'Start item' for $($item.Paths.FullPath): $($_.Exception.Message)"
        }
    }
}



#********************************************Main Code Block***************************************************

New-UsingBlock (New-Object Sitecore.Data.BulkUpdateContext) {
    Set-Location -Path "master:/"
    $importCSVFileFolderPath = "/sitecore/media library/CsvFiles"
    # if (-Not (Test-Path $importCSVFileFolderPath)) {
    #     Show-Alert -Title "'$importCSVFileFolderPath' doesn't exist !!"
    #     Write-Host "'$importCSVFileFolderPath' doesn't exist!" -ForegroundColor Red;
    #     Exit
    # }

    # Code to select the CSV file which needs to be imported
    $finalFileImportPath = "";
    
    $parameters = @(
        @{ Name = "sourceNode"; Title = "Source Website Node"; Tooltip = "Enter the source website node"; Editor = "droptree"; DefaultValue = "/sitecore/content/contosomvc" },
        @{ Name = "destinationNode"; Title = "Destination Website Node"; Tooltip = "Enter the destination website node"; Editor = "droptree"; DefaultValue = "/sitecore/content/DemoHeadlesstenant/sxawebsite" },
        @{ Name = "importFileFolder"; Title = "CSV File Location"; Source = "Datasource=/sitecore/media library/"; Mandatory = $true; Editor = "droptree" },
        @{ Name = "sourceMediaLibrary"; Title = "Source Media Library Folder"; Source = "Datasource=/sitecore/media library/"; Tooltip = "Enter the source media library folder"; Editor = "droptree"; DefaultValue = "/sitecore/media library" },
        @{ Name = "destinationMediaLibrary"; Title = "Destination Media Library Folder"; Source = "Datasource=/sitecore/media library/"; Tooltip = "Enter the destination media library folder"; Editor = "droptree"; DefaultValue = "/sitecore/media library" },
        @{ Name = "newHomepage"; Title = "Start Item Website Home Page"; Tooltip = "Enter the website's homepage"; Editor = "droptree"; DefaultValue = "/sitecore/content/DemoHeadlesstenant/sxawebsite/Homepage" }
    )
    
    $result = Read-Variable -Parameters $parameters -Description "Select source, destination node and CSV file." -Title "Configuration" -Width 500 -Height 500 -OkButtonName "Proceed" -CancelButtonName "Cancel" -ShowHints

    if ($result -eq "cancel") {
        Write-Host "Pleases select source, destination node and CSV file." 
        Exit
    }
    else {
        
        $global:sourceNodePath = $sourceNode.Parent.Name + "/" + $sourceNode.Name
        $global:destinationNodePath = $destinationNode.Parent.Name + "/" + $destinationNode.Name
        $global:destinationMediaLibraryPath = $destinationMediaLibrary.FullPath
        $finalFileImportPath = $importFileFolder.Paths.FullPath
        
    } 

    # Get media item
    $resultSet = Get-Item -Path $finalFileImportPath
    # Get stream and save content to variable $content
    [System.IO.Stream]$body = $resultSet.Fields["Blob"].GetBlobStream()
    try {
        $contents = New-Object byte[] $body.Length
        $body.Read($contents, 0, $body.Length) | Out-Null
    }
    finally {
        $body.Close()    
    }

    # Convert to dynamic object
    $csv = [System.Text.Encoding]::Default.GetString($contents) | ConvertFrom-Csv -Delimiter ","
 

    $uniqueRenderings = $csv | Select-Object "CurrentItem-Rendering-ItemId" -Unique
    foreach ($rendering in $uniqueRenderings) {
        if ($rendering."CurrentItem-Rendering-ItemId") {
            $renderingItemId = $rendering."CurrentItem-Rendering-ItemId"
            Update-RenderingItems -renderingItemId $renderingItemId
        }
    }


    # Extract unique highest-level content item paths
    $uniqueContentItemPaths = $csv | 
    Select-Object "CurrentItem-ItemPath" -Unique | 
    Where-Object { $_."CurrentItem-ItemPath" -ne $sourceNode.FullPath } |
    Sort-Object { $_."CurrentItem-ItemPath".Length }

    $filteredPaths = @()
    foreach ($pathObj in $uniqueContentItemPaths) {
        $path = $pathObj."CurrentItem-ItemPath"
        $isChild = $false
        foreach ($filteredPath in $filteredPaths) {
            if ($path.StartsWith($filteredPath)) {
                $isChild = $true
                break
            }
        }
        if (-not $isChild) {
            $filteredPaths += $path
        }
    }
    Write-Host "Filtered paths:" $filteredPaths

    #Update Renderings/Layout/Link type field values of the item
    # foreach ($filteredPath in $filteredPaths) {
    #     $filteredPath
    #     Get-ChildItem -Path $filteredPath -Recurse -WithParent | ForEach-Object {
    #         Write-Host "Updating content item : "$_.FullPath
    #         Update-LinkFields -SourceContentItemPath $_.FullPath
                         
    #     }
        
    # }




    foreach ($filteredPath in $filteredPaths) {
        if ($filteredPath -like "*/Presentation/Page Designs") {
            Get-ChildItem -Path $filteredPath -Recurse | ForEach-Object {
                Write-Host "Updating content item : "$_.FullPath
                Update-LinkFields -SourceContentItemPath $_.FullPath
                             
            }
        }

        elseif ($filteredPath -like "*/Presentation/Partial Designs") {
            Get-ChildItem -Path $filteredPath -Recurse  | ForEach-Object {
                Write-Host "Updating content item : "$_.FullPath
                Update-LinkFields -SourceContentItemPath $_.FullPath
                             
            }           
            
        }
        else {
            Get-ChildItem -Path $filteredPath -Recurse -WithParent | ForEach-Object {
                Write-Host "Updating content item : "$_.FullPath
                Update-LinkFields -SourceContentItemPath $_.FullPath
                             
            }
        }
    }


    # Update template's standard values and insert options for link type fields
    $uniqueTemplateIds = $csv | Select-Object -ExpandProperty "CurrentItem-CreatedWith-TemplateId" -Unique
    foreach ($templateId in $uniqueTemplateIds) {
        $templateItem = Get-Item -Path "master:" -ID $templateId
        if ($templateItem -and $templateItem["__Standard Values"]) {
            $standardValuesPath = $templateItem.Paths.FullPath + "/__Standard Values"
            Write-Host "Updating standard value item: $standardValuesPath"
            Update-LinkFields -SourceContentItemPath $standardValuesPath
        }
    }



    #Update new Site's Start item
    $siteGroupingPath = "$($destinationNode.Fullpath)/Settings/Site Grouping"
    Update-SiteGroupingStartItem -SiteGroupingPath $siteGroupingPath -NewStartItemId $newHomepage.Id




    Write-Host "Number of fields updated: "$global:updatedFields

    

}




