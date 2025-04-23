# Global variables for source and destination nodes
$global:sourceNodePath = ""
$global:destinationNodePath = ""
$global:sourceNodeTenantName = ""
$global:destinationNodeTenantName = ""
$global:destinationMediaLibraryPath = ""
$global:itemsCopied = 0
$global:itemsExisting = 0
$global:itemsFailed = 0
$global:GenericParametersTemplate = ""
$global:GenericHeadlessLayout = ""



# Hardcoded values for new template and placeholders
$global:newLayoutTemplatePath = "/sitecore/templates/Foundation/JSS Experience Accelerator/Presentation/SXA JSS Layout"
$global:defaultHeadlessLayoutPath = "/sitecore/layout/Layouts/Foundation/JSS Experience Accelerator/Presentation/JSS Layout"
$global:headlessVariantTemplatePath = "/sitecore/templates/Foundation/JSS Experience Accelerator/Headless Variants/HeadlessVariants"
$global:headlessVariantTemplateDefinitionPath = "/sitecore/templates/Foundation/JSS Experience Accelerator/Headless Variants/Variant Definition"
$global:additionalPlaceholderIds = @(
    "{21F39740-9A0D-40D1-8341-0896179C9A1B}",
    "{284D388A-9D4E-4742-A298-EC6871592D4B}",
    "{49E56593-BB61-41CA-8B9A-806B11486366}"
)
$global:jsonRenderingTemplateId = "{04646A89-996F-4EE7-878A-FFDBF1F0EF0D}"
$global:inheritedTemplates = @(
    "{6650FB34-7EA1-4245-A919-5CC0F002A6D7}"
    "{4414A1F9-826A-4647-8DF4-ED6A95E64C43}"
    "{371D5FBB-5498-4D94-AB2B-E3B70EEBE78C}"
    "{47151711-26CA-434E-8132-D3E0B7D26683}"
)

$global:inheritedParameterTemplates = @(
    "{4247AAD4-EBDE-4994-998F-E067A51B1FE4}"
    "{5C74E985-E055-43FF-B28C-DB6C6A6450A2}"
    "{44A022DB-56D3-419A-B43B-E27E4D8E9C41}"
)


$global:pageIdentifierIds = @(
    "{BD74A392-DACD-4C23-853A-D520762B33A1}"
    "{B792CF81-FC99-4D71-A882-0E9FF9F0EC79}"   
    "{56ED46AC-0F58-416F-9D09-683E39825B27}"
    "{CE98D373-6154-4E38-8B5C-70B5B4AFEA60}"
    "{60C2F379-9FFD-4AA6-9D6D-87494ACEEDDD}"
    "{FD2059FD-6043-4DFE-8C04-E2437CE87634}"
    "{1105B8F8-1E00-426B-BF1F-C840742D827B}"
    "{47151711-26CA-434E-8132-D3E0B7D26683}"
)

# Function to ensure the target folder exists with an additional type parameter
function Ensure-Folder {
    param (
        [string]$Path,
        [string]$Type = "Folder"
    )
    if (-not $Path) {
        Write-Host "Ensure-Folder No Path  provided."
        return
    }

    $item = Get-Item -Path "master:$Path" -ErrorAction SilentlyContinue
    if (-not $item) {
        $pathParts = $Path -split '/'
        # Remove the last part of the path
        # $pathParts = $pathParts[0..($pathParts.Length - 2)]
        $currentPath = "master:"

        foreach ($part in $pathParts) {
            if (-not [String]::IsNullOrWhiteSpace($part)) {
                $destinationPath = $currentPath
                $currentPath = Join-Path $currentPath $part
                $folder = Get-Item -Path $currentPath -ErrorAction SilentlyContinue
                if (-not $folder) {
                    New-Item -Path $destinationPath -Name $part -Type $Type | Out-Null
                }
            }
        }
    }
}

#Function to create new layouts and placeholders
function Migrate-LayoutItems {
    param (
        [Parameter(Mandatory = $true)][string]$layoutItemPath
    )
    if (-not $layoutItemPath) {
        Write-Host "Migrate-LayoutItems No layoutItemPath  provided."
        return
    }

    $layoutItem = Get-Item -Path $layoutItemPath -ErrorAction SilentlyContinue

    if ($layoutItem -and $layoutItem["Placeholders"]) {
        $placeholderIDs = $layoutItem["Placeholders"] -split '\|'
        $newPlaceholderIDs = @()

        foreach ($id in $placeholderIDs) {
            $placeholderItem = Get-Item -Path "master:$id" -ErrorAction SilentlyContinue
            if ($placeholderItem) {
                try {
                    $newPlaceholderPath = Remap-DestinationPath -sourcePath $placeholderItem.Parent.Paths.FullPath
                    Write-Host $newPlaceholderPath

                    $existingItem = Get-Item -Path "$newPlaceholderPath/$($placeholderItem.Name)"
                    if ($existingItem -ne $null) {
                        $newPlaceholder = $existingItem
                        $global:itemsExisting++

                    }
                    else {
                        Ensure-Folder -Path $newPlaceholderPath -Type $placeholderItem.Parent.Template.FullName
                        $newPlaceholder = Copy-Item -Path $placeholderItem.ItemPath -Destination $newPlaceholderPath -PassThru -ErrorAction SilentlyContinue
                        $global:itemsCopied++
                    }
                    if ($newPlaceholder) {
                        $newPlaceholderIDs += $newPlaceholder.ID
                    }
                }
                catch {
                    
                    $global:itemsFailed++
                    Write-Host "Failed to copy item: $($_.Exception.Message)"
                    
                }
            }
        }

        if ($newPlaceholderIDs.Count -gt 0) {
            try {
                $newLayoutPath = Remap-DestinationPath -sourcePath $layoutItem.Parent.Paths.FullPath 
               

                $existingItem = Get-Item -Path "$newLayoutPath/$($layoutItem.Name)"
                if ($existingItem -ne $null) {
                    $newLayoutItem = $existingItem
                    $global:itemsExisting++
                }
                else {
                    Ensure-Folder -Path $newLayoutPath -Type $layoutItem.Parent.Template.FullName
                    $newLayoutItem = Copy-Item -Path $layoutItem.Paths.FullPath -Destination $newLayoutPath -PassThru -ErrorAction SilentlyContinue
                
                    if ($newLayoutItem) {
                        # Change the template
                        Set-ItemTemplate -Item $newLayoutItem -Template $global:newLayoutTemplatePath -ErrorAction SilentlyContinue
                        $updatedPlaceholders = ($newPlaceholderIDs + $global:additionalPlaceholderIds) -join "|"
                        $newLayoutItem.Editing.BeginEdit()
                        $newLayoutItem["Placeholders"] = $updatedPlaceholders
                        $newLayoutItem.Editing.EndEdit()
                    }
                    $global:itemsCopied++
                }
            }
            catch {


                $global:itemsFailed++
                Write-Host "Failed to copy item: $($_.Exception.Message)"
                
            }
        }
    }
}

#Function to create a new Generic Layout
function Create-GenericHeadlessLayout {
    param (
        [Parameter(Mandatory = $true)][string]$sourceLayoutItemPath
    )
    if (-not $sourceLayoutItemPath) {
        Write-Host "Create-GenericHeadlessLayout No sourceLayoutItemPath  provided."
        return
    }

    $destinationFolderPath = "/sitecore/layout/Layouts/Project/$($global:destinationNodePath)"
    Write-Host "Destination Folder Path: " $destinationFolderPath

    $sourceLayoutItem = Get-Item -Path $sourceLayoutItemPath -ErrorAction SilentlyContinue

    if ($sourceLayoutItem ) {
        try {
            Write-Host "Source layout item found: " $sourceLayoutItem.FullPath

            # Ensure the destination folder exists
            Ensure-Folder -Path $destinationFolderPath -Type "{93227C5D-4FEF-474D-94C0-F252EC8E8219}"

            # Copy the layout item to the destination folder
            $newGenericLayout = Copy-Item -Path $sourceLayoutItem.Paths.FullPath -Destination $destinationFolderPath -PassThru -ErrorAction SilentlyContinue
            Write-Host "Creating Generic Layout"

            $newGenericLayout.Editing.BeginEdit()
            $newGenericLayout.Name = $newGenericLayout.Name.Replace($newGenericLayout.Name, "Default") 
            $newGenericLayout["__Display name"] = $newGenericLayout.Name

            # $newGenericLayout.Editing.EndEdit()
            $global:GenericHeadlessLayout = $newGenericLayout
            $global:itemsCopied++
            Write-Host "Created Generic Layout"

        }
        catch {
            Write-Host "Error occurred at line 158: $($_.Exception.Message)"
        }
    }
    else {
        Write-Host "Source layout item not found."
    }

}

