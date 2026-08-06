--<doku>
--=====================================================================================================================
--
--	Berechnung der Kennzahl 705 Anzahl der durchgef Psychologischen Tätigkeiten
--
--  	Erzeugte Tabellen:	

--				tf_pd_knz_705
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
--	08.11.2013	Stefan Junghans, AIS	AFM058759 BI_BER_Anpassungen an den Dimensionen „Stelle“, „Rechtskreis Auftraggeber“ und „Beschäftigungsstand“ im BPS-Cockpit  im Zuge von Veränderungen bei DELTA.NT und VerBIS   - SBT 
--										Umbenennung einiger Dimensionsviews; Faktenberechnung auf Aufbereitungszeitraum beschraenkt
-- 
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

FROM		dbo.uf_ueb_kalender_Kennzahl( '705' )	;


-- Fakten schreiben
------------------------------------------------------------------------------------------------------------------------
EXEC    dbo.up_ueb_object_droptable  @Audit_ID, 'tf_pd_knz_705'
------------------------------------------------------------------------------------------------------------------------

SELECT 1 AS Anzahl
	, fc.org_id
	, fc.pd_tae_durch
	, fc.pd_rks_id
	, CASE	WHEN ISNULL(fc.[pd_anzahl_pt], 0) < 4 THEN ISNULL(fc.[pd_anzahl_pt], 0)
		ELSE 4
		END [pd_anzahl_pt_id]
	, CAST(LEFT(CONVERT ( VARCHAR(8), fc.[pd_abschl_dat], 112), 6) AS INT) [mon_id]
INTO tf_pd_knz_705
FROM tf_pd_fc fc
WHERE fc.pd_abschl_art = 10010
	AND fc.pd_veranl_stl <> 23006
	AND fc.pd_tae_durch IN (2003, 2006)
	AND fc.pd_fehl_typ = 0
	AND CAST(LEFT(CONVERT ( VARCHAR(8), fc.[pd_abschl_dat], 112), 6) AS INT) BETWEEN @von_mon_id AND @bis_mon_id

------------------------------------------------------------------------------------------------------------------------
EXEC    dbo.up_ueb_log_CreateTable  @Audit_ID, 'tf_pd_knz_705', @@ROWCOUNT
------------------------------------------------------------------------------------------------------------------------

UPDATE tf_pd_knz_705
	SET pd_tae_durch = 9999
	WHERE pd_tae_durch NOT IN (SELECT tkd_id FROM /*<DBNAME_PD_KNZ>*/con_pd_knz/*<DBNAME_PD_KNZ>*/.[dbo].vd_pd_taetigkeit_durchgefuehrt)
		OR pd_tae_durch IS NULL

UPDATE tf_pd_knz_705
	SET pd_rks_id = 99999
	WHERE pd_rks_id NOT IN (SELECT rks_a_id FROM /*<DBNAME_PD_KNZ>*/con_pd_knz/*<DBNAME_PD_KNZ>*/.dbo.vd_bps_rechtskreis_auftraggeber)
		OR pd_rks_id IS NULL

------------------------------------------------------------------------------------------------------------------------
--	EXEC	dbo.up_ueb_kalender_FaktenViews_Kennzahl	@Audit_ID, 'tf_pd_knz_705', 705
-- zum korrekten Anlagen der AS2000-Views muss derweilen eine etwas andere Vorgehensweise erfolgen, da die Objektnamen doch zu unterschiedlich sind
--EXEC	dbo.up_ueb_kalender_FaktenViews_Kennzahl_Felder @Audit_ID, 'tf_pd_knz_705', 705, '*', NULL, 'knz_pd_705'

--	Aufruf der Querschnittsfunktion für Erstellung Partitionierung, Indizierung, Faktenviews

EXEC		/*<DBNAME_CON_STRG>*/x/*<DBNAME_CON_STRG>*/.dbo.usp_pd_knz_erstellt	
				@Audit_ID, 'tf_pd_knz_705', 'mon_id';
