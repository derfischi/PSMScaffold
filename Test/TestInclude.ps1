class TestClass {
    #region "Instance properties"
    [string]$Name
    [string]$TenantDomain
    [guid]$TenantId
    [string]$IIQApplication
    [pscredential]$ServicePrincipal
    [bool]$IsFederated
    [string]$OnPremisesDomain
    [pscredential]$OnPremisesCredential
    [string]$Environment
    [datetime]$Created
    [datetime]$Modified
    #endregion
}