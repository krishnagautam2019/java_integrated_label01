CREATE OR REPLACE package jc_fx_facility as 


    PROCEDURE new_jc_store_sys_code_setup   (     v_jcrew_fixes_id 	    IN OUT 	NUMBER
                                                , v_fixes_seq      	    IN OUT 	NUMBER    
                                                , v_facility_alias_id   IN      varchar2 default null );


    PROCEDURE new_jc_store_nxt_up_setup     (     v_jcrew_fixes_id 	    IN OUT 	NUMBER
                                                , v_fixes_seq      	    IN OUT 	NUMBER    
                                                , v_facility_alias_id   IN      varchar2 default null );
    
    
end jc_fx_facility;
/


CREATE OR REPLACE package body jc_fx_facility as


    PROCEDURE new_jc_store_sys_code_setup   (     v_jcrew_fixes_id 	    IN OUT 	NUMBER
                                                , v_fixes_seq      	    IN OUT 	NUMBER    
                                                , v_facility_alias_id   IN      varchar2 default null ) as
        v_code  VARCHAR2(10);
        v_errm  VARCHAR2(256);      
        
        vc_facility_alias_id    facility_alias.facility_alias_id%type;
    begin
        for new_stores in (
            select fa.facility_alias_id
                    , fa.facility_id
              from facility             fc
              join facility_alias       fa
                on fa.facility_id       = fc.facility_id
             where fc.facility_type_bits= 64
               and fc.is_operational    = 1
               and fa.facility_alias_id = nvl( v_facility_alias_id, fa.facility_alias_id )
               and length( fa.facility_alias_id )       = 4
               and is_number( fa.facility_alias_id )    = 1
               and not exists (
                        select 1
                          from sys_code         sc
                         where sc.rec_type      = 'S'
                           and sc.code_type     = '537'
                           and sc.code_id       = fa.facility_alias_id ) ) 
        loop
        
            vc_facility_alias_id := new_stores.facility_alias_id;
            
            jc_fx_base.fix_tracking (     v_jcrew_fixes_id
                                        , v_fixes_seq
                                        , 'NEW_STORE_SYS_CODE_SETUP'--FUNCTION_NAME
                                        , NULL                      --ITEM_NAME
                                        , null                      --TC_LPN_ID
                                        , NULL                      --TC_SHIPMENT_ID
                                        , 'FACILITY_ALIAS_ID'       --REF_FIELD_1_ID
                                        , vc_facility_alias_id      --REF_FIELD_1
                                        , NULL                      --REF_FIELD_2_ID
                                        , NULL                      --REF_FIELD_2
                                        , NULL );                   --BACKUP_TABLE
    
            IF v_jcrew_fixes_id != 0 THEN            
            
                Insert into SYS_CODE (
                      REC_TYPE
                    , CODE_TYPE
                    , CODE_ID
                    , CODE_DESC
                    , SHORT_DESC
                    , MISC_FLAGS
                    , CREATE_DATE_TIME
                    , MOD_DATE_TIME
                    , USER_ID
                    , WM_VERSION_ID
                    , SYS_CODE_ID
                    , SYS_CODE_TYPE_ID ) 
                values ( 'S'
                    , '537'
                    , new_stores.facility_alias_id
                    , 'Store ' || new_stores.facility_alias_id || ' Nextup'
                    , 'Store ' || new_stores.facility_alias_id
                    , 'LPN TC LPN ID                                               1'
                    , sysdate
                    , sysdate
                    , 'gkrishna'
                    , 1
                    , sys_code_id_seq.nextval
                    , 602 );
                
                commit;
            end if;
            
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
                                    'vc_facility_alias_id : ' || vc_facility_alias_id );                
    end new_jc_store_sys_code_setup;


    PROCEDURE new_jc_store_nxt_up_setup     (     v_jcrew_fixes_id 	    IN OUT 	NUMBER
                                                , v_fixes_seq      	    IN OUT 	NUMBER    
                                                , v_facility_alias_id   IN      varchar2 default null ) as
        v_code  VARCHAR2(10);
        v_errm  VARCHAR2(256);      
        
        vc_facility_alias_id    facility_alias.facility_alias_id%type;
    begin
        for new_stores in (
            select sc.code_id
             from sys_code               sc
            where sc.rec_type            = 'S' 
              and sc.code_type           = '537'
              and length( sc.code_id )   = 4
              and sc.short_desc          like 'Store%'
              and is_number( sc.code_id ) = 1
              and not exists ( select 1
                                 from nxt_up_cnt        nuc
                                where nuc.rec_type_id   = sc.code_id ) )
        loop
            vc_facility_alias_id := new_stores.code_id;

            jc_fx_base.fix_tracking (     v_jcrew_fixes_id
                                        , v_fixes_seq
                                        , 'NEW_STORE_NXT_UP_SETUP'  --FUNCTION_NAME
                                        , NULL                      --ITEM_NAME
                                        , null                      --TC_LPN_ID
                                        , NULL                      --TC_SHIPMENT_ID
                                        , 'FACILITY_ALIAS_ID'       --REF_FIELD_1_ID
                                        , vc_facility_alias_id      --REF_FIELD_1
                                        , NULL                      --REF_FIELD_2_ID
                                        , NULL                      --REF_FIELD_2
                                        , NULL );                   --BACKUP_TABLE
    
            IF v_jcrew_fixes_id != 0 THEN
            
                Insert into nxt_up_cnt nuc (
                      cd_master_id
                    , rec_type_id
                    , pfx_field
                    , pfx_len
                    , start_nbr
                    , end_nbr
                    , curr_nbr
                    , nbr_len
                    , incr_value
                    , nxt_start_nbr
                    , nxt_end_nbr
                    , chk_digit_type
                    , chk_digit_len
                    , repeat_range
                    , create_date_time
                    , mod_date_time
                    , user_id
                    , nxt_up_cnt_id
                    , hibernate_version
                    , facility_id
                    , whse ) 
                values ( 1                          -- cd_master_id
                    , vc_facility_alias_id          -- rec_type_id
                    , '8' || vc_facility_alias_id   -- pfx_field
                    , 5                             -- pfx_len
                    , 1                             -- start_nbr
                    , 99999                         -- end_nbr
                    , 1                             -- curr_nbr
                    , 5                             -- nbr_len
                    , 1                             -- incr_value
                    , 1                             -- nxt_start_nbr
                    , 99999                         -- nxt_end_nbr
                    , null                          -- chk_digit_type
                    , 0                             -- chk_digit_len
                    , 'Y'                           -- repeat_range
                    , sysdate                       -- create_date_time
                    , sysdate                       -- mod_date_time
                    , 'gkrishna'                    -- user_id
                    , nxt_up_cnt_id_seq.nextval     -- nxt_up_cnt_id
                    , 1                             -- hibernate_version
                    , 1                             -- facility_id
                    , 'ADC' );                      -- whse 
                
                commit;
            
            end if;
            
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
                                    'vc_facility_alias_id : ' || vc_facility_alias_id );                
    end new_jc_store_nxt_up_setup;


end jc_fx_facility;
/
