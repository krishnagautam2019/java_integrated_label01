CREATE OR REPLACE PACKAGE jc_shipment_history_maint AS

    PROCEDURE jsh_update                    (   v_tc_shipment_id        wms_shipment.tc_shipment_id%type    default null );

    
    PROCEDURE jsh_insert_new                (   v_tc_shipment_id        wms_shipment.tc_shipment_id%type    default null );
    

    PROCEDURE jsh_updt_cancelled_shipments  (   v_tc_shipment_id        wms_shipment.tc_shipment_id%type    default null );


    PROCEDURE jsh_updt_open_shipments       (   v_tc_shipment_id        wms_shipment.tc_shipment_id%type    default null );


    PROCEDURE jsh_chng_status_to_closed     (   v_tc_shipment_id        wms_shipment.tc_shipment_id%type    default null );
    

    PROCEDURE jsh_updt_closed_shipments     (   v_tc_shipment_id        wms_shipment.tc_shipment_id%type    default null );
    

    PROCEDURE jsh_chng_status_to_invoiced   (   v_tc_shipment_id        wms_shipment.tc_shipment_id%type    default null );
    
    
    PROCEDURE jsh_updt_invoiced_not_verified(   v_tc_shipment_id        wms_shipment.tc_shipment_id%type    default null );
    
    
    PROCEDURE jsh_final_shipment_data_updt  (   v_tc_shipment_id        wms_shipment.tc_shipment_id%type    default null );
    
    
    PROCEDURE jsh_shipment_insert           (   v_tc_shipment_id        wms_shipment.tc_shipment_id%type
                                              , v_shipment_status       wms_shipment.shipment_status%type );
    
    
    PROCEDURE jsh_updt_shp_hdr_stat         (   v_tc_shipment_id        wms_shipment.tc_shipment_id%type );
    

    PROCEDURE jsh_updt_stat_invoiced        (   v_tc_shipment_id        wms_shipment.tc_shipment_id%type );
    
    
    PROCEDURE jsh_mark_shipment_invoiced    (   v_tc_shipment_id        wms_shipment.tc_shipment_id%type
                                              , v_invoiced_dttm         date default null );
    

    PROCEDURE jsh_ifee_msg_lpn_ref_missing  (   v_message_id            ifee_tran_log.message_id%type DEFAULT NULL );
    
    
    PROCEDURE jsh_ifee_msg_lpn_check        (   v_tc_shipment_id        wms_shipment.tc_shipment_id%type );


    PROCEDURE jsh_ifee_msg_po_ref_missing   (   v_message_id            ifee_tran_log.message_id%type DEFAULT NULL );


    PROCEDURE jsh_ifee_msg_po_check         (   v_tc_shipment_id        wms_shipment.tc_shipment_id%type );
    
    
    PROCEDURE jsh_updt_ship_invoice_dttm    (   v_tc_shipment_id        wms_shipment.tc_shipment_id%type );


END jc_shipment_history_maint;
/


