# Shopping Basket Feature Implementation

## Overview
The shopping basket feature enables users to create baskets of items, compare vendor quotations, and select the best prices. This is a complete implementation following the specifications in prompt-05.md.

## Database Schema

### New Tables (4)
1. **basket_headers** - Shopping basket headers with auto ID, dates, description, and computed totals
2. **basket_items** - Items in a basket with quantities and prices from manufacturer materials
3. **basket_vendors** - Vendor quotations for a basket with computed roll-ups
4. **basket_vendor_items** - Individual item quotations from vendors with availability and pricing

### Table Indices
All basket tables are registered in the sync configuration:
- basket_headers: 9
- basket_items: 10
- basket_vendors: 11
- basket_vendor_items: 12

### Foreign Key Relationships
- basket_items → basket_headers (basket_uuid)
- basket_items → manufacturer_materials (manufacturer_material_uuid)
- basket_vendors → basket_headers (basket_uuid)
- basket_vendors → vendors (vendor_uuid)
- basket_vendor_items → basket_vendors (basket_vendor_uuid)
- basket_vendor_items → basket_headers (basket_uuid)
- basket_vendor_items → basket_items (basket_item_uuid)
- basket_vendor_items → vendor_price_lists (vendor_price_list_uuid)

## Models (4 new files)
- `basket_header.dart` - BasketHeader model with all fields
- `basket_item.dart` - BasketItem model with material references
- `basket_vendor.dart` - BasketVendor model with vendor reference
- `basket_vendor_item.dart` - BasketVendorItem model with complex relationships

## Database Helper Methods
Added to `database_helper.dart`:
- **Basket Headers CRUD**: createBasketHeader, getAllBasketHeaders, getBasketHeader, updateBasketHeader, deleteBasketHeader
- **Basket Items CRUD**: createBasketItem, getBasketItems, getBasketItem, updateBasketItem, deleteBasketItem, deleteBasketItemsByBasketUuid
- **Basket Vendors CRUD**: createBasketVendor, getBasketVendors, getBasketVendor, updateBasketVendor, deleteBasketVendor, deleteBasketVendorsByBasketUuid
- **Basket Vendor Items CRUD**: createBasketVendorItem, getBasketVendorItems, getBasketVendorItem, updateBasketVendorItem, deleteBasketVendorItem
- **Helper methods**:
  - `_getNextIdForBasket()` - Auto-increment ID within basket scope
  - `_updateBasketHeaderTotals()` - Recalculate basket total price and item count
  - `_updateBasketVendorTotals()` - Recalculate vendor quotation totals and availability counts

## UI Screens (6 new files)

### 1. Baskets Screen (`baskets_screen.dart`)
- Lists all baskets with search functionality
- Displays: ID, description, date, expected delivery, item count, total price
- Navigate to basket details
- Create new basket
- Delete basket (cascades to items and vendor quotations)

### 2. Basket Detail Screen (`basket_detail_screen.dart`)
- Edit basket header: date, description, expected delivery, currency
- **Manufacturer Material Search**: Toggle search UI to find and add materials
- List of basket items with edit/delete
- Summary showing item count and total price
- Button to navigate to vendor quotations comparison
- Automatic total recalculation on item changes

### 3. Basket Item Detail Screen (`basket_item_detail_screen.dart`)
- Shows material details: manufacturer, model, material name, unit, MRP
- Edit quantity
- Automatic price calculation: quantity × MRP
- Real-time price updates as quantity changes
- Save to update basket item

### 4. Basket Vendors Screen (`basket_vendors_screen.dart`)
- Lists all vendor quotations for a basket
- **Best Price Highlighting**: First quotation (lowest total) marked with 🏆
- Shows availability (available/unavailable item counts)
- Displays base price, tax, and total for each vendor
- Add new vendor quotation
- Delete vendor quotation
- Navigate to quotation details

