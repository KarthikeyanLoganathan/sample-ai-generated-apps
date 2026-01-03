# Google Apps Script Backend - Purchase App

Backend code for the Flutter Purchase App, written in Google Apps Script. This provides the server-side sync functionality using Google Sheets as the database.

## Overview

This backend implements:
- Delta sync between Flutter app and Google Sheets
- RESTful API endpoints for data synchronization
- Change log tracking for efficient sync
- Data maintenance utilities for manufacturer materials and vendor price lists
- Shopping basket feature with 4 tables (basket_headers, basket_items, basket_vendors, basket_vendor_items)
- Foreign key consistency validation and cleanup
- Automatic table setup and schema management
- Namespace-based code organization for better modularity

## Project Structure

```
google-app-script-code/
├── Code.js                             # Legacy monolithic file (deprecated)
├── constants.js                        # Global constants and change modes
├── tableMetadata.js                    # Table metadata, column definitions, data types
├── config.js                           # config namespace - Configuration management
├── setup.js                            # setup namespace - Sheet setup and initialization
├── utils.js                            # utils namespace - Utility functions (UUID, date helpers, sheet operations)
├── webService.js                       # doGet/doPost web endpoints
├── webSecurity.js                      # webSecurity namespace - Request validation and secret code checking
├── deltaSync.js                        # deltaSync namespace - Sync logic (upsert, delete, batch operations)
├── changeLogUtils.js                   # changeLog namespace - Change log management and condensed log generation
├── dataReaders.js                      # dataReaders namespace - Data reading functions with filter support
├── cleanup.js                          # cleanup namespace - Data cleanup utilities
├── consistencyChecks.js                # consistencyChecks namespace - Foreign key consistency validation and cleanup
├── exportCSV.js                        # csvExport namespace - CSV export functionality
├── maintainManufacturerModels.js       # maintainManufacturerModelNames namespace - Model names maintenance
├── maintainManufacturerModelData.js    # maintainManufacturerModelData namespace - MRP/lot size maintenance
├── maintainVendorPriceLists.js         # Vendor price list maintenance (stub)
├── sheetEventHandlers.js               # onEdit, onOpen event triggers
├── z-test.js                           # Test functions
├── globals.d.ts                        # TypeScript definitions for VSCode IntelliSense
├── jsconfig.json                       # VSCode JavaScript configuration
├── package.json                        # npm dependencies and scripts
├── .clasp.json.example                 # Example clasp configuration
├── .claspignore                        # Files to exclude from clasp push
└── README.md                           # This file
```

## Code Organization

The codebase uses a **namespace pattern** for better modularity and organization:

### Namespaces

- **`config`** - Configuration value retrieval
  - `config.getConfigValue(name)` - Get configuration value from config sheet

- **`setup`** - Sheet setup and initialization
  - `setup.setupDataTableSheets()` - Initialize all data sheets
  - `setup.setupDataTableSheet(tableName, doLogging)` - Setup individual table/sheet

- **`utils`** - Utility functions
  - `utils.UUID()` - Generate UUID
  - `utils.fillUUID()` - Fill missing UUIDs in active sheet
  - `utils.getEpochTimeMilliseconds(input, defaultValue)` - Convert to epoch time
  - `utils.isDateColumn(tableName, columnName)` - Check if column is a date
  - `utils.autoResizeSheetColumns(sheet)` - Auto-resize columns
  - `utils.applyNumericFormatting(sheet, tableName)` - Apply numeric formatting
  - `utils.applyLookupFormulas(sheet, tableName)` - Apply lookup formulas
  - `utils.createDataValidationForGivenRange(...)` - Create data validation dropdown
  - `utils.removeProtectionsFromSheet(sheet)` - Remove sheet protections
  - `utils.getWebAppUrl()` - Get deployed web app URL
  - `utils.deleteRowsFromSheetGivenStartRow(sheet, startRow)` - Delete rows from sheet

- **`cleanup`** - Data cleanup operations
  - `cleanup.cleanupSheet(sheetName)` - Clear data from specific sheet
  - `cleanup.cleanup()` - Cleanup all data sheets
  - `cleanup.cleanupCurrentSheet()` - Cleanup currently active sheet

