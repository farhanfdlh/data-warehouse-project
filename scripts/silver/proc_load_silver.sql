/*
===============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
===============================================================================
Tujuan Script:
    Stored procedure ini menjalankan proses ETL (Extract, Transform, Load) untuk
    mengisi tabel-tabel di schema 'silver' dari schema 'bronze'.
    Aksi yang Dilakukan:
    - Mengosongkan (truncate) tabel-tabel Silver.
    - Memasukkan data yang telah ditransformasi dan dibersihkan dari Bronze ke tabel-tabel Silver.

Parameter:
    Tidak ada.
    Stored procedure ini tidak menerima parameter apapun atau mengembalikan nilai apapun.

Contoh Penggunaan:
    EXEC Silver.load_silver;
===============================================================================
*/

CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
	DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME;
	BEGIN TRY

		SET @batch_start_time = GETDATE();

		PRINT '================================================';
		PRINT 'Loading Silver Layer';
		PRINT '================================================';

		PRINT '------------------------------------------------';
		PRINT 'Loading CRM Tables';
		PRINT '------------------------------------------------';

		SET @start_time = GETDATE();
		PRINT '>>Truncating Table: silver.crm_customer_info'
		TRUNCATE TABLE silver.crm_customer_info; -- Clear existing data to avoid duplicates before inserting new records
		PRINT '>>Inserting Data Into: silver.crm_customer_info'
		INSERT INTO silver.crm_customer_info (
			cst_id,
			cst_key,
			cst_firstname,
			cst_lastname,
			cst_marital_status,
			cst_gndr,
			cst_create_date)

		SELECT
			cst_id,
			cst_key,
			TRIM (cst_firstname) AS cst_firsname, -- Remove unwanted spaces from first name
			TRIM (cst_lastname) AS cst_lastname, -- Remove unwanted spaces from last name
			CASE
				WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
				WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
				ELSE 'n/a' 
			END AS cst_marital_status, -- Normalize marital status values to readable format
			CASE 
				WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
				WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
				ELSE 'n/a' 
			END AS cst_gndr, -- Normalize gender values to readable format
			cst_create_date
		FROM (
			SELECT
			*,
			ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
			FROM bronze.crm_customer_info
			WHERE cst_id IS NOT NULL
		)t
		WHERE flag_last = 1; -- Remove duplicates and Select the most recent record per customer
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -----------------------------';

		SET @start_time = GETDATE();
		PRINT '>>Truncating Table: silver.crm_product_info'
		TRUNCATE TABLE silver.crm_product_info;
		PRINT '>>Inserting Data Into: silver.crm_product_info'
		INSERT INTO silver.crm_product_info (
			prd_id,
			cat_id,
			prd_key,
			prd_nm,
			prd_cost,
			prd_line,
			prd_start_dt,
			prd_end_dt
		)
		SELECT 
			prd_id,
			REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id, -- Extract category ID from prd_key and replace hyphens with underscores for consistency
			SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key, -- Extract product key by removing the category prefix
			prd_nm,
			ISNULL(prd_cost, 0) AS prd_cost, -- Replace NULL costs with 0 to avoid issues in calculations
			CASE UPPER(TRIM(prd_line))
				WHEN 'M' THEN 'Mountain'
				WHEN 'R' THEN 'Road'
				WHEN 'T' THEN 'Touring'
				WHEN 'S' THEN 'Other Sales'
				ELSE 'n/a'
			END AS prd_line, -- Map product line codes to descriptive values
			CAST (prd_start_dt AS DATE) AS prd_start_dt, -- Convert start date to DATE only
			CAST(
				LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt) - 1 
				AS DATE
			) AS prd_end_dt -- Calculate end date as the day before the next start date for the same product key, ensuring no overlapping periods
		FROM bronze.crm_product_info;
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -----------------------------';

		SET @start_time = GETDATE();
		PRINT '>>Truncating Table: silver.crm_sales_details'
		TRUNCATE TABLE silver.crm_sales_details;
		PRINT '>>Inserting Data Into: silver.crm_sales_details'
		INSERT INTO silver.crm_sales_details (
			sls_ord_num,
			sls_prd_key,
			sls_cust_id,
			sls_order_dt,
			sls_ship_dt,
			sls_due_dt,
			sls_sales,
			sls_quantity,
			sls_price
		)
		SELECT 
			sls_ord_num,
			sls_prd_key,
			sls_cust_id,
			CASE WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL
				 ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE) 
			END AS sls_order_dt, -- Convert order date to DATE format, handling invalid formats by setting them to NULL and data type casting
			CASE WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8 THEN NULL
				 ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE) 
			END AS sls_ship_dt, -- Convert ship date
			CASE WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8 THEN NULL
				 ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE) 
			END AS sls_due_dt, -- Convert due date
			CASE WHEN sls_sales IS NULL OR sls_sales <=0 OR sls_sales != sls_quantity * ABS(sls_price)
				 THEN sls_quantity * ABS(sls_price)
				 ELSE sls_sales
			END AS sls_sales, -- Calculate sales as quantity * price if sales is NULL, zero, negative, or inconsistent with quantity and price; otherwise, keep original sales value
			sls_quantity,
			CASE WHEN sls_price iS NULL OR sls_price <= 0 
				 THEN sls_sales / NULLIF(sls_quantity, 0)
				 ELSE sls_price
			END AS sls_price -- Derive price from sales and quantity if price is NULL or non-positive; otherwise, keep original price value
		FROM bronze.crm_sales_details
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -----------------------------';

		SET @start_time = GETDATE();
		PRINT '>>Truncating Table: silver.erp_cust_az12'
		TRUNCATE TABLE silver.erp_cust_az12;
		PRINT '>>Inserting Data Into: silver.erp_cust_az12'
		INSERT INTO silver.erp_cust_az12 (
			cid, 
			bdate, 
			gen
		)
		SELECT
			CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
				 ELSE cid 
			END AS cid, -- Remove 'NAS' prefix from cid if present, otherwise keep it as is
			CASE WHEN bdate > GETDATE() THEN NULL
				 ELSE bdate 
			END AS bdate, -- Set bdate to NULL if it is in the future, otherwise keep it as is
			CASE WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
				 WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
				 ELSE 'n/a' 
			END AS gen -- Normalize gender values and handle unknown cases
		FROM bronze.erp_cust_az12
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -----------------------------';

		SET @start_time = GETDATE();
		PRINT '>>Truncating Table: silver.erp_loc_a101'
		TRUNCATE TABLE silver.erp_loc_a101;
		PRINT '>>Inserting Data Into: silver.erp_loc_a101'
		INSERT INTO silver.erp_loc_a101 (
			cid, 
			cntry
		)
		SELECT
			REPLACE(cid, '-', '') cid, -- Remove hyphens from cid
			CASE WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
				 WHEN TRIM(cntry) = 'DE' THEn 'Germany'
				 WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
				 ELSE TRIM(cntry)
			END AS cntry -- Normalize and handle missing or blank country codes
		FROM bronze.erp_loc_a101
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -----------------------------';

		SET @start_time = GETDATE();
		PRINT '>>Truncating Table: silver.erp_px_cat_g1v2'
		TRUNCATE TABLE silver.erp_px_cat_g1v2;
		PRINT '>>Inserting Data Into: silver.erp_px_cat_g1v2'
		INSERT INTO silver.erp_px_cat_g1v2 (
			id, 
			cat, 
			subcat, 
			maintenance
		)
		SELECT 
			id, 
			cat, 
			subcat, 
			maintenance 
		FROM bronze.erp_px_cat_g1v2
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -----------------------------';

		SET @batch_end_time = GETDATE();
		PRINT '==================================';
		PRINT 'Finished Loading Silver Layer';
		PRINT '>> Total Load Duration: ' + CAST(DATEDIFF(second, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
		PRINT '==================================';

	END TRY
	BEGIN CATCH
		PRINT '=========================================';
		PRINT 'ERROR OCCURED DURING LOADING SILVER LAYER';
		PRINT 'Error Message' + CAST (ERROR_NUMBER() AS NVARCHAR);
		PRINT 'Error Message' + CAST (ERROR_STATE() AS NVARCHAR);
		PRINT '=========================================';
	END CATCH
END