#Function to create placeholders and adding them to the layout
function Manage-PlaceholdersFromCsv {
    param (
        [Parameter(Mandatory = $true)]
        [object]$groupedPlaceholders
    )
    if (-not $groupedPlaceholders) {
        Write-Host "Manage-PlaceholdersFromCsv - No groupedPlaceholders  provided."
        return
    }

    foreach ($group in $groupedPlaceholders) {
        $layoutId = $group.Name
        $layoutItem = Get-Item -Path "master:/$layoutId" -ErrorAction SilentlyContinue
  
        if ($layoutId) {
            # $newLayoutPath = Remap-DestinationPath -sourcePath $layoutItem.Parent.Paths.FullPath
            # $newLayoutItem = Get-Item -Path "master:$newLayoutPath/$($layoutItem.Name)"
            Write-Host "master:$newLayoutPath/$($layoutItem.Name)"
            #  $newLayoutTemplate = Get-Item  -Path "master:/$($newLayoutItem.TemplateId) " -ErrorAction SilentlyContinue
            if ((IsOOTBItem -itemPath $layoutItem.FullPath)) {
                $newLayoutItem = $global:GenericHeadlessLayout
            }
            else {
                $newLayoutPath = Remap-DestinationPath -sourcePath $layoutItem.Parent.Paths.FullPath
                $newLayoutItem = Get-Item -Path "master:$newLayoutPath/$($layoutItem.Name)"
            }

            if ($newLayoutItem) {
                Write-Host  "Manage-PlaceholdersFromCsv - newLayoutItem : " $newLayoutItem.FullPath
                $placeholdersInCsv = $group.Group | Select-Object "CurrentItem-Rendering-Placeholder-ItemName" -Unique
  
                foreach ($placeholders in $placeholdersInCsv) {
                    $placeholderList = $placeholders."CurrentItem-Rendering-Placeholder-ItemName"
                    $placeholderKeys = $placeholderList -split '/'
                    foreach ($placeholderkey in $placeholderKeys) {
                        Write-Host $placeholderkey
                        $existingPlaceholderItem = Find-ExistingPlaceholder -placeholderKey $placeholderKey
                        if (-not $existingPlaceholderItem -and $placeholderkey) {
                            Write-Host "No existingPlaceholderItem : Creating new for $placeholderkey"

                            $newPlaceholderItem = Create-Placeholder -placeholderKey $placeholderKey
                            $newLayoutItem.Editing.BeginEdit()
                            $newLayoutItem["Placeholders"] += "|$($newPlaceholderItem.ID)"
                            $newLayoutItem.Editing.EndEdit()
                            $global:itemsCopied++
                        }
                    }
                }
            }
        }
    }
}

#Function to check if the placeholder used in the renderings exists
function Find-ExistingPlaceholder {
    param (
        [string]$placeholderKey
    )
    if (-not $placeholderKey) {
        Write-Host "Find-ExistingPlaceholder - No placeholderKey  provided."
        return
    }

    $placeholderPath = "/sitecore/layout/Placeholder Settings/Project/$($global:destinationNodePath)"
    $existingPlaceholder = Get-ChildItem -Path "master:$placeholderPath" | Where-Object { $_.Fields["Placeholder Key"].Value -eq $placeholderKey }
    return $existingPlaceholder
}
  
#Function to create new placeholders to the specific path
function Create-Placeholder {
    param (
        [string]$placeholderKey
    )
    if (-not $placeholderKey) {
        Write-Host "Create-Placeholder - No placeholderKey  provided."
        return
    }

    $placeholderPath = "/sitecore/layout/Placeholder Settings/Project/$($global:destinationNodePath)"
    Write-Host "Creating Placeholder in : " $placeholderPath
    Ensure-Folder -Path $placeholderPath -Type '{C3B037A0-46E5-4B67-AC7A-A144B962A56F}'
    $newPlaceholderItem = New-Item -Path "$placeholderPath" -Name $placeholderKey -ItemType "/sitecore/templates/System/Layout/Placeholder"
    $newPlaceholderItem.Editing.BeginEdit()
    $newPlaceholderItem["Placeholder Key"] = $placeholderKey
    $newPlaceholderItem.Editing.EndEdit()
    return $newPlaceholderItem
}
  
  

#Function to create new rendering parameter for renderings w/o not using any.
function Create-GenericRenderingParameter {
   
    param (
        [Parameter(Mandatory = $true)][string]$ParameterTemplateName,
        [Parameter(Mandatory = $true)][string]$DestinationPath
    )
    if (-not $ParameterTemplateName) {
        Write-Host "No ParameterTemplateName  provided."
        return
    }
    if (-not $DestinationPath) {
        Write-Host "No DestinationPath  provided."
        return
    }

    # Ensure the folder for the parameters template exists
    Ensure-Folder -Path $destinationPath -Type '{0437FEE2-44C9-46A6-ABE9-28858D9FEE8C}'

    # Define the full path for the new template
    $fullNewTemplatePath = Join-Path $destinationPath $parameterTemplateName

    # Check if the parameters template already exists
    $existingTemplate = Get-Item -Path "master:$fullNewTemplatePath" -ErrorAction SilentlyContinue
    if (-not $existingTemplate) {
        # Create the new parameters template
        $newTemplateItem = New-Item -Path $destinationPath -Name $parameterTemplateName -ItemType "{AB86861A-6030-46C5-B394-E8F99E8B87DB}"
        $global:GenericParametersTemplate = $newTemplateItem.Id
        
        if ($newTemplateItem) {
            # Begin editing the item
            $newTemplateItem.Editing.BeginEdit()

            try {
                # Set the base templates
                $newTemplateItem["__Base template"] = $global:inheritedParameterTemplates -join '|'

                # End editing the item
                $newTemplateItem.Editing.EndEdit()
            }
            catch {
                # If an error occurs, cancel the edit and show a message
                $newTemplateItem.Editing.CancelEdit()
                Write-Host "Error encountered: $($_.Exception.Message)"
            }
        }
    }
    else {
        Write-Host "Template '$newTemplateName' already exists at '$destinationPath'."
    }
}

#Check if item already exists in Headless Experience Accelerator(rendering/template) and returns the path
#This also remove white spaces for the rendering name as it is JSS renderings should not have spaces in between names.
function Check-Existing-HeadlessSXAItem {
    param (
        [Parameter(Mandatory = $true)][string]$ItemLocation,
        [Parameter(Mandatory = $true)][string]$ItemName
    )
    if (-not $ItemLocation) {
        Write-Host "No ItemLocation  provided."
        return
    }
    if (-not $ItemName) {
        Write-Host "No ItemName  provided."
        return
    }

    # Replace "Experience Accelerator" with "JSS Experience Accelerator" in the provided path
    if ($ItemLocation -like "*Feature/Experience Accelerator*" -or ($ItemLocation -like "*Foundation/Experience Accelerator*")) {
    
        $headlessSxaPath = $ItemLocation -replace "Experience Accelerator", "JSS Experience Accelerator"
        $headlessRendering = Get-Item -Path "$headlessSxaPath/$ItemName"
        # Write-Host "item  :" $ItemLocation"/"$ItemName
        # Write-Host "new Path : " $headlessSxaPath"/"$ItemName

        if ($headlessRendering) {
            # If the item exists, return its path
            # Write-Host "item exists :" $headlessRendering.FullPath
            return $headlessSxaPath
        }
        else {           
            # Write-Host "item does not exists :" $headlessRendering.FullPath
    
            return ""
            
        }
    }
    else {
        # Write-Host "item does not come from SXA OOTB :" $ItemPath
    
        return ""
    }
    
}


