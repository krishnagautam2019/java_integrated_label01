package integratedLabelPkg;

import java.sql.SQLException;
import java.util.StringTokenizer;

import org.apache.logging.log4j.Logger;

import oracle.ucp.jdbc.PoolDataSource;
import oracle.ucp.jdbc.PoolDataSourceFactory;

public class ProcessIpcMessage implements Runnable {
	
	private PoolDataSource pds;
	private Logger loggerObj;
	private String ipcMsg;
	private ScandataCommunicationVariables scv;
	//private PrinterSupport prns;
	
	ProcessIpcMessage ( PoolDataSource vpds, Logger vLoggerObj, String vIpcMsg, ScandataCommunicationVariables vscv ) {
		this.pds = vpds;
		this.loggerObj = vLoggerObj;
		this.ipcMsg = vIpcMsg;
		this.scv = vscv;
		//this.prns = v_prns;
	}
	
	public void run() {
		loggerObj.trace( "Processsing msg : " + ipcMsg );
		
		StringTokenizer st1 = new StringTokenizer( ipcMsg, "|", false );
		String msgType;
		String msgValue;
		String msgPrinter;
		
		if ( st1.countTokens() >= 3 ) {
			
			msgType = st1.nextToken();
			msgValue = st1.nextToken();
			msgPrinter = st1.nextToken();
			
			loggerObj.trace( "msgType	: " + msgType );
			loggerObj.trace( "msgValue	: " + msgValue );
			loggerObj.trace( "msgPrinter: " + msgPrinter );
			
		} else {
			return;
		}
		
		//if the connection is it available then create it
		if ( pds == null) {
			try {
				pds = connectionInit();
			} catch ( Exception e ) {
				loggerObj.error( "Exception. \n",e );
			}	
		}
		
		if ( msgType.equals( "Printer" ) ) {
			loggerObj.trace( "Processing msgType " + msgType + " for : " + msgValue );
			processPrintShipLabelForCarton ( msgValue, msgPrinter );
		} else if ( msgType.equals( "CreateShipUnit" ) ) {
			loggerObj.trace( "Processing msgType " + msgType + " for : " + msgValue );
			processCreateShipUnit( msgValue );
		} else if ( msgType.equals( "CancelShipUnit" ) ) {
			loggerObj.trace( "Processing msgType " + msgType + " for : " + msgValue );
			processCancelShipUnit( msgValue );
		} else if ( msgType.equals( "UpgradeShipUnit" ) ) {
			loggerObj.trace( "Processing msgType " + msgType + " for : " + msgValue );
			processUpgradeShipUnit( msgValue );
		} else if ( msgType.equals( "GetShipUnitLabel" ) ) {
			loggerObj.trace( "Processing msgType " + msgType + " for : " + msgValue );
			processGetShipUnitLabel( msgValue );
		} else if ( msgType.equals( "LoadShipUnits" ) ) {
			loggerObj.trace( "Processing msgType " + msgType + " for : " + msgValue );
			processLoadTrailer( msgValue );
		} else if ( msgType.equals( "ManifestTrailer" ) ) {
			loggerObj.trace( "Processing msgType " + msgType + " for : " + msgValue );
			processManifestTrailer( msgValue );
		} else if ( msgType.equals( "LoadAndInvoice" ) ) {
			loggerObj.trace( "Processing msgType " + msgType + " for : " + msgValue );
			processLoadAndInvoiceTrailer( msgValue );
		}
		
		return;
	}

