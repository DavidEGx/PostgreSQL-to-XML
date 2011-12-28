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
    myType text;
BEGIN
    if (array_lower(data, 1) is null) then
        myXML := '';
        return myXML;
    end if;

    FOR i IN array_lower(data, 1) .. array_upper(data, 1) LOOP
        SELECT composite_to_xml(data[i], false)
          into currentElement;

        myType := pg_typeof(data[i])::text;
        myXML := myXML || '<item_' || i::text || ' type="' || myType || '" array="0">' || currentElement || '</item_' || i::text || '>';
    END LOOP;
    if (tableforest) then
        return '<?xml version="1.0"?><xml xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="' || targetns || '">' || myXML || '</xml>';
    else
        return myXML;
    end if;

END;
$BODY$
  LANGUAGE plpgsql STABLE
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

/**
 * Set value of composite variable field dynamically
 *
 * @param source_object Composite variable to be updated
 * @param field_name Field inside the variable that will be updated
 * @param field_value Value for the field
 * @return Returns the source_object with the field updated
 *
 * @author David Escribano Garcia <davidegx@gmail.com>
 * Based on Erwin Brandstetter code (http://goo.gl/aMQyW)
 * 
 */
CREATE OR REPLACE FUNCTION composite_set_field(source_object anyelement, field_name text, field_value text)
    RETURNS anyelement
AS $body$
DECLARE
    _list text;
BEGIN
    _list := (
       SELECT string_agg(x.fld, ',')
         FROM
         (
               SELECT Case
                          When a.attname = field_name Then
                              quote_literal(field_value) || '::'||
                                  (SELECT quote_ident(typname)
                                     FROM pg_catalog.pg_type
                                    WHERE oid = a.atttypid
                                  )
                      Else quote_ident(a.attname)
                      End as fld
                 FROM pg_catalog.pg_attribute a 
                WHERE a.attrelid = (SELECT typrelid
                                      FROM pg_catalog.pg_type
                                     WHERE oid = pg_typeof(source_object)::oid) 
             ORDER BY a.attnum
         ) x
    );

    EXECUTE '
        SELECT ' || _list || '
          FROM   (SELECT $1.*) x'
      USING source_object
       INTO source_object;

    return source_object;
END;
$body$
    LANGUAGE plpgsql STABLE;

/**
 * Divides a json text into an array
 *
 * @param jsontext Text in json format
 * @return Tokens array
 * 
 * @author David Escribano Garcia <davidegx@gmail.com>
 */
CREATE OR REPLACE FUNCTION json_to_tokens(jsontext text)
  RETURNS text[] AS
$BODY$
DECLARE
    i integer := 1;
    stringScaped boolean := false;
    stringOpened boolean := false;
    keysOpened integer := 0;
    currentCharacter char;
    currentState text;
    currentKey text := '';
    currentType text := '';
    currentValue text := '';
    json_tokenized text[];
    isArray boolean;
