# Bitwise AND in Exasol

Exasol unterstützt keinen `&`-Operator für Bit-Operationen. Stattdessen
jede Bit-Prüfung `col & V <> 0` ersetzen durch
`MOD(FLOOR(col / V), 2) <> 0` wobei V die Potenz von 2 ist (1,2,4,8,...).