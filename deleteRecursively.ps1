$targetTemplateIds = @(
"{1105B8F8-1E00-426B-BF1F-C840742D827B}",<#Page Design#>
"{3F367812-0AB0-46AD-B3E4-6A6B61E48AD0}", <#Partial Design Folder#>
"{FD2059FD-6043-4DFE-8C04-E2437CE87634}", <#Partial Design#>
"{45B3EAF3-2BDB-5B4A-A8DF-9170AF754AAD}" <#App Route#>
)


#$folderItem = Get-Item -Path 'master:/sitecore/content/XMCMyaccount/txumyaccount/Presentation/Partial Designs'
#$folderItem = Get-Item -Path 'master:/sitecore/content/XMCMyaccount/teemyaccount/Data'
#folderItem = Get-Item -Path 'master:/sitecore/content/XMCMyaccount/teemyaccount/Presentation/Page Designs'
$folderItem = Get-Item -Path 'master:/sitecore/content/XMCMyaccount/teemyaccount/Presentation/Partial Designs'

Get-ChildItem -Path $folderItem.FullPath -Recurse |
    Where-Object { $targetTemplateIds -contains $_.TemplateID } |
    ForEach-Object {
        Write-Host "Deleting item: $($_.Name) (template: $($_.TemplateID))"
        $_ | Remove-Item -Recurse
    }

Write-Host "Done"
