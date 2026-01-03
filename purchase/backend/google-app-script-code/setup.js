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

            // Delete redundant columns if there are more than needed
            const currentMaxColumn = sheet.getMaxColumns();
            const requiredColumns = tableMetaInfo.TOTAL_COLUMN_COUNT;

            if (currentMaxColumn > requiredColumns) {
                const columnsToDelete = currentMaxColumn - requiredColumns;
                sheet.deleteColumns(requiredColumns + 1, columnsToDelete);
                if (doLogging) {
                    Logger.log(
                        `Deleted ${columnsToDelete} redundant columns from "${tableName}"`
                    );
                }
            }

            // Update header row to ensure it matches the schema
            sheet.getRange(1, 1, 1, tableMetaInfo.COLUMN_NAMES.length).setValues([tableMetaInfo.COLUMN_NAMES]);

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
    }
};