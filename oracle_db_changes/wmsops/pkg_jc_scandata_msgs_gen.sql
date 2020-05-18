CREATE OR REPLACE package jc_scandata_msgs_gen as
    
    
    function parse_lpn_list (
                  p_delimstring     IN      VARCHAR2
                , p_delim           IN      VARCHAR2 DEFAULT ',' )
            return number;
    
    /*generally do not use*/
    function jc_scnd_msg_create_ship ( 
                                  v_tc_lpn_id       in      varchar2
                                , v_session_id      in      number      default null )
                return clob;


    --copy of the function to get the xml for alternate ship via
    function jc_scnd_msg_create_ship_via ( 
                                  v_tc_lpn_id       in      varchar2
                                , v_ship_via        in      varchar2    default null
                                , v_session_id      in      number      default null )
                return clob;


    function jc_scnd_msg_create_ship_plt ( 
                                  v_tc_lpn_id       in      varchar2
                                , v_session_id      in      number      default null )
                return clob;


    function jc_scnd_msg_create_ship_intl ( 
                                  v_tc_lpn_id       in      varchar2
                                , v_session_id      in      number      default null )
                return clob;


    function jc_scnd_msg_get_ship_label ( 
                                  v_tc_lpn_id       in      varchar2 
                                , v_session_id      in      number      default null )
                return clob;


    function jc_scnd_msg_cancel_ship ( 
                                  v_tc_lpn_id       in      varchar2
                                , v_session_id      in      number      default null ) 
                return clob;


    function jc_scnd_msg_load_ship ( 
                                  v_tc_shipment_id  in      varchar2
                                , v_part_num        in      number
                                , v_session_id      in      number      default null ) 
                return clob;

    
    function jc_scnd_msg_carton_dtls    (
                                  v_tc_lpn_id       in      varchar2 )
                return clob;
                

    function jc_scnd_msg_manifest_trlr  ( 
                                  v_tc_shipment_id  in      varchar2 
                                , v_session_id      in      number      default null ) 
                return clob;

/*    
    function rank_load_cartons (  v_tc_shipment_id  in      varchar2 )
                return integer;
*/

    function get_session_id_when_null  (    
                                  v_session_id      in      number      default null ) 
                return number;


end jc_scandata_msgs_gen;
/


