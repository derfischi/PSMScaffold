function GetExportedFunctions {
    param (
        $Files
    )
    
    $functionsToExport = @()

    $Files |ForEach-Object {
        $tokens = $errors = $null
		$ast = [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors)

		$functionDefinitions = $ast.FindAll({
			param([System.Management.Automation.Language.Ast]$Ast)
			$Ast -is [System.Management.Automation.Language.FunctionDefinitionAst] -and ($PSVersionTable.PSVersion.Major -lt 5 -or $Ast.Parent -isnot [System.Management.Automation.Language.FunctionMemberAst])
		}, $true)

		$functionsToExport += $functionDefinitions |ForEach-Object { ($_ -as [System.Management.Automation.Language.FunctionDefinitionAst]).Name }
    }

    return $functionsToExport
}

function GetBuildVersion {
    param (
        $FilePath
    )

    $buildNumber = 0
	$revNumber = -1

    $git = Get-Command git -ErrorAction SilentlyContinue
	if ($null -ne $git) {
		$revNumber = [int]"0x$(git rev-parse --short HEAD)"
	}

	$versions = @{}
	if (Test-Path $FilePath) {
		$versions = Get-Content $FilePath -Raw |ConvertFrom-Json
		$buildNumber = ++$versions.$version
		$versions.$version = $buildNumber 
	} else {
		$versions.$version = ++$buildNumber
	}
	$versions |ConvertTo-Json |Set-Content $FilePath

	$v = [Version]$version
	$v = New-Object System.Version $v.Major,$v.Minor,$buildNumber,$revNumber
	
    return $v.ToString()
}

function ProcessInclude {
    param (
        [string]$Path
    )

    $sb = [System.Text.StringBuilder]::new()

    Get-ChildItem $Path |ForEach-Object {
        Write-Debug "Include: ${_}"
        [void]$sb.Append("#region ")
        [void]$sb.AppendLine("`"$($_.Name)`"")
        Get-Content -Path $_ -Encoding UTF8 |ForEach-Object {
            Write-Debug "Append: ${_}"
            [void]$sb.AppendLine($_)
        }
        [void]$sb.AppendLine("#endregion")
    }

    return $sb
}
function ProcessScriptModule {
    param (
        [string]$Path
    )

    $file = Resolve-Path $Path
    $dir = Split-Path $file

    Write-Debug $file
    Write-Debug $dir

    $lines = Get-Content -Path $file -Encoding UTF8

    $sb = [System.Text.StringBuilder]::new()

    $lines |ForEach-Object {
        if ($_ -match "^#include\<(.*)\>$") {
            $includePath = Join-Path $dir $Matches[1]
            $sb.Append((ProcessInclude $includePath))
        } else {
            Write-Debug "Append: ${_}"
            [void]$sb.AppendLine($_)
        }
    }

    return $sb.ToString()
}