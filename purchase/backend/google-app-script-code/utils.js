const utils = {
    getExecutionContext() {
        try {
            // Try to get UI - only works in interactive mode
            SpreadsheetApp.getUi();
            return {
                isWebApp: false,
                isSheetsUI: true,
                canShowToast: true,
                canShowAlert: true
            };
        } catch (e) {
            return {
                isWebApp: true,
                isSheetsUI: false,
                canShowToast: false,
                canShowAlert: false
            };
        }
    },

    roundToDigits(num, digits) {
        const multiplier = Math.pow(10, digits);
        return Math.round(num * multiplier) / multiplier;
    },

    UUID() {
        return Utilities.getUuid();
    },

    getEpochTimeMilliseconds(input, defaultValue) {
        let result = input;
        if (!result) {
            result = defaultValue ? defaultValue : new Date();
        }
        if (typeof result === "string") {
            result = new Date(result);
        }
        if (result instanceof Date) {
            result = result.getTime();
        }
        return result;
    },

    /**
     * Fill the current active cell with a UUID value
     */
    fillUUID() {
        const sheet = SpreadsheetApp.getActiveSheet();
        const cell = sheet.getActiveCell();

        if (!cell) {
            SpreadsheetApp.getActiveSpreadsheet().toast("No cell selected!");
            return;
        }

        cell.setValue(this.UUID());
        SpreadsheetApp.getActiveSpreadsheet().toast("UUID filled successfully!");
    },

    /**
     * Helper to identify if a column should be treated as a date
     */
    isDateColumn(tableName, columnName) {
        return TABLE_DEFINITIONS?.[tableName]?.COLUMNS?.[columnName] === DATA_TYPES.TIME_STAMP;
    },

    removeProtectionsFromSheet(sheet) {
        // Remove all range-level protections
        const rangeProtections = sheet.getProtections(SpreadsheetApp.ProtectionType.RANGE);
        for (let i = 0; i < rangeProtections.length; i++) {
            rangeProtections[i].remove();
        }

        // Remove all sheet-level protections
        const sheetProtections = sheet.getProtections(SpreadsheetApp.ProtectionType.SHEET);
        for (let i = 0; i < sheetProtections.length; i++) {
            sheetProtections[i].remove();
        }
    },

    /**
     * Get the deployed web app URL
     */
    getWebAppUrl() {
        return ScriptApp.getService().getUrl();
    },

    /**
     * Helper function to automatically resize all columns in a sheet
     * Includes header rows in calculation and ensures a minimum width
     */
    autoResizeSheetColumns(sheet) {
        const lastColumn = sheet.getLastColumn();
        if (lastColumn === 0) return;

        // Force a flush to ensure all pending changes (like header text updates) are applied before resizing
        SpreadsheetApp.flush();

        const headers = sheet.getRange(1, 1, 1, lastColumn).getValues()[0];

        for (let i = 1; i <= lastColumn; i++) {
            sheet.autoResizeColumn(i);

            // Google Sheets autoResizeColumn sometimes ignores the header width when there's no data.
            // We'll calculate a minimum width based on the header text length.
            const headerText = String(headers[i - 1] || "");
            // Approximate 10 pixels per character for bold text, plus some padding
            const estimatedHeaderWidth = headerText.length * 10 + 20;

            const currentWidth = sheet.getColumnWidth(i);
            const finalWidth = Math.max(currentWidth, estimatedHeaderWidth, 100);

            sheet.setColumnWidth(i, finalWidth);
        }
    },

    /**
     * Apply number formatting and alignment to numeric columns
     */
    applyNumericFormatting(sheet, tableName) {
        const tableDef = TABLE_DEFINITIONS?.[tableName];
        const tableMetaInfo = TABLE_META_INFO?.[tableName];
        if (!tableMetaInfo?.COLUMN_COUNT) return;

        const lastRow = sheet.getLastRow();
        if (lastRow < 2) return; // No data rows to format

        for (let i = 0; i < tableMetaInfo.COLUMN_NAMES.length; i++) {
            const columnName = tableMetaInfo.COLUMN_NAMES[i];
            const columnType = tableDef?.COLUMNS?.[columnName];
            const colIndex = i + 1;
            // Apply to data rows (row 2 onwards)
            const range = sheet.getRange(2, colIndex, lastRow - 1, 1);
            if (columnType === DATA_TYPES.ID || columnType === DATA_TYPES.INTEGER) {
                range.setNumberFormat("0");
                range.setHorizontalAlignment("right");
            } else if (columnType === DATA_TYPES.QUANTITY) {
                range.setNumberFormat("0.00");
                range.setHorizontalAlignment("right");
            } else if (columnType === DATA_TYPES.AMOUNT ||
                columnType === DATA_TYPES.DOUBLE) {
                range.setNumberFormat("#,##0.00");
                range.setHorizontalAlignment("right");
            } else if (columnType === DATA_TYPES.PERCENT) {
                range.setNumberFormat("0.00");
                range.setHorizontalAlignment("right");
            } else if (columnType === DATA_TYPES.BOOLEAN) {
                range.setNumberFormat("0");
                range.setHorizontalAlignment("center");
            } else if (columnType === DATA_TYPES.TIME_STAMP) {
                range.setNumberFormat("dd/mm/yyyy hh:mm:ss");
            }
        }
    },

    /**
     * Apply lookup formulas to a sheet for computed/reference columns
     * @param {GoogleAppsScript.Spreadsheet.Sheet} sheet - The sheet to apply lookup formulas to
     * @param {string} tableName - The name of the table/sheet
     * @returns {void}
     */
    applyLookupFormulas(sheet, tableName) {
        const tableDef = TABLE_DEFINITIONS?.[tableName];
        const tableMetaInfo = TABLE_META_INFO?.[tableName];

        if (!tableMetaInfo.LOOKUP_COLUMN_COUNT) return;

        tableMetaInfo.LOOKUP_COLUMN_NAMES.forEach((lookupColName, index) => {
            const colIndex = tableMetaInfo.COLUMN_COUNT + index + 1;
            const headerRange = sheet.getRange(1, colIndex);

            // Set header name and formula in the first row (ARRAYFORMULA handles the rest)
            headerRange.setFormula(tableDef.LOOKUP_COLUMNS[lookupColName]);

            // Format header
            headerRange
                .setBackground("#673AB7") // Different color for lookup columns
                .setFontColor("#FFFFFF")
                .setFontWeight("bold")
                .setHorizontalAlignment("center");

            // Format data rows to indicate they are read-only (using a red font color)
            const dataRange = sheet.getRange(2, colIndex, sheet.getMaxRows() - 1, 1);
            dataRange.setFontColor("#B71C1C"); // Material Dark Red
        });

        // Clean up any stray columns beyond lookups
        const maxCols = sheet.getMaxColumns();
        if (maxCols > tableMetaInfo.TOTAL_COLUMN_COUNT) {
            // Note: We don't delete if pickers follow, setup() handles that
        }
    },

    /**
     * @param {GoogleAppsScript.Spreadsheet.Range} targetRange
     * @param {string} sourceSheetName
     * @param {string} sourceColumnName
     * @param {number} startRow
     * @returns {void}
     */
    createDataValidationForGivenRange(targetRange, sourceSheetName, sourceColumnName, startRow) {
        const ss = SpreadsheetApp.getActiveSpreadsheet();
        const sheet = ss.getSheetByName(sourceSheetName);
        if (sheet) {
            const lastRow = sheet.getLastRow();
            if (lastRow > 1) {
                const colIndx = TABLE_META_INFO?.[sourceSheetName]?.COLUMN_INDICES?.[sourceColumnName];
                if (colIndx !== undefined) {
                    const range = sheet.getRange(startRow, colIndx + 1, lastRow - startRow + 1, 1);
                    const rule = SpreadsheetApp.newDataValidation()
                        .requireValueInRange(range, true)
                        .setAllowInvalid(false)
                        .build();
                    targetRange.setDataValidation(rule);
                }
            }
        }
    },

    /**
     * @param {GoogleAppsScript.Spreadsheet.Sheet} sheet
     * @param {number} startRow
     * @returns {number | undefined} Number of rows deleted, or undefined if none deleted
     */
    deleteRowsFromSheetGivenStartRow(sheet, startRow) {
        const numCols = sheet.getLastColumn();
        const maxRows = sheet.getMaxRows(); // Use getMaxRows() to include empty rows

        if (startRow > maxRows) {
            return; // Nothing to delete
        }

        // Calculate total number of rows including startRow to maxRows
        const numRows = maxRows - startRow + 1;

        // Clear content and formatting from startRow onwards (all rows)
        if (numCols > 0) {
            sheet.getRange(startRow, 1, numRows, numCols).clearContent().clearFormat();
        }

        // Delete all rows after startRow (keep startRow cleared but not deleted)
        if (numRows > 1) {
            sheet.deleteRows(startRow + 1, numRows - 1);
        }

        return numRows;
    }
};