--<doku>
--=====================================================================================================================
--
--	Berechnung der Kennzahl 702 Gesamtlaufzeiten f d Auftragsbearb durch den PD
--
--  	Erzeugte Tabellen:	

--				tf_pd_knz_702
--
--=====================================================================================================================
--</doku>
--<doku_rfc>
--=====================================================================================================================
--
-- DATUM			ENTWICKLER
-- ----------  --------------------    -----------------------------------------------------------------------
--	17.06.2010	Stefan Junghans, SIS	Initiale Version
--	20.09.2011	Stefan Junghans, AIS	Migration auf SQL Srv 2008
--	27.03.2012	ReussM					Nacharbeiten MIG2008 (Prozedur zur Kennzahlviewerstellung eingebaut)	
--	14.09.2012	Stefan Junghans, AIS	AFM047655 NEO Welle 2
--	04.12.2012	Stefan Junghans, AIS	AFM047669 NEO Welle 3 (Ausbau org_id_alt)
--	08.11.2013	Stefan Junghans, AIS	AFM058759 BI_BER_Anpassungen an den Dimensionen „Stelle“, „Rechtskreis Auftraggeber“ und „Beschäftigungsstand“ im BPS-Cockpit  im Zuge von Veränderungen bei DELTA.NT und VerBIS   - SBT 
--										Umbenennung einiger Dimensionsviews; Faktenberechnung auf Aufbereitungszeitraum beschraenkt
--	11.11.2013	Stefan Junghans, AIS	AFM058714 BI_KNZ_Umstellung der Falllaufzeiten im BPS-Cockpit von Kalendertagen auf Arbeitstage - SBT
--										Sonderfall BM 201312: die 201312er Daten werden mit den 201311er ueberschrieben
--	19.11.2014	Stefan Junghans, AIS	AFM068953 BI_BER_68792_Weiterentwicklung BPS-Fachcontrolling Teil 2 - Anpassung der Laufzeitendarstellung - Bruttolaufzeiten
--										Vorgehen zur Strukturaenderung 201412 mit Archivierung 
--										- BM 201412: die Vormonatsfaktentabelle wird aus der Vormonats-Fact-DB geholt
--										- BM 201412: trotz Strukturaenderung in der Lieferung, bleibt die Faktentabelle strukturell unveraendert
--										- BM 201412: keine Aufbereitung der 201412 gelieferten Daten, sondern Replikation der 201411er Daten als 201412er
--										- BM 201412: im Anschluss an die KNZ-Berechnung wird die Faktentabelle in ihrer "Alt"-Struktur archiviert (siehe BPS Archiv.Management.sql)
--										- BM 201412: Aufbereitungszeitraum wird auf Beginn := 201501 angepasst, aber noch nicht verwendet, stattdessen fix im Quellcode Beginn := 201401
--										- BM 201501: KNZ-Berechnung erfolgt auf neuer Struktur
--										- BM 201501: Aufbereitungszeitraumbeginn := 201501 wird wirksam
-- 26.02.2015  ReussM			Hotfix, Schema MSTR-Projekt muss noch angepasst werden
-- 16.10.2017  ReussM			[AFM86313 - BPS-Cockpit: Ausweisung von gesonderten Laufzeiten für Aufträge mit Stelle "Reha-Beratung Wiedereingliederung"]
--								- Einbau Laufzeitauswertung von Fällen innerhalb/außerhalb 10 Arbeitstagen
--27.02.2019	ReussM			[AFM90745_Entfernung der Variable 'Kundentyp'] + [AFM90448_Implementierung einer neuen Variable 'Dringlichkeit']
--								Enterfernung der kdt_id und Einbau dgk_id zu BM201903 (P91)
--=====================================================================================================================
--</doku_rfc>

USE /*<DBNAME_PD_FACT>*/con_pd_fact/*<DBNAME_PD_FACT>*/
GO

DECLARE		@Audit_ID	INT,
			@von_mon_id	INT,			--	Erster  Berichtsmonat
			@bis_mon_id	INT	;			--	Letzter Berichtsmonat
			
SELECT		@Audit_ID	= /*<Strg.Audit_ID>*/NULL/*<Strg.Audit_ID>*/,
			@von_mon_id	= ErsterMonat,
			@bis_mon_id	= LetzterMonat

FROM		dbo.uf_ueb_kalender_Kennzahl( '702' )	;


-- Fakten schreiben
------------------------------------------------------------------------------------------------------------------------
EXEC	dbo.up_ueb_object_droptable	@Audit_ID, 'tf_pd_knz_702'
------------------------------------------------------------------------------------------------------------------------