# Function to migrate rendering items
function Migrate-RenderingItems {
    param (
        [Parameter(Mandatory = $true)][string]$renderingItemId
    )
    if (-not $renderingItemId) {
        Write-Host "No renderingItemId  provided."
        return
    }

    $renderingItem = Get-Item -Path "master:$renderingItemId"

    # Proceed only if the rendering item exists
    if ($renderingItem) {
        
        # Step 1: Copy Rendering Item to new rendering path for headless
        try {
            Write-Host "Source rendering path: " $renderingItem.FullPath
            if (IsOOTBItem -itemPath $renderingItem.FullPath) {
                if ($renderingItem.FullPath -match "/sitecore/layout/Renderings/") {
                    $newRenderingPath = $renderingItem.Parent.Paths.FullPath -replace "/Feature/Experience Accelerator", "/Project/$($global:destinationNodePath)"
                   
                }
            }
            else {
                $newRenderingPath = Remap-DestinationPath -sourcePath  $renderingItem.Parent.Paths.FullPath 

            }
            $existingItem = Get-Item -Path "$newRenderingPath/$($renderingItem.Name)" -ErrorAction SilentlyContinue
            $isExistingItem = $false
            if ($existingItem -ne $null) {
                #  $newRenderingItem = $existingItem
                $isExistingItem = $true

                $global:itemsExisting++
                Write-Host "Existing Item Path: "$existingItem.FullPath

            }
            else {
                Ensure-Folder -Path $newRenderingPath -Type $renderingItem.Parent.Template.FullName
                $newRenderingItem = Copy-Item -Path $renderingItem.ItemPath -Destination $newRenderingPath -PassThru 
                $global:itemsCopied++
            }

            Write-Host "new Rendering Path: "$newRenderingPath

        }
        catch {
            if ($_.Exception.Message -like "*already exists*") {
                #              Write-Host "rendering exists " $renderingItem.FullPath
                $global:itemsExisting++
            }
            else {
                $global:itemsFailed++
                Write-Host "Failed to copy item: $($_.Exception.Message)"
            }
        }
        # Step 3: Migrate parameters template if any
        $parametersTemplateId = $renderingItem["Parameters Template"]
        Write-Host "Parameter Template Id" $parametersTemplateId
        if ($parametersTemplateId -and (-not $isExistingItem) ) {
            $parametersTemplateItem = Get-Item -Path "master:$parametersTemplateId" 
            Write-Host "Parameter Template Id" $parametersTemplateItem.Name

            if ($parametersTemplateItem) {
                try {

                    if (IsOOTBItem -templatePath $parametersTemplateItem.FullPath) {
                        $newParametersTemplatePath = Check-Existing-HeadlessSXAItem -ItemLocation $parametersTemplateItem.Parent.Paths.Path -ItemName $parametersTemplateItem.Name
                        if (-not $newParametersTemplatePath) {
                            $newParametersTemplatePath = Get-NewTemplatePathForOOBItems -templateItem $parametersTemplateItem
                        }
                       
                    }
                    else {
                        $newParametersTemplatePath = Remap-DestinationPath -sourcePath  $parametersTemplateItem.Parent.Paths.FullPath
        
                    }

                    # $newParametersTemplatePath = Remap-DestinationPath -sourcePath  $parametersTemplateItem.Parent.Paths.FullPath
                    # Check if the item already exists at the destination
                    $existingItem = Get-Item -Path "$newParametersTemplatePath/$($parametersTemplateItem.Name)" -ErrorAction SilentlyContinue
                    Write-Host "Getting Existing Item: " $existingItem.Name
                    if ($existingItem -ne $null) {
                        # If the item exists, use the existing item
                        $newParametersTemplateItem = $existingItem
                    }
                    else {
                       
                        # If the item does not exist, proceed to copy 
                        Copy-TemplateRecursively -templatePath $parametersTemplateItem.ItemPath -newTemplatePath $newParametersTemplatePath
                        $newParametersTemplateItem = Get-Item -Path "$newParametersTemplatePath/$($parametersTemplateItem.Name)" -ErrorAction SilentlyContinue
                        Write-Host $parametersTemplateItem.ItemPath
                        Write-Host $newParametersTemplatePath
                        Write-Host "new parametersTemplateItem: " $newParametersTemplateItem.Name
                        $newParametersTemplateItem.Editing.BeginEdit()
                        # Combine current and new base template IDs into an array
                        $combinedBaseTemplates = @($newParametersTemplateItem["__Base template"].Split('|'), $global:inheritedParameterTemplates).Trim() | Where-Object { $_ -ne '' } | Select-Object -Unique
 
                        # Join the array elements into a single string separated by '|'
                        $parameterBaseTemplates = $combinedBaseTemplates -join '|' 
                        $newParametersTemplateItem["__Base template"] = $parameterBaseTemplates -join "|"
                        $newParametersTemplateItem.Editing.EndEdit()
                    }
                    Write-Host "new Parameters template Path: "$newParametersTemplatePath

                }
                catch {
                    
                    $global:itemsFailed++
                    
                    Write-Host "Failed to copy item test: $($_.Exception.Message)"
                    
                }
            }
        }
        else {
            Create-GenericRenderingParameter -ParameterTemplateName "HeadlessBaseParameterTemplate"   -DestinationPath "/sitecore/templates/Feature/$global:destinationNodePath/Rendering Parameters"
        }

        # Steps 4 and 5: Migrate datasource location and template if they are paths
        $datasourceLocation = $renderingItem["Datasource Location"]
        Write-Host "Datasource Location" $datasourceLocation

        if ($datasourceLocation -and -not $datasourceLocation.StartsWith("query:") -and (-not $isExistingItem)) {
            
            $datasourceLocationItem = Get-Item -Path "master:$datasourceLocation" -ErrorAction SilentlyContinue
            Write-Host "Datasource Template Location Item Get: " $datasourceLocationItem.Name

            if ($datasourceLocationItem) {
                
                $newDatasourceLocation = Remap-DestinationPath -sourcePath  $datasourceLocation 
                
                
            }
        }

        #Migrate Datasource template
        $datasourceTemplatePath = $renderingItem["Datasource Template"]

        $datasourceTemplateItem = Get-Item -Path "master:$($datasourceTemplatePath)" 
        if ($datasourceTemplateItem) {
            try {

                if (IsOOTBItem -templatePath $datasourceTemplateItem.FullPath) {
                    $newDatasourceTemplatePath = Check-Existing-HeadlessSXAItem -ItemLocation $datasourceTemplateItem.Parent.Paths.Path -ItemName $datasourceTemplateItem.Name
                    if (-not $newDatasourceTemplatePath) {
                        $newDatasourceTemplatePath = Get-NewTemplatePathForOOBItems -templateItem $datasourceTemplateItem
                    }
                           
                }
                else {
                    $newDatasourceTemplatePath = Remap-DestinationPath -sourcePath  $datasourceTemplateItem.Parent.Paths.FullPath
            
                }                     

                # Check if the item already exists at the destination
                $existingItem = Get-Item -Path "$newDatasourceTemplatePath/$($datasourceTemplateItem.Name)" -ErrorAction SilentlyContinue
                if ($existingItem -ne $null) {
                    $newDatasourceTemplateItem = $existingItem                           
                }
                elseif ($datasourceTemplateItem.FullPath -match "/sitecore/templates/Branches") {
                    Ensure-Folder -Path $newDatasourceTemplatePath -Type $datasourceTemplateItem.Parent.Template.FullName
                    $newDatasourceTemplateItem = Copy-Item -Path $datasourceTemplateItem.FullPath -Destination $newDatasourceTemplatePath -Recurse -PassThru
                    Copy-BranchTemplatesAndSetNewPath -branchItemPath $newDatasourceTemplateItem.FullPath 

                }
                else {                         
                    Copy-TemplateRecursively -templatePath $datasourceTemplateItem.ItemPath -newTemplatePath $newDatasourceTemplatePath
                    $newDatasourceTemplateItem = Get-Item -Path "$newDatasourceTemplatePath/$($datasourceTemplateItem.Name)" -ErrorAction SilentlyContinue
                }
                        
                Write-Host "new Datasource template Path: "$newDatasourceTemplatePath


            }
            catch {
                      
                $global:itemsFailed++
                Write-Host "Failed to copy item: $($_.Exception.Message)"
                        
            }
        }
        


        # Step 6: Update the new rendering item with the new details
        if ($newRenderingItem -and (-not $isExistingItem)) {
            # Step 7: Change the rendering's template to Json Rendering
            Set-ItemTemplate -Item $newRenderingItem -Template $global:jsonRenderingTemplateId -ErrorAction SilentlyContinue
            $newRenderingItem.Editing.BeginEdit()
            if ($parametersTemplateId ) {
                Write-Host $newRenderingItem["Parameters Template"] 
                $newRenderingItem["Parameters Template"] = $newParametersTemplateItem.ID  
                Write-Host $newRenderingItem["Parameters Template"] 
                Write-Host $newParametersTemplateItem.ID              
            }
            else {
                $newRenderingItem["Parameters Template"] = $global:GenericParametersTemplate

            }
            if ($newDatasourceTemplateItem) {
                $newRenderingItem["Datasource Template"] = $newDatasourceTemplateItem.FullPath
                $newRenderingItem["Datasource Location"] = $newDatasourceLocation
               

            }

            
          
            $newRenderingItem.Editing.EndEdit()
        }


    }
    else {
        Write-Host "Rendering item with ID $renderingItemId does not exist."
    }
}

# Function to replace the path segment
function Remap-DestinationPath {
    param(
        [string]$sourcePath
    )
    if (-not $sourcePath) {
        Write-Host "No sourcePath path provided."
        return
    }

    # Source Node Path
    if ($sourcePath -match $global:sourceNodePath) {
        return $sourcePath -replace $global:sourceNodePath, $global:destinationNodePath
    }
    # Source Node Tenant Name
    elseif ($sourcePath -match $global:sourceNodeTenantName) {
        return $sourcePath -replace $global:sourceNodeTenantName, $global:destinationNodeTenantName
    }
    # Templates
    elseif ($sourcePath -match "/sitecore/templates/") {
        return  "/sitecore/templates/Project/$global:destinationNodePath/"
    }
    # Renderings
    elseif ($sourcePath -match "/sitecore/layout/Renderings/") {
        return  "/sitecore/layout/Renderings/Project/$global:destinationNodePath/"
    }
    # Layouts
    elseif ($sourcePath -match "/sitecore/layout/Layouts/") {
        return  "/sitecore/layout/Layouts/Project/$global:destinationNodePath/"
    }
    # Placeholder Settings
    elseif ($sourcePath -match "/sitecore/layout/Placeholder Settings/") {
        return  "/sitecore/layout/Placeholder Settings/Project/$global:destinationNodePath/"
    }
    # Default case if none of the above matches
    else {
        return $sourcePath
    }
}


