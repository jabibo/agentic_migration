-- =============================================
-- Script Template
-- =============================================
CREATE TABLE tf_deltant_pd_azt  (
    pd_pkey            INTEGER        NOT NULL,
    pd_aufzaehl_Name   NVARCHAR(100)   NOT NULL,
    pd_status          SMALLINT       NOT NULL, 
    pd_bez             NVARCHAR(200),
    pd_kurzbez         NVARCHAR(100),
    bi_load_date       CHAR(15)       NOT NULL, 
    bi_load_filename   NVARCHAR(256)   NOT NULL
) WITH ( DATA_COMPRESSION = PAGE );
