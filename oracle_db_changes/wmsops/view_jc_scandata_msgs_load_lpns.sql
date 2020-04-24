  CREATE OR REPLACE FORCE VIEW WMSOPS.JC_SCANDATA_MSGS_LOAD_LPNS (
              LPN_ID
            , TC_LPN_ID
            , TC_SHIPMENT_ID
            , PART_NUM ) AS 
  select  l2.lpn_id
        , l2.tc_lpn_id
        , l2.tc_shipment_id
        , ( ceil( (rank() OVER ( PARTITION BY l2.tc_shipment_id ORDER BY l2.tc_lpn_id ) )/ to_number(trim (substr( sc.misc_flags, 5, 4 ))) ) )    part_num
  from wms_lpn          l2
  join msf_sys_code     sc
    on sc.code_type     = 'WSP'
   and sc.code_id       = 'WSP'
 where l2.tc_company_id                 = 1
   and l2.inbound_outbound_indicator    = 'O'
   and l2.lpn_facility_status           >= 50
   and l2.tc_shipment_id                IS NOT NULL;


grant select on JC_SCANDATA_MSGS_LOAD_LPNS to  wmsro, wmsq1;