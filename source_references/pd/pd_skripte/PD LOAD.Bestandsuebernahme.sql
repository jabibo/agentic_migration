-----------------------------------------------------------------------------------------------------------------------
--
--	Übertragung der Ladedaten in die Bestandsschicht. 
--
--	Schritt	1: Prüfung auf Existenz alter Bestandsdaten
--	Schritt	2: Integrieren aktueller Ladedaten in Bestandsdaten
--	Schritt	3: temporäre Übernahme der Daten für das DST-Mapping zur Weitergabe an das Cockpit 
--	<obsolete>	Schritt	4: Erzeuge View auf tf_deltant_pd_fc für die Umsetzung des AFM040701
-----------------------------------------------------------------------------------------------------------------------
--
--	22.09.2011	Stefan Junghans, AIS	Erstellung / Überarbeitung im Zuge der Migration auf SQL Srv 2008
--	29.02.2012	Stefan Junghans, AIS	Übernahme der DST-Mapping-Daten	(AFM36190)
--	12.06.2012	Stefan Junghans, AIS	AFM40701 Umgang mit unplausiblen Datensätzen für das Fachcontrolling des PD: Leer-Werte
--	13.09.2012	Stefan Junghans, AIS	Implementierung für AFM040701 wurde in separates Skript ausgelagert
--	19.11.2014	Stefan Junghans, AIS	AFM068953: BI_BER_68792_Weiterentwicklung BPS-Fachcontrolling Teil 2 - Anpassung der Laufzeitendarstellung - Bruttolaufzeiten
--	30.04.2015  ReussM					[AFM68795 Teil 3+4 Schnittstellenaenderung P51 bei FA-Daten]
--	25.04.2016  ReussM					[78830_BI-Ergebniscontrolling-BI_KNZ_78581_Verkürzung_Nutzungsdauer]
--	13.07.2017	ReussM					[AFM84892_BI-EC-@MySkills-BKE-Ergänzungen_zum_AFM-RfC_81919]
--										Anpassung zu Schnittstellenänderung mit P72 (2 neue Attribute bkeberuf, kundentyp)
--	27.02.2019	ReussM					[AFM90745_Entfernung der Variable 'Kundentyp'] + [AFM90448_Implementierung einer neuen Variable 'Dringlichkeit']
--										Entfernung der kdt_id und Einbau dgk_id zu BM201903 (P91)
--	20.05.2019	ReussM					[AFM87580_MYSKILLS_Monitoring_DIPF_BI]
--										Anpassung zu Schnittstellenänderung mit P92 (2 neue Attribute BKESPRACHE ud TRAEGERNUMMER)
--  01.02.2024	ReussM					AFM109413_Aktualisierung_BPS-Cockpit_Berichte (Attribut Alter/pd_geb_dat aus View "tf_deltant_pd_fc_k" zurückgebaut)
--  06.02.2025	KaestnerT002			pd_geb_dat aus BI_DELTA_FC ausgebaut!
-----------------------------------------------------------------------------------------------------------------------

	
USE		/*<DBNAME_PD_DWH>*/con_pd_dwh/*<DBNAME_PD_DWH>*/

DECLARE	@Audit_ID	INT
SELECT	@Audit_ID	= /*<Strg.Audit_ID>*/NULL/*<Strg.Audit_ID>*/

-------------------------------------------------------------------------------------

-- Schritt 1:
-- Prüfen auf Existenz der Bestandsdaten-DB	(con_pd_data_<Berichtsmonat	- 1>)

IF EXISTS(SELECT	* 
	FROM	sys.databases
	WHERE LOWER(name) =	LOWER(/*<'DBNAME_PD_DWH_Vormonat'>*/'con_pd_dwh_vm'/*<'DBNAME_PD_DWH_Vormonat'>*/))
-- Vormonats-DB	existiert, prüfe auf Bestandstabellen
BEGIN
--print	'Vormonatsbestand gefunden - starte	Übernahme in aktuellen Bestand.'
	EXEC	dbo.up_ueb_log_Meldung	@audit_id	= @Audit_ID, 
									@Meldung	= 'Vormonatsbestand	gefunden - starte Übernahme	in aktuellen Bestand.'	 

-------------------------------------------------------------------------------------
	
	
	TRUNCATE TABLE tf_deltant_pd_fc
	
	INSERT INTO	tf_deltant_pd_fc
	SELECT * 
	FROM /*<DBNAME_PD_DWH_Vormonat>*/con_pd_dwh_vm/*<DBNAME_PD_DWH_Vormonat>*/.dbo.tf_deltant_pd_fc
	
