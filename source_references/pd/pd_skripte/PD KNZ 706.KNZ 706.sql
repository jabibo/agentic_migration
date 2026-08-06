--<doku>
--=====================================================================================================================
--
--	Berechnung der Kennzahl 706 Bearbeitet und unbearbeitet abgeschl Aufträge
--
--  	Erzeugte Tabellen:	

--				tf_pd_knz_706
--
--=====================================================================================================================
--</doku>
--<doku_rfc>
--=====================================================================================================================
--
--	DATUM				ENTWICKLER
--      ----------      --------------------    -----------------------------------------------------------------------
--	23.06.2010	Stefan Junghans, SIS	Initiale Version
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

FROM		dbo.uf_ueb_kalender_Kennzahl( '706' )	;


-- Fakten schreiben
------------------------------------------------------------------------------------------------------------------------
EXEC    dbo.up_ueb_object_droptable  @Audit_ID, 'tf_pd_knz_706'
------------------------------------------------------------------------------------------------------------------------

SELECT 1 AS Anzahl
	, fc.org_id
	, fc.pd_tae_beauf
	, fc.pd_veranl_stl 
	, CAST(LEFT(CONVERT ( VARCHAR(8), fc.[pd_abschl_dat], 112), 6) AS INT) [mon_id]
	, fc.pd_abschl_art
	, fc.pd_abschl_grund
INTO tf_pd_knz_706
FROM tf_pd_fc fc
WHERE fc.pd_fehl_typ = 0
	AND CAST(LEFT(CONVERT ( VARCHAR(8), fc.[pd_abschl_dat], 112), 6) AS INT) BETWEEN @von_mon_id AND @bis_mon_id

------------------------------------------------------------------------------------------------------------------------
EXEC    dbo.up_ueb_log_CreateTable  @Audit_ID, 'tf_pd_knz_706', @@ROWCOUNT
------------------------------------------------------------------------------------------------------------------------

UPDATE tf_pd_knz_706
	SET pd_tae_beauf = 9999
	WHERE pd_tae_beauf NOT IN (SELECT tkb_id FROM /*<DBNAME_PD_KNZ>*/con_pd_knz/*<DBNAME_PD_KNZ>*/.[dbo].vd_pd_taetigkeit_beauftragt)
		OR pd_tae_beauf IS NULL

UPDATE tf_pd_knz_706
	SET pd_veranl_stl = 99999
	WHERE pd_veranl_stl NOT IN (SELECT ste_id FROM /*<DBNAME_PD_KNZ>*/con_pd_knz/*<DBNAME_PD_KNZ>*/.dbo.vd_bps_stelle)
		OR pd_veranl_stl IS NULL

UPDATE tf_pd_knz_706
	SET pd_abschl_art = 99999
	WHERE pd_abschl_art NOT IN (SELECT asa_id FROM /*<DBNAME_PD_KNZ>*/con_pd_knz/*<DBNAME_PD_KNZ>*/.dbo.vd_pd_abschlussart)
		OR pd_abschl_art IS NULL
		
UPDATE tf_pd_knz_706
	SET pd_abschl_grund = 0
	WHERE pd_abschl_grund NOT IN (SELECT asg_id FROM /*<DBNAME_PD_KNZ>*/con_pd_knz/*<DBNAME_PD_KNZ>*/.dbo.vd_bps_Abschlussgrund)
		OR pd_abschl_grund IS NULL


------------------------------------------------------------------------------------------------------------------------
--	EXEC	dbo.up_ueb_kalender_FaktenViews_Kennzahl	@Audit_ID, 'tf_pd_knz_706', 706
-- zum korrekten Anlagen der AS2000-Views muss derweilen eine etwas andere Vorgehensweise erfolgen, da die Objektnamen doch zu unterschiedlich sind
--EXEC	dbo.up_ueb_kalender_FaktenViews_Kennzahl_Felder @Audit_ID, 'tf_pd_knz_706', 706, '*', NULL, 'knz_pd_706'

-------------------------------------------------------------------------------------------------------------------------------------------
--	Aufruf der Querschnittsfunktion für Erstellung Partitionierung, Indizierung, Faktenviews

EXEC		/*<DBNAME_CON_STRG>*/x/*<DBNAME_CON_STRG>*/.dbo.usp_pd_knz_erstellt	
				@Audit_ID, 'tf_pd_knz_706', 'mon_id';