
# Function to retrieve sources of fields from a given template item.

function Get-TemplateFieldSources {
    param([string]$ItemPath, [string]$database)
 
    $templateFields = @()   
    # Retrieve the template of the specified item.
    $templateItem = Get-ItemTemplate -Path "$($database):$ItemPath"
    # Iterate over each base template of the item template.

    foreach ($template in $templateItem.BaseTemplates) {
        $templateFields += @{
            "Template ID"        = $templateItem.ID
            "Template Name"      = $templateItem.Name
            "Template Path"      = $templateItem.FullName
            "Base Template ID"   = $template.ID
            "Base Template Name" = $template.DisplayName
            "Base Template Path" = $template.FullName
            "Field Name"         = ""
            "Source"             = ""
        }
        # Iterate over each field in the base template.

        foreach ($field in $template.Fields) {
            # Add a record for each field with a source and exclude standard fields. 

         
            if ((![string]::IsNullOrWhiteSpace($field.Source)) -and (!$field.InnerItem.Paths.FullPath.StartsWith("/sitecore/templates/system", 'CurrentCultureIgnoreCase'))) {
                $templateFields += @{
                    "Template ID"        = $templateItem.ID
                    "Template Name"      = $templateItem.Name
                    "Template Path"      = $templateItem.FullName
                    "Base Template ID"   = $template.ID
                    "Base Template Name" = $template.DisplayName
                    "Base Template Path" = $template.FullName
                    "Field Name"         = $field.Name
                    "Source"             = $field.Source
                    "Field ID"           = $field.ID
                }
            }
        }
    }
    return $templateFields
}      

# Function to check if an item is an Out-Of-The-Box (OOTB) item based on its path.

function IsOOTBItem {
    param([string]$path)
    # Define OOTB namespaces for Sitecore and SXA
    $ootbNamespaces = @("/sitecore/templates/System", 
        "/sitecore/templates/Feature/Experience Accelerator",
        "/sitecore/templates/Feature/JSS Experience Accelerator",
        "/sitecore/templates/Foundation/Experience Accelerator",
        "/sitecore/templates/Foundation/JSS Experience Accelerator",
        "/sitecore/templates/Foundation/JavaScript Services",
        "/sitecore/templates/Modules",
        "/sitecore/templates/Common")

    # Check if the path starts with any of the OOTB namespaces.

    foreach ($ns in $ootbNamespaces) {
        if ($path.StartsWith($ns)) {
            return $true
        }
    }
    return $false
}

# Function to retrieve rendering information from an item.

