$global:sourceNodePath = ""
$global:destinationNodePath = ""

function doSomething {
    param(
    [Parameter(Mandatory = $true)]
    [string]$RootTemplateItemPath,

    [Parameter(Mandatory = $true)]
    [string]$SourceNodePath,

    [Parameter(Mandatory = $true)]
    [string]$DestinationNodePath
)

    $global:sourceNodePath = $SourceNodePath
    $global:destinationNodePath = $DestinationNodePath

    Write-Host $RootTemplateItemPath

    function Convert-DestinationPath {
        param(
            [string]$sourcePath
        )
        
        write-host $global:sourceNodePath
        write-host $global:destinationNodePath
        
        return $sourcePath -replace $global:sourceNodePath, $global:destinationNodePath
    }

    function Update-MultilistFieldSources {
        param([Sitecore.Data.Items.Item]$TemplateItem)

        Write-Host "Updating for Template '$($TemplateItem.Paths.FullPath)'"

        # Get all sections within the template
        $sections = $TemplateItem.Children | Where-Object { $_.TemplateID -eq [Sitecore.TemplateIDs]::TemplateSection }

        foreach ($section in $sections) {
            Write-Host "Updating for section '$($section.Paths.FullPath)'"
            
            # Get all fields within the section
            $fields = $section.Children 

            foreach ($field in $fields) {
                $source = $field["Source"]
                $fieldType = $field["Type"]

                if ($fieldType -eq "Multilist" -and $source -and $source.Trim() -ne "") {
                    
                    Write-Host "Updating field '$($field.Name)' for item '$($TemplateItem.Paths.FullPath)' Source Path: '$($source)'"
                    $newContentItemPath = Convert-DestinationPath -sourcePath $field.Source
                    Write-Host "New source path: $newContentItemPath"

                    $TemplateItem.Editing.BeginEdit()
                    $field.Source = $newContentItemPath
                    $TemplateItem.Editing.EndEdit()
                }
            }
        }

        # Recurse through children
        foreach ($child in $TemplateItem.Children) {
            Update-MultilistFieldSources -TemplateItem $child
        }
    }

    $rootItem = Get-Item -Path "master:$RootTemplateItemPath" -ErrorAction SilentlyContinue
    if ($rootItem) {
        Write-Host $rootItem
        Update-MultilistFieldSources -TemplateItem $rootItem
    }
    else {
        Write-Host "Cannot find template item at $RootTemplateItemPath."
    }

}


doSomething -RootTemplateItemPath "/sitecore/templates/Project/XMCMyaccount/My Energy Dashboard/MEDHomesLikeYoursWidget" -SourceNodePath "TXU/MyAccount" -DestinationNodePath "XMCMyaccount/txumyaccount"