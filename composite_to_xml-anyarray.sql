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
  LANGUAGE plpgsql VOLATILE
  COST 100;