- **`consistencyChecks`** - Foreign key consistency validation and cleanup
  - `consistencyChecks.checkNullUUIDs(tableName)` - Check for null/empty UUIDs in a table
  - `consistencyChecks.loadTargetUUIDs(tableName)` - Load all valid UUIDs from a target table
  - `consistencyChecks.checkAndCleanTable(tableName, simulate)` - Check and optionally clean a specific table
  - `consistencyChecks.checkAndCleanAllTables(simulate)` - Check and optionally clean all tables with foreign keys
  - `consistencyChecks.deleteInvalidRecords(sheet, tableName, invalidRecords, simulate)` - Delete invalid records
  - `consistencyChecks.logDeletions(tableName, invalidRecords)` - Log deletions to change log
  - Processing order: basket_vendor_items, basket_items, basket_vendors, basket_headers (children before parents)
  - `checkDataConsistency()` - Menu function to check consistency (report only)
  - `cleanDataConsistency()` - Menu function to check and clean consistency issues

- **`dataReaders`** - Data reading functions with optional filtering
  - `dataReaders.readManufacturers(filter)` - Read manufacturers
  - `dataReaders.readVendors(filter)` - Read vendors
  - `dataReaders.readMaterials(filter)` - Read materials
  - `dataReaders.readManufacturerMaterials(manufacturersMap, materialsMap, filter)` - Read manufacturer materials
  - `dataReaders.readVendorPriceList(manufacturersMap, materialsMap, manufacturerMaterialsMap, filter)` - Read vendor price lists

- **`deltaSync`** - Delta synchronization
  - `deltaSync.upsertRecords(tableName, records)` - Insert or update records
  - `deltaSync.deleteRecords(tableName, deletions)` - Delete records
  - `deltaSync.applyDeltaChangesBatch(log, tableRecords)` - Apply batch of changes
  - `deltaSync.fetchTableRecordsForChanges(log)` - Fetch records based on change log
  - `deltaSync.batchGetRecordsByUuids(sheet, tableName, uuids)` - Get multiple records by UUID

- **`changeLog`** - Change log management
  - `changeLog.initializeChangeLogFromDataSheets()` - Initialize change log from all data
  - `changeLog.logChange(tableName, key, changeMode, updatedAt)` - Log single change
  - `changeLog.logChanges(tableName, keys, changeMode, updatedAt)` - Log multiple changes (batch)
  - `changeLog.prepareCondensedChangeLogFromChangeLog(since)` - Prepare condensed change log
  - `changeLog.writeCondensedChangeLog(since)` - Write condensed log to sheet
  - `changeLog.writeCondensedChangeLogForAllData()` - Write condensed log for all data
  - `changeLog.readCondensedChangeLog(offset, limit)` - Read condensed log with pagination

- **`maintainManufacturerModelNames`** - Manufacturer model names maintenance
  - `maintainManufacturerModelNames.setupSheet()` - Setup "saveData" input sheet
  - `maintainManufacturerModelNames.prepareData()` - Prepare/load data for editing
  - `maintainManufacturerModelNames.saveData()` - Save changes to manufacturer_materials table
  - `maintainManufacturerModelNames.clearData()` - Clear input data rows
  - `maintainManufacturerModelNames.protectSheet()` - Protect sheet regions
  - `maintainManufacturerModelNames.LAYOUT` - Layout constants (button positions, columns, etc.)

- **`maintainManufacturerModelData`** - Manufacturer model MRP/lot size maintenance
  - `maintainManufacturerModelData.setupSheet()` - Setup "MaintainManufacturerMaterialModelData" input sheet
  - `maintainManufacturerModelData.prepareData()` - Prepare/load data for editing
  - `maintainManufacturerModelData.saveData()` - Save MRP and lot size changes
  - `maintainManufacturerModelData.clearData()` - Clear input data rows
  - `maintainManufacturerModelData.protectSheet()` - Protect sheet regions
  - `maintainManufacturerModelData.LAYOUT` - Layout constants (button positions, columns, etc.)

- **`maintainVendorPriceLists`** - Vendor price list maintenance
  - `maintainVendorPriceLists.setupSheet()` - Setup "MaintainVendorPrices" input sheet
  - `maintainVendorPriceLists.prepareData()` - Prepare/load data for editing (stub)
  - `maintainVendorPriceLists.saveData()` - Save vendor price changes (stub)
  - `maintainVendorPriceLists.clearData()` - Clear input data rows (stub)
  - `maintainVendorPriceLists.LAYOUT` - Layout constants

- **`webSecurity`** - Request validation and security
  - `webSecurity.validateSecretCode(providedCode)` - Validate secret code against configuration

- **`csvExport`** - CSV export functionality
  - `csvExport.exportCurrentSheetToCSV()` - Export currently active sheet to CSV file

