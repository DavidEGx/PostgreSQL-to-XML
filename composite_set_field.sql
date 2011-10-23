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
