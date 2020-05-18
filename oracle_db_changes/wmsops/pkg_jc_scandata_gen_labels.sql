CREATE OR REPLACE package jc_scandata_gen_labels as
    

    function gen_4x2_ppk_for_int_label      ( v_tc_lpn_id       in  varchar2
                                            , v_ship_via        in  varchar2 default null )
            return varchar2;


    function gen_4x2_ppk_for_int_label2     ( v_tc_lpn_id       in  varchar2
                                            , v_ship_via        in  varchar2 default null )
            return varchar2;


    function jc_scnd_gen_err_lbl_generic    ( v_tc_lpn_id       in      varchar2
                                            , v_error_text      in      varchar2 default null )
                return varchar2;


    function jc_scnd_gen_err_lbl_intl       ( v_tc_lpn_id       in      varchar2 )
                return varchar2;


    function jc_scnd_gen_err_lbl_loaded     ( v_tc_lpn_id       in      varchar2 )
                return varchar2;


    function jc_scnd_gen_err_lbl_shipped    ( v_tc_lpn_id       in      varchar2 )
                return varchar2;


end jc_scandata_gen_labels;

/


CREATE OR REPLACE package body jc_scandata_gen_labels as
    

    function gen_4x2_ppk_for_int_label      ( v_tc_lpn_id       in  varchar2
                                            , v_ship_via        in  varchar2 default null )
            return varchar2 as
        v_code          varchar2(10);
        v_errm          varchar2(256);

        v_facility_alias_id     wms_lpn.d_facility_alias_id%type;
        v_tc_reference_lpn_id   wms_lpn.tc_reference_lpn_id%type;
        v_route_alias_id        msf_static_route.route_alias_id%type;
        v_store_carton_zip_brcd varchar2(30);
        v_store_carton_zip_nbr  varchar2(30);

        v_return_str    varchar2(2000);
    begin
        select l1.d_facility_alias_id
               , substr(l1.tc_reference_lpn_id,-4) 
               , sr.route_alias_id
               , (substr(l1.tc_lpn_id,3,3)||substr(l1.tc_lpn_id,3,8)||substr(decode(f2.country_code,'US',f2.postal_code,'11111'),1,5))    
                                                                    c_store_carton_zip_brcd
               , (substr(l1.tc_lpn_id,3,3)||'  '||substr(l1.tc_lpn_id,3,3)||'  '||substr(l1.tc_lpn_id,-5,5)||'  '||substr(decode(f2.country_code,'US',f2.postal_code,'11111'),1,5)) 
                                                                    c_store_carton_zip_nbr
          into    v_facility_alias_id
                , v_tc_reference_lpn_id
                , v_route_alias_id
                , v_store_carton_zip_brcd
                , v_store_carton_zip_nbr
          from wms_lpn                  l1
          join msf_facility             f2
            on f2.facility_id           = l1.d_facility_id
          left join msf_static_route    sr
            on sr.static_route_id       = l1.static_route_id
         where l1.tc_lpn_id             = v_tc_lpn_id;

        if ( v_tc_lpn_id is not null ) then 
            v_return_str := '^FO30,950^BY4,2.5^B2N,171,N,N,N^FD' || v_tc_lpn_id || '^FS^FT30,1142^A0N,23,32^FD' || v_tc_lpn_id || '^FS';
        end if;

        if ( v_tc_reference_lpn_id is not null ) then
            v_return_str := v_return_str ||  '^FO540,950^GB234,84,2^FS^FT570,1015^A0N,68,94^FD' || v_tc_reference_lpn_id || '^FS';
        end if;

        if ( v_route_alias_id is not null ) then
            v_return_str := v_return_str ||  '^FT600,1100^A0N,79,109^FD' || v_route_alias_id || '^FS';
        end if;

        v_return_str := v_return_str || '^FO515,1115^BY2,2.5^B2N,75,N,N,N^FD' || v_store_carton_zip_brcd || '^FS^FT500,1215^A0N,23,32^FD' || v_store_carton_zip_nbr || '^FS^FT80,1210^A0N,79,109^FD' || v_facility_alias_id || '^FS';

        return v_return_str;
    exception
        when no_data_found then
            return null;     
        when jc_exception_pkg.assertion_failure_exception then
            rollback;
            raise;
        when others then 
            rollback;
            v_code := SQLCODE;
            v_errm := SUBSTR(SQLERRM, 1, 255);
            jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)'
                                            , 'v_tc_lpn_id : ' || v_tc_lpn_id || chr(10) ||
                                              'v_ship_via : ' || v_ship_via );
    end gen_4x2_ppk_for_int_label;


    function gen_4x2_ppk_for_int_label2     ( v_tc_lpn_id       in  varchar2
                                            , v_ship_via        in  varchar2 default null )
            return varchar2 as
        v_code          varchar2(10);
        v_errm          varchar2(256);

        v_facility_alias_id     wms_lpn.d_facility_alias_id%type;
        v_tc_reference_lpn_id   wms_lpn.tc_reference_lpn_id%type;
        v_route_alias_id        msf_static_route.route_alias_id%type;
        v_store_carton_zip_brcd varchar2(30);
        v_store_carton_zip_nbr  varchar2(30);

        v_return_str    varchar2(2000);
    begin
        select l1.d_facility_alias_id
               , substr(l1.tc_reference_lpn_id,-4) 
               , sr.route_alias_id
               , (substr(l1.tc_lpn_id,3,3)||substr(l1.tc_lpn_id,3,8)||substr(decode(f2.country_code,'US',f2.postal_code,'11111'),1,5))    c_store_carton_zip_brcd
               , (substr(l1.tc_lpn_id,3,3)||'  '||substr(l1.tc_lpn_id,3,3)||'  '||substr(l1.tc_lpn_id,-5,5)||'  '||substr(decode(f2.country_code,'US',f2.postal_code,'11111'),1,5)) 
                                                                                                                                        c_store_carton_zip_nbr
          into    v_facility_alias_id
                , v_tc_reference_lpn_id
                , v_route_alias_id
                , v_store_carton_zip_brcd
                , v_store_carton_zip_nbr
          from wms_lpn                  l1
          join msf_facility             f2
            on f2.facility_id           = l1.d_facility_id
          left join msf_static_route    sr
            on sr.static_route_id       = l1.static_route_id
         where l1.tc_lpn_id             = v_tc_lpn_id;

        if ( v_tc_lpn_id is not null ) then 
            v_return_str := '^FO20,850^BY4,2.5^B2N,171,N,N,N^FD' || v_tc_lpn_id || '^FS^FT20,1050^A0N,23,32^FD' || v_tc_lpn_id || '^FS';
        end if;

        if ( v_tc_reference_lpn_id is not null ) then
            v_return_str := v_return_str ||  '^FO530,850^GB234,84,2^FS^FT550,915^A0N,68,94^FD' || v_tc_reference_lpn_id || '^FS';
        end if;

        if ( v_route_alias_id is not null ) then
            v_return_str := v_return_str ||  '^FT580,1030^A0N,79,109^FD' || v_route_alias_id || '^FS';
        end if;

        v_return_str := v_return_str || '^FO480,1055^BY2,2.5^B2N,75,N,N,N^FD' || v_store_carton_zip_brcd || '^FS^FT480,1165^A0N,23,32^FD' || v_store_carton_zip_nbr || '^FS^FT70,1160^A0N,79,109^FD' || v_facility_alias_id || '^FS';

        return v_return_str;
    exception
        when no_data_found then
            return null;     
        when jc_exception_pkg.assertion_failure_exception then
            rollback;
            raise;
        when others then 
            rollback;
            v_code := SQLCODE;
            v_errm := SUBSTR(SQLERRM, 1, 255);
            jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)'
                                            , 'v_tc_lpn_id : ' || v_tc_lpn_id || chr(10) ||
                                              'v_ship_via : ' || v_ship_via );
    end gen_4x2_ppk_for_int_label2;


    function jc_scnd_gen_err_lbl_generic    ( v_tc_lpn_id       in      varchar2
                                            , v_error_text      in      varchar2 default null )
                return varchar2 as
        v_code          varchar2(10);
        v_errm          varchar2(256);

        v_data_xml              varchar2(1000);
        v_label                 varchar2(2000);
    begin
        v_data_xml := gen_4x2_ppk_for_int_label2 ( v_tc_lpn_id );

        v_label := '^XA';

        if v_error_text is not null then
            v_label := v_label || '^CF0,60,90^FO100,100^FB600,8,1,^FD' || v_error_text || '^FS';
        end if;

        v_label := v_label || '^FO0020,0820^GB778,003,3,B^FS' || v_data_xml || '^XZ';

        return v_label;

    exception
        when no_data_found then
            return null;     
        when jc_exception_pkg.assertion_failure_exception then
            rollback;
            raise;
        when others then 
            rollback;
            v_code := SQLCODE;
            v_errm := SUBSTR(SQLERRM, 1, 255);
            jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)'
                                            , 'v_tc_lpn_id : ' || v_tc_lpn_id );
    end jc_scnd_gen_err_lbl_generic;


    function jc_scnd_gen_err_lbl_intl       ( v_tc_lpn_id       in      varchar2 )
                return varchar2 as
        v_code          varchar2(10);
        v_errm          varchar2(256);

        v_data_xml              varchar2(1000);
        v_label                 varchar2(2000);
        v_err_msg               varchar2(100) := 'Integrated Label cannot be generated for International Cartons';
    begin
        v_label := jc_scnd_gen_err_lbl_generic( v_tc_lpn_id, v_err_msg );

        return v_label;

    exception
        when no_data_found then
            return null;     
        when jc_exception_pkg.assertion_failure_exception then
            rollback;
            raise;
        when others then 
            rollback;
            v_code := SQLCODE;
            v_errm := SUBSTR(SQLERRM, 1, 255);
            jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)'
                                            , 'v_tc_lpn_id : ' || v_tc_lpn_id );
    end jc_scnd_gen_err_lbl_intl;


    function jc_scnd_gen_err_lbl_loaded     ( v_tc_lpn_id       in      varchar2 )
                return varchar2 as
        v_code          varchar2(10);
        v_errm          varchar2(256);

        v_data_xml              varchar2(1000);
        v_label                 varchar2(2000);
        v_err_msg               varchar2(100) := 'Carton is already loaded without tracking ID; new Integrated Label can''t be generated';
    begin
        v_label := jc_scnd_gen_err_lbl_generic( v_tc_lpn_id, v_err_msg );

        return v_label;

    exception
        when no_data_found then
            return null;     
        when jc_exception_pkg.assertion_failure_exception then
            rollback;
            raise;
        when others then 
            rollback;
            v_code := SQLCODE;
            v_errm := SUBSTR(SQLERRM, 1, 255);
            jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)'
                                            , 'v_tc_lpn_id : ' || v_tc_lpn_id );
    end jc_scnd_gen_err_lbl_loaded;


    function jc_scnd_gen_err_lbl_shipped    ( v_tc_lpn_id       in      varchar2 )
                return varchar2 as
        v_code          varchar2(10);
        v_errm          varchar2(256);

        v_data_xml              varchar2(1000);
        v_label                 varchar2(2000);
        v_err_msg               varchar2(100) := 'Carton is marked shipped without tracking ID; new Integrated Label can''t be generated';
    begin
        v_label := jc_scnd_gen_err_lbl_generic( v_tc_lpn_id, v_err_msg );

        return v_label;

    exception
        when no_data_found then
            return null;     
        when jc_exception_pkg.assertion_failure_exception then
            rollback;
            raise;
        when others then 
            rollback;
            v_code := SQLCODE;
            v_errm := SUBSTR(SQLERRM, 1, 255);
            jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)'
                                            , 'v_tc_lpn_id : ' || v_tc_lpn_id );
    end jc_scnd_gen_err_lbl_shipped;


end jc_scandata_gen_labels;
/