BEGIN
    jsonText := replace(jsonText, chr(10), '');
    jsonText := replace(jsonText, chr(13), '');
    jsonText := trim(jsonText);

    if (substr(jsonText, 1, 1) = '[') then
        isArray = true;
    else
        isArray = false;
    end if;
    
    jsonText := substr(jsonText, 2, length(jsonText) - 2);
   
    if (isArray) then
        currentState := 'VALUE_START';
    else
        currentState := 'KEY_START';
    end if;

    /*
     * currentState values for object:
     *
     * KEY_START |-> KEY |-> KEY_END |-> VALUE_START |-> VALUE_NUMBER  |-> VALUE_END |
     * |                                             |-> VALUE_TEXT    |             |
     * ^                                             |-> VALUE_OBJECT  |             |
     * |                                             |-> VALUE_ARRAY   |             |
     * |                                             |-> VALUE_BOOLEAN |             |
     * |                                                                             |
     * |--<--------<--------<--------<--------<--------<--------<--------<--------<--|
     * 
     * currentState values for array:
     *
     * VALUE_START      |-> VALUE_NUMBER     |-> VALUE_END |
     * |                |-> VALUE_TEXT       |             |
     * ^                |-> VALUE_OBJECT     |             |
     * |                |-> VALUE_ARRAY      |             |
     * |                |-> VALUE_BOOLEAN    |             |
     * |                                                   |
     * |--<--------<--------<--------<--------<--------<---|
     */
    while (i <= length(jsonText)) loop

        currentCharacter := substring(jsonText, i, 1);

        if (currentState = 'KEY_START') then
            Case
                When currentCharacter = '"' Then
                    currentState = 'KEY';
                Else
            End case;

        elseif (currentState = 'KEY') then
            Case currentCharacter
                When '\' Then
                    if (stringScaped) then
                        stringScaped := false;
                    else
                        stringScaped := true;
                    end if;
                When '"' Then 
                    if (stringScaped) then
                        stringScaped := false;
                    else
                        currentState = 'KEY_END';
                    end if;
                Else
                    currentKey := currentKey || currentCharacter;
            End Case;

        elseif (currentState = 'KEY_END') then
            if (currentCharacter = ':') then
                currentState := 'VALUE_START';
            end if;

        elseif (currentState = 'VALUE_START') then
            Case
                When currentCharacter in ('t','f','n') Then
                    currentState := 'VALUE_BOOLEAN';
                    currentValue := currentValue || currentCharacter;

                When currentCharacter in ('0','1','2','3','4','5','6','7','8','9','-') Then
                    currentState := 'VALUE_NUMBER';
                    currentValue := currentValue || currentCharacter;

                When currentCharacter = '"' Then
                    currentState := 'VALUE_TEXT';

                When currentCharacter = '[' Then
                    currentState := 'VALUE_ARRAY';
                    currentValue := '[';
                    keysOpened := 1;

                When currentCharacter = '{' Then
                    currentState := 'VALUE_OBJECT';
                    currentValue := '{';
                    keysOpened := 1;
                Else
            End Case;

        elseif (currentState = 'VALUE_BOOLEAN') then
            Case
                When (currentValue = 'null') Then
                    currentValue := null;
                When 'true'  like (currentValue || currentCharacter || '%')
                  or 'false' like (currentValue || currentCharacter || '%')
                  or 'null'  like (currentValue || currentCharacter || '%') Then
                    currentValue := currentValue || currentCharacter;
                Else
                    currentState := 'VALUE_END';
            End Case;

        elseif (currentState = 'VALUE_NUMBER') then
            Case
                When currentCharacter in ('0','1','2','3','4','5','6','7','8','9','.','e','E','-') Then
                    currentValue := currentValue || currentCharacter;
                Else
                    currentState := 'VALUE_END';
            End Case;

        elseif (currentState = 'VALUE_TEXT') then
            Case currentCharacter
                When '\' Then
                    if (stringScaped) then
                        stringScaped := false;
                    else
                        stringScaped := true;
                    end if;
                    currentValue := currentValue || currentCharacter;
                When '"' Then
                    if (stringScaped) then
                        currentValue := currentValue || currentCharacter;
                    else
                        currentState := 'VALUE_END';
                    end if;
                    stringScaped := false;
                When ' ' Then
                    currentValue := currentValue || ' ';
                    stringScaped := false;
                Else
                    currentValue := currentValue || currentCharacter;
                    stringScaped := false;
            End Case;
            
        elseif (currentState = 'VALUE_OBJECT') then
            Case currentCharacter
                When '{' Then
                    currentValue := currentValue || currentCharacter;
                    if (not stringOpened) then
                        keysOpened := keysOpened + 1;
                    end if;
                When '}' Then
                    currentValue := currentValue || currentCharacter;
                    if (not stringOpened) then
                        keysOpened := keysOpened - 1;
                        if (keysOpened = 0) then
                            currentState := 'VALUE_END';
                        end if;
                    end if;
                When '"' Then
                    currentValue := currentValue || currentCharacter;
                    if (stringOpened) then
                        if (stringScaped) then
                            stringScaped := false;
                        else
                            stringOpened := false;
                        end if;
                    else
                        stringOpened := true;
                    end if;
                When '\' Then
                    currentValue := currentValue || currentCharacter;
                    if (stringScaped) then
                        stringScaped := false;
                    else
                        stringScaped := true;
                    end if;
                When ' ' Then
                    currentValue := currentValue || ' ';
                    stringScaped := false;
                Else
                    currentValue := currentValue || currentCharacter;
            End Case;

        elseif (currentState = 'VALUE_ARRAY') then
            Case currentCharacter
                When '[' Then
                    currentValue := currentValue || currentCharacter;
                    if (not stringOpened) then
                        keysOpened := keysOpened + 1;
                    end if;
                When ']' Then
                    currentValue := currentValue || currentCharacter;
                    if (not stringOpened) then
                        keysOpened := keysOpened - 1;
                        if (keysOpened = 0) then
                            currentState := 'VALUE_END';
                        end if;
                    end if;
                When '"' Then
                    currentValue := currentValue || currentCharacter;
                    if (stringOpened) then
                        if (stringScaped) then
                            stringScaped := false;
                        else
                            stringOpened := false;
                        end if;
                    else
                        stringOpened := true;
                    end if;
                When '\' Then
                    currentValue := currentValue || currentCharacter;
                    if (stringScaped) then
                        stringScaped := false;
                    else
                        stringScaped := true;
                    end if;
                When ' ' Then
                    currentValue := currentValue || ' ';
                    stringScaped := false;
                Else
                    currentValue := currentValue || currentCharacter;
            End Case;
        end if;

        if (currentState = 'VALUE_END') then
            json_tokenized := json_tokenized || currentValue;
            if (isArray) then
                currentState := 'VALUE_START';
            else
                currentState := 'KEY_START';
            end if;
            currentKey   := '';
            currentValue := '';
        end if;
        i := i + 1;
    end loop;
    if (currentValue <> '') then
        json_tokenized := json_tokenized || currentValue;
    end if;
    return json_tokenized;
END;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;


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

    arrayTokens := json_to_tokens(jsontext);
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