function Get-ItemRenderings {
    param([Sitecore.Data.Items.Item]$item, [string]$database)
    Set-Location -Path "$($database):/"

    $renderingInstances = Get-Rendering -Id $item.ID -Database $database -FinalLayout
    $renderingNames = @()

    foreach ($renderingInstance in $renderingInstances) {
        $renderingItem = Get-Item -Path "$($database):" -ID $renderingInstance.ItemID
        $dataSourcePath = ""
        if ([Sitecore.Data.ID]::IsID($renderingInstance.Datasource)) {
            $dataSourceItem = Get-Item -Path "$($database):" -ID $renderingInstance.Datasource
            $dataSourcePath = $dataSourceItem.FullPath
        }
        else {
            $dataSourcePath = $renderingInstance.Datasource
        }

        # Decode parameters and get rendering variant and styles
        $decodedParams = [System.Web.HttpUtility]::UrlDecode($renderingInstance.Parameters)
        $styleItems = @()
        $renderingVariantItem = ""
        if ($decodedParams -match "FieldNames=({.+?})") {
            $renderingVariantId = $Matches[1] -replace "%7B", "{" -replace "%7D", "}"
            $renderingVariantItem = Get-Item -Path "master:" -ID $renderingVariantId

        }
        if ($decodedParams -match "Styles=([^&]+)") {
            $stylesParam = $Matches[1] -replace "%7B", "{" -replace "%7D", "}" -split '\|'
            foreach ($guid in $stylesParam) {
                $styleItem = Get-Item -Path "master:" -ID $guid -ErrorAction SilentlyContinue
                if ($styleItem -ne $null) {
                    $styleItems += $styleItem
                }
            }
        }

        # Add rendering details along with the variant and styles to the list
        if ($renderingItem -ne $null) {
            if ($styleItems) {
                foreach ($style in $styleItems) {
                    $renderingNames += @{
                        "Rendering Name"                = $renderingItem.DisplayName
                        "Rendering ID"                  = $renderingInstance.ItemID
                        "Rendering Template Name"       = $renderingItem.TemplateName
                        "Rendering Owner Path"          = $renderingInstance.OwnerItemPath
                        "Rendering Owner ID"            = ($renderingInstance.OwnerItemId -replace "{{", "{") -replace "}}", "}"
                        "Placeholder"                   = $renderingInstance.Placeholder
                        "Datasource ID"                 = $renderingInstance.Datasource
                        "Datasource Path"               = $dataSourcePath
                        "Rendering Parameters Template" = $renderingItem.Fields["Parameters Template"].Value
                        "Rendering Datasource Location" = $renderingItem.Fields["Datasource Location"].Value
                        "Rendering Datasource Template" = $renderingItem.Fields["Datasource Template"].Value
                        "Rendering Variant Name"        = $renderingVariantItem.Name
                        "Rendering Variant Id"          = $renderingVariantItem.Id
                        "Rendering Style Id"            = $style.Id
                        "Rendering Style Name"          = $style.Name
                    } 
                    Write-Host "Variant Name:" $renderingVariantItem.Name
                    Write-Host "Style Name:" $style.Name

                }
            }
            
            else {
                $renderingNames += @{
                    "Rendering Name"                = $renderingItem.DisplayName
                    "Rendering ID"                  = $renderingInstance.ItemID
                    "Rendering Template Name"       = $renderingItem.TemplateName
                    "Rendering Owner Path"          = $renderingInstance.OwnerItemPath
                    "Rendering Owner ID"            = ($renderingInstance.OwnerItemId -replace "{{", "{") -replace "}}", "}"
                    "Placeholder"                   = $renderingInstance.Placeholder
                    "Datasource ID"                 = $renderingInstance.Datasource
                    "Datasource Path"               = $dataSourcePath
                    "Rendering Parameters Template" = $renderingItem.Fields["Parameters Template"].Value
                    "Rendering Datasource Location" = $renderingItem.Fields["Datasource Location"].Value
                    "Rendering Datasource Template" = $renderingItem.Fields["Datasource Template"].Value
                }
            }
            
        }
    }
    return $renderingNames
}


# Function to get base template names for a given template item.

function Get-BaseTemplateFieldValues {
    param([Sitecore.Data.Items.Item]$templateItem, [string]$database)
    # Split the base template IDs and retrieve their names.
    $baseTemplateIds = $templateItem.Fields["__Base template"].Value -split '\|'
    $baseTemplateNames = @()
    if ($baseTemplateIds) {
        foreach ($id in $baseTemplateIds) {
            if (![string]::IsNullOrWhiteSpace($id)) {
                $baseTemplateItem = Get-Item -Path "$($database):" -ID $id -ErrorAction SilentlyContinue
                if ($baseTemplateItem -ne $null) {
                    $baseTemplateNames += $baseTemplateItem.DisplayName
                }
            }
        }
    }
    return $baseTemplateNames -join ", "
}


