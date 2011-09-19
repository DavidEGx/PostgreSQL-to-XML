/**
 * Converts a composite type into a xml text
 *
 * @param data Any non array variable
 * @param tableforest If true prints a root node
 * @param targetns XML namespace
 * @return XML representing the input
 * @author David Escribano Garcia <davidegx@gmail.com>
 */
CREATE OR REPLACE FUNCTION composite_to_xml(data anynonarray, tableforest boolean DEFAULT true, targetns text DEFAULT ''::text)
  RETURNS text AS
$BODY$
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
         WHERE c.relname = pg_typeof(data)::text
    LOOP
        if (isArray = 0) then
            arraySuffix := '';
        else
            arraySuffix := '[]';
        end if;

        if (isComposite = 0) then
            EXECUTE 'SELECT $1."' || currentName ||'"'
               INTO currentValue
              USING data, currentName;
        else
            EXECUTE 'SELECT composite_to_xml($1."' || currentName || '"::'|| currentType || arraySuffix ||', false)'
               INTO currentValue
              USING data, currentName;
        end if;

        if (tableforest) then
            finalXML := '<?xml version="1.0"?><xml xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="' || targetns || '">';
        end if;
        finalXML := finalXML || '<' || coalesce(currentName, 'NULL');
        finalXML := finalXML || ' type="' || coalesce(currentType, 'NULL') || '" ';
        finalXML := finalXML || ' array="' || coalesce(isArray, 0) || '">';
        finalXML := finalXML || coalesce(currentValue, 'NULL');
        finalXML := finalXML ||'</' || coalesce(currentName, 'NULL') || '>';
        if (tableforest) then
            finalXML := finalXML || '</xml>';
        end if;
    END LOOP;
    return finalXML;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

