/**
 * Setup function to create all required sheets matching SQLite database structure
 * Run this function once to initialize the Google Sheet
 */
function onOpen() {
    const ui = SpreadsheetApp.getUi();
    ui.createMenu("Purchase App")
        .addItem("Fill UUID", "util.fillUUID")
        .addItem("Normalize Texts in Selected Column", "utils.normalizeTextsInSelectedColumn")
        .addSeparator()
        .addItem("Display Record Statistics", "consistencyChecks.displayRecordCountStatistics")
        .addItem("Do Consistency Checks", "consistencyChecks.generateConsistencyReport")
        .addItem("Perform Consistency Cleanup", "consistencyChecks.performConsistencyCleanup")
        .addSeparator()
        .addItem("Export Current Sheet to CSV", "csvExport.exportCurrentSheet")
        .addItem("Export All Data Sheets to ZIP", "csvExport.exportAllDataSheets")        
        .addSeparator()
        .addItem("Cleanup Current Sheet", "cleanup.cleanupCurrentSheet")
        .addItem("Cleanup Transaction Data Sheets", "cleanup.cleanupTransactionDataSheets")
        .addItem("Cleanup Log Data Sheets", "cleanup.cleanupLogDataSheets")
        .addSeparator()
        .addItem("Initialize Change Log from Data Sheets", "changeLog.initializeChangeLogFromDataSheets")
        .addItem("Write Condensed Change Log", "changeLog.writeCondensedChangeLogForAllData")
        .addSeparator()
        .addItem("Setup / Update Schema", "setup.setupDataTableSheets")
        .addItem("Setup / Update Schema for Current Sheet", "setup.setupDataTableSheetForCurrentSheet")
        .addItem("Setup Statistics Sheet", "setup.setupStatisticsSheet")
        .addItem("Setup Maintain Manufacturer Material Models - Input Sheet", "maintainManufacturerModelNames.setupSheet")
        .addItem("Setup Maintain Manufacturer Material Model Data - Input Sheet", "maintainManufacturerModelData.setupSheet")
        .addItem("Setup Maintain Vendor Price Lists - Input Sheet", "maintainVendorPriceLists.setupSheet")
        .addSeparator()
        .addItem("Deploy Web App", "deployer.deployWebApp")
        .addToUi();
}

/**
 * Handle checkbox clicks on the utility sheet buttons
 */
function onEdit(e) {
    try {
        const range = e.range;
        const sheet = range.getSheet();
        const sheetName = sheet.getName();

        if (sheetName === maintainManufacturerModelNames.LAYOUT.SHEET) {
            maintainManufacturerModelNames.onEdit(range);
        } else if (sheetName === maintainManufacturerModelData.LAYOUT.SHEET) {
            maintainManufacturerModelData.onEdit(range);
        } else if (sheetName === maintainVendorPriceLists.LAYOUT.SHEET) {
            maintainVendorPriceLists.onEdit(range);
        }
    } catch (error) {
        Logger.log("Error in onEdit: " + error.toString());
        SpreadsheetApp.getActiveSpreadsheet().toast("Error: " + error.toString());
    }
}
