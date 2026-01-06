const setup = {
    /**
     * Setup a all Data Worksheets according to schema
     */
    setupDataTableSheets() {
        const ss = SpreadsheetApp.getActiveSpreadsheet();

        // Create config sheet first
        let configSheet = ss.getSheetByName(CONFIG_SHEET_NAME);
        if (!configSheet) {
            configSheet = ss.insertSheet(CONFIG_SHEET_NAME);
            configSheet
                .getRange(1, 1, 1, 2)
                .setValues([["name", "value", "description"]]);

            // Format header
            configSheet
                .getRange(1, 1, 1, 2)
                .setBackground("#FF6B6B")
                .setFontColor("#FFFFFF")
                .setFontWeight("bold")
                .setHorizontalAlignment("center");

            // Add default APP_CODE - USER MUST CHANGE THIS!
            configSheet.appendRow(["APP_CODE", "CHANGE_ME_" + new Date().getTime()]);

            configSheet.setFrozenRows(1);
            configSheet.autoResizeColumn(1);
            configSheet.autoResizeColumn(2);

            Logger.log("Config sheet created. IMPORTANT: Change APP_CODE value!");
        }

        // Setup all tables
        for (const tableName of TABLE_META_INFO.TABLE_NAMES) {
            this.setupDataTableSheet(tableName, true);
        }

        // Delete default "Sheet1" if it exists and is empty
        const sheet1 = ss.getSheetByName("Sheet1");
        if (sheet1 && sheet1.getLastRow() === 0) {
            ss.deleteSheet(sheet1);
        }

        Logger.log("Setup completed successfully!");
        Logger.log("⚠️  IMPORTANT: Go to config sheet and change APP_CODE value!");
        return "Setup completed! REMEMBER: Change APP_CODE in config sheet!";
    },

    /**
     * Setup a single table/sheet
     * @param {string} tableName - Name of the table to setup
     */
    setupDataTableSheet(tableName, doLogging = true) {
        const ss = SpreadsheetApp.getActiveSpreadsheet();
        const tableDef = TABLE_DEFINITIONS[tableName];
        if (!tableDef) {
            throw new Error(`Table "${tableName}" not found in TABLE_DEFINITIONS`);
        }
        const tableMetaInfo = TABLE_META_INFO[tableName];

        let sheet = ss.getSheetByName(tableName);

        if (sheet) {
            if (doLogging) {
                Logger.log(`Sheet "${tableName}" already exists. Checking columns...`);
            }

            const currentMaxColumn = sheet.getMaxColumns();
            const requiredColumnNames = tableMetaInfo.COLUMN_NAMES;
            const requiredColumns = requiredColumnNames.length;

            // Read current header row
            let currentHeaders = [];
            if (currentMaxColumn > 0) {
                currentHeaders = sheet.getRange(1, 1, 1, currentMaxColumn).getValues()[0];
            }

            // Process each required column position
            for (let targetIndex = 0; targetIndex < requiredColumns; targetIndex++) {
                const requiredColumnName = requiredColumnNames[targetIndex];
                const currentColumnName = currentHeaders[targetIndex];

                if (currentColumnName === requiredColumnName) {
                    // Column is already in the correct position
                    continue;
                }

                // Find if the required column exists elsewhere
                const existingIndex = currentHeaders.indexOf(requiredColumnName);

                if (existingIndex !== -1 && existingIndex > targetIndex) {
                    // Column exists but at wrong position - move it
                    if (doLogging) {
                        Logger.log(
                            `Moving column "${requiredColumnName}" from position ${existingIndex + 1} to ${targetIndex + 1} in "${tableName}"`
                        );
                    }

                    // Move the column by inserting at target position and copying data
                    sheet.insertColumnBefore(targetIndex + 1);
                    
                    // Copy data from old position to new position (existingIndex is now +1 due to insert)
                    const maxRows = sheet.getMaxRows();
                    if (maxRows > 0) {
                        const sourceRange = sheet.getRange(1, existingIndex + 2, maxRows, 1);
                        const targetRange = sheet.getRange(1, targetIndex + 1, maxRows, 1);
                        sourceRange.copyTo(targetRange);
                    }
                    
                    // Delete the old column (now at existingIndex + 2)
                    sheet.deleteColumn(existingIndex + 2);
                    
                    // Update our tracking array
                    currentHeaders.splice(existingIndex, 1);
                    currentHeaders.splice(targetIndex, 0, requiredColumnName);

                } else if (existingIndex === -1) {
                    // Column doesn't exist - insert new column
                    if (doLogging) {
                        Logger.log(
                            `Inserting new column "${requiredColumnName}" at position ${targetIndex + 1} in "${tableName}"`
                        );
                    }

                    if (targetIndex < currentHeaders.length) {
                        sheet.insertColumnBefore(targetIndex + 1);
                    } else {
                        sheet.insertColumnAfter(currentHeaders.length);
                    }
                    
                    // Set the header
                    sheet.getRange(1, targetIndex + 1).setValue(requiredColumnName);
                    
                    // Update our tracking array
                    currentHeaders.splice(targetIndex, 0, requiredColumnName);
                }
            }

            // Delete any columns with unwanted or empty headers
            const finalMaxColumn = sheet.getMaxColumns();
            const allAllowedColumns = [...requiredColumnNames, ...tableMetaInfo.LOOKUP_COLUMN_NAMES];
            for (let colIndex = finalMaxColumn; colIndex >= 1; colIndex--) {
                const headerValue = sheet.getRange(1, colIndex).getValue();
                const headerStr = String(headerValue).trim();
                
                // Delete if header is empty or not in required columns list (including lookup columns)
                if (!headerStr || !allAllowedColumns.includes(headerStr)) {
                    sheet.deleteColumn(colIndex);
                    if (doLogging) {
                        Logger.log(
                            `Deleted column ${colIndex} with ${!headerStr ? 'empty' : 'unwanted'} header "${headerStr}" from "${tableName}"`
                        );
                    }
                }
            }

            // Ensure header row has correct values (in case any got lost)
            sheet.getRange(1, 1, 1, requiredColumns).setValues([requiredColumnNames]);

            // Format header
            sheet
                .getRange(1, 1, 1, tableMetaInfo.COLUMN_NAMES.length)
                .setBackground("#4285F4")
                .setFontColor("#FFFFFF")
                .setFontWeight("bold")
                .setHorizontalAlignment("center");

            // Apply lookup formulas if defined
            utils.applyLookupFormulas(sheet, tableName);

            // Apply numeric formatting to existing data
            utils.applyNumericFormatting(sheet, tableName);

            // Optimize column widths
            utils.autoResizeSheetColumns(sheet);

            if (doLogging) {
                Logger.log(`Sheet "${tableName}" updated successfully`);
            }
        } else {
            // Create new sheet
            sheet = ss.insertSheet(tableName);

            // Set header row
            sheet.getRange(1, 1, 1, tableMetaInfo.COLUMN_NAMES.length).setValues([tableMetaInfo.COLUMN_NAMES]);

            // Format header
            sheet
                .getRange(1, 1, 1, tableMetaInfo.COLUMN_NAMES.length)
                .setBackground("#4285F4")
                .setFontColor("#FFFFFF")
                .setFontWeight("bold")
                .setHorizontalAlignment("center");

            // Freeze header row
            sheet.setFrozenRows(1);

            // Delete extra rows (Google Sheets creates 1000 rows by default)
            // Keep only header row + 1 empty data row
            const maxRows = sheet.getMaxRows();
            if (maxRows > 2) {
                sheet.deleteRows(3, maxRows - 2);
            }

            // Delete extra columns beyond what we need
            const maxColumns = sheet.getMaxColumns();
            const totalInitialCols = tableMetaInfo.TOTAL_COLUMN_COUNT;

            if (maxColumns > totalInitialCols) {
                sheet.deleteColumns(
                    totalInitialCols + 1,
                    maxColumns - totalInitialCols
                );
            }

            // Apply lookup formulas if defined
            utils.applyLookupFormulas(sheet, tableName);

            // Apply numeric formatting (even on empty sheets for when data is added)
            utils.applyNumericFormatting(sheet, tableName);

            // Optimize column widths
            utils.autoResizeSheetColumns(sheet);

            if (doLogging) {
                Logger.log(`Sheet "${tableName}" created successfully`);
            }
        }
    },

    setupDataTableSheetForCurrentSheet() {
        const ss = SpreadsheetApp.getActiveSpreadsheet();
        const sheet = ss.getActiveSheet();
        const tableName = sheet.getName();

        this.setupDataTableSheet(tableName, true);
    },

    /**
     * Setup statistics sheet showing row counts for all data tables
     */
    setupStatisticsSheet() {
        const ss = SpreadsheetApp.getActiveSpreadsheet();
        const STATISTICS_SHEET_NAME = "statistics";
        
        let statsSheet = ss.getSheetByName(STATISTICS_SHEET_NAME);
        
        // Create sheet if it doesn't exist
        if (!statsSheet) {
            statsSheet = ss.insertSheet(STATISTICS_SHEET_NAME);
            Logger.log(`Sheet "${STATISTICS_SHEET_NAME}" created`);
        } else {
            Logger.log(`Sheet "${STATISTICS_SHEET_NAME}" already exists. Updating...`);
        }
        
        // Clear existing content
        statsSheet.clear();
        
        // Set header row
        const headers = [["Sheet", "Records"]];
        statsSheet.getRange(1, 1, 1, 2).setValues(headers);
        
        // Format header
        statsSheet.getRange(1, 1, 1, 2)
            .setBackground("#4CAF50")
            .setFontColor("#FFFFFF")
            .setFontWeight("bold")
            .setHorizontalAlignment("center");
        
        // Freeze header row
        statsSheet.setFrozenRows(1);
        
        // Get all table names from TABLE_META_INFO
        const tableNames = TABLE_META_INFO.TABLE_NAMES;
        const numTables = tableNames.length;
        
        // Prepare data rows with formulas
        const dataRows = tableNames.map(tableName => {
            // Formula to count non-empty rows in column A (excluding header)
            // COUNTA counts all non-empty cells in the first column, then subtract 1 for the header
            const formula = `=MAX(0, COUNTA(INDIRECT("${tableName}!A:A")) - 1)`;
            return [tableName, formula];
        });
        
        // Write data rows
        if (numTables > 0) {
            statsSheet.getRange(2, 1, numTables, 2).setValues(dataRows);
        }
        
        // Auto-resize columns
        statsSheet.autoResizeColumn(1);
        statsSheet.autoResizeColumn(2);
        
        // Set column alignment
        if (numTables > 0) {
            statsSheet.getRange(2, 1, numTables, 1).setHorizontalAlignment("left");
            statsSheet.getRange(2, 2, numTables, 1).setHorizontalAlignment("right");
        }
        
        // Delete extra rows (keep header + data rows + 1 empty)
        const maxRows = statsSheet.getMaxRows();
        const neededRows = numTables + 2;
        if (maxRows > neededRows) {
            statsSheet.deleteRows(neededRows + 1, maxRows - neededRows);
        }
        
        // Delete extra columns beyond what we need (2 columns)
        const maxColumns = statsSheet.getMaxColumns();
        if (maxColumns > 2) {
            statsSheet.deleteColumns(3, maxColumns - 2);
        }
        
        Logger.log(`Statistics sheet setup completed with ${numTables} tables`);
        return `Statistics sheet ready with ${numTables} tables tracked`;
    },
};