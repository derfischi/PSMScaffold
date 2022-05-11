$Script:Var1 = ""
$Script:Var2 = ""

function TestFunc {
    return "Bla"
}

#include<TestInclude.ps1>

Get-ChildItem (Join-Path $PSScriptRoot "Private") -Filter "*.ps1" -Recurse |ForEach-Object {
	Write-Debug "Loading $($_.FullName)"
	. $_.FullName
}

Get-ChildItem (Join-Path $PSScriptRoot "Public") -Filter "*.ps1" -Recurse |ForEach-Object {
	Write-Debug "Loading $($_.FullName)"
	. $_.FullName
}