const zlocalTests = {
    zTestClearDataValidations() {
        var spreadsheet = SpreadsheetApp.getActive();
        spreadsheet.getActiveSheet().getDataRange().clearDataValidations();
    },

    zTestSyncInBackend() {
        const { log, totalRecords } = changeLog.readCondensedChangeLog(0, 200);
        const tableRecords = deltaSync.fetchTableRecordsForChanges(log);
        console.log("done");
    }
};


function ztestSetup(){
  setup.setupDataTableSheets()
}