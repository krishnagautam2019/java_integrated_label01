CREATE OR REPLACE package jc_scandata_utils as


    function get_label_url_for_carton   ( v_tc_lpn_id       in  varchar2 )
            return varchar2;
            
            
    function get_invoiced_carton_count  ( v_tc_shipment_id  in  varchar2 )
            return integer;
            

    function get_ship_via_for_carton    ( v_tc_lpn_id       in  varchar2 )
            return varchar2;


end jc_scandata_utils;
/


CREATE OR REPLACE package body jc_scandata_utils as


    function get_label_url_for_carton   ( v_tc_lpn_id       in  varchar2 )
            return varchar2 as

        v_code      VARCHAR2(10);
        v_errm      VARCHAR2(256);
        
        v_label     wms_c_scandata_docs.doc_url%type := '0';
        v_scandata_docs_id  wms_c_scandata_docs.c_scandata_docs_id%type;
    begin
        begin
            select nvl( max( t1.c_scandata_docs_id ),  0 )      max_scandata_docs_id
              into v_scandata_docs_id
              from wms_c_scandata_docs  t1
             where t1.doc_type          = '1'
               and t1.stat_code         < 99
               and t1.object_id         = v_tc_lpn_id;
               
            if v_scandata_docs_id > 0 then
                select t1.doc_url
                  into v_label
                  from wms_c_scandata_docs      t1
                 where t1.c_scandata_docs_id    = v_scandata_docs_id; 
                
                return v_label;
            else
                select coalesce( l1.tracking_nbr, l1.tc_lpn_id, '0' )
                  into v_label  
                  from wms_lpn  l1
                 where l1.tc_lpn_id     = v_tc_lpn_id
                   and l1.lpn_type      = 1
                   and l1.inbound_outbound_indicator = 'O'; 
                
                return v_label;
            end if;
        exception
            when others then
                return '0';
        end;
        
        return v_label;
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
    end get_label_url_for_carton;


    function get_invoiced_carton_count  ( v_tc_shipment_id  in  varchar2 )
            return integer as

        v_code      VARCHAR2(10);
        v_errm      VARCHAR2(256);
        
        v_lpn_count integer := -10;
    begin
        select case when not exists (
                            select 1
                              from wms_shipment         sh
                             where sh.tc_shipment_id    = v_tc_shipment_id )
                    then -8
                    else -7
                end shipment_exists
          into v_lpn_count
          from dual;
        
        --get the count invoiced cartons
        if v_lpn_count = -7 then
            select sum( l1.tc_lpn_id )
              into v_lpn_count
              from wms_lpn              l1
             where l1.tc_shipment_id    = v_tc_shipment_id
               and l1.lpn_type          = 1
               and l1.inbound_outbound_indicator    = 'O'
               and l1.lpn_facility_status           = 90;
        else
            return v_lpn_count;
        end if;
        
        --check if the carton are only loaded
        if v_lpn_count > 0 then
            return v_lpn_count;
        else 
            select sum( l1.tc_lpn_id )
              into v_lpn_count
              from wms_lpn              l1
             where l1.tc_shipment_id    = v_tc_shipment_id
               and l1.lpn_type          = 1
               and l1.inbound_outbound_indicator    = 'O'
               and l1.lpn_facility_status           = 50;        
        end if;

        --check if any cartons are assigned 
        if v_lpn_count > 0 then
            return -6;
        else 
            select sum( l1.tc_lpn_id )
              into v_lpn_count
              from wms_lpn             l1
             where l1.tc_shipment_id    = v_tc_shipment_id
               and l1.lpn_type          = 1
               and l1.inbound_outbound_indicator    = 'O';        
        end if;

        --check if any cartons are loaded 
        if v_lpn_count > 0 then
            return -5;
        end if;

        return v_lpn_count;
        
    exception
       when jc_exception_pkg.assertion_failure_exception then
          rollback;
          raise;
       when others then 
          rollback;
          v_code := SQLCODE;
          v_errm := SUBSTR(SQLERRM, 1, 255);
          jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)'
                                            , 'v_tc_shipment_id : ' || v_tc_shipment_id );
    end get_invoiced_carton_count;


    function get_ship_via_for_carton    ( v_tc_lpn_id       in  varchar2 )
            return varchar2 as
        v_code      varchar2(10);
        v_errm      varchar2(256);
        
        v_ship_via              wms_lpn.ship_via%type;
        v_facility_alias_id     wms_lpn.d_facility_alias_id%type;
        v_lpn_facility_status   wms_lpn.lpn_facility_status%type;
        v_site                  wms_lpn.misc_instr_code_5%type;
        
        v_carrier_code          msf_carrier_code.carrier_code%type;
        
        v_return_value          wms_lpn.ship_via%type := 'DFLT';
        v_rec_exists            varchar2(1) := 'N';
    begin

        --step 1: get the current assigned ship via to the carton
        /*SYS.dbms_output.put_line ( 'Step 01' ||
                                   ', v_tc_lpn_id : '           || lpad(v_tc_lpn_id,10) ||
                                   ', v_facility_alias_id : '   || lpad(v_facility_alias_id,6) ||
                                   ', v_lpn_facility_status : ' || lpad(v_lpn_facility_status,2) ||
                                   ', v_site : '                || lpad(v_site,2) ||
                                   ', v_carrier_code : '        || lpad(v_carrier_code,6) ||
                                   ', v_ship_via : '            || lpad(v_ship_via,4) ||
                                   ', v_return_value : '        || lpad(v_return_value,4) ); */

        begin
            select    l1.ship_via
                    , l1.d_facility_alias_id
                    , l1.lpn_facility_status
                    , decode( l1.misc_instr_code_5
                                    , 'DF', 'AV'
                                    , 'AV', 'AV'
                                    , 'GE', 'GE'
                                    , 'GW', 'GW'
                                    , 'AV' )
              into    v_ship_via
                    , v_facility_alias_id
                    , v_lpn_facility_status
                    , v_site
              from wms_lpn          l1
             where l1.lpn_type      = 1             --this is a carton and not a pallet
               and l1.inbound_outbound_indicator = 'O'
               and l1.tc_lpn_id     = v_tc_lpn_id;
        exception
            when no_data_found then
                --very likely because carton doesn't exist
                v_return_value := 'ERRR';
                return v_return_value;
        end;


        --step 2: if the carton is alread loaded or shipped return special values
        /*SYS.dbms_output.put_line ( 'Step 02' ||
                                   ', v_tc_lpn_id : '           || lpad(v_tc_lpn_id,10) ||
                                   ', v_facility_alias_id : '   || lpad(v_facility_alias_id,6) ||
                                   ', v_lpn_facility_status : ' || lpad(v_lpn_facility_status,2) ||
                                   ', v_site : '                 || lpad(v_site,2) ||
                                   ', v_carrier_code : '        || lpad(v_carrier_code,6) ||
                                   ', v_ship_via : '            || lpad(v_ship_via,4) ||
                                   ', v_return_value : '        || lpad(v_return_value,4) ); */

        if ( v_lpn_facility_status  = 50 ) then
            v_return_value := 'LOAD';
            return v_return_value;
        elsif ( v_lpn_facility_status  = 90 ) then
            v_return_value := 'SHPD';
            return v_return_value;
        elsif ( ( v_lpn_facility_status > 51 ) and ( v_lpn_facility_status not in ( 50, 90 ) ) ) then
            v_return_value := 'ERRR';
            return v_return_value;
        end if;

        --step 3: if currently assigned to UPS or Fedex ship via then thats it
        /*SYS.dbms_output.put_line ( 'Step 03' ||
                                   ', v_tc_lpn_id : '           || lpad(v_tc_lpn_id,10) ||
                                   ', v_facility_alias_id : '   || lpad(v_facility_alias_id,6) ||
                                   ', v_lpn_facility_status : ' || lpad(v_lpn_facility_status,2) ||
                                   ', v_site : '                || lpad(v_site,2) ||
                                   ', v_carrier_code : '        || lpad(v_carrier_code,6) ||
                                   ', v_ship_via : '            || lpad(v_ship_via,4) ||
                                   ', v_return_value : '        || lpad(v_return_value,4) ); */
                                   
        if ( v_ship_via is not null ) then
            select    cc.carrier_code
                    --, sv.ship_via
              into v_carrier_code
              from msf_carrier_code                 cc
              JOIN msf_tp_company_service_level     csl
                ON csl.carrier_id                   = cc.carrier_id
              JOIN msf_service_level                sl
                ON sl.service_level_id              = csl.service_level_id
              JOIN msf_ship_via                     sv
                ON sv.carrier_id                    = csl.carrier_id
               AND sv.service_level_id              = csl.service_level_id 
             where sv.ship_via                      = v_ship_via;

            if ( nvl( v_carrier_code, '1' ) in ( 'UPS' ) ) then
                v_return_value := v_ship_via;
                return v_return_value;
            end if;
        else
            v_ship_via := 'DFLT';
        end if;


        --step 4: so its not a original ups ship via; so 
        --whats the alternative ship via
        /*SYS.dbms_output.put_line ( 'Step 04' ||
                                   ', v_tc_lpn_id : '           || lpad(v_tc_lpn_id,10) ||
                                   ', v_facility_alias_id : '   || lpad(v_facility_alias_id,6) ||
                                   ', v_lpn_facility_status : ' || lpad(v_lpn_facility_status,2) ||
                                   ', v_site : '                || lpad(v_site,2) ||
                                   ', v_carrier_code : '        || lpad(v_carrier_code,6) ||
                                   ', v_ship_via : '            || lpad(v_ship_via,4) ||
                                   ', v_return_value : '        || lpad(v_return_value,4) ); */     
                                   
        select case when exists (
                            select svc1.alt_ship_via
                              from jc_scandata_alt_ship_via    svc1
                             where svc1.ship_via               = v_ship_via
                               and svc1.site                   = v_site
                               and svc1.carrier_code           = 'UPS' )
                    then 'Y'
                    else 'N'
                end rec_exists
          into v_rec_exists
          from dual;
        
        /*SYS.dbms_output.put_line ( 'Step 04, v_rec_exists : ' || v_rec_exists );  */
        if ( v_rec_exists = 'Y' ) then
            select svc1.alt_ship_via
              into v_return_value
              from jc_scandata_alt_ship_via    svc1
             where svc1.ship_via               = v_ship_via
               and svc1.site                   = v_site
               and svc1.carrier_code           = 'UPS';
        end if;

        --step 5. does the store have a override for the ups service level assigned
        /*SYS.dbms_output.put_line ( 'Step 05' ||
                                   ', v_tc_lpn_id : '           || lpad(v_tc_lpn_id,10) ||
                                   ', v_facility_alias_id : '   || lpad(v_facility_alias_id,6) ||
                                   ', v_lpn_facility_status : ' || lpad(v_lpn_facility_status,2) ||
                                   ', v_site : '                || lpad(v_site,2) ||
                                   ', v_carrier_code : '        || lpad(v_carrier_code,6) ||
                                   ', v_ship_via : '            || lpad(v_ship_via,4) ||
                                   ', v_return_value : '        || lpad(v_return_value,4) ); */

        select case when exists (
                            select ssv.alt_ship_via
                              from jc_scandata_store_ship_via   ssv
                             where ssv.facility_alias_id        = v_facility_alias_id
                               and ssv.site                     = v_site
                               and ssv.carrier_code             = 'UPS' )
                    then 'Y'
                    else 'N'
                 end rec_exists
          into v_rec_exists
          from dual;
        
        /*SYS.dbms_output.put_line ( 'Step 05, v_rec_exists : ' || v_rec_exists ); */
        if ( v_rec_exists = 'Y' ) then
            select ssv.alt_ship_via
              into v_return_value 
              from jc_scandata_store_ship_via   ssv
             where ssv.facility_alias_id        = v_facility_alias_id
               and ssv.site                     = v_site
               and ssv.carrier_code             = 'UPS'; 
        end if;
        
        return nvl( v_return_value, 'DFLT' );
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
    end get_ship_via_for_carton;

    
end jc_scandata_utils;
/
