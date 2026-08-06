
-----------------------------------------------------------------------------------------------------------------------
--
--	Faktenview für BerichtsMonat.Monat Dimensionen im Teilverfahren PD erstellen,
--	in denen die Zeiträume in einer WHERE-Klausel begrenzt werden, um die Source-Table-Filter zu ersetzen.
--
-----------------------------------------------------------------------------------------------------------------------
--
--	10.11.2011	Stefan Junghans, SIS	Erstellung
--	21.05.2014	Stefan Junghans, AIS	Rückbau AS2000 Elemente
-----------------------------------------------------------------------------------------------------------------------

USE	/*<DBNAME_PD_CALC>*/con_pd_calc/*<DBNAME_PD_CALC>*/

	
SET 	NOCOUNT	ON

DECLARE	@Audit_ID	INT
SELECT	@Audit_ID	= /*<Strg.Audit_ID>*/NULL/*<Strg.Audit_ID>*/

-----------------------------------------------------------------------------------------------------------------------
--	Berichtsmonats-View für PD erstellen

DECLARE	@type_monat		INT,
		@Teilverfahren	VARCHAR(  10 ),
		@in_db			VARCHAR( 128 ),
		@from_db        VARCHAR( 128 )

SELECT	@type_monat 	= dbo.uf_ueb_kalender_BerichtsMonatViews_Monat( ),
		@Teilverfahren	= 'pd',
		@in_db	    	= /*<'DBNAME_PD_KNZ'>*/'con_pd_knz'/*<'DBNAME_PD_KNZ'>*/,
		@from_db        = /*<'DBNAME_CON_DIM'>*/'x'/*<'DBNAME_CON_DIM'>*/


EXEC	dbo.up_ueb_log_Meldung	@Audit_ID, 'Faktenview zu Monats-Dimensionen für PD-Cubes anlegen'

EXEC	dbo.up_ueb_kalender_BerichtsMonatViews	@Audit_ID, @Teilverfahren, @type_monat, @in_db, @kennzahlen = /*<'PD.Kennzahlen'>*/'PD.Kennzahlen'/*<'PD.Kennzahlen'>*/


    --  Denormalisierte Dimensionsviews aus con_dim holen,
    --  wegen Sourcetablefilter erst nach obigem Aufruf (vd_pd_KalenderMonat)
EXEC    /*<DBNAME_CON_DIM>*/x/*<DBNAME_CON_DIM>*/.dbo.usp_dim_create_tv_olap_views  @audit_id   = @Audit_ID, 
                                                                                    @ZIELDB     = @in_db, 
                                                                                    @Verfahren  = @Teilverfahren,
                                                                                    @QUELLDB    = @from_db,
                                                                                    @AllMember  = 1;

-------------------------------------------------------------------------------------------------------------------------------------------