### Global Functions (Non-namespaced)

These functions are available globally for menu integration and web endpoints:

- `onOpen()` - Creates custom "Purchase App" menu (in [sheetEventHandlers.js](sheetEventHandlers.js))
- `onEdit(e)` - Handles checkbox button clicks in maintenance sheets (in [sheetEventHandlers.js](sheetEventHandlers.js))
- `doPost(e)` - Web service POST endpoint for delta sync (in [webService.js](webService.js))
- `doGet(e)` - Web service GET endpoint (in [webService.js](webService.js))
- `fillUUID()` - Backward compatibility wrapper for `utils.fillUUID()`
- `setup()` - Backward compatibility wrapper for `setup.setupDataTableSheets()`
- `setupTable(tableName, doLogging)` - Backward compatibility wrapper for `setup.setupDataTableSheet()`

### Usage Examples

```javascript
// Configuration
const appCode = config.getConfigValue("APP_CODE");

// UUID generation
const newId = utils.UUID();

// Data reading with filters
const manufacturers = dataReaders.readManufacturers({ id: "M001" });

// Delta sync
const upserted = deltaSync.upsertRecords("materials", records);

// Change logging
changeLog.logChange("materials", uuid, "I", new Date());

// Cleanup
cleanup.cleanupSheet("manufacturers");

// Consistency checks
// Check all tables and get a report (simulate mode - doesn't delete)
const report = consistencyChecks.checkAndCleanAllTables(true);

// Check and clean all tables (actually delete invalid records)
const summary = consistencyChecks.checkAndCleanAllTables(false);

// Check a specific table only (simulate mode)
const result = consistencyChecks.checkAndCleanTable("purchase_order_items", true);

// Check for null UUIDs in a table
const nullCheck = consistencyChecks.checkNullUUIDs("basket_items");

// Setup
setup.setupDataTableSheet("vendors", true);

// Maintenance sheet setup
maintainManufacturerModelNames.setupSheet();
maintainManufacturerModelData.setupSheet();
```

## Prerequisites

- Node.js and npm installed
- Google account with access to Google Apps Script
- VS Code (recommended) or any code editor

## Setup Instructions

### 1. Install Dependencies

```bash
npm install
```

This installs:
- `@google/clasp` - Command-line tool for Apps Script
- `@types/google-apps-script` - TypeScript definitions for IntelliSense

### 2. Login to Google Apps Script

First time only:

```bash
npm run login
```

This opens a browser window to authenticate with your Google account.

### 3. Connect to Your Apps Script Project

You have two options:

#### Option A: Connect to Existing Project

1. Open your Google Apps Script project in browser
2. Get the Script ID from the URL: `https://script.google.com/home/projects/{SCRIPT_ID}/edit`
3. Copy the example configuration:

```bash
cp .clasp.json.example .clasp.json
```

4. Edit `.clasp.json` and replace `YOUR_SCRIPT_ID_HERE` with your actual Script ID:

```json
{
  "scriptId": "1a2b3c4d5e6f7g8h9i0j_actual_script_id",
  "rootDir": "."
}
```

**Note:** `.clasp.json` is gitignored and won't be committed to the repository.

#### Option B: Create New Project

```bash
npm run create
```

This creates a new Apps Script project linked to a Google Sheet.

### 4. Push Code to Google Apps Script

```bash
npm run push
```

This uploads all `.js` files to your Apps Script project. Clasp automatically converts them to `.gs` format when pushing to Google Apps Script.

## Usage

### Available npm Scripts

| Command | Description |
|---------|-------------|
| `npm run login` | Authenticate with Google (first time only) |
| `npm run push` | Upload all local files to Apps Script |
| `npm run pull` | Download files from Apps Script to local |
| `npm run open` | Open the Apps Script project in browser |
| `npm run create` | Create new Apps Script project |

### Development Workflow

1. **Edit Code Locally** - Use VS Code with IntelliSense support
2. **Push to Apps Script** - Run `npm run push`
3. **Test in Google Sheets** - Open your spreadsheet and test functionality
4. **Pull Changes** - If you made edits in web editor, run `npm run pull`

### VSCode IntelliSense

The project includes TypeScript definitions for full IntelliSense support:

- **Google Apps Script APIs** - Auto-complete for SpreadsheetApp, etc.
- **Namespace Objects** - Auto-complete for config, utils, cleanup, dataReaders, deltaSync, changeLog, etc.
- **Custom Functions** - Jump to definition across files (Cmd+Click)
- **Global Constants** - All constants from `constants.js` and `tableMetadata.js` are recognized

