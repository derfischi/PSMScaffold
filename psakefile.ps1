Properties {
	$moduleName = "MyModule"
	$version = "1.0"
    $buildVersion = $version
	$moduleManifest = "${moduleName}.psd1"
	$scriptModule = "${moduleName}.psm1"
	$rootDir = Split-Path $psake.build_script_file
    $sourceDir = "${rootDir}\src"
    $buildDir = "${rootDir}\build"
}

Task InitModule {

    if (-not (Test-Path $sourceDir)) {
        mkdir $sourceDir
        "public","private","scripts","classes","lib" |New-Item -Path $sourceDir -ItemType Directory
    }
    if (-not (Test-Path $buildDir)) { mkdir $buildDir }

    if (-not (Test-Path "${sourceDir}\${moduleManifest}" -PathType Leaf)) {
        New-ModuleManifest -Path "${sourceDir}\${moduleManifest}" -ModuleVersion $buildVersion
    }

    if (-not (Test-Path "${sourceDir}\${scriptModule}" -PathType Leaf)) {
        "# ${scriptModule}" |Out-File -FilePath "${sourceDir}\${scriptModule}" -Encoding utf8
    }
}

Task UpdateVersion {

    $buildNumber = 0
	$revNumber = -1

    $git = Get-Command git -ErrorAction SilentlyContinue
	if ($null -ne $git) {
		$revNumber = [int]"0x$(git rev-parse --short HEAD)"
	}

	$versions = @{}
	if (Test-Path "${sourceDir}\Versions.json") {
		$versions = Get-Content ${sourceDir}\Versions.json -Raw |ConvertFrom-Json
		$buildNumber = ++$versions.$version
		$versions.$version = $buildNumber 
	} else {
		$versions.$version = ++$buildNumber
	}
	$versions |ConvertTo-Json |Set-Content ${sourceDir}\Versions.json

	$v = [Version]$version
	$v = New-Object System.Version $v.Major,$v.Minor,$buildNumber,$revNumber
	$script:buildVersion = $v.ToString()

    "`$buildVersion = " + $script:buildVersion
}

Task UpdateModuleManifest -depends UpdateVersion {

	$functionsToExport = @()

	ls (Join-Path $sourceDir "Public\*.ps1") -Recurse |ForEach-Object {
		$tokens = $errors = $null
		$ast = [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors)

		$functionDefinitions = $ast.FindAll({
			param([System.Management.Automation.Language.Ast]$Ast)
			$Ast -is [System.Management.Automation.Language.FunctionDefinitionAst] -and ($PSVersionTable.PSVersion.Major -lt 5 -or $Ast.Parent -isnot [System.Management.Automation.Language.FunctionMemberAst])
		}, $true)

		$functionsToExport += $functionDefinitions |ForEach-Object { ($_ -as [System.Management.Automation.Language.FunctionDefinitionAst]).Name }
	}

	$scriptsToProcess = @()
	$scriptsToProcess += (ls (Join-Path $sourceDir "Scripts\*.ps1") |% {"Scripts\$($_.Name)"})
	$scriptsToProcess += (ls (Join-Path $sourceDir "Classes\*.ps1") |% {"Classes\$($_.Name)"})

	Update-ModuleManifest -Path (Join-Path $sourceDir $moduleManifest) -FunctionsToExport $functionsToExport -ModuleVersion $script:buildVersion -ScriptsToProcess $scriptsToProcess
}

Task Clean {
	if (Test-Path $buildRoot) {
		#Remove-Item $buildRoot -Recurse -Force
		# Workaround: removal of files in OneDrive folder
		# https://evotec.xyz/remove-item-access-to-the-cloud-file-is-denied-while-deleting-files-from-onedrive/
		Get-ChildItem $buildDir -Recurse -File |Remove-Item
		Get-ChildItem $buildDir -Recurse -Directory |select -ExpandProperty FullName |sort -Descending |% { [IO.Directory]::Delete($_) }
		#[IO.Directory]::Delete($buildDir)
	}
}