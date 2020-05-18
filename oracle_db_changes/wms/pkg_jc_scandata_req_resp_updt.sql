CREATE OR REPLACE package jc_scandata_req_resp_updt as


    procedure updt_create_request   (
                                  v_msg             c_scandata_req_resp.message%type
                                , v_session_id      c_scandata_req_resp.session_id%type
                                , v_msg_group_id    c_scandata_req_resp.msg_group_id%type default null );


    procedure updt_create_response   (
                                  v_msg             c_scandata_req_resp.message%type
                                , v_session_id      c_scandata_req_resp.session_id%type
                                , v_msg_group_id    c_scandata_req_resp.msg_group_id%type default null );
                                

    procedure updt_cancel_request   (
                                  v_msg             c_scandata_req_resp.message%type
                                , v_session_id      c_scandata_req_resp.session_id%type
                                , v_msg_group_id    c_scandata_req_resp.msg_group_id%type default null );


    procedure updt_cancel_response   (
                                  v_msg             c_scandata_req_resp.message%type
                                , v_session_id      c_scandata_req_resp.session_id%type
                                , v_msg_group_id    c_scandata_req_resp.msg_group_id%type default null );


    procedure updt_load_ship_request   (
                                  v_msg             c_scandata_req_resp.message%type
                                , v_session_id      c_scandata_req_resp.session_id%type
                                , v_msg_group_id    c_scandata_req_resp.msg_group_id%type default null );


    procedure updt_load_ship_response   (
                                  v_msg             c_scandata_req_resp.message%type
                                , v_session_id      c_scandata_req_resp.session_id%type
                                , v_msg_group_id    c_scandata_req_resp.msg_group_id%type default null );


    procedure updt_trlr_manifest_request   (
                                  v_msg             c_scandata_req_resp.message%type
                                , v_session_id      c_scandata_req_resp.session_id%type
                                , v_msg_group_id    c_scandata_req_resp.msg_group_id%type default null );


    procedure updt_trlr_manifest_response   (
                                  v_msg             c_scandata_req_resp.message%type
                                , v_session_id      c_scandata_req_resp.session_id%type
                                , v_msg_group_id    c_scandata_req_resp.msg_group_id%type default null );


end jc_scandata_req_resp_updt;
/


