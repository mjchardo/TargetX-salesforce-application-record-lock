trigger ApplicationDoNotEditTrigger
    on TargetX_SRMb__Application__c (before update) {

    // Identify Applications that were already locked.
    List<TargetX_SRMb__Application__c> lockedApps =
        new List<TargetX_SRMb__Application__c>();

    for (TargetX_SRMb__Application__c newApp : Trigger.new) {

        TargetX_SRMb__Application__c oldApp =
            Trigger.oldMap.get(newApp.Id);

        if (oldApp.Do_Not_Edit__c == true) {
            lockedApps.add(newApp);
        }
    }

    // Exit immediately if no records were locked.
    if (lockedApps.isEmpty()) {
        return;
    }

    // Retrieve field metadata only once.
    Map<String, Schema.SObjectField> fieldMap =
        Schema.SObjectType.TargetX_SRMb__Application__c
            .fields.getMap();

    // Build the list of fields to protect.
    List<String> protectedFields = new List<String>();

    for (String fieldName : fieldMap.keySet()) {

        // The checkbox must always remain editable.
        if (fieldName == 'Do_Not_Edit__c') {
            continue;
        }

        Schema.DescribeFieldResult fieldInfo =
            fieldMap.get(fieldName).getDescribe();

        // Exclude calculated and non-updateable fields.
        if (!fieldInfo.isUpdateable() ||
            fieldInfo.isCalculated()) {
            continue;
        }

        protectedFields.add(fieldName);
    }

    // Compare only previously locked records.
    for (TargetX_SRMb__Application__c newApp : lockedApps) {

        TargetX_SRMb__Application__c oldApp =
            Trigger.oldMap.get(newApp.Id);

        for (String fieldName : protectedFields) {

            Object oldValue = oldApp.get(fieldName);
            Object newValue = newApp.get(fieldName);

            // Detect any unauthorized field change.
            if (oldValue != newValue) {

                newApp.addError(
                    'This Application is locked. ' +
                    'Uncheck Do Not Edit and save the record ' +
                    'before making any other changes.'
                );

                // Stop comparing fields on this record.
                break;
            }
        }
    }
}