SELECT 
	1 AS Anzahl,
	fc.org_id, 
	fc.pd_tae_durch, 
	fc.pd_veranl_stl, 
	fc.pd_rks_id, 
	ISNULL(fc.pd_leist_art_1, 0) AS pd_leist_art_1, 
	CAST(LEFT(CONVERT ( VARCHAR(8), fc.[pd_abschl_dat], 112), 6) AS INT) [mon_id],
	fc.pd_lz,
	fc.pd_dgk_id,
	CASE WHEN fc.pd_lz BETWEEN 31 AND 50 THEN 1 ELSE 0 END AS btw_31_to_50_days, 
	CASE WHEN fc.pd_lz > 50 THEN 1 ELSE 0 END AS bg_50_days,
	CASE WHEN fc.pd_lz BETWEEN 0 AND 10 THEN 1 ELSE 0 END AS sm_11_days, -- 0-10  Arbeitstage
	CASE WHEN fc.pd_lz > 10 THEN 1 ELSE 0 END AS bg_10_days,             -- 10+   Arbeitstage
	--Hotfix MR 26.02.2015, Schema MSTR-Projekt muss noch angepasst werden
	0 AS GLZ_NETTO_in_Wochen, 
	0 AS sm_10_days, 
	--0 AS bg_10_days, --Reaktivierung mit AFM86313
	0 AS sm_15_days, 
	0 AS bg_15_days, 
	0 AS sm_20_days, 
	0 AS bg_20_days, 
	0 AS sm_25_days, 
	0 AS bg_25_days, 
	0 AS sm_30_days, 
	0 AS bg_30_days, 
	0 AS sm_35_days, 
	0 AS bg_35_days, 
	0 AS sm_40_days, 
	0 AS bg_40_days, 
	0 AS sm_45_days, 
	0 AS bg_45_days, 
	0 AS sm_50_days, 
	0 AS pd_traeger_id
	--CASE WHEN fc.pd_lz >  50 THEN 1 ELSE 0 END bg_50_days 
INTO tf_pd_knz_702
FROM tf_pd_fc fc
WHERE fc.pd_abschl_art = 10010
	AND fc.pd_fehl_typ = 0
	AND CAST(LEFT(CONVERT ( VARCHAR(8), fc.[pd_abschl_dat], 112), 6) AS INT) BETWEEN @von_mon_id AND @bis_mon_id
	
------------------------------------------------------------------------------------------------------------------------
EXEC    dbo.up_ueb_log_CreateTable  @Audit_ID, 'tf_pd_knz_702', @@ROWCOUNT
------------------------------------------------------------------------------------------------------------------------
	
UPDATE tf_pd_knz_702
	SET pd_tae_durch = 9999
	WHERE pd_tae_durch NOT IN (SELECT tkd_id FROM /*<DBNAME_PD_KNZ>*/con_pd_knz/*<DBNAME_PD_KNZ>*/.[dbo].vd_pd_taetigkeit_durchgefuehrt)
		OR pd_tae_durch IS NULL
	
UPDATE tf_pd_knz_702
	SET pd_veranl_stl = 99999
	WHERE pd_veranl_stl NOT IN (SELECT ste_id FROM /*<DBNAME_PD_KNZ>*/con_pd_knz/*<DBNAME_PD_KNZ>*/.dbo.vd_bps_stelle)
		OR pd_veranl_stl IS NULL
	
UPDATE tf_pd_knz_702
	SET pd_rks_id = 99999
	WHERE pd_rks_id NOT IN (SELECT rks_a_id FROM /*<DBNAME_PD_KNZ>*/con_pd_knz/*<DBNAME_PD_KNZ>*/.dbo.vd_bps_rechtskreis_auftraggeber)
		OR pd_rks_id IS NULL
	
UPDATE tf_pd_knz_702
	SET pd_leist_art_1 = 99999
	WHERE pd_leist_art_1 NOT IN (SELECT lst_id FROM /*<DBNAME_PD_KNZ>*/con_pd_knz/*<DBNAME_PD_KNZ>*/.dbo.vd_pd_leistung)

UPDATE tf_pd_knz_702
	SET pd_dgk_id = 9999
	WHERE pd_dgk_id NOT IN (SELECT dgk_id FROM /*<DBNAME_PD_KNZ>*/con_pd_knz/*<DBNAME_PD_KNZ>*/.dbo.vd_as_bps_Dringlichkeit)
-------------------------------------------------------------------------------------------------------------------------------------------
--	Aufruf der Querschnittsfunktion für Erstellung Partitionierung, Indizierung, Faktenviews

EXEC		/*<DBNAME_CON_STRG>*/x/*<DBNAME_CON_STRG>*/.dbo.usp_pd_knz_erstellt	
				@Audit_ID, 'tf_pd_knz_702', 'mon_id';

