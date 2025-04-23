write-host 'Running script...'
Set-Location master:\content
#$pages = get-item 'master:/sitecore/content/XMCMyaccount' | get-childitem -Language * -Version * -Recurse
$pages = get-item 'master:/sitecore/content/XMCShopping' | get-childitem -Recurse

$device = Get-LayoutDevice -Default
$Results = @();

foreach($page in $pages){

    $renderings = Get-Rendering -Item $page -Device $device -FinalLayout

    foreach($rendering in $renderings){
        if($rendering.ItemID -ne $null){
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
            
                $Properties = @{
                    Language = $page.Language
                    UsedOnPage = $page.Name
                    UsedOnPageID = $page.ID
                    UsedOnPagePath = $page.Paths.Path
                    RenderingItemName = $renderingItem.Name
                    RenderingItemID = $renderingItem.ID
                    RenderingItemPath = $renderingItem.Paths.Path
                    DataSource = $rendering.Datasource
                    DataSourcePath = $dataSourceItem.Paths.Path
                    ControllerAction = $renderingItem."Controller Action"
                    ViewPath = $renderingItem.Path
                    Variant = $variant
                    PageTemplate = $pageTemplate.Name
                    PageTemplateId = $pageTemplate.ID
                    PageLayout = $rendering.Value | ConvertFrom-Json
                    Layout = $rendering.Layout
                }

                $Results += New-Object psobject -Property $Properties
            }
        }
    }
}

$Results | Show-ListView -Property Layout,Language,UsedOnPage,UsedOnPageID,UsedOnPagePath,RenderingItemName,RenderingItemID,RenderingItemPath,Datasource,DataSourcePath,ControllerAction,ViewPath,Variant,PageTemplate,PageTemplateId

write-host 'Script ended' 