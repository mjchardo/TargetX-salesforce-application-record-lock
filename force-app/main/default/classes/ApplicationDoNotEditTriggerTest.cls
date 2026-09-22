@IsTest
private class ApplicationDoNotEditTriggerTest {

    private static final String LOCK_ERROR =
        'This Application is locked.';

    /*
     * Create a test Contact and Application.
     */
    private static TargetX_SRMb__Application__c createApplication(
        String major
    ) {
        Contact student = new Contact(
            LastName = 'Test Student'
        );

        insert student;

        TargetX_SRMb__Application__c app =
            new TargetX_SRMb__Application__c(
                TargetX_SRMb__Contact__c = student.Id,
                Do_Not_Edit__c = false,
                Major_Full__c = major
            );

        insert app;

        return app;
    }

    /*
     * Retrieve saved values for verification only.
     *
     * Do not reuse this queried record for DML.
     */
    private static TargetX_SRMb__Application__c getApplication(
        Id appId
    ) {
        return [
            SELECT Id,
                   TargetX_SRMb__Contact__c,
                   Do_Not_Edit__c,
                   Major_Full__c
            FROM TargetX_SRMb__Application__c
            WHERE Id = :appId
            LIMIT 1
        ];
    }

    /*
     * Verify a failure came from our locking trigger.
     */
    private static void assertLockError(
        Database.SaveResult result
    ) {
        System.assertEquals(
            false,
            result.isSuccess(),
            'The locked Application update should fail.'
        );

        Boolean foundLockError = false;

        for (Database.Error err : result.getErrors()) {
            if (err.getMessage().contains(LOCK_ERROR)) {
                foundLockError = true;
                break;
            }
        }

        System.assertEquals(
            true,
            foundLockError,
            'Expected the Application lock error.'
        );
    }

    /*
     * TEST 1:
     * Complete lock and unlock lifecycle.
     */
    @IsTest
    static void testCompleteLockLifecycle() {

        TargetX_SRMb__Application__c app =
            createApplication('Computer Science');

        Id appId = app.Id;

        Test.startTest();

        // 1. Confirm the record is initially unlocked.

        System.assertEquals(
            false,
            getApplication(appId).Do_Not_Edit__c,
            'New Application should be unlocked.'
        );

        // 2. Edit the Application while unlocked.

        update new TargetX_SRMb__Application__c(
            Id = appId,
            Major_Full__c = 'Mechanical Engineering'
        );

        System.assertEquals(
            'Mechanical Engineering',
            getApplication(appId).Major_Full__c,
            'Editing while unlocked should succeed.'
        );

        // 3. Check Do Not Edit.

        update new TargetX_SRMb__Application__c(
            Id = appId,
            Do_Not_Edit__c = true
        );

        System.assertEquals(
            true,
            getApplication(appId).Do_Not_Edit__c,
            'The Application should now be locked.'
        );

        // 4. Attempt to change Major_Full__c
        // while the Application is locked.

        Database.SaveResult blockedResult =
            Database.update(
                new TargetX_SRMb__Application__c(
                    Id = appId,
                    Major_Full__c = 'Data Science'
                ),
                false
            );

        assertLockError(blockedResult);

        System.assertEquals(
            'Mechanical Engineering',
            getApplication(appId).Major_Full__c,
            'The locked major must remain unchanged.'
        );

        // 5. Attempt to unlock and edit simultaneously.

        Database.SaveResult combinedResult =
            Database.update(
                new TargetX_SRMb__Application__c(
                    Id = appId,
                    Do_Not_Edit__c = false,
                    Major_Full__c = 'Cybersecurity'
                ),
                false
            );

        assertLockError(combinedResult);

        TargetX_SRMb__Application__c savedApp =
            getApplication(appId);

        System.assertEquals(
            true,
            savedApp.Do_Not_Edit__c,
            'The failed update must not unlock the record.'
        );

        System.assertEquals(
            'Mechanical Engineering',
            savedApp.Major_Full__c,
            'The failed update must not change the major.'
        );

        // 6. Uncheck Do Not Edit without changing
        // any other fields.

        update new TargetX_SRMb__Application__c(
            Id = appId,
            Do_Not_Edit__c = false
        );

        System.assertEquals(
            false,
            getApplication(appId).Do_Not_Edit__c,
            'Checkbox-only unlocking should succeed.'
        );

        // 7. Edit the Application after unlocking.

        update new TargetX_SRMb__Application__c(
            Id = appId,
            Major_Full__c = 'Cybersecurity'
        );

        System.assertEquals(
            'Cybersecurity',
            getApplication(appId).Major_Full__c,
            'Editing after unlocking should succeed.'
        );

        Test.stopTest();
    }

