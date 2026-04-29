/*
===============================================================================
Quality Checks
===============================================================================
Tujuan Script:
    Script ini melakukan pengecekan kualitas untuk memvalidasi integritas, 
    konsistensi, dan akurasi dari Layer Gold. Pengecekan ini memastikan:
    - Keunikan surrogate key pada tabel dimensi.
    - Integritas referensial antara tabel fakta dan tabel dimensi.
    - Validasi relasi dalam model data untuk keperluan analitis.

Catatan Penggunaan:
    - Selidiki dan selesaikan setiap ketidaksesuaian yang ditemukan selama 
      pengecekan.
===============================================================================
*/

-- ====================================================================
-- Checking 'gold.dim_customers'
-- ====================================================================
-- Check for Uniqueness of Customer Key in gold.dim_customers
-- Expectation: No results 
SELECT 
    customer_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_customers
GROUP BY customer_key
HAVING COUNT(*) > 1;

-- ====================================================================
-- Checking 'gold.product_key'
-- ====================================================================
-- Check for Uniqueness of Product Key in gold.dim_products
-- Expectation: No results 
SELECT 
    product_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_products
GROUP BY product_key
HAVING COUNT(*) > 1;

-- ====================================================================
-- Checking 'gold.fact_sales'
-- ====================================================================
-- Check the data model connectivity between fact and dimensions
SELECT * 
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
ON c.customer_key = f.customer_key
LEFT JOIN gold.dim_products p
ON p.product_key = f.product_key
WHERE p.product_key IS NULL OR c.customer_key IS NULL  