### 5. Basket Vendor Detail Screen (`basket_vendor_detail_screen.dart`)
- Vendor information display
- Edit quotation date and expected delivery date
- **Generate Items Button**: Auto-creates vendor items from basket items
  - Matches basket items with vendor price lists
  - Marks items as available/unavailable
  - Copies pricing from vendor price list if available
  - Auto-calculates totals
- Summary with available/unavailable counts, base price, tax, total
- List of vendor items with availability indicators
- Edit individual vendor items

### 6. Basket Vendor Item Detail Screen (`basket_vendor_item_detail_screen.dart`)
- Toggle item availability
- Edit rate before tax and tax percent (when available)
- Automatic calculations:
  - Rate = Rate Before Tax × (1 + Tax% / 100)
  - Base Price = Rate Before Tax × Quantity
  - Tax Amount = Base Price × Tax% / 100
  - Total Amount = Base Price + Tax Amount
- Real-time updates as prices change
- Save to update vendor item (triggers vendor total recalculation)

## Navigation
Added "Baskets" menu item to Home Screen with shopping_basket icon in deep orange color.

## Key Features Implemented

### Auto-Numbering
- Basket headers, items, and vendors have auto-incrementing IDs
- IDs are scoped per basket for items and vendors
- Implemented using `_getNextId()` and `_getNextIdForBasket()` helpers

### Computed Fields with Auto-Update
- **Basket Header**:
  - `total_price`: Sum of all item prices
  - `number_of_items`: Count of items
  - Updated automatically on item insert/update/delete

- **Basket Vendor**:
  - `base_price`: Sum of vendor item base prices
  - `tax_amount`: Sum of vendor item tax amounts
  - `total_amount`: Sum of vendor item total amounts
  - `number_of_available_items`: Count of available items
  - `number_of_unavailable_items`: Count of unavailable items
  - Updated automatically on vendor item insert/update/delete

- **Basket Vendor Item**:
  - `rate`: Calculated from rate before tax and tax percent
  - `base_price`: Rate before tax × quantity
  - `tax_amount`: Base price × tax percent / 100
  - `total_amount`: Base price + tax amount

### Search Functionality
- Manufacturer material search in basket detail screen
- Search by manufacturer name, material name, or model
- Toggle between basket view and search view
- Add materials directly from search results

### Vendor Quotation Generation
- Automatically creates vendor items from basket items
- Matches with vendor price lists to populate rates
- Marks availability based on vendor price list existence
- One-click geheaders_date` on basket_headers(date)
- `idx_basket_headers_updated_at` on basket_headers(updated_at)
- `idx_basket_items_basket` on basket_items(basket_uuid)
- `idx_basket_items_manufacturer_material` on basket_items(manufacturer_material_uuid)
- `idx_basket_items_updated_at` on basket_items(updated_at)
- `idx_basket_vendors_basket` on basket_vendors(basket_uuid)
- `idx_basket_vendors_vendor` on basket_vendors(vendor_uuid)
- `idx_basket_vendors_updated_at` on basket_vendors(updated_at)
- `idx_basket_vendor_items_basket_vendor` on basket_vendor_items(basket_vendor_uuid)
- `idx_basket_vendor_items_basket` on basket_vendor_items(basket_uuid)
- `idx_basket_vendor_items_basket_item` on basket_vendor_items(basket_item_uuid)
- `idx_basket_vendor_items_updated_at` on basket_vendor_items(updated_at

### Data Integrity
- Foreign key relationships maintained
- Cascade delete from header to items to vendor quotations
- Proper UUID primary keys throughout
- Updated_at timestamps on all records
- Change log integration for delta sync

## Database Indexes
Added for performance:
- `idx_basket_items_basket` on basket_items(basket_uuid)
- `idx_basket_items_manufacturer_material` on basket_items(manufacturer_material_uuid)
- `idx_basket_vendors_basket` on basket_vendors(basket_uuid)
- `Backend Integration