	private PoolDataSource connectionInit() {
		
		try {
			PoolDataSource localPds = PoolDataSourceFactory.getPoolDataSource();
			
			//Setting connection properties of the data source
			localPds.setConnectionFactoryClassName("oracle.jdbc.pool.OracleDataSource");
			
            ///*
            //options for prod
			localPds.setURL("jdbc:oracle:thin:@//jxr3-scan.jcrew.com:1521/rwmsp_app.jcrew.com");
			localPds.setUser("wmsops");
			localPds.setPassword("o1p2s3wms");
            //*/
            
            /*
            // options for qa
            localPds.setURL("jdbc:oracle:thin:@//jxr3-scan.jcrew.com:1521/rwmsp_app.jcrew.com");
            localPds.setUser("WMSRO");
            localPds.setPassword("WMSRO45");
            */
			
			//Setting pool properties
			localPds.setInitialPoolSize(2);
			localPds.setMinPoolSize(2);
			localPds.setMaxPoolSize(20);
			localPds.setAbandonedConnectionTimeout ( 10 );
			localPds.setTimeToLiveConnectionTimeout ( 600 );
			localPds.setConnectionPoolName ( "IntegratedLabelThread" );
			
			loggerObj.debug ( "Opening a new DB connection pool" );
			
			return localPds;
		} catch ( SQLException e ) {
			loggerObj.error( "Error trying initialize Connection Pool", e );
		}
		
		return null;
	}

	private void processCreateShipUnit ( String v_tc_lpn_id ) {
		loggerObj.debug( "Process CreateShipUnits : " + v_tc_lpn_id );
		TransactionCreateShipUnit csu = new TransactionCreateShipUnit( pds, loggerObj, scv, v_tc_lpn_id );
		csu.createShipUnitMsgScandata();
	}
	
	private void processCancelShipUnit ( String v_tc_lpn_id ) {
		loggerObj.debug( "Process CancelShipUnits : " + v_tc_lpn_id );
		TransactionCancelShipUnit csu = new TransactionCancelShipUnit( pds, loggerObj, scv, v_tc_lpn_id );
		csu.cancelShipUnitMsgScandata();
	}

	private void processUpgradeShipUnit ( String v_tc_lpn_id ) {
		loggerObj.debug( "Process UpgradeShipUnits : " + v_tc_lpn_id );
		TransactionUpgradeShipUnit usu = new TransactionUpgradeShipUnit( pds, loggerObj, scv, v_tc_lpn_id );
		usu.upgradeShipUnitMsgScandata();
	}

	private void processPrintShipLabelForCarton ( String v_tc_lpn_id, String v_printer_name ) {
		loggerObj.debug( "Process Print ship label : " + v_tc_lpn_id );
		TransactionPrintShipLabel psl = new TransactionPrintShipLabel( pds, loggerObj, scv, v_tc_lpn_id, v_printer_name );
		psl.printShipLabel();
	}

	private void processGetShipUnitLabel( String v_tc_lpn_id)  {
		loggerObj.debug( "Process Get ship label : " + v_tc_lpn_id );
		TransactionGetShipUnitLabelLabel gsl = new TransactionGetShipUnitLabelLabel( pds, loggerObj, scv, v_tc_lpn_id );
		gsl.getShipUnitLabelMsgScandata();
	}
	
	private void processLoadTrailer( String v_tc_shipment_id )  {
		loggerObj.debug( "Process Load Trailer : " + v_tc_shipment_id );
		TransactionLoadShipUnitsForTrailer gsl = new TransactionLoadShipUnitsForTrailer( pds, loggerObj, scv, v_tc_shipment_id );
		gsl.processLoadShipUnitsForTrailer();
	}

	private void processManifestTrailer( String v_tc_shipment_id )  {
		loggerObj.debug( "Process Manifest Trailer : " + v_tc_shipment_id );
		TransactionManifestTrailer gsl = new TransactionManifestTrailer( pds, loggerObj, scv, v_tc_shipment_id );
		gsl.manifestTrailerMsgScandata(1);
	}
	
	private void processLoadAndInvoiceTrailer( String v_tc_shipment_id )  {
		loggerObj.debug( "Process Manifest Trailer : " + v_tc_shipment_id );
		TransactionInvoiceTrailer gsl = new TransactionInvoiceTrailer( pds, loggerObj, scv, v_tc_shipment_id );
		gsl.manifestTrailerMsgScandata(0);
	}
}
