# HelloID-Conn-Prov-Target-Ricoh-myPrint

> [!IMPORTANT]
> This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.

<p align="center">
  <img src="">
</p>

## Table of contents

- [HelloID-Conn-Prov-Target-Ricoh-myPrint](#helloid-conn-prov-target-ricoh-myprint)
  - [Table of contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Supported  features](#supported--features)
  - [Getting started](#getting-started)
    - [Prerequisites](#prerequisites)
    - [Connection settings](#connection-settings)
    - [Correlation configuration](#correlation-configuration)
    - [Field mapping](#field-mapping)
    - [Account Reference](#account-reference)
  - [Remarks](#remarks)
    - [Soap connector](#soap-connector)
    - [Correlation and delete only](#correlation-and-delete-only)
    - [Correlation Based on Email Address](#correlation-based-on-email-address)
    - [Import script](#import-script)
    - [Force delete;](#force-delete)
    - [Not all actions available in reconciliation](#not-all-actions-available-in-reconciliation)
  - [Development resources](#development-resources)
    - [API endpoints](#api-endpoints)
  - [Getting help](#getting-help)
  - [HelloID docs](#helloid-docs)

## Introduction

_HelloID-Conn-Prov-Target-Ricoh-myPrint_ is a _target_ connector. _Ricoh-myPrint_ provides a set of REST API's that allow you to programmatically interact with its data.

## Supported  features

The following features are available:

| Feature                                   | Supported | Actions          | Remarks                                             |
| ----------------------------------------- | --------- | ---------------- | --------------------------------------------------- |
| **Account Lifecycle**                     | ✅         | Create, Delete   | Create only correlates, no enable disable or update |
| **Permissions**                           | ❌         | -                |                                                     |
| **Resources**                             | ❌         | -                |                                                     |
| **Entitlement Import: Accounts**          | ✅         | -                |                                                     |
| **Entitlement Import: Permissions**       | ❌         | -                |                                                     |
| **Governance Reconciliation Resolutions** | ✅         | - Create, Delete | Create only correlates, no enable disable or update |

## Getting started

### Prerequisites

- **IP Whitelisting**:<br>
  The IP addresses used by the connector must be whitelisted on the target system's firewall to allow access. Ensure that the firewall rules are configured to permit incoming and outgoing connections from these IPs.

### Connection settings

The following settings are required to connect to the API.

| Setting     | Description                            | Mandatory |
| ----------- | -------------------------------------- | --------- |
| AccessToken | The access token to connect to the API | Yes       |
| BaseUrl     | The URL to the API                     | Yes       |

### Correlation configuration

The correlation configuration is used to specify which properties will be used to match an existing account within _Ricoh-myPrint_ to a person in _HelloID_.

| Setting                   | Value                                    |
| ------------------------- | ---------------------------------------- |
| Enable correlation        | `True`                                   |
| Person correlation field  | `Accounts.MicrosoftActiveDirectory.mail` |
| Account correlation field | `Identifier`                             |

> [!TIP]
> _For more information on correlation, please refer to our correlation [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems/correlation.html) pages_.

### Field mapping

The field mapping can be imported by using the _fieldMapping.json_ file.

### Account Reference

The account reference is populated with the property `Identifier` property from _Ricoh-myPrint_

## Remarks

### Soap connector
- **Soap**: The connector is based on soap, therefore all the body's are hardcoded in the scripts.

### Correlation and delete only
- **Only correlate and delete**: The connector only correlates and deletes account in _Ricoh-myPrint_.
- **Force delete property**: The delete request has a propery named `ForceDelete` with a default value of 0. More information on the functionality of this property can be found at [Force delete;](#force-delete)

### Correlation Based on Email Address
- **Email Address Correlation**: The connector relies on email addresses to correlate and match records between systems. Ensure that email addresses are accurately maintained and consistent across systems to avoid issues with data synchronization and matching.
- **No update of account reference possible**: The API does not support an update request. This means that if a user's email changes, the account reference cannot be updated in Ricoh-Myprint.

### Import script
- **import script takes a while**: The import script may take some time to import all users. To ensure you see results in preview mode, a filter based on the $dryrun variable is applied within the pagination loop.


### Force delete;
- **0 (Default)**: account will be deleted. The account is deleted only if the 3rd party print system is active. If the user has a positive balance and:

  - voucher refund is enabled the user receives a
refund voucher by email.
  - refunding by bank account is enabled the
user is not deleted.

- **1**: account will always be deleted even if refunding by
bank account is enabled and the 3rd party print system
maintaining the balances is not responding. The user
receives a refunding voucher in case of a positive
balance and refunding by voucher is enabled.

- **NOTE**: With ForceDelete set to 1, the account is always deleted
in myPrint and in the 3rd party print system. If the 3rd
party print system is not responding the account remains
in the 3rd party print system with its balance.

- **NOTE**: With ForceDelete set to 1, the account is not deleted if
the option “Delete account in 3rd party print system” in
“Account configuration” is disabled. In case the 3rd party
print system is responding the account’s balance is set to
zero.

  
### Not all actions available in reconciliation 
- **No enable and disable actions in reconciliation**: Since there are no enable and disable actions the enabled property gets mapped to false in the import script.
## Development resources

### API endpoints

The following soap actions are used by the connector

| Endpoint       | Description                |
| -------------- | -------------------------- |
| /ReadAccount   | Retrieve user information  |
| /ReadAccounts  | Retrieve users information |
| /DeleteAccount | delete user                |

## Getting help

> [!TIP]
> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems.html) pages_.

> [!TIP]
>  _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com/forum/helloid-connectors/provisioning/5374-helloid-conn-prov-target-ricoh-myprint)_.

## HelloID docs

The official HelloID documentation can be found at: https://docs.helloid.com/
