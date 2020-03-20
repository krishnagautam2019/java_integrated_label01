CREATE OR REPLACE package jc_scandata_actions as

    
    procedure create_ship_unit_on_success (
                          v_tc_lpn_id       in      varchar2
                        , v_ship_via        in      varchar2
                        , v_tracking_nbr    in      varchar2
                        , v_label_url       in      varchar2 );


    procedure cancel_ship_unit_on_success (
                          v_tc_lpn_id       in      varchar2 );


end;
/


CREATE OR REPLACE package body jc_scandata_actions as

    
    procedure create_ship_unit_on_success (
                          v_tc_lpn_id       in      varchar2
                        , v_ship_via        in      varchar2
                        , v_tracking_nbr    in      varchar2
                        , v_label_url       in      varchar2 ) as
                pragma autonomous_transaction;
                        
        v_code  VARCHAR2(10);
        v_errm  VARCHAR2(256);
        
        v_scandata_docs_id      c_scandata_docs.c_scandata_docs_id%type := 0;
    begin
        SELECT nvl( max( t1.c_scandata_docs_id ), 0 )     max_c_scandata_docs_id
          into v_scandata_docs_id
          FROM c_scandata_docs  t1
         where t1.doc_type      = 1
           and t1.object_id     = v_tc_lpn_id;
        
        if ( ( v_tc_lpn_id is not null ) AND ( v_label_url is not null ) ) then   
            if v_scandata_docs_id > 0 then
                
                update c_scandata_docs  t1
                   set t1.ship_via      = v_ship_via
                        , t1.doc_url    = v_label_url
                        , t1.last_updated_dttm  = sysdate
                 where t1.c_scandata_docs_id    = v_scandata_docs_id;
                
                commit;
            else
                Insert into c_scandata_docs ( 
                      c_scandata_docs_id
                    , object_id
                    , ship_via
                    , doc_type
                    , doc_url
                    , print_count
                    , stat_code
                    , created_dttm
                    , last_updated_dttm
                    , last_updated_source ) 
                values (
                      C_SCANDATA_DOCS_ID_SEQ.nextval
                    , v_tc_lpn_id
                    , v_ship_via
                    , '1'
                    , v_label_url
                    , 1
                    , 2
                    , systimestamp
                    , systimestamp
                    , '327048' );
                    
                commit;
            end if;
        end if;
        
        if nvl( v_tracking_nbr, '0' ) <> '0' then
            update lpn l1
               set l1.tracking_nbr  = v_tracking_nbr
             where l1.tc_lpn_id     = v_tc_lpn_id
               and l1.lpn_type      = 1
               and l1.inbound_outbound_indicator    = 'O';
            
            commit;
        end if;

    exception
       when jc_exception_pkg.assertion_failure_exception then
          rollback;
          raise;
       when others then 
          rollback;
          v_code := SQLCODE;
          v_errm := SUBSTR(SQLERRM, 1, 255);
          jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)'
                                                    , 'v_tc_lpn_id : ' || v_tc_lpn_id );        
    end;


    procedure cancel_ship_unit_on_success (
                          v_tc_lpn_id       in      varchar2 ) as
                pragma autonomous_transaction;
                        
        v_code  VARCHAR2(10);
        v_errm  VARCHAR2(256);
        
        v_scandata_docs_id      c_scandata_docs.c_scandata_docs_id%type := 0;
    begin
        
        if ( v_tc_lpn_id is not null )  then   
            delete from c_scandata_docs csd
             where csd.doc_type         = '1'
               and csd.object_id        = v_tc_lpn_id;
            
            update lpn l1
               set l1.tracking_nbr  = null
             where l1.tc_lpn_id     = v_tc_lpn_id
               and l1.lpn_type      = 1
               and l1.inbound_outbound_indicator    = 'O';
            
            commit;
        end if;
        
    exception
       when jc_exception_pkg.assertion_failure_exception then
          rollback;
          raise;
       when others then 
          rollback;
          v_code := SQLCODE;
          v_errm := SUBSTR(SQLERRM, 1, 255);
          jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)'
                                                    , 'v_tc_lpn_id : ' || v_tc_lpn_id );        
    end;


end;
/
