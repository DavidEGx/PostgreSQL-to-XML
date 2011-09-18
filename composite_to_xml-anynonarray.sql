/**
 * Converts a composite type into a xml text
 *
 * @param objeto Any non array variable
 * @return XML representing the input
 * @author David Escribano Garcia <davidegx@gmail.com>
 */
CREATE OR REPLACE FUNCTION composite_to_xml(objeto anynonarray)
  RETURNS text
  LANGUAGE plpgsql
AS
$body$
DECLARE
    currentName text;
    currentType text;
    currentValue text;
    isArray integer;
    isComposite integer;
    arraySuffix text;
    finalXML text = '';
BEGIN
    FOR currentName, currentType, isArray, isComposite IN
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
        if (isArray = 0) then
            arraySuffix := '';
        else
            arraySuffix := '[]';
        end if;

        if (isComposite = 0) then
            EXECUTE 'SELECT $1."' || currentName ||'"'
               INTO currentValue
              USING objeto, currentName;
        else
            EXECUTE 'SELECT composite_to_xml($1."' || currentName || '"::'|| currentType || arraySuffix ||')'
               INTO currentValue
              USING objeto, currentName;
        end if;
         
        finalXML := finalXML || '<' || coalesce(currentName, 'NULL');
        finalXML := finalXML || ' type="' || coalesce(currentType, 'NULL') || '" ';
        finalXML := finalXML || ' array="' || coalesce(isArray, 0) || '">';
        finalXML := finalXML || coalesce(currentValue, 'NULL');
        finalXML := finalXML ||'</' || coalesce(currentName, 'NULL') || '>';
    END LOOP;
    return finalXML;
END;
$body$
 VOLATILE
 COST 100
