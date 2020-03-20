CREATE OR REPLACE package jc_scandata_msgs_gen as
    
    
    function parse_lpn_list (
                  p_delimstring     IN      VARCHAR2
                , p_delim           IN      VARCHAR2 DEFAULT ',' )
            return number;


    function jc_scnd_msg_create_ship_bknd ( 
                                  v_tc_lpn_id       in      varchar2
                                , v_ship_via        in      varchar2
                                , v_session_id      in      number )
                return clob;


    function jc_scnd_msg_create_ship ( 
                                  v_tc_lpn_id       in      varchar2
                                , v_session_id      in      number      default null )
                return clob;


    --copy of the function to get the xml for alternate ship via
    function jc_scnd_msg_create_ship_via ( 
                                  v_tc_lpn_id       in      varchar2
                                , v_ship_via        in      varchar2
                                , v_session_id      in      number      default null )
                return clob;


    function jc_scnd_msg_create_ship_plt ( 
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


    function jc_scnd_msg_manifest_trlr ( 
                                  v_tc_shipment_id  in      varchar2 
                                , v_session_id      in      number      default null ) 
                return clob;

/*    
    function rank_load_cartons (  v_tc_shipment_id  in      varchar2 )
                return integer;
*/

    function get_seession_id_when_null (    
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
    

    function jc_scnd_msg_create_ship_bknd ( 
                                  v_tc_lpn_id       in      varchar2
                                , v_ship_via        in      varchar2
                                , v_session_id      in      number )
                return clob as
        v_code      varchar2(10);
        v_errm      varchar2(256);
        
        v_xml_clob  clob;
    begin
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
                                            , nvl( v_session_id, get_seession_id_when_null( v_session_id ) ) )
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
                                                        , XMLElement( "ShipVia", nvl( v_ship_via, t2.ship_via ) ) 
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
                                    'v_tc_lpn_id : ' || v_tc_lpn_id || chr(10) ||
                                    'v_ship_via : ' || v_ship_via || chr(10) ||
                                    'v_session_id : ' || v_session_id );             
    end;

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
            v_session_id2 := get_seession_id_when_null( v_session_id );
        else
            v_session_id2 := v_session_id;
        end if;
        
        if v_check_multilpn <= 0 then
            select nvl( l2.ship_via, 'DFLT' )
              into v_ship_via
              from wms_lpn l2
             where l2.tc_lpn_id = v_tc_lpn_id; 
            
            v_xml_clob := jc_scnd_msg_create_ship_bknd( v_tc_lpn_id, v_ship_via, v_session_id );
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
                                , v_ship_via        in      varchar2
                                , v_session_id      in      number      default null )
                return clob as
        v_code      varchar2(10);
        v_errm      varchar2(256);
        
        v_xml_clob              clob;
        v_session_id2           number;
    begin
        --get the session_id if its null
        if ( v_session_id is null ) then
            v_session_id2 := get_seession_id_when_null( v_session_id );
        else
            v_session_id2 := v_session_id;
        end if;
        
        v_xml_clob := jc_scnd_msg_create_ship_bknd( v_tc_lpn_id, nvl(v_ship_via,'DFLT'), v_session_id );
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
                                                , nvl( v_session_id, get_seession_id_when_null( v_session_id ) ) )
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
                                            , nvl( v_session_id, get_seession_id_when_null( v_session_id ) ) )
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
                                                , nvl( v_session_id, get_seession_id_when_null( v_session_id ) ) )
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
                                            , nvl( v_session_id, get_seession_id_when_null( v_session_id ) ) )
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


    function get_seession_id_when_null (    
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
    end get_seession_id_when_null;   


end jc_scandata_msgs_gen;
/
