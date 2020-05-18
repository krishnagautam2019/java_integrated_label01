#! /bin/bash

sqlplus -s "WMSOPS/o1p2s3wms@${ORACLE_SID}" << SQL
    execute wmsops.jc_scandata_utils.find_invoiced_shipments(120);
    exit;
SQL

exit 0
