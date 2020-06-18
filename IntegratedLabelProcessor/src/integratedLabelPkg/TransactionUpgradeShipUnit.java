package integratedLabelPkg;


import org.apache.logging.log4j.Logger;

import oracle.ucp.jdbc.PoolDataSource;

public class TransactionUpgradeShipUnit {
	
	private PoolDataSource pds;
	private Logger loggerObj;
	private ScandataCommunicationVariables scv;
	private String tc_lpn_id;
	
	@SuppressWarnings("unused")
	private String ship_via;
	public int errorCode;
	public String labelUrl;
	
	public TransactionUpgradeShipUnit ( PoolDataSource vpds, Logger vLoggerObj, ScandataCommunicationVariables vscv, String v_tc_lpn_id ) {
		this.pds = vpds;
		this.loggerObj = vLoggerObj;
		this.scv = vscv;
		this.tc_lpn_id = v_tc_lpn_id;
		this.ship_via = "";
		this.errorCode = -1;
		this.labelUrl = new String();
	}
	
	public TransactionUpgradeShipUnit ( PoolDataSource vpds, Logger vLoggerObj, ScandataCommunicationVariables vscv, String v_tc_lpn_id, String v_ship_via ) {
		this.pds = vpds;
		this.loggerObj = vLoggerObj;
		this.scv = vscv;
		this.tc_lpn_id = v_tc_lpn_id;
		this.ship_via = v_ship_via;
		this.errorCode = -1;
		this.labelUrl = new String();
	}
	
	public void upgradeShipUnitMsgScandata () {

		//currently not using ship via
		//Boolean b_ship_via = ship_via.isEmpty();
		
		loggerObj.info( tc_lpn_id + " : Process CancelShipUnits.");
		TransactionCancelShipUnit cancel_su = new TransactionCancelShipUnit( pds, loggerObj, scv, tc_lpn_id );
		cancel_su.cancelShipUnitMsgScandata();
		this.errorCode = cancel_su.errorCode;
		
		if ( this.errorCode == 0 ) {
			loggerObj.debug( tc_lpn_id + " : Process CreateShipUnits." );
			TransactionCreateShipUnit create_su = new TransactionCreateShipUnit( pds, loggerObj, scv, tc_lpn_id );
			create_su.createShipUnitMsgScandata();
			
			if ( create_su.errorCode == 0 ) {
				errorCode = 0;
				this.labelUrl = create_su.labelUrl;
			} else {
				//print the error happened label
				errorCode = 2;
				loggerObj.debug ( tc_lpn_id + " : Upgrade for CreateShipUnit had error " + create_su.errorCode );
			}
			
		} else {
			loggerObj.error( tc_lpn_id + " : Cannot do CreateShipUnits part of upgrade of carton because cancel failed for carton." );
		}
		
	}

}
