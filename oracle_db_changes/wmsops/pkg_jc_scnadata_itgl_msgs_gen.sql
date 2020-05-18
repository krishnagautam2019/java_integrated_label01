CREATE OR REPLACE package jc_scnadata_itgl_msgs_gen as


    function jc_scnd_msg_create_ship_via ( 
                                  v_tc_lpn_id       in      varchar2
                                , v_session_id      in      number      default null )
                return clob;


    function jc_scnd_msg_cancel_ship ( 
                                  v_tc_lpn_id       in      varchar2
                                , v_session_id      in      number      default null ) 
                return clob;


    function jc_scnd_msg_get_ship_label ( 
                                  v_tc_lpn_id       in      varchar2 
                                , v_session_id      in      number      default null )
                return clob;
                

    function jc_scnd_msg_load_ship ( 
                                  v_tc_shipment_id  in      varchar2
                                , v_part_num        in      number
                                , v_session_id      in      number      default null ) 
                return clob;


    function jc_scnd_msg_manifest_trlr  ( 
                                  v_tc_shipment_id  in      varchar2 
                                , v_session_id      in      number      default null ) 
                return clob;


end jc_scnadata_itgl_msgs_gen;
/


CREATE OR REPLACE package body jc_scnadata_itgl_msgs_gen as


    function jc_scnd_msg_create_ship_via ( 
                                  v_tc_lpn_id       in      varchar2
                                , v_session_id      in      number      default null ) 
                return clob as
        v_code                  VARCHAR2(10);
        v_errm                  VARCHAR2(256);  

        v_xml_clob              CLOB;
    begin
        v_xml_clob := jc_scandata_msgs_gen.jc_scnd_msg_create_ship_via( v_tc_lpn_id, null, v_session_id );
        wms_jc_scandata_req_resp_updt.updt_create_request( v_xml_clob, to_number( v_tc_lpn_id ) );
    exception
       when jc_exception_pkg.assertion_failure_exception then
          rollback;
          raise;
       when no_data_found  then
          null;
       when others then 
          rollback;
          v_code := SQLCODE;
          v_errm := SUBSTR(SQLERRM, 1, 255);
          jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)',
                                    'v_tc_lpn_id : ' || v_tc_lpn_id );   
    end;


    function jc_scnd_msg_cancel_ship ( 
                                  v_tc_lpn_id       in      varchar2
                                , v_session_id      in      number      default null ) 
                return clob as
        v_code                  VARCHAR2(10);
        v_errm                  VARCHAR2(256);  

        v_xml_clob              CLOB;
    begin
        v_xml_clob := jc_scandata_msgs_gen.jc_scnd_msg_cancel_ship( v_tc_lpn_id, v_session_id );
        wms_jc_scandata_req_resp_updt.updt_cancel_request( v_xml_clob, to_number( v_tc_lpn_id ) );
    exception
       when jc_exception_pkg.assertion_failure_exception then
          rollback;
          raise;
       when no_data_found  then
          null;
       when others then 
          rollback;
          v_code := SQLCODE;
          v_errm := SUBSTR(SQLERRM, 1, 255);
          jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)',
                                    'v_tc_lpn_id : ' || v_tc_lpn_id );   
    end;


    function jc_scnd_msg_get_ship_label ( 
                                  v_tc_lpn_id       in      varchar2 
                                , v_session_id      in      number      default null )
                return clob as
        v_code                  VARCHAR2(10);
        v_errm                  VARCHAR2(256);  

        v_xml_clob              CLOB;
    begin
        v_xml_clob := jc_scandata_msgs_gen.jc_scnd_msg_get_ship_label( v_tc_lpn_id, v_session_id );
        --wms_jc_scandata_req_resp_updt.updt_create_request( v_xml_clob, to_number( v_tc_lpn_id ) );
    exception
       when jc_exception_pkg.assertion_failure_exception then
          rollback;
          raise;
       when no_data_found  then
          null;
       when others then 
          rollback;
          v_code := SQLCODE;
          v_errm := SUBSTR(SQLERRM, 1, 255);
          jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)',
                                    'v_tc_lpn_id : ' || v_tc_lpn_id );   
    end;


    function jc_scnd_msg_load_ship ( 
                                  v_tc_shipment_id  in      varchar2
                                , v_part_num        in      number
                                , v_session_id      in      number      default null ) 
                return clob as
        v_code                  VARCHAR2(10);
        v_errm                  VARCHAR2(256);  

        v_xml_clob              CLOB;
    begin
        v_xml_clob := jc_scandata_msgs_gen.jc_scnd_msg_load_ship( v_tc_shipment_id, v_part_num, v_session_id );
        wms_jc_scandata_req_resp_updt.updt_load_ship_request( v_xml_clob, to_number( substr( v_tc_shipment_id || v_part_num, 3,9 ) ) );
    exception
       when jc_exception_pkg.assertion_failure_exception then
          rollback;
          raise;
       when no_data_found  then
          null;
       when others then 
          rollback;
          v_code := SQLCODE;
          v_errm := SUBSTR(SQLERRM, 1, 255);
          jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)',
                                    'v_tc_shipment_id : ' || v_tc_shipment_id || ' v_part_num : ' || v_part_num );   
    end;


    function jc_scnd_msg_manifest_trlr  ( 
                                  v_tc_shipment_id  in      varchar2 
                                , v_session_id      in      number      default null ) 
                return clob as
        v_code                  VARCHAR2(10);
        v_errm                  VARCHAR2(256);  

        v_xml_clob              CLOB;
    begin
        v_xml_clob := jc_scandata_msgs_gen.jc_scnd_msg_manifest_trlr( v_tc_shipment_id, v_session_id );
        wms_jc_scandata_req_resp_updt.updt_trlr_manifest_request( v_xml_clob, to_number( substr(v_tc_shipment_id,3,8)) );
    exception
       when jc_exception_pkg.assertion_failure_exception then
          rollback;
          raise;
       when no_data_found  then
          null;
       when others then 
          rollback;
          v_code := SQLCODE;
          v_errm := SUBSTR(SQLERRM, 1, 255);
          jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)',
                                    'v_tc_shipment_id : ' || v_tc_shipment_id );   
    end;


end jc_scnadata_itgl_msgs_gen;
/
