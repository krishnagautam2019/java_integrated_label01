--------------------------------------------------------
--  File created - Monday-March-16-2020   
--------------------------------------------------------
--------------------------------------------------------
--  DDL for Function JC_SCANDATA_MSG_LOAD_SHIP
--------------------------------------------------------

  CREATE OR REPLACE FUNCTION "WMSQ1"."JC_SCANDATA_MSG_LOAD_SHIP" (
                                  v_tc_shipment_id  in      varchar2
                                , v_part_num        in      number
                                , v_session_id      in      number      default null ) 
                return clob as
    v_xml   clob;                
begin
    /*
    dbms_output.put_line(   chr(10) || 'v_tc_shipment_id : ' || v_tc_shipment_id ||
                            chr(10) || 'v_part_num : ' || v_part_num ||
                            chr(10) || 'v_session_id : ' || v_session_id );
    */
    
    v_xml := jc_scandata_msgs_gen.jc_scnd_msg_load_ship( v_tc_shipment_id, v_part_num, v_session_id );
    return v_xml;
    
end jc_scandata_msg_load_ship;

/