# Main function to get MVC site items and their related information.
function Get-MvcSiteItems {
    param(
        [string]$path,
        [string]$database = "master"
    )
    # Retrieve all child items under the specified path.
    $items = Get-ChildItem -Path "$($database):$path" -Recurse -WithParent
    $siteItems = @()
    foreach ($item in $items) {
        # Get rendering information for the item.
        $renderings = Get-ItemRenderings -item $item -database $database
        # Retrieve the item's template and layout.
        $templateItem = Get-Item -Path "$($database):" -ID $item.TemplateID
        $device = Get-LayoutDevice -Default 
        $layoutItem = Get-Layout -Id $item.Id -Device $device -ErrorAction SilentlyContinue
        # Get base template field values and template field sources.
        $baseTemplateFieldValues = Get-BaseTemplateFieldValues -templateItem $templateItem -database $database
        $templateFieldSources = Get-TemplateFieldSources -database $database -ItemPath $item.FullPath
        $templateFields = Get-TemplateFieldSources -database $database -ItemPath $item.FullPath
        
        # Determine if the item has a final layout.
        $isFinalLayout = $false

        #Check If there are renderings in the item.
        if ($item.Fields["__Final Renderings"].Value -ne "") {
            $isFinalLayout = $true
        }
      

        $itemType = ""
        #Check if item is under CONTENT item.
        if ($item.FullPath.StartsWith("/sitecore/content")) {
            $itemType = "ContentItem"
        }
        
        
        
        #add each item details from the list and iterate renderings and templates to get all the needed data.
    
        if ($renderings) {
            foreach ($rendering in $renderings) {
                if ($templateFields) {
                    foreach ($templateField in $templateFields) {

                        $siteItems += [PSCustomObject]@{
                            "CurrentItem-ItemId"                                            = $item.ID
                            "CurrentItem-ItemName"                                          = $item.DisplayName
                            "CurrentItem-ItemPath"                                          = $item.FullPath
                            "CurrentItem-Type"                                              = $itemType
                            "CurrentItem-TemplateName"                                      = $item.TemplateName
                            "CurrentItem-Layout-ItemId"                                     = $layoutItem.ID
                            "CurrentItem-Layout-ItemName"                                   = $layoutItem.Name
                            "Has Page Layout"                                               = $true
                            "Has Final Layout"                                              = $isFinalLayout
                            "CurrentItem-Layout-ItemTemplate"                               = $layoutItem.TemplateName
                            "CurrentItem-Layout-ItemPath"                                   = $layoutItem.ItemPath
                            "CurrentItem-Rendering-ItemName"                                = $rendering."Rendering Name"
                            "CurrentItem-Rendering-ItemId"                                  = $rendering."Rendering ID"
                            "CurrentItem-Rendering-Type"                                    = $rendering."Rendering Template Name"
                            "CurrentItem-Rendering-UsedAt"                                  = $rendering."Rendering Owner Path"
                            "CurrentItem-Rendering-UsedAt-ItemId"                           = $rendering."Rendering Owner ID"
                            "CurrentItem-Rendering-Placeholder-ItemName"                    = $rendering."Placeholder"
                            "CurrentItem-Rendering-DatasourceId"                            = $rendering."Datasource ID"
                            "CurrentItem-Rendering-Datasource-Path"                         = $rendering."Datasource Path"
                            "CurrentItem-Rendering-Parameters-Template"                     = $rendering."Rendering Parameters Template"
                            "CurrentItem-Rendering-Datasource-Location"                     = $rendering."Rendering Datasource Location"
                            "CurrentItem-Rendering-Datasource-Template"                     = $rendering."Rendering Datasource Template"

                            "CurrentItem-Rendering-Rendering-VariantId"                     = $rendering."Rendering Variant ID"
                            "CurrentItem-Rendering-Rendering-VariantName"                   = $rendering."Rendering Variant Name"
                            "CurrentItem-Rendering-StyleId"                                 = $rendering."Rendering Style Id"
                            "CurrentItem-Rendering-StyleName"                               = $rendering."Rendering Style Name"

                            "CurrentItem-CreatedWith-TemplateId"                            = $templateField."Template ID"
                            "CurrentItem-CreatedWith-TemplateName"                          = $templateField."Template Name"
                            "CurrentItem-CreatedWith-TemplatePath"                          = $templateField."Template Path"
                            "CurrentItem-CreatedWith-Template-Inheritance-ItemId"           = $templateField."Base Template ID"
                            "CurrentItem-CreatedWith-Template-Inheritance-ItemName"         = $templateField."Base Template Name"
                            "CurrentItem-CreatedWith-Template-Inheritance-ItemPath"         = $templateField."Base Template Path"
                            "CurrentItem-CreatedWith-Template-Field-With-Source-ItemName"   = $templateField."Field Name"
                            "CurrentItem-CreatedWith-Template-FieldId"                      = $templateField."Field ID"
                            "CurrentItem-CreatedWith-Template-Field-With-Source-SourcePath" = $templateField."Source"
                        }
                    }
                }
                else {
                    $siteItems += [PSCustomObject]@{
                        "CurrentItem-ItemId"                                            = $item.ID
                        "CurrentItem-ItemName"                                          = $item.DisplayName
                        "CurrentItem-ItemPath"                                          = $item.FullPath
                        "CurrentItem-Type"                                              = $itemType
                        "CurrentItem-TemplateName"                                      = $item.TemplateName
                        "CurrentItem-Layout-ItemId"                                     = $layoutItem.ID
                        "CurrentItem-Layout-ItemName"                                   = $layoutItem.Name
                        "Has Page Layout"                                               = $true
                        "Has Final Layout"                                              = $isFinalLayout
                        "CurrentItem-Layout-ItemTemplate"                               = $layoutItem.TemplateName
                        "CurrentItem-Layout-ItemPath"                                   = $layoutItem.ItemPath
                        "CurrentItem-Rendering-ItemName"                                = $rendering."Rendering Name"
                        "CurrentItem-Rendering-ItemId"                                  = $rendering."Rendering ID"
                        "CurrentItem-Rendering-Type"                                    = $rendering."Rendering Template Name"
                        "CurrentItem-Rendering-UsedAt"                                  = $rendering."Rendering Owner Path"
                        "CurrentItem-Rendering-UsedAt-ItemId"                           = $rendering."Rendering Owner ID"
                        "CurrentItem-Rendering-Placeholder-ItemName"                    = $rendering."Placeholder"
                        "CurrentItem-Rendering-DatasourceId"                            = $rendering."Datasource ID"
                        "CurrentItem-Rendering-Datasource-Path"                         = $rendering."Datasource Path"
                        "CurrentItem-Rendering-Parameters-Template"                     = $rendering."Rendering Parameters Template"
                        "CurrentItem-Rendering-Datasource-Location"                     = $rendering."Rendering Datasource Location"
                        "CurrentItem-Rendering-Datasource-Template"                     = $rendering."Rendering Datasource Template"
                        "CurrentItem-Rendering-Rendering-VariantId"                     = $rendering."Rendering Variant ID"
                        "CurrentItem-Rendering-Rendering-VariantName"                   = $rendering."Rendering Variant Name"
                        "CurrentItem-Rendering-StyleId"                                 = $rendering."Rendering Style Id"
                        "CurrentItem-Rendering-StyleName"                               = $rendering."Rendering Style Name"
                        "CurrentItem-CreatedWith-TemplateId"                            = $templateField."Template ID"
                        "CurrentItem-CreatedWith-TemplateName"                          = $templateField."Template Name"
                        "CurrentItem-CreatedWith-TemplatePath"                          = $templateField."Template Path"
                        "CurrentItem-CreatedWith-Template-Inheritance-ItemId"           = $templateField."Base Template ID"
                        "CurrentItem-CreatedWith-Template-Inheritance-ItemName"         = $templateField."Base Template Name"
                        "CurrentItem-CreatedWith-Template-Inheritance-ItemPath"         = $templateField."Base Template Path"
                        "CurrentItem-CreatedWith-Template-Field-With-Source-ItemName"   = $templateField."Field Name"
                        "CurrentItem-CreatedWith-Template-FieldId"                      = $templateField."Field ID"
                        "CurrentItem-CreatedWith-Template-Field-With-Source-SourcePath" = $templateField."Source"
                    
                    }
                }
            }         
        }
        else {
            if ($templateFields) {
                foreach ($templateField in $templateFields) {

                    $siteItems += [PSCustomObject]@{
                        "CurrentItem-ItemId"                                            = $item.ID
                        "CurrentItem-ItemName"                                          = $item.DisplayName
                        "CurrentItem-ItemPath"                                          = $item.FullPath
                        "CurrentItem-Type"                                              = $itemType
                        "CurrentItem-TemplateName"                                      = $item.TemplateName
                        "CurrentItem-Layout-ItemId"                                     = $layoutItem.ID
                        "CurrentItem-Layout-ItemName"                                   = $layoutItem.Name
                        "Has Page Layout"                                               = $false
                        "Has Final Layout"                                              = $isFinalLayout
                        "CurrentItem-Layout-ItemTemplate"                               = $layoutItem.TemplateName
                        "CurrentItem-Layout-ItemPath"                                   = $layoutItem.ItemPath
                        "CurrentItem-Rendering-ItemName"                                = $rendering."Rendering Name"
                        "CurrentItem-Rendering-ItemId"                                  = $rendering."Rendering ID"
                        "CurrentItem-Rendering-Type"                                    = $rendering."Rendering Template Name"
                        "CurrentItem-Rendering-UsedAt"                                  = $rendering."Rendering Owner Path"
                        "CurrentItem-Rendering-UsedAt-ItemId"                           = $rendering."Rendering Owner ID"
                        "CurrentItem-Rendering-Placeholder-ItemName"                    = $rendering."Placeholder"
                        "CurrentItem-Rendering-DatasourceId"                            = $rendering."Datasource ID"
                        "CurrentItem-Rendering-Datasource-Path"                         = $rendering."Datasource Path"
                        "CurrentItem-Rendering-Parameters-Template"                     = $rendering."Rendering Parameters Template"
                        "CurrentItem-Rendering-Datasource-Location"                     = $rendering."Rendering Datasource Location"
                        "CurrentItem-Rendering-Datasource-Template"                     = $rendering."Rendering Datasource Template"
                        "CurrentItem-Rendering-Rendering-VariantId"                     = $rendering."Rendering Variant ID"
                        "CurrentItem-Rendering-Rendering-VariantName"                   = $rendering."Rendering Variant Name"
                        "CurrentItem-Rendering-StyleId"                                 = $rendering."Rendering Style Id"
                        "CurrentItem-Rendering-StyleName"                               = $rendering."Rendering Style Name"
                        "CurrentItem-CreatedWith-TemplateId"                            = $templateField."Template ID"
                        "CurrentItem-CreatedWith-TemplateName"                          = $templateField."Template Name"
                        "CurrentItem-CreatedWith-TemplatePath"                          = $templateField."Template Path"
                        "CurrentItem-CreatedWith-Template-Inheritance-ItemId"           = $templateField."Base Template ID"
                        "CurrentItem-CreatedWith-Template-Inheritance-ItemName"         = $templateField."Base Template Name"
                        "CurrentItem-CreatedWith-Template-Inheritance-ItemPath"         = $templateField."Base Template Path"
                        "CurrentItem-CreatedWith-Template-Field-With-Source-ItemName"   = $templateField."Field Name"
                        "CurrentItem-CreatedWith-Template-FieldId"                      = $templateField."Field ID"
                        "CurrentItem-CreatedWith-Template-Field-With-Source-SourcePath" = $templateField."Source"
                    }
                }
            }
            else {
                $siteItems += [PSCustomObject]@{
                    "CurrentItem-ItemId"                                            = $item.ID
                    "CurrentItem-ItemName"                                          = $item.DisplayName
                    "CurrentItem-ItemPath"                                          = $item.FullPath
                    "CurrentItem-Type"                                              = $itemType
                    "CurrentItem-TemplateName"                                      = $item.TemplateName
                    "CurrentItem-Layout-ItemId"                                     = $layoutItem.ID
                    "CurrentItem-Layout-ItemName"                                   = $layoutItem.Name
                    "Has Page Layout"                                               = $false
                    "Has Final Layout"                                              = $isFinalLayout
                    "CurrentItem-Layout-ItemTemplate"                               = $layoutItem.TemplateName
                    "CurrentItem-Layout-ItemPath"                                   = $layoutItem.ItemPath
                    "CurrentItem-Rendering-ItemName"                                = $rendering."Rendering Name"
                    "CurrentItem-Rendering-ItemId"                                  = $rendering."Rendering ID"
                    "CurrentItem-Rendering-Type"                                    = $rendering."Rendering Template Name"
                    "CurrentItem-Rendering-UsedAt"                                  = $rendering."Rendering Owner Path"
                    "CurrentItem-Rendering-UsedAt-ItemId"                           = $rendering."Rendering Owner ID"
                    "CurrentItem-Rendering-Placeholder-ItemName"                    = $rendering."Placeholder"
                    "CurrentItem-Rendering-DatasourceId"                            = $rendering."Datasource ID"
                    "CurrentItem-Rendering-Datasource-Path"                         = $rendering."Datasource Path"
                    "CurrentItem-Rendering-Parameters-Template"                     = $rendering."Rendering Parameters Template"
                    "CurrentItem-Rendering-Datasource-Location"                     = $rendering."Rendering Datasource Location"
                    "CurrentItem-Rendering-Datasource-Template"                     = $rendering."Rendering Datasource Template"
                    "CurrentItem-Rendering-Rendering-VariantId"                     = $rendering."Rendering Variant ID"
                    "CurrentItem-Rendering-Rendering-VariantName"                   = $rendering."Rendering Variant Name"
                    "CurrentItem-Rendering-StyleId"                                 = $rendering."Rendering Style Id"
                    "CurrentItem-Rendering-StyleName"                               = $rendering."Rendering Style Name"
                    "CurrentItem-CreatedWith-TemplateId"                            = $templateField."Template ID"
                    "CurrentItem-CreatedWith-TemplateName"                          = $templateField."Template Name"
                    "CurrentItem-CreatedWith-TemplatePath"                          = $templateField."Template Path"
                    "CurrentItem-CreatedWith-Template-Inheritance-ItemId"           = $templateField."Base Template ID"
                    "CurrentItem-CreatedWith-Template-Inheritance-ItemName"         = $templateField."Base Template Name"
                    "CurrentItem-CreatedWith-Template-Inheritance-ItemPath"         = $templateField."Base Template Path"
                    "CurrentItem-CreatedWith-Template-Field-With-Source-ItemName"   = $templateField."Field Name"
                    "CurrentItem-CreatedWith-Template-FieldId"                      = $templateField."Field ID"
                    "CurrentItem-CreatedWith-Template-Field-With-Source-SourcePath" = $templateField."Source"
                }
            }
        }
    }
    return $siteItems
}