--print	'FC-Daten aus Vormonatsbestand übernommen: '
	EXEC	dbo.up_ueb_log_Meldung	@audit_id	= @Audit_ID, 
									@Meldung	= 'FC-Daten	aus	Vormonatsbestand übernommen: ',	
									@wert_Int	= @@ROWCOUNT
	
	TRUNCATE TABLE tf_deltant_pd_fa
	
	INSERT INTO	tf_deltant_pd_fa
	SELECT * 
	FROM /*<DBNAME_PD_DWH_Vormonat>*/con_pd_dwh_vm/*<DBNAME_PD_DWH_Vormonat>*/.dbo.tf_deltant_pd_fa
	
--print	'FA-Daten aus Vormonatsbestand übernommen: '
	EXEC	dbo.up_ueb_log_Meldung	@audit_id	= @Audit_ID, 
									@Meldung	= 'FA-Daten	aus	Vormonatsbestand übernommen: ',	
									@wert_Int	= @@ROWCOUNT

	TRUNCATE TABLE tf_deltant_pd_azt

	INSERT INTO	tf_deltant_pd_azt
	SELECT * 
	FROM /*<DBNAME_PD_DWH_Vormonat>*/con_pd_dwh_vm/*<DBNAME_PD_DWH_Vormonat>*/.dbo.tf_deltant_pd_azt
	
--print	'AZT-Daten aus Vormonatsbestand	übernommen:	'
	EXEC	dbo.up_ueb_log_Meldung	@audit_id	= @Audit_ID, 
									@Meldung	= 'AZT-Daten aus Vormonatsbestand übernommen: ', 
									@wert_Int	= @@ROWCOUNT
END

-- Schritt 2:
-- Übernahme der Ladedaten in aktuellen	Bestand.
EXEC	dbo.up_ueb_log_Meldung	@audit_id	= @Audit_ID, 
								@Meldung	= 'Übernahme der Ladedaten in aktuellen	Bestand.'

EXEC	/*<DBNAME_PD_CALC>*/con_pd_calc/*<DBNAME_PD_CALC>*/.dbo.up_ueb_object_DropTable	@audit_id	= @Audit_ID, 
																								@ObjectName	= 'tt_pd_loaded'

--print	'Ermitteln der Ladetabellen.'
EXEC	dbo.up_ueb_log_Meldung	@audit_id	= @Audit_ID, 
								@Meldung	= 'Ermitteln der Ladetabellen.'
SELECT	[l].[tabelle]
INTO	/*<DBNAME_PD_CALC>*/con_pd_calc/*<DBNAME_PD_CALC>*/.dbo.tt_pd_loaded
FROM	/*<DBNAME_CON_STRG>*/con_strg/*<DBNAME_CON_STRG>*/.dbo.[vm_inka_files_loaded]  AS [l]
INNER JOIN	/*<DBNAME_CON_STRG>*/con_strg/*<DBNAME_CON_STRG>*/.dbo.[vm_inka_ablauf_info]   AS [i] 
		ON	[i].[audit_id] = /*<DBNAME_CON_STRG>*/con_strg/*<DBNAME_CON_STRG>*/.[dbo].[uf_inka_audit_root](	[l].[audit_id] )
WHERE	[i].[Job] =	'PD_LOAD_DATA'
		AND	[l].uc4_id = /*<'Strg.UC4_Aufruf_ID'>*/'x'/*<'Strg.UC4_Aufruf_ID'>*/
ORDER BY [l].[tabelle] ASC

EXEC	/*<DBNAME_PD_CALC>*/con_pd_calc/*<DBNAME_PD_CALC>*/.dbo.up_ueb_log_CreateTable	@audit_id	= @Audit_ID, 
																						@ObjectName	= 'tt_pd_loaded', 
																						@RowCount	= @@ROWCOUNT

DECLARE		@table_name		VARCHAR(128), 
			@timestamp		VARCHAR(15), 
			@filename		VARCHAR(168), 
			@script			VARCHAR(MAX), 
			@script_insert	VARCHAR(MAX), 
			@script_sel_fc	VARCHAR(MAX), 
			@script_from	VARCHAR(MAX), 
			@script_where	VARCHAR(MAX), 
			@script_insert_err		VARCHAR(MAX), 
			@script_where_err		VARCHAR(MAX), 
			@script_meldung1		VARCHAR(MAX), 
			@script_meldung2		VARCHAR(MAX), 
			@script_meldung3		VARCHAR(MAX), 
			@crlf			CHAR(2), 
			@Meldung		VARCHAR(MAX)