CREATE OR REPLACE PACKAGE BODY jc_shipment_history_maint AS


    PROCEDURE jsh_update                    (   v_tc_shipment_id        wms_shipment.tc_shipment_id%type    default null ) as
        v_code  VARCHAR2(10);
        v_errm  VARCHAR2(256);  

        v_retcode integer := 0;        
    BEGIN
    
        v_retcode := jc_proc_lock.get_lock( 'jsh_update', '1', 3600 );

        IF v_retcode = 0 THEN
            raise_application_error( -20000, 'jsh_update is already running' );
        else
            
            begin
                jsh_insert_new              ( v_tc_shipment_id );
                jsh_updt_cancelled_shipments( v_tc_shipment_id );
                jsh_updt_open_shipments     ( v_tc_shipment_id );
                jsh_chng_status_to_closed   ( v_tc_shipment_id );
                jsh_updt_closed_shipments   ( v_tc_shipment_id );
                jsh_chng_status_to_invoiced ( v_tc_shipment_id );
                jsh_updt_invoiced_not_verified  ( v_tc_shipment_id );
                jsh_final_shipment_data_updt    ( v_tc_shipment_id );
            exception
               when jc_exception_pkg.assertion_failure_exception then
                  rollback;
                  --raise;
               when others then 
                  rollback;
                  v_retcode := jc_proc_lock.release_lock( 'jsh_update', '1', v_retcode );
                  v_code := SQLCODE;
                  v_errm := SUBSTR(SQLERRM, 1, 255);
                  jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)',
                                            'tc_shipment_id : ' || v_tc_shipment_id );
            end;
            
            --release the lock for the shipm,ent history maint
            v_retcode := jc_proc_lock.release_lock( 'jsh_update', '1', v_retcode );    
            
            begin  
                jc_pcs_export.pcs_export_data_kickoff;
                --jc_pcs_export.queue_shipment( v_tc_shipment_id );
            exception
                when others then
                    v_code := SQLCODE;
                    v_errm := SUBSTR(SQLERRM, 1, 255);
                    jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)' );
            end;
            
        END IF;
        
        
        
    END jsh_update;


    PROCEDURE jsh_insert_new                (   v_tc_shipment_id        wms_shipment.tc_shipment_id%type    default null ) as
        v_code  VARCHAR2(10);
        v_errm  VARCHAR2(256);
        
        v_tc_shipment_id1       wms_shipment.tc_shipment_id%type := v_tc_shipment_id;
    BEGIN
    
        for shipment_list in (
            SELECT s.tc_shipment_id
                    , s.shipment_status
              FROM wms_shipment     s
             where s.tc_shipment_id = nvl( v_tc_shipment_id, s.tc_shipment_id )
               and NOT EXISTS ( SELECT 1 
                                  FROM jc_shipment_history jsh
                                 WHERE jsh.tc_shipment_id  = s.tc_shipment_id ) )
        loop
            v_tc_shipment_id1 := shipment_list.tc_shipment_id;
            
            begin
                jsh_shipment_insert ( shipment_list.tc_shipment_id, shipment_list.shipment_status );
            exception
               when jc_exception_pkg.assertion_failure_exception then
                  rollback;
                  --raise;
               when others then 
                  rollback;
                  v_code := SQLCODE;
                  v_errm := SUBSTR(SQLERRM, 1, 255);
                  jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)',
                                            'tc_shipment_id : ' || v_tc_shipment_id1 );
            end;
            
        end loop;
    exception
       when jc_exception_pkg.assertion_failure_exception then
          rollback;
          --raise;
       when others then 
          rollback;
          v_code := SQLCODE;
          v_errm := SUBSTR(SQLERRM, 1, 255);
          jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)',
                                    'tc_shipment_id : ' || v_tc_shipment_id1 );        
    END jsh_insert_new;


    PROCEDURE jsh_updt_cancelled_shipments  (   v_tc_shipment_id        wms_shipment.tc_shipment_id%type    default null ) as
        v_code  VARCHAR2(10);
        v_errm  VARCHAR2(256); 
        
        v_tc_shipment_id1       wms_shipment.tc_shipment_id%type := v_tc_shipment_id;
    begin
        for shipment_list in (
            SELECT s.tc_shipment_id
                    , s.shipment_status
              FROM jc_shipment_history  jsh
              join wms_shipment         s
                on s.tc_shipment_id     = jsh.tc_shipment_id
               --and s.shipment_status    = jsh.shipment_status 
             where jsh.tc_shipment_id   = nvl( v_tc_shipment_id, jsh.tc_shipment_id )
               and jsh.shipment_status  < 85
               and s.shipment_status    = 120 )
        loop
            v_tc_shipment_id1 := shipment_list.tc_shipment_id;
            
            begin
                delete from jc_shipment_history where tc_shipment_id = shipment_list.tc_shipment_id;
                commit;
                
                jsh_shipment_insert ( shipment_list.tc_shipment_id, shipment_list.shipment_status );
            exception
               when jc_exception_pkg.assertion_failure_exception then
                  rollback;
                  --raise;
               when others then 
                  rollback;
                  v_code := SQLCODE;
                  v_errm := SUBSTR(SQLERRM, 1, 255);
                  jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)',
                                            'tc_shipment_id : ' || v_tc_shipment_id1 );
            end;
            
        end loop;
    exception
       when jc_exception_pkg.assertion_failure_exception then
          rollback;
          --raise;
       when others then 
          rollback;
          v_code := SQLCODE;
          v_errm := SUBSTR(SQLERRM, 1, 255);
          jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)',
                                    'tc_shipment_id : ' || v_tc_shipment_id1 );        
    end jsh_updt_cancelled_shipments;
    
    
    PROCEDURE jsh_updt_open_shipments       (   v_tc_shipment_id        wms_shipment.tc_shipment_id%type    default null ) as
        v_code  VARCHAR2(10);
        v_errm  VARCHAR2(256);
        
        v_tc_shipment_id1       wms_shipment.tc_shipment_id%type := v_tc_shipment_id;
    begin
        for shipment_list in (
            SELECT s.tc_shipment_id
                    , s.shipment_status
              FROM jc_shipment_history  jsh
              join wms_shipment         s
                on s.tc_shipment_id     = jsh.tc_shipment_id
               --and s.shipment_status    = jsh.shipment_status 
             where jsh.tc_shipment_id   = nvl( v_tc_shipment_id, jsh.tc_shipment_id )
               and jsh.shipment_status  = 60
               and s.shipment_status    = 60
               and jsh.last_updated_dttm < ( sysdate - INTERVAL '4' HOUR ) )
        loop
            v_tc_shipment_id1 := shipment_list.tc_shipment_id;
            
            begin
                delete from jc_shipment_history where tc_shipment_id = shipment_list.tc_shipment_id;
                commit;
                
                jsh_shipment_insert ( shipment_list.tc_shipment_id, shipment_list.shipment_status );
            exception
               when jc_exception_pkg.assertion_failure_exception then
                  rollback;
                  --raise;
               when others then 
                  rollback;
                  v_code := SQLCODE;
                  v_errm := SUBSTR(SQLERRM, 1, 255);
                  jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)',
                                            'tc_shipment_id : ' || v_tc_shipment_id1 );
            end;
            
        end loop;
    exception
       when jc_exception_pkg.assertion_failure_exception then
          rollback;
          --raise;
       when others then 
          rollback;
          v_code := SQLCODE;
          v_errm := SUBSTR(SQLERRM, 1, 255);
          jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)',
                                    'tc_shipment_id : ' || v_tc_shipment_id1 );        
    end jsh_updt_open_shipments;    
    

    PROCEDURE jsh_chng_status_to_closed     (   v_tc_shipment_id        wms_shipment.tc_shipment_id%type    default null ) as
        v_code  VARCHAR2(10);
        v_errm  VARCHAR2(256);
        
        v_tc_shipment_id1       wms_shipment.tc_shipment_id%type := v_tc_shipment_id;
    begin
        for shipment_list in (
            SELECT s.tc_shipment_id
                    , s.shipment_status
              FROM jc_shipment_history  jsh
              join wms_shipment         s
                on s.tc_shipment_id     = jsh.tc_shipment_id
               --and s.shipment_status    = jsh.shipment_status 
             where jsh.tc_shipment_id   = nvl( v_tc_shipment_id, jsh.tc_shipment_id )
               and jsh.shipment_status  = 60
               and s.shipment_status    = 80 )
        loop
            v_tc_shipment_id1 := shipment_list.tc_shipment_id;
            
            begin
                delete from jc_shipment_history where tc_shipment_id = shipment_list.tc_shipment_id;
                commit;
                
                jsh_shipment_insert ( shipment_list.tc_shipment_id, shipment_list.shipment_status );
                
                --send data for this shipment to pcs
                jc_pcs_export.queue_shipment_on_close( shipment_list.tc_shipment_id );
            exception
               when jc_exception_pkg.assertion_failure_exception then
                  rollback;
                  --raise;
               when others then 
                  rollback;
                  v_code := SQLCODE;
                  v_errm := SUBSTR(SQLERRM, 1, 255);
                  jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)',
                                            'tc_shipment_id : ' || v_tc_shipment_id1 );
            end;
            
        end loop;
    exception
       when jc_exception_pkg.assertion_failure_exception then
          rollback;
          --raise;
       when others then 
          rollback;
          v_code := SQLCODE;
          v_errm := SUBSTR(SQLERRM, 1, 255);
          jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)',
                                    'tc_shipment_id : ' || v_tc_shipment_id1 );        
    end jsh_chng_status_to_closed;
    

    PROCEDURE jsh_updt_closed_shipments     (   v_tc_shipment_id        wms_shipment.tc_shipment_id%type    default null )  as
        v_code  VARCHAR2(10);
        v_errm  VARCHAR2(256);
        
        v_tc_shipment_id1       wms_shipment.tc_shipment_id%type := v_tc_shipment_id;
    begin
        for shipment_list in (
            SELECT s.tc_shipment_id
                    , s.shipment_status
              FROM jc_shipment_history  jsh
              join wms_shipment         s
                on s.tc_shipment_id     = jsh.tc_shipment_id
               --and s.shipment_status    = jsh.shipment_status 
             where jsh.tc_shipment_id   = nvl( v_tc_shipment_id, jsh.tc_shipment_id )
               and jsh.shipment_status  = 80
               and s.shipment_status    = 80
               and jsh.last_updated_dttm < ( sysdate - INTERVAL '4' HOUR )
               and not exists (
                    select 1
                      from wms_outpt_lpn ol
                     where ol.tc_shipment_id = s.tc_shipment_id ) )
        loop
            v_tc_shipment_id1 := shipment_list.tc_shipment_id;
            
            begin
                delete from jc_shipment_history where tc_shipment_id = shipment_list.tc_shipment_id;
                commit;
                
                jsh_shipment_insert ( shipment_list.tc_shipment_id, shipment_list.shipment_status );
            exception
               when jc_exception_pkg.assertion_failure_exception then
                  rollback;
                  --raise;
               when others then 
                  rollback;
                  v_code := SQLCODE;
                  v_errm := SUBSTR(SQLERRM, 1, 255);
                  jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)',
                                            'tc_shipment_id : ' || v_tc_shipment_id1 );
            end;
            
        end loop;
    exception
       when jc_exception_pkg.assertion_failure_exception then
          rollback;
          --raise;
       when others then 
          rollback;
          v_code := SQLCODE;
          v_errm := SUBSTR(SQLERRM, 1, 255);
          jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)',
                                    'tc_shipment_id : ' || v_tc_shipment_id1 );        
    end jsh_updt_closed_shipments;
    

    PROCEDURE jsh_chng_status_to_invoiced   (   v_tc_shipment_id        wms_shipment.tc_shipment_id%type    default null )  as
        v_code  VARCHAR2(10);
        v_errm  VARCHAR2(256);
        
        v_tc_shipment_id1       wms_shipment.tc_shipment_id%type := v_tc_shipment_id;
    begin
        for shipment_list in (
            SELECT s.tc_shipment_id
                    , s.shipment_status
              FROM jc_shipment_history  jsh
              join wms_shipment         s
                on s.tc_shipment_id     = jsh.tc_shipment_id
               --and s.shipment_status    = jsh.shipment_status 
             where jsh.tc_shipment_id   = nvl( v_tc_shipment_id, jsh.tc_shipment_id )
               and jsh.shipment_status  = 80
               and s.shipment_status    = 80
               and exists (
                    select 1
                      from wms_outpt_lpn ol
                     where ol.tc_shipment_id = s.tc_shipment_id ) )
        loop
            v_tc_shipment_id1 := shipment_list.tc_shipment_id;
            
            begin
                delete from jc_shipment_history where tc_shipment_id = shipment_list.tc_shipment_id;
                commit;
                
                jsh_shipment_insert ( shipment_list.tc_shipment_id, shipment_list.shipment_status );
                jsh_mark_shipment_invoiced ( shipment_list.tc_shipment_id );
    
                --send data for this shipment to pcs
                jc_pcs_export.queue_shipment_on_invoice( shipment_list.tc_shipment_id );            
            exception
               when jc_exception_pkg.assertion_failure_exception then
                  rollback;
                  --raise;
               when others then 
                  rollback;
                  v_code := SQLCODE;
                  v_errm := SUBSTR(SQLERRM, 1, 255);
                  jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)',
                                            'tc_shipment_id : ' || v_tc_shipment_id1 );
            end;            
        end loop;
    exception
       when jc_exception_pkg.assertion_failure_exception then
          rollback;
          --raise;
       when others then 
          rollback;
          v_code := SQLCODE;
          v_errm := SUBSTR(SQLERRM, 1, 255);
          jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)',
                                    'tc_shipment_id : ' || v_tc_shipment_id1 );        
    end jsh_chng_status_to_invoiced;


    PROCEDURE jsh_updt_invoiced_not_verified(   v_tc_shipment_id        wms_shipment.tc_shipment_id%type    default null )  as
        v_code  VARCHAR2(10);
        v_errm  VARCHAR2(256);
        
        v_tc_shipment_id1       wms_shipment.tc_shipment_id%type := v_tc_shipment_id;
    begin
        for shipment_list in (
            SELECT s.tc_shipment_id
                    , s.shipment_status
                    , jsh.shipment_status   jsh_status
              FROM jc_shipment_history  jsh
              join wms_shipment         s
                on s.tc_shipment_id     = jsh.tc_shipment_id
               --and s.shipment_status    = jsh.shipment_status 
             where jsh.tc_shipment_id   = nvl( v_tc_shipment_id, jsh.tc_shipment_id )
               and jsh.shipment_status  in ( 81, 82, 83, 84 )
               and s.shipment_status    = 80 )
        loop
            v_tc_shipment_id1 := shipment_list.tc_shipment_id;
            
            begin
                if shipment_list.jsh_status in ( 81, 82 ) then
                    jsh_ifee_msg_lpn_check  ( shipment_list.tc_shipment_id );
                    jsh_ifee_msg_po_check   ( shipment_list.tc_shipment_id );
                elsif shipment_list.jsh_status in ( 83, 84 ) then
                    jsh_ifee_msg_po_check   ( shipment_list.tc_shipment_id );
                end if;
            exception
               when jc_exception_pkg.assertion_failure_exception then
                  rollback;
                  --raise;
               when others then 
                  rollback;
                  v_code := SQLCODE;
                  v_errm := SUBSTR(SQLERRM, 1, 255);
                  jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)',
                                            'tc_shipment_id : ' || v_tc_shipment_id1 );
            end;                
        end loop;
    exception
       when jc_exception_pkg.assertion_failure_exception then
          rollback;
          raise;
       when others then 
          rollback;
          v_code := SQLCODE;
          v_errm := SUBSTR(SQLERRM, 1, 255);
          jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)',
                                    'tc_shipment_id : ' || v_tc_shipment_id1 );        
    end jsh_updt_invoiced_not_verified;


    PROCEDURE jsh_final_shipment_data_updt  (   v_tc_shipment_id        wms_shipment.tc_shipment_id%type    default null ) as 
        v_code  VARCHAR2(10);
        v_errm  VARCHAR2(256);
        
        v_tc_shipment_id1       wms_shipment.tc_shipment_id%type := v_tc_shipment_id;
    begin
        for shipment_list in (
                select jsh.tc_shipment_id
                  from jc_shipment_history      jsh
                 where jsh.shipment_status      = 85
                   and jsh.last_updated_dttm    < ( sysdate - INTERVAL '1' DAY )
                   and jsh.invoice_date         > ( sysdate - INTERVAL '3' DAY )
                   and to_char( sysdate, 'HH24' ) = '01' )  --make sure it runs at midnight only
        loop
            v_tc_shipment_id1 := shipment_list.tc_shipment_id;
                
            begin
                jsh_updt_shp_hdr_stat ( shipment_list.tc_shipment_id );
                jsh_updt_stat_invoiced( shipment_list.tc_shipment_id );
            exception
               when jc_exception_pkg.assertion_failure_exception then
                  rollback;
                  --raise;
               when others then 
                  rollback;
                  v_code := SQLCODE;
                  v_errm := SUBSTR(SQLERRM, 1, 255);
                  jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)',
                                            'tc_shipment_id : ' || v_tc_shipment_id1 );
            end;
        end loop;
    exception
       when jc_exception_pkg.assertion_failure_exception then
          rollback;
          --raise;
       when others then 
          rollback;
          v_code := SQLCODE;
          v_errm := SUBSTR(SQLERRM, 1, 255);
          jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)',
                                    'tc_shipment_id : ' || v_tc_shipment_id1 );        
    end jsh_final_shipment_data_updt;


    PROCEDURE jsh_shipment_insert           (   v_tc_shipment_id        wms_shipment.tc_shipment_id%type
                                              , v_shipment_status       wms_shipment.shipment_status%type ) as 
        v_code  VARCHAR2(10);
        v_errm  VARCHAR2(256);    
    begin
    
        INSERT INTO jc_shipment_history COLUMNS (
                  tc_shipment_id
                , shipment_id
                , shipment_status
                , bol
                , trailer_number
                , carrier
                , ship_via
                , destination
                , invoice_verified
                , last_updated_dttm )
        SELECT    sh.tc_shipment_id
                , sh.shipment_id
                , sh.shipment_status
                , sh.bill_of_lading_number
                , sh.trailer_number
                , nvl( sh.dsg_carrier_code, sh.assigned_carrier_code )
                , sh.assigned_ship_via
                , sh.d_facility_id
                , 'N'
                , sysdate
          FROM wms_shipment         sh
         WHERE sh.tc_shipment_id    = v_tc_shipment_id
           AND NOT EXISTS ( SELECT 1 
                              FROM jc_shipment_history jsh
                             WHERE jsh.tc_shipment_id  = sh.tc_shipment_id );
                             
        update jc_shipment_history  jsh
           set ( jsh.business_partner_id, jsh.route_alias_id )
                = ( select   decode( is_valid_business_partner_id( sh.lane_name )
                                        , 'Y', sh.lane_name
                                        , jsr.business_partner_id )
                           , jsr.route 
                      from wms_shipment         sh
                      join msf_static_route     sr
                        on sr.static_route_id   = sh.static_route_id
                      join jc_ship_route_alias  jsr
                        on jsr.route            = sr.route_alias_id
                     where sh.tc_shipment_id    = jsh.tc_shipment_id )
         where jsh.tc_shipment_id   = v_tc_shipment_id;                             
                             
        update jc_shipment_history jsh
           set ( jsh.cartons, jsh.weight, jsh.quantity )
                = ( select    COUNT(DISTINCT l.lpn_id)                                          cartons
                            , SUM( jib.quantity_dtl * jib.UNIT_WEIGHT_dtl * ld.size_value )    weight
                            , SUM( jib.quantity_dtl * ld.size_value )                          quantity
                      from wms_lpn              l 
                      JOIN wms_lpn_detail       ld 
                        ON ld.lpn_id            = l.lpn_id
                       AND l.inbound_outbound_indicator = 'O'
                       AND l.lpn_facility_status in (50,90)
                      JOIN jc_item_bom          jib
                        ON jib.item_id_hdr      = ld.item_id
                     where l.tc_shipment_id     = jsh.tc_shipment_id )
         where jsh.tc_shipment_id   = v_tc_shipment_id;

        update jc_shipment_history jsh
           set ( jsh.nominal_qty )
                = ( select sum ( ld.size_value )           quantity
                      from wms_lpn              l 
                      JOIN wms_lpn_detail       ld 
                        ON ld.lpn_id            = l.lpn_id
                       AND l.inbound_outbound_indicator = 'O'
                       AND l.lpn_facility_status in ( 50, 90 )
                     where l.tc_shipment_id     = jsh.tc_shipment_id )
         where jsh.tc_shipment_id   = v_tc_shipment_id;
        
        if v_shipment_status = 80 then  
            update jc_shipment_history jsh
               set ( jsh.close_date_first, jsh.close_date_last )
                    = ( SELECT    min( ptt2.mod_date_time )         close_date_first
                                , max( ptt2.mod_date_time )         close_date_last
                          FROM wms_shipment         sh
                          join wms_prod_trkg_tran   ptt2
                            on ptt2.tran_type       = '800'
                           AND ptt2.tran_code       = '003'
                           AND ptt2.menu_optn_name  = 'RF Close Trailer'
                           AND ptt2.ref_field_1     = sh.tc_shipment_id
                           AND ptt2.whse            = 'ADC'
                           AND ptt2.mod_date_time   > sh.created_dttm
                         WHERE sh.tc_shipment_id    = jsh.tc_shipment_id )
             where jsh.tc_shipment_id   = v_tc_shipment_id;
    
            commit;
        end if;
        
        --jsh_shipment_check_invoiced ( v_tc_shipment_id );

    exception
       when jc_exception_pkg.assertion_failure_exception then
          rollback;
          raise;
       when others then 
          rollback;
          v_code := SQLCODE;
          v_errm := SUBSTR(SQLERRM, 1, 255);
          jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)',
                                    'tc_shipment_id : ' || v_tc_shipment_id );        
    end;  
    
    
    PROCEDURE jsh_updt_stat_invoiced        (   v_tc_shipment_id        wms_shipment.tc_shipment_id%type ) as
        v_code  VARCHAR2(10);
        v_errm  VARCHAR2(256);
        
        v_check VARCHAR2(1) := 'N';
    begin
        update jc_shipment_history jsh
           set ( jsh.cartons, jsh.weight, jsh.quantity )
                = ( select    COUNT(DISTINCT l.lpn_id)                                         cartons
                            , SUM( jib.quantity_dtl * jib.unit_weight_dtl * ld.size_value )    weight
                            , SUM( jib.quantity_dtl * ld.size_value )                          quantity
                      from wms_lpn              l 
                      JOIN wms_lpn_detail       ld 
                        ON ld.lpn_id            = l.lpn_id
                       AND l.inbound_outbound_indicator = 'O'
                       AND l.lpn_facility_status in ( 50, 90 )
                      JOIN jc_item_bom          jib
                        ON jib.item_id_hdr      = ld.item_id
                     where l.tc_shipment_id     = jsh.tc_shipment_id )
         where jsh.tc_shipment_id   = v_tc_shipment_id;

        update jc_shipment_history jsh
           set ( jsh.nominal_qty )
                = ( select sum ( ld.size_value )           quantity
                      from wms_lpn              l 
                      JOIN wms_lpn_detail       ld 
                        ON ld.lpn_id            = l.lpn_id
                       AND l.inbound_outbound_indicator = 'O'
                       AND l.lpn_facility_status in ( 50, 90 )
                     where l.tc_shipment_id     = jsh.tc_shipment_id )
         where jsh.tc_shipment_id   = v_tc_shipment_id;
         
        commit;
        
        select case 
                    when exists ( 
                            select 1
                              from jc_shipment_history  jsh
                             where jsh.tc_shipment_id   = v_tc_shipment_id
                               and jsh.close_date_first is not null )
                        then 'Y'
                        else 'N'
               end rec_exists  
          into v_check
          from dual;
        
        if v_check = 'N' then      
            update jc_shipment_history jsh
               set ( jsh.close_date_first, jsh.close_date_last )
                    = ( SELECT    min( ptt2.mod_date_time )         close_date_first
                                , max( ptt2.mod_date_time )         close_date_last
                          FROM wms_shipment         sh
                          join wms_prod_trkg_tran   ptt2
                            on ptt2.tran_type       = '800'
                           AND ptt2.tran_code       = '003'
                           AND ptt2.menu_optn_name  = 'RF Close Trailer'
                           AND ptt2.ref_field_1     = sh.tc_shipment_id
                           AND ptt2.whse            = 'ADC'
                           AND ptt2.mod_date_time   > sh.created_dttm
                         WHERE sh.tc_shipment_id    = jsh.tc_shipment_id )
             where jsh.tc_shipment_id   = v_tc_shipment_id;
            
            commit;
        else
            update jc_shipment_history jsh
               set ( jsh.close_date_last )
                    = ( SELECT max( ptt2.mod_date_time )            close_date_last
                          FROM wms_shipment         sh
                          join wms_prod_trkg_tran   ptt2
                            on ptt2.tran_type       = '800'
                           AND ptt2.tran_code       = '003'
                           AND ptt2.menu_optn_name  = 'RF Close Trailer'
                           AND ptt2.ref_field_1     = sh.tc_shipment_id
                           AND ptt2.whse            = 'ADC'
                           AND ptt2.mod_date_time   > sh.created_dttm
                         WHERE sh.tc_shipment_id    = jsh.tc_shipment_id )
             where jsh.tc_shipment_id   = v_tc_shipment_id;
            
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
          jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)',
                                    'tc_shipment_id : ' || v_tc_shipment_id);        
    end jsh_updt_stat_invoiced;
    

    PROCEDURE jsh_updt_shp_hdr_stat         (   v_tc_shipment_id        wms_shipment.tc_shipment_id%type ) as
        v_code  VARCHAR2(10);
        v_errm  VARCHAR2(256);
        
        v_check VARCHAR2(1) := 'N';    
    begin
        update jc_shipment_history  jsh
           set (  jsh.bol
                , jsh.trailer_number
                , jsh.carrier
                , jsh.ship_via
                , jsh.destination ) = (
                    select    sh1.bill_of_lading_number
                            , sh1.trailer_number
                            , nvl( sh1.dsg_carrier_code, sh1.assigned_carrier_code )
                            , sh1.assigned_ship_via
                            , sh1.d_facility_id
                      from wms_shipment         sh1 
                     where sh1.tc_shipment_id   = jsh.tc_shipment_id )
         where jsh.tc_shipment_id   = v_tc_shipment_id
           and exists (
                select 1
                  from wms_shipment         sh2 
                 where jsh.tc_shipment_id   = sh2.tc_shipment_id
                   and jsh.bol              <> sh2.bill_of_lading_number
                   and jsh.trailer_number   <> sh2.trailer_number
                   and jsh.carrier          <> nvl( sh2.dsg_carrier_code, sh2.assigned_carrier_code )
                   and jsh.ship_via         <> sh2.assigned_ship_via
                   and jsh.destination      <> sh2.d_facility_id );
        
        commit;
    exception
       when jc_exception_pkg.assertion_failure_exception then
          rollback;
          raise;
       when others then 
          rollback;
          v_code := SQLCODE;
          v_errm := SUBSTR(SQLERRM, 1, 255);
          jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)',
                                    'tc_shipment_id : ' || v_tc_shipment_id);        
    end jsh_updt_shp_hdr_stat;    
    

    PROCEDURE jsh_mark_shipment_invoiced    (   v_tc_shipment_id        wms_shipment.tc_shipment_id%type
                                              , v_invoiced_dttm         date default null ) as
        v_code  VARCHAR2(10);
        v_errm  VARCHAR2(256);
    begin
        update jc_shipment_history  jsh
           set    jsh.shipment_status   = 81
                , jsh.invoice_verified  = 'K'
         where jsh.tc_shipment_id   = v_tc_shipment_id;
        
        commit;
        
        if  v_invoiced_dttm is not null then
            update jc_shipment_history  jsh
               set jsh.invoice_date     = v_invoiced_dttm
             where jsh.tc_shipment_id   = v_tc_shipment_id;
            
            commit;
        else 
            jsh_updt_ship_invoice_dttm ( v_tc_shipment_id );
        end if;
        
        jsh_updt_stat_invoiced  ( v_tc_shipment_id );
        jsh_ifee_msg_lpn_check  ( v_tc_shipment_id );
        jsh_ifee_msg_po_check   ( v_tc_shipment_id );

    exception
       when jc_exception_pkg.assertion_failure_exception then
          rollback;
          raise;
       when others then 
          rollback;
          v_code := SQLCODE;
          v_errm := SUBSTR(SQLERRM, 1, 255);
          jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)',
                                    'tc_shipment_id : ' || v_tc_shipment_id );        
    end jsh_mark_shipment_invoiced;
    
    
    PROCEDURE jsh_ifee_msg_lpn_ref_missing  (   v_message_id            ifee_tran_log.message_id%type DEFAULT NULL ) as
        v_code  VARCHAR2(10);
        v_errm  VARCHAR2(256);
        
        v_reference_id      ifee_tran_log.reference_id%type;
    begin
        for lpn_ref_msgs in (
            select tl.message_id
                    , tl.msg_type
              from ifee_tran_log    tl
             where tl.msg_type      = 'LPNLevelASN'
               and tl.reference_id  IS NULL
               and tl.result_code   = 25
               and tl.message_id    = nvl( v_message_id, tl.message_id ) )
        loop
            begin
                select s.tc_shipment_id
                  into v_reference_id
                  from ifee_tran_log     tl
                        , XMLTABLE( 'tXML/Message/ASN' PASSING XMLTYPE( jc_ifee_tlm_processor.get_tlm_clob ( tl.message_id ) )
                                COLUMNS
                                        tc_shipment_id    VARCHAR2(10)    PATH 'ShipmentID' )        s
                 where tl.message_id        = lpn_ref_msgs.message_id
                   and tl.msg_type          = lpn_ref_msgs.msg_type
                   and rownum               = 1;
                
                ifee_jc_updt_msg_reference_id ( lpn_ref_msgs.message_id, lpn_ref_msgs.msg_type, v_reference_id );
            exception
               when jc_exception_pkg.assertion_failure_exception then
                  rollback;
                  --raise;
               when others then 
                  rollback;
                  ifee_jc_updt_msg_reference_id ( lpn_ref_msgs.message_id, lpn_ref_msgs.msg_type, 'ERROR' );
                  v_code := SQLCODE;
                  v_errm := SUBSTR(SQLERRM, 1, 255);
                  jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)',
                                              'v_message_id : ' || lpn_ref_msgs.message_id || chr(10) ||
                                              'v_reference_id'  || v_reference_id );                 
            end;
            
        end loop;
    exception
       when jc_exception_pkg.assertion_failure_exception then
          rollback;
          raise;
       when others then 
          rollback;
          v_code := SQLCODE;
          v_errm := SUBSTR(SQLERRM, 1, 255);
          jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)',
                                    'v_message_id : ' || v_message_id );        
    end jsh_ifee_msg_lpn_ref_missing;
    
    
    PROCEDURE jsh_ifee_msg_lpn_check        (   v_tc_shipment_id        wms_shipment.tc_shipment_id%type ) as
        v_code  VARCHAR2(10);
        v_errm  VARCHAR2(256);
        
        v_tc_shipment_id2   jc_shipment_history.tc_shipment_id%type;
        
        v_lpn_count         jc_shipment_history.cartons%type := 0;
        v_tot_lpn_count     jc_shipment_history.cartons%type := 0;

        v_lpn_qty           jc_shipment_history.quantity%type := 0;
        v_tot_lpn_qty       jc_shipment_history.quantity%type := 0;       
    begin
        --check if any lpn level asn messages doesnt have reference id
        jsh_ifee_msg_lpn_ref_missing;
        
        for lpnlevelasn_check in (
            select tl.message_id
                    , jsh.invoice_date
              from jc_shipment_history  jsh
              join ifee_tran_log        tl
                on tl.msg_type          = 'LPNLevelASN'
               and tl.reference_id      = jsh.tc_shipment_id
               and tl.created_dttm      > nvl( jsh.invoice_date, jsh.last_updated_dttm )
             where jsh.shipment_status  in (81, 82)
               and jsh.tc_shipment_id   = v_tc_shipment_id )
        loop
            begin
                v_lpn_count := 0;
                v_lpn_qty := 0;
                
                select    s.tc_shipment_id
                        , count( distinct l.tc_lpn_id )     lpn_count
                        , sum( q.shipped_qty )              lpn_qty  
                  into v_tc_shipment_id2
                        , v_lpn_count
                        , v_lpn_qty
                  from ifee_tran_log     tl
                        , XMLTABLE( 'tXML/Message/ASN' PASSING XMLTYPE( jc_ifee_tlm_processor.get_tlm_clob ( tl.message_id ) )
                            COLUMNS
                                  tc_shipment_id    VARCHAR2(10)    PATH 'ShipmentID'
                                , lpns              XMLTYPE         PATH 'LPN' )        s
                        , XMLTABLE( '/LPN'          PASSING         s.lpns
                            COLUMNS
                                  tc_lpn_id         VARCHAR2(30)    PATH 'LPNID'
                                , lpn_detail        XMLTYPE         PATH 'LPNDetail' ) l
                        , XMLTABLE('/LPNDetail'     PASSING         l.lpn_detail
                            COLUMNS
                                --sku             VARCHAR2(20)    PATH 'ItemName'
                                --, po              VARCHAR2(10)    PATH 'PurchaseOrderID'
                                --, po_line_id      VARCHAR2(5)     PATH 'PurchaseOrderLineItemID',
                                shipped_qty         NUMBER(5)       PATH 'LPNDetailQuantity/ShippedAsnQuantity' ) q
                 where tl.msg_type          = 'LPNLevelASN'
                   and tl.message_id        = lpnlevelasn_check.message_id
                   and tl.created_dttm      > lpnlevelasn_check.invoice_date
                   and tl.reference_id      = v_tc_shipment_id
                 group by s.tc_shipment_id;
                 
                v_tot_lpn_count := v_tot_lpn_count + v_lpn_count;
                v_tot_lpn_qty := v_tot_lpn_qty + v_lpn_qty;
                
            exception
               when jc_exception_pkg.assertion_failure_exception then
                  rollback;
                  raise;
               when others then 
                  rollback;
                  v_code := SQLCODE;
                  v_errm := SUBSTR(SQLERRM, 1, 255);
                  jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)',
                                            'tc_shipment_id : ' || v_tc_shipment_id );               
            end;
            
        end loop;
        
        select jsh.cartons
                , jsh.nominal_qty
          into v_lpn_count
                , v_lpn_qty
          from jc_shipment_history  jsh
         where jsh.tc_shipment_id   = v_tc_shipment_id;
         
        if      ( v_tot_lpn_count = v_lpn_count )
            and ( v_tot_lpn_qty   = v_lpn_qty   )   then
            
            update jc_shipment_history      jsh
               set jsh.shipment_status      = 83
                   , jsh.invoice_verified   = 'L'
             where jsh.tc_shipment_id       = v_tc_shipment_id;
            
            commit;
        else 
            update jc_shipment_history      jsh
               set jsh.shipment_status      = 82
                   , jsh.invoice_verified   = 'K'
             where jsh.tc_shipment_id       = v_tc_shipment_id;
            
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
          jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)',
                                    'tc_shipment_id : ' || v_tc_shipment_id );        
    end jsh_ifee_msg_lpn_check;    


    PROCEDURE jsh_ifee_msg_po_ref_missing   (   v_message_id            ifee_tran_log.message_id%type DEFAULT NULL ) as
        v_code  VARCHAR2(10);
        v_errm  VARCHAR2(256);
        
        v_reference_id      ifee_tran_log.reference_id%type;
    begin
        for po_ref_msgs in (
            select tl.message_id
                    , tl.msg_type
                    , tl.result_code
              from ifee_tran_log    tl
             where tl.msg_type      = 'POLevelASN'
               and tl.reference_id  IS NULL
               and tl.is_msg_stored     = 1
               and tl.message_id    = nvl( v_message_id, tl.message_id ) )
        loop
            begin
                select s.tc_shipment_id
                  into v_reference_id
                  from ifee_tran_log     tl
                        , XMLTABLE( 'tXML/Message/ASN' PASSING XMLTYPE( jc_ifee_tlm_processor.get_tlm_clob ( tl.message_id ) )
                                COLUMNS
                                        tc_shipment_id    VARCHAR2(10)    PATH 'ShipmentID' )        s
                 where tl.message_id        = po_ref_msgs.message_id
                   and tl.msg_type          = po_ref_msgs.msg_type
                   and rownum               = 1;
                
                ifee_jc_updt_msg_reference_id ( po_ref_msgs.message_id, po_ref_msgs.msg_type, v_reference_id );
            exception
               when jc_exception_pkg.assertion_failure_exception then
                  rollback;
                  raise;
               when others then 
                  rollback;
                  v_code := SQLCODE;
                  v_errm := SUBSTR(SQLERRM, 1, 255);
                  jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)',
                                            'v_message_id : ' || po_ref_msgs.message_id || chr(10) ||
                                            'result_code  : ' || po_ref_msgs.result_code ) ;                  
            end;
            
        end loop;
        
    exception
       when jc_exception_pkg.assertion_failure_exception then
          rollback;
          raise;
       when others then 
          rollback;
          v_code := SQLCODE;
          v_errm := SUBSTR(SQLERRM, 1, 255);
          jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)',
                                    'v_message_id : ' || v_message_id );        
    end jsh_ifee_msg_po_ref_missing;


    PROCEDURE jsh_ifee_msg_po_check         (   v_tc_shipment_id        wms_shipment.tc_shipment_id%type ) as
        v_code  VARCHAR2(10);
        v_errm  VARCHAR2(256);
        
        v_tc_shipment_id2   jc_shipment_history.tc_shipment_id%type;
        
        v_lpn_count         jc_shipment_history.cartons%type := 0;
        
        v_lpn_qty           jc_shipment_history.quantity%type := 0;
        v_tot_lpn_qty       jc_shipment_history.quantity%type := 0;       
    begin
        --check if any po level asn messages doesnt have reference id
        jsh_ifee_msg_po_ref_missing;
        
        for polevelasn_check in (
            select tl.message_id
                    , jsh.invoice_date
              from jc_shipment_history  jsh
              join ifee_tran_log        tl
                on tl.msg_type          = 'POLevelASN'
               and tl.reference_id      = jsh.tc_shipment_id
               and tl.created_dttm      > nvl( jsh.invoice_date, jsh.last_updated_dttm )
             where jsh.shipment_status  in (83, 84)
               and jsh.tc_shipment_id   = v_tc_shipment_id )
        loop
            begin
                v_lpn_qty := 0;
                
                select    s.tc_shipment_id
                        , sum( q.shipped_qty )              lpn_qty  
                  into v_tc_shipment_id2
                        , v_lpn_qty
                  from ifee_tran_log     tl
                        , XMLTABLE( 'tXML/Message/ASN' PASSING XMLTYPE( jc_ifee_tlm_processor.get_tlm_clob ( tl.message_id ) )
                            COLUMNS
                                  tc_shipment_id    VARCHAR2(10)    PATH 'ShipmentID'
                                , asn_detail        XMLTYPE         PATH 'ASNDetail' ) s
                        , XMLTABLE('/ASNDetail'     PASSING         s.asn_detail
                            COLUMNS
                                shipped_qty         NUMBER(5)       PATH 'Quantity/ShippedQty' ) q
                 where tl.msg_type          = 'POLevelASN'
                   and tl.message_id        = polevelasn_check.message_id
                   and tl.created_dttm      > polevelasn_check.invoice_date
                   and tl.reference_id      = v_tc_shipment_id
                 group by s.tc_shipment_id;
                 
                 v_tot_lpn_qty := v_tot_lpn_qty + v_lpn_qty;
            exception
               when jc_exception_pkg.assertion_failure_exception then
                  rollback;
                  --raise;
               when others then 
                  rollback;
                  v_code := SQLCODE;
                  v_errm := SUBSTR(SQLERRM, 1, 255);
                  jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)',
                                            'tc_shipment_id : ' || polevelasn_check.message_id );               
            end;
            
        end loop;
        
        select jsh.cartons
                , jsh.nominal_qty
          into v_lpn_count
                , v_lpn_qty
          from jc_shipment_history  jsh
         where jsh.tc_shipment_id   = v_tc_shipment_id;
         
        if      ( v_tot_lpn_qty   = v_lpn_qty   )   then
            
            update jc_shipment_history      jsh
               set jsh.shipment_status      = 85
                   , jsh.invoice_verified   = 'Y'
             where jsh.tc_shipment_id       = v_tc_shipment_id;
            
            commit;
        else 
            update jc_shipment_history      jsh
               set jsh.shipment_status      = 84
                   , jsh.invoice_verified   = 'O'
             where jsh.tc_shipment_id       = v_tc_shipment_id;
            
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
          jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)',
                                    'tc_shipment_id : ' || v_tc_shipment_id );        
    end jsh_ifee_msg_po_check;    


    PROCEDURE jsh_updt_ship_invoice_dttm    (   v_tc_shipment_id        wms_shipment.tc_shipment_id%type ) as
        v_code  VARCHAR2(10);
        v_errm  VARCHAR2(256);
        
        v_rec_exists    VARCHAR2(1) := 'N';
    begin
        select case
                    when exists (
                            select 1
                              from wms_lpn l
                             where l.tc_shipment_id     = v_tc_shipment_id
                               and l.lpn_type           = 1
                               and l.inbound_outbound_indicator = 'O'
                               and l.lpn_facility_status= 90 )
                    then 'Y'
                    else 'N'
                end rec_exists
          into v_rec_exists  
          from dual;
    
        if v_rec_exists = 'Y' then
            update jc_shipment_history  jsh
               set jsh.invoice_date     = ( select min( l.shipped_dttm ) 
                                              from wms_lpn l
                                             where l.tc_shipment_id     = v_tc_shipment_id
                                               and l.lpn_type           = 1
                                               and l.inbound_outbound_indicator = 'O'
                                               and l.lpn_facility_status= 90
                                               and l.shipped_dttm       IS NOT NULL )
             where jsh.tc_shipment_id   = v_tc_shipment_id;
            
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
          jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)',
                                    'tc_shipment_id : ' || v_tc_shipment_id);        
    end jsh_updt_ship_invoice_dttm;
    
    
END jc_shipment_history_maint;
/
