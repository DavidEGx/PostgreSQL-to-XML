/**
 * Converts a composite type into a xml text
 *
 * @param objeto Any array variable
 * @return XML representing the input
 * @author David Escribano Garcia <davidegx@gmail.com>
 */
CREATE OR REPLACE FUNCTION composite_to_xml(objeto anyarray)
  RETURNS text
  LANGUAGE plpgsql
AS
$body$
DECLARE
    myXML text = '';
    currentElement text;
BEGIN
    FOR i IN array_lower(objeto, 1) .. array_upper(objeto, 1) LOOP
        SELECT composite_to_xml(objeto[i])
          into currentElement;
          
        myXML := myXML || currentElement;
    END LOOP;
    return myXML;
END;
$body$
 VOLATILE
 COST 100
