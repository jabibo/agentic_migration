--<doku>
--=====================================================================================================================
--
--	Berechnung der Kennzahl 703 Vormerkzeiten und Gutachtenerstellungszeiten
--
--  	Erzeugte Tabellen:	

--				tf_pd_knz_703
--
--=====================================================================================================================
--</doku>
--<doku_rfc>
--=====================================================================================================================
--
--	DATUM				ENTWICKLER
--      ----------      --------------------    -----------------------------------------------------------------------
--	22.06.2010	Stefan Junghans, SIS	Initiale Version
--	20.09.2011	Stefan Junghans, AIS	Migration auf SQL Srv 2008
--	27.03.2012	ReussM					Nacharbeiten MIG2008 (Prozedur zur Kennzahlviewerstellung eingebaut)	
--	14.09.2012	Stefan Junghans, AIS	AFM047655 NEO Welle 2
--	04.12.2012	Stefan Junghans, AIS	AFM047669 NEO Welle 3 (Ausbau org_id_alt)
--	11.11.2013	Stefan Junghans, AIS	AFM058714 BI_KNZ_Umstellung der Falllaufzeiten im BPS-Cockpit von Kalendertagen auf Arbeitstage - SBT
--										- Sonderfall BM 201312: die 201312er Daten werden mit den 201311er ueberschrieben; 
--										- Faktenberechnung auf Aufbereitungszeitraum beschraenkt
--	20.11.2014	Stefan Junghans, AIS	AFM068953 BI_BER_68792_Weiterentwicklung BPS-Fachcontrolling Teil 2 - Anpassung der Laufzeitendarstellung - Bruttolaufzeiten
--										Vorgehen zur Strukturaenderung 201412 mit Archivierung 
--										- BM 201412: die Vormonatsfaktentabelle wird aus der Vormonats-Fact-DB geholt
--										- BM 201412: trotz Strukturaenderung in der Lieferung, bleibt die Faktentabelle strukturell unveraendert
--										- BM 201412: keine Aufbereitung der 201412 gelieferten Daten, sondern Replikation der 201411er Daten als 201412er
--										- BM 201412: im Anschluss an die KNZ-Berechnung findet allerdings KEINE Archivierung statt
--										- BM 201412: Aufbereitungszeitraum wird auf Beginn := 201501 angepasst, aber noch nicht verwendet, stattdessen fix im Quellcode Beginn := 201401
--										- BM 201501: KNZ-Berechnung erfolgt auf neuer Struktur
--										- BM 201501: Rueckbau [pd_vmz_bereinigt]
--										- BM 201501: Aufbereitungszeitraumbeginn := 201501 wird wirksam
-- 26.02.2015  ReussM         Hotfix, Schema MSTR-Projekt muss noch angepasst werden
-- 26.11.2015  ReussM         [AFM000000076103 - BI-Controlling-Kennzahlen - < BPS-Cockpit_KNZ_76097_QM-Kennzahlen >]
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

FROM		dbo.uf_ueb_kalender_Kennzahl( '703' )	;


-- Fakten schreiben
------------------------------------------------------------------------------------------------------------------------
EXEC    dbo.up_ueb_object_droptable  @Audit_ID, 'tf_pd_knz_703'
------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------
-- Sonderbehandlung im Rahmen AFM068953:
-- BM 201412: Vormonatsfaktentabelle wird aus der Vormonats-Fact-DB geholt
------------------------------------------------------------------------------------------------------------------------