# Define the dialog for user input
$databaseOptions = [ordered]@{
    "master" = "master"
    "web"    = "web"
}


$parameters = @(
    @{ Name = "homePath"; Title = "Home Path"; Tooltip = "Enter the home page to start from"; Editor = "droptree"; DefaultValue = "/sitecore/content/Home" },
    @{ Name = "pageDesignPath"; Title = "Page Design Path"; Tooltip = "Enter the page design path to start from"; Editor = "droptree"; DefaultValue = "/sitecore/content/Home" },
    @{ Name = "partialPageDesignPath"; Title = "Partial Page Design Path"; Tooltip = "Enter the partial page design path to start from"; Editor = "droptree"; DefaultValue = "/sitecore/content/Home" },
    @{ Name = "database"; Title = "Database"; Tooltip = "Choose the database"; Editor = "radio"; Options = $databaseOptions; DefaultValue = "master" }
)

# Show Read-Variable dialog
$result = Read-Variable -Parameters $parameters -Description "Select options to fetch Sitecore item details." -Title "Fetch Sitecore Item Details" -Width 450 -Height 250 -OkButtonName "Proceed" -CancelButtonName "Cancel"

if ($result -ne "ok") {
    # User cancelled the dialog, exit the script
    return
}
#function and display results
$results = Get-MvcSiteItems -path $homePath.FullPath -database $database 
$results += Get-MvcSiteItems -path $pageDesignPath.FullPath -database $database 
$results += Get-MvcSiteItems -path $partialPageDesignPath.FullPath -database $database 