function IsOOTBItem {
    param(
        [string]$templatePath,
        [string]$itemPath
    )
    if (-not $templatePath) {
        Write-Host "No templatePath path provided."
        return
    }
    if (-not $itemPath) {
        Write-Host "No itemPath path provided."
        return
    }

    # Define standard template paths for Sitecore and SXA
    $standardTemplatePaths = @(
        "/sitecore/templates/System",
        "/sitecore/templates/Feature/Experience Accelerator",
        "/sitecore/templates/Feature/JSS Experience Accelerator",
        "/sitecore/templates/Foundation/Experience Accelerator",
        "/sitecore/templates/Foundation/JSS Experience Accelerator",
        "/sitecore/templates/Foundation/JavaScript Services",
        "/sitecore/templates/Modules",
        "/sitecore/templates/Common",
        "/sitecore/templates/System/Layout/Layout",
        "/sitecore/templates/Branches/Feature/Experience Accelerator",
        "/sitecore/templates/Branches/Foundation/Experience Accelerator"
    )
    $OOTBItemPaths = @(
        "/sitecore/layout/Renderings/Feature/Experience Accelerator",
        "/sitecore/templates/Feature/Experience Accelerator",
        "/sitecore/layout/Layouts/Foundation/Experience Accelerator"
        "/sitecore/layout/Renderings/System/"
    )

    if ($templatePath) {
        foreach ($path in $standardTemplatePaths) {
            if ($templatePath.StartsWith($path, "OrdinalIgnoreCase")) {
                return $true
            }
        }
    }

    if ($itemPath) {
        foreach ($path in $OOTBItemPaths) {
            if ($itemPath.StartsWith($path, "OrdinalIgnoreCase")) {
                return $true
            }
        }
    }
    
    return $false
}

function Get-NewTemplatePathForOOBItems {
    param(
        [Parameter(Mandatory = $true)]
        [Sitecore.Data.Items.Item]$templateItem
    )
    if (-not $templateItem) {
        Write-Host "No templateItem path provided."
        return
    }

    # Initialize newTemplatePath variable
    $newTemplatePath = $null

    # Determine the new base template path based on the original path of the base template item
    if ($templateItem.FullPath -match "/sitecore/templates/Feature") {
        $newTemplatePath = $templateItem.Parent.Paths.FullPath -replace "/Feature/Experience Accelerator", "/Project/$($global:destinationNodePath)"
    }
    elseif ($templateItem.FullPath -match "/sitecore/templates/Foundation") {
        $newTemplatePath = $templateItem.Parent.Paths.FullPath -replace "/Foundation/Experience Accelerator", "/Project/$($global:destinationNodePath)"
    }
    elseif ($templateItem.FullPath -match "/sitecore/templates/Branches/Foundation") {
        $newTemplatePath = $templateItem.Parent.Paths.FullPath -replace "/Branches/Foundation/Experience Accelerator", "/Branches/Project/$($global:destinationNodePath)"
    }
    elseif ($templateItem.FullPath -match "/sitecore/templates/Branches/Feature") {
        $newTemplatePath = $templateItem.Parent.Paths.FullPath -replace "/Branches/Feature/Experience Accelerator", "/Branches/Project/$($global:destinationNodePath)"
    }
    Write-Host "Source template item: " $templateItem.FullPath
    Write-Host "New Template path: " $newTemplatePath

    # Return the new base template path
    return $newTemplatePath
}


function IsPageTemplate {
    param(
        [Sitecore.Data.Items.Item]$templateItem
    )
    if (-not $templateItem) {
        Write-Host "No templateItem path provided."
        return
    }

    # Split the base templates of the item into an array
    $baseTemplates = $templateItem["__Base template"] -split '\|'
    # Iterate over each identifier ID to see if it's present in the base templates
    foreach ($id in $global:pageIdentifierIds) {
        if ($baseTemplates -contains $id) {
            return $true
        }
    }
    # If none of the IDs are found, return false
    return $false
}


# Function to recursively copy templates and update base templates
function Copy-TemplateRecursively {
    param (
        [string]$templatePath,
        [string]$newTemplatePath
    )
    if (-not $templatePath) {
        Write-Host "No template path provided."
        return
    }

    if (-not $newTemplatePath) {
        Write-Host "No newTemplatePath path provided."
        return
    }

    $proceedTemplateMigration = $false

    if ($templatePath -match "Foundation/Experience Accelerator" -or ($templatePath -match "Feature/Experience Accelerator") ) {
        $proceedTemplateMigration = $true
    }
    elseif (-not (IsOOTBItem -templatePath $templatePath)) {
        $proceedTemplateMigration = $true
    }
    else {
        $proceedTemplateMigration = $false

    }

    if ($proceedTemplateMigration) {
        $templateItem = Get-Item -Path "master:$templatePath" -ErrorAction SilentlyContinue
        Write-Host "Creating :"$newTemplatePath

        if ($templateItem) {
            $existingItem = Get-Item -Path "master:$newTemplatePath/$($templateItem.Name)" -ErrorAction SilentlyContinue

            if (-not $existingItem) {
                Ensure-Folder -Path $newTemplatePath -Type $templateItem.Parent.Template.FullName
                $newTemplateItem = Copy-Item -Path $templatePath -Destination $newTemplatePath -Recurse -PassThru
                # Increment the counter for each item copied
                Get-ChildItem -Path  $templatePath -Recurse | ForEach-Object {
                    $global:itemsCopied++
                }

                Write-Host "Copied - $($newTemplateItem.ItemPath)"

                # Update base templates for the copied template
                $baseTemplates = @()
                foreach ($baseTemplateId in $templateItem."__Base template" -split '\|') {
                    Write-Host $baseTemplateId
                    $baseTemplateItem = Get-Item -Path "master:$baseTemplateId" -ErrorAction SilentlyContinue

                    #check if base template is a sitecore oob
                    if (-not ($baseTemplateItem.FullPath -match "/sitecore/templates/Modules" -or
                            $path -match "/sitecore/templates/Common" -or
                            $path -match "/sitecore/templates/System" -or
                            $path -match "/sitecore/templates/Foundation/JavaScript Services" -or
                            $path -match "/sitecore/templates/Foundation/Experience Accelerator")) {

                        if ($baseTemplateItem) {

                            if (IsOOTBItem -templatePath $baseTemplateItem.FullPath) {
                                $newBaseTemplatePath = Check-Existing-HeadlessSXAItem -ItemLocation $baseTemplateItem.Parent.Paths.Path -ItemName $baseTemplateItem.Name
                                if (-not $newBaseTemplatePath) {
                                    $newBaseTemplatePath = Get-NewTemplatePathForOOBItems -templateItem $baseTemplateItem
                                    
                                }
                               
                            }
                            else {
                                $newBaseTemplatePath = Remap-DestinationPath -sourcePath  $baseTemplateItem.Parent.Paths.FullPath
                
                            }

                            
                            $existingTemplate = Get-Item -Path "$newBaseTemplatePath/$($baseTemplateItem.Name)"  -ErrorAction SilentlyContinue
                            if ($existingTemplate) {
                                $newBaseTemplate = $existingTemplate  
                            }
                            else {
                                Copy-TemplateRecursively -templatePath $baseTemplateItem.Paths.FullPath -newTemplatePath $newBaseTemplatePath
                                $newBaseTemplate = Get-Item -Path "$newBaseTemplatePath/$($baseTemplateItem.Name)" 
                            }
                           
                            $baseTemplates += $newBaseTemplate.Id
                        
                        }
                    }
                    else {
                        $baseTemplates += $baseTemplateId
                    }
                }

                if ($newTemplateItem -and $baseTemplates) {
                    # If it's a page template, add the provided base template IDs
                    if (IsPageTemplate -templateItem $templateItem) {
                        # Add the provided base template IDs
                        $baseTemplates += $global:inheritedTemplates
                    }

                    $newTemplateItem.Editing.BeginEdit()
                    $newTemplateItem["__Base template"] = $baseTemplates -join "|"
                    $newTemplateItem.Editing.EndEdit()
                }

                Update-TemplateDetails -templatePath $newTemplateItem.Paths.FullPath
            }
            else {
                Write-Host "Existing Item - $($existingItem.ItemPath)"
                $global:itemsExisting++
            }
        }
    }
}

function Copy-BranchTemplatesAndSetNewPath {
    param (
        [string]$branchItemPath
    )
    if (-not $branchItemPath) {
        Write-Host "No branch Item path provided."
        return
    }
    $branchItem = Get-Item -Path "master:$branchItemPath"
    if ($branchItem) {
        Write-Host "BranchTemplate :" $branchItem.FullPath

        $subItems = Get-ChildItem -Path "master:$branchItemPath" -Recurse -ErrorAction SilentlyContinue
      

        foreach ($subItem in $subItems) {
            Write-Host "subitem :" $subItem.FullPath
            $branchTemplateItem = Get-Item -Path "master:$($subItem.TemplateID)"

            if ($branchTemplateItem) {
                try {
                    $newBranchTemplatePath = ""
                    if (IsOOTBItem -templatePath $branchTemplateItem.FullPath) {
                        $newBranchTemplatePath = Check-Existing-HeadlessSXAItem -ItemLocation $branchTemplateItem.Parent.Paths.Path -ItemName $branchTemplateItem.Name
                        if (-not $newBranchTemplatePath) {
                            $newBranchTemplatePath = Get-NewTemplatePathForOOBItems -templateItem $branchTemplateItem
                        }
                    }
                    else {
                        $newBranchTemplatePath = Remap-DestinationPath -sourcePath $branchTemplateItem.Parent.Paths.FullPath
                    }

                    $existingItem = Get-Item -Path "$newBranchTemplatePath/$($branchTemplateItem.Name)" -ErrorAction SilentlyContinue
                    if (-not $existingItem) {
                        Copy-TemplateRecursively -templatePath $branchTemplateItem.ItemPath -newTemplatePath $newBranchTemplatePath
                        $newTemplateItem = Get-Item -Path "$newBranchTemplatePath/$($branchTemplateItem.Name)" -ErrorAction SilentlyContinue

                    }

                    if ($newTemplateItem) {
                        Set-ItemTemplate -Item $subItem -Template $newTemplateItem.FullPath -ErrorAction SilentlyContinue
                    }
                    Write-Host "Updated template for subitem $($subItem.Name) to new path: $newBranchTemplatePath"
                }
                catch {
                    $global:itemsFailed++
                    Write-Host "Failed to process subitem $($subItem.Name): $($_.Exception.Message)"
                }
            }
        }
    }
    else {
        Write-Host "Branch item at path $branchItemPath does not exist."
    }
}


