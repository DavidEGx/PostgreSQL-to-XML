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
    currentCategory char;
    finalXML text = '';
    dataType text;
BEGIN
    dataType := pg_typeof(data)::text;
    dataType := trim(both '"' from dataType);

    if (not exists (SELECT 1 FROM pg_catalog.pg_class WHERE relname = dataType)) then
        return data;
    end if;

    FOR currentName, currentType, currentCategory IN
        SELECT a.attname
             , coalesce(aa.typname, tt.typname)
             , tt.typcategory
          FROM pg_catalog.pg_class c
          join pg_catalog.pg_attribute a on a.attrelid = c.oid
          join pg_catalog.pg_type tt on tt.oid = a.atttypid
          left join pg_catalog.pg_type aa on aa.oid = tt.typelem
         WHERE c.relname = dataType
           and a.atttypid <> 0
           and a.attnum > 0
           and a.attisdropped = false
      ORDER BY a.attnum
    LOOP
        EXECUTE 'SELECT composite_to_xml($1."' || currentName || '", false)'
           INTO currentValue
          USING data, currentName;

        finalXML := finalXML || '<' || coalesce(currentName, 'NULL');
        finalXML := finalXML || ' type="' || coalesce(currentType, 'NULL') || '"';
        if (currentCategory = 'A') then
            finalXML := finalXML || ' array="1">';
        else
            finalXML := finalXML || ' array="0">';
        end if;
        finalXML := finalXML || coalesce(currentValue, 'NULL');
        finalXML := finalXML ||'</' || coalesce(currentName, 'NULL') || '>';
    END LOOP;
    if (tableforest) then
        finalXML := '<?xml version="1.0"?><xml xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="' || targetns || '">' || finalXML;
        finalXML := finalXML || '</xml>';
    end if;
    return finalXML;
END;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;

