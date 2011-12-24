/**
 * Converts a composite type into a json text
 *
 * @param data Any non array variable
 * @return Json representing the input
 * @author David Escribano Garcia <davidegx@gmail.com>
 */
CREATE OR REPLACE FUNCTION composite_to_json(data anynonarray, root boolean DEFAULT true)
  RETURNS text AS
$BODY$
DECLARE
    currentName text;
    currentType text;
    currentValue text;
    jsonResult text := '{';
    dataType text;
BEGIN
    dataType := pg_typeof(data)::text;
    dataType := trim(both '"' from dataType);

    if (not exists (SELECT 1 FROM pg_catalog.pg_class WHERE relname = dataType)) then
        if (root) then
            if (dataType = any(ARRAY['char','varchar','text', 'timestamp'])) then
                return '{"":"' || data || '"}';
            else
                return '{"":' || data || '}';
            end if;
        else
            return data;
        end if;
    end if;

    FOR currentName, currentType IN
        SELECT a.attname
             , coalesce(substring(tt.typname, 2, 100), aa.typname)
          FROM pg_catalog.pg_class c
          join pg_catalog.pg_attribute a on a.attrelid = c.oid
          left join pg_type tt on tt.typelem = a.atttypid
          left join pg_type aa on aa.typarray = a.atttypid
         WHERE c.relname = dataType
           and a.atttypid <> 0
      ORDER BY a.attnum
    LOOP

        EXECUTE 'SELECT composite_to_json($1."' || currentName || '", false)'
           INTO currentValue
          USING data;

        jsonResult := jsonResult || '"' || coalesce(currentName, '"unnamed"') || '":';

        if (currentValue is null) then
            jsonResult := jsonResult || 'null';
        else
            if (currentType = any(ARRAY['char','varchar','text', 'timestamp'])) then
                jsonResult := jsonResult || '"' || currentValue || '"';
            elseif (currentType = 'bool' and currentValue = 't') then
                jsonResult := jsonResult || 'true';
            elseif (currentType = 'bool') then
                jsonResult := jsonResult || 'false';
            else
                jsonResult := jsonResult || currentValue;
            end if;
        end if;
        jsonResult := jsonResult || ',';
    END LOOP;
    jsonResult := trim(trailing ',' from jsonResult) || '}';
    return jsonResult;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
