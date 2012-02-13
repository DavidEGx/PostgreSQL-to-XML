/**
 * Converts a json array into a Postgresql array
 * 
 * @param jsontext Json input
 * @param returntype Variable declared as the desired return type
 * @return Array representing the input
 * 
 * @author David Escribano Garcia <davidegx@gmail.com>
 */
CREATE OR REPLACE FUNCTION json_to_composite(jsontext text, returntype anyarray)
  RETURNS anyarray AS
$BODY$
DECLARE
    i integer;
    n integer;
    arrayTokens text[];
    innerType text;
BEGIN
    innerType := pg_typeof(returntype[0])::text;

    arrayTokens := json_to_tokens(jsontext, true);
    i := array_lower(arrayTokens, 1);
    n := array_upper(arrayTokens, 1);

    WHILE (i <= n) LOOP
        arrayTokens[i] := trim(replace(replace(arrayTokens[i], chr(10), ''), chr(13), ''));
        if (substr(arrayTokens[i], 1, 1) in  ('[', '{')) then
            -- arrayTokens[i] is an array or an object => i proceed recursively
            EXECUTE 'SELECT $1 || json_to_composite($2, null::' || innerType || ')'
              USING returnType, arrayTokens[i]
               INTO returnType;
        else
            returnType[i] := arrayTokens[i];
        end if;

        i:= i + 1;
    END LOOP;
    
    return returntype;
END;
$BODY$
  LANGUAGE plpgsql STABLE 
  COST 100;