### Google Apps Script (tableMetadata.js)
Extended TABLE_DEFINITIONS with basket tables:
- basket_headers with 9 columns (uuid, id, date, description, expected_delivery_date, total_price, currency, number_of_items, updated_at)
- basket_items with 13 columns and LOOKUP_COLUMNS for manufacturer_name, material_name
- basket_vendors with 13 columns and LOOKUP_COLUMNS for vendor_name
- basket_vendor_items with 19 columns and LOOKUP_COLUMNS for material_name

All FOREIGN_KEY_RELATIONSHIPS defined with targetTable and targetColumn (frozen objects).

### Consistency Checks (consistencyChecks.js)
Added basket tables to processingOrder for foreign key validation:
1. basket_vendor_items (most dependent - 4 foreign keys)
2. basket_items (depends on basket_headers, manufacturer_materials)
3. basket_vendors (depends on basket_headers, vendors)
4. basket_headers (parent table - deleted last)

### Sync Configuration (sync_config.dart)
Updated tableIndices and tableNamesByIndices with basket tables (indices 9-12).

## Files Modified
1. `lib/services/database_helper.dart` - Added 4 tables with indexes, CRUD methods, helper methods
2. `lib/screens/home_screen.dart` - Added Baskets menu item
3. `lib/config/sync_config.dart` - Added basket table indices for delta sync
4. `backend/google-app-script-code/tableMetadata.js` - Extended TABLE_DEFINITIONS with basket tables
5. `backend/google-app-script-code/consistencyChecks.js` - Added basket tables to processingOrder

## Technical Details

### Data Immutability
All backend constants are deeply frozen using Object.freeze():
- TABLE_NAMES_TO_INDICES
- TABLE_DEFINITIONS (including all COLUMNS, LOOKUP_COLUMNS, FOREIGN_KEY_RELATIONSHIPS)
- Individual objects within FOREIGN_KEY_RELATIONSHIPS arrays

### Delta Sync Support
- All basket tables integrated with change_log mechanism
- Table indices registered for proper sync ordering
- Change logging on all insert/update/delete operations
- Backend consistency validation enabled

### Cascade Delete
Proper cascade delete order maintained:
1. Delete basket_vendor_items (most dependent)
2. Delete basket_vendors
3. Delete basket_items
4. Delete basket_headers (parent)

## Notes
- All code follows existing patterns in the app
- Proper error handling and user feedback
- Loading states with progress indicators
- Confirmation dialogs for delete operations
- Real-time calculations with immediate UI updates
- Clean separation of concerns (models, services, screens)
- Consistent with Material Design guidelines
- Full integration with existing database and sync infrastructure
- Backend and frontend table indices synchronized (9-12)
- All foreign key relationships validated by backend consistency checks
9. `lib/screens/basket_vendor_detail_screen.dart`
10. `lib/screens/basket_vendor_item_detail_screen.dart`
11. `BASKET_FEATURE.md` - This documentation file
6. `lib/screens/basket_detail_screen.dart`
7. `lib/screens/basket_item_detail_screen.dart`
8. `lib/screens/basket_vendors_screen.dart`
9. `lib/screens/basket_vendor_detail_screen.dart`
10. `lib/screens/basket_vendor_item_detail_screen.dart`

## Usage Flow
1. User creates a new basket from Baskets screen
2. In basket detail, user adds items by searching manufacturer materials
3. User sets quantities for each item
4. User clicks "Compare Vendor Quotations"
5. User adds vendor quotations by selecting vendors
6. For each vendor quotation, user clicks "Generate Items"
7. System auto-populates items from basket with vendor prices
8. User can manually edit rates and availability
9. User compares vendors to find best price
10. Best price is automatically highlighted

## Notes
- All code follows existing patterns in the app
- Proper error handling and user feedback
- Loading states with progress indicators
- Confirmation dialogs for delete operations
- Real-time calculations with immediate UI updates
- Clean separation of concerns (models, services, screens)
- Consistent with Material Design guidelines
- Full integration with existing database and sync infrastructure