The `globals.d.ts` file declares only truly global functions (like `setup()`, `doPost()`, `onOpen()`). Namespace objects are automatically inferred by TypeScript from their const declarations in the JavaScript files.

Reload VS Code window if IntelliSense doesn't work: `Cmd+Shift+P` → "Developer: Reload Window"

## File Management

### Files to Push

All `.js` files are automatically pushed to Google Apps Script and converted to `.gs` format.

### Files Ignored (`.claspignore`)

The following files are NOT uploaded to Apps Script:
- `node_modules/`
- `package.json`, `package-lock.json`
- `jsconfig.json`, `globals.d.ts`
- `.git/`, `.gitignore`
- `README.md`

## Google Sheets Setup

### First Time Setup

1. Create a new Google Sheet for your Purchase App
2. Open **Extensions → Apps Script**
3. Note the Script ID from the URL
4. Update `.clasp.json` with this Script ID
5. Run `npm run push`
6. In Google Sheets: **Purchase App → Setup / Update Schema**

### Menu Functions

After setup, the Google Sheet has a custom menu:

**Purchase App Menu:**
- **Fill UUID** - Generate UUIDs for records missing them (calls `fillUUID()`)
- **Export Current Sheet to CSV** - Download current sheet as CSV (calls `csvExport.exportCurrentSheetToCSV()`)
- **Cleanup Current Sheet** - Remove data rows from current sheet (calls `cleanup.cleanupCurrentSheet()`)
- **Initialize Change Log from Data Sheets** - Create change log from existing data (calls `changeLog.initializeChangeLogFromDataSheets()`)
- **Write Condensed Change Log** - Generate condensed change log for all data (calls `changeLog.writeCondensedChangeLogForAllData()`)
- **Check Data Consistency** - Validate foreign key relationships across all tables (calls `checkDataConsistency()`)
- **Clean Data Consistency** - Find and remove records with invalid foreign keys (calls `cleanDataConsistency()`)
- **Setup / Update Schema** - Create or update all table schemas including basket tables (calls `setup.setupDataTableSheets()`)
- **Setup Maintain Manufacturer Material Models - Input Sheet** - Create "saveData" sheet for managing model names (calls `maintainManufacturerModelNames.setupSheet()`)
- **Setup Maintain Manufacturer Material Model Data - Input Sheet** - Create sheet for managing MRP/lot sizes (calls `maintainManufacturerModelData.setupSheet()`)
- **Setup Maintain Vendor Price Lists - Input Sheet** - Create sheet for vendor pricing (calls `maintainVendorPriceLists.setupSheet()`)

### Maintenance Sheets

The maintenance sheets use interactive checkbox buttons:

**"saveData" Sheet** (Manufacturer Material Model Names):
- Manufacturer dropdown to select manufacturer
- ⚡ **Prepare** - Load existing models for the selected manufacturer
- 💾 **Save** - Save new/modified model names to database
- 🗑️ **Clear** - Clear all input data

**"MaintainManufacturerMaterialModelData" Sheet** (MRP/Lot Size):
- Manufacturer dropdown to select manufacturer
- ⚡ **Prepare** - Load existing MRP and lot size data
- 💾 **Save** - Save updated MRP and lot size values
- 🗑️ **Clear** - Clear all input data

**"MaintainVendorPrices" Sheet** (Vendor Price Lists - Stub):
- Vendor, Manufacturer, and Material dropdowns
- ⚡ **Prepare** - Load vendor price data (not yet implemented)
- 💾 **Save** - Save updated vendor prices (not yet implemented)
- 🗑️ **Clear** - Clear all input data (not yet implemented)

## API Endpoints

The backend exposes a web service endpoint:

### POST Endpoint

**URL:** Deploy as Web App → Get deployment URL

**Operations:**
- `pull` - Download changes from Google Sheets
- `push` - Upload changes to Google Sheets

**Request Body:**
```json
{
  "secret": "your-secret-code",
  "operation": "pull",
  "since": "2024-01-01T00:00:00Z",
  "log": [],
  "tableRecords": {}
}
```

## Configuration

### Secret Code

Set your secret code in Google Sheets:
1. Create a sheet named `config`
2. Add row: `APP_CODE | your-secret-value`

### Table Metadata

