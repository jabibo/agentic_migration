# Fachnotiz — PD KNZ INIT.vd_pd_KalenderMonat.sql

Reine Framework-Boilerplate: ruft generische Prozeduren
(`up_ueb_kalender_BerichtsMonatViews`, `usp_dim_create_tv_olap_views`)
auf, um Kalender-Views anzulegen. Keine eigene Fachlogik, kein
Migrationsziel — deshalb `excluded`/Klasse C ohne Konsequenz.
