--<doku>
--=====================================================================================================================
--
--	Berechnung der Kennzahl 709 Kundenbezogene Auftragsdaten
--
--  	Erzeugte Tabellen:	
--				tf_pd_knz_709
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
--	26.02.2013	Reuß	M.				[C13647_Anpassung der "Schulabschlüsse" im Zuge von Änderungen bei Delta.NT]
--										neues Attribut "bps_bild_abs" (Dimension Bildungsabschluss) aufgenommen, DimView "vd_pd_schulabschluss" ersetzt durch "vd_bps_Bildungsniveau"
--	08.11.2013	Stefan Junghans, AIS	AFM058759 BI_BER_Anpassungen an den Dimensionen „Stelle“, „Rechtskreis Auftraggeber“ und „Beschäftigungsstand“ im BPS-Cockpit  im Zuge von Veränderungen bei DELTA.NT und VerBIS   - SBT 
--										Abschaltung Dimension "Beschäftigungsstand"; Faktenberechnung auf Aufbereitungszeitraum beschraenkt
-- 07.04.2016 ReussM			AFM80885-Erweiterung der Auswahlliste Geschlechts um das Merkmal kein Eintrag im Geburtenregister
-- 09.01.2024 ReusssM			AFM109413_Aktualisierung_BPS-Cockpit_Berichte
--								um 2 Attribute erweitern [Rechtskreis Auftraggeber (pd_rks_id) + Tätigkeit durchgeführt e1 (pd_tae_durch)]
--								Rückbau Geburtsdatum aus der Kennzahl (pd_geb_dat/pd_age_key ausgebaut)

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

FROM		dbo.uf_ueb_kalender_Kennzahl( '709' )	;


-- Fakten schreiben
------------------------------------------------------------------------------------------------------------------------
EXEC    dbo.up_ueb_object_droptable  @Audit_ID, 'tf_pd_knz_709'
EXEC    /*<DBNAME_PD_CALC>*/con_pd_calc/*<DBNAME_PD_CALC>*/.dbo.up_ueb_object_droptable  @Audit_ID, 'tt_pd_knz_709'
------------------------------------------------------------------------------------------------------------------------

SELECT 	fc.pd_auftr_id
	,fc.org_id 
	, fc.pd_schul_abschl
	, ISNULL(fc.pd_geschlecht, 29004) AS pd_geschlecht --AFM80885
	, dbo.uf_pd_Behinderung_Key(fc.[pd_beh_1])
	| dbo.uf_pd_Behinderung_Key(fc.[pd_beh_2])
	| dbo.uf_pd_Behinderung_Key(fc.[pd_beh_3])
	| dbo.uf_pd_Behinderung_Key(fc.[pd_beh_4])AS pd_beh_key
	, CAST(LEFT(CONVERT ( VARCHAR(8), fc.[pd_abschl_dat], 112), 6) AS INT)  [mon_id]
	, fc.pd_abschl_art
	, fc.bps_bild_abs
	, fc.pd_rks_id
	, fc.pd_tae_durch
INTO /*<DBNAME_PD_CALC>*/con_pd_calc/*<DBNAME_PD_CALC>*/.dbo.tt_pd_knz_709
FROM tf_pd_fc fc
WHERE fc.pd_veranl_stl <> 23006
	AND fc.pd_fehl_typ = 0
	AND CAST(LEFT(CONVERT ( VARCHAR(8), fc.[pd_abschl_dat], 112), 6) AS INT) BETWEEN @von_mon_id AND @bis_mon_id

------------------------------------------------------------------------------------------------------------------------
EXEC    /*<DBNAME_PD_CALC>*/con_pd_calc/*<DBNAME_PD_CALC>*/.dbo.up_ueb_log_CreateTable  @Audit_ID, 'tt_pd_knz_709', @@ROWCOUNT
------------------------------------------------------------------------------------------------------------------------

SELECT 1 AS Anzahl
	, pd_auftr_id
	, org_id
	, pd_schul_abschl
	, pd_geschlecht
	--Ausbau ################################
	--, pd_age_key
	--Ausbau ################################
	, mon_id
	, pd_abschl_art
	, bps_bild_abs
	, pd_beh_key
	, CASE WHEN (pd_beh_key & 1 <> 0) 
		OR (pd_beh_key = 0)        THEN 1 ELSE 0 END pd_beh1
	, CASE WHEN pd_beh_key & 2 <> 0    THEN 1 ELSE 0 END pd_beh2
	, CASE WHEN pd_beh_key & 4 <> 0    THEN 1 ELSE 0 END pd_beh3
	, CASE WHEN pd_beh_key & 8 <> 0    THEN 1 ELSE 0 END pd_beh4
	, CASE WHEN pd_beh_key & 16 <> 0   THEN 1 ELSE 0 END pd_beh5
	, CASE WHEN pd_beh_key & 32 <> 0   THEN 1 ELSE 0 END pd_beh6
	, CASE WHEN pd_beh_key & 64 <> 0   THEN 1 ELSE 0 END pd_beh7
	, CASE WHEN pd_beh_key & 128 <> 0  THEN 1 ELSE 0 END pd_beh8
	, CASE WHEN pd_beh_key & 256 <> 0  THEN 1 ELSE 0 END pd_beh9
	, CASE WHEN pd_beh_key & 512 <> 0  THEN 1 ELSE 0 END pd_beh10
	, CASE WHEN pd_beh_key & 1024 <> 0 THEN 1 ELSE 0 END pd_beh11
	, CASE WHEN pd_beh_key & 2048 <> 0 THEN 1 ELSE 0 END pd_beh12	--(AFM81921)
	,pd_rks_id
	,pd_tae_durch