#Updates the templates standard values which consist of layout/renderings.
#Also update the source of data from the templates fields.
function Update-TemplateDetails {
    param (
        [string]$templatePath
    )
    if (-not $templatePath) {
        Write-Host "No Template path provided."
        return
    }

    $templateItem = Get-Item -Path "master:$templatePath" -ErrorAction SilentlyContinue
    Write-Host "updating-" $templateItem.Name
    if ($templateItem) {
        # Template Field Template ID
        $templateFieldTemplateId = "{455A3E98-A627-4B40-8035-E683A0331AC7}"

        # Iterate through each child item of the template
        $templateItem.Children | ForEach-Object {
            # Check and update standard values
            if ($_.Name -eq "__Standard Values") {
                $standardValuesItemPath = $_.Paths.FullPath

                # Check if Standard Values has a layout
                if (Get-Layout -Item $_ -FinalLayout) {
                    Update-Layouts -itemPath $standardValuesItemPath
                }

                # Check and update renderings
                if (Get-Rendering -Item $_ -FinalLayout) {
                    Update-Renderings -itemPath $standardValuesItemPath
                }
            }

            $_.Children | ForEach-Object {
                $_.Name
                if ($_.TemplateID -eq $templateFieldTemplateId) {
                    # It's a template field, check and update the Source field
                    $fieldItem = $_
                    $sourceField = $fieldItem.Fields["Source"]

                    if ($sourceField -and $sourceField.Value -like "/sitecore/*") {
                        # It's a path, update the Source field
                        $newSourcePath = Remap-DestinationPath -sourcePath $sourceField.Value
                        Write-Host "New Source has "$newSourcePath

                        Write-Host "Source has "$sourceField.Value
                        $fieldItem.Editing.BeginEdit()
                        $sourceField.Value = $newSourcePath
                        $fieldItem.Editing.EndEdit()
                        Write-Host "Updated Source field for $($fieldItem.Name) to $newSourcePath"
                    }
                }
            }
        }
    }
    else {
        Write-Host "Template not found: $templatePath"
    }
}
  
   
function Update-Renderings {
    param (
        [Parameter(Mandatory = $true)][string]$itemPath
    )
    if (-not $itemPath) {
        Write-Host "No Item path provided."
        return
    }

    try {
        $item = Get-Item -Path "master:$itemPath" 
        $device = Get-LayoutDevice -Default

      

        # Function to update renderings for a specific layout type
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
    
            foreach ($renderingInstance in $renderingInstances) {
                ## Update datasource 


                if ($renderingInstance.Datasource -and 
                    -not ($renderingInstance.Datasource -match "^local:/") -and
                    -not ($renderingInstance.Datasource -match "^query:") -and
                ($renderingInstance.Datasource -match "^/sitecore" -or $renderingInstance.Datasource -match "^[{].*[}]$")) {
            
                    $renderingDatasource = Get-Item -ID $renderingInstance.Datasource -Path "master:/" -ErrorAction SilentlyContinue
                    $newDatasourcePath = ""           
                    if ($renderingDatasource.FullPath -match "sitecore/content/") {
                        $newDatasourcePath = Remap-DestinationPath -sourcePath  $renderingDatasource.Parent.Paths.Path
                    }

       
                    
                    $newDatasource = Get-Item -Path "$newDatasourcePath/$($renderingDatasource.Name)" -ErrorAction SilentlyContinue
                 

                    if ($newDatasource) {
                        $renderingInstance.DataSource = "$newDatasourcePath/$($renderingDatasource.Name)"
                    }
                    else {
                        Write-Host "No changes to $($renderingInstance.Name) the Datasource:" $newDatasourcePath
                    }
                    
                
                }


                # Call Update-RenderingParameters to update the variant and styles

                # # Decode parameters and get rendering variant and styles
                $decodedParams = [System.Web.HttpUtility]::UrlDecode($renderingInstance.Parameters)
                $updatedParams = $decodedParams

                # Update Rendering Variant
                if ($decodedParams -match "FieldNames=({.+?})") {
                    $renderingVariantId = $Matches[1]
                    if ($renderingVariantId) {
                        $variantDestination = "/sitecore/content/$($global:destinationNodePath)/Presentation/Headless Variants"
            
                        # New path format, dynamically replacing the matched path with the new base path up to "/Presentation/Styles"
                  

                        #  Write-Host "rendering variant Id: " $renderingVariantId
                        $renderingVariantItem = Get-Item -Path "master:" -ID $renderingVariantId -ErrorAction SilentlyContinue

                        # Assuming function Remap-DestinationPath is defined to remap paths
                        $newRenderingVariantPath = $variantDestination + "/$($renderingVariantItem.Parent.Name)/$($renderingVariantItem.Name)"
                        #  Write-Host "rendering variant path: " $newRenderingVariantPath

                        $newRenderingVariant = Get-Item -Path "master:$newRenderingVariantPath"  -ErrorAction SilentlyContinue
                        if ($newRenderingVariant) {
                            $updatedParams = $updatedParams -replace $renderingVariantId, $newRenderingVariant.ID
                            # Write-Host "src rendering variant ID : "$renderingVariantId
                            # Write-Host "new rendering variant ID : "$newRenderingVariant.ID
                            # Write-Host "src Params: " $decodedParams 

                            # Write-Host "updated Params: " $updatedParams 
                        }
                    }
                }

                ##   Update Styles
                if ($decodedParams -match "Styles=([^&]+)") {
                    $stylesParam = $Matches[1] -split '\|'
                    # Regular expression to dynamically match the entire path up to "/Presentation/Styles"
                    $regex = "/sitecore/content/([^/]+)/([^/]+)/Presentation/Styles"
            
                    if ($stylesParam) {
                    
                        foreach ($guid in $stylesParam) {
                            $styleItem = Get-Item -Path "master:" -ID $guid -ErrorAction SilentlyContinue
                            if ($styleItem) {
                                # New path format, dynamically replacing the matched path with the new base path up to "/Presentation/Styles"
                                $newStylePath = $styleItem.Paths.FullPath -replace $regex, "/sitecore/content/$($global:destinationNodePath)/Presentation/Styles"
                                $newStyleItem = Get-Item -Path "master:$newStylePath" -ErrorAction SilentlyContinue
                                if ($newStyleItem) {
                                    $updatedParams = $updatedParams -replace $styleItem.ID, $newStyleItem.ID

                                }
                            }
                        }

                    }
                }

                # Update the rendering instance parameters
                $newEncodedParams = [System.Web.HttpUtility]::UrlEncode($updatedParams)
                # Write-Host "src Params: " $decodedParams 

                # Write-Host "updated Params: " $updatedParams 
                # Write-Host "SRC encoded Params: "$renderingInstance.Parameters

                # Write-Host "New encoded Params: "$newEncodedParams
                $renderingInstance.Parameters = [System.Web.HttpUtility]::UrlEncode($updatedParams)



                # Get the current rendering item
                $currentRenderingItem = Get-Item -Path "master:" -ID $renderingInstance.ItemID
    
                if (IsOOTBItem -itemPath $currentRenderingItem.FullPath) {
                    $headlessRenderingName = $currentRenderingItem.Name -replace " ", ""
                    Write-Host  $headlessRenderingName
                    $newRenderingItemPath = Check-Existing-HeadlessSXAItem -ItemLocation $currentRenderingItem.Parent.Paths.Path -ItemName $headlessRenderingName
                    if (-not $newRenderingItemPath) {
                        $newRenderingItemPath = Find-TemplateOrRenderingInFolder -itemName $currentRenderingItem.Name -folderPath "/sitecore/layout/Renderings/Project/$($global:destinationNodePath)"
                        # Write-Host "Check isOOTBItem -> Find-TemplateOrRenderingInFolder function"


                    }
                    else {
                        $newRenderingItemPath = "$newRenderingItemPath/$headlessRenderingName"
                        # Write-Host "Check Check-Existing-HeadlessSXAItem function"

                    }
                   
                }
                else {
                    $newRenderingItemPath = Remap-DestinationPath -sourcePath $currentRenderingItem.Paths.FullPath
                    #   Write-Host  "New Rendering Path after Remapping" $newRenderingItemPath

                    if ($newRenderingItemPath -eq "/sitecore/layout/Renderings/Project/$global:destinationNodePath/") {
                        $newRenderingItemPath = Find-TemplateOrRenderingInFolder -itemName $currentRenderingItem.Name -folderPath "/sitecore/layout/Renderings/Project/$($global:destinationNodePath)"
                        #     Write-Host "Check Find-TemplateOrRenderingInFolder function"

                    }

                }


                # Remap rendering item
                $newRenderingItem = Get-Item -Path "master:$newRenderingItemPath"

                Write-Host  "Old Rendering Path" $currentRenderingItem.Paths.Path
                Write-Host  "New Rendering Path" $newRenderingItemPath

                if ($renderingInstance.ItemID -ne $newRenderingItem.Id) {
                    $renderingInstance.ItemID = $newRenderingItem.Id
                }
                                                      
                if ($isFinalLayout) {
                    Set-Rendering -Item $item -Instance $renderingInstance -FinalLayout

                }
                else {
                    Set-Rendering -Item $item -Instance $renderingInstance 

                }
                
                
 
            
            }
        }
    
        # Update Final Layout Renderings
        if ($item.Fields["__Final Renderings"]) {
            Update-RenderingsForLayoutType -item $item -isFinalLayout $true
        }
    
        # Update Shared Layout Renderings
        if ($item.Fields["__Renderings"]) {
            Update-RenderingsForLayoutType -item $item -isFinalLayout $false
        }
    
        Write-Host "Renderings and Datasources updated for item: $itemPath"
    }
    catch {
        Write-Host "Error updating renderings for item: $itemPath. Error: $($_.Exception.Message)"
        $global:itemsFailed++
    }
}
    
    
function Update-Layouts {
    param (
        [Parameter(Mandatory = $true)][string]$itemPath
    )
    if (-not $itemPath) {
        Write-Host "No Item path provided."
        return
    }

    $device = Get-LayoutDevice -Default
    $item = Get-Item -Path "master:$itemPath" -ErrorAction SilentlyContinue
    $jsonDevice = Get-LayoutDevice -Name "JSON"

    if ($item) {
        $layout = Get-Layout -Item $item
        if ($layout) {
            $newLayoutPath = Remap-DestinationPath -sourcePath $layout.Paths.FullPath
            Write-Host "New Layout Path" $newLayoutPath
            $newLayoutItem = Get-Item -Path "master:$newLayoutPath" -ErrorAction SilentlyContinue
            $newLayoutItemTemplateId = Get-Item -Path "master:$($newLayoutItem.TemplateId)"
            if ( $newLayoutItemTemplateId.Id -ne "{E4E11508-04A4-4B0B-A263-5201F811C9CD}" ) {
                $newLayoutItem = $global:GenericHeadlessLayout
                Write-Host "using Headless Layout Path" $global:GenericHeadlessLayout.FullPath

            } 

            Set-Layout -Item $item -Device $device -Layout $newLayoutItem | Out-Null
            Remove-Layout -Item $item -Device $jsonDevice -FinalLayout
            Remove-Layout -Item $item -Device $jsonDevice

            Write-Host "Updated layout for item: $itemPath"
                    


        }
    }
    else {
        Write-Host "Item not found at path: $itemPath"
    }
}
    