IF /*<Ablauf.Berichtsmonat>*/0/*<Ablauf.Berichtsmonat>*/ = 201412 
BEGIN
	
	DECLARE @am_fact	NVARCHAR(128), 
			@vm_fact	NVARCHAR(128), 
			@crlf		NCHAR(2) = NCHAR(13) + NCHAR(10),
			@script		NVARCHAR(MAX), 
			@paramdef	NVARCHAR(500), 
			@rowcount	INT

	SELECT	@am_fact = 	dbo.uf_ueb_param_Get(@audit_id, 'DBNAME_PD_FACT')
	SELECT	@vm_fact = 	REPLACE(@am_fact, '201412', '201411')

	SELECT	@script =  N'SELECT	* ' + @crlf 
					+  N'INTO	' + @am_fact + N'.dbo.tf_pd_knz_703 ' + @crlf 
					+  N'FROM	' + @vm_fact + N'.dbo.tf_pd_knz_703 ' + @crlf
					+  N'SELECT	@rc	= @@ROWCOUNT', 
			@paramdef = N'@rc INT OUTPUT'

	EXEC	sp_executesql @script, @paramdef, @rc = @rowcount OUTPUT

	------------------------------------------------------------------------------------------------------------------------
	EXEC    dbo.up_ueb_log_CreateTable  @Audit_ID, 'tf_pd_knz_703', @rowcount
	------------------------------------------------------------------------------------------------------------------------
	EXEC	dbo.up_ueb_log_meldung	@audit_id = @Audit_ID, 
									@Meldung = 'Faktentabelle aus Vormonat abgeholt', 
									@wert_Int = @rowcount, 
									@wert_Text = 'tf_pd_knz_703'
	------------------------------------------------------------------------------------------------------------------------
	
	--  Im BM 201412 werden die Daten zu mon_id 201412 entfernt und durch duplizierte Daten zu mon_id 201411 ersetzt.
	SELECT	@script = N'' + @crlf
					+ N'INSERT INTO tf_pd_knz_703' + @crlf
					+ N'SELECT 	org_id, ' + @crlf
					+ N'		201412,' + @crlf
					+ N'		Anzahl, ' + @crlf
					+ N'		pd_gez, ' + @crlf
					+ N'		pd_vmz_bereinigt' + @crlf
					+ N'FROM	tf_pd_knz_703' + @crlf
					+ N'WHERE mon_id = 201411' + @crlf
					+ N'SELECT	@rc = @@ROWCOUNT'

	EXEC	sp_executesql @script, @paramdef, @rc = @rowcount OUTPUT

	EXEC	dbo.up_ueb_log_meldung	@audit_id = @Audit_ID, 
									@Meldung = 'Novemberdaten als Dezemberdaten eingespielt', 
									@wert_Int = @rowcount, 
									@wert_Text = 'tf_pd_knz_703'

	-------------------------------------------------------------------------------------------------------------------------------------------
	--	Aufruf der Querschnittsfunktion für Erstellung Partitionierung, Indizierung, Faktenviews

	--	Aufbereitungsbeginn fuer Sonderbehandlung fest auf 201401 eingestellt
	EXEC		/*<DBNAME_CON_STRG>*/x/*<DBNAME_CON_STRG>*/.dbo.usp_pd_knz_erstellt	
					@Audit_ID, 'tf_pd_knz_703', 'mon_id';

