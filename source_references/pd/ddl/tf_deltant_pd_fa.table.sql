-- =============================================
-- Script Template
-- =============================================
CREATE TABLE tf_deltant_pd_fa  (
	[pd_dat_akt]         [datetime] NOT NULL,
	[pd_agent_nr]        [nvarchar](3) NOT NULL,
	[pd_zeit_von]        [smalldatetime] NOT NULL,
	[pd_zeit_bis]        [smalldatetime] NOT NULL,
	[pd_dat_eing]        [smalldatetime] NOT NULL,
	[pd_asa_id]          [int] NULL,
	[pd_tkd_id]          [int] NULL,
	[pd_rks_a_id]        [int] NULL,
	[pd_anz_eingae]      [int] NOT NULL,
	[pd_anz_in_bear]     [int] NOT NULL,
	[bi_load_date]       [nchar](15) NOT NULL,
	[bi_load_filename]   [nvarchar](256) NOT NULL
) WITH ( DATA_COMPRESSION = PAGE );


