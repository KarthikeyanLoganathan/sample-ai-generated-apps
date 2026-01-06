const config = {
    /**
     * Get configuration value by name
     */
    getConfigValue(name) {
        const ss = SpreadsheetApp.getActiveSpreadsheet();
        const configSheet = ss.getSheetByName(CONFIG_SHEET_NAME);

        if (!configSheet) {
            throw new Error("Config sheet not found. Run setup() first.");
        }

        const data = configSheet.getDataRange().getValues();
        for (let i = 1; i < data.length; i++) {
            if (data[i][0] === name) {
                return data[i][1];
            }
        }

        return null;
    }
};