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
    currentCategory char;
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

        -- Add name
        jsonResult := jsonResult || '"' || coalesce(currentName, '"unnamed"') || '":';
        
        -- Get the value
        if (currentCategory = any(ARRAY['A', 'C'])) then
            EXECUTE 'SELECT composite_to_json($1."' || currentName || '", false)'
               INTO currentValue
              USING data;
        else
            EXECUTE 'SELECT $1."' || currentName || '"'
               INTO currentValue
              USING data;
        end if;

        -- Add the value
        if (currentValue is null) then
            jsonResult := jsonResult || 'null';
        else
            if (currentCategory = any(ARRAY['A', 'C', 'N'])) then
                jsonResult := jsonResult || currentValue;
            elseif (currentCategory = 'B' and currentValue = 't') then
                jsonResult := jsonResult || 'true';
            elseif (currentCategory = 'B') then
                jsonResult := jsonResult || 'false';
            else
                currentValue := regexp_replace(currentValue, '\\', '\\\\');
                currentValue := regexp_replace(currentValue, '"', '\\"');
                jsonResult := jsonResult || '"' || currentValue || '"';
            end if;
        end if;
        jsonResult := jsonResult || ',';
    END LOOP;
    jsonResult := trim(trailing ',' from jsonResult) || '}';
    return jsonResult;
END;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
