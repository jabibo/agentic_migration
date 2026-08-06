--<doku_rfc>
--=====================================================================================================================
--
--	DATUM				ENTWICKLER
--   ----------      --------------------    -----------------------------------------------------------------------
--											Initiale Version
--	13.07.2017		ReussM					AFM84892_BI-EC-@MySkills-BKE-Ergänzungen_zum_AFM-RfC_81919
--											Anpassung zu Schnittstellenänderung mit P72 (2 neue Attribute bkeberuf, kundentyp)
--	27.02.2019		ReussM					[AFM90745_Entfernung der Variable 'Kundentyp'] + [AFM90448_Implementierung einer neuen Variable 'Dringlichkeit']
--											Entfernung der ktd_id und Einbau dgk_id zu BM201903
--	20.05.2019		ReussM					[AFM87580_MYSKILLS_Monitoring_DIPF_BI]
--											Anpassung zu Schnittstellenänderung mit P92 (2 neue Attribute BKESPRACHE ud TRAEGERNUMMER)
--	16.02.2022		ReussM					[AFM102189_BPS-Cockpit_Änderungen_Schnittstelle_Delta_BI]
--											Anpassung Schnittstellenänderung zur Prv.22.01 
--											nur 3 statt 5 Dateien + (*.csv nach *.txt)
--											aus FC-Lieferung entfallen Attribute (PKEY|FKPKEY_FA|AKTIVITAET_DURCHGEFUEHRT|KD_NR|CREATED_BY|UPDATED_BY|)
--  06.02.2025		KaestnerT002			pd_geb_dat aus BI_DELTA_FC ausgebaut!
--=====================================================================================================================
--</doku_rfc>

USE /*<DBNAME_PD_DATA>*/con_data_201108/*<DBNAME_PD_DATA>*/
GO

DECLARE @pfad AS VARCHAR (512) = /*<'Ablauf.Pfad.Import'>*/'e:\bdata\batches\controlling_201108\work\import'/*<'Ablauf.Pfad.Import'>*/ + '\con_pd_data';
DECLARE @files AS TABLE ( [Name] VARCHAR(50),
						  [Deep] BIT,
						  [File] BIT);

INSERT INTO @files
EXEC xp_dirtree @pfad, 1, 1 

DECLARE @name VARCHAR (50);
DECLARE files CURSOR FOR SELECT REPLACE ([Name],'.txt','') FROM @files WHERE [File] = 1
OPEN files;
	WHILE 1=1 
	BEGIN
		FETCH NEXT FROM files INTO	@name;
		IF @@FETCH_STATUS <> 0 BREAK;

		DECLARE @sql VARCHAR (MAX) = '';
		IF CHARINDEX ('BI_DELTA_AZT', @name ,0) = 1
		
		SELECT @sql = 'CREATE TABLE [dbo].' + QUOTENAME(@name) + ' (
							[pd_pkey]			[int]			NULL ,
							[pd_aufzaehl_Name]	[varchar] (100)	NULL ,
							[pd_status]			[smallint]		NULL ,
							[pd_bez]			[varchar] (200)	NULL ,
							[pd_kurzbez]		[varchar] (100)	NULL )
							WITH ( DATA_COMPRESSION = PAGE )' 
			
		ELSE IF CHARINDEX ('BI_DELTA_FA', @name ,0) = 1
		
		SELECT @sql = 'CREATE TABLE [dbo].' + QUOTENAME(@name) + ' (
							[pd_agent_nr]		[varchar] (3)	NULL ,
							[pd_dat_eing]		[smalldatetime]	NULL ,
							[pd_asa_id]			[int]			NULL ,
							[pd_tkd_id]			[int]			NULL ,
							[pd_rks_a_id]		[int]			NULL )
							WITH ( DATA_COMPRESSION = PAGE )'


			
		ELSE IF CHARINDEX ('BI_DELTA_FC', @name ,0) = 1
							
		SELECT @sql = 'CREATE TABLE [dbo].' + QUOTENAME(@name) + ' (
							[pd_auftr_id]		[bigint]		NULL ,
							[pd_fehl_typ]		[int]			NULL ,
							[pd_fehler_txt]		[varchar] (512)	NULL ,
							[pd_dnst_nr]		[varchar] (3)	NULL ,
							[pd_tae_beauf]		[int]			NULL ,
							[pd_tae_durch]		[int]			NULL ,
							[pd_veranl_stl]		[int]			NULL ,
							[pd_rks_id]			[int]			NULL ,
							[pd_schul_abschl]	[int]			NULL ,
							[pd_geschlecht]		[int]			NULL ,
							[pd_leist_art_1]	[int]			NULL ,
							[pd_leist_art_2]	[int]			NULL ,
							[pd_beh_1]			[int]			NULL ,
							[pd_beh_2]			[int]			NULL ,
							[pd_beh_3]			[int]			NULL ,
							[pd_beh_4]			[int]			NULL ,
							[pd_anzahl_pt]		[smallint]		NULL ,
							[pd_eing_dat]		[smalldatetime]	NULL ,
							[pd_abschl_dat]		[smalldatetime]	NULL ,
							[pd_abschl_art]		[int]			NULL ,
							[pd_abschl_grund]	[int]			NULL ,
							[pd_gez]			[int]			NULL ,
							[pd_lz]				[int]			NULL ,
							[pd_create_dat]		[smalldatetime]	NULL ,
							[pd_update_dat]		[smalldatetime]	NULL ,
							[bps_bild_abs]		[int]			NULL ,
							[pd_lpe]			[int]			NULL ,
							[pd_lap]			[int]			NULL ,
							[pd_bkb_id]			[int]			NULL ,
							[pd_dgk_id]			[int]			NULL ,
							[pd_spr_id]			[int]			NULL ,
							[pd_trg_schl]		[varchar] (10)	NULL  )
							WITH ( DATA_COMPRESSION = PAGE )'

							
		ELSE IF CHARINDEX ('BI_DELTA_BL', @name ,0) = 1
		
		SELECT @sql = 'CREATE TABLE [dbo].' + QUOTENAME(@name) + ' (
							pd_user_name		[varchar] (50)	NOT NULL ,
							pd_spec_bakey		[varchar] (50)	NOT NULL )
							WITH ( DATA_COMPRESSION = PAGE )'

		ELSE IF CHARINDEX ('BI_DELTA_LS', @name ,0) = 1
		
		SELECT @sql = 'CREATE TABLE [dbo].' + QUOTENAME(@name) + ' (
							pd_spec_bakey		[varchar] (50)	NOT NULL ,
							pd_control_unit_bakey	[varchar] (50)	NOT NULL )
							WITH ( DATA_COMPRESSION = PAGE )'

	IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(@name) AND type in (N'U'))
	BEGIN 
		DECLARE @drop_sql varchar (200) = 'DROP TABLE [dbo].' + QUOTENAME(@name);
		EXEC dbo.up_ueb_log_Meldung	@audit_id	= /*<Strg.Audit_ID>*/NULL/*<Strg.Audit_ID>*/,
									@Meldung	= @drop_sql
		EXECUTE (@drop_sql);
	END
	
	EXEC dbo.up_ueb_log_CreateTable	@audit_id	= /*<Strg.Audit_ID>*/NULL/*<Strg.Audit_ID>*/, 
									@ObjectName = @name
	EXECUTE (@sql);
	END
	
CLOSE files;
DEALLOCATE files;
