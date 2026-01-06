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
            const headerText = String(headers[i - 1] || "");
            
            sheet.autoResizeColumn(i);

            // Google Sheets autoResizeColumn sometimes ignores the header width when there's no data.
            // We'll calculate a minimum width based on the header text length.
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

        let currentLookupIndex = 0;
        
        // Iterate through each source column and its lookup columns
        for (const [sourceColumnName, lookupColumnNames] of Object.entries(tableDef.LOOKUP_COLUMNS)) {
            const sourceColumnIndex = tableMetaInfo.COLUMN_INDICES[sourceColumnName];
            if (sourceColumnIndex === undefined) continue;
            
            // Get the target table from FOREIGN_KEY_RELATIONSHIPS
            const targetInfo = tableDef.FOREIGN_KEY_RELATIONSHIPS[sourceColumnName];
            if (!targetInfo) continue;
            
            const targetTableName = Object.keys(targetInfo)[0];
            const targetKeyColumn = targetInfo[targetTableName];
            const targetTableMeta = TABLE_META_INFO[targetTableName];
            
            if (!targetTableMeta) continue;
            
            // Column letter for the source column (1-indexed)
            const sourceColLetter = String.fromCharCode(65 + sourceColumnIndex);
            const sourceRange = `${sourceColLetter}2:${sourceColLetter}`;
            
            // Apply formula for each lookup column
            for (const lookupColumnName of lookupColumnNames) {
                const lookupColIndex = tableMetaInfo.COLUMN_COUNT + currentLookupIndex + 1;
                const headerRange = sheet.getRange(1, lookupColIndex);
                
                // Find the target column index in the target table
                // Check if it's a regular column first
                let targetColumnIndex = targetTableMeta.COLUMN_INDICES[lookupColumnName];
                
                // If not found in regular columns, check if it's a lookup column in the target table
                if (targetColumnIndex === undefined) {
                    // Find the position among lookup columns
                    const lookupIndex = targetTableMeta.LOOKUP_COLUMN_NAMES.indexOf(lookupColumnName);
                    if (lookupIndex !== -1) {
                        // Lookup columns come after regular columns
                        targetColumnIndex = targetTableMeta.COLUMN_COUNT + lookupIndex;
                    }
                }
                
                if (targetColumnIndex === undefined) {
                    Logger.log(`Warning: Column '${lookupColumnName}' not found in table '${targetTableName}'`);
                    currentLookupIndex++;
                    continue;
                }
                
                // Calculate VLOOKUP column index (1-based, relative to target table)
                const vlookupColIndex = targetColumnIndex + 1;
                
                // Calculate the range to include both regular and lookup columns
                const totalColumns = targetTableMeta.TOTAL_COLUMN_COUNT;
                const rangeEndColumn = String.fromCharCode(65 + totalColumns - 1);
                
                // Generate the ARRAYFORMULA with VLOOKUP
                const formula = `=ARRAYFORMULA({"${lookupColumnName}"; IF(${sourceRange}="", "", IFERROR(VLOOKUP(${sourceRange}, ${targetTableName}!A:${rangeEndColumn}, ${vlookupColIndex}, FALSE), "Not Found"))})`;
                
                // Set header name and formula
                headerRange.setFormula(formula);

                // Format header
                headerRange
                    .setBackground("#673AB7") // Different color for lookup columns
                    .setFontColor("#FFFFFF")
                    .setFontWeight("bold")
                    .setHorizontalAlignment("center");

                // Format data rows to indicate they are read-only
                const dataRange = sheet.getRange(2, lookupColIndex, sheet.getMaxRows() - 1, 1);
                dataRange.setFontColor("#B71C1C"); // Material Dark Red
                
                currentLookupIndex++;
            }
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
    },

    normalizeName(input) {
        if (!input) return '';

        // Remove punctuation (commas, periods, semicolons, etc.) but keep spaces and alphanumeric
        const cleaned = input.replace(/[^\w\s]/g, ' ');

        // Split into words, filter out empty strings
        const words = cleaned.split(/\s+/).filter(word => word.length > 0);

        // Capitalize first letter of each word, lowercase the rest
        const camelCased = words.map(word => {
            return word.charAt(0).toUpperCase() + word.slice(1).toLowerCase();
        });

        // Join with single space
        return camelCased.join(' ');

        // Examples:
        // console.log(normalizeName("1,Model box;"));     // "1 Model Box"
        // console.log(normalizeName("1 Model Box;"));     // "1 Model Box"
        // console.log(normalizeName("hello,world.test;")); // "Hello World Test"
        // console.log(normalizeName("ABC,def,GHI"));       // "Abc Def Ghi"        
    },

    /**
     * Normalize values in selected column(s) excluding the header row
     * Removes punctuation and applies proper camel casing
     */
    normalizeTextsInSelectedColumn() {
        const sheet = SpreadsheetApp.getActiveSheet();
        const selection = sheet.getActiveRange();

        if (!selection) {
            SpreadsheetApp.getActiveSpreadsheet().toast("Please select a column or range to normalize!");
            return;
        }

        const startRow = selection.getRow();
        const startCol = selection.getColumn();
        const numRows = selection.getNumRows();
        const numCols = selection.getNumColumns();

        // Determine if header row is included in selection
        const dataStartRow = (startRow === 1) ? 2 : startRow;
        const dataNumRows = (startRow === 1) ? numRows - 1 : numRows;

        if (dataNumRows <= 0) {
            SpreadsheetApp.getActiveSpreadsheet().toast("No data rows to normalize!");
            return;
        }

        // Get the data range (excluding header if row 1 was selected)
        const dataRange = sheet.getRange(dataStartRow, startCol, dataNumRows, numCols);
        const values = dataRange.getValues();

        // Normalize each cell value
        const normalizedValues = values.map(row => {
            return row.map(cell => {
                if (typeof cell === 'string' && cell.trim() !== '') {
                    return this.normalizeName(cell);
                }
                return cell;
            });
        });

        // Write normalized values back
        dataRange.setValues(normalizedValues);

        const message = `Normalized ${dataNumRows} row(s) and ${numCols} column(s)`;
        SpreadsheetApp.getActiveSpreadsheet().toast(message);
    },

    /**
     * Get column index mapping from sheet headers
     * This makes the code resilient to column reordering in sheets
     * @param {GoogleAppsScript.Spreadsheet.Sheet} sheet - The sheet to read headers from
     * @param {string} tableName - The table name (optional, for validation)
     * @returns {Object} Map of column name to column index (0-based)
     */
    getSheetColumnMap(sheet, tableName) {
        if (!sheet) {
            throw new Error('Sheet is required');
        }

        const lastCol = sheet.getLastColumn();
        if (lastCol === 0) {
            return {};
        }

        // Read first row as headers
        const headers = sheet.getRange(1, 1, 1, lastCol).getValues()[0];
        
        // Create column map
        const columnMap = {};
        headers.forEach((header, index) => {
            if (header && header.toString().trim() !== '') {
                columnMap[header.toString().trim()] = index;
            }
        });

        // Optionally validate against TABLE_DEFINITIONS
        if (tableName && TABLE_DEFINITIONS[tableName]) {
            const expectedColumns = Object.keys(TABLE_DEFINITIONS[tableName].COLUMNS);
            const missingColumns = expectedColumns.filter(col => !(col in columnMap));
            if (missingColumns.length > 0) {
                console.warn(`Sheet "${sheet.getName()}" is missing expected columns: ${missingColumns.join(', ')}`);
            }
        }

        return columnMap;
    },

    /**
     * Build row data array from record object using column map
     * @param {Object} record - The record object with column name keys
     * @param {Array<string>} columnNames - Array of column names in desired order
     * @param {Object} columnMap - Map of column name to sheet column index
     * @param {string} tableName - The table name (for date column detection)
     * @returns {Array} Row data array aligned with sheet column order
     */
    buildRowDataFromRecord(record, columnNames, columnMap, tableName) {
        // Create an array with undefined values at actual sheet positions
        const maxIndex = Math.max(...Object.values(columnMap));
        const rowData = new Array(maxIndex + 1);
        
        // Fill in values based on column map
        columnNames.forEach((colName) => {
            const sheetIndex = columnMap[colName];
            if (sheetIndex !== undefined) {
                let val = record[colName] || "";
                
                // Handle date conversion
                if (val && this.isDateColumn(tableName, colName)) {
                    try {
                        const date = new Date(val);
                        if (!isNaN(date.getTime())) {
                            val = date;
                        }
                    } catch (e) {
                        // If parsing fails, use original value
                    }
                }
                
                rowData[sheetIndex] = val;
            }
        });
        
        return rowData;
    }
};