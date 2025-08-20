##################################################
# HelloID-Conn-Prov-Target-Ricoh-myPrint-Delete
# PowerShell V2
##################################################

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
    # Verify if [aRef] has a value
    if ([string]::IsNullOrEmpty($($actionContext.References.Account))) {
        throw 'The account reference could not be found'
    }

    $body = "<soapenv:Envelope xmlns:soapenv=`"http://schemas.xmlsoap.org/soap/envelope/`" xmlns:tem=`"http://tempuri.org/`" xmlns:ric=`"http://schemas.datacontract.org/2004/07/RicohKC.MyPrint.ConnectService`">
    <soapenv:Header/>
    <soapenv:Body>
        <tem:ReadAccount>
            <tem:readAccountRequest>
                <ric:Identifier>$($actionContext.References.Account)</ric:Identifier>
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

    if ($null -ne $correlatedAccount) {
        $action = 'DeleteAccount'
    } else {
        $action = 'NotFound'
    }

    # Process
    switch ($action) {
        'DeleteAccount' {
            # Cast forceDeleteEnabled to int to get the necessary 0 and 1 values
            $deleteBody = "<soapenv:Envelope xmlns:soapenv=`"http://schemas.xmlsoap.org/soap/envelope/`" xmlns:tem=`"http://tempuri.org/`" xmlns:ric=`"http://schemas.datacontract.org/2004/07/RicohKC.MyPrint.ConnectService`" xmlns:ric1=`"http://schemas.datacontract.org/2004/07/RicohKC.MyPrint.ConnectService.Accounts`">
    <soapenv:Header/>
    <soapenv:Body>
        <tem:DeleteAccount>
            <tem:DeleteAccountRequest>
                <ric:Identifier>$($actionContext.References.Account)</ric:Identifier>
                <ric:SecurityToken>$($actionContext.Configuration.accessToken)</ric:SecurityToken>
                <ric1:ForceDelete>$([int]$actionContext.Configuration.forceDeleteEnabled)</ric1:ForceDelete>
            </tem:DeleteAccountRequest>
        </tem:DeleteAccount>
    </soapenv:Body>
</soapenv:Envelope>"

            $deleteHeaders = @{
                SoapAction     = 'http://tempuri.org/IConnect/DeleteAccount'
                'Content-Type' = 'text/xml; charset=utf-8'
            }

            $params = @{
                Uri     = "$($actionContext.Configuration.BaseUrl)/RicohmyPrint/ConnectService/Connect.svc/SSL"
                Method  = 'POST'
                Body    = $deleteBody
                Headers = $deleteHeaders

            }

            if (-not($actionContext.DryRun -eq $true)) {
                Write-Information "Deleting Ricoh-myPrint account with accountReference: [$($actionContext.References.Account)]"
                [xml]$response = Invoke-WebRequest @params -UseBasicParsing
            } else {
                Write-Information "[DryRun] Delete Ricoh-myPrint account with accountReference: [$($actionContext.References.Account)], will be executed during enforcement"
            }

            $outputContext.Success = $true
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "Ricoh-myPrint account: [$($actionContext.References.Account)] Delete account was successful"
                    IsError = $false
                })
            break
        }

        'NotFound' {
            Write-Information "Ricoh-myPrint account: [$($actionContext.References.Account)] could not be found, indicating that it may have been deleted"
            $outputContext.Success = $true
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "Ricoh-myPrint account: [$($actionContext.References.Account)] could not be found, indicating that it may have been deleted"
                    IsError = $false
                })
            break
        }
    }
} catch {
    $outputContext.success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-Ricoh-myPrintError -ErrorObject $ex
        $auditMessage = "Could not delete Ricoh-myPrint account. Error: $($errorObj.FriendlyMessage)"
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    } else {
        $auditMessage = "Could not delete Ricoh-myPrint account. Error: $($_.Exception.Message)"
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditMessage
            IsError = $true
        })
}