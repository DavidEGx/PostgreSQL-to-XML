/**
* Converts a composite type into a json text
*
* @param data Any array variable
* @return Json representing the input
* @author David Escribano Garcia <davidegx@gmail.com>
*/
CREATE OR REPLACE FUNCTION composite_to_json(data anyarray, root boolean DEFAULT true)
  RETURNS text AS
$BODY$
DECLARE
    jsonResult text;
    currentElement text;
    currentType text;
BEGIN
    if (array_lower(data, 1) is null) then
        jsonResult := '[]';
        return jsonResult;
    end if;

    jsonResult := '[';
    FOR i IN array_lower(data, 1) .. array_upper(data, 1) LOOP
        SELECT composite_to_json(data[i], false)
          into currentElement;

        currentType := pg_typeof(data[i])::text;
        jsonResult := jsonResult || currentElement || ',';
    END LOOP;
    jsonResult := trim(trailing ',' from jsonResult) || ']';
    return jsonResult;

END;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
