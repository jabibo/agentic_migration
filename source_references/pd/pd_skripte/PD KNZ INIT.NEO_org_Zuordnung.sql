-----------------------------------------------------------------------------------------------------------------------
--
--	AFM047665: BI-Controlling-Berichtswesen_C13087-0_Änderungen in der Organisationsstruktur PD / PD-Cockpit durch NEO und neues Fachkonzept
--	- NEO Implementierung - Verarbeitung der Zuordnungstabellen und Schlüsseleung von org_id und org_id_alt
--	AFM047669: BI-Controlling-Berichtswesen_C13087-1_Änderungen in der Organisationsstruktur PD / PD-Cockpit durch NEO und neues Fachkonzept 
--	- NEO Implementierung Welle 3 (W3)- Reduktion und Änderung der Zuordnungstabellen für org_ids alt->NEO_W3 und NEO_W2 -> NEO_W3
--	
--	- erzeugte Tabellen:
--		-	con_pd_calc.dbo.tt_delta_pd_fc_org
--		-	con_pd_fact.dbo.tf_pd_fa
--
-----------------------------------------------------------------------------------------------------------------------
--
--	13.09.2012	Stefan Junghans, AIS	Erstellung
--	04.12.2012	Stefan Junghans, AIS	AFM047669: Umbau für NEO Welle 3
-- 25.06.2015							Anpassung bei FA-Daten, Eingangs- und Ladedatum zuseatzlich als "mon_id"  mitnehmen
-- 25.04.2016	ReussM					[78830_BI-Ergebniscontrolling-BI_KNZ_78581_Verkürzung_Nutzungsdauer]
-- 20.05.2019	ReussM					[AFM87580_MYSKILLS_Monitoring_DIPF_BI]
--										Anpassung zu Schnittstellenänderung mit P92 (2 neue Attribute BKESPRACHE ud TRAEGERNUMMER)
--										Rückbau der NEO-Wellen Betrachtung für Daten aus 2011
-----------------------------------------------------------------------------------------------------------------------

USE	/*<DBNAME_PD_CALC>*/con_pd_calc/*<DBNAME_PD_CALC>*/

	
SET 	NOCOUNT	ON

DECLARE	@Audit_ID	INT
SELECT	@Audit_ID	= /*<Strg.Audit_ID>*/NULL/*<Strg.Audit_ID>*/


EXEC	dbo.up_ueb_object_droptable  @Audit_ID, 'tt_deltant_pd_fc_org'

SELECT
	f.*, 
	dst.org_id AS org_id,
	ISNULL(reg.gst_id, 9999) AS gst_id

INTO	dbo.tt_deltant_pd_fc_org

FROM /*<DBNAME_PD_DWH>*/con_pd_dwh/*<DBNAME_PD_DWH>*/.dbo.tf_deltant_pd_fc_k f

	LEFT OUTER JOIN /*<DBNAME_PD_KNZ>*/con_pd_knz/*<DBNAME_PD_KNZ>*/.dbo.vd_pd_dienststelle dst
		ON dst.ba_schl = f.pd_dnst_nr
	LEFT OUTER JOIN /*<DBNAME_PD_KNZ>*/con_pd_knz/*<DBNAME_PD_KNZ>*/.dbo.vd_as_bps_Region reg --P92, TRAEGERNUMMER mit ba_schl Umwandlung in gst_id
		ON f.pd_trg_schl = reg.gst_ba_schl
		AND reg.gst_guelt_bis_dat IS NULL

EXEC	dbo.up_ueb_log_CreateTable  @Audit_ID, 'tt_deltant_pd_fc_org', @@ROWCOUNT

----------------------------------------------------------------------------------------------------


EXEC	/*<DBNAME_PD_FACT>*/con_pd_fact/*<DBNAME_PD_FACT>*/.dbo.up_ueb_object_droptable  @Audit_ID, 'tf_pd_fa'

SELECT
	f.*
	,kal_eing.mon_id as mon_id_eing 
	,dbo.uf_ueb_kalender_MonatAdd(LEFT(CONVERT (VARCHAR(8), bi_load_date, 112), 6),-1) as mon_id_load_decr 
	,dst.org_id org_id
INTO	/*<DBNAME_PD_FACT>*/con_pd_fact/*<DBNAME_PD_FACT>*/.dbo.tf_pd_fa

FROM /*<DBNAME_PD_DWH>*/con_pd_dwh/*<DBNAME_PD_DWH>*/.dbo.tf_deltant_pd_fa_k f

	LEFT OUTER JOIN /*<DBNAME_PD_KNZ>*/con_pd_knz/*<DBNAME_PD_KNZ>*/.[dbo].vd_pd_dienststelle dst
		ON dst.ba_schl = f.pd_agent_nr
	
	LEFT JOIN [dbo].[td_ueb_kalender_Tag] kal_eing
		ON f.pd_dat_eing = kal_eing.tag_dat	

EXEC	/*<DBNAME_PD_FACT>*/con_pd_fact/*<DBNAME_PD_FACT>*/.dbo.up_ueb_log_CreateTable  @Audit_ID, 'tf_pd_fa', @@ROWCOUNT