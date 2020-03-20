--------------------------------------------------------
--  File created - Monday-March-16-2020   
--------------------------------------------------------
--------------------------------------------------------
--  DDL for Function JC_SCANDATA_MSG_CANCEL_SHIP
--------------------------------------------------------

  CREATE OR REPLACE FUNCTION "WMSQ1"."JC_SCANDATA_MSG_CANCEL_SHIP" (
                                  v_tc_lpn_id       in      varchar2
                                , v_session_id      in      number      default null )
                return clob as
    v_xml   clob;                
begin
    v_xml := jc_scandata_msgs_gen.jc_scnd_msg_cancel_ship( v_tc_lpn_id, v_session_id );
    return v_xml;
end jc_scandata_msg_cancel_ship;

/
