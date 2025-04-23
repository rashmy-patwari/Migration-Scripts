    # Function to replace template and retain field values
    function ReplaceTemplateAndRetainFields {
        param (
            [Sitecore.Data.Items.Item]$currentItem,
            [string]$compareTemplateId,
            [string]$newTemplateId
        )

        if($currentItem.TemplateId -ne $compareTemplateId) {
            Write-Host "Nothing to do, skipping: $($currentItem.Paths.FullPath)"
            return
        }

        # Store the field values
        $fieldValues = @{}
        $currentItem.Fields | ForEach-Object {
            $fieldValues[$_.Name] = $_.Value
        }

        # Store the layout fields
        $layoutFields = @{
            "__Renderings" = $currentItem["__Renderings"]
            "__Final Renderings" = $currentItem["__Final Renderings"]
        }

        # Change the template
        $currentItem.Editing.BeginEdit()
        try {
            
            #Set-ItemTemplate -Item $currentItem -Template $templateItem
            $currentItem.TemplateId = $newTemplateId

            # Restore the field values
            $fieldValues.GetEnumerator() | ForEach-Object {
                $currentItem[$_.Key] = $_.Value
            }

            # Restore the layout fields
            $layoutFields.GetEnumerator() | ForEach-Object {
                $currentItem[$_.Key] = $_.Value
            }

            $currentItem.Editing.EndEdit()

        } catch {
            $currentItem.Editing.CancelEdit()
            Write-Error "Failed to change template for item $($currentItem.Paths.FullPath): $_"
        }
}

function Replace-ItemTemplate {
    param (
        [string]$ItemPath,
        [string]$compareTemplateId,
        [string]$newTemplateId
    )

    # Get the item and the new template
    $item = Get-Item -Path "master:$ItemPath"

    if ($null -eq $item) {
        Write-Error "Item does not exist: $ItemPath"
        exit 1
    }

    if (-not $newTemplateId) {
        Write-Error "New template does not exist: $newTemplateId"
        exit 1
    }


    # Replace template for the item and its children
    $itemsToProcess = @($item) + $item.Axes.GetDescendants()
    foreach ($currentItem in $itemsToProcess) {
        ReplaceTemplateAndRetainFields -currentItem $currentItem -compareTemplateId $compareTemplateId -newTemplateId $newTemplateId
    }

    Write-Host "Template for item $ItemPath and its children has been replaced with $newTemplateId and field values retained."
}

# Example usage
Replace-ItemTemplate -ItemPath "/sitecore/content/shopping/txushopping/Copy of home" -compareTemplateId "{45B3EAF3-2BDB-5B4A-A8DF-9170AF754AAD}" -newTemplateId "{3616DF87-3E04-40B1-AFA7-262812590404}"

#custom-route
Replace-ItemTemplate -ItemPath "/sitecore/content/shopping/txushopping/Copy of home/styleguide/custom-route-type" -compareTemplateId "{3395F496-970F-5C67-B624-F58C0B89AE73}" -newTemplateId "{3C8F74BA-21E0-4083-BF8C-EB6C0C8A4B7D}"