    /*
     * TEST 2:
     * Editing and locking in the same save
     * must be allowed when previously unlocked.
     */
    @IsTest
    static void testEditAndLockTogether() {

        TargetX_SRMb__Application__c app =
            createApplication('Computer Science');

        Id appId = app.Id;

        Test.startTest();

        update new TargetX_SRMb__Application__c(
            Id = appId,
            Major_Full__c = 'Data Science',
            Do_Not_Edit__c = true
        );

        Test.stopTest();

        TargetX_SRMb__Application__c savedApp =
            getApplication(appId);

        System.assertEquals(
            true,
            savedApp.Do_Not_Edit__c,
            'The Application should be locked.'
        );

        System.assertEquals(
            'Data Science',
            savedApp.Major_Full__c,
            'Editing and locking together should succeed.'
        );
    }

    /*
     * TEST 3:
     * A locked Application can be updated
     * when no protected field changes.
     */
    @IsTest
    static void testLockedApplicationNoChanges() {

        TargetX_SRMb__Application__c app =
            createApplication('Computer Science');

        Id appId = app.Id;

        // Lock the record using a sparse update.

        update new TargetX_SRMb__Application__c(
            Id = appId,
            Do_Not_Edit__c = true
        );

        Test.startTest();

        // Submit only the record ID.
        // No protected fields are changed.

        Database.SaveResult result =
            Database.update(
                new TargetX_SRMb__Application__c(
                    Id = appId
                ),
                false
            );

        Test.stopTest();

        System.assertEquals(
            true,
            result.isSuccess(),
            'An update without field changes should succeed.'
        );

        TargetX_SRMb__Application__c savedApp =
            getApplication(appId);

        System.assertEquals(
            true,
            savedApp.Do_Not_Edit__c,
            'The Application should remain locked.'
        );

        System.assertEquals(
            'Computer Science',
            savedApp.Major_Full__c,
            'The major should remain unchanged.'
        );
    }

    /*
     * TEST 4:
     * Bulk processing with 20 Applications.
     *
     * First 10: Locked, updates must fail.
     * Last 10: Unlocked, updates must succeed.
     */
    @IsTest
    static void testBulkUpdates() {

        Contact student = new Contact(
            LastName = 'Bulk Test Student'
        );

        insert student;

        List<TargetX_SRMb__Application__c> apps =
            new List<TargetX_SRMb__Application__c>();

        // Create 20 Applications.

        for (Integer i = 0; i < 20; i++) {

            apps.add(
                new TargetX_SRMb__Application__c(
                    TargetX_SRMb__Contact__c = student.Id,
                    Do_Not_Edit__c = false,
                    Major_Full__c = 'Original Major'
                )
            );
        }

        insert apps;

        // Lock the first 10 records.

        List<TargetX_SRMb__Application__c> toLock =
            new List<TargetX_SRMb__Application__c>();

        for (Integer i = 0; i < 10; i++) {

            toLock.add(
                new TargetX_SRMb__Application__c(
                    Id = apps[i].Id,
                    Do_Not_Edit__c = true
                )
            );
        }

        update toLock;

        // Prepare sparse update records.

        List<TargetX_SRMb__Application__c> updates =
            new List<TargetX_SRMb__Application__c>();

        for (Integer i = 0; i < 20; i++) {

            updates.add(
                new TargetX_SRMb__Application__c(
                    Id = apps[i].Id,
                    Major_Full__c = 'Updated Major'
                )
            );
        }

        Test.startTest();

        Database.SaveResult[] results =
            Database.update(updates, false);

        Test.stopTest();

        System.assertEquals(
            20,
            results.size(),
            'Expected 20 update results.'
        );

        // Verify the first 10 failed.

        for (Integer i = 0; i < 10; i++) {
            assertLockError(results[i]);
        }

        // Verify the last 10 succeeded.

        for (Integer i = 10; i < 20; i++) {

            System.assertEquals(
                true,
                results[i].isSuccess(),
                'Unlocked Application should update.'
            );
        }

        // Verify saved database values.

        Set<Id> appIds = new Set<Id>();
        Set<Id> lockedIds = new Set<Id>();

        for (Integer i = 0; i < 20; i++) {

            appIds.add(apps[i].Id);

            if (i < 10) {
                lockedIds.add(apps[i].Id);
            }
        }

        List<TargetX_SRMb__Application__c> savedApps = [
            SELECT Id,
                   Do_Not_Edit__c,
                   Major_Full__c
            FROM TargetX_SRMb__Application__c
            WHERE Id IN :appIds
        ];

        System.assertEquals(
            20,
            savedApps.size(),
            'All 20 Applications should exist.'
        );

        for (TargetX_SRMb__Application__c savedApp : savedApps) {

            if (lockedIds.contains(savedApp.Id)) {

                System.assertEquals(
                    true,
                    savedApp.Do_Not_Edit__c,
                    'Locked Application must stay locked.'
                );

                System.assertEquals(
                    'Original Major',
                    savedApp.Major_Full__c,
                    'Locked major must not change.'
                );

            } else {

                System.assertEquals(
                    false,
                    savedApp.Do_Not_Edit__c,
                    'Unlocked Application must stay unlocked.'
                );

                System.assertEquals(
                    'Updated Major',
                    savedApp.Major_Full__c,
                    'Unlocked major should update.'
                );
            }
        }
    }
}