-- erstelle	Skriptbausteine
SELECT		@crlf			= CHAR(13) + CHAR(10), 
			@script_insert	= 'INSERT INTO tf_deltant_pd_fc	',
			@script_sel_fc	= 'SELECT [pd_auftr_id], '
							+ '[pd_fehl_typ], '
							+ '[pd_fehler_txt],	'
							+ '[pd_dnst_nr], '
							+ '[pd_tae_beauf], '
							+ '[pd_tae_durch], '
							+ '[pd_veranl_stl],	'
							+ '[pd_rks_id],	'
							+ '[pd_schul_abschl], '
							+ '[pd_geschlecht],	'
							+ '[pd_leist_art_1], '
							+ '[pd_leist_art_2], '
							+ '[pd_beh_1], '
							+ '[pd_beh_2], '
							+ '[pd_beh_3], '
							+ '[pd_beh_4], '
							+ '[pd_anzahl_pt], '
							+ '[pd_eing_dat], '
							+ '[pd_abschl_dat],	'
							+ '[pd_abschl_art],	'
							+ '[pd_abschl_grund], '
							+ '[pd_gez], '
							+ '[pd_lz], '
							+ '[pd_create_dat],	'
							+ '[pd_update_dat],	'
							+ '[bps_bild_abs], '
							+ '[pd_lpe], '
							+ '[pd_lap], '
							+ '[pd_bkb_id], '
							+ '[pd_dgk_id], '
							+ '[pd_spr_id], '
							+ '[pd_trg_schl] '
							,	
			@script_from	= '	FROM ' 
							+ /*<'DBNAME_PD_DATA'>*/'con_pd_data'/*<'DBNAME_PD_DATA'>*/	
							+ '.dbo.', 
			@script_where	= '	WHERE pd_auftr_id NOT IN	(SELECT	pd_auftr_id FROM tf_deltant_pd_fc)'
							+ '	 AND pd_fehl_typ = 0'
							+ '	 AND pd_auftr_id	  IS NOT NULL'
							+ '	 AND pd_fehl_typ	  IS NOT NULL'
							+ '	 AND pd_dnst_nr		  IS NOT NULL'
							+ '	 AND pd_eing_dat	  IS NOT NULL'
							+ '	 AND pd_abschl_dat	  IS NOT NULL'
							+ '	 AND pd_abschl_art	  IS NOT NULL'
							+ '	 AND pd_create_dat	  IS NOT NULL'
							+ '	 AND pd_update_dat	  IS NOT NULL'
							+ @crlf, 
			@script_insert_err	= REPLACE(@script_insert, 'pd_fc', 'pd_fc_err'), 
			@script_where_err	= '	WHERE pd_auftr_id NOT IN	(SELECT	DISTINCT pd_auftr_id FROM tf_deltant_pd_fc)'
								+ '	 AND pd_fehl_typ = 0'
								+ '	 AND (pd_auftr_id	   IS NULL'
								+ '	  OR  pd_fehl_typ	   IS NULL'
								+ '	  OR  pd_dnst_nr	   IS NULL'
								+ '	  OR  pd_eing_dat	   IS NULL'
								+ '	  OR  pd_abschl_dat	   IS NULL'
								+ '	  OR  pd_abschl_art	   IS NULL'
								+ '	  OR  pd_create_dat	   IS NULL'
								+ '	  OR  pd_update_dat	   IS NULL)'
								+ @crlf, 
			@script_meldung1	= 'EXEC	' 
								+ /*<'DBNAME_PD_DATA'>*/'con_pd_data'/*<'DBNAME_PD_DATA'>*/
								+ '.dbo.up_ueb_log_Meldung	@audit_id =	'
								+ /*<'Strg.Audit_ID'>*/'NULL'/*<'Strg.Audit_ID'>*/
								+ ', @Meldung =	''Ladedaten	aus	##table_name## wurden in Bestand überführt:	'''
								+ ', @wert_Int = @@ROWCOUNT',
			@script_meldung2	= 'EXEC	' 
								+ /*<'DBNAME_PD_DATA'>*/'con_pd_data'/*<'DBNAME_PD_DATA'>*/
								+ '.dbo.up_ueb_log_Meldung	@audit_id =	'
								+ /*<'Strg.Audit_ID'>*/'NULL'/*<'Strg.Audit_ID'>*/
								+ ', @Meldung =	''Ladedaten	aus	##table_name## wurden wegen	Constraint-Verletzung abgelehnt: '''
								+ ', @wert_Int = @@ROWCOUNT',
			@script_meldung3	= 'EXEC	'
								+ /*<'DBNAME_PD_CALC'>*/'con_pd_calc'/*<'DBNAME_PD_CALC'>*/
								+ '.dbo.up_ueb_log_Meldung	@audit_id =	'
								+ /*<'Strg.Audit_ID'>*/'NULL'/*<'Strg.Audit_ID'>*/
								+ ', @Meldung =	''DST-Mapping-Daten	aus	##table_name## wurden zur Weiterverarbeitung übertragen: '''
								+ ', @wert_Int = @@ROWCOUNT'

