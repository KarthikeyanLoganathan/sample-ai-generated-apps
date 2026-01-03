const cleanup = {
    /**
     * Cleanup a single sheet by clearing all data rows (keeps header)
     * @param {string} sheetName - Name of the sheet to cleanup
     * @returns {number} Number of rows cleared (0 if sheet not found or already empty)
     */
    cleanupSheet(sheetName) {
        const ss = SpreadsheetApp.getActiveSpreadsheet();
        const sheet = ss.getSheetByName(sheetName);

        if (!sheet) {
            Logger.log(`WARNING: Sheet "${sheetName}" not found`);
            return 0;
        }

        const lastRow = sheet.getMaxRows();

        // If there are data rows (more than just the header)
        if (lastRow > 1) {
            const numRowsToClear = lastRow - 1;
            const numCols = sheet.getLastColumn();

            // Clear the content of data rows (keep the rows but remove content)
            sheet.getRange(2, 1, numRowsToClear, numCols).clearContent();

            Logger.log(`Cleared ${numRowsToClear} rows from ${sheetName}`);

            // Delete all rows after the header row
            if (lastRow > 2) {
                sheet.deleteRows(3, lastRow - 2);
                Logger.log(`Deleted ${lastRow - 1} rows from ${sheetName}`);
            }

            return numRowsToClear;
        } else {
            Logger.log(`${sheetName} is already empty`);
            return 0;
        }
    },

    /**
     * Cleanup function to clear all data from data sheets
     * Keeps the config sheet and its APP_CODE intact
     * Only clears data rows (keeps headers)
     */
    cleanup() {
        let clearedCount = 0;
        let totalRowsCleared = 0;

        for (const sheetName of TABLE_META_INFO.TABLE_NAMES) {
            const rowsCleared = this.cleanupSheet(sheetName);
            if (rowsCleared > 0) {
                clearedCount++;
                totalRowsCleared += rowsCleared;
            }
        }

        Logger.log(
            `Cleanup completed! Cleared ${totalRowsCleared} total rows from ${clearedCount} sheets.`
        );
        Logger.log("Config sheet preserved.");

        return `Cleanup completed! Cleared ${totalRowsCleared} total rows from ${clearedCount} data sheets. Config sheet preserved.`;
    },

    /**
     * Cleanup the current active sheet by clearing all data rows (keeps header)
     * Wrapper function for menu item that calls cleanupSheet()
     */
    cleanupCurrentSheet() {
        const ss = SpreadsheetApp.getActiveSpreadsheet();
        const sheet = ss.getActiveSheet();
        const sheetName = sheet.getName();

        const rowsCleared = this.cleanupSheet(sheetName);

        const message = rowsCleared > 0
            ? `Cleared ${rowsCleared} rows from ${sheetName}`
            : `${sheetName} is already empty`;

        SpreadsheetApp.getActiveSpreadsheet().toast(message);
        return message;
    }
};

