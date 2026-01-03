const csvExport = {
    /**
     * Export current sheet to CSV format with ISO 8601 dates
     */
    exportCurrentSheet() {
        const ss = SpreadsheetApp.getActiveSpreadsheet();
        const sheet = ss.getActiveSheet();
        const sheetName = sheet.getName();
        const data = sheet.getDataRange().getValues();

        if (data.length < 1) {
            SpreadsheetApp.getActiveSpreadsheet().toast("The sheet is empty.");
            return;
        }
        const tableColumns = TABLE_META_INFO?.[sheetName]?.COLUMN_NAMES;
        const baseColumns = tableColumns || data[0];
        const colIndices = baseColumns
            .map((col) => data[0].indexOf(col))
            .filter((idx) => idx !== -1);

        let csvContent = "";

        for (let i = 0; i < data.length; i++) {
            const row = data[i];
            // Only include base columns in CSV
            const csvRow = colIndices.map((index) => {
                let value = row[index];

                // Format dates specifically
                if (value instanceof Date) {
                    value = value.toISOString();
                } else if (
                    typeof value === "string" &&
                    utils.isDateColumn(sheetName, baseColumns[index])
                ) {
                    // Double check if it's a date string that needs normalization
                    try {
                        const d = new Date(value);
                        if (!isNaN(d.getTime())) {
                            value = d.toISOString();
                        }
                    } catch (e) { }
                }

                // Escape quotes and wrap in quotes if necessary
                let stringValue =
                    value === null || value === undefined ? "" : String(value);
                if (
                    stringValue.includes(",") ||
                    stringValue.includes('"') ||
                    stringValue.includes("\n")
                ) {
                    stringValue = '"' + stringValue.replace(/"/g, '""') + '"';
                }
                return stringValue;
            });

            csvContent += csvRow.join(",") + "\r\n";
        }

        const filename = sheetName + ".csv";
        showDownloadDialog(csvContent, filename);

        /**
         * Helper to show a download dialog for the generated CSV
         */
        function showDownloadDialog(content, filename) {
            const htmlContent = `
      <html>
        <body>
          <p>Your CSV file is ready for download.</p>
          <a id="downloadLink" href="#" download="${filename}">Click here to download if it doesn't start automatically</a>
          <script>
            const content = ${JSON.stringify(content)};
            const blob = new Blob([content], {type: 'text/csv'});
            const url = URL.createObjectURL(blob);
            const link = document.getElementById('downloadLink');
            link.href = url;
            link.click();
            // Close dialog after a delay
            setTimeout(() => { google.script.host.close(); }, 3000);
          </script>
        </body>
      </html>
    `;

            const html = HtmlService.createHtmlOutput(htmlContent)
                .setWidth(400)
                .setHeight(150);

            SpreadsheetApp.getUi().showModalDialog(html, "Downloading CSV...");
        }
    }
};
