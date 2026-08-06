--<doku>
--=====================================================================================================================
--
--	Berechnung der Kennzahl 711 Auftragseingänge und Auftragsbestände
--
--  	Erzeugte Tabellen:	
--
--				tf_pd_knz_711
--
--=====================================================================================================================
--</doku>
--<doku_rfc>
--=====================================================================================================================
--
--	DATUM				ENTWICKLER
--      ----------      --------------------    -----------------------------------------------------------------------
--	01.07.2010	Stefan Junghans, SIS	Initiale Version
--	20.09.2011	Stefan Junghans, AIS	Migration auf SQL Srv 2008
--	27.03.2012	ReussM					Nacharbeiten MIG2008 (Prozedur zur Kennzahlviewerstellung eingebaut)	
--	14.09.2012	Stefan Junghans, AIS	AFM047655 NEO Welle 2
--	04.12.2012	Stefan Junghans, AIS	AFM047669 NEO Welle 3 (Ausbau org_id_alt)
--	13.11.2013	Stefan Junghans, AIS	AFM058759 Faktenberechnung auf Aufbereitungszeitraum beschraenkt
-- 30.04.2015  ReussM           [AFM68795 Teil 3+4 Schnittstellenaenderung P51 bei FA-Daten]
-- 01.06.2015  ReussM           Fix Spaltenbezeichnung geändert (asa_id, tkd_id, rks_a_id)
-- 18.06.2015  ReussM           Fix, Ermittlung Vormonat optimiert
-- 25.06.2015  Anpassung bei FA-Daten, Eingangs- und Ladedatum zuseatzlich als "mon_id"  mitnehmen
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

FROM		dbo.uf_ueb_kalender_Kennzahl( '711' )	;


-- Fakten schreiben
------------------------------------------------------------------------------------------------------------------------
EXEC    dbo.up_ueb_object_droptable  @Audit_ID, 'tf_pd_knz_711_vorP51'
------------------------------------------------------------------------------------------------------------------------
--vor P51
SELECT fa.pd_anz_eingae
	,fa.pd_anz_in_bear
	,fa.pd_asa_id as asa_id		   --neu mit P51, Anpassung Spaltenname wegen MSTR
   ,fa.pd_tkd_id as tkd_id		   --neu mit P51, Anpassung Spaltenname wegen MSTR
   ,fa.pd_rks_a_id as rks_a_id	--neu mit P51, Anpassung Spaltenname wegen MSTR
	, fa.org_id
	, CAST(LEFT(CONVERT ( VARCHAR(8), fa.[pd_zeit_von], 112), 6) AS INT) [mon_id]
INTO tf_pd_knz_711_vorP51
FROM dbo.tf_pd_fa fa
WHERE CAST(LEFT(CONVERT ( VARCHAR(8), fa.[pd_zeit_von], 112), 6) AS INT) BETWEEN @von_mon_id AND '201503'--von Anfang bis vor P51


------------------------------------------------------------------------------------------------------------------------
EXEC    dbo.up_ueb_object_droptable  @Audit_ID, 'tf_pd_knz_711_nachP51'
------------------------------------------------------------------------------------------------------------------------
--nach P51
SELECT
SUM (CASE WHEN 
   fa.mon_id_eing = fa.mon_id_load_decr --wenn Eingang im Lademonat-1, (-1 da Liefermonat mit Daten aus Vormonat)
	THEN 1
	ELSE 0
	END) AS pd_anz_eingae
,SUM(CASE WHEN fa.pd_asa_id in (10010, 10011) THEN 0
	ELSE 1 
   END) AS pd_anz_in_bear
,ISNULL(fa.pd_asa_id, 99999) AS	asa_id	   --neu mit P51, Anpassung Spaltenname wegen MSTR
,ISNULL(fa.pd_tkd_id, 9999) AS tkd_id  	   --neu mit P51, Anpassung Spaltenname wegen MSTR
,ISNULL(fa.pd_rks_a_id, 99999) AS rks_a_id	--neu mit P51, Anpassung Spaltenname wegen MSTR
,fa.org_id
,fa.mon_id_load_decr as mon_id

INTO tf_pd_knz_711_nachP51

FROM dbo.tf_pd_fa fa

WHERE fa.mon_id_load_decr BETWEEN '201504' AND @bis_mon_id --von P51 bis Ende
GROUP BY fa.mon_id_load_decr, fa.pd_asa_id, fa.pd_tkd_id, fa.pd_rks_a_id, fa.org_id


------------------------------------------------------------------------------------------------------------------------
EXEC    dbo.up_ueb_object_droptable  @Audit_ID, 'tf_pd_knz_711'
------------------------------------------------------------------------------------------------------------------------
--zusammenfuehren vor/nach P51
SELECT *
INTO tf_pd_knz_711

FROM tf_pd_knz_711_vorP51
   UNION ALL 
SELECT * FROM tf_pd_knz_711_nachP51


------------------------------------------------------------------------------------------------------------------------
EXEC    dbo.up_ueb_log_CreateTable  @Audit_ID, 'tf_pd_knz_711', @@ROWCOUNT
------------------------------------------------------------------------------------------------------------------------

--	EXEC	dbo.up_ueb_kalender_FaktenViews_Kennzahl	@Audit_ID, 'tf_pd_knz_711', 711
-- zum korrekten Anlagen der AS2000-Views muss derweilen eine etwas andere Vorgehensweise erfolgen, da die Objektnamen doch zu unterschiedlich sind
--EXEC	dbo.up_ueb_kalender_FaktenViews_Kennzahl_Felder @Audit_ID, 'tf_pd_knz_711', 711, '*', NULL, 'knz_pd_711'

-------------------------------------------------------------------------------------------------------------------------------------------
--	Aufruf der Querschnittsfunktion für Erstellung Partitionierung, Indizierung, Faktenviews

EXEC		/*<DBNAME_CON_STRG>*/x/*<DBNAME_CON_STRG>*/.dbo.usp_pd_knz_erstellt	
				@Audit_ID, 'tf_pd_knz_711', 'mon_id';