CREATE OR REPLACE package body jc_scandata_req_resp_updt as


    procedure updt_create_request   (
                                  v_msg             c_scandata_req_resp.message%type
                                , v_session_id      c_scandata_req_resp.session_id%type
                                , v_msg_group_id    c_scandata_req_resp.msg_group_id%type default null ) as
        PRAGMA AUTONOMOUS_TRANSACTION; 
        
        v_msg_group_id2     c_scandata_req_resp.msg_group_id%type := v_msg_group_id;
        v_ins_check         varchar2(1) := 'N';
    begin
    
        v_ins_check := jc_config_pkg.get_jc_config_value ( 'INT_LABEL_MSG_SAVE', 'REQUEST' , 'CREATE SHIP UNITS' );
        
        if v_ins_check = 'Y' then
            if v_msg_group_id2 is null then
                v_msg_group_id2 := C_SCANDATA_MSG_GRP.nextval;
            end if;
            
            Insert into c_scandata_req_resp (
                  c_scandata_req_resp_id
                , message_context
                , msg_group_id
                , session_id
                , msg_type
                , message
                , created_dttm
                , created_source ) 
            values (
                  C_SCANDATA_REQ_RESP_ID_SEQ.nextval
                , 'CREATE SHIP UNITS'
                , v_msg_group_id2
                , v_session_id
                , 'REQUEST'
                , v_msg
                , systimestamp
                , 'WMSOPS' );
            
            commit;
        end if;
    exception
        when others then
            --do nothing
            null;
    end;

    procedure updt_create_response   (
                                  v_msg             c_scandata_req_resp.message%type
                                , v_session_id      c_scandata_req_resp.session_id%type
                                , v_msg_group_id    c_scandata_req_resp.msg_group_id%type default null ) as
        PRAGMA AUTONOMOUS_TRANSACTION; 
        
        v_msg_group_id2     c_scandata_req_resp.msg_group_id%type := v_msg_group_id;
        v_ins_check         varchar2(1) := 'N';
    begin
    
        v_ins_check := jc_config_pkg.get_jc_config_value ( 'INT_LABEL_MSG_SAVE', 'RESPONSE' , 'CREATE SHIP UNITS' );
        
        if v_ins_check = 'Y' then
            if v_msg_group_id2 is null then
                v_msg_group_id2 := C_SCANDATA_MSG_GRP.nextval;
            end if;
            
            Insert into c_scandata_req_resp (
                  c_scandata_req_resp_id
                , message_context
                , msg_group_id
                , session_id
                , msg_type
                , message
                , created_dttm
                , created_source ) 
            values (
                  C_SCANDATA_REQ_RESP_ID_SEQ.nextval
                , 'CREATE SHIP UNITS'
                , v_msg_group_id2
                , v_session_id
                , 'RESPONSE'
                , v_msg
                , systimestamp
                , 'WMSOPS' );
            
            commit;
        end if;
    exception
        when others then
            --do nothing
            null;
    end;


    procedure updt_cancel_request   (
                                  v_msg             c_scandata_req_resp.message%type
                                , v_session_id      c_scandata_req_resp.session_id%type
                                , v_msg_group_id    c_scandata_req_resp.msg_group_id%type default null ) as
        PRAGMA AUTONOMOUS_TRANSACTION; 
        
        v_msg_group_id2     c_scandata_req_resp.msg_group_id%type := v_msg_group_id;
        v_ins_check         varchar2(1) := 'N';
    begin
    
        v_ins_check := jc_config_pkg.get_jc_config_value ( 'INT_LABEL_MSG_SAVE', 'REQUEST' , 'CANCEL SHIP UNITS' );
        
        if v_ins_check = 'Y' then
            if v_msg_group_id2 is null then
                v_msg_group_id2 := C_SCANDATA_MSG_GRP.nextval;
            end if;
            
            Insert into c_scandata_req_resp (
                  c_scandata_req_resp_id
                , message_context
                , msg_group_id
                , session_id
                , msg_type
                , message
                , created_dttm
                , created_source ) 
            values (
                  C_SCANDATA_REQ_RESP_ID_SEQ.nextval
                , 'CANCEL SHIP UNITS'
                , v_msg_group_id2
                , v_session_id
                , 'REQUEST'
                , v_msg
                , systimestamp
                , 'WMSOPS' );
            
            commit;
        end if;
    exception
        when others then
            --do nothing
            null;
    end;


    procedure updt_cancel_response   (
                                  v_msg             c_scandata_req_resp.message%type
                                , v_session_id      c_scandata_req_resp.session_id%type
                                , v_msg_group_id    c_scandata_req_resp.msg_group_id%type default null ) as
        PRAGMA AUTONOMOUS_TRANSACTION; 
        
        v_msg_group_id2     c_scandata_req_resp.msg_group_id%type := v_msg_group_id;
        v_ins_check         varchar2(1) := 'N';
    begin
    
        v_ins_check := jc_config_pkg.get_jc_config_value ( 'INT_LABEL_MSG_SAVE', 'RESPONSE' , 'CANCEL SHIP UNITS' );
        
        if v_ins_check = 'Y' then
            if v_msg_group_id2 is null then
                v_msg_group_id2 := C_SCANDATA_MSG_GRP.nextval;
            end if;
            
            Insert into c_scandata_req_resp (
                  c_scandata_req_resp_id
                , message_context
                , msg_group_id
                , session_id
                , msg_type
                , message
                , created_dttm
                , created_source ) 
            values (
                  C_SCANDATA_REQ_RESP_ID_SEQ.nextval
                , 'CANCEL SHIP UNITS'
                , v_msg_group_id2
                , v_session_id
                , 'RESPONSE'
                , v_msg
                , systimestamp
                , 'WMSOPS' );
            
            commit;
        end if;
    exception
        when others then
            --do nothing
            null;
    end;


    procedure updt_load_ship_request   (
                                  v_msg             c_scandata_req_resp.message%type
                                , v_session_id      c_scandata_req_resp.session_id%type
                                , v_msg_group_id    c_scandata_req_resp.msg_group_id%type default null ) as
        PRAGMA AUTONOMOUS_TRANSACTION; 
        
        v_msg_group_id2     c_scandata_req_resp.msg_group_id%type := v_msg_group_id;
        v_ins_check         varchar2(1) := 'N';
    begin
    
        v_ins_check := jc_config_pkg.get_jc_config_value ( 'INT_LABEL_MSG_SAVE', 'REQUEST' , 'LOAD SHIP UNITS' );
        
        if v_ins_check = 'Y' then
            if v_msg_group_id2 is null then
                v_msg_group_id2 := C_SCANDATA_MSG_GRP.nextval;
            end if;
            
            Insert into c_scandata_req_resp (
                  c_scandata_req_resp_id
                , message_context
                , msg_group_id
                , session_id
                , msg_type
                , message
                , created_dttm
                , created_source ) 
            values (
                  C_SCANDATA_REQ_RESP_ID_SEQ.nextval
                , 'LOAD SHIP UNITS'
                , v_msg_group_id2
                , v_session_id
                , 'REQUEST'
                , v_msg
                , systimestamp
                , 'WMSOPS' );
            
            commit;
        end if;
    exception
        when others then
            --do nothing
            null;
    end;


    procedure updt_load_ship_response   (
                                  v_msg             c_scandata_req_resp.message%type
                                , v_session_id      c_scandata_req_resp.session_id%type
                                , v_msg_group_id    c_scandata_req_resp.msg_group_id%type default null ) as
        PRAGMA AUTONOMOUS_TRANSACTION; 
        
        v_msg_group_id2     c_scandata_req_resp.msg_group_id%type := v_msg_group_id;
        v_ins_check         varchar2(1) := 'N';
    begin
    
        v_ins_check := jc_config_pkg.get_jc_config_value ( 'INT_LABEL_MSG_SAVE', 'RESPONSE' , 'LOAD SHIP UNITS' );
        
        if v_ins_check = 'Y' then
            if v_msg_group_id2 is null then
                v_msg_group_id2 := C_SCANDATA_MSG_GRP.nextval;
            end if;
            
            Insert into c_scandata_req_resp (
                  c_scandata_req_resp_id
                , message_context
                , msg_group_id
                , session_id
                , msg_type
                , message
                , created_dttm
                , created_source ) 
            values (
                  C_SCANDATA_REQ_RESP_ID_SEQ.nextval
                , 'LOAD SHIP UNITS'
                , v_msg_group_id2
                , v_session_id
                , 'RESPONSE'
                , v_msg
                , systimestamp
                , 'WMSOPS' );
            
            commit;
        end if;
    exception
        when others then
            --do nothing
            null;
    end;


    procedure updt_trlr_manifest_request   (
                                  v_msg             c_scandata_req_resp.message%type
                                , v_session_id      c_scandata_req_resp.session_id%type
                                , v_msg_group_id    c_scandata_req_resp.msg_group_id%type default null ) as
        PRAGMA AUTONOMOUS_TRANSACTION; 
        
        v_msg_group_id2     c_scandata_req_resp.msg_group_id%type := v_msg_group_id;
        v_ins_check         varchar2(1) := 'N';
    begin
    
        v_ins_check := jc_config_pkg.get_jc_config_value ( 'INT_LABEL_MSG_SAVE', 'REQUEST' , 'MANIFEST TRAILER' );
        
        if v_ins_check = 'Y' then
            if v_msg_group_id2 is null then
                v_msg_group_id2 := C_SCANDATA_MSG_GRP.nextval;
            end if;
            
            Insert into c_scandata_req_resp (
                  c_scandata_req_resp_id
                , message_context
                , msg_group_id
                , session_id
                , msg_type
                , message
                , created_dttm
                , created_source ) 
            values (
                  C_SCANDATA_REQ_RESP_ID_SEQ.nextval
                , 'MANIFEST TRAILER'
                , v_msg_group_id2
                , v_session_id
                , 'REQUEST'
                , v_msg
                , systimestamp
                , 'WMSOPS' );
            
            commit;
        end if;
    exception
        when others then
            --do nothing
            null;
    end;


    procedure updt_trlr_manifest_response   (
                                  v_msg             c_scandata_req_resp.message%type
                                , v_session_id      c_scandata_req_resp.session_id%type
                                , v_msg_group_id    c_scandata_req_resp.msg_group_id%type default null ) as
        PRAGMA AUTONOMOUS_TRANSACTION; 
        
        v_msg_group_id2     c_scandata_req_resp.msg_group_id%type := v_msg_group_id;
        v_ins_check         varchar2(1) := 'N';
    begin
    
        v_ins_check := jc_config_pkg.get_jc_config_value ( 'INT_LABEL_MSG_SAVE', 'RESPONSE' , 'MANIFEST TRAILER' );
        
        if v_ins_check = 'Y' then
            if v_msg_group_id2 is null then
                v_msg_group_id2 := C_SCANDATA_MSG_GRP.nextval;
            end if;
            
            Insert into c_scandata_req_resp (
                  c_scandata_req_resp_id
                , message_context
                , msg_group_id
                , session_id
                , msg_type
                , message
                , created_dttm
                , created_source ) 
            values (
                  C_SCANDATA_REQ_RESP_ID_SEQ.nextval
                , 'MANIFEST TRAILER'
                , v_msg_group_id2
                , v_session_id
                , 'RESPONSE'
                , v_msg
                , systimestamp
                , 'WMSOPS' );
            
            commit;
        end if;
    exception
        when others then
            --do nothing
            null;
    end;


end jc_scandata_req_resp_updt;
/