-- ermittle	und	übertrage FC-Ladedaten
DECLARE	cur_fc CURSOR FOR
SELECT [tabelle],	REPLACE([tabelle], 'BI_DELTA_FC',	'')	[timestamp], [tabelle] + '.txt'
FROM /*<DBNAME_PD_CALC>*/con_pd_calc/*<DBNAME_PD_CALC>*/.dbo.tt_pd_loaded
WHERE [tabelle] LIKE '%FC%'

OPEN cur_fc

FETCH NEXT FROM	cur_fc INTO	@table_name, @timestamp, @filename

WHILE @@FETCH_STATUS = 0
BEGIN
	SELECT	@script	= @script_insert
					+ @script_sel_fc
					+ ',''' + @timestamp + ''',	'''	+ @filename	+ ''''					
					+ @script_from
					+ @table_name
					+ @script_where
					+ REPLACE(@script_meldung1,	'##table_name##', @table_name)
--	  print	(@script)
	EXEC	(@script)

	SELECT	@script	= @script_insert_err
					+ @script_sel_fc
					+ ',''' + @timestamp + ''',	'''	+ @filename	+ ''''
					+ @script_from
					+ @table_name
					+ @script_where_err
					+ REPLACE(@script_meldung2,	'##table_name##', @table_name)
--	  print	(@script)
	EXEC	(@script)

	FETCH NEXT FROM	cur_fc INTO	@table_name, @timestamp, @filename
END

-- ermittle	und	übertrage FA-Ladedaten
DECLARE	cur_fa CURSOR FOR
SELECT [tabelle],	REPLACE([tabelle], 'BI_DELTA_FA',	'')	[timestamp], [tabelle] + '.txt'
FROM /*<DBNAME_PD_CALC>*/con_pd_calc/*<DBNAME_PD_CALC>*/.dbo.tt_pd_loaded
WHERE [tabelle] LIKE '%FA%'

OPEN cur_fa

FETCH NEXT FROM	cur_fa INTO	@table_name, @timestamp, @filename

WHILE @@FETCH_STATUS = 0
BEGIN
	SELECT	@script	= REPLACE(@script_insert, 'pd_fc', 'pd_fa')
					--+ 'SELECT [pd_dat_akt],	[pd_agent_nr], [pd_zeit_von], [pd_zeit_bis], [pd_anz_eingae], [pd_anz_in_bear],	'''
	
			    + ' SELECT CAST(0 AS SMALLDATETIME) AS [pd_dat_akt]'
				+ ' ,[pd_agent_nr]'
	            + ' ,CAST(0 AS SMALLDATETIME) AS [pd_zeit_von]'
	            + ' ,CAST(0 AS SMALLDATETIME) AS [pd_zeit_bis]'
	     	    + ' ,[pd_dat_eing]'
	            + ' ,[pd_asa_id]'
	            + ' ,[pd_tkd_id]'
      			+ ' ,[pd_rks_a_id]'
	            + ' ,0 AS [pd_anz_eingae]'
	            + ' ,0 AS [pd_anz_in_bear], '''
					+ @timestamp + ''',	'''	+ @filename	+ ''''
					+ @script_from
					+ @table_name
					+ '	WHERE ''' +	@timestamp + ''' NOT IN	(SELECT	bi_load_date FROM tf_deltant_pd_fa)	'
					+ @crlf
					+ REPLACE(@script_meldung1,	'##table_name##', @table_name)
--	  print	(@script)
	EXEC	(@script)

	FETCH NEXT FROM	cur_fa INTO	@table_name, @timestamp, @filename
END

-- ermittle	und	übertrage AZT-Ladedaten
DECLARE	cur_azt	CURSOR FOR
SELECT [tabelle],	REPLACE([tabelle], 'BI_DELTA_AZT', '') [timestamp], [tabelle] +	'.txt'
FROM /*<DBNAME_PD_CALC>*/con_pd_calc/*<DBNAME_PD_CALC>*/.dbo.tt_pd_loaded
WHERE [tabelle] LIKE '%AZT%'

OPEN cur_azt

FETCH NEXT FROM	cur_azt	INTO @table_name, @timestamp, @filename

WHILE @@FETCH_STATUS = 0
BEGIN
	SELECT	@script	= REPLACE(@script_insert, 'pd_fc', 'pd_azt')
					+ 'SELECT [pd_pkey], [pd_aufzaehl_Name], [pd_status], [pd_bez],	[pd_kurzbez], ''' 
					+ @timestamp + ''',	'''	+ @filename	+ ''''
					+ @script_from
					+ @table_name
					+ '	WHERE ''' +	@timestamp + ''' NOT IN	(SELECT	bi_load_date FROM tf_deltant_pd_azt) '
					+ @crlf
					+ REPLACE(@script_meldung1,	'##table_name##', @table_name)
--	  print	(@script)
	EXEC	(@script)

	FETCH NEXT FROM	cur_azt	INTO @table_name, @timestamp, @filename
END

-- reset @table_name
SELECT	@table_name = NULL

CLOSE cur_fc
DEALLOCATE cur_fc
CLOSE cur_fa
DEALLOCATE cur_fa
CLOSE cur_azt
DEALLOCATE cur_azt


---------------------------------------------------------------------
--Kappung dynamisch (max. 5 Jahre)
---------------------------------------------------------------------
DECLARE @create_fc_k VARCHAR(MAX), @create_fa_k VARCHAR(MAX), @create_azt_k VARCHAR(MAX)
DECLARE @PD_dat_ErsterMonat VARCHAR(8)

--Festlegung linker Rand:
SELECT @PD_dat_ErsterMonat = (SELECT CONVERT(VARCHAR(4),(LEFT(/*<Ablauf.Berichtsmonat>*/2016/*<Ablauf.Berichtsmonat>*/,4)-4))+'0101')


----------------------------------
--##FC-Daten
SELECT @create_fc_k = 
   '  SELECT 
		[pd_auftr_id]
      ,[pd_fehl_typ]
      ,[pd_fehler_txt]
      ,[pd_dnst_nr]
      ,[pd_tae_beauf]
      ,[pd_tae_durch]
      ,[pd_veranl_stl]
      ,[pd_rks_id]
      ,[pd_schul_abschl]
      ,[pd_geschlecht]
      ,[pd_leist_art_1]
      ,[pd_leist_art_2]
      ,[pd_beh_1]
      ,[pd_beh_2]
      ,[pd_beh_3]
      ,[pd_beh_4]
      ,[pd_anzahl_pt]
      ,[pd_eing_dat]
      ,[pd_abschl_dat]
      ,[pd_abschl_art]
      ,[pd_abschl_grund]
      ,[pd_gez]
      ,[pd_lz]
      ,[pd_create_dat]
      ,[pd_update_dat]
      ,[bps_bild_abs]
      ,[pd_lpe]
      ,[pd_lap]
      ,[pd_bkb_id]
      ,[pd_dgk_id]
      ,[pd_spr_id]
      ,[pd_trg_schl]
      ,[bi_load_date]
      ,[bi_load_filename]
      FROM [dbo].[tf_deltant_pd_fc]
      where pd_abschl_dat >= ''' + @PD_dat_ErsterMonat + ''''

EXEC dbo.up_ueb_object_CreateView /*<Strg.Audit_ID>*/NULL/*<Strg.Audit_ID>*/, 'tf_deltant_pd_fc_k', @create_fc_k

----------------------------------
--##AZT-Daten
SELECT @create_azt_k = 
   '  SELECT *
      FROM [dbo].[tf_deltant_pd_azt]
      where bi_load_date >= ''' + @PD_dat_ErsterMonat + ''''

EXEC dbo.up_ueb_object_CreateView /*<Strg.Audit_ID>*/NULL/*<Strg.Audit_ID>*/, 'tf_deltant_pd_azt_k', @create_azt_k

----------------------------------
--##FA-Daten
SELECT @create_fa_k = 
   '  SELECT *
      FROM [dbo].[tf_deltant_pd_fa]
      where bi_load_date >= ''' + @PD_dat_ErsterMonat + ''''

EXEC dbo.up_ueb_object_CreateView /*<Strg.Audit_ID>*/NULL/*<Strg.Audit_ID>*/, 'tf_deltant_pd_fa_k', @create_fa_k

