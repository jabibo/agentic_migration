--<doku>
--=====================================================================================================================
--
--	Berechnung der Kennzahl 708 Durchgef Aktivitäten und Verw computergest Tests
--
--  	Erzeugte Tabellen:	

--				tf_pd_knz_708
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
--	13.11.2013	Stefan Junghans, AIS	AFM058759 Faktenberechnung auf Aufbereitungszeitraum beschraenkt
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

FROM		dbo.uf_ueb_kalender_Kennzahl( '708' )	;


-- Fakten schreiben
------------------------------------------------------------------------------------------------------------------------
EXEC    dbo.up_ueb_object_droptable  @Audit_ID, 'tf_pd_knz_708'
------------------------------------------------------------------------------------------------------------------------

SELECT 1 AS Anzahl 
	, fc.org_id 
	, fc.pd_tae_durch
	, CAST(LEFT(CONVERT ( VARCHAR(8), fc.[pd_abschl_dat], 112), 6) AS INT) [mon_id]
INTO tf_pd_knz_708
FROM tf_pd_fc fc
WHERE fc.pd_abschl_art = 10010
	AND fc.pd_veranl_stl <> 23006
	AND fc.pd_tae_durch <> 2001
	AND fc.pd_fehl_typ = 0
	AND CAST(LEFT(CONVERT ( VARCHAR(8), fc.[pd_abschl_dat], 112), 6) AS INT) BETWEEN @von_mon_id AND @bis_mon_id

------------------------------------------------------------------------------------------------------------------------
EXEC    dbo.up_ueb_log_CreateTable  @Audit_ID, 'tf_pd_knz_708', @@ROWCOUNT
------------------------------------------------------------------------------------------------------------------------

UPDATE tf_pd_knz_708
	SET pd_tae_durch = 9999
	WHERE pd_tae_durch NOT IN (SELECT tkd_id FROM /*<DBNAME_PD_KNZ>*/con_pd_knz/*<DBNAME_PD_KNZ>*/.[dbo].vd_pd_taetigkeit_durchgefuehrt)
		OR pd_tae_durch IS NULL

------------------------------------------------------------------------------------------------------------------------
--	EXEC	dbo.up_ueb_kalender_FaktenViews_Kennzahl	@Audit_ID, 'tf_pd_knz_708', 708
-- zum korrekten Anlagen der AS2000-Views muss derweilen eine etwas andere Vorgehensweise erfolgen, da die Objektnamen doch zu unterschiedlich sind
--EXEC	dbo.up_ueb_kalender_FaktenViews_Kennzahl_Felder @Audit_ID, 'tf_pd_knz_708', 708, '*', NULL, 'knz_pd_708'

-------------------------------------------------------------------------------------------------------------------------------------------
--	Aufruf der Querschnittsfunktion für Erstellung Partitionierung, Indizierung, Faktenviews

EXEC		/*<DBNAME_CON_STRG>*/x/*<DBNAME_CON_STRG>*/.dbo.usp_pd_knz_erstellt
				@Audit_ID, 'tf_pd_knz_708', 'mon_id';