All table schemas are defined in [tableMetadata.js](tableMetadata.js):
- 12 data tables: manufacturers, vendors, materials, manufacturer_materials, vendor_price_lists, purchase_orders, purchase_order_items, purchase_order_payments, basket_headers, basket_items, basket_vendors, basket_vendor_items
- Table names, columns, and data types with TABLE_NAMES_TO_INDICES (1-12)
- Column indices for efficient data access
- Lookup formulas for foreign key relationships (VLOOKUP formulas)
- Foreign key relationships with targetTable and targetColumn
- Numeric formatting rules
- All metadata deeply frozen using `Object.freeze()` for complete immutability

### Layout Constants

Maintenance sheets use frozen layout constants for consistent UI:

**`maintainManufacturerModelNames.LAYOUT`:**
- `SHEET: "saveData"` - Sheet name
- `TITLE_ROW: 1` - Title row position
- `INPUT_MANUFACTURER_ROW: 2` - Manufacturer dropdown row
- `BUTTONS_ROW: 3` - Button (checkbox) row
- `HEADER_ROW: 4` - Column header row
- `DATA_START_ROW: 5` - First data row
- `MATERIAL_COLUMN: 1`, `UNIT_COLUMN: 2` - Data columns
- `FIRST_MODEL_COLUMN: 3`, `NUMBER_OF_MODELS: 10` - Model columns (3-12)
- Button column positions: `PREPARE`, `SAVE`, `CLEAR` checkboxes

**`maintainManufacturerModelData.LAYOUT`:**
- `SHEET: "MaintainManufacturerMaterialModelData"` - Sheet name
- `MRP_COLUMN: 1`, `LOT_SIZE_COLUMN: 2` - Input columns
- `MATERIAL_COLUMN: 3`, `MODEL_COLUMN: 4`, `UNIT_COLUMN: 5`, `CURRENCY_COLUMN: 6` - Display columns
- Similar button and row structure as model names sheet

**`maintainVendorPriceLists.LAYOUT`:**
- `SHEET: "MaintainVendorPrices"` - Sheet name
- Vendor, Manufacturer, Material input rows
- Similar structure (stub implementation)

## Troubleshooting

### Push Fails

**Error:** `Push failed. Errors:`

**Solution:** 
- Check if you're logged in: `npm run login`
- Verify Script ID in `.clasp.json`
- Ensure you have edit permissions on the Apps Script project

### IntelliSense Not Working

**Solution:**
1. Reload VS Code: `Cmd+Shift+P` → "Developer: Reload Window"
2. Verify `jsconfig.json` exists
3. Check TypeScript version: Should auto-detect types

### Authentication Issues

**Error:** `User has not enabled the Apps Script API`

**Solution:**
1. Visit: https://script.google.com/home/usersettings
2. Enable "Google Apps Script API"
3. Try login again

## Best Practices

### Code Organization

- **Namespace pattern** - Functions are organized into namespace objects (config, utils, cleanup, etc.)
- **One function per purpose** - Keep functions focused and modular
- **Use namespaces** - Access functions via their namespace (e.g., `utils.UUID()`, `config.getConfigValue()`)
- **Use constants** - Define in `constants.js` or `tableMetadata.js`
- **Layout constants** - Use frozen objects for UI layouts (prevents accidental changes)
- **JSDoc comments** - Add type annotations for better IntelliSense
- **Error handling** - Use try-catch and log errors appropriately
- **Filter parameters** - Data readers support optional filter objects for efficient queries
- **Internal method calls** - Within namespace objects, use `this.methodName()` to call other methods

### Namespace Best Practices

**DO:**
```javascript
// Call namespace methods with the namespace prefix
const uuid = utils.UUID();
const manufacturers = dataReaders.readManufacturers();
cleanup.cleanupSheet("materials");
```

**Within namespace objects:**
```javascript
const myNamespace = {
  methodA() {
    // Call other methods in same namespace using 'this'
    this.methodB();
  },
  methodB() {
    // Can call methods from other namespaces directly
    const uuid = utils.UUID();
  }
};
```

### Syncing

- **Push frequently** - Small, incremental changes
- **Test before deploy** - Always test in Google Sheets after pushing
- **Pull before edit** - If using web editor, pull changes first

### Version Control

- **Commit locally first** - Git commit before pushing to Apps Script
- **Don't edit online** - Use local editor for consistency
- **Pull after collaboration** - If team members edit online

## Links

- [Google Apps Script Documentation](https://developers.google.com/apps-script)
- [clasp Documentation](https://github.com/google/clasp)
- [TypeScript Definitions](https://www.npmjs.com/package/@types/google-apps-script)

## License

ISC
