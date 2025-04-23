
# Initialize results as an empty array
$results = @()


# Corrected Regex Patterns
$htmlTagPattern = "<[^>]+>" # Detects HTML tags
$linkPattern = "(http|https)://[a-zA-Z0-9/.\\-_?=&%#!]+"

function ContainsHtmlOrLink {
    param (
        [string]$fieldValue
    )

    # Check for HTML tags or links in the field value
    return ($fieldValue -match $htmlTagPattern) -or ($fieldValue -match $linkPattern)
}


$parameters = @(
    @{ Name = "homePath"; Title = "Home Path"; Tooltip = "Enter the home page to start from"; Editor = "droptree"; DefaultValue = "/sitecore/content/Home" },
    @{ Name = "siteDataPath"; Title = "Site Data Path"; Tooltip = "Enter the site data path to start from"; Editor = "droptree"; DefaultValue = "/sitecore/content/Home" },
    @{ Name = "pageDesignPath"; Title = "Page Design Path"; Tooltip = "Enter the page design path to start from"; Editor = "droptree"; DefaultValue = "/sitecore/content/Home" },
    @{ Name = "partialPageDesignPath"; Title = "Partial Page Design Path"; Tooltip = "Enter the partial page design path to start from"; Editor = "droptree"; DefaultValue = "/sitecore/content/Home" }
)

# Show Read-Variable dialog
$result = Read-Variable -Parameters $parameters -Description "Select options to fetch Sitecore item details." -Title "Fetch Sitecore Item Details" -Width 450 -Height 250 -OkButtonName "Proceed" -CancelButtonName "Cancel"

if ($result -ne "ok") {
    # User cancelled the dialog, exit the script
    return
}


# Start the search from the root path
$items = Get-ChildItem -Path "master:$($homePath.FullPath)" -Recurse -WithParent
$items += Get-ChildItem -Path "master:$($siteDataPath.FullPath)" -Recurse 
$items += Get-ChildItem -Path "master:$($pageDesignPath.FullPath)" -Recurse 

$items += Get-ChildItem -Path "master:$($partialPageDesignPath.FullPath)" -Recurse 

# Initialize counters
$totalItemsChecked = 0
$fieldsWithHtmlOrLinksCount = 0

# Iterate through each item
foreach ($item in $items) {
    $totalItemsChecked += 1
    foreach ($field in $item.Fields) {
        if ($field -and ![string]::IsNullOrWhiteSpace($field.Value) -and !$field.InnerItem.Paths.FullPath.StartsWith("/sitecore/templates/system", 'CurrentCultureIgnoreCase')) {

        # Skip system fields and check only relevant field types
        if (!$field.Name.StartsWith("__") -and ($field.Type -eq "Rich Text" -or $field.Type -eq "Single-Line Text" -or $field.Type -eq "Multi-Line Text")) {
            $fieldValue = $item[$field.Name] # Access field value directly
            if (ContainsHtmlOrLink -fieldValue $fieldValue) {
                $fieldsWithHtmlOrLinksCount += 1
                # Log details of the field containing HTML or link
                $results += New-Object PSObject -Property @{
                    "Item Path" = $item.Paths.FullPath
                    "Item ID" = $item.ID
                    "Field Type" = $field.Type
                    "Field Name" = $field.Name
                    "Field ID" = $field.ID
                }
              #  Write-Host "Item Path: $($item.Paths.FullPath), Field Name: $($field.Name), Field Value contains HTML or Link"
            }
        }
    }
    }
}

# Summary of the operation
Write-Host "Total Items Checked: $totalItemsChecked"
Write-Host "Fields with HTML or Links Detected: $fieldsWithHtmlOrLinksCount"



# Show results in a ListView
if ($results.Count -gt 0) {
    $results | Show-ListView -Property "Item Path", "Item ID", "Field Type", "Field Name", "Field ID" -Title "Fields with HTML or Links"
    Close-Window
}
else {
    Write-Host "No fields with HTML tags or links were found."
}