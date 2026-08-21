# Retail Sales Data Warehouse — ETL Pipeline & Star Schema

> Designing and building a modern SQL Server data warehouse that consolidates fragmented CRM and ERP sales data into a single, analysis-ready source of truth.

---

## 📑 Table of Contents

- [Business Background](#-business-background)
- [Business Objective](#-business-objective)
- [Data Overview](#-data-overview)
- [Approach / Methodology](#-approach--methodology)
- [Data Transformation](#-data-transformation)
- [Data Model (Star Schema)](#-data-model-star-schema)
- [Key Outcomes](#-key-outcomes)
- [Business Impact & Recommendations](#-business-impact--recommendations)
- [Tools & Tech Stack](#%EF%B8%8F-tools--tech-stack)
- [Repository Structure](#-repository-structure)
- [Related Project](#-related-project)
- [Author](#-author)

---

## 📌 Business Background

Sales data lived in two disconnected source systems — **CRM** and **ERP** — each with its own format, keys, and quality issues. Without a unified structure, every reporting request meant manually pulling and reconciling CSV exports, which was slow, error-prone, and not scalable as the business grew. There was no single, trusted place for analysts or stakeholders to go for sales, customer, or product data.

## 🎯 Business Objective

Build a centralized data warehouse that:
- Combines CRM and ERP data into one **unified, analytical data model**
- Resolves data quality issues (duplicates, inconsistent formatting, invalid values) before the data reaches business users
- Provides a **query-ready structure** that supports fast, reliable reporting without repeated manual data wrangling
- Is documented well enough for both technical and non-technical stakeholders to understand what the data represents

This project focuses on the **latest snapshot of data** (historical tracking/versioning is out of scope).

## 📂 Data Overview

| Source | Format | Contents |
|---|---|---|
| CRM | CSV | Customer info, sales transactions, product mapping |
| ERP | CSV | Customer demographics, location, additional product attributes |

## 🔧 Approach / Methodology

The warehouse follows the **Medallion Architecture** (Bronze → Silver → Gold):

```
Raw CSV Files (CRM + ERP)
        ↓
🥉 Bronze Layer   → Raw ingestion via BULK INSERT, data kept as-is for traceability
        ↓
🥈 Silver Layer   → Cleansing, standardization, deduplication, business rule handling
        ↓
🥇 Gold Layer     → Star Schema modeling, business-ready views for reporting
```

Each layer is built with SQL **stored procedures**, making the pipeline repeatable and re-runnable end-to-end.

![Data Architecture](docs/data_architecture.png)

## 🔄 Data Transformation

**Silver Layer (Bronze → Silver) — cleansing & standardization**
- **Customers (CRM):** dropped rows with missing customer IDs, kept only the most recent record per customer, trimmed name fields, and standardized marital status and gender codes into readable labels.
- **Products (CRM):** split the raw product key into a category ID and a clean product key, defaulted missing costs to 0, mapped product line codes to descriptive categories, and derived each product's end date from the next version's start date to preserve version history.
- **Sales (CRM):** validated and cast order, ship, and due dates, and recalculated sales amount and unit price whenever stored values were missing, zero, or inconsistent with quantity × price.
- **Customer demographics (ERP):** stripped system-generated ID prefixes, nulled out birthdates set in the future, and standardized gender labels.
- **Location (ERP):** cleaned ID formatting and standardized country names (e.g., US/USA → United States).
- **Product categories (ERP):** loaded as-is; no transformation required.

**Gold Layer (Silver → Gold) — integration & modeling**
- **dim_customers:** merged CRM and ERP customer data with generated surrogate keys, applying a fallback rule where gender defaults to the ERP source whenever CRM data is unavailable.
- **dim_products:** joined with ERP category data and generated surrogate keys, filtering to only the current/active version of each product (historical versions excluded).
- **fact_sales:** joined sales transactions to both dimension tables, replacing natural keys with surrogate keys to preserve referential integrity across the star schema.

## ⭐ Data Model (Star Schema)

The Gold Layer is modeled as a Star Schema optimized for analytical queries, with a central **Sales Fact table** connected to **Customer** and **Product** dimension tables — enabling fast slicing by customer, product, and time without complex joins across raw source tables.

## 📈 Key Outcomes

- A fully automated ETL pipeline from raw CSV to business-ready Star Schema
- A single, cleaned, and documented dataset merging CRM + ERP — eliminating the need to manually reconcile two source systems
- Reusable stored procedures that can be re-run whenever new source extracts arrive
- Supporting documentation (data catalog and naming conventions in [`docs/`](docs/)) so both technical and non-technical stakeholders can understand what each field and table represents without reading the underlying SQL

## 💡 Business Impact & Recommendations

**1. Enables self-service BI/reporting**
With a clean Star Schema in place, analysts and business teams no longer need SQL expertise in raw source systems — they can connect BI tools (Power BI, Tableau, Excel) directly to the Gold Layer and get consistent numbers every time.

**2. Reduces manual reporting effort**
What used to require manually exporting and reconciling two CSV sources can now be answered with a single query against the warehouse — cutting report turnaround time and reducing the risk of human error in manual merging.

**3. Recommended next steps for the business**
- Layer a BI dashboard (Power BI/Tableau) directly on top of the Gold Layer for real-time sales monitoring
- Add incremental loading/historization if the business later needs trend analysis over multiple snapshots, not just the latest state
- Extend the model with additional fact tables (e.g., returns, inventory) as new reporting needs emerge

*(See the follow-up analytics work built on top of this warehouse in the [related project](#-related-project) below.)*

## 🛠️ Tools & Tech Stack

| Tool | Purpose |
|---|---|
| SQL Server Express | Database engine |
| SQL Server Management Studio (SSMS) | Database GUI |
| Draw.io | Architecture & data flow diagrams |
| Git & GitHub | Version control |

## 📂 Repository Structure

```
data-warehouse-project/
│
├── datasets/                           # Raw datasets (ERP and CRM CSV files)
│
├── docs/                                # Project documentation and architecture diagrams
│   ├── data_architecture.drawio         # Data architecture diagram
│   ├── data_flow.drawio                 # Data flow diagram
│   ├── data_models.drawio               # Star schema / data model diagram
│   ├── data_catalog.md                  # Dataset catalog with field descriptions
│   ├── naming-conventions.md            # Naming conventions for tables, columns, and files
│
├── scripts/                             # SQL scripts for ETL and transformations
│   ├── bronze/                          # Scripts for raw data ingestion
│   ├── silver/                          # Scripts for data cleansing and transformation
│   ├── gold/                            # Scripts for analytical views (Star Schema)
│
├── tests/                               # Data quality check scripts
│
├── README.md
└── LICENSE
```

## 🔗 Related Project

The analytics layer built on top of this warehouse — SQL-based customer, product, and sales trend analysis — is in a separate repository: **[SQL Data Analytics Project](https://github.com/farhanfdlh/data-analytics-project)**.

## 🙏 Acknowledgements

Built as a guided project following the [SQL Data Warehouse Project](https://www.youtube.com/watch?v=9GVqKuTVANE) tutorial by [Data With Baraa](https://github.com/DataWithBaraa), then documented and reframed here with a business/portfolio lens.

## 👤 Author

**Farhan Fadhilah Rasyid**

[![GitHub](https://img.shields.io/badge/GitHub-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/farhanfdlh)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-0077B5?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/farhan-fadhilah-rasyid)
[![Website](https://img.shields.io/badge/Website-000000?style=for-the-badge&logo=google-chrome&logoColor=white)](https://farhan-portfolio-smoky.vercel.app)
