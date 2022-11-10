Properties {
	$moduleName = "MyModule"
	$version = "1.0"
	$moduleManifest = "${moduleName}.psd1"
	$scriptModule = "${moduleName}.psm1"
	$rootDir = Split-Path $psake.build_script_file
    $sourceDir = "${rootDir}/src"
    $buildDir = "${rootDir}/build"
}

Task Default -depends Build,PostBuild

Task Build -depends InitBuild,Clean,UpdateModuleManifest,PrepareBuild {
	ProcessScriptModule "${sourceDir}/${scriptModule}" |Out-File -FilePath "${script:outpath}/${scriptModule}" -Encoding utf8

	ls (Join-Path $sourceDir "private") -Recurse -Filter "*.ps1" |% {Get-Content $_.FullName -Encoding UTF8 |Add-Content "${script:outpath}/${scriptModule}" -Encoding UTF8}
	ls (Join-Path $sourceDir "public") -Recurse -Filter "*.ps1" |% {Get-Content $_.FullName -Encoding UTF8 |Add-Content "${script:outpath}/${scriptModule}" -Encoding UTF8}
}

Task InitBuild {
	Import-Module "${rootDir}/Functions.psm1"
}

Task PostBuild {
	Get-Module -Name Functions -All |Remove-Module
}

Task Scaffold {

    if (-not (Test-Path $sourceDir)) {
        mkdir $sourceDir
        "public","private","scripts","classes","lib" |% {New-Item -Path $sourceDir -Name $_ -ItemType Directory}
    }
    if (-not (Test-Path $buildDir)) { mkdir $buildDir }

    if (-not (Test-Path "${sourceDir}/${moduleManifest}" -PathType Leaf)) {
        New-ModuleManifest -Path "${sourceDir}/${moduleManifest}" -ModuleVersion $buildVersion -RootModule $scriptModule
    }

    if (-not (Test-Path "${sourceDir}\${scriptModule}" -PathType Leaf)) {
        "# ${scriptModule}" |Out-File -FilePath "${sourceDir}/${scriptModule}" -Encoding utf8
    }
}

Task UpdateVersion {

	"`$version = " + $version

	$script:buildVersion = GetBuildVersion "${sourceDir}/Versions.json" $version

    "`$buildVersion = " + $script:buildVersion
}

Task PrepareBuild {
    $script:outpath = Join-Path $buildDir "${moduleName}/${script:buildVersion}"
	if (-not (Test-Path $script:outpath)) {
		New-Item $script:outpath -ItemType Directory
	}

    Copy-Item (Join-Path $sourceDir $moduleManifest) -Destination $script:outpath
	Copy-Item (Join-Path $sourceDir "lib") -Recurse -Destination $script:outpath
	Copy-Item (Join-Path $sourceDir "scripts") -Recurse -Destination $script:outpath
	Copy-Item (Join-Path $sourceDir "assets") -Recurse -Destination $script:outpath
}

Task UpdateModuleManifest -depends UpdateVersion {

	$functionsToExport = GetExportedFunctions (ls (Join-Path $sourceDir "Public/*.ps1") -Recurse)
	$scriptsToProcess = @()
	$scriptsToProcess += (ls (Join-Path $sourceDir "Scripts/*.ps1") |% {"Scripts/$($_.Name)"})

	$param = @{
		Path = (Join-Path $sourceDir $moduleManifest)
		FunctionsToExport = $functionsToExport
		ModuleVersion = $buildVersion
	}

	if ($null -ne $scriptsToProcess -and $scriptsToProcess.Count -gt 0) {
		$param["ScriptsToProcess"] = $scriptsToProcess
	}

	Update-ModuleManifest @param
}

Task Clean {
	if (Test-Path $buildDir) {
		# Workaround: removal of files in OneDrive folder
		# https://evotec.xyz/remove-item-access-to-the-cloud-file-is-denied-while-deleting-files-from-onedrive/
		Get-ChildItem $buildDir -Recurse -File |Remove-Item
		Get-ChildItem $buildDir -Recurse -Directory |select -ExpandProperty FullName |sort -Descending |% { [IO.Directory]::Delete($_) }
		#[IO.Directory]::Delete($buildDir)
	}
}