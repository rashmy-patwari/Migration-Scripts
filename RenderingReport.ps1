write-host 'Running script...'
Set-Location master:\content
$pages = get-item 'TEE/ShoppingTEE' | get-childitem -Recurse
$device = Get-LayoutDevice -Default
$Results = @();

foreach($page in $pages){

    $renderings = Get-Rendering -Item $page -Device $device -FinalLayout

    foreach($rendering in $renderings){

        if($rendering.ItemID -ne $null)
        {
            $renderingItem = Get-Item master: -ID $rendering.ItemID
            $dataSourceItem = $null
            $pageTemplate = Get-ItemTemplate -Item $page
            
            if (![string]::IsNullOrEmpty($rendering.Datasource))
            {
                $datasourcePath = $rendering.Datasource
                if ($datasourcePath.StartsWith("local:")) {
                    $datasourcePath = $datasourcePath.Replace("local:", $page.Paths.FullPath)
                
                    #"datasourcePath: " + $datasourcePath
                    $dataSourceItem = Get-Item -Path "master:$datasourcePath" -ErrorAction SilentlyContinue
                }
                else {

                        $guidRegex = '\b[A-F0-9]{8}(?:-[A-F0-9]{4}){3}-[A-F0-9]{12}\b'
                        if ($datasourcePath -match $guidRegex) {
                            $dataSourceItem = Get-Item master: -ID $datasourcePath
                        } else {
                            $dataSourceItem = Get-Item -Path "master:$datasourcePath" -ErrorAction SilentlyContinue
                        }
                }
            }
            
            if($renderingItem -ne $null)
            {

                # identifying SXA variant
                $variant = ''
                if ($rendering.Parameters -match "FieldNames=(?<variantId>%7B[0-9A-Fa-f\-]+%7D)") {
                    $encodedVariantId = $matches['variantId']
                    # Decode the URL-encoded GUID
                    $variantId = [System.Uri]::UnescapeDataString($encodedVariantId)
                    $variantItem = Get-Item -Path "master:/sitecore/system/Settings/Feature/Experience Accelerator/Rendering Variants/$variantId"
                
                    if ($variantItem) {
                        $variant = $variantItem.DisplayName
                    }
                }

                # Gather non-standard fields from the data source
                if ($dataSourceItem -ne $null) {
                    $nonStdFields = $dataSourceItem.Fields | Where-Object { -not $_.Name.StartsWith("__") }
                    $fieldPairs = @()

                    foreach ($field in $nonStdFields) {
                        $fieldPairs += ("{0}={1}" -f $field.Name, $field.Value)
                    }

                    # Join all pairs into a single string
                    $fieldValues = $fieldPairs -join "; "
                }
                else {
                    $fieldValues = ""
                }

                $Properties = @{
                    RenderingItemName = $renderingItem.Name
                    RenderingItemID = $renderingItem.ID
                    DataSource = $rendering.Datasource
                    DataSourcePath = $dataSourceItem.Paths.Path
                    RenderingItemPath = $renderingItem.Paths.Path
                    ControllerAction = $renderingItem."Controller Action"
                    ViewPath = $renderingItem.Path
                    Variant = $variant
                    UsedOnPage = $page.Name
                    UsedOnPageID = $page.ID
                    UsedOnPagePath = $page.Paths.Path
                    PageTemplate = $pageTemplate.Name
                    PageTemplateId = $pageTemplate.ID
                    Rendering = $rendering.Rules
                    FieldValues = $fieldValues
                }

                $Results += New-Object psobject -Property $Properties
            }
        }

    }
}

$Results | Show-ListView -Property RenderingItemName,RenderingItemID,RenderingItemPath,Datasource,DataSourcePath,ControllerAction,ViewPath,Variant,UsedOnPage,UsedOnPageID,UsedOnPagePath,PageTemplate,PageTemplateId,FieldValues

write-host 'Script ended' 