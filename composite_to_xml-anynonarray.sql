CREATE OR REPLACE FUNCTION toxml(objeto anynonarray)
  RETURNS text
  LANGUAGE plpgsql
AS
$body$
DECLARE
    currentName text;
    currentType text;
    currentArray integer;
    currentValue text;
    currentCompuesto integer;
    arraySuffix text;
    finalXML text = '';
BEGIN
    FOR currentName, currentType, currentArray, currentCompuesto IN
        SELECT a.attname
             , coalesce(substring(tt.typname, 2, 100), aa.typname)
             , Case When aa.typarray is null Then 0 Else 1 End
             , Case When tt.typname is null Then 1 Else 0 End
          FROM pg_catalog.pg_class c
          join pg_catalog.pg_attribute a on a.attrelid = c.oid
          left join pg_type tt on tt.typelem = a.atttypid
          left join pg_type aa on aa.typarray = a.atttypid
         WHERE c.relname = pg_typeof(objeto)::text
    LOOP
        if (currentArray = 0) then
            arraySuffix := '';
        else
            arraySuffix := '[]';
        end if;

        if (currentCompuesto = 0) then
            EXECUTE 'SELECT $1."' || currentName ||'"'
               INTO currentValue
              USING objeto, currentName;
        else
            EXECUTE 'SELECT toXML($1."' || currentName || '"::'|| currentType || arraySuffix ||')'
               INTO currentValue
              USING objeto, currentName;
        end if;

          
        finalXML := finalXML || '<' || coalesce(currentName, 'NULL');
        finalXML := finalXML || ' type="' || coalesce(currentType, 'NULL') || '" ';
        finalXML := finalXML || ' array="' || coalesce(currentArray, 0) || '">';
        finalXML := finalXML || coalesce(currentValue, 'NULL');
        finalXML := finalXML ||'</' || coalesce(currentName, 'NULL') || '>';
    END LOOP;
    return finalXML;
END;
$body$
 VOLATILE
 COST 100
