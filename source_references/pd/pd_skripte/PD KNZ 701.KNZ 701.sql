--<doku>
--=====================================================================================================================
--
--	Berechnung der Kennzahl 701 Erbrachte Dienstleistungen des PD
--
--  	Erzeugte Tabellen:	

--				tf_pd_knz_701
--
--=====================================================================================================================
--</doku>
--<doku_rfc>
--=====================================================================================================================
--
--	DATUM				ENTWICKLER
--      ----------      --------------------    -----------------------------------------------------------------------
--	17.06.2010	Stefan Junghans, SIS	Initiale Version
--	20.09.2011	Stefan Junghans, AIS	Migration auf SQL Srv 2008
--	27.03.2012	ReussM					Nacharbeiten MIG2008 (Prozedur zur Kennzahlviewerstellung eingebaut)	
--	14.09.2012	Stefan Junghans, AIS	AFM047655 NEO Welle 2
--	04.12.2012	Stefan Junghans, AIS	AFM047669 NEO Welle 3 (Ausbau org_id_alt)
--	08.11.2013	Stefan Junghans, AIS	AFM058759 BI_BER_Anpassungen an den Dimensionen „Stelle“, „Rechtskreis Auftraggeber“ und „Beschäftigungsstand“ im BPS-Cockpit  im Zuge von Veränderungen bei DELTA.NT und VerBIS   - SBT 
--										Umbenennung einiger Dimensionsviews; Faktenberechnung auf Aufbereitungszeitraum beschraenkt
--	13.07.2017	ReussM					[AFM84892_BI-EC-@MySkills-BKE-Ergänzungen_zum_AFM-RfC_81919]
--										Anpassung zu Schnittstellenänderung mit P72 (2 neue Attribute bkeberuf, kundentyp)
--	27.02.2019	ReussM					[AFM90745_Entfernung der Variable 'Kundentyp']  ktd_id entfernt
-- 01.02.2024	ReussM					AFM109413_Aktualisierung_BPS-Cockpit_Berichte (Anzahl festgestellter Behinderungen ermitteln, als Vorbereitung für MSTR-Berechnungen)
--=====================================================================================================================
--</doku_rfc>

USE /*<DBNAME_PD_FACT>*/con_pd_fact/*<DBNAME_PD_FACT>*/
GO

DECLARE     @Audit_ID       INT,
            @von_mon_id	INT,			--	Erster  Berichtsmonat
			@bis_mon_id	INT	;			--	Letzter Berichtsmonat
			
SELECT      @Audit_ID       = /*<Strg.Audit_ID>*/NULL/*<Strg.Audit_ID>*/,
            @von_mon_id	= ErsterMonat,
			@bis_mon_id	= LetzterMonat

FROM		dbo.uf_ueb_kalender_Kennzahl( '701' )	;


-- Fakten schreiben
------------------------------------------------------------------------------------------------------------------------
EXEC    dbo.up_ueb_object_droptable  @Audit_ID, 'tt_knz701_beh'
------------------------------------------------------------------------------------------------------------------------
--Anzahl festgestellter Behinderungen ermitteln, fuer Ausweisung/Berechnung im Frontend
--ohne pd_beh_1 = 11040 "keine Behinderung"
  SELECT
	pd_auftr_id
	,CASE WHEN pd_beh_1 = 11040   THEN NULL ELSE  pd_beh_1 END AS pd_beh_1
	,CASE WHEN pd_beh_2 = 11040   THEN NULL ELSE  pd_beh_2 END AS pd_beh_2
	,CASE WHEN pd_beh_3 = 11040   THEN NULL ELSE  pd_beh_3 END AS pd_beh_3
	,CASE WHEN pd_beh_4 = 11040   THEN NULL ELSE  pd_beh_4 END AS pd_beh_4
  INTO	tt_knz701_beh
  FROM [tf_pd_fc]


------------------------------------------------------------------------------------------------------------------------
EXEC    dbo.up_ueb_log_CreateTable  @Audit_ID, 'tt_knz701_beh', @@ROWCOUNT
------------------------------------------------------------------------------------------------------------------------


------------------------------------------------------------------------------------------------------------------------
EXEC    dbo.up_ueb_object_droptable  @Audit_ID, 'tt_knz701_sum_beh'
------------------------------------------------------------------------------------------------------------------------
--Anzahl festgestellter Behinderungen ermitteln, fuer Ausweisung/Berechnung im Frontend

