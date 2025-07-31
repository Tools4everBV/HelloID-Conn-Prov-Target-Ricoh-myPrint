#################################################
# HelloID-Conn-Prov-Target-Ricoh-myPrint-Import
# PowerShell V2
#################################################

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

#region functions
function Convert-CSXmlResponseToPSCustomObject {
    param (
        [Parameter()]
        [System.Xml.XmlElement]$XmlResponse
    )

    $properties = @{}
    foreach ($node in $XmlResponse.ChildNodes) {
        if ($node.NodeType -eq 'Element') {
            $properties[$node.LocalName] = $node.InnerText
        }
    }
    $object = [PSCustomObject]$properties
    Write-Output $object
}

function Resolve-Ricoh-myPrintError {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]
        $ErrorObject
    )
    process {
        $httpErrorObj = [PSCustomObject]@{
            ScriptLineNumber = $ErrorObject.InvocationInfo.ScriptLineNumber
            Line             = $ErrorObject.InvocationInfo.Line
            ErrorDetails     = $ErrorObject.Exception.Message
            FriendlyMessage  = $ErrorObject.Exception.Message
        }
        if (-not [string]::IsNullOrEmpty($ErrorObject.ErrorDetails.Message)) {
            $httpErrorObj.ErrorDetails = $ErrorObject.ErrorDetails.Message
        } elseif ($ErrorObject.Exception.GetType().FullName -eq 'System.Net.WebException') {
            if ($null -ne $ErrorObject.Exception.Response) {
                $streamReaderResponse = [System.IO.StreamReader]::new($ErrorObject.Exception.Response.GetResponseStream()).ReadToEnd()
                if (-not [string]::IsNullOrEmpty($streamReaderResponse)) {
                    $httpErrorObj.ErrorDetails = $streamReaderResponse
                }
            }
        }
        try {
            $httpErrorObj.FriendlyMessage = $httpErrorObj.ErrorDetails
        } catch {
            $httpErrorObj.FriendlyMessage = "Error: [$($httpErrorObj.ErrorDetails)] [$($_.Exception.Message)]"
        }
        Write-Output $httpErrorObj
    }
}
#endregion

try {
    $batchSize = 100
    $batchId = (New-Guid).guid

    $body = "<soapenv:Envelope xmlns:soapenv=`"http://schemas.xmlsoap.org/soap/envelope/`" xmlns:tem=`"http://tempuri.org/`" xmlns:ric=`"http://schemas.datacontract.org/2004/07/RicohKC.MyPrint.ConnectService.Accounts`">
   <soapenv:Header/>
   <soapenv:Body>
      <tem:ReadAccounts>
         <tem:readAccountsRequest>
            <ric:BatchId>$($batchId)</ric:BatchId>
            <ric:BatchSize>$($batchSize)</ric:BatchSize>
            <ric:SecurityToken>$($actionContext.Configuration.accessToken)</ric:SecurityToken>
         </tem:readAccountsRequest>
      </tem:ReadAccounts>
   </soapenv:Body>
</soapenv:Envelope>"

    $headers = @{
        SoapAction     = 'http://tempuri.org/IConnect/ReadAccounts'
        'Content-Type' = 'text/xml; charset=utf-8'
    }

    $importedAccounts = @()
    do {
        $params = @{
            Uri     = "$($actionContext.Configuration.BaseUrl)/RicohmyPrint/ConnectService/Connect.svc/SSL"
            Method  = 'POST'
            Body    = $body
            Headers = $headers

        }
        [xml]$response = Invoke-WebRequest @params -UseBasicParsing

        if ($response.Envelope.Body.ReadAccountsResponse.ReadAccountsResult.Accounts.Account) {
            $importedAccounts += $response.Envelope.Body.ReadAccountsResponse.ReadAccountsResult.Accounts.Account
        } elseif ($response.Envelope.Body.ReadAccountsResponse.ReadAccountsResult.Message.value) {
            throw $response.Envelope.Body.ReadAccountsResponse.ReadAccountsResult.Message.value
        }
    } until ($response.Envelope.Body.ReadAccountsResponse.ReadAccountsResult.AccountsRemaining -eq 0 -or $actionContext.DryRun)

    # Map the imported data to the account field mappings
    foreach ($importedAccount in $importedAccounts) {
        $account = Convert-CSXmlResponseToPSCustomObject -XmlResponse $importedAccount
        $data = $account

        $displayName = "$($account.FirstName) $($account.LastName)".trim(' ')
        if ([string]::IsNullOrEmpty($displayName)) {
            $displayName = $account.Identifier
        }

        Write-Output @{
            AccountReference = $account.Identifier
            DisplayName      = $displayName
            UserName         = $account.Identifier
            Enabled          = $false
            Data             = $data | Select-Object -Property $actionContext.ImportFields
        }
    }
    Write-Information 'Account data import completed'
} catch {
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-Ricoh-myPrintError -ErrorObject $ex
        Write-Warning "Could not import Ricoh-myPrint account. Error: $($errorObj.FriendlyMessage)"
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    } else {
        Write-Warning "Could not import Ricoh-myPrint account. Error: $($ex.Exception.Message)"
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
}