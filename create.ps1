# Setting error action preference to silently continue on errors
$ErrorActionPreference = 'SilentlyContinue'

# Creating a list to store output objects
$output = New-Object Collections.Generic.List[object]

# Defining the download template URL
$downloadLink = "https://github.com/Glaives-of-Eorzea/FFXIV.Plugin.Distribution/raw/main/plugins/{0}/latest.zip"
$downloadBetaLink = "https://github.com/Glaives-of-Eorzea/FFXIV.Plugin.Distribution/raw/main/plugins/test/{0}/latest.zip"
# URL of the external repository's raw JSON file
$externalRepoJsonUrl = "https://puni.sh/api/repository/veyn"

# Searching for JSON files in the 'plugins' directory, recursively
Get-ChildItem -Path plugins -File -Recurse -Include *.json | ForEach-Object {
    # Reading and converting JSON content to a PowerShell object
    $content = Get-Content -Path $_.FullName -Raw | ConvertFrom-Json
   
    # Adding new properties to the content object
    $content | Add-Member -Force -Name "IsHide" -Value "False" -MemberType NoteProperty
    $content | Add-Member -Force -Name "IsTestingExclusive" -Value "False" -MemberType NoteProperty
    
    # Replacing newline characters with HTML break lines in description
    $newDesc = $content.Description -replace "\n", "<br>"
    # Replacing pipe characters with the letter 'I'
    $newDesc = $newDesc -replace "\|", "I"
    $content.Description = $newDesc
    
    # Getting the last update date of the plugin ZIP file using git
    $internalName = $content.InternalName
    $updateDate = git log -1 --pretty="format:%ct" "plugins/$internalName/latest.zip"
    if (-not $updateDate) {
        $updateDate = 0
    }
    $content | Add-Member -Force -Name "LastUpdate" -Value $updateDate -MemberType NoteProperty
    
    # Constructing the download links
    $link = $downloadLink -f $internalName
    $betaLink = $downloadBetaLink -f $internalName
    $content | Add-Member -Force -Name "DownloadLinkInstall" -Value $link -MemberType NoteProperty
    $content | Add-Member -Force -Name "DownloadLinkTesting" -Value $betaLink -MemberType NoteProperty
    $content | Add-Member -Force -Name "DownloadLinkUpdate" -Value $link -MemberType NoteProperty
    
    # Adding the modified content to the output list
    $output.Add($content)
}

# Fetching JSON content from the external repository
try {
    $externalContent = Invoke-WebRequest -Uri $externalRepoJsonUrl -UseBasicParsing | Select-Object -ExpandProperty Content
    $externalObject = $externalContent | ConvertFrom-Json

    # Filtering for the block where "Name" is "Island sanctuary automation"
    $specificObject = $externalObject | Where-Object { $_.Name -eq "V(ery) Island" }

    # If the specific block is found, add it to the output list
    if ($specificObject) {
        $output.Add($specificObject)
    }
    else {
        Write-Host "Specific block not found in external JSON."
    }
}
catch {
    Write-Error "Failed to fetch or parse external repository JSON: $_"
}

# Convert the output list to a JSON string and write to a file
$outputStr = $output | ConvertTo-Json -Depth 10
Out-File -Encoding ASCII -FilePath .\pluginmaster.json -InputObject $outputStr
