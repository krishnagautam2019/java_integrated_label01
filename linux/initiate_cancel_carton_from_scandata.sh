#! /bin/bash

intg_lbl_dir=/apps/scope/scripts/integrated_label/
IPC_log=${intg_lbl_dir}/ipc_log.log

##cd ${intg_lbl_dir}
v_tc_lpn_id=$1
ipc_command="CancelShipUnit|${v_tc_lpn_id}|0|"

log_date=`date '+%Y%m%d_%H%M'`
echo "${log_date} : ${ipc_command}" >> ${IPC_log}

echo ${ipc_command} | nc localhost 37000

exit 0
