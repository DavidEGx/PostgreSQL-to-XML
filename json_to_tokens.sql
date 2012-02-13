/**
 * Divides a json text into an array
 *
 * @param jsontext Text in json format
 * @return Tokens array
 * 
 * @author David Escribano Garcia <davidegx@gmail.com>
 */
CREATE OR REPLACE FUNCTION json_to_tokens(jsontext text, ordered boolean DEFAULT false)
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
    json_keys text[];
    json_values text[];
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
                    currentState := 'VALUE_END';
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
            json_keys := json_keys || currentKey;
            json_values := json_values || currentValue;
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
        json_keys := json_keys || currentKey;
        json_values := json_values || currentValue;
    end if;

    if (ordered) then
        SELECT array(
            SELECT json_values[j]
              FROM generate_series(1, array_upper(json_values, 1)) j
          ORDER BY json_keys[j]
        )
          INTO json_values;
    end if;

    return json_values;
END;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;