function Copy-ContentItems {
    param (
        [Parameter(Mandatory = $true)][array]$PathsToCopy,
        [Parameter(Mandatory = $true)][string]$CopyDestination
    )
    # Check if PathsToCopy is null or empty
    if (-not $PathsToCopy -or $PathsToCopy.Count -eq 0) {
        Write-Host "No paths provided to copy."
        return
    }

    # Check if CopyDestination is null or empty
    if (-not $CopyDestination) {
        Write-Host "No destination path provided."
        return
    }
    foreach ($path in $PathsToCopy) {
        try {
            $sourcePath = "master:$path"
            $destinationPath = Remap-DestinationPath -sourcePath $sourcePath
            $existingItem = Get-Item -Path $destinationPath -ErrorAction SilentlyContinue
            Write-Host "destination path:" $destinationPath
                        

            if (-not $existingItem) {
                $newContentItems = Copy-Item -Path $sourcePath -Destination $CopyDestination -Recurse -PassThru 
                Write-Host  "Getting child items of new content items:" $newContentItems.FullPath
                Get-ChildItem -Path  $newContentItems.FullPath -Recurse | ForEach-Object {
                    $global:itemsCopied++
                }            
            } 
            else {
                $global:itemsExisting++
            }
        }
        catch {
            $global:itemsFailed++
            Write-Host "Failed to copy item at path $path : $($_.Exception.Message)"
        }
    }
}

  
 
function Update-CopiedContentItemFields {
    param (
        [Parameter(Mandatory = $true)][string]$ContentItemPath
    )
    if (-not $ContentItemPath) {
        Write-Host "No ContentItem path provided."
        return
    }

    try {
        $item = Get-Item -Path "master:$ContentItemPath" -ErrorAction SilentlyContinue
        if ($item) {
            # Get and remap the old template path
            
            $sourceTemplateItem = Get-Item -Path "master:/" -ID $item.Template.ID -ErrorAction SilentlyContinue



            if (IsOOTBItem -templatePath $sourceTemplateItem.FullPath) {
                $newTemplateItem = Check-Existing-HeadlessSXAItem -ItemLocation $sourceTemplateItem.FullPath -ItemName $sourceTemplateItem.Name
                if (-not $newTemplateItem) {
                    $newTemplateItem = Get-NewTemplatePathForOOBItems -templateItem $sourceTemplateItem
                    $newTemplateItem += "/" + $sourceTemplateItem.Name
                }
            }
            else {
                #$newTemplateItem = Remap-DestinationPath -sourcePath $sourceTemplateItem.FullPath
                $newTemplateItem = Find-TemplateOrRenderingInFolder -itemName $sourceTemplateItem.Name -folderPath "/sitecore/templates/Project/$($global:destinationNodePath)"
                
            }

            $newContentItemPath = Remap-DestinationPath -sourcePath $item.Paths.FullPath
            Write-Host "New content Item: "$newContentItemPath
            $newContentItem = Get-Item -Path "master:$newContentItemPath" -ErrorAction SilentlyContinue         
           

            # Update the item template
            if ($newTemplateItem) {
                Set-ItemTemplate -Item $newContentItem -Template $newTemplateItem -ErrorAction SilentlyContinue
                $newTemplate = Get-Item -Path $newTemplateItem -ErrorAction SilentlyContinue

            }
            
            #Copy the values from the old item to the new item
            $newContentItem.Editing.BeginEdit()
            
            # Copy field values from old item to new item
            foreach ($field in $item.Fields) {
                # Check if the new item has a field with the same name
                if (!$field.InnerItem.Paths.FullPath.StartsWith("/sitecore/templates/system", 'CurrentCultureIgnoreCase')) {

                    # Ensure the new item actually contains the field
                    if ($newContentItem.Fields[$field.Name] -and ![string]::IsNullOrEmpty($field.Value)) {
                        # Use safe method to update field value
                        $newContentItem.Fields[$field.Name].Value = $field.Value
                    }
                }
            }

            $newContentItem.Editing.EndEdit()



  
            # Update renderings and layouts

            if (IsPageTemplate -templateItem $newTemplate ) {
                Write-Host "Page type: " $newContentItem.Name
                Update-Renderings -itemPath $newContentItem.Paths.FullPath
                Update-Layouts -itemPath $newContentItem.Paths.FullPath
            }

            # Update link fields
            #    Update-LinkFields -ContentItem $newContentItem

        }
    }
    catch {
        Write-Host "Failed to update item at path $path : $($_.Exception.Message)"
    }
    
}
function Find-TemplateOrRenderingInFolder {
    param (
        [Parameter(Mandatory = $true)][string]$itemName,
        [Parameter(Mandatory = $true)][string]$folderPath
    )

    # Ensure the path is valid for templates and renderings
    if (-not $folderPath.StartsWith("/sitecore/templates") -and -not $folderPath.StartsWith("/sitecore/layout")) {
        Write-Error "The folder path must start with '/sitecore/templates' or '/sitecore/layout'."
        return
    }

    # Get the folder item
    $folderItem = Get-Item -Path "master:$folderPath"
    if (-not $folderItem) {
        Write-Error "Folder not found: $folderPath"
        return
    }

    # Search for the item by name within the folder, considering both templates and renderings
    $items = Get-ChildItem -Path "master:$folderPath" -Recurse | Where-Object {
        ($_.TemplateName -eq "Template" -or $_.TemplateName -eq "Json Rendering" -or $_.TemplateName -eq "Sublayout") -and $_.Name -eq $itemName
    } | Sort-Object { $_.Paths.FullPath.Length } -Descending

    # Select the last item based on the sort order
    $lastItem = $items | Select-Object -Last 1

    if ($lastItem) {
        Write-Host "Item found: $($lastItem.FullPath)"
        return $lastItem.FullPath
    }
    else {
        Write-Host "Item '$itemName' not found in '$folderPath'."
    }
}