$properties = @(
    "CurrentItem-ItemId",
    "CurrentItem-ItemName",
    "CurrentItem-ItemPath",
    "CurrentItem-Type",
    "CurrentItem-TemplateName",
    "CurrentItem-Layout-ItemId",
    "CurrentItem-Layout-ItemName",
    "Has Page Layout",
    "Has Final Layout",
    "CurrentItem-Layout-ItemTemplate",
    "CurrentItem-Layout-ItemPath",
    "CurrentItem-Rendering-ItemName",
    "CurrentItem-Rendering-ItemId",
    "CurrentItem-Rendering-Type",
    "CurrentItem-Rendering-UsedAt",
    "CurrentItem-Rendering-UsedAt-ItemId",
    "CurrentItem-Rendering-Placeholder-ItemName",
    "CurrentItem-Rendering-DatasourceId",
    "CurrentItem-Rendering-Datasource-Path",
    "CurrentItem-Rendering-Parameters-Template",
    "CurrentItem-Rendering-Datasource-Location",
    "CurrentItem-Rendering-Datasource-Template",
    
    "CurrentItem-Rendering-Rendering-VariantId",
    "CurrentItem-Rendering-Rendering-VariantName",
    "CurrentItem-Rendering-StyleId",
    "CurrentItem-Rendering-StyleName",

    
    "CurrentItem-CreatedWith-TemplateId",
    "CurrentItem-CreatedWith-TemplateName",
    "CurrentItem-CreatedWith-TemplatePath",
    "CurrentItem-CreatedWith-Template-Inheritance-ItemId",
    "CurrentItem-CreatedWith-Template-Inheritance-ItemName",
    "CurrentItem-CreatedWith-Template-Inheritance-ItemPath",
    "CurrentItem-CreatedWith-Template-Field-With-Source-ItemName",
    "CurrentItem-CreatedWith-Template-FieldId",
    "CurrentItem-CreatedWith-Template-Field-With-Source-SourcePath"
)

$results | Show-ListView -Property $properties
