#################################################
# HelloID-Conn-Prov-Target-Ricoh-myPrint-Create
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
    # Initial Assignments
    $outputContext.AccountReference = 'Currently not available'

    # Validate correlation configuration
    if ($actionContext.CorrelationConfiguration.Enabled) {
        $correlationField = $actionContext.CorrelationConfiguration.AccountField
        $correlationValue = $actionContext.CorrelationConfiguration.PersonFieldValue

        if ([string]::IsNullOrEmpty($($correlationField))) {
            throw 'Correlation is enabled but not configured correctly'
        }
        if ([string]::IsNullOrEmpty($($correlationValue))) {
            throw 'Correlation is enabled but [accountFieldValue] is empty. Please make sure it is correctly mapped'
        }

        $body = "<soapenv:Envelope xmlns:soapenv=`"http://schemas.xmlsoap.org/soap/envelope/`" xmlns:tem=`"http://tempuri.org/`" xmlns:ric=`"http://schemas.datacontract.org/2004/07/RicohKC.MyPrint.ConnectService`">
    <soapenv:Header/>
    <soapenv:Body>
        <tem:ReadAccount>
            <tem:readAccountRequest>
                <ric:Identifier>$($correlationValue)</ric:Identifier>
                <ric:SecurityToken>$($actionContext.Configuration.accessToken)</ric:SecurityToken>
            </tem:readAccountRequest>
        </tem:ReadAccount>
    </soapenv:Body>
</soapenv:Envelope>"

        $headers = @{
            SoapAction     = 'http://tempuri.org/IConnect/ReadAccount'
            'Content-Type' = 'text/xml; charset=utf-8'
        }

        $params = @{
            Uri     = "$($actionContext.Configuration.BaseUrl)/RicohmyPrint/ConnectService/Connect.svc/SSL"
            Method  = 'POST'
            Body    = $body
            Headers = $headers

        }
        [xml]$response = Invoke-WebRequest @params -UseBasicParsing

        if ($response.Envelope.Body.ReadAccountResponse.ReadAccountResult.Message.value -eq 'account not found') {
            $correlatedAccount = $null
        } elseif ($response.Envelope.Body.ReadAccountResponse.ReadAccountResult.Account.nil -eq $true) {
            throw "$($response.Envelope.Body.ReadAccountResponse.ReadAccountResult.Message.value)"
        } else {
            $correlatedAccount = Convert-CSXmlResponseToPSCustomObject -XmlResponse $response.Envelope.Body.ReadAccountResponse.ReadAccountResult.Account
        }
    } else {
        throw 'Since this connector only correlates and deletes users, correlation must be enabled.'
    }

    if ($null -eq $correlatedAccount) {
        throw "No account found on field [$($correlationField)] with value: [$($correlationValue)]."
    } elseif (($correlatedAccount | Measure-Object).count -eq 1) {
        $action = 'CorrelateAccount'
    } elseif (($correlatedAccount | Measure-Object).count -gt 1) {
        throw "Multiple accounts found on field [$($correlationField)] with value: [$($correlationValue)]."
    }

    # Process
    switch ($action) {
        'CorrelateAccount' {
            Write-Information 'Correlating Ricoh-myPrint account'
            $outputContext.Data = ($correlatedAccount | Select-Object -Property $actionContext.data.PSObject.Properties.Name)
            $outputContext.AccountReference = $correlatedAccount.Identifier
            $outputContext.AccountCorrelated = $true
            $auditLogMessage = "Correlated account: [$($outputContext.AccountReference)] on field: [$($correlationField)] with value: [$($correlationValue)]"
            break
        }
    }

    $outputContext.success = $true
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Action  = $action
            Message = $auditLogMessage
            IsError = $false
        })
} catch {
    $outputContext.success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-Ricoh-myPrintError -ErrorObject $ex
        $auditMessage = "Could not create or correlate Ricoh-myPrint account. Error: $($errorObj.FriendlyMessage)"
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    } else {
        $auditMessage = "Could not create or correlate Ricoh-myPrint account. Error: $($ex.Exception.Message)"
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditMessage
            IsError = $true
        })
}