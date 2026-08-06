-----------------------------------------------------------------------------------------------------------------------
--
--	AFM040701: Umgang mit unplausiblen Datensätzen für das Fachcontrolling des PD: Leer-Werte 
--	- Fakten erhalten neue DIM-IDs für unplausible Fallabschlüsse (Umsetzung des AFM040701)
--	- 
--
--	- erzeugte Tabellen:
--		-	tf_pd_fc
--
-----------------------------------------------------------------------------------------------------------------------
--
--	12.06.2012	Stefan Junghans, AIS	AFM40701 Umgang	mit	unplausiblen Datensätzen für das Fachcontrolling des PD: Leer-Werte	
--	13.09.2012	Stefan Junghans, AIS	Umbau in separates Skript im Zuge AFM047665
--	06.12.2012	Stefan Junghans, AIS	manueller Merge im Zuge AFM047669 (NEO3) wegen gemeinsamer Produktivsetzung
--	08.11.2013	Stefan Junghans, AIS	AFM058759 BI_BER_Anpassungen an den Dimensionen „Stelle“, „Rechtskreis Auftraggeber“ und „Beschäftigungsstand“ im BPS-Cockpit  im Zuge von Veränderungen bei DELTA.NT und VerBIS   - SBT 
--										Erweiterung ueber die unplausiblen Fallabschluesse hinaus
--	19.11.2014	Stefan Junghans, AIS	AFM068953: BI_BER_68792_Weiterentwicklung BPS-Fachcontrolling Teil 2 - Anpassung der Laufzeitendarstellung - Bruttolaufzeiten
--	07.04.2016	ReussM					[AFM80885-Erweiterung der Auswahlliste Geschlechts um das Merkmal kein Eintrag im Geburtenregister]
--										Schnittstellenänderung ab P61 (April 2016), ID 29003 "unbekannt" wird 29004 "unbekannt"
--										alle ID´s vor P61 werden damit auf 29004 gehoben
--	13.07.2017	ReussM					[AFM84892_BI-EC-@MySkills-BKE-Ergänzungen_zum_AFM-RfC_81919]
--										Anpassung zu Schnittstellenänderung mit P72 (2 neue Attribute bkeberuf, kundentyp)
--	27.02.2019	ReussM					[AFM90745_Entfernung der Variable 'Kundentyp'] + [AFM90448_Implementierung einer neuen Variable 'Dringlichkeit']
--										Entfernung der kdt_id und Einbau dgk_id zu BM201903 (P91)
--	20.05.2019	ReussM					[AFM87580_MYSKILLS_Monitoring_DIPF_BI]
--										Anpassung zu Schnittstellenänderung mit P92 (2 neue Attribute BKESPRACHE ud TRAEGERNUMMER)
-- 01.02.2024	ReussM					AFM109413_Aktualisierung_BPS-Cockpit_Berichte (Attribut Alter/pd_geb_dat zurückgebaut)
-----------------------------------------------------------------------------------------------------------------------

USE	/*<DBNAME_PD_FACT>*/con_pd_fact/*<DBNAME_PD_FACT>*/

	
SET 	NOCOUNT	ON

DECLARE	@Audit_ID	INT
SELECT	@Audit_ID	= /*<Strg.Audit_ID>*/NULL/*<Strg.Audit_ID>*/


EXEC	dbo.up_ueb_object_droptable  @Audit_ID, 'tf_pd_fc'

SELECT	[pd_auftr_id]
		,[pd_fehl_typ]
		,[pd_fehler_txt]
		,[pd_dnst_nr]
		,[org_id]
		,CASE 
	      WHEN pd_tae_beauf = 2020	THEN pd_bkb_id	--wenn Taetigkeitsform '2020 MySkills' dann Attribut 'bkeberuf' (Detailsausprägung) verwenden, da Dartstellung in einer Dimension 
		   ELSE pd_tae_beauf
		 END AS [pd_tae_beauf]
		 ,CASE 
	       WHEN pd_tae_durch = 2020	THEN pd_bkb_id	--wenn Taetigkeitsform '2020 MySkills' dann Attribut 'bkeberuf' (Detailsausprägung) verwenden, da Dartstellung in einer Dimension 
		    ELSE pd_tae_durch
		  END AS pd_tae_durch
		,CASE 
			WHEN pd_veranl_stl = 23018	THEN	23015
			WHEN pd_veranl_stl = 23017	THEN	23016
			ELSE pd_veranl_stl
		END pd_veranl_stl 
		,CASE 
			WHEN pd_rks_id = 52002		THEN	52003
			ELSE pd_rks_id
		END pd_rks_id
		,[pd_schul_abschl]
		,CASE 
	      WHEN (LEFT(CONVERT (VARCHAR(8), bi_load_date, 112), 6))-1 < 201604 --AFM80885, alle ID´s mit 29003 vor P61 (201604) werden auf Wert 29004 gehoben
		   AND pd_geschlecht = 29003 THEN 29004
		   ELSE pd_geschlecht
	   END AS pd_geschlecht
		,[pd_leist_art_1]
		,[pd_leist_art_2]
		,[pd_beh_1]
		,[pd_beh_2]
		,[pd_beh_3]
		,[pd_beh_4]
		,[pd_anzahl_pt]
		,[pd_eing_dat]
		,[pd_abschl_dat]
		, CASE 
			WHEN ([pd_abschl_art] =	10010 AND ISNULL([pd_tae_durch], 0)	= 0) THEN 10012
			ELSE [pd_abschl_art]
		END	[pd_abschl_art]
		,[pd_abschl_grund]
		,[pd_gez]
		,[pd_lz]
		,[pd_create_dat]
		,[pd_update_dat]
		,[bps_bild_abs]
		,[pd_lpe]
		,[pd_lap]
		,[pd_bkb_id]
		,ISNULL(pd_dgk_id,9999) AS [pd_dgk_id] --9999 'fehlende Werte/keine Zuordnung möglich'
		,[pd_spr_id]
		,[gst_id]
		,[bi_load_date]
		,[bi_load_filename]
INTO	tf_pd_fc
FROM	/*<DBNAME_PD_CALC>*/con_pd_calc/*<DBNAME_PD_CALC>*/.dbo.tt_deltant_pd_fc_org


EXEC	dbo.up_ueb_log_CreateTable  @Audit_ID, 'tf_pd_fc', @@ROWCOUNT
