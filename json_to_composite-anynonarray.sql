/**
 * Converts a json object into a Postgresql composite type
 * 
 * @param jsontext Valid json object
 * @param returntype Variable declared as the desired output type
 * @return Composite type representing the input
 * 
 * @author David Escribano Garcia <davidegx@gmail.com>
 */
CREATE OR REPLACE FUNCTION json_to_composite(jsontext text, returntype anynonarray)
  RETURNS anyelement AS
$BODY$
DECLARE
    i integer := 1;
    currentKey text;
    currentType text;
    isObject boolean;
    isArray boolean;
    arrayTokens text[];
    arrayTypes text[];
BEGIN

    arrayTokens := json_to_tokens(jsontext);
    i := 1;

    FOR currentKey, currentType, isArray, isObject IN
          SELECT a.attname
               , coalesce(trim(leading '_' from tt.typname), aa.typname)
               , Case
                     When tt.typelem is null
                         Then true
                     Else false
                 End
               , Case
                     When exists (SELECT 1
                                    FROM pg_catalog.pg_class ic
                                   WHERE ic.relname = trim(leading '_' from tt.typname)
                                  )
                         Then true
                     Else false
                 End
            FROM pg_catalog.pg_class c
            join pg_catalog.pg_attribute a on a.attrelid = c.oid
            left join pg_type tt on tt.typelem = a.atttypid
            left join pg_type aa on aa.typarray = a.atttypid
           WHERE c.relname = pg_typeof(returntype)::text
        ORDER BY a.attnum
    LOOP
        if (isObject) then
            EXECUTE 'SELECT * FROM composite_set_field($1, $2, json_to_composite($3, null::' || currentType || ')::text)'
              USING returntype, currentKey, arrayTokens[i]
               INTO returntype;
        elsif (isArray) then
            EXECUTE 'SELECT * FROM composite_set_field($1, $2, json_to_composite($3, null::' || currentType || '[])::text)'
              USING returntype, currentKey, arrayTokens[i]
               INTO returntype;
        else
            returntype := (SELECT composite_set_field(returntype, currentKey, arrayTokens[i]));
        end if;
        i := i + 1;
    END LOOP;
    return returnType;
END;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