INTO tf_pd_knz_709
FROM /*<DBNAME_PD_CALC>*/con_pd_calc/*<DBNAME_PD_CALC>*/.[dbo].[tt_pd_knz_709]	

-- clean up temporary tables

EXEC    /*<DBNAME_PD_CALC>*/con_pd_calc/*<DBNAME_PD_CALC>*/.dbo.up_ueb_object_droptable  @Audit_ID, 'tt_pd_knz_709'

------------------------------------------------------------------------------------------------------------------------
EXEC    dbo.up_ueb_log_CreateTable  @Audit_ID, 'tf_pd_knz_709', @@ROWCOUNT
------------------------------------------------------------------------------------------------------------------------

UPDATE tf_pd_knz_709
	SET pd_schul_abschl = 99999
	WHERE pd_schul_abschl NOT IN (SELECT bn_id FROM /*<DBNAME_PD_KNZ>*/con_pd_knz/*<DBNAME_PD_KNZ>*/.[dbo].vd_bps_Bildungsniveau)
		OR pd_schul_abschl IS NULL

UPDATE tf_pd_knz_709
	SET bps_bild_abs = 55999
	WHERE bps_bild_abs NOT IN (SELECT bas_id FROM /*<DBNAME_PD_KNZ>*/con_pd_knz/*<DBNAME_PD_KNZ>*/.[dbo].vd_bps_Bildungsabschluss)
		OR bps_bild_abs IS NULL

UPDATE tf_pd_knz_709
	SET pd_geschlecht = 99999
	WHERE pd_geschlecht NOT IN (SELECT sex_id FROM /*<DBNAME_PD_KNZ>*/con_pd_knz/*<DBNAME_PD_KNZ>*/.[dbo].vd_pd_geschlecht)
		OR pd_geschlecht IS NULL

UPDATE tf_pd_knz_709
	SET pd_abschl_art = 99999
	WHERE pd_abschl_art NOT IN (SELECT asa_id FROM /*<DBNAME_PD_KNZ>*/con_pd_knz/*<DBNAME_PD_KNZ>*/.[dbo].vd_pd_abschlussart)
		OR pd_abschl_art IS NULL

UPDATE tf_pd_knz_709
	SET pd_rks_id = 99999
	WHERE pd_rks_id NOT IN (SELECT rks_a_id FROM /*<DBNAME_PD_KNZ>*/con_pd_knz/*<DBNAME_PD_KNZ>*/.dbo.vd_bps_rechtskreis_auftraggeber)
		OR pd_rks_id IS NULL

UPDATE tf_pd_knz_709
	SET pd_tae_durch = 9999
	WHERE pd_tae_durch NOT IN (SELECT tkd_id FROM /*<DBNAME_PD_KNZ>*/con_pd_knz/*<DBNAME_PD_KNZ>*/.[dbo].vd_pd_taetigkeit_durchgefuehrt)
		OR pd_tae_durch IS NULL

------------------------------------------------------------------------------------------------------------------------
--	EXEC	dbo.up_ueb_kalender_FaktenViews_Kennzahl	@Audit_ID, 'tf_pd_knz_709', 709
-- zum korrekten Anlagen der AS2000-Views muss derweilen eine etwas andere Vorgehensweise erfolgen, da die Objektnamen doch zu unterschiedlich sind
--EXEC	dbo.up_ueb_kalender_FaktenViews_Kennzahl_Felder @Audit_ID, 'tf_pd_knz_709', 709, '*', NULL, 'knz_pd_709'

-------------------------------------------------------------------------------------------------------------------------------------------
--	Aufruf der Querschnittsfunktion für Erstellung Partitionierung, Indizierung, Faktenviews

EXEC		/*<DBNAME_CON_STRG>*/x/*<DBNAME_CON_STRG>*/.dbo.usp_pd_knz_erstellt	
				@Audit_ID, 'tf_pd_knz_709', 'mon_id';