CREATE OR REPLACE package body jc_scandata_msgs_gen as


    function parse_lpn_list(
                  p_delimstring     IN      VARCHAR2
                , p_delim           IN      VARCHAR2 DEFAULT ',' )
            return number 
    IS
        v_string    VARCHAR2(3000) := p_delimstring;
        v_nfields   PLS_INTEGER := 1;
        v_delimpos  PLS_INTEGER := INSTR(p_delimstring, p_delim);
        v_delimlen  PLS_INTEGER := LENGTH(p_delim);

        v_session_key   number(6,0) := 0;
    BEGIN
        DBMS_RANDOM.SEED( to_char(sysdate,'YYYYMMDDHH24MI') );
        v_session_key := ceil( DBMS_RANDOM.value ( 100001, 999999 ) );   

        WHILE v_delimpos > 0
        LOOP
            insert into jc_scandata_temp_lpn_list( tc_lpn_id, session_key ) values( SUBSTR(v_string,1,v_delimpos-1), v_session_key );
            v_string := SUBSTR(v_string,v_delimpos+v_delimlen);

            IF ( nvl(length(v_string),0) > 0 ) THEN
                v_nfields := v_nfields+1;
            END IF;

            v_delimpos := INSTR(v_string, p_delim);
            --dbms_output.put_line(v_table(v_nfields));
        END LOOP;

        IF ( nvl(length(v_string),0) > 0 ) THEN
            insert into jc_scandata_temp_lpn_list( tc_lpn_id, session_key ) values( v_string, v_session_key );
        END IF;

        return v_session_key;

    END parse_lpn_list;

    
    /*generally do not use*/
    function jc_scnd_msg_create_ship ( 
                                  v_tc_lpn_id       in      varchar2
                                , v_session_id      in      number      default null ) 
                return clob as
        v_code      VARCHAR2(10);
        v_errm      VARCHAR2(256); 

        v_xml_clob              CLOB;
        v_check_multilpn        number;
        v_session_id2           number;
        v_ship_via              varchar2(4);
    begin

        --check if its a  pallet or a carton
        v_check_multilpn := instr( v_tc_lpn_id , ',' );

        --get the session_id if its null
        if ( v_session_id is null ) then
            v_session_id2 := get_session_id_when_null( v_session_id );
        else
            v_session_id2 := v_session_id;
        end if;

        if v_check_multilpn <= 0 then
            select nvl( l2.ship_via, 'DFLT' )
              into v_ship_via
              from wms_lpn l2
             where l2.tc_lpn_id = v_tc_lpn_id; 
            
            if ( v_ship_via in ( 'UTST','UTSA','UCEX','UCST' ) ) then
                v_xml_clob := jc_scnd_msg_create_ship_intl ( v_tc_lpn_id );
            else
                SELECT  XMLSERIALIZE( CONTENT
                            XMLElement( "env:Envelope"
                                , XMLATTRIBUTES( 
                                      'http://schemas.xmlsoap.org/soap/envelope/'                       AS "xmlns:env"     
                                    , 'http://ScanData.com/WTM/'                                        AS "xmlns:wtm" )
                                , XMLConcat(
                                      XMLElement( "env:Header" )
                                    , XMLElement( "env:Body"
                                        , XMLElement( "wtm:CreateShipUnits"
                                            , XMLATTRIBUTES( 
                                                  'http://ScanData.com/WTM/'                            AS "xmlns:wtm" )
                                            , XMLConcat ( 
                                                  XMLElement( "wtm:SessionID"
                                                    , XMLATTRIBUTES( 
                                                          'http://ScanData.com/WTM/'                    AS "xmlns:wtm" )
                                                    , nvl( v_session_id, get_session_id_when_null( v_session_id ) ) )
                                                , XMLElement( "wtm:CreateShipUnitsParams"
                                                    , XMLATTRIBUTES( 
                                                          'http://ScanData.com/WTM/'                    AS "xmlns:wtm" )
                                                    , XMLElement( "CREATE_SHIP_UNITS_PARAMS"
                                                        , XMLATTRIBUTES( 
                                                              '1'                                                               AS "MSN"     
                                                            , 'http://ScanData.com/WTM/XMLSchemas/WTM_XMLSchema_14.00.0000.xsd' AS "xmlns" )
                                                        , XMLElement( "SHIP_UNIT"
                                                            , XMLConcat(
                                                                  XMLElement( "CartonNumber", t1.tc_lpn_id )
                                                                , XMLElement( "DistributionCenter", t1.o_facility_alias_id )
                                                                , XMLElement( "OrderNumber", t1.order_id ) 
                                                                , XMLElement( "Quantity", t2.carton_units ) 
                                                                , XMLElement( "EstimatedWeight", t1.estimated_weight ) 
                                                                , XMLElement( "BillingAccountID", 'ADC' ) 
                                                                , XMLElement( "Status", 'LABELED' ) 
                                                                , XMLElement( "ShipVia", t2.ship_via ) 
                                                                , XMLElement( "Weight", t1.weight )
                                                                , ( select  XMLElement( "ADDRESS"
                                                                                , XMLConcat( 
                                                                                      XMLElement( "Class", 'DELIVER_TO' )
                                                                                    , XMLElement( "AddressCode", t1.d_facility_alias_id )
                                                                                    , XMLElement( "CompanyName", nvl( t5.ship_contact, 'JCREW ' || t1.d_facility_alias_id ) )
                                                                                    , XMLElement( "IndividualName",  nvl( t5.facility_name, t3.facility_name ) )
                                                                                    , XMLElement( "StreetAddress",  nvl( t5.ship_address_1, t4.address_1 ) )
                                                                                    , XMLElement( "Address1",  nvl( t5.ship_address_2, t4.address_2 ) )
                                                                                    , XMLElement( "Address2",  nvl( t5.ship_address_3, t4.address_3 ) )
                                                                                    , XMLElement( "City",  nvl( t5.ship_city, t4.city ) )
                                                                                    , XMLElement( "State",  nvl( t5.ship_state_prov, t4.state_prov ) )
                                                                                    , XMLElement( "ZIPCode",  nvl( t5.ship_postal_code, t4.postal_code ) )
                                                                                    , XMLElement( "Country",  decode( nvl( t5.ship_country_code, t4.country_code )
                                                                                                                    , 'US', 'UNITED STATES'
                                                                                                                    , 'CA', 'CANADA'
                                                                                                                    , 'UNITED STATES' ) )
                                                                                    , XMLElement( "PhoneNumber",  nvl( t5.ship_postal_code, t4.postal_code ) )
                                                                                ) )
                                                                      from msf_facility_alias   t3
                                                                      join msf_facility         t4
                                                                        on t4.facility_id       = t3.facility_id
                                                                      left join jc_stores       t5
                                                                        on t5.facility_alias_id = t3.facility_alias_id
                                                                     where t3.facility_alias_id = t1.d_facility_alias_id )   
        
                                                                ) )
                                                        , XMLElement( "LabelOutputFileType", 'Buffer' ) ) ) ) ) ) )
                            ) AS CLOB ) c1
                  INTO v_xml_clob
                  FROM wms_lpn      t1
                  join jc_cartons   t2
                    on t2.tc_lpn_id = t1.tc_lpn_id
                 where t1.tc_lpn_id = v_tc_lpn_id ;
            end if;
            
        --if its a multilpn parameter then
        else
            v_xml_clob := jc_scnd_msg_create_ship_plt ( v_tc_lpn_id, v_session_id );
        end if;

        return v_xml_clob;

    exception
       when jc_exception_pkg.assertion_failure_exception then
          rollback;
          raise;
       when others then 
          rollback;
          v_code := SQLCODE;
          v_errm := SUBSTR(SQLERRM, 1, 255);
          jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)',
                                    'v_tc_lpn_id : ' || v_tc_lpn_id );         
    end jc_scnd_msg_create_ship; 


    function jc_scnd_msg_create_ship_via ( 
                                  v_tc_lpn_id       in      varchar2
                                , v_ship_via        in      varchar2    default null
                                , v_session_id      in      number      default null )
                return clob as
        v_code      varchar2(10);
        v_errm      varchar2(256);

        v_xml_clob              clob;
        v_session_id2           number;

        v_data_xml              varchar2(1000);

        v_ship_via2             wms_lpn.ship_via%type := v_ship_via;
    begin
        --get the session_id if its null
        if ( v_session_id is null ) then
            v_session_id2 := get_session_id_when_null( v_session_id );
        else
            v_session_id2 := v_session_id;
        end if;

        --if ship_via is null
        if ( v_ship_via2 is null ) then
            v_ship_via2 := jc_scandata_utils.get_ship_via_for_carton ( v_tc_lpn_id );
        end if;
        
        if ( v_ship_via in ( 'UTST','UTSA','UCEX','UCST' ) ) then 
            v_xml_clob := jc_scnd_msg_create_ship_intl( v_tc_lpn_id );
        else
            v_data_xml := jc_scandata_gen_labels.gen_4x2_ppk_for_int_label2 ( v_tc_lpn_id, v_ship_via );
    
            SELECT  XMLSERIALIZE( CONTENT
                        XMLElement( "env:Envelope"
                            , XMLATTRIBUTES( 
                                  'http://schemas.xmlsoap.org/soap/envelope/'                       AS "xmlns:env"     
                                , 'http://ScanData.com/WTM/'                                        AS "xmlns:wtm" )
                            , XMLConcat(
                                  XMLElement( "env:Header" )
                                , XMLElement( "env:Body"
                                    , XMLElement( "wtm:CreateShipUnits"
                                        , XMLATTRIBUTES( 
                                              'http://ScanData.com/WTM/'                            AS "xmlns:wtm" )
                                        , XMLConcat ( 
                                              XMLElement( "wtm:SessionID"
                                                , XMLATTRIBUTES( 
                                                      'http://ScanData.com/WTM/'                    AS "xmlns:wtm" )
                                                , nvl( v_session_id, get_session_id_when_null( v_session_id ) ) )
                                            , XMLElement( "wtm:CreateShipUnitsParams"
                                                , XMLATTRIBUTES( 
                                                      'http://ScanData.com/WTM/'                    AS "xmlns:wtm" )
                                                , XMLElement( "CREATE_SHIP_UNITS_PARAMS"
                                                    , XMLATTRIBUTES( 
                                                          '1'                                                               AS "MSN"     
                                                        , 'http://ScanData.com/WTM/XMLSchemas/WTM_XMLSchema_14.00.0000.xsd' AS "xmlns" )
                                                    , XMLElement( "SHIP_UNIT"
                                                        , XMLConcat(
                                                              XMLElement( "CartonNumber", t1.tc_lpn_id )
                                                            , XMLElement( "DistributionCenter", t1.o_facility_alias_id )
                                                            , XMLElement( "OrderNumber", t1.order_id ) 
                                                            , XMLElement( "Quantity", t2.carton_units ) 
                                                            , XMLElement( "EstimatedWeight", t1.estimated_weight ) 
                                                            , XMLElement( "BillingAccountID", 'ADC' ) 
                                                            , XMLElement( "Status", 'LABELED' ) 
                                                            , XMLElement( "ShipVia", nvl( v_ship_via2, t2.ship_via ) ) 
                                                            , XMLElement( "Weight", t1.weight )
                                                            , decode( v_data_xml
                                                                            , null, null
                                                                            , XMLElement ( "DataXML"
                                                                                , XMLElement ( "Label4By2", v_data_xml ) ) )
                                                            , ( select  XMLElement( "ADDRESS"
                                                                            , XMLConcat( 
                                                                                  XMLElement( "Class", 'DELIVER_TO' )
                                                                                , XMLElement( "AddressCode", t1.d_facility_alias_id )
                                                                                , XMLElement( "CompanyName", nvl( t5.ship_contact, 'JCREW ' || t1.d_facility_alias_id ) )
                                                                                , XMLElement( "IndividualName",  nvl( t5.facility_name, t3.facility_name ) )
                                                                                , XMLElement( "StreetAddress",  nvl( t5.ship_address_1, t4.address_1 ) )
                                                                                , XMLElement( "Address1",  nvl( t5.ship_address_2, t4.address_2 ) )
                                                                                , XMLElement( "Address2",  nvl( t5.ship_address_3, t4.address_3 ) )
                                                                                , XMLElement( "City",  nvl( t5.ship_city, t4.city ) )
                                                                                , XMLElement( "State",  nvl( t5.ship_state_prov, t4.state_prov ) )
                                                                                , XMLElement( "ZIPCode",  nvl( t5.ship_postal_code, t4.postal_code ) )
                                                                                , XMLElement( "Country",  decode( nvl( t5.ship_country_code, t4.country_code )
                                                                                                                , 'US', 'UNITED STATES'
                                                                                                                , 'CA', 'CANADA'
                                                                                                                , 'UNITED STATES' ) )
                                                                                , XMLElement( "PhoneNumber",  nvl( t5.ship_postal_code, t4.postal_code ) )
                                                                            ) )
                                                                  from msf_facility_alias   t3
                                                                  join msf_facility         t4
                                                                    on t4.facility_id       = t3.facility_id
                                                                  left join jc_stores       t5
                                                                    on t5.facility_alias_id = t3.facility_alias_id
                                                                 where t3.facility_alias_id = t1.d_facility_alias_id )   
    
                                                            ) )
                                                    , XMLElement( "LabelOutputFileType", 'Buffer' ) ) ) ) ) ) )
                        ) AS CLOB ) c1
              INTO v_xml_clob
              FROM wms_lpn      t1
              join jc_cartons   t2
                on t2.tc_lpn_id = t1.tc_lpn_id
             where t1.tc_lpn_id = v_tc_lpn_id ;
        end if;
        
        return v_xml_clob;
    exception
       when jc_exception_pkg.assertion_failure_exception then
          rollback;
          raise;
       when others then 
          rollback;
          v_code := SQLCODE;
          v_errm := SUBSTR(SQLERRM, 1, 255);
          jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)',
                                    'v_tc_lpn_id : '    || v_tc_lpn_id  || chr(10) ||
                                    'v_ship_via : '     || v_ship_via   || chr(10) ||
                                    'v_session_id : '   || v_session_id );             
    end;


    function jc_scnd_msg_create_ship_plt ( 
                                  v_tc_lpn_id       in      varchar2
                                , v_session_id      in      number      default null )
                return clob as
        v_code      varchar2(10);
        v_errm      varchar2(256);  
        
        v_session_key       number(6,0) := 0;
        v_xml_clob          clob;
    begin
        v_session_key := parse_lpn_list( v_tc_lpn_id, ',' );

            SELECT  XMLSERIALIZE( CONTENT
                        XMLElement( "env:Envelope"
                            , XMLATTRIBUTES( 
                                  'http://schemas.xmlsoap.org/soap/envelope/'                       AS "xmlns:env"     
                                , 'http://ScanData.com/WTM/'                                        AS "xmlns:wtm" )
                            , XMLConcat(
                                  XMLElement( "env:Header" )
                                , XMLElement( "env:Body"
                                    , XMLElement( "wtm:CreateShipUnits"
                                        , XMLATTRIBUTES( 
                                              'http://ScanData.com/WTM/'                            AS "xmlns:wtm" )
                                        , XMLConcat ( 
                                              XMLElement( "wtm:SessionID"
                                                , XMLATTRIBUTES( 
                                                      'http://ScanData.com/WTM/'                    AS "xmlns:wtm" )
                                                , nvl( v_session_id, get_session_id_when_null( v_session_id ) ) )
                                            , XMLElement( "wtm:CreateShipUnitsParams"
                                                , XMLATTRIBUTES( 
                                                      'http://ScanData.com/WTM/'                    AS "xmlns:wtm" )
                                                , XMLElement( "CREATE_SHIP_UNITS_PARAMS"
                                                    , XMLATTRIBUTES( 
                                                          '1'                                                               AS "MSN"     
                                                        , 'http://ScanData.com/WTM/XMLSchemas/WTM_XMLSchema_14.00.0000.xsd' AS "xmlns" )
                                                    , ( SELECT XMLAGG (
                                                                    XMLElement( "SHIP_UNIT"
                                                                    , XMLConcat(
                                                                          XMLElement( "CartonNumber", t1.tc_lpn_id )
                                                                        , XMLElement( "DistributionCenter", t1.o_facility_alias_id )
                                                                        , XMLElement( "OrderNumber", t1.order_id ) 
                                                                        , XMLElement( "Quantity", t2.carton_units ) 
                                                                        , XMLElement( "EstimatedWeight", t1.estimated_weight ) 
                                                                        , XMLElement( "BillingAccountID", 'ADC' ) 
                                                                        , XMLElement( "Status", 'LABELED' ) 
                                                                        , XMLElement( "ShipVia", t2.ship_via ) 
                                                                        , XMLElement( "Weight", t1.weight )
                                                                        , ( select  XMLElement( "ADDRESS"
                                                                                        , XMLConcat( 
                                                                                              XMLElement( "Class", 'DELIVER_TO' )
                                                                                            , XMLElement( "AddressCode", t1.d_facility_alias_id )
                                                                                            , XMLElement( "CompanyName", nvl( t5.ship_contact, 'JCREW ' || t1.d_facility_alias_id ) )
                                                                                            , XMLElement( "IndividualName",  nvl( t5.facility_name, t3.facility_name ) )
                                                                                            , XMLElement( "StreetAddress",  nvl( t5.ship_address_1, t4.address_1 ) )
                                                                                            , XMLElement( "Address1",  nvl( t5.ship_address_2, t4.address_2 ) )
                                                                                            , XMLElement( "Address2",  nvl( t5.ship_address_3, t4.address_3 ) )
                                                                                            , XMLElement( "City",  nvl( t5.ship_city, t4.city ) )
                                                                                            , XMLElement( "State",  nvl( t5.ship_state_prov, t4.state_prov ) )
                                                                                            , XMLElement( "ZIPCode",  nvl( t5.ship_postal_code, t4.postal_code ) )
                                                                                            , XMLElement( "Country",  decode( nvl( t5.ship_country_code, t4.country_code )
                                                                                                                            , 'US', 'UNITED STATES'
                                                                                                                            , 'CA', 'CANADA'
                                                                                                                            , 'UNITED STATES' ) )
                                                                                            , XMLElement( "PhoneNumber",  nvl( t5.ship_postal_code, t4.postal_code ) )
                                                                                        ) )
                                                                              from msf_facility_alias   t3
                                                                              join msf_facility         t4
                                                                                on t4.facility_id       = t3.facility_id
                                                                              left join jc_stores       t5
                                                                                on t5.facility_alias_id = t3.facility_alias_id
                                                                             where t3.facility_alias_id = t1.d_facility_alias_id )   
                
                                                                        ) ) order by t1.tc_lpn_id )
                                                        from jc_scandata_temp_lpn_list  lpn_list
                                                        join wms_lpn        t1
                                                          on t1.tc_lpn_id   = lpn_list.tc_lpn_id
                                                        join jc_cartons     t2
                                                          on t2.tc_lpn_id   = t1.tc_lpn_id
                                                       where lpn_list.session_key = v_session_key )
                                                , XMLElement( "LabelOutputFileType", 'Buffer' ) ) ) ) ) ) )
                        ) AS CLOB ) c1
              INTO v_xml_clob
              FROM dual;

        /*
        for lpn_list in (
            select t1.tc_lpn_id
              from jc_scandata_temp_lpn_list  t1
             where t1.session_key   = v_session_key )
        loop
            dbms_output.put_line( lpn_list.tc_lpn_id );
        end loop;*/
        
        --dbms_output.put_line( v_xml_clob );
        commit;
        return v_xml_clob;
        
    exception
       when jc_exception_pkg.assertion_failure_exception then
          rollback;
          raise;
       when others then 
          rollback;
          v_code := SQLCODE;
          v_errm := SUBSTR(SQLERRM, 1, 255);
          jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)',
                                    'v_tc_lpn_id : ' || v_tc_lpn_id );         
    end jc_scnd_msg_create_ship_plt;                


    function jc_scnd_msg_create_ship_intl ( 
                                  v_tc_lpn_id       in      varchar2
                                , v_session_id      in      number      default null ) 
                return clob as
        v_code      VARCHAR2(10);
        v_errm      VARCHAR2(256); 

        v_xml_clob              CLOB;
        v_check_multilpn        number;
        v_session_id2           number;
        v_ship_via              varchar2(4);
        v_declared_value        number := 0;
    begin
    
    select SUM(nvl(oli.PRICE,0)*ld.SIZE_VALUE) declared_value
      into v_declared_value
      from wms_lpn          l1
      join wms_lpn_detail   ld
        on ld.lpn_id        = l1.lpn_id
      join wms_order_line_item  oli
        on oli.line_item_id = ld.distribution_order_dtl_id
     where l1.tc_lpn_id     = v_tc_lpn_id;
     
            SELECT  XMLSERIALIZE( CONTENT
                        XMLElement( "env:Envelope"
                            , XMLATTRIBUTES( 
                                  'http://schemas.xmlsoap.org/soap/envelope/'                       AS "xmlns:env"     
                                , 'http://ScanData.com/WTM/'                                        AS "xmlns:wtm" )
                            , XMLConcat(
                                  XMLElement( "env:Header" )
                                , XMLElement( "env:Body"
                                    , XMLElement( "wtm:CreateShipUnits"
                                        , XMLATTRIBUTES( 
                                              'http://ScanData.com/WTM/'                            AS "xmlns:wtm" )
                                        , XMLConcat ( 
                                              XMLElement( "wtm:SessionID"
                                                , XMLATTRIBUTES( 
                                                      'http://ScanData.com/WTM/'                    AS "xmlns:wtm" )
                                                , nvl( v_session_id, get_session_id_when_null( v_session_id ) ) )
                                            , XMLElement( "wtm:CreateShipUnitsParams"
                                                , XMLATTRIBUTES( 
                                                      'http://ScanData.com/WTM/'                    AS "xmlns:wtm" )
                                                , XMLElement( "CREATE_SHIP_UNITS_PARAMS"
                                                    , XMLATTRIBUTES( 
                                                          '1'                                                               AS "MSN"     
                                                        , 'http://ScanData.com/WTM/XMLSchemas/WTM_XMLSchema_14.00.0000.xsd' AS "xmlns" )
                                                    , ( SELECT XMLAGG (
                                                                    XMLElement( "SHIP_UNIT"
                                                                        , XMLConcat(
                                                                              XMLElement( "CartonNumber", t1.tc_lpn_id )
                                                                            , XMLElement( "DistributionCenter", t1.o_facility_alias_id )
                                                                            , XMLElement( "OrderNumber", t1.order_id ) 
                                                                            , XMLElement( "Quantity", t2.carton_units ) 
                                                                            , XMLElement( "EstimatedWeight", t1.estimated_weight ) 
                                                                            , XMLElement( "BillingAccountID", 'ADC' ) 
                                                                            , XMLElement( "Status", 'LABELED' ) 
                                                                            , XMLElement( "OutboundPalletID", t1.tc_parent_lpn_id )
                                                                            , XMLElement( "ShipVia", t2.ship_via ) 
                                                                            , XMLElement( "ShipPointID", t6.shippoint_id ) 
                                                                            , XMLElement( "Weight", t1.weight )
                                                                            , XMLElement( "DeclaredValue", v_declared_value )
                                                                            , ( select  XMLElement( "ADDRESS"
                                                                                            , XMLConcat( 
                                                                                                  XMLElement( "Class", 'DELIVER_TO' )
                                                                                                , XMLElement( "AddressCode", t1.d_facility_alias_id )
                                                                                                , XMLElement( "CompanyName", nvl( t5.ship_contact, 'JCREW ' || t1.d_facility_alias_id ) )
                                                                                                , XMLElement( "IndividualName",  nvl( t5.facility_name, t3.facility_name ) )
                                                                                                , XMLElement( "StreetAddress",  nvl( t5.ship_address_1, t4.address_1 ) )
                                                                                                , XMLElement( "Address1",  nvl( t5.ship_address_2, t4.address_2 ) )
                                                                                                , XMLElement( "Address2",  nvl( t5.ship_address_3, t4.address_3 ) )
                                                                                                , XMLElement( "City",  nvl( t5.ship_city, t4.city ) )
                                                                                                , XMLElement( "State",  nvl( t5.ship_state_prov, t4.state_prov ) )
                                                                                                , XMLElement( "ZIPCode",  nvl( t5.ship_postal_code, t4.postal_code ) )
                                                                                                , XMLElement( "Country",  decode( nvl( t5.ship_country_code, t4.country_code )
                                                                                                                                , 'US', 'UNITED STATES'
                                                                                                                                , 'CA', 'CANADA'
                                                                                                                                , 'UNITED STATES' ) )
                                                                                                , XMLElement( "PhoneNumber",  nvl( t5.ship_postal_code, t4.postal_code ) )
                                                                                            ) )
                                                                                  from msf_facility_alias   t3
                                                                                  join msf_facility         t4
                                                                                    on t4.facility_id       = t3.facility_id
                                                                                  left join jc_stores       t5
                                                                                    on t5.facility_alias_id = t3.facility_alias_id
                                                                                 where t3.facility_alias_id = t1.d_facility_alias_id )   
                                                                            , ( select  XMLElement( "ADDRESS"
                                                                                            , XMLConcat( 
                                                                                                  XMLElement( "Class", 'RETURN' )
                                                                                                --, XMLElement( "AddressCode", nvl(t6.return_store,t1.d_facility_alias_id) )
                                                                                                , XMLElement( "CompanyName", nvl( t3.facility_name, 'JCREW ' || nvl(t6.return_store,t1.d_facility_alias_id) ) )
                                                                                                , XMLElement( "IndividualName",  coalesce( t7.first_name || ' ' || t7.surname, t5.facility_name, t3.facility_name ) )
                                                                                                , XMLElement( "StreetAddress",  coalesce( t5.ship_address_1, t4.address_1 ) )
                                                                                                , XMLElement( "Address1",  coalesce( t5.ship_address_2, t4.address_2 ) )
                                                                                                , XMLElement( "Address2",  coalesce( t5.ship_address_3, t4.address_3 ) )
                                                                                                , XMLElement( "City",  coalesce( t5.ship_city, t4.city ) )
                                                                                                , XMLElement( "State",  coalesce( t5.ship_state_prov, t4.state_prov ) )
                                                                                                , XMLElement( "ZIPCode",  coalesce( t5.ship_postal_code, t4.postal_code ) )
                                                                                                , XMLElement( "Country",  decode( coalesce( t5.ship_country_code, t4.country_code )
                                                                                                                                , 'US', 'UNITED STATES'
                                                                                                                                , 'CA', 'CANADA'
                                                                                                                                , 'UNITED STATES' ) )
                                                                                                , XMLElement( "PhoneNumber",  coalesce( t5.ship_postal_code, t4.postal_code ) )
                                                                                            ) )
                                                                                  from msf_facility_alias   t3
                                                                                  join msf_facility         t4
                                                                                    on t4.facility_id       = t3.facility_id
                                                                                  left join msf_facility_contact    t7
                                                                                    on t7.facility_id       = t4.facility_id
                                                                                   and t7.contact_type      = 3 --consignee                                                                                    
                                                                                  left join jc_stores       t5
                                                                                    on t5.facility_alias_id = t3.facility_alias_id
                                                                                 where t3.facility_alias_id = nvl(t6.return_store,t1.d_facility_alias_id) )  
                                                                            , XMLElement( "INTERNATIONAL_SHIP_UNIT"
                                                                                , XMLConcat(
                                                                                      XMLElement( "CO_GenerationType", 'HOST' )
                                                                                    , XMLElement( "CI_GenerationType", 'HOST' )
                                                                                    , XMLElement( "CI_ReasonForExport", 'Sale' )
                                                                                    , XMLElement( "CI_TermsOfSale", 'FOB' )
                                                                                    , XMLElement( "CurrencyCode", 'USD' )
                                                                                    , XMLElement( "SED_GenerationType", 'SHIPPING SYSTEM AES' )
                                                                                    , XMLElement( "SED_PartiesToTransaction", 'Y' )
                                                                                    , ( select  XMLAGG(
                                                                                                    XMLElement( "ITEM"
                                                                                                        , XMLConcat(
                                                                                                              XMLElement( "ExportClassID", t9.commodity_code ) --6105100010
                                                                                                            , XMLElement( "MasterItemID", t9.item_name ) --AH295BL7778L
                                                                                                            , XMLElement( "ItemDescription", t9.description ) --BROKEN IN POLO, BL7778, L
                                                                                                            , XMLElement( "CI_LineNumber", rownum ) --1
                                                                                                            , XMLElement( "CI_OriginISOCountryNumber", t10.ISO_CNTRY_CODE ) --360
                                                                                                            , XMLElement( "CI_Quantity", ceil( (t8.size_value*t9.primary_conv) ) ) --2
                                                                                                            , XMLElement( "CI_QuantityUM", t9.primary_uom ) --DOZ
                                                                                                            , XMLElement( "CI_Weight", (t8.size_value*t11.quantity_dtl*t11.unit_weight_dtl*0.0625) ) --0.02872
                                                                                                            , XMLElement( "CI_UnitPrice", t12.price ) --6.66
                                                                                                            , XMLElement( "TotalAmount", t12.price*t8.size_value ) --13.32
                                                                                                            , XMLElement( "SED_ScheduleBDescription", t9.hts_description ) --MEN&apos;S SHIRTS, KNITTED OR CROCHETED, OF COTTON
                                                                                                            , XMLElement( "SED_ScheduleBQty", t8.size_value ) --1
                                                                                                            , XMLElement( "SED_ScheduleBUM", t9.primary_uom ) --DOZ
                                                                                                            , XMLElement( "SED_ScheduleBSecondaryQty", ceil(t8.size_value * nvl( t9.secondary_conv, t9.primary_conv)) ) --1
                                                                                                            , XMLElement( "SED_ScheduleBSecondaryUM", nvl( t9.secondary_uom, t9.primary_uom) ) --KG
                                                                                                            , XMLElement( "SED_Weight", (t8.size_value*t11.quantity_dtl*t11.unit_weight_dtl*0.0625) ) --0.02872
                                                                                                        )
                                                                                                    )
                                                                                                )
                                                                                          from wms_lpn_detail   t8
                                                                                          join jc_item_bom      t11
                                                                                            on t11.item_id_hdr  = t8.item_id
                                                                                          join wms_hts_codes_uom t9
                                                                                            on t9.item_id       = t11.item_id_dtl
                                                                                          join wms_order_line_item t12
                                                                                            on t12.line_item_id = t8.distribution_order_dtl_id
                                                                                          left join msf_country t10
                                                                                            on t10.country_code = t8.cntry_of_orgn
                                                                                         where t8.lpn_id        = t1.lpn_id 
                                                                                    )
                                                                                ) 
                                                                            )
                                                                            , XMLElement( "REFERENCE_NOTES" 
                                                                                , XMLConcat(
                                                                                      XMLElement( "SHIP_UNIT_REFERENCE_NOTES"
                                                                                        , XMLConcat(
                                                                                              XMLElement( "ReferenceNoteType", 'REFERENCE1' )
                                                                                            , XMLElement( "ReferenceNote", t1.tc_lpn_id )
                                                                                        )
                                                                                      )
                                                                                    , XMLElement( "SHIP_UNIT_REFERENCE_NOTES"
                                                                                        , XMLConcat(
                                                                                              XMLElement( "ReferenceNoteType", 'REFERENCE2' )
                                                                                            , XMLElement( "ReferenceNote", t1.tc_lpn_id || t1.d_facility_alias_id )
                                                                                        )
                                                                                    )
                                                                                )
                                                                            )
                                                                        ) 
                                                                    ) 
                                                                order by t1.tc_lpn_id )
                                                        from wms_lpn                    t1
                                                        join jc_cartons                 t2
                                                          on t2.tc_lpn_id               = t1.tc_lpn_id
                                                        left join wms_c_scandata_int    t6
                                                          on t6.store_nbr               = t1.d_facility_alias_id
                                                         and t6.ship_via                = t1.ship_via 
                                                       where t1.tc_lpn_id               = v_tc_lpn_id )
                                                , XMLElement( "LabelOutputFileType", 'Buffer' ) ) ) ) ) ) )
                        ) AS CLOB ) c1
              INTO v_xml_clob
              FROM dual;

        dbms_output.put_line( to_char(v_xml_clob) );       
        return v_xml_clob;

    exception
       when jc_exception_pkg.assertion_failure_exception then
          rollback;
          raise;
       when others then 
          rollback;
          v_code := SQLCODE;
          v_errm := SUBSTR(SQLERRM, 1, 255);
          jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)',
                                    'v_tc_lpn_id : ' || v_tc_lpn_id );         
    end jc_scnd_msg_create_ship_intl; 


    function jc_scnd_msg_get_ship_label ( 
                                  v_tc_lpn_id       in      varchar2 
                                , v_session_id      in      number      default null )
                return clob as

        v_code  VARCHAR2(10);
        v_errm  VARCHAR2(256);  

    begin
        -- TODO: Implementation required for function JC_SCANDATA_MSGS_GEN.jc_scnd_msg_get_ship_label
        return null;
    exception
       when jc_exception_pkg.assertion_failure_exception then
          rollback;
          raise;
       when others then 
          rollback;
          v_code := SQLCODE;
          v_errm := SUBSTR(SQLERRM, 1, 255);
          jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)',
                                    'v_tc_lpn_id : ' || v_tc_lpn_id );         
    end jc_scnd_msg_get_ship_label;


    function jc_scnd_msg_cancel_ship ( 
                                  v_tc_lpn_id       in      varchar2
                                , v_session_id      in      number      default null ) 
                return clob as

        v_code      VARCHAR2(10);
        v_errm      VARCHAR2(256);  

        v_xml_clob              CLOB;

    begin

        SELECT  XMLSERIALIZE( CONTENT
                    XMLElement( "env:Envelope"
                        , XMLATTRIBUTES( 
                              'http://schemas.xmlsoap.org/soap/envelope/'                       AS "xmlns:env"     
                            , 'http://ScanData.com/WTM/'                                        AS "xmlns:wtm" )        
                        , XMLConcat( 
                              XMLElement( "env:Header" )
                            , XMLElement( "env:Body"
                                , XMLElement( "wtm:CancelShipUnits"
                                    , XMLATTRIBUTES( 'http://ScanData.com/WTM/' AS "xmlns:wtm" )
                                    , XMLConcat( 
                                          XMLElement( "wtm:SessionID"
                                            , XMLATTRIBUTES( 'http://ScanData.com/WTM/' AS "xmlns:wtm" )
                                            , nvl( v_session_id, get_session_id_when_null( v_session_id ) ) )
                                        , XMLElement( "wtm:ShipUnitList"
                                            , XMLATTRIBUTES( 'http://ScanData.com/WTM/' AS "xmlns:wtm" )
                                            , XMLElement( "SHIP_UNIT_LIST_PARAMS"
                                                , XMLATTRIBUTES( 
                                                      '1'                                                               AS "MSN"     
                                                    , 'http://ScanData.com/WTM/XMLSchemas/WTM_XMLSchema_14.00.0000.xsd' AS "xmlns" )
                                                , XMLConcat( 
                                                      XMLElement( "CartonNumber",           v_tc_lpn_id )
                                                    , XMLElement( "DistributionCenter",     'ADC' ) 
                                                ) 
                                            ) 
                                        ) 
                                    ) 
                                ) 
                            ) 
                        ) 
                    ) AS CLOB ) c1
          INTO v_xml_clob
          FROM dual     t1;

        return v_xml_clob;

    exception
       when jc_exception_pkg.assertion_failure_exception then
          rollback;
          raise;
       when others then 
          rollback;
          v_code := SQLCODE;
          v_errm := SUBSTR(SQLERRM, 1, 255);
          jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)',
                                    'v_tc_lpn_id : ' || v_tc_lpn_id );         
    end jc_scnd_msg_cancel_ship;


    function jc_scnd_msg_load_ship ( 
                                  v_tc_shipment_id  in      varchar2
                                , v_part_num        in      number
                                , v_session_id      in      number      default null ) 
                return clob as

        v_code      VARCHAR2(10);
        v_errm      VARCHAR2(256);  

        v_lpn_list              XMLTYPE;
        v_xml_clob              CLOB;
        v_part_num2             INTEGER;
        v_carrier_id            VARCHAR2(10);

        v_rank_cartons          integer := 0;

    begin
        /*
        dbms_output.put_line(   chr(10) || 'v_tc_shipment_id : ' || v_tc_shipment_id ||
                                chr(10) || 'v_part_num : ' || v_part_num ||
                                chr(10) || 'v_session_id : ' || v_session_id );
        */

        if v_part_num is null OR v_part_num <= 0 then
            v_part_num2 := 1;
        else 
            v_part_num2 := v_part_num;
        end if;

        /*
        dbms_output.put_line(   chr(10) || 'v_tc_shipment_id : ' || v_tc_shipment_id ||
                                chr(10) || 'v_part_num2 : ' || v_part_num2 ||
                                chr(10) || 'v_session_id : ' || v_session_id );
        */

        select nvl( sh.dsg_carrier_code, sh.assigned_carrier_code )
          into v_carrier_id
          from wms_shipment         sh
         where sh.tc_shipment_id    = v_tc_shipment_id; 

        --v_rank_cartons := rank_load_cartons ( v_tc_shipment_id );

        SELECT  XMLSERIALIZE( CONTENT
                    XMLElement( "env:Envelope"
                        , XMLATTRIBUTES( 
                              'http://schemas.xmlsoap.org/soap/envelope/'                       AS "xmlns:env"     
                            , 'http://ScanData.com/WTM/'                                        AS "xmlns:wtm" )
                        , XMLConcat(
                              XMLElement( "env:Header" )
                            , XMLElement( "env:Body"
                                , XMLElement( "wtm:LoadShipUnits"
                                    , XMLATTRIBUTES( 
                                          'http://ScanData.com/WTM/'                            AS "xmlns:wtm" )
                                    , XMLConcat ( 
                                          XMLElement( "wtm:SessionID"
                                            , XMLATTRIBUTES( 
                                                  'http://ScanData.com/WTM/'                    AS "xmlns:wtm" )
                                                , nvl( v_session_id, get_session_id_when_null( v_session_id ) ) )
                                        , XMLElement( "wtm:LoadShipUnitsParam"
                                            , XMLATTRIBUTES( 
                                                  'http://ScanData.com/WTM/'                    AS "xmlns:wtm" )
                                            , XMLElement( "LOAD_SHIP_UNITS_PARAMS"
                                                , XMLATTRIBUTES( 
                                                      '1'                                                               AS "MSN"     
                                                    , 'http://ScanData.com/WTM/XMLSchemas/WTM_XMLSchema_14.00.0000.xsd' AS "xmlns" )
                                                , XMLElement( "TRAILER"
                                                    , XMLForest(
                                                          'ADC'             as "DistributionCenter"
                                                        , v_tc_shipment_id  as "TrailerNumber"
                                                        , v_carrier_id      as "CarrierID" ) )
                                                , ( select  XMLAgg(
                                                                XMLElement( "CartonNumber", l2.tc_lpn_id ) )
                                                      from jc_scandata_msgs_load_lpns l2
                                                     where l2.tc_shipment_id    = v_tc_shipment_id
                                                       and l2.part_num          = v_part_num2 )
                                                , XMLElement( "DistributionCenter", 'ADC' ) ) ) ) ) ) )
                    ) AS CLOB ) c1
          INTO v_xml_clob
          FROM dual t1;

        /*
        dbms_output.put_line(   chr(10) || 'v_tc_shipment_id : ' || v_tc_shipment_id ||
                                chr(10) || 'v_part_num2 : ' || v_part_num2 ||
                                chr(10) || 'v_session_id : ' || v_session_id );

        DBMS_OUTPUT.PUT( v_xml_clob );
        */

        return v_xml_clob;
    exception
       when jc_exception_pkg.assertion_failure_exception then
          rollback;
          raise;
       when others then 
          rollback;
          v_code := SQLCODE;
          v_errm := SUBSTR(SQLERRM, 1, 255);
          jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)',
                                    'v_tc_shipment_id : ' || v_tc_shipment_id || chr(10) ||
                                    'v_part_num : ' || v_part_num );         
    end jc_scnd_msg_load_ship;


    function jc_scnd_msg_carton_dtls    (
                                  v_tc_lpn_id       in      varchar2 )
                return clob as
        v_code      VARCHAR2(10);
        v_errm      VARCHAR2(256);  

        v_xml_clob              CLOB;
    begin
        return v_xml_clob;
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
    end jc_scnd_msg_carton_dtls;
    
    
    function jc_scnd_msg_manifest_trlr ( 
                                  v_tc_shipment_id  in      varchar2 
                                , v_session_id      in      number      default null ) 
                return clob as

        v_code      VARCHAR2(10);
        v_errm      VARCHAR2(256);  

        v_xml_clob              CLOB;

    begin

        SELECT  XMLSERIALIZE( CONTENT
                    XMLElement( "env:Envelope"
                        , XMLATTRIBUTES( 
                              'http://schemas.xmlsoap.org/soap/envelope/'                       AS "xmlns:env"     
                            , 'http://ScanData.com/WTM/'                                        AS "xmlns:wtm" )        
                        , XMLConcat( 
                              XMLElement( "env:Header" )
                            , XMLElement( "env:Body"
                                , XMLElement( "wtm:ManifestTrailer"
                                    , XMLATTRIBUTES( 'http://ScanData.com/WTM/' AS "xmlns:wtm" )
                                    , XMLConcat( 
                                          XMLElement( "wtm:SessionID"
                                            , XMLATTRIBUTES( 'http://ScanData.com/WTM/' AS "xmlns:wtm" )
                                            , nvl( v_session_id, get_session_id_when_null( v_session_id ) ) )
                                        , XMLElement( "wtm:TrailerNumber"
                                            , XMLATTRIBUTES( 'http://ScanData.com/WTM/' AS "xmlns:wtm" )
                                            , v_tc_shipment_id )
                                        , XMLElement( "wtm:DistributionCenter"
                                            , XMLATTRIBUTES( 'http://ScanData.com/WTM/' AS "xmlns:wtm" )
                                            , 'ADC' ) 
                                    ) 
                                ) 
                            ) 
                        ) 
                    ) AS CLOB ) c1
          INTO v_xml_clob
          FROM dual t1;

        return v_xml_clob;
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
    end jc_scnd_msg_manifest_trlr;

