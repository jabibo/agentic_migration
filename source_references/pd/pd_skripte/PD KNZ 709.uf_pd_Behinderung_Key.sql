
--=========================================================================================================================================
--
--  Erstellung der Hilfsfunktion für Kennzahl 709
--  - Funktion zur Ermittlung des Behinderungskunstschlüssels
--
--=========================================================================================================================================
--
--  24.06.2010  S.Junghans, SIS     Initiale Version
--  09.11.2011  S.Junghans, AIS     Migration auf 2008
--
--=========================================================================================================================================
USE /*<DBNAME_PD_FACT>*/con_pd_fact/*<DBNAME_PD_FACT>*/
    
-----------------------------------------------------------------------------------------------------------------------

EXEC    dbo.up_ueb_object_DropFunction  /*<Strg.Audit_ID>*/NULL/*<Strg.Audit_ID>*/, 'uf_pd_Behinderung_Key'
GO

CREATE  FUNCTION    uf_pd_Behinderung_Key
(
    @Behinderung_Key    INT
) 
RETURNS INT
AS

BEGIN
    -- ID für "fehlende Werte / keine zuordnung möglich" setzen
    SELECT @Behinderung_Key = 
        CASE WHEN ISNULL(@Behinderung_Key, 0) IN (0, 11040, 11041, 11042, 11008, 11010, 11043, 11016, 11035, 11044, 11045, 11046, 11047) THEN ISNULL(@Behinderung_Key, 0)
            ELSE 99999 END
    
    RETURN (SELECT 
        CASE 
            WHEN @Behinderung_Key = 11040   THEN 1      --  1   keine Behinderung
            WHEN @Behinderung_Key = 11041   THEN 2      --  2   Psychische Behinderung
            WHEN @Behinderung_Key = 11042   THEN 4      --  3   Neurologische Behinderung
            WHEN @Behinderung_Key = 11008   THEN 8      --  4   Lernbehinderung
            WHEN @Behinderung_Key = 11010   THEN 16     --  5   Geistige Behinderung
            WHEN @Behinderung_Key = 11043   THEN 32     --  6   Sehbehinderung
            WHEN @Behinderung_Key = 11016   THEN 64     --  7   Hörbehinderung
            WHEN @Behinderung_Key = 11035   THEN 128    --  8   Sprachbehinderung
            WHEN @Behinderung_Key = 11044   THEN 256    --  9   Körperbehinderung - Stütz- und Bewegungsapparat
            WHEN @Behinderung_Key = 11045   THEN 512    --  10  Körperbehinderung - organisch
            WHEN @Behinderung_Key = 11046   THEN 1024   --  11  Sonstige Behinderung
            WHEN @Behinderung_Key = 11047   THEN 2048   --  12  Von Dritten festgestellte Behinderung (AFM81921)
            WHEN @Behinderung_Key = 99999   THEN 4096   --  13  Fehlende Werte/Keine Zuordnung möglich
            ELSE 0                                      --  0/1 keine Behinderung (ohne Schlüssel / Standard)
        END)
END
GO

------- Protokollieren -----------------------------------------------------------------------------------------------
EXEC    dbo.up_ueb_log_CreateFunction /*<Strg.Audit_ID>*/NULL/*<Strg.Audit_ID>*/, 'uf_pd_Behinderung_Key'
