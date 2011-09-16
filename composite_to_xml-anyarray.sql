CREATE OR REPLACE FUNCTION toxml(objeto anyarray)
  RETURNS text
  LANGUAGE plpgsql
AS
$body$
DECLARE
    myXML text = '';
    currentElement text;
BEGIN
    FOR i IN array_lower(objeto, 1) .. array_upper(objeto, 1) LOOP
        SELECT toXML(objeto[i])
          into currentElement;
          
        myXML := myXML || currentElement;
    END LOOP;
    return myXML;
END;
$body$
 VOLATILE
 COST 100
