----<doku>
----=====================================================================================================================
----
----	Berechnung der Kennzahl 721 MYSKILLS
----
----  	Erzeugte Tabellen:	
----		tf_ms_knz_721
----
----=====================================================================================================================
----</doku>
----<doku_rfc>
----=====================================================================================================================
----
----	DATUM				ENTWICKLER
----  ----------      --------------------    -----------------------------------------------------------------------
----	04.062019		ReussM					Initiale Version
----=====================================================================================================================
----</doku_rfc>

--USE /*<DBNAME_PD_FACT>*/con_pd_fact/*<DBNAME_PD_FACT>*/
--GO

--DECLARE     @Audit_ID       INT,
--            @von_mon_id	INT,			--	Erster  Berichtsmonat
--			@bis_mon_id	INT	;			--	Letzter Berichtsmonat
			
--SELECT      @Audit_ID       = /*<Strg.Audit_ID>*/NULL/*<Strg.Audit_ID>*/,
--            @von_mon_id	= ErsterMonat,
--			@bis_mon_id	= LetzterMonat

--FROM		dbo.uf_ueb_kalender_Kennzahl( '721' );


---- Fakten schreiben
--------------------------------------------------------------------------------------------------------------------------
--EXEC    dbo.up_ueb_object_droptable  @Audit_ID, 'tf_ms_knz_721'
--------------------------------------------------------------------------------------------------------------------------

--SELECT 
--	CAST(LEFT(CONVERT ( VARCHAR(8), fc.[pd_abschl_dat], 112), 6) AS INT) AS mon_id,
--	fc.gst_id, 
--	fc.pd_rks_id		AS rks_a_id, 
--	fc.pd_tae_durch		AS tkd_id,
--	fc.pd_spr_id		AS spr_id,
--	1 AS Anzahl_gesamt,
--	CASE WHEN 
--		ms_beauf.tkb_id IS NOT NULL AND ms_durchgef.tkd_id IS NOT NULL THEN 1 	ELSE 0	--beauftragt und durchgeführt
--		END 
--	AS Anzahl_abgeschlossen,
--	CASE WHEN 
--		ms_beauf.tkb_id IS NOT NULL AND ms_durchgef.tkd_id IS NULL THEN 1 	ELSE 0		--beauftragt aber nicht durchgeführt
--		END 
--	AS Anzahl_abgebrochen

--INTO tf_ms_knz_721

--FROM tf_pd_fc fc

--INNER JOIN /*<DBNAME_PD_KNZ>*/con_pd_knz/*<DBNAME_PD_KNZ>*/.[dbo].vd_as_pd_Taetigkeitbeauftragt		ms_beauf
--	ON fc.pd_tae_beauf = ms_beauf.tkb_id
--	AND ms_beauf.tkb_id = 2012			--Filter nur auf MYSKILLS-Berufe

--LEFT JOIN /*<DBNAME_PD_KNZ>*/con_pd_knz/*<DBNAME_PD_KNZ>*/.[dbo].vd_as_pd_Taetigkeitdurchgefuehrt	ms_durchgef
--	ON fc.pd_tae_durch = ms_durchgef.tkd_id
--	AND ms_durchgef.tkd_id = 2012			--Filter nur auf MYSKILLS-Berufe

--WHERE CAST(LEFT(CONVERT ( VARCHAR(8), fc.[pd_abschl_dat], 112), 6) AS INT) BETWEEN @von_mon_id AND @bis_mon_id
--	--AND fc.pd_abschl_art = 10010		--Bearbeitungsstand bearbeitet abgeschlossen	--deaktiviert, so Unterscheidung von beauftragt unf durchgeführt möglich


--------------------------------------------------------------------------------------------------------------------------
--EXEC    dbo.up_ueb_log_CreateTable  @Audit_ID, 'tf_ms_knz_721', @@ROWCOUNT
--------------------------------------------------------------------------------------------------------------------------

--UPDATE tf_ms_knz_721
--	SET rks_a_id = 99999
--	WHERE rks_a_id NOT IN (SELECT rks_a_id FROM /*<DBNAME_PD_KNZ>*/con_pd_knz/*<DBNAME_PD_KNZ>*/.dbo.vd_bps_rechtskreis_auftraggeber)
--		OR rks_a_id IS NULL

--UPDATE tf_ms_knz_721
--	SET spr_id = 9999
--	WHERE spr_id NOT IN (SELECT spr_id FROM /*<DBNAME_PD_KNZ>*/con_pd_knz/*<DBNAME_PD_KNZ>*/.dbo.vd_as_bps_Sprache)
--		OR spr_id IS NULL

--UPDATE tf_ms_knz_721
--	SET tkd_id = 2020
--	WHERE --tkd_id NOT IN (SELECT tkd_id FROM /*<DBNAME_PD_KNZ>*/con_pd_knz/*<DBNAME_PD_KNZ>*/.dbo.vd_as_bps_berufe_MySkills)
--		--OR 
--		tkd_id IS NULL


---------------------------------------------------------------------------------------------------------------------------------------------
----	Aufruf der Querschnittsfunktion für Erstellung Partitionierung, Indizierung, Faktenviews

--EXEC		/*<DBNAME_CON_STRG>*/con_strg/*<DBNAME_CON_STRG>*/.dbo.usp_ms_knz_erstellt	
--				@Audit_ID, 'tf_ms_knz_721', 'mon_id';