/*
    function rank_load_cartons (  v_tc_shipment_id  in      varchar2 )
                return integer as 
        v_code      VARCHAR2(10);
        v_errm      VARCHAR2(256);  

        v_current_lpn_count     integer := 0;
        v_ranked_lpn_count      integer := 0;

    begin
        select count( l1.tc_lpn_id )
          into v_current_lpn_count
          from wms_lpn  l1
         where l1.tc_shipment_id        = v_tc_shipment_id
           and l1.lpn_facility_status   >= 50;

        select count( l2.tc_lpn_id )
          into v_ranked_lpn_count
          from jc_scandata_msgs_load_lpns l2
         where l2.tc_shipment_id        = v_tc_shipment_id; 

        if (    v_current_lpn_count = 0
             or v_current_lpn_count = v_ranked_lpn_count ) then
             --do nothing and exit;
             return 1;
        elsif   v_current_lpn_count > 0 then

            if v_ranked_lpn_count > 0 then
                delete from jc_scandata_msgs_load_lpns where tc_shipment_id = v_tc_shipment_id;
            end if;

            insert into jc_scandata_msgs_load_lpns 
            select  l2.lpn_id
                    , l2.tc_lpn_id
                    , l2.tc_shipment_id
                    , ( floor( (rank() OVER ( ORDER BY l2.tc_lpn_id ) )/ 100 ) + 1 )   c2
              from wms_lpn              l2
             where l2.tc_shipment_id    = v_tc_shipment_id;

            commit;

        end if;

        return 0;

    exception
       when jc_exception_pkg.assertion_failure_exception then
          rollback;
          raise;
       when others then 
          rollback;
          v_code := SQLCODE;
          v_errm := SUBSTR(SQLERRM, 1, 255);
          jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)',
                                    'v_tc_shipment_id : ' || v_tc_shipment_id ); 
    end rank_load_cartons;
*/


    function get_session_id_when_null (    
                                  v_session_id      in      number      default null ) 
                return number as
        v_code      VARCHAR2(10);
        v_errm      VARCHAR2(256);  

        v_new_session_id     integer := 0;
    begin
        if v_session_id is not null then
            return v_session_id;
        else 
            v_new_session_id := wms_C_SCANDATA_REQ_RESP_ID_SEQ.nextval;
        end if;

        return v_new_session_id;
    exception
       when jc_exception_pkg.assertion_failure_exception then
          rollback;
          --raise;
       when others then 
          rollback;
          v_code := SQLCODE;
          v_errm := SUBSTR(SQLERRM, 1, 255);
          jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)',
                                    'v_session_id : ' || v_session_id ); 
    end get_session_id_when_null;   


end jc_scandata_msgs_gen;
/
