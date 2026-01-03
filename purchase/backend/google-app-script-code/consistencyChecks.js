/**
 * Consistency Checks Module
 * 
 * This module handles foreign key consistency validation and cleanup.
 * It identifies and deletes records with invalid foreign key references.
 */

const consistencyChecks = {
    /**
     * Check for null or empty UUIDs in a table
     * @param {string} tableName - Name of the table to check
     * @returns {Object} Results with rows that have null/empty UUIDs
     */
    checkNullUUIDs(tableName) {
        const ss = SpreadsheetApp.getActiveSpreadsheet();
        const sheet = ss.getSheetByName(tableName);

        if (!sheet) {
            Logger.log(`Warning: Sheet '${tableName}' not found`);
            return { tableName, invalidRows: [], rowsToDelete: [] };
        }

        const lastRow = sheet.getLastRow();
        if (lastRow <= 1) {
            Logger.log(`Table '${tableName}' is empty (only header row)`);
            return { tableName, invalidRows: [], rowsToDelete: [] };
        }

        const tableMetaInfo = TABLE_META_INFO[tableName];
        if (!tableMetaInfo) {
            Logger.log(`Warning: No metadata found for table '${tableName}'`);
            return { tableName, invalidRows: [], rowsToDelete: [] };
        }

        const uuidColumnIndex = tableMetaInfo.COLUMN_INDICES.uuid;
        const columnCount = tableMetaInfo.COLUMN_COUNT;

        // Get all data (UUID column and all columns to check if row is completely empty)
        const allData = sheet.getRange(2, 1, lastRow - 1, columnCount).getValues();

        const invalidRows = [];
        const rowsToDelete = [];

        for (let i = 0; i < allData.length; i++) {
            const row = allData[i];
            const uuid = row[uuidColumnIndex];
            const rowNumber = i + 2; // +2 because arrays are 0-indexed and we skip header

            // Check if entire row is empty (all cells are empty/null/undefined)
            const isRowCompletelyEmpty = row.every(cell =>
                cell === '' || cell === null || cell === undefined
            );

            // Skip completely empty rows (these are just blank rows in the sheet)
            if (isRowCompletelyEmpty) {
                continue;
            }

            // If row has data but UUID is missing, it's invalid
            if (!uuid || uuid === '' || uuid === null || uuid === undefined) {
                invalidRows.push({
                    rowNumber,
                    issue: 'NULL or EMPTY UUID'
                });
                rowsToDelete.push(rowNumber);
            }
        }

        Logger.log(`Found ${invalidRows.length} rows with null/empty UUIDs in table '${tableName}'`);

        return {
            tableName,
            invalidRows,
            rowsToDelete
        };
    },

    /**
     * Check for duplicate UUIDs in a table
     * @param {string} tableName - Name of the table to check
     * @returns {Object} Results with rows that have duplicate UUIDs
     */
    checkDuplicateUUIDs(tableName) {
        const ss = SpreadsheetApp.getActiveSpreadsheet();
        const sheet = ss.getSheetByName(tableName);

        if (!sheet) {
            Logger.log(`Warning: Sheet '${tableName}' not found`);
            return { tableName, duplicates: [], rowsToDelete: [] };
        }

        const lastRow = sheet.getLastRow();
        if (lastRow <= 1) {
            Logger.log(`Table '${tableName}' is empty (only header row)`);
            return { tableName, duplicates: [], rowsToDelete: [] };
        }

        const tableMetaInfo = TABLE_META_INFO[tableName];
        if (!tableMetaInfo) {
            Logger.log(`Warning: No metadata found for table '${tableName}'`);
            return { tableName, duplicates: [], rowsToDelete: [] };
        }

        const uuidColumnIndex = tableMetaInfo.COLUMN_INDICES.uuid;
        const uuidData = sheet.getRange(2, uuidColumnIndex + 1, lastRow - 1, 1).getValues();

        const uuidMap = new Map(); // Map of UUID -> [row numbers]
        const duplicates = [];
        const rowsToDelete = [];

        // Build map of UUIDs to row numbers
        for (let i = 0; i < uuidData.length; i++) {
            const uuid = uuidData[i][0];
            const rowNumber = i + 2;

            // Skip null/empty UUIDs (handled by checkNullUUIDs)
            if (!uuid || uuid === '') {
                continue;
            }

            if (!uuidMap.has(uuid)) {
                uuidMap.set(uuid, []);
            }
            uuidMap.get(uuid).push(rowNumber);
        }

        // Find duplicates (keep first occurrence, mark rest for deletion)
        for (const [uuid, rowNumbers] of uuidMap.entries()) {
            if (rowNumbers.length > 1) {
                // Keep the first occurrence, delete the rest
                const duplicateRows = rowNumbers.slice(1); // All except the first
                duplicates.push({
                    uuid,
                    firstRow: rowNumbers[0],
                    duplicateRows,
                    count: rowNumbers.length
                });
                rowsToDelete.push(...duplicateRows);
            }
        }

        Logger.log(`Found ${duplicates.length} duplicate UUIDs in table '${tableName}' (${rowsToDelete.length} rows to delete)`);

        return {
            tableName,
            duplicates,
            rowsToDelete
        };
    },

    /**
     * Load all UUIDs from a target table into a Set for fast lookup
     * @param {string} tableName - Name of the table to load UUIDs from
     * @returns {Set<string>} Set of all UUIDs in the table
     */
    loadTargetUUIDs(tableName) {
        const ss = SpreadsheetApp.getActiveSpreadsheet();
        const sheet = ss.getSheetByName(tableName);

        if (!sheet) {
            Logger.log(`Warning: Sheet '${tableName}' not found`);
            return new Set();
        }

        const lastRow = sheet.getLastRow();
        if (lastRow <= 1) {
            // Only header row or empty sheet
            return new Set();
        }

        const uuidColumnIndex = TABLE_META_INFO[tableName].COLUMN_INDICES.uuid;
        const uuidData = sheet.getRange(2, uuidColumnIndex + 1, lastRow - 1, 1).getValues();

        const uuidSet = new Set();
        for (let i = 0; i < uuidData.length; i++) {
            const uuid = uuidData[i][0];
            if (uuid && uuid !== '') {
                uuidSet.add(uuid);
            }
        }

        Logger.log(`Loaded ${uuidSet.size} UUIDs from table '${tableName}'`);
        return uuidSet;
    },

    /**
     * Check a single table for foreign key violations
     * @param {string} tableName - Name of the child table to check
     * @returns {Object} Results object with invalid records and deletion info
     */
    checkTableConsistency(tableName) {
        const ss = SpreadsheetApp.getActiveSpreadsheet();
        const sheet = ss.getSheetByName(tableName);

        if (!sheet) {
            Logger.log(`Warning: Sheet '${tableName}' not found`);
            return { tableName, invalidRecords: [], deleted: 0 };
        }

        const relationships = TABLE_DEFINITIONS[tableName]?.FOREIGN_KEY_RELATIONSHIPS;
        if (!relationships || relationships.length === 0) {
            Logger.log(`No foreign key relationships defined for table '${tableName}'`);
            return { tableName, invalidRecords: [], deleted: 0 };
        }

        Logger.log(`Checking consistency for table '${tableName}'...`);

        // Load all target UUIDs into Sets for fast lookup
        const targetUUIDSets = {};
        for (const rel of relationships) {
            if (!targetUUIDSets[rel.targetTable]) {
                targetUUIDSets[rel.targetTable] = this.loadTargetUUIDs(rel.targetTable);
            }
        }

        // Get all data from the child table
        const lastRow = sheet.getLastRow();
        if (lastRow <= 1) {
            Logger.log(`Table '${tableName}' is empty (only header row)`);
            return { tableName, invalidRecords: [], deleted: 0 };
        }

        const tableMetaInfo = TABLE_META_INFO[tableName];
        const lastCol = tableMetaInfo.COLUMN_COUNT;
        const data = sheet.getRange(2, 1, lastRow - 1, lastCol).getValues();

        // Track rows to delete (in reverse order for safe deletion)
        const rowsToDelete = [];
        const invalidRecords = [];

        // Check each row for foreign key violations
        for (let i = 0; i < data.length; i++) {
            const row = data[i];
            const rowNumber = i + 2; // +2 because arrays are 0-indexed and we skip header
            let hasViolation = false;
            const violations = [];

            for (const rel of relationships) {
                const fkColumnIndex = tableMetaInfo.COLUMN_INDICES[rel.column];
                const foreignKeyValue = row[fkColumnIndex];

                // Skip null/empty foreign keys (these might be optional)
                if (!foreignKeyValue || foreignKeyValue === '') {
                    continue;
                }

                // Check if the foreign key exists in the target table
                const targetSet = targetUUIDSets[rel.targetTable];
                if (!targetSet.has(foreignKeyValue)) {
                    hasViolation = true;
                    violations.push({
                        column: rel.column,
                        value: foreignKeyValue,
                        targetTable: rel.targetTable
                    });
                }
            }

            if (hasViolation) {
                const uuidColumnIndex = tableMetaInfo.COLUMN_INDICES.uuid;
                const recordUUID = row[uuidColumnIndex];

                invalidRecords.push({
                    rowNumber,
                    uuid: recordUUID,
                    violations
                });
                rowsToDelete.push(rowNumber);
            }
        }

        Logger.log(`Found ${invalidRecords.length} invalid records in table '${tableName}'`);

        return {
            tableName,
            invalidRecords,
            rowsToDelete
        };
    },

    /**
     * Delete invalid records from a table
     * @param {string} tableName - Name of the table
     * @param {Array<number>} rowsToDelete - Array of row numbers to delete
     * @returns {number} Number of rows deleted
     */
    deleteInvalidRecords(tableName, rowsToDelete) {
        if (!rowsToDelete || rowsToDelete.length === 0) {
            return 0;
        }

        const ss = SpreadsheetApp.getActiveSpreadsheet();
        const sheet = ss.getSheetByName(tableName);

        if (!sheet) {
            Logger.log(`Warning: Sheet '${tableName}' not found`);
            return 0;
        }

        // Sort rows in descending order to delete from bottom to top
        // This prevents row number shifts during deletion
        rowsToDelete.sort((a, b) => b - a);

        Logger.log(`Deleting ${rowsToDelete.length} invalid records from table '${tableName}'...`);

        for (const rowNumber of rowsToDelete) {
            sheet.deleteRow(rowNumber);
        }

        Logger.log(`Successfully deleted ${rowsToDelete.length} records from table '${tableName}'`);
        return rowsToDelete.length;
    },

    /**
     * Log changes to the change log after deleting records
     * @param {string} tableName - Name of the table
     * @param {Array<Object>} invalidRecords - Array of invalid records with UUIDs
     */
    logDeletions(tableName, invalidRecords) {
        if (!invalidRecords || invalidRecords.length === 0) {
            return;
        }

        const uuids = invalidRecords.map(record => record.uuid).filter(uuid => uuid);

        if (uuids.length > 0 && typeof changeLog !== 'undefined' && changeLog.logChanges) {
            const updatedAt = new Date();
            changeLog.logChanges(tableName, uuids, CHANGE_MODE_DELETE, updatedAt);
            Logger.log(`Logged ${uuids.length} deletions to change log for table '${tableName}'`);
        }
    },

    /**
     * Check UUID integrity for a table (null/empty and duplicates)
     * @param {string} tableName - Name of the table to check
     * @param {boolean} simulate - If true, only report. If false, delete invalid rows
     * @returns {Object} Results with UUID validation issues
     */
    checkUUIDIntegrity(tableName, simulate = false) {
        Logger.log(`\nChecking UUID integrity for '${tableName}'...`);

        const nullCheck = this.checkNullUUIDs(tableName);
        const duplicateCheck = this.checkDuplicateUUIDs(tableName);

        const totalIssues = nullCheck.invalidRows.length + duplicateCheck.duplicates.length;
        const totalRowsToDelete = [...new Set([...nullCheck.rowsToDelete, ...duplicateCheck.rowsToDelete])];

        if (totalIssues > 0) {
            Logger.log(`  ⚠ UUID integrity issues in '${tableName}':`);

            if (nullCheck.invalidRows.length > 0) {
                Logger.log(`    • ${nullCheck.invalidRows.length} rows with NULL/EMPTY UUIDs`);
                if (nullCheck.invalidRows.length <= 10) {
                    for (const row of nullCheck.invalidRows) {
                        Logger.log(`      - Row ${row.rowNumber}: ${row.issue}`);
                    }
                }
            }

            if (duplicateCheck.duplicates.length > 0) {
                Logger.log(`    • ${duplicateCheck.duplicates.length} duplicate UUIDs (${duplicateCheck.rowsToDelete.length} duplicate rows)`);
                if (duplicateCheck.duplicates.length <= 10) {
                    for (const dup of duplicateCheck.duplicates) {
                        Logger.log(`      - UUID '${dup.uuid}': appears ${dup.count} times (keeping row ${dup.firstRow}, would delete rows ${dup.duplicateRows.join(', ')})`);
                    }
                }
            }

            if (simulate) {
                Logger.log(`  📊 SIMULATION: Would delete ${totalRowsToDelete.length} rows with UUID issues`);
            } else {
                const deletedCount = this.deleteInvalidRecords(tableName, totalRowsToDelete);
                Logger.log(`  ✓ CLEANUP: Deleted ${deletedCount} rows with UUID issues`);
            }
        } else {
            Logger.log(`  ✓ UUID integrity OK in '${tableName}'`);
        }

        return {
            tableName,
            nullUUIDs: nullCheck.invalidRows.length,
            duplicateUUIDs: duplicateCheck.duplicates.length,
            duplicateRows: duplicateCheck.rowsToDelete.length,
            totalIssues,
            rowsToDelete: totalRowsToDelete,
            deleted: simulate ? 0 : totalRowsToDelete.length,
            wouldDelete: simulate ? totalRowsToDelete.length : 0
        };
    },

    /**
     * Check and clean a specific table
     * @param {string} tableName - Name of the table to check and clean
     * @param {boolean} simulate - If true, only simulate and report (don't delete). If false, perform cleanup (default: false)
     * @returns {Object} Results object with summary
     */
    checkAndCleanTable(tableName, simulate = false) {
        Logger.log(`\n${'='.repeat(60)}`);
        Logger.log(`Checking table: ${tableName}`);
        Logger.log('='.repeat(60));

        const result = this.checkTableConsistency(tableName);

        if (result.invalidRecords.length > 0) {
            Logger.log(`\n⚠ Invalid records found in '${tableName}': ${result.invalidRecords.length}`);

            // Group violations by type for better reporting
            const violationsByType = {};
            for (const record of result.invalidRecords) {
                for (const violation of record.violations) {
                    const key = `${violation.column} -> ${violation.targetTable}`;
                    if (!violationsByType[key]) {
                        violationsByType[key] = 0;
                    }
                    violationsByType[key]++;
                }
            }

            Logger.log(`\n  Violation breakdown:`);
            for (const [violationType, count] of Object.entries(violationsByType)) {
                Logger.log(`    • ${violationType}: ${count} invalid references`);
            }

            // Show detailed records only if count is manageable
            if (result.invalidRecords.length <= 20) {
                Logger.log(`\n  Detailed invalid records:`);
                for (const record of result.invalidRecords) {
                    Logger.log(`    Row ${record.rowNumber} (UUID: ${record.uuid}):`);
                    for (const violation of record.violations) {
                        Logger.log(`      - ${violation.column}: '${violation.value}' not found in ${violation.targetTable}`);
                    }
                }
            } else {
                Logger.log(`\n  (${result.invalidRecords.length} records - too many to list individually)`);
            }

            if (simulate) {
                result.deleted = 0;
                result.wouldDelete = result.invalidRecords.length;
                Logger.log(`\n  📊 SIMULATION: ${result.invalidRecords.length} records would be deleted`);
            } else {
                const deletedCount = this.deleteInvalidRecords(tableName, result.rowsToDelete);
                this.logDeletions(tableName, result.invalidRecords);
                result.deleted = deletedCount;
                result.wouldDelete = 0;
                Logger.log(`\n  ✓ CLEANUP: Deleted ${deletedCount} invalid records`);
            }
        } else {
            Logger.log(`✓ No consistency issues found in '${tableName}'`);
            result.deleted = 0;
            result.wouldDelete = 0;
        }

        return result;
    },

    /**
     * Check and clean all tables with foreign key relationships
     * @param {boolean} simulate - If true, only simulate and report (don't delete). If false, perform cleanup (default: true for safety)
     * @returns {Object} Summary of all checks and cleanups
     */
    checkAndCleanAllTables(simulate = true) {
        const mode = simulate ? 'SIMULATION MODE' : 'CLEANUP MODE';
        Logger.log('\n' + '='.repeat(80));
        Logger.log('COMPREHENSIVE CONSISTENCY CHECK - ' + mode);
        Logger.log('='.repeat(80));
        Logger.log(`Mode: ${simulate ? '📊 SIMULATION (no deletions)' : '🗑️  CLEANUP (will delete invalid records)'}`);
        Logger.log(`Timestamp: ${new Date().toISOString()}\n`);

        const ss = SpreadsheetApp.getActiveSpreadsheet();
        const context = utils.getExecutionContext();

        if (context.canShowToast) {
            ss.toast(`Starting consistency check (${simulate ? 'simulation' : 'cleanup'})...`, 'Consistency Check', 5);
        }

        // Get all tables that need UUID validation
        const allTables = Object.keys(TABLE_DEFINITIONS).filter(t =>
            t !== 'change_log' && t !== 'condensed_change_log'
        );

        // Step 1: Check UUID integrity across ALL tables first
        Logger.log('\n' + '-'.repeat(80));
        Logger.log('STEP 1: UUID INTEGRITY VALIDATION');
        Logger.log('-'.repeat(80));

        const uuidResults = [];
        let totalUUIDIssues = 0;
        let totalUUIDDeleted = 0;
        let totalUUIDWouldDelete = 0;

        for (const tableName of allTables) {
            const result = this.checkUUIDIntegrity(tableName, simulate);
            uuidResults.push(result);
            totalUUIDIssues += result.totalIssues;
            totalUUIDDeleted += result.deleted || 0;
            totalUUIDWouldDelete += result.wouldDelete || 0;
        }

        // Step 2: Check foreign key consistency (only for tables with FK relationships)
        Logger.log('\n' + '-'.repeat(80));
        Logger.log('STEP 2: FOREIGN KEY CONSISTENCY VALIDATION');
        Logger.log('-'.repeat(80));

        // Process tables in reverse dependency order (children before parents)
        // This ensures that when we delete a parent, we've already cleaned up its children
        const processingOrder = [
            'manufacturer_materials',    // depends on: manufacturers, materials (base tables)
            'vendor_price_lists',        // depends on: manufacturer_materials, vendors
            'purchase_orders',           // depends on: vendors (parent - delete last)
            'purchase_order_items',      // depends on: purchase_orders, manufacturer_materials, materials (child - delete first)
            'purchase_order_payments',   // depends on: purchase_orders (child - delete first)
            'basket_headers',            // basket parent (delete last among basket tables)
            'basket_items',              // depends on: basket_headers, manufacturer_materials (child)
            'basket_vendors',            // depends on: basket_headers, vendors (child)
            'basket_vendor_items',       // depends on: basket_vendors, basket_items, basket_headers, vendor_price_lists (most dependent child)
        ];

        const fkResults = [];
        let totalFKInvalid = 0;
        let totalFKDeleted = 0;
        let totalFKWouldDelete = 0;

        for (const tableName of processingOrder) {
            const result = this.checkAndCleanTable(tableName, simulate);
            fkResults.push(result);
            totalFKInvalid += result.invalidRecords.length;
            totalFKDeleted += result.deleted || 0;
            totalFKWouldDelete += result.wouldDelete || 0;
        }

        // Combine results
        const results = [...uuidResults, ...fkResults];
        const totalInvalid = totalUUIDIssues + totalFKInvalid;
        const totalDeleted = totalUUIDDeleted + totalFKDeleted;
        const totalWouldDelete = totalUUIDWouldDelete + totalFKWouldDelete;

        // Summary
        Logger.log('\n' + '='.repeat(80));
        Logger.log('COMPREHENSIVE CONSISTENCY CHECK SUMMARY - ' + mode);
        Logger.log('='.repeat(80));
        Logger.log(`Tables checked: ${allTables.length}`);
        Logger.log(`\nUUID Integrity Issues:`);
        Logger.log(`  - NULL/Empty UUIDs: ${uuidResults.reduce((sum, r) => sum + r.nullUUIDs, 0)}`);
        Logger.log(`  - Duplicate UUIDs: ${uuidResults.reduce((sum, r) => sum + r.duplicateUUIDs, 0)} (${uuidResults.reduce((sum, r) => sum + r.duplicateRows, 0)} duplicate rows)`);
        Logger.log(`  - Total UUID issues: ${totalUUIDIssues}`);

        Logger.log(`\nForeign Key Violations:`);
        Logger.log(`  - Invalid references: ${totalFKInvalid}`);

        Logger.log(`\nOverall Totals:`);
        Logger.log(`  - Total issues found: ${totalInvalid}`);

        if (simulate) {
            Logger.log(`  - Total records that WOULD BE deleted: ${totalWouldDelete}`);
        } else {
            Logger.log(`  - Total records deleted: ${totalDeleted}`);
        }

        Logger.log('='.repeat(80));
        Logger.log('\nUUID Integrity Results:');

        for (const result of uuidResults) {
            if (result.totalIssues > 0) {
                const issues = [];
                if (result.nullUUIDs > 0) issues.push(`${result.nullUUIDs} null`);
                if (result.duplicateUUIDs > 0) issues.push(`${result.duplicateUUIDs} duplicates`);

                if (simulate) {
                    Logger.log(`  ${result.tableName}: ${issues.join(', ')} (would delete ${result.wouldDelete})`);
                } else {
                    Logger.log(`  ${result.tableName}: ${issues.join(', ')} (deleted ${result.deleted})`);
                }
            } else {
                Logger.log(`  ${result.tableName}: ✓ UUID integrity OK`);
            }
        }

        Logger.log('\nForeign Key Consistency Results:');

        for (const result of fkResults) {
            if (result.invalidRecords && result.invalidRecords.length > 0) {
                if (simulate) {
                    Logger.log(`  ${result.tableName}: ${result.invalidRecords.length} invalid references (would delete ${result.wouldDelete})`);
                } else {
                    Logger.log(`  ${result.tableName}: ${result.invalidRecords.length} invalid references (deleted ${result.deleted})`);
                }
            } else {
                Logger.log(`  ${result.tableName}: ✓ FK consistency OK`);
            }
        }

        Logger.log('\n' + '='.repeat(80));

        if (totalInvalid === 0) {
            Logger.log('✓✓✓ All tables are fully consistent! No issues found.');
            Logger.log('  • All UUIDs are valid and unique');
            Logger.log('  • All foreign key references are valid');
        } else if (simulate) {
            Logger.log(`⚠⚠⚠ SIMULATION COMPLETE`);
            Logger.log(`Found ${totalInvalid} total issues:`);
            Logger.log(`  • UUID issues: ${totalUUIDIssues}`);
            Logger.log(`  • Foreign key violations: ${totalFKInvalid}`);
            Logger.log(`${totalWouldDelete} records would be deleted if cleanup is performed`);
            Logger.log(`\nTo perform actual cleanup, call: consistencyChecks.checkAndCleanAllTables(false)`);
        } else {
            Logger.log(`✓✓✓ CLEANUP COMPLETE!`);
            Logger.log(`Successfully deleted ${totalDeleted} invalid records:`);
            Logger.log(`  • UUID issues fixed: ${totalUUIDDeleted}`);
            Logger.log(`  • Foreign key violations fixed: ${totalFKDeleted}`);
        }

        Logger.log('='.repeat(80) + '\n');

        if (context.canShowToast) {
            if (totalInvalid === 0) {
                ss.toast('All tables are consistent!', 'Consistency Check Complete', 5);
            } else if (simulate) {
                ss.toast(`Found ${totalInvalid} invalid records (simulation)`, 'Check Complete', 5);
            } else {
                ss.toast(`Deleted ${totalDeleted} invalid records`, 'Cleanup Complete', 5);
            }
        }

        return {
            timestamp: new Date().toISOString(),
            mode: simulate ? 'simulation' : 'cleanup',
            tablesChecked: allTables.length,
            uuidIssues: {
                nullUUIDs: uuidResults.reduce((sum, r) => sum + r.nullUUIDs, 0),
                duplicateUUIDs: uuidResults.reduce((sum, r) => sum + r.duplicateUUIDs, 0),
                duplicateRows: uuidResults.reduce((sum, r) => sum + r.duplicateRows, 0),
                total: totalUUIDIssues,
                deleted: totalUUIDDeleted,
                wouldDelete: totalUUIDWouldDelete
            },
            foreignKeyIssues: {
                total: totalFKInvalid,
                deleted: totalFKDeleted,
                wouldDelete: totalFKWouldDelete
            },
            totalInvalid,
            totalDeleted,
            totalWouldDelete,
            simulate,
            uuidResults,
            foreignKeyResults: fkResults
        };
    },

    /**
     * Generate a detailed report of consistency issues without deleting (simulation mode)
     */
    generateConsistencyReport() {
        const report = this.checkAndCleanAllTables(true);
        const ss = SpreadsheetApp.getActiveSpreadsheet();
        const context = utils.getExecutionContext();

        if (context.canShowAlert) {
            if (report.totalInvalid === 0) {
                SpreadsheetApp.getUi().alert(
                    'Consistency Check Complete',
                    'All data is consistent!\n\n✓ All UUIDs are valid and unique\n✓ All foreign key references are valid',
                    SpreadsheetApp.getUi().ButtonSet.OK
                );
            } else {
                const messageParts = [];

                // UUID issues
                if (report.uuidIssues.total > 0) {
                    messageParts.push('UUID Integrity Issues:');
                    const uuidIssues = report.uuidResults
                        .filter(r => r.totalIssues > 0)
                        .map(r => {
                            const issues = [];
                            if (r.nullUUIDs > 0) issues.push(`${r.nullUUIDs} null`);
                            if (r.duplicateUUIDs > 0) issues.push(`${r.duplicateUUIDs} duplicates`);
                            return `• ${r.tableName}: ${issues.join(', ')}`;
                        });
                    messageParts.push(...uuidIssues);
                    messageParts.push('');
                }

                // Foreign key issues
                if (report.foreignKeyIssues.total > 0) {
                    messageParts.push('Foreign Key Violations:');
                    const fkIssues = report.foreignKeyResults
                        .filter(r => r.invalidRecords && r.invalidRecords.length > 0)
                        .map(r => `• ${r.tableName}: ${r.invalidRecords.length} invalid references`);
                    messageParts.push(...fkIssues);
                    messageParts.push('');
                }

                messageParts.push(`Total: ${report.totalInvalid} issues found (${report.totalWouldDelete} records would be deleted)`);
                messageParts.push('');
                messageParts.push('Use "Clean Data Consistency" to fix these issues.');

                SpreadsheetApp.getUi().alert(
                    'Consistency Issues Found',
                    messageParts.join('\n'),
                    SpreadsheetApp.getUi().ButtonSet.OK
                );
            }
        }
    },

    /**
     * Menu function to check and clean all consistency issues
     */
    performConsistencyCleanup() {
        const context = utils.getExecutionContext();
        if (context.canShowAlert) {
            const ui = SpreadsheetApp.getUi();
            const response = ui.alert(
                'Clean Data Consistency',
                'This will delete all records with invalid foreign key references.\n\nThis action cannot be undone.\n\nDo you want to continue?',
                ui.ButtonSet.YES_NO
            );

            if (response !== ui.Button.YES) {
                ui.alert('Operation cancelled');
                return;
            }
        }

        const summary = this.checkAndCleanAllTables(false);

        if (context.canShowAlert) {
            if (summary.totalDeleted > 0) {
                SpreadsheetApp.getUi().alert(
                    'Cleanup Complete',
                    `Successfully deleted ${summary.totalDeleted} invalid records.\n\nCheck the logs for details.`,
                    SpreadsheetApp.getUi().ButtonSet.OK
                );
            } else if (summary.totalInvalid === 0) {
                SpreadsheetApp.getUi().alert(
                    'No Issues Found',
                    'All data is already consistent!',
                    SpreadsheetApp.getUi().ButtonSet.OK
                );
            }
        }
    }
};