/**
* Converts a composite type into a xml text
*
* @param data Any array variable
* @param tableforest If true prints a root node
* @param targetns XML namespace
* @return XML representing the input
* @author David Escribano Garcia <davidegx@gmail.com>
*/
CREATE OR REPLACE FUNCTION composite_to_xml(data anyarray, tableforest boolean DEFAULT true, targetns text DEFAULT ''::text)
  RETURNS text AS
$BODY$
DECLARE
    myXML text = '';
    currentElement text;
BEGIN
    FOR i IN array_lower(data, 1) .. array_upper(data, 1) LOOP
        SELECT composite_to_xml(data[i], false)
          into currentElement;
          
        myXML := myXML || currentElement;
    END LOOP;
    if (tableforest) then
        return '<?xml version="1.0"?><xml xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="' || targetns || '">' || myXML || '</xml>';
    else
        return myXML;
    end if;

END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

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

/**
* Converts a composite type into a json text
*
* @param data Any array variable
* @return Json representing the input
* @author David Escribano Garcia <davidegx@gmail.com>
*/
CREATE OR REPLACE FUNCTION composite_to_json(data anyarray)
  RETURNS text AS
$BODY$
DECLARE
    jsonResult text;
    currentElement text;
    currentType text;
BEGIN
    jsonResult := '[';
    FOR i IN array_lower(data, 1) .. array_upper(data, 1) LOOP
        SELECT composite_to_json(data[i])
          into currentElement;

        currentType := pg_typeof(data[i])::text;
        jsonResult := jsonResult || currentElement || ',';
    END LOOP;
    jsonResult := trim(trailing ',' from jsonResult) || ']';
    return jsonResult;

END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

/**
 * Converts a composite type into a json text
 *
 * @param data Any non array variable
 * @return Json representing the input
 * @author David Escribano Garcia <davidegx@gmail.com>
 */
CREATE OR REPLACE FUNCTION composite_to_json(data anynonarray)
  RETURNS text AS
$BODY$
DECLARE
    currentName text;
    currentType text;
    currentValue text;
    jsonResult text := '{';
BEGIN
    if (not exists (SELECT 1 FROM pg_catalog.pg_class WHERE relname = pg_typeof(data)::text)) then
        return data;
    end if;

    FOR currentName, currentType IN
        SELECT a.attname
             , coalesce(substring(tt.typname, 2, 100), aa.typname)
          FROM pg_catalog.pg_class c
          join pg_catalog.pg_attribute a on a.attrelid = c.oid
          left join pg_type tt on tt.typelem = a.atttypid
          left join pg_type aa on aa.typarray = a.atttypid
         WHERE c.relname = pg_typeof(data)::text
      ORDER BY a.attnum
    LOOP

        EXECUTE 'SELECT composite_to_json($1."' || currentName || '")'
           INTO currentValue
          USING data;

        jsonResult := jsonResult || '"' || coalesce(currentName, '"unnamed"') || '":';

        if (currentValue is null) then
            jsonResult := jsonResult || 'null';
        else
            if (currentType = any(ARRAY['char','varchar','text'])) then
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