SELECT
	pd_auftr_id
	,COUNT([pd_beh_1])+COUNT([pd_beh_2])+COUNT([pd_beh_3])+COUNT([pd_beh_4]) as count_anz_beh
  
  INTO	tt_knz701_sum_beh

  FROM tt_knz701_beh
  GROUP BY pd_auftr_id

------------------------------------------------------------------------------------------------------------------------
EXEC    dbo.up_ueb_log_CreateTable  @Audit_ID, 'tt_knz701_sum_beh', @@ROWCOUNT
------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------
EXEC    dbo.up_ueb_object_droptable  @Audit_ID, 'tf_pd_knz_701'
------------------------------------------------------------------------------------------------------------------------

SELECT 
	1 AS Anzahl,
	fc.pd_auftr_id,
	fc.org_id, 
	fc.pd_tae_durch, 
	fc.pd_veranl_stl, 
	fc.pd_rks_id, 
	ISNULL(tt.count_anz_beh,0) AS anz_beh,
	--Beratung je nach Anzahl der Termine mit Faktor versehen (AFM109413_Aktualisierung_BPS-Cockpit_Berichte)
	--Beratung mit einem Termin - 9 Punkte 
	--Beratung mit 2 Terminen - 18 Punkte
	--Beratung mit 3 oder mehr Terminen - 27 Punkte
	CASE ISNULL(pd_anzahl_pt, 0)
		WHEN  0 THEN 0
		WHEN  1 THEN 9
		WHEN  2 THEN 18
		ELSE 27
	END AS pt_mit_faktor,
	99999 AS [pd_traeger_id],  --FIX, MSTR verweist noch auf das 2014 ausgebaute Attribut! (todo: Rückbau in MSTR dann Anpassung der Fakten)
	CAST(LEFT(CONVERT ( VARCHAR(8), fc.[pd_abschl_dat], 112), 6) AS INT) [mon_id]
INTO tf_pd_knz_701

FROM tf_pd_fc fc

LEFT JOIN tt_knz701_sum_beh tt
	ON fc.pd_auftr_id = tt.pd_auftr_id

WHERE fc.pd_abschl_art = 10010
	AND fc.pd_fehl_typ = 0
	AND CAST(LEFT(CONVERT ( VARCHAR(8), fc.[pd_abschl_dat], 112), 6) AS INT) BETWEEN @von_mon_id AND @bis_mon_id

------------------------------------------------------------------------------------------------------------------------
EXEC    dbo.up_ueb_log_CreateTable  @Audit_ID, 'tf_pd_knz_701', @@ROWCOUNT
------------------------------------------------------------------------------------------------------------------------

UPDATE tf_pd_knz_701
	SET pd_tae_durch = 9999
	WHERE pd_tae_durch NOT IN (SELECT tkd_id FROM /*<DBNAME_PD_KNZ>*/con_pd_knz/*<DBNAME_PD_KNZ>*/.[dbo].vd_pd_taetigkeit_durchgefuehrt)
		OR pd_tae_durch IS NULL

UPDATE tf_pd_knz_701
	SET pd_veranl_stl = 99999
	WHERE pd_veranl_stl NOT IN (SELECT ste_id FROM /*<DBNAME_PD_KNZ>*/con_pd_knz/*<DBNAME_PD_KNZ>*/.dbo.vd_bps_stelle)
		OR pd_veranl_stl IS NULL

UPDATE tf_pd_knz_701
	SET pd_rks_id = 99999
	WHERE pd_rks_id NOT IN (SELECT rks_a_id FROM /*<DBNAME_PD_KNZ>*/con_pd_knz/*<DBNAME_PD_KNZ>*/.dbo.vd_bps_rechtskreis_auftraggeber)
		OR pd_rks_id IS NULL

-------------------------------------------------------------------------------------------------------------------------------------------
--	Aufruf der Querschnittsfunktion für Erstellung Partitionierung, Indizierung, Faktenviews

EXEC		/*<DBNAME_CON_STRG>*/x/*<DBNAME_CON_STRG>*/.dbo.usp_pd_knz_erstellt	
				@Audit_ID, 'tf_pd_knz_701', 'mon_id';
