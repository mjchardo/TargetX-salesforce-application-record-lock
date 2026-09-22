
# Salesforce Application Record Lock

A reversible record-locking solution built with Salesforce Apex.

## Overview

This project implements a custom locking mechanism for Salesforce Application records.

Users can lock an Application by selecting the **Do Not Edit** checkbox. Once locked, changes to other editable fields are rejected.

Users can unlock the Application by unchecking the checkbox and saving the record separately.
<img width="732" height="418" alt="image" src="https://github.com/user-attachments/assets/30d8f795-455f-4fc8-a405-23ba1289f23c" />

## User Story

As a Salesforce Administrator, I need the ability to lock historical Application records from being modified by end users and
integrations so that I can preserve historical enrollment data, maintain data integrity, and ensure accurate year-over-year reporting
and dashboard comparisons.

## Business Problem

Historical Application records are subject to updates from Salesforce integrations and automated processes. These updates can
unintentionally modify data from previous admission cycles, potentially compromising the accuracy of historical reporting and 
year-over-year enrollment comparisons.

## Features

- Reversible record locking
- Dynamic field comparison using Salesforce Schema
- Bulk-safe Apex trigger
- Prevents simultaneous unlocking and editing
- Supports newly added editable fields
- Apex unit tests covering locking and unlocking

## Business Requirements

| Scenario | Expected Result |
|---|---|
| Create an unlocked Application | Allowed |
| Edit an unlocked Application | Allowed |
| Check Do Not Edit | Allowed |
| Edit another field while locked | Blocked |
| Uncheck Do Not Edit only | Allowed |
| Uncheck and edit simultaneously | Blocked |
| Edit after unlocking | Allowed |

## Technical Implementation

The before-update Apex trigger compares the previous and proposed values of editable Application fields.

The trigger:

1. Identifies previously locked records.
2. Retrieves field metadata once per execution.
3. Excludes the Do Not Edit checkbox.
4. Compares protected field values.
5. Uses `addError()` to reject unauthorized changes.

No additional SOQL queries or DML operations are performed by the locking trigger.

## Testing

The Apex test class includes four test methods:

- Complete lock and unlock lifecycle
- Editing and locking in the same transaction
- Updating a locked record without field changes
- Bulk processing with partial success

**Test Results: 4 of 4 tests passed.**

## Requirements

This implementation targets a Salesforce environment with the TargetX Application managed-package object.

**Object:**
`TargetX_SRMb__Application__c`

**Custom Fields:**
- `Do_Not_Edit__c`
- `Major_Full__c` (used in tests)

**Required Student Lookup:**
`TargetX_SRMb__Contact__c`

## Limitations

- Does not prevent record deletion.
- Does not lock separate related records.
- Excludes non-updateable and calculated fields.
- Field selection depends on Apex describe permissions.
- Other automation may affect the final transaction.
- Requires adaptation for environments without TargetX.

## Why Apex Instead of a Validation Rule?

A Salesforce Validation Rule was considered as an alternative for protecting historical Application records. However, the requirement to
allow reversible locking while protecting all other editable fields presented a maintainability challenge.

A validation rule would require explicitly identifying each protected field using ISCHANGED(). As new fields are introduced to the
Application object, the rule would need to be manually updated to maintain comprehensive protection.

An Apex trigger was implemented to dynamically retrieve eligible Application fields through Salesforce Schema and compare their previous
and proposed values.

This approach provides a scalable locking mechanism that supports evolving data models, prevents unauthorized modifications by users and
integrations, and allows records to be unlocked when legitimate corrections are required.

The solution helps preserve historical Application data used in year-over-year admissions reporting and dashboards.

## Author

**Matthew Guichardo**

Salesforce Certified Platform Developer I
