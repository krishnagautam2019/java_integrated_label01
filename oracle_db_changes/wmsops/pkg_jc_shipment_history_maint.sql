CREATE OR REPLACE PACKAGE jc_shipment_history_maint AS

    PROCEDURE jsh_update;

    PROCEDURE jsh_prod_update;

    PROCEDURE jsh_prod_invoiced_insert;

    PROCEDURE jsh_archive_insert;

END jc_shipment_history_maint;
/


CREATE OR REPLACE PACKAGE BODY jc_shipment_history_maint AS

    PROCEDURE jsh_update AS
    BEGIN
        jsh_prod_update;
        --jsh_archive_insert;
    END jsh_update;

    PROCEDURE jsh_prod_update AS
    BEGIN
        jsh_prod_invoiced_insert;
        --jsh_prod_closed_insert;
        --jsh_prod_invoiced_update;
    END jsh_prod_update;

    PROCEDURE jsh_prod_invoiced_insert AS
    BEGIN

        INSERT INTO jc_shipment_history COLUMNS (
            shipment, trailer, carrier, cartons,
            weight, quantity, route, destination,
            invoice_date, ship_date )
        WITH shipped_times AS
            ( SELECT ptt2.REF_FIELD_1, MAX(ptt2.MOD_DATE_TIME) MOD_DATE_TIME
                FROM wms_PROD_TRKG_TRAN ptt2
               WHERE ptt2.menu_optn_name = 'RF Close Trailer'
                 AND ptt2.TRAN_TYPE = '800'
                 AND ptt2.TRAN_CODE = '003'
               GROUP BY ptt2.REF_FIELD_1 )
        SELECT  s.tc_shipment_id                                  shipment,
                s.trailer_number                                  trailer,
                s.assigned_carrier_code                           carrier,
                COUNT(DISTINCT l.lpn_id)                          cartons,
                SUM( jib.quantity_dtl * jib.UNIT_WEIGHT_dtl * ld.shipped_qty )            
                                                                  weight,
                SUM( jib.quantity_dtl * ld.SHIPPED_QTY )          quantity,
                sr.route_alias_id                                 route,
                s.d_stop_location_name                            destination,
                MAX(l.shipped_dttm)                               invoice_date,
                MAX(nvl(t1.MOD_DATE_TIME,s.LAST_UPDATED_DTTM))    ship_date
          FROM wms_shipment s
          LEFT JOIN shipped_times t1
            on t1.REF_FIELD_1 = s.TC_SHIPMENT_ID
          JOIN msf_static_route sr 
            ON s.static_route_id = sr.static_route_id
          JOIN wms_lpn l 
            ON l.shipment_id = s.shipment_id
          JOIN wms_lpn_detail ld 
            ON ld.lpn_id = l.lpn_id
           AND l.inbound_outbound_indicator = 'O'
           AND l.lpn_facility_status = 90
          JOIN jc_item_bom jib
            ON jib.ITEM_ID_HDR = ld.ITEM_ID
         WHERE s.shipment_status = 80
           AND NOT EXISTS ( SELECT 1 
                              FROM jc_shipment_history jsh
                             WHERE jsh.shipment = s.tc_shipment_id )
         GROUP BY s.tc_shipment_id,
                 s.trailer_number,
                 s.assigned_carrier_code,
                 sr.route_alias_id,
                 s.d_stop_location_name,
                 s.shipment_id;    

         COMMIT;
         
    END jsh_prod_invoiced_insert;

    PROCEDURE jsh_archive_insert AS
    BEGIN
        
        /*
        INSERT INTO jc_shipment_history
        WITH shipped_times AS 
            (  SELECT ptt2.REF_FIELD_1, MAX(ptt2.MOD_DATE_TIME) MOD_DATE_TIME
                 FROM wmsp_arc.arch_prod_trkg_tran ptt2
                WHERE ptt2.TRAN_TYPE = '800'
                  AND ptt2.TRAN_CODE = '003'
                  AND ptt2.menu_optn_name = 'RF Close Trailer'
                GROUP BY ptt2.REF_FIELD_1 )
        SELECT s.tc_shipment_id                                 shipment,
               s.trailer_number                                 trailer,
               s.assigned_carrier_code                          carrier,
               COUNT(distinct l.lpn_id)                         cartons,
               SUM( jib.quantity_dtl * jib.UNIT_WEIGHT_dtl * ld.shipped_qty )           
                                                                weight,
               SUM( jib.quantity_dtl * ld.SHIPPED_QTY )         quantity,
               sr.route_alias_id                                route,
               s.d_stop_location_name                           destination,
               MAX(nvl(t1.MOD_DATE_TIME,s.LAST_UPDATED_DTTM))   ship_date,
               MAX(l.shipped_dttm)                              invoiced_dttm
          FROM wmsp_arc.arch_shipment s
          LEFT JOIN shipped_times t1
            on t1.REF_FIELD_1 = s.TC_SHIPMENT_ID
          JOIN msf_static_route sr 
            ON s.static_route_id = sr.static_route_id
          JOIN wmsp_arc.arch_lpn l 
            ON l.shipment_id = s.shipment_id
          JOIN wmsp_arc.arch_lpn_detail ld 
            ON ld.lpn_id = l.lpn_id
          JOIN JC_ITEM_BOM jib
            ON jib.ITEM_ID_HDR = ld.ITEM_ID
          WHERE NOT EXISTS ( SELECT 1 
                              FROM jc_shipment_history jsh
                             WHERE jsh.shipment = s.tc_shipment_id )
           AND l.inbound_outbound_indicator = 'O'
           AND s.shipment_status = 80
           --AND s.tc_shipment_id = 'CS00012976'
           --AND trunc(nvl(ptt.MOD_DATE_TIME,s.LAST_UPDATED_DTTM)) 
           --       BETWEEN trunc(TO_DATE('01/01/2017', 'MM/DD/YYYY') ) 
           --           AND trunc(TO_DATE('01/01/2018', 'MM/DD/YYYY') )
         GROUP BY s.tc_shipment_id,
                  s.trailer_number,
                  s.assigned_carrier_code,
                  sr.route_alias_id,
                  s.d_stop_location_name,
                  s.shipment_id;*/
                  
        COMMIT;

    END jsh_archive_insert;

END jc_shipment_history_maint;
/
