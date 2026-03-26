/*
=============================================================
Create Database and Schemas
=============================================================
Tujuan Script:
  Script ini membuat database baru bernama 'DataWarehouse' setelah mengecek apakah database tersebut sudah ada sebelumnya.
  ika database sudah ada, maka akan dihapus dan dibuat ulang. Selain itu, script ini juga membuat tiga schema
  di dalam database tersebut: 'bronze', 'silver', dan 'gold'.
	
PERINGATAN:
  Menjalankan script ini akan menghapus seluruh database 'DataWarehouse' jika sudah ada.
  Semua data di dalam database akan terhapus secara permanen. Harap berhati-hati
  dan pastikan kamu sudah memiliki backup yang sesuai sebelum menjalankan script ini.
*/

USE master;
GO

-- Drop and recreate the 'DataWarehouse' database
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'DataWarehouse')
BEGIN
    ALTER DATABASE DataWarehouse SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DataWarehouse;
END;
GO

-- Create Database 'DataWarehouse'
CREATE DATABASE DataWarehouse;
GO
USE DataWarehouse;
GO

-- Create Schemas 'bronze', 'silver', and 'gold'
CREATE SCHEMA bronze;
GO
CREATE SCHEMA silver;
GO
CREATE SCHEMA gold;
GO