function Copy-StyleItemsToNewPath {
    param (
        [Parameter(Mandatory = $true)][string]$styleId
    )

    $styleItem = Get-Item -Path "master:/" -ID $styleId -ErrorAction SilentlyContinue
    if ($styleItem) {
        try {

            # Regular expression to dynamically match the entire path up to "/Presentation/Styles"
            $regex = "/sitecore/content/([^/]+)/([^/]+)/Presentation/Styles"
            
            # New path format, dynamically replacing the matched path with the new base path up to "/Presentation/Styles"
            $newStylePath = $styleItem.Parent.Paths.FullPath -replace $regex, "/sitecore/content/$($global:destinationNodePath)/Presentation/Styles"
           
            
            $existingStyleItem = Get-Item -Path "$newStylePath/$($styleItem.Name)" -ErrorAction SilentlyContinue
            if ($existingStyleItem) {
                # Style item already exists at the destination, no need to copy
                Write-Host "Style item already exists at the new path: $newStylePath/$($styleItem.Name)"
                $global:itemsExisting++
            }
            else {
                # Ensure the folder exists at the new path before copying
                Ensure-Folder -Path $newStylePath -Type $styleItem.Parent.Template.FullName
                
                # Copy the style item to the new path
                $copiedStyleItem = Copy-Item -Path $styleItem.ItemPath -Destination $newStylePath -PassThru -ErrorAction SilentlyContinue
                if ($copiedStyleItem) {
                    Write-Host "Successfully copied style item to: $newStylePath/$($styleItem.Name)"
                    $global:itemsCopied++
                }
                else {
                    throw "Failed to copy style item to: $newStylePath/$($styleItem.Name)"
                }
            }
        }
        catch {
            Write-Host "Error occurred while copying style item: $styleId. Error: $($_.Exception.Message)"
            $global:itemsFailed++
        }
    }
    else {
        Write-Host "Style item with ID $styleId does not exist."
    }
}

function Migrate-Variants {
    param (
        [Parameter(Mandatory = $true)][string]$variantId
    )

    # Use global variables for template paths and counters
    $destinationPath = "/sitecore/content/$($global:destinationNodePath)/Presentation/Headless Variants"
    $headlessVariantsTemplatePath = $global:headlessVariantTemplatePath
    $variantDefinitionTemplatePath = $global:headlessVariantTemplateDefinitionPath

    # Ensure the destination folder exists
    Ensure-Folder -Path $destinationPath

    # Migrate the variant parent
    $variantItem = Get-Item -Path "master:/" -ID $variantId
    $variantParentItem = $variantItem.Parent
    $newVariantParentPath = $destinationPath + "/" + $variantParentItem.Name
    Write-Host "Parent Path: " $newVariantParentPath
    # Check if variant parent already exists at the destination
    $existingVariantParent = Get-Item -Path "master:$newVariantParentPath" -ErrorAction SilentlyContinue
    if (-not $existingVariantParent) {
        try {
            $newVariantParent = Copy-Item -Path $variantParentItem.Paths.FullPath -Destination $destinationPath -PassThru
            # Change the template of the variant parent
           
            Set-ItemTemplate -Item $newVariantParent -Template $headlessVariantsTemplatePath
            $global:itemsCopied++
        }
        catch {
            $global:itemsFailed++
            Write-Host "Failed to copy variant parent: $variantParentId"
        }
    }
    else {
        $global:itemsExisting++
    }

    # Migrate the variant
    $newVariantPath = $newVariantParentPath + "/" + $variantItem.Name

    # Check if variant already exists under the new parent
    $existingVariant = Get-Item -Path "master:$newVariantPath" -ErrorAction SilentlyContinue
    if (-not $existingVariant) {
        try {
            $newVariant = Copy-Item -Path $variantItem.Paths.FullPath -Destination $newVariantParentPath -PassThru
            # Change the template of the variant
            Set-ItemTemplate -Item $newVariant -Template $variantDefinitionTemplatePath
            $global:itemsCopied++
        }
        catch {
            $global:itemsFailed++
            Write-Host "Failed to copy variant: $variantId"
        }
    }
    else {
        $global:itemsExisting++
    }
}


    



#********************************************Main Code Block***************************************************

