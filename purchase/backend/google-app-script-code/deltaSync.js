const deltaSync = {
    /**
     * Insert or update records in a sheet
     * Uses uuid as primary table_key_uuid for upsert logic
     */
    upsertRecords(tableName, records) {
        const ss = SpreadsheetApp.getActiveSpreadsheet();
        const sheet = ss.getSheetByName(tableName);
        const tableDef = TABLE_DEFINITIONS?.[tableName];
        const tableMetaInfo = TABLE_META_INFO?.[tableName];
        const colIdx = tableMetaInfo.COLUMN_INDICES;

        if (!sheet) {
            throw new Error(`Sheet "${tableName}" not found`);
        }
        if (!tableDef) {
            throw new Error(`Schema for "${tableName}" not found`);
        }

        const data = sheet.getDataRange().getValues();
        let updatedCount = 0;

        for (const record of records) {
            const uuid = record.uuid;
            let rowIndex = -1;

            // Find existing row by uuid
            for (let i = 1; i < data.length; i++) {
                if (data[i][colIdx.uuid] === uuid) {
                    rowIndex = i + 1; // +1 because sheet rows are 1-indexed
                    break;
                }
            }

            // Prepare row data with Date object conversion
            const rowData = tableMetaInfo.COLUMN_NAMES.map((colName) => {
                let val = record[colName] || "";
                if (val && utils.isDateColumn(tableName, colName)) {
                    try {
                        // Attempt to parse ISO string to Date object
                        const date = new Date(val);
                        if (!isNaN(date.getTime())) {
                            return date;
                        }
                    } catch (e) {
                        // If parsing fails, fall back to original value
                    }
                }
                return val;
            });

            if (rowIndex > 0) {
                // Update existing row (only base columns)
                const range = sheet.getRange(rowIndex, 1, 1, tableMetaInfo.COLUMN_COUNT);
                range.setValues([rowData]);
            } else {
                // Append new row
                sheet.appendRow(rowData);
            }

            updatedCount++;
        }

        // Optimize column widths after updates
        utils.autoResizeSheetColumns(sheet);

        return updatedCount;
    },

    /**
     * Delete records from a sheet
     * @param {string} tableName - Name of the table
     * @param {Array} deletions - Array of {uuid, deleted_at} objects
     * @returns {number} Number of records deleted
     */
    deleteRecords(tableName, deletions) {
        const ss = SpreadsheetApp.getActiveSpreadsheet();
        const sheet = ss.getSheetByName(tableName);
        const tableDef = TABLE_DEFINITIONS?.[tableName];
        const tableMetaInfo = TABLE_META_INFO?.[tableName];
        const colIdx = tableMetaInfo.COLUMN_INDICES;

        if (!sheet) {
            throw new Error(`Sheet "${tableName}" not found`);
        }
        if (!tableDef) {
            throw new Error(`Schema for "${tableName}" not found`);
        }

        const data = sheet.getDataRange().getValues();

        let deletedCount = 0;

        // Process each deletion
        for (const deletion of deletions) {
            const uuid = deletion.uuid;
            let rowIndex = -1;

            // Find existing row by uuid
            for (let i = 1; i < data.length; i++) {
                if (data[i][colIdx.uuid] === uuid) {
                    rowIndex = i + 1; // +1 because sheet rows are 1-indexed
                    break;
                }
            }

            if (rowIndex > 0) {
                // Delete the row
                sheet.deleteRows(rowIndex, 1);
                deletedCount++;

                // Update data array to reflect deletion
                data.splice(rowIndex - 1, 1);
            }
        }

        return deletedCount;
    },

    /**
     * Apply delta changes from client to server with batch processing
     * Processes deletes first, then inserts/updates in batches per table
     * @param {array} log - Array of change log entries
     * @param {object} tableRecords - Map of table names to record maps
     * @returns {number} Number of changes processed
     */
    applyDeltaChangesBatch(log, tableRecords) {
        const now = new Date();
        let processed = 0;

        // Group changes by table and operation
        const changesByTable = {};

        for (const change of log) {
            try {
                const tableIndex = change.table_index;
                const table_key_uuid = change.table_key_uuid;
                const changeMode = change.change_mode;
                const updatedAt = new Date(utils.getEpochTimeMilliseconds(change.updated_at, now));

                // Find table name from index
                const tableName = TABLE_INDICES_TO_NAMES?.[String(tableIndex)];
                if (!tableName) {
                    Logger.log(`Unknown table index: ${tableIndex}`);
                    continue;
                }

                // Initialize table structure
                if (!changesByTable[tableName]) {
                    changesByTable[tableName] = {
                        deletes: [],
                        upserts: []
                    };
                }

                if (changeMode === CHANGE_MODE_DELETE) {
                    changesByTable[tableName].deletes.push({ uuid: table_key_uuid, deleted_at: updatedAt });
                } else {
                    // For insert/update, get record from tableRecords
                    const record = tableRecords?.[tableName]?.[table_key_uuid];
                    if (record) {
                        record[CHANGE_MODE_TEMPORARY_FIELD] = changeMode; // Store change mode temporarily if needed
                        record[UPDATED_AT_TEMPORARY_FIELD] = updatedAt;
                        record.updated_at = new Date(utils.getEpochTimeMilliseconds(record.updated_at, updatedAt)); // Ensure updated_at is Date object
                        changesByTable[tableName].upserts.push(record);
                    }
                }
            } catch (error) {
                Logger.log(`ERROR grouping change: ${error.toString()}`);
            }
        }

        // Process each table: deletes first, then upserts
        for (const tableName in changesByTable) {
            const changes = changesByTable[tableName];
            const tableIndex = TABLE_NAMES_TO_INDICES[tableName];

            try {
                // Process deletes
                if (changes.deletes.length > 0) {
                    Logger.log(`Deleting ${changes.deletes.length} records from ${tableName}`);
                    const deleted = this.deleteRecords(tableName, changes.deletes);
                    processed += deleted;

                    const changeLogs = [];
                    // Log changes
                    for (const deletion of changes.deletes) {
                        changeLogs.push({
                            uuid: utils.UUID(),
                            table_index: tableIndex,
                            table_key_uuid: deletion.uuid,
                            change_mode: CHANGE_MODE_DELETE,
                            updated_at: deletion.deleted_at
                        });
                    }
                    changeLog.insertRecords(changeLogs);
                }

                // Process upserts
                if (changes.upserts.length > 0) {
                    Logger.log(`Upserting ${changes.upserts.length} records to ${tableName}`);
                    const upserted = this.upsertRecords(tableName, changes.upserts);
                    processed += upserted;

                    const changeLogs = [];
                    // Log changes
                    for (const record of changes.upserts) {
                        changeLogs.push({
                            uuid: utils.UUID(),
                            table_index: tableIndex,
                            table_key_uuid: record.uuid,
                            change_mode: record[CHANGE_MODE_TEMPORARY_FIELD] || CHANGE_MODE_INSERT,
                            updated_at: record[UPDATED_AT_TEMPORARY_FIELD] || now
                        });
                    }
                    changeLog.insertRecords(changeLogs);
                }
            } catch (error) {
                Logger.log(`ERROR processing table ${tableName}: ${error.toString()}`);
            }
        }

        return processed;
    },

    /**
     * Fetch table records efficiently for a list of changes
     * Groups changes by table and fetches all records in batch
     * @param {array} log - Array of change log entries
     * @returns {object} Object with table names as table_key_uuids and record maps as values
     */
    fetchTableRecordsForChanges(log) {
        const ss = SpreadsheetApp.getActiveSpreadsheet();
        const tableRecords = {};

        // Group changes by table_index
        const changesByTable = {};
        for (const change of log) {
            const tableIndex = change.table_index;
            const changeMode = change.change_mode;
            const table_key_uuid = change.table_key_uuid;

            // Only fetch records for insert/update operations
            if (changeMode === CHANGE_MODE_INSERT || changeMode === CHANGE_MODE_UPDATE) {
                if (!changesByTable[tableIndex]) {
                    changesByTable[tableIndex] = [];
                }
                changesByTable[tableIndex].push(table_key_uuid);
            }
        }

        // Fetch records for each table
        for (const tableIndexStr in changesByTable) {
            const tableIndex = parseInt(tableIndexStr, 10);
            const tableName = TABLE_INDICES_TO_NAMES[String(tableIndex)];

            if (!tableName) {
                Logger.log(`WARNING: Unknown table index ${tableIndex}`);
                continue;
            }

            const table_key_uuids = changesByTable[tableIndex];
            if (table_key_uuids.length === 0) continue;

            const sheet = ss.getSheetByName(tableName);
            if (!sheet) {
                Logger.log(`WARNING: Sheet "${tableName}" not found`);
                continue;
            }

            const tableDef = TABLE_DEFINITIONS?.[tableName];
            if (!tableDef) {
                Logger.log(`WARNING: No metadata for table "${tableName}"`);
                continue;
            }

            // Fetch all records for this table efficiently
            const records = this.batchGetRecordsByUuids(sheet, tableName, table_key_uuids);

            if (Object.keys(records).length > 0) {
                tableRecords[tableName] = records;
            }
        }

        for (let i = log.length - 1; i >= 0; i--) {
            const change = log[i];
            const tableIndex = change.table_index;
            const changeMode = change.change_mode;
            const table_key_uuid = change.table_key_uuid;
            const tableName = TABLE_INDICES_TO_NAMES[String(tableIndex)];

            // Only fetch records for insert/update operations
            if (changeMode === CHANGE_MODE_INSERT || changeMode === CHANGE_MODE_UPDATE) {
                if (!tableRecords?.[tableName]?.[table_key_uuid]) {
                    Logger.log(`WARNING: Record with UUID ${table_key_uuid} not found in table ${tableName}`);
                    log.splice(i, 1);
                }
            }
        }

        return tableRecords;
    },

    /**
     * Batch fetch records by UUIDs for performance
     * @param {GoogleAppsScript.Spreadsheet.Sheet} sheet - Google Sheet object
     * @param {string} tableName - Name of the table
     * @param {array} uuids - Array of UUIDs to fetch
     * @returns {object} Map of UUID to record objects
     */
    batchGetRecordsByUuids(sheet, tableName, uuids) {
        const records = {};
        const tableDef = TABLE_DEFINITIONS?.[tableName];
        const tableMetaInfo = TABLE_META_INFO?.[tableName];
        const colDef = tableDef?.COLUMNS;
        const colIdx = tableMetaInfo?.COLUMN_INDICES;

        if (colIdx?.uuid === undefined) {
            return records;
        }

        const lastRow = sheet.getLastRow();
        if (lastRow < 2) {
            return records; // No data rows
        }

        // Read all data at once for efficiency
        const sheetData = sheet.getRange(2, 1, lastRow - 1, tableMetaInfo?.COLUMN_COUNT).getValues();
        // Create a set for faster lookup
        const uuidSet = new Set(uuids);

        // Find matching rows
        for (let i = 0; i < sheetData.length; i++) {
            const row = sheetData[i];
            const uuid = row[colIdx.uuid];

            if (uuidSet.has(uuid)) {
                const record = {};
                for (const colName in tableDef.COLUMNS) {
                    let val = row[colIdx?.[colName]];

                    if (colDef?.[colName] === DATA_TYPES.TIME_STAMP && val && val instanceof Date) {
                        // Convert Date objects to ISO strings
                        val = val.toISOString();
                        //Is this necessary?
                        //JSON serialization automatically converts Date to ISO string
                    }
                    record[colName] = val;
                }
                records[uuid] = record;
                if (!record.updated_at) {
                    record.updated_at = new Date().toISOString();
                }
            }
        }

        return records;
    }
};
