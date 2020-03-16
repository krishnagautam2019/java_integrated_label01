--------------------------------------------------------
--  File created - Monday-March-16-2020   
--------------------------------------------------------
--------------------------------------------------------
--  DDL for Function IS_NUMBER
--------------------------------------------------------

  CREATE OR REPLACE FUNCTION "WMSQ1"."IS_NUMBER" (p_string IN VARCHAR2)
   RETURN INT
IS
   v_new_num NUMBER;
BEGIN
   v_new_num := TO_NUMBER(p_string);
   RETURN 1;
EXCEPTION
WHEN VALUE_ERROR THEN
   RETURN 0;
END is_number;

/
