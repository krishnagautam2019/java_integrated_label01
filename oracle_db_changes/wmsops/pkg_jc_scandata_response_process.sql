CREATE OR REPLACE package jc_scandata_response_process as


    function process_create_ship_reponse 
                            ( response_input     in      varchar2 )
                return varchar2;


    function process_cancel_ship_reponse 
                            ( response_input     in      varchar2 )
                return varchar2;


    function process_load_ship_reponse 
                            (   response_input      in      varchar2
                              , v_tc_shipment_id_in in      varchar2 default null )
                return INTEGER;


    function process_manifest_trlr_reponse  
                            (   response_input      in      varchar2
                              , v_tc_shipment_id_in in      varchar2 default null )
                return INTEGER;


end jc_scandata_response_process;
/


CREATE OR REPLACE package body jc_scandata_response_process as


    function process_create_ship_reponse ( response_input     in      varchar2 )
                return varchar2 as
            
            v_code      VARCHAR2(10);
            v_errm      VARCHAR2(256);

            v_soap_response     varchar2(3000) := response_input;

            v_tc_lpn_id         VARCHAR2(30);
            v_ship_via          VARCHAR2(30);
            v_tracking_nbr      VARCHAR2(30);
            v_label             VARCHAR2(200);
    begin

        v_soap_response :=  replace( v_soap_response, '<?xml version="1.0" encoding="UTF-8"?>' );
        --v_soap_response :=  replace( v_soap_response, '<CreateShipUnitsResponse xmlns="http://ScanData.com/WTM/">', '<CreateShipUnitsResponse>');
        v_soap_response :=  replace( v_soap_response, '<CREATE_SHIP_UNIT_DOC xmlns="http://ScanData.com/WTM/XMLSchemas/WTM_XMLSchema_14.00.0000.xsd" MSN="1">', '<CREATE_SHIP_UNIT_DOC>' );
        --dbms_output.put_line( v_soap_response );

        /*
        v_soap_response :=  replace( v_soap_response, 'xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"' );
        v_soap_response :=  replace( v_soap_response, 'xmlns:xsd="http://www.w3.org/2001/XMLSchema"' );
        v_soap_response :=  replace( v_soap_response, 'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"' );
        v_soap_response :=  replace( v_soap_response, 'xmlns="http://ScanData.com/WTM/"' );
        v_soap_response :=  replace( v_soap_response, 'xmlns="http://ScanData.com/WTM/XMLSchemas/WTM_XMLSchema_14.00.0000.xsd" MSN="1"' );
        v_soap_response :=  replace( v_soap_response, 'soap:Envelope', 'soapEnvelope' );
        v_soap_response :=  replace( v_soap_response, 'soap:Body', 'soapBody' );
        v_soap_response :=  replace( v_soap_response, ' ' );
        */

        /*
        v_soap_response := substr( v_soap_response
                                    , instr( v_soap_response, '<SHIP_UNIT_SHIP_INFO>', 435 )
                                    , length(v_soap_response) - instr( v_soap_response, '</SHIP_UNIT_SHIP_INFO>', 435 ) + instr( v_soap_response, '<SHIP_UNIT_SHIP_INFO>', 435 ) - 43 );
        */
        --dbms_output.put_line( v_soap_response );

        if instr( v_soap_response, 'ERROR', 1 ) > 0 then
            --has error do this
            select    t1.CartonNumber
                    , t1.TrackingNumber
                    , t1.LabelURL
              into    v_tc_lpn_id
                    , v_tracking_nbr
                    , v_label
              from XMLTABLE( 
                        xmlnamespaces ( 
                              'http://schemas.xmlsoap.org/soap/envelope/'       as "soap"
                            , 'http://www.w3.org/2001/XMLSchema-instance'       as "xsi"
                            , 'http://www.w3.org/2001/XMLSchema'                as "xsd" 
                            , default   'http://ScanData.com/WTM/' )
                        , '/soap:Envelope/soap:Body/CreateShipUnitsResponse/CreateShipUnitsResult/CREATE_SHIP_UNIT_DOC/SHIP_UNIT_SHIP_INFO_ROW/ERROR' PASSING XMLTYPE( v_soap_response )
                                COLUMNS
                                      TrackingNumber    VARCHAR2(30)    PATH    'Number'  
                                    , LabelURL          VARCHAR2(200)   PATH    'Description'
                                    , CartonNumber      VARCHAR2(30)    PATH    'CartonNumber' ) t1;

            --error_code    error_description
            --2601          ;Cannot insert duplicate key row in object 'dbo.SHIP_UNITS' with unique index 'IX_SHIP_UNITS_CARTON_NUMBER'. The duplicate key value is (8010420116, ADC).;100023:Failed to insert SHIP_UNIT for ShipUnitID 1790053
            return v_tracking_nbr; --tracking number field has the error now 

        else
            select    t1.CartonNumber
                    , t1.ShipVia
                    , t1.TrackingNumber
                    , t1.LabelURL
              into    v_tc_lpn_id
                    , v_ship_via
                    , v_tracking_nbr
                    , v_label
              from XMLTABLE( 
                        xmlnamespaces ( 
                              'http://schemas.xmlsoap.org/soap/envelope/'       as "soap"
                            , 'http://www.w3.org/2001/XMLSchema-instance'       as "xsi"
                            , 'http://www.w3.org/2001/XMLSchema'                as "xsd" 
                            , default   'http://ScanData.com/WTM/' )
                        , '/soap:Envelope/soap:Body/CreateShipUnitsResponse/CreateShipUnitsResult/CREATE_SHIP_UNIT_DOC/SHIP_UNIT_SHIP_INFO_ROW/SHIP_UNIT_SHIP_INFO' PASSING XMLTYPE( v_soap_response )
                                COLUMNS
                                      CartonNumber      VARCHAR2(30)    PATH    'CartonNumber'
                                    , ShipVia           VARCHAR2(30)    PATH    'ShipVia'  
                                    , TrackingNumber    VARCHAR2(30)    PATH    'TrackingNumber'  
                                    , LabelURL          VARCHAR2(200)   PATH    'LABEL/LabelURL' ) t1;

            --update/insert the label data in wms
            wms_jc_scandata_actions.create_ship_unit_on_success( v_tc_lpn_id, v_ship_via, v_tracking_nbr, v_label );        

            return v_label;

        end if;

        --retrun data to java
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
                                            , 'response_input : ' || response_input );   
    end;


    function process_cancel_ship_reponse ( response_input     in      varchar2 )
                return varchar2 as

            v_code      VARCHAR2(10);
            v_errm      VARCHAR2(256);

            v_soap_response     varchar2(3000) := response_input;

            v_tc_lpn_id         VARCHAR2(30);
    begin

        v_soap_response :=  replace( v_soap_response, '<?xml version="1.0" encoding="UTF-8"?>' );
        v_soap_response :=  replace( v_soap_response, '<SHIP_UNIT_RESULT_DOC xmlns="http://ScanData.com/WTM/XMLSchemas/WTM_XMLSchema_14.00.0000.xsd" MSN="1">', '<SHIP_UNIT_RESULT_DOC>' );
        --dbms_output.put_line( v_soap_response );

        if instr( v_soap_response, 'ERROR', 1 ) > 0 then
            --has error do this
            v_tc_lpn_id := '1';
            return v_tc_lpn_id; --tracking number field has the error now 

        else
            select    t1.CartonNumber
              into    v_tc_lpn_id
              from XMLTABLE( 
                        xmlnamespaces ( 
                              'http://schemas.xmlsoap.org/soap/envelope/'       as "soap"
                            , 'http://www.w3.org/2001/XMLSchema-instance'       as "xsi"
                            , 'http://www.w3.org/2001/XMLSchema'                as "xsd" 
                            , default   'http://ScanData.com/WTM/' )
                        , '/soap:Envelope/soap:Body/CancelShipUnitsResponse/CancelShipUnitsResult/SHIP_UNIT_RESULT_DOC/SHIP_UNIT_RESULT_ROW' PASSING XMLTYPE( v_soap_response )
                                COLUMNS
                                      CartonNumber      VARCHAR2(30)    PATH    'CartonNumber' ) t1;

            --update wms data
            wms_jc_scandata_actions.cancel_ship_unit_on_success( v_tc_lpn_id );

            return v_tc_lpn_id;
        end if;

        --retrun to java
        return v_tc_lpn_id;
    exception
       when jc_exception_pkg.assertion_failure_exception then
          rollback;
          raise;
       when others then 
          rollback;
          v_code := SQLCODE;
          v_errm := SUBSTR(SQLERRM, 1, 255);
          jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)'
                                            , 'response_input : ' || response_input );
    end;


    function process_load_ship_reponse 
                            (   response_input      in      varchar2
                              , v_tc_shipment_id_in in      varchar2 default null )
                return integer as

            v_code      VARCHAR2(10);
            v_errm      VARCHAR2(256);

            v_soap_response     varchar2(3000) := response_input;

            v_carton_count      integer := 0;
    begin
        if v_tc_shipment_id_in is not null then
            wms_jc_scandata_req_resp_updt.updt_trlr_manifest_response( response_input, to_number( substr( v_tc_shipment_id_in, 3, 9) ) , null );
        end if;
        
        v_soap_response :=  replace( v_soap_response, '<?xml version="1.0" encoding="UTF-8"?>' );
        --dbms_output.put_line( v_soap_response );

        if instr( v_soap_response, 'ERROR', 1 ) > 0 then
            --has error do this
            v_carton_count := 0;
            
            v_soap_response :=  replace( v_soap_response, q'[ xmlns="http://ScanData.com/WTM/XMLSchemas/WTM_XMLSchema_14.00.0000.xsd" MSN="1"]', '' );
            dbms_output.put_line( 'v_soap_response : ' || v_soap_response );
            
            select    t1.ErrorCode
              into    v_carton_count
              from XMLTABLE( 
                        xmlnamespaces ( 
                              'http://schemas.xmlsoap.org/soap/envelope/'       as "soap"
                            , 'http://www.w3.org/2001/XMLSchema-instance'       as "xsi"
                            , 'http://www.w3.org/2001/XMLSchema'                as "xsd"
                            , 'http://ScanData.com/WTM/XMLSchemas/WTM_XMLSchema_14.00.0000.xsd' 
                                                                                as xmlns
                            , default   'http://ScanData.com/WTM/' )
                        , '/soap:Envelope/soap:Body/LoadShipUnitsResponse/LoadShipUnitsResult/LOAD_SHIP_UNITS_DOC/ERROR' PASSING XMLTYPE( v_soap_response )
                                COLUMNS
                                      ErrorCode         INTEGER     PATH    'Number' ) t1;
            
            if v_carton_count = 547 then
                v_carton_count := -547;
            else
                v_carton_count := 0;
            end if;
            
            return v_carton_count; --tracking number field has the error now 
        else
            v_soap_response :=  replace( v_soap_response, q'[<LOAD_SHIP_UNITS_DOC MSN='1' xmlns='http://ScanData.com/WTM/XMLSchemas/WTM_XMLSchema_11.00.0000.xsd'>]', '<LOAD_SHIP_UNITS_DOC>' );
            
            select    t1.CartonCount
              into    v_carton_count
              from XMLTABLE( 
                        xmlnamespaces ( 
                              'http://schemas.xmlsoap.org/soap/envelope/'       as "soap"
                            , 'http://www.w3.org/2001/XMLSchema-instance'       as "xsi"
                            , 'http://www.w3.org/2001/XMLSchema'                as "xsd" 
                            , default   'http://ScanData.com/WTM/' )
                        , '/soap:Envelope/soap:Body/LoadShipUnitsResponse/LoadShipUnitsResult/LOAD_SHIP_UNITS_DOC/TRAILER_INFO' PASSING XMLTYPE( v_soap_response )
                                COLUMNS
                                      CartonCount       VARCHAR2(30)    PATH    'TotalUnitCount' ) t1;

            return v_carton_count;
        end if;

        --retrun to java
        return v_carton_count;
    exception
       when jc_exception_pkg.assertion_failure_exception then
          rollback;
          raise;
       when others then 
          rollback;
          v_code := SQLCODE;
          v_errm := SUBSTR(SQLERRM, 1, 255);
          jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)'
                                            , 'response_input : ' || response_input );
    end;


    function process_manifest_trlr_reponse  
                            (   response_input      in      varchar2
                              , v_tc_shipment_id_in in      varchar2 default null )
                return integer as

            v_code      VARCHAR2(10);
            v_errm      VARCHAR2(256);

            v_soap_response     varchar2(3000) := response_input;
            
            v_tc_shipment_id    wms_shipment.tc_shipment_id%type;
            v_carton_count      integer := 0;
            v_req_resp_entry    integer := 0;
    begin
        if v_tc_shipment_id_in is not null then
            wms_jc_scandata_req_resp_updt.updt_trlr_manifest_response( response_input, to_number( substr( v_tc_shipment_id_in, 3, 8) ) , null );
        end if;

        v_soap_response :=  replace( v_soap_response, '<?xml version="1.0" encoding="UTF-8"?>' );
        --dbms_output.put_line( v_soap_response );

        if instr( v_soap_response, 'ERROR', 1 ) > 0 then
            --has error do this
            v_carton_count := 0;
            
            v_soap_response :=  replace( v_soap_response, q'[ xmlns="http://ScanData.com/WTM/XMLSchemas/WTM_XMLSchema_14.00.0000.xsd" MSN="1"]', '' );
            dbms_output.put_line( 'v_soap_response : ' || v_soap_response );
            
            select    t1.ErrorCode
              into    v_carton_count
              from XMLTABLE( 
                        xmlnamespaces ( 
                              'http://schemas.xmlsoap.org/soap/envelope/'       as "soap"
                            , 'http://www.w3.org/2001/XMLSchema-instance'       as "xsi"
                            , 'http://www.w3.org/2001/XMLSchema'                as "xsd"
                            , 'http://ScanData.com/WTM/XMLSchemas/WTM_XMLSchema_14.00.0000.xsd' 
                                                                                as xmlns
                            , default   'http://ScanData.com/WTM/' )
                        , '/soap:Envelope/soap:Body/ManifestTrailerResponse/ManifestTrailerResult/MANIFEST_RESULTS_DOC/ERROR' PASSING XMLTYPE( v_soap_response )
                                COLUMNS
                                      ErrorCode         INTEGER     PATH    'Number' ) t1;
            
            if v_carton_count = 547 then
                v_carton_count := -547;
            else
                v_carton_count := 0;
            end if;
            
            return v_carton_count; --tracking number field has the error now 
        else
            v_soap_response :=  replace( v_soap_response, q'[<MANIFEST_RESULTS_DOC xmlns="http://ScanData.com/WTM/XMLSchemas/WTM_XMLSchema_14.00.0000.xsd">]', '<MANIFEST_RESULTS_DOC>' );
            
            select    t1.TrailerNumber
                    , t1.TotalErrorCount
              into    v_tc_shipment_id
                    , v_carton_count
              from XMLTABLE( 
                        xmlnamespaces ( 
                              'http://schemas.xmlsoap.org/soap/envelope/'       as "soap"
                            , 'http://www.w3.org/2001/XMLSchema-instance'       as "xsi"
                            , 'http://www.w3.org/2001/XMLSchema'                as "xsd" 
                            , default   'http://ScanData.com/WTM/' )
                        , '/soap:Envelope/soap:Body/ManifestTrailerResponse/ManifestTrailerResult/MANIFEST_RESULTS_DOC' PASSING XMLTYPE( v_soap_response )
                                COLUMNS
                                      TrailerNumber     VARCHAR2(30)    PATH    'TrailerNumber'
                                    , TotalShipUnitCount    INTEGER     PATH    'TotalShipUnitCount'
                                    , TotalWeight       INTEGER         PATH    'TotalWeight'
                                    , TotalErrorCount   INTEGER         PATH    'TotalErrorCount' ) t1;
            
            --lets try to populate the c_scandata _req_resp
            for recs in (
                        select    t1.TrailerNumber
                                , t2.ReportType
                                , t2.ReportURL
                          --into    v_carton_count
                          from XMLTABLE( 
                                    xmlnamespaces ( 
                                          'http://schemas.xmlsoap.org/soap/envelope/'       as "soap"
                                        , 'http://www.w3.org/2001/XMLSchema-instance'       as "xsi"
                                        , 'http://www.w3.org/2001/XMLSchema'                as "xsd" 
                                        , default   'http://ScanData.com/WTM/' )
                                    , '/soap:Envelope/soap:Body/ManifestTrailerResponse/ManifestTrailerResult/MANIFEST_RESULTS_DOC' PASSING XMLTYPE( v_soap_response )
                                            COLUMNS
                                                  TrailerNumber     VARCHAR2(30)    PATH    'TrailerNumber'
                                                , TotalShipUnitCount    INTEGER     PATH    'TotalShipUnitCount'
                                                , TotalWeight       INTEGER         PATH    'TotalWeight'
                                                , TotalErrorCount   INTEGER         PATH    'TotalErrorCount'
                                                , reports           XMLTYPE         PATH    'REPORT' ) t1
                                , XMLTABLE( 
                                    xmlnamespaces ( 
                                          'http://schemas.xmlsoap.org/soap/envelope/'       as "soap"
                                        , 'http://www.w3.org/2001/XMLSchema-instance'       as "xsi"
                                        , 'http://www.w3.org/2001/XMLSchema'                as "xsd" 
                                        , default   'http://ScanData.com/WTM/' )
                                    , '/REPORT' PASSING t1.reports
                                            COLUMNS
                                                  ReportType        VARCHAR2(10)    PATH    'Type'
                                                , ReportURL         VARCHAR2(150)   PATH    'ReportURL' ) t2 )
            loop
                v_req_resp_entry :=  v_req_resp_entry + 1;
                wms_jc_scandata_actions.manifest_trlr_on_success( recs.TrailerNumber, recs.ReportType, recs.ReportURL );
            end loop;
            
            if ( v_req_resp_entry = 0 ) then
                wms_jc_scandata_actions.manifest_trlr_on_success( v_tc_shipment_id, 'CARRIER', 'No URL in Response' );
            end if;
            
            return v_carton_count;
        end if;

        --retrun to java
        return v_carton_count;
    exception
       when jc_exception_pkg.assertion_failure_exception then
          rollback;
          raise;
       when others then 
          rollback;
          v_code := SQLCODE;
          v_errm := SUBSTR(SQLERRM, 1, 255);
          jc_exception_pkg.throw( jc_exception_pkg.unhandled_except, v_code || ' - ' || v_errm || ' ($Header$)'
                                            , 'v_tc_shipment_id : ' || v_tc_shipment_id
                                            , 'response_input : ' || v_soap_response );
    end;


end jc_scandata_response_process;
/
