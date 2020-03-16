--------------------------------------------------------
--  File created - Sunday-March-15-2020   
--------------------------------------------------------
--------------------------------------------------------
--  DDL for Table JC_SCANDATA_TEMP_LPN_LIST
--------------------------------------------------------

  CREATE GLOBAL TEMPORARY TABLE "WMSOPS"."JC_SCANDATA_TEMP_LPN_LIST" 
   (	"TC_LPN_ID" VARCHAR2(50 BYTE), 
	"SESSION_KEY" NUMBER(6,0)
   ) ON COMMIT DELETE ROWS ;
--------------------------------------------------------
--  DDL for Index JC_SCANDATA_TEMP_LPN_LIST_IDX1
--------------------------------------------------------

  CREATE INDEX "WMSOPS"."JC_SCANDATA_TEMP_LPN_LIST_IDX1" ON "WMSOPS"."JC_SCANDATA_TEMP_LPN_LIST" ("TC_LPN_ID") ;
--------------------------------------------------------
--  DDL for Index JC_SCANDATA_TEMP_LPN_LIST_IDX2
--------------------------------------------------------

  CREATE INDEX "WMSOPS"."JC_SCANDATA_TEMP_LPN_LIST_IDX2" ON "WMSOPS"."JC_SCANDATA_TEMP_LPN_LIST" ("SESSION_KEY") ;