END
ELSE	-- /*<Ablauf.Berichtsmonat>*/0/*<Ablauf.Berichtsmonat>*/ = 201412 
BEGIN

	-------------------------------------------------------------------
	EXEC    dbo.up_ueb_object_droptable  @Audit_ID, 'tt_pd_knz_703_all'
	-------------------------------------------------------------------
	SELECT 
		fc.org_id
		, CAST(LEFT(CONVERT ( VARCHAR(8), fc.[pd_abschl_dat], 112), 6) AS INT) [mon_id]
		, pd_tae_durch --76097_QM-Kennzahlen
		, 1 AS Anzahl
		, fc.[pd_gez]
		, CASE
            WHEN ISNULL(pd_gez, 99999) BETWEEN 0 AND 1 THEN 1
            WHEN ISNULL(pd_gez, 99999) BETWEEN 2 AND 3 THEN 2
            WHEN ISNULL(pd_gez, 99999) BETWEEN 4 AND 5 THEN 3
            ELSE 5
        END AS gez_id_lz
		, fc.[pd_lpe]
		, CASE
            WHEN ISNULL(pd_lpe, 99999) BETWEEN 0 AND 1 THEN 1
            WHEN ISNULL(pd_lpe, 99999) BETWEEN 2 AND 3 THEN 2
            WHEN ISNULL(pd_lpe, 99999) BETWEEN 4 AND 5 THEN 3
            ELSE 5
        END AS lpe_id_lz		
		, fc.[pd_lap]
		, CASE
            WHEN ISNULL(pd_lap, 99999) BETWEEN 0 AND 1 THEN 1
            WHEN ISNULL(pd_lap, 99999) BETWEEN 2 AND 3 THEN 2
            WHEN ISNULL(pd_lap, 99999) BETWEEN 4 AND 5 THEN 3
            ELSE 5
        END AS lap_id_lz		
		
		--eigenes Laufzeitintervall zunächst deaktiviert (lpe, lap)
		--, CASE
            --WHEN ISNULL(pd_lpe, 0) BETWEEN 0 AND 1 THEN 1
            --WHEN ISNULL(pd_lpe, 0) = 2             THEN 2
            --ELSE 3 -- ">2"
         --END AS lpe_id_lz
		--, CASE
            --WHEN ISNULL(pd_lap, 0) BETWEEN 0 AND 1 THEN 1
            --WHEN ISNULL(pd_lap, 0) = 2             THEN 2
            --ELSE 3 -- ">2"
        --END AS lap_id_lz
	-- AFM068953: Rueckbau [pd_vmz_bereinigt]
	-- 26.02.2015  ReussM         Hotfix, Schema MSTR-Projekt muss noch angepasst werden ([pd_vmz_bereinigt] benötigt)
	,0 AS [pd_vmz_bereinigt]
	
	INTO tt_pd_knz_703_all
	
	FROM tf_pd_fc fc
	WHERE fc.pd_abschl_art = 10010 --bearbeitet abgeschlossen
		AND fc.pd_veranl_stl <> 23006
		AND fc.pd_fehl_typ = 0
		AND CAST(LEFT(CONVERT ( VARCHAR(8), fc.[pd_abschl_dat], 112), 6) AS INT) BETWEEN @von_mon_id AND @bis_mon_id
 
	------------------------------------------------------------------------------------------------------------------------
	EXEC    dbo.up_ueb_log_CreateTable  @Audit_ID, 'tt_pd_knz_703_all', @@ROWCOUNT
	------------------------------------------------------------------------------------------------------------------------
 
 
	------------------------------------------------------------------------------------------------------------------------
	EXEC    dbo.up_ueb_object_droptable  @Audit_ID, 'tf_pd_knz_703'
	------------------------------------------------------------------------------------------------------------------------
--gez-Daten
	SELECT 
		org_id
		,mon_id
		,pd_tae_durch
		,Anzahl
		,pd_gez
		,gez_id_lz --zentrale Laufzeit-ID (für alle 3)
		,NULL AS pd_lpe
		,99999 AS lpe_id_lz		
		,NULL AS pd_lap
		,99999 AS lap_id_lz		
		,[pd_vmz_bereinigt]
	INTO tf_pd_knz_703
	FROM tt_pd_knz_703_all
--lpe-Daten
	UNION ALL SELECT 
		org_id
		,mon_id
		,pd_tae_durch
		,0 AS Anzahl
		,NULL AS pd_gez
		,lpe_id_lz AS gez_id_lz --Darstellung in selber ID (möglich, da selbe Zeiträume)
		,pd_lpe
		,lpe_id_lz		
		,NULL AS pd_lap
		,99999 AS lap_id_lz		
		,[pd_vmz_bereinigt]
	FROM tt_pd_knz_703_all
	WHERE pd_lpe IS NOT NULL
--lap-daten	
	UNION ALL SELECT 
		org_id
		,mon_id
		,pd_tae_durch
		,0 As Anzahl
		,NULL AS pd_gez
		,lap_id_lz AS gez_id_lz --Darstellung in selber ID (möglich, da selbe Zeiträume)
		,NULL AS pd_lpe
		,99999 AS lpe_id_lz		
		,pd_lap
		,lap_id_lz		
		,[pd_vmz_bereinigt]
	FROM tt_pd_knz_703_all
	WHERE pd_lap IS NOT NULL

 
	------------------------------------------------------------------------------------------------------------------------
	EXEC    dbo.up_ueb_log_CreateTable  @Audit_ID, 'tf_pd_knz_703', @@ROWCOUNT
	------------------------------------------------------------------------------------------------------------------------

	-------------------------------------------------------------------------------------------------------------------------------------------
	--	Aufruf der Querschnittsfunktion für Erstellung Partitionierung, Indizierung, Faktenviews

	EXEC		/*<DBNAME_CON_STRG>*/x/*<DBNAME_CON_STRG>*/.dbo.usp_pd_knz_erstellt	
					@Audit_ID, 'tf_pd_knz_703', 'mon_id';

END		-- /*<Ablauf.Berichtsmonat>*/0/*<Ablauf.Berichtsmonat>*/ = 201412 