New-UsingBlock (New-Object Sitecore.Data.BulkUpdateContext) {
    Set-Location -Path "master:/"

    # Code to select the CSV file which needs to be imported
    $finalFileImportPath = "";
    
    $parameters = @(
        @{ Name = "sourceNode"; Title = "Source Website Node"; Tooltip = "Enter the source website node"; Editor = "droptree"; DefaultValue = "sitecore/content/TXU/Shopping" },
        @{ Name = "destinationNode"; Title = "Destination Website Node"; Tooltip = "Enter the destination website node"; Editor = "droptree"; DefaultValue = "sitecore/content/shopping/txushopping" },
        @{ Name = "importFileFolder"; Title = "CSV File Location"; Source = "Datasource=/sitecore/media library/"; Mandatory = $true; Editor = "droptree" ; DefaultValue = "/Sitecore/Media Library/Files/txushopping"},
        @{ Name = "sourceMediaLibrary"; Title = "Source Media Library Folder"; Source = "Datasource=/sitecore/media library/"; Tooltip = "Enter the source media library folder"; Editor = "droptree"; DefaultValue = "/sitecore/media library/Project/TXU/Shopping" },
        @{ Name = "destinationMediaLibrary"; Title = "Destination Media Library Folder"; Source = "Datasource=/sitecore/media library/"; Tooltip = "Enter the destination media library folder"; Editor = "droptree"; DefaultValue = "/sitecore/media library/Project/shopping/txushopping" }
    )
    
    $result = Read-Variable -Parameters $parameters -Description "Select source, destination node and CSV file." -Title "Configuration" -Width 500 -Height 500 -OkButtonName "Proceed" -CancelButtonName "Cancel" -ShowHints

    if ($result -eq "cancel") {
        Write-Host "Pleases select source, destination node and CSV file." 
        Exit
    }
    else {
        
        $global:sourceNodePath = $sourceNode.Parent.Name + "/" + $sourceNode.Name
        $global:destinationNodePath = $destinationNode.Parent.Name + "/" + $destinationNode.Name

        $global:sourceNodeTenantName = $sourceNode.Parent.Name
        $global:destinationNodeTenantName = $destinationNode.Parent.Name

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
    
    
   
    
    <# # Process CSV data
    $uniqueLayouts = $csv | Select-Object "CurrentItem-Layout-ItemPath" -Unique
    $uniqueLayouts
    foreach ($layout in $uniqueLayouts) {
        if ($layout."CurrentItem-Layout-ItemPath") {
            $layout."CurrentItem-Layout-ItemPath"
            $layoutItem = Get-Item -Path $layout."CurrentItem-Layout-ItemPath"
            Write-Host "Layout Path: " $layoutItem.FullPath
            # Call the function to migrate layout items
            #If layout is OOB, create a generic layout instead
            if (-not (IsOOTBItem -itemPath $layoutItem.FullPath)) {
                Migrate-LayoutItems -layoutItemPath $layoutItem.FullPath
            }
            else {
                if (-not $global:GenericHeadlessLayout) {
                    Create-GenericHeadlessLayout -sourceLayoutItemPath $global:defaultHeadlessLayoutPath
                }
                else {
                    Write-Host "Generic Layout already created"
                }
            }
            
            
        }
    } #>

<#      # #Process Placeholders used in pages or content items.
    $groupedPlaceholders = $csv | Group-Object "CurrentItem-Layout-ItemId"
    Manage-PlaceholdersFromCsv -groupedPlaceholders $groupedPlaceholders
 #>
    #process Unique renderings used in pages 
    $uniqueRenderings = $csv | Select-Object "CurrentItem-Rendering-ItemId" -Unique
    foreach ($rendering in $uniqueRenderings) {
        if ($rendering."CurrentItem-Rendering-ItemId") {
            $renderingItemId = $rendering."CurrentItem-Rendering-ItemId"
            
            if ($renderingItemId) {
                $renderingItem = Get-Item -Path "master:$renderingItemId"
                $renderingName = $renderingItem.Name -replace " ", ""
                if ($renderingItem) {
                    if (-not (Check-Existing-HeadlessSXAItem -ItemLocation $renderingItem.Parent.Paths.Path -ItemName $renderingName)) {
                        Migrate-RenderingItems -renderingItemId $renderingItemId
                    }
                }           

            }
            
        }
    }

    $uniqueTemplates = $csv | Select-Object "CurrentItem-CreatedWith-TemplateId" -Unique
    
    foreach ($itemTemplate in $uniqueTemplates) {
        if ($itemTemplate."CurrentItem-CreatedWith-TemplateId") {
            $itemTemplateId = $itemTemplate."CurrentItem-CreatedWith-TemplateId"
            $templateItem = Get-Item -Path "master:/" -ID $itemTemplateId
            try {

                if (IsOOTBItem -templatePath $templateItem.FullPath) {
                    $newTemplatePath = Check-Existing-HeadlessSXAItem -ItemLocation $templateItem.Parent.Paths.Path -ItemName $templateItem.Name
                    if (-not $newTemplatePath) {
                        $newTemplatePath = Get-NewTemplatePathForOOBItems -templateItem $templateItem
                    }
                   
                }
                else {
                    $newTemplatePath = Remap-DestinationPath -sourcePath  $templateItem.Parent.Paths.FullPath
    
                }

                # Check if the item already exists at the destination
                $existingItem = Get-Item -Path "$newTemplatePath/$($templateItem.Name)" -ErrorAction SilentlyContinue
                if ($existingItem -ne $null) {
                    # If the item exists, use the existing item
                    $newTemplateItem = $existingItem
                }
                else {
                    # If the item does not exist, proceed to copy
                    Copy-TemplateRecursively -templatePath $templateItem.ItemPath -newTemplatePath $newTemplatePath
                    $newTemplateItem = Get-Item -Path "$newTemplatePath/$($templateItem.Name)" -ErrorAction SilentlyContinue

                }
            }
            catch {
                    
                $global:itemsFailed++
                Write-Host "Failed to copy item: $($_.Exception.Message)"
                    
            }
            
        }
    }


    
   <# $uniqueStyles = $csv | Select-Object "CurrentItem-Rendering-StyleId" -Unique
    
    foreach ($style in $uniqueStyles) {
        if ($style."CurrentItem-Rendering-StyleId") {
            $styleId = $style."CurrentItem-Rendering-StyleId"
            Copy-StyleItemsToNewPath -styleId $styleId

        }
   
    }


    #Copy Rendering Variants

    $uniqueVariants = $csv | Select-Object "CurrentItem-Rendering-Rendering-VariantName", "CurrentItem-Rendering-Rendering-VariantId" -Unique

    foreach ($variant in $uniqueVariants) {
        if ($variant."CurrentItem-Rendering-Rendering-VariantId") {
            $variantId = $variant."CurrentItem-Rendering-Rendering-VariantId"
            Migrate-Variants -variantId $variantId
        }
    }


    #Copy media library to new media

   
    $mediaFolders = Get-ChildItem -Path $sourceMediaLibrary.Fullpath
        
    foreach ($mediaFolder in $mediaFolders) {
        try {
            if (Get-Item -Path "$($destinationMediaLibrary.FullPath)/$($mediaFolder.Name)") {
                Write-Host "Media Folder - $($mediaFolder.Name) already exists"
            }
            else {
                $newMediaLibrary = Copy-Item -Path $mediaFolder.FullPath -Destination $destinationMediaLibrary.FullPath -Recurse -PassThru

                # Increment the counter for each item copied
                Get-ChildItem -Path  $mediaFolder.FullPath -Recurse | ForEach-Object {
                    $global:itemsCopied++
                }

                Write-Host "Copied - $($newMediaLibrary.ItemPath)"
            
            }
            
       
        }
        catch {
                    
            $global:itemsFailed++
            Write-Host "Failed to copy item: $($_.Exception.Message)"
            
        }
    }



    # #Copy Data items
    $uniqueDataSources = $csv | Select-Object "CurrentItem-Rendering-Datasource-Path" -Unique


    foreach ($dataSource in $uniqueDataSources) {
        if ($dataSource."CurrentItem-Rendering-Datasource-Path") {
            $dataSourcePath = $dataSource."CurrentItem-Rendering-Datasource-Path"
            if ($dataSourcePath -match "/sitecore/content/") {               
                $sourceData = Get-Item -Path $dataSourcePath -ErrorAction SilentlyContinue
                Write-Host " datasource: " $sourceData.FullPath

                if ($sourceData) {
                    # Regular expression to match the dynamic parts of the path
                    $regex = "/sitecore/content/([^/]+)/([^/]+)/Data"
                    
                    # Replace the matched segments with the new combined tenant and site name, keeping the static parts of the path
                    $newDataSourcePath = $sourceData.Parent.Paths.FullPath -replace $regex, "/sitecore/content/$($global:destinationNodePath)/Data"
    
                    $existingItem = Get-Item -Path "$newDataSourcePath/$($sourceData.Name)" -ErrorAction SilentlyContinue
                    if (-not $existingItem) {
                        try {
                            Ensure-Folder -Path $newDataSourcePath -Type $sourceData.Parent.Template.FullName
                            $newDataItem = Copy-Item -Path $sourceData.Paths.FullPath -Destination $newDataSourcePath -PassThru -ErrorAction SilentlyContinue
                            Write-Host "Created datasource: " $newDataItem.FullPath
                            $global:itemsCopied++
                        }
                        catch {
                            Write-Host "Failed to copy item: $dataSourcePath. Error: $($_.Exception.Message)"
                            $global:itemsFailed++
                        }
                    }
                    else {
                        $global:itemsExisting++
                    }


                    $templateItem = Get-Item -Path "master:/" -ID $sourceData.Parent.TemplateID
                    Write-Host "template Item : "$templateItem.FullPath

                    try {

                        if (IsOOTBItem -templatePath $templateItem.FullPath) {
                            $newTemplatePath = Check-Existing-HeadlessSXAItem -ItemLocation $templateItem.Parent.Paths.Path -ItemName $templateItem.Name
                            if (-not $newTemplatePath) {
                                $newTemplatePath = Get-NewTemplatePathForOOBItems -templateItem $templateItem
                            }
                                       
                        }
                        else {
                            $newTemplatePath = Remap-DestinationPath -sourcePath  $templateItem.Parent.Paths.FullPath
                        
                        }
                        Write-Host "new Template Path datasource : "$newTemplatePath
                        # Check if the item already exists at the destination
                        Write-Host "Existing Item: " "$newTemplatePath/$($templateItem.Name)"
                        $existingItem = Get-Item -Path "$newTemplatePath/$($templateItem.Name)" -ErrorAction SilentlyContinue
                        if ($existingItem) {
                            # If the item exists, use the existing item
                            $newTemplateItem = $existingItem
                            Write-Host "Using Existing Item: " $existingItem.FullPath
                        }
                        else {
                            # If the item does not exist, proceed to copy
                            Copy-TemplateRecursively -templatePath $templateItem.FullPath -newTemplatePath $newTemplatePath
                            $newTemplateItem = Get-Item -Path "$newTemplatePath/$($templateItem.Name)" -ErrorAction SilentlyContinue
                    
                        }
                    }
                    catch {
                                        
                        $global:itemsFailed++
                        Write-Host "Failed to copy item: $($_.Exception.Message)"
                                        
                    }


                }
            }
        }
    }

    #updating Datasource Items
    Get-ChildItem -Path "/sitecore/content/$($global:destinationNodePath)/Data" -Recurse | ForEach-Object {
        Write-Host "Updating content item : "$_.FullPath
        Update-CopiedContentItemFields -ContentItemPath $_.FullPath }        
                

    
    #Copy Content items
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

    # Copy content items/Page designs/Partial Designs to the new site
    
    foreach ($filteredPath in $filteredPaths) {
        if ($filteredPath -like "*/Presentation/Page Designs") {
            $itemChildren = Get-ChildItem -Path $filteredPath
            foreach ($child in $itemChildren) {
                $pageDesignDestinationNode = "$($destinationNode.FullPath)/Presentation/Page Designs"
                Copy-ContentItems -PathsToCopy $child.FullPath -CopyDestination $pageDesignDestinationNode

                #Update Renderings/Layout/Link type field values of the item

                Get-ChildItem -Path $filteredPath -Recurse -WithParent | ForEach-Object {
                    Write-Host "Updating content item : "$_.FullPath
                    Update-CopiedContentItemFields -ContentItemPath $_.FullPath }        
            }
        }

        elseif ($filteredPath -like "*/Presentation/Partial Designs") {
            $itemChildren = Get-ChildItem -Path $filteredPath
            foreach ($child in $itemChildren) {
                $partialDesignDestinationNode = "$($destinationNode.FullPath)/Presentation/Partial Designs"

                Copy-ContentItems -PathsToCopy $child.FullPath -CopyDestination $partialDesignDestinationNode

                #   Update Renderings/Layout/Link type field values of the item

                Get-ChildItem -Path $filteredPath -Recurse -WithParent | ForEach-Object {
                    Write-Host "Updating content item : "$_.FullPath
                    Update-CopiedContentItemFields -ContentItemPath $_.FullPath
                     
                }
            }

        }
        else {
            Copy-ContentItems -PathsToCopy $filteredPath -CopyDestination $destinationNode.FullPath
                
            ##  Update Renderings/Layout/Link type field values of the item

            Get-ChildItem -Path $filteredPath -Recurse -WithParent | ForEach-Object {
                Write-Host "Updating content item : "$_.FullPath
                Update-CopiedContentItemFields -ContentItemPath $_.FullPath
                 
            }
        }

        
    }
 #>


    #Create a list of data
    $migrationResults = @(
        @{Name = "Items Copied"; Value = $global:itemsCopied },
        @{Name = "Items Existing"; Value = $global:itemsExisting },
        @{Name = "Items Failed"; Value = $global:itemsFailed }
    )

    $migrationResults | Show-ListView -Property @{Label = "Statistic"; Expression = { $_.Name } }, @{Label = "Count"; Expression = { $_.Value } } -Title "Operation Summary"


}




