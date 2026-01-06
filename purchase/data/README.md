# Sample Data Files

This folder contains CSV template files for importing data into the Purchase Application database.

## File Structure

### 1. manufacturers.csv
Contains manufacturer data.

**Columns:**
- `uuid` (required): Unique identifier for the manufacturer
- `name` (required): Manufacturer name
- `description` (optional): Description of the manufacturer

**Example:**
```csv
uuid,name,description
mfg-001,Apple Inc,Technology company specializing in consumer electronics
```

### 2. vendors.csv
Contains vendor/supplier data.

**Columns:**
- `uuid` (required): Unique identifier for the vendor
- `name` (required): Vendor name
- `description` (optional): Description of the vendor
- `address` (optional): Vendor address
- `geo_location` (optional): Geographic location (latitude,longitude)

**Example:**
```csv
uuid,name,description,address,geo_location
ven-001,TechSupply Co,Electronics supplier,123 Tech Street,40.7128,-74.0060
```

### 3. materials.csv
Contains material/product data.

**Columns:**
- `uuid` (required): Unique identifier for the material
- `name` (required): Material name
- `description` (optional): Description of the material
- `unit_of_measure` (required): Unit of measure (e.g., pcs, kg, liters)

**Example:**
```csv
uuid,name,description,unit_of_measure
mat-001,Laptop,Portable computer,pcs
```

### 4. manufacturer_materials.csv
Contains manufacturer material/model data.

**Columns:**
- `uuid` (required): Unique identifier
- `manufacturer_uuid` (required): UUID from manufacturers.csv
- `material_uuid` (required): UUID from materials.csv
- `model` (required): Model name/number
- `selling_lot_size` (optional): Selling lot size (integer)
- `max_retail_price` (optional): Maximum retail price (decimal)
- `currency` (optional): Currency code (e.g., USD, EUR)

**Example:**
```csv
uuid,manufacturer_uuid,material_uuid,model,selling_lot_size,max_retail_price,currency
mm-001,mfg-001,mat-001,MacBook Pro 16-inch,1,2499.00,USD
```

### 5. vendor_price_lists.csv
Contains vendor pricing information.

**Columns:**
- `uuid` (required): Unique identifier
- `manufacturer_material_uuid` (required): UUID from manufacturer_materials.csv
- `vendor_uuid` (required): UUID from vendors.csv
- `rate` (required): Price rate (decimal)
- `currency` (optional): Currency code
- `tax_percent` (required): Tax percentage (decimal)

**Note:** Tax amount is automatically calculated as: `rate * tax_percent / 100`

**Example:**
```csv
uuid,manufacturer_material_uuid,vendor_uuid,rate,currency,tax_percent
vpl-001,mm-001,ven-001,2299.00,USD,8.5
```

## Import Order

When importing data, follow this order to maintain referential integrity:

1. **manufacturers.csv** - Import first (no dependencies)
2. **vendors.csv** - Import second (no dependencies)
3. **materials.csv** - Import third (no dependencies)
4. **manufacturer_materials.csv** - Import fourth (depends on manufacturers and materials)
5. **vendor_price_lists.csv** - Import last (depends on manufacturer_materials and vendors)

The import service automatically handles this order.

## Usage

1. Edit the CSV files with your data
2. Ensure UUIDs are unique and match across related files
3. Use the "Import Data" button in the app's home screen
4. The app will import all CSV files in the correct order

## Notes

- UUIDs must be unique within each table
- Foreign key references (manufacturer_uuid, material_uuid, vendor_uuid, manufacturer_material_uuid, etc.) must exist in their respective tables
- Empty optional fields can be left blank
- The import process will update existing records if the UUID already exists
- All dates (updated_at) are automatically set to the current timestamp during import

