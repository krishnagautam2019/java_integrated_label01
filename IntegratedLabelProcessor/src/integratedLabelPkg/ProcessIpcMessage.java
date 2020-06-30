package integratedLabelPkg;

import java.util.StringTokenizer;

import org.apache.logging.log4j.Logger;

public class ProcessIpcMessage implements Runnable {
	
	private DatabaseConnectionPoolSupport cps;
	private Logger loggerObj;
	private String ipcMsg;
	private ScandataCommunicationVariables scv;
	//private PrinterSupport prns;
	
	ProcessIpcMessage ( DatabaseConnectionPoolSupport vcps, Logger vLoggerObj, String vIpcMsg, ScandataCommunicationVariables vscv ) {
		this.cps = vcps;
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
			
			loggerObj.trace( "msgType       : " + msgType );
			loggerObj.trace( "msgValue      : " + msgValue );
			loggerObj.trace( "msgPrinter    : " + msgPrinter );
			
		} else {
			return;
		}
				
		if ( msgType.equals( "Printer" ) ) {
			loggerObj.trace( msgValue + " : Processing msgType : " + msgType );
			processPrintShipLabelForCarton ( msgValue, msgPrinter );
		} else if ( msgType.equals( "CreateShipUnit" ) ) {
			loggerObj.trace( msgValue + " : Processing msgType : " + msgType );
			processCreateShipUnit( msgValue );
		} else if ( msgType.equals( "CancelShipUnit" ) ) {
			loggerObj.trace( msgValue + " : Processing msgType : " + msgType );
			processCancelShipUnit( msgValue );
		} else if ( msgType.equals( "UpgradeShipUnit" ) ) {
			loggerObj.trace( msgValue + " : Processing msgType : " + msgType );
			processUpgradeShipUnit( msgValue );
		} else if ( msgType.equals( "GetShipUnitLabel" ) ) {
			loggerObj.trace( msgValue + " : Processing msgType : " + msgType );
			processGetShipUnitLabel( msgValue );
		} else if ( msgType.equals( "LoadShipUnits" ) ) {
			loggerObj.trace( msgValue + " : Processing msgType : " + msgType );
			processLoadTrailer( msgValue );
		} else if ( msgType.equals( "ManifestTrailer" ) ) {
			loggerObj.trace( msgValue + " : Processing msgType : " + msgType );
			processManifestTrailer( msgValue );
		} else if ( msgType.equals( "LoadAndInvoice" ) ) {
			loggerObj.trace( msgValue + " : Processing msgType : " + msgType );
			processLoadAndInvoiceTrailer( msgValue );
		}
		
		return;
	}

	private void processCreateShipUnit ( String v_tc_lpn_id ) {
		loggerObj.debug( "Process CreateShipUnits : " + v_tc_lpn_id );
		TransactionCreateShipUnit csu = new TransactionCreateShipUnit( cps, loggerObj, scv, v_tc_lpn_id );
		csu.createShipUnitMsgScandata();
	}
	
	private void processCancelShipUnit ( String v_tc_lpn_id ) {
		loggerObj.debug( "Process CancelShipUnits : " + v_tc_lpn_id );
		TransactionCancelShipUnit csu = new TransactionCancelShipUnit( cps, loggerObj, scv, v_tc_lpn_id );
		csu.cancelShipUnitMsgScandata();
	}

	private void processUpgradeShipUnit ( String v_tc_lpn_id ) {
		loggerObj.debug( "Process UpgradeShipUnits : " + v_tc_lpn_id );
		TransactionUpgradeShipUnit usu = new TransactionUpgradeShipUnit( cps, loggerObj, scv, v_tc_lpn_id );
		usu.upgradeShipUnitMsgScandata();
	}

	private void processPrintShipLabelForCarton ( String v_tc_lpn_id, String v_printer_name ) {
		loggerObj.debug( "Process Print ship label : " + v_tc_lpn_id );
		TransactionPrintShipLabel psl = new TransactionPrintShipLabel( cps, loggerObj, scv, v_tc_lpn_id, v_printer_name );
		psl.printShipLabel();
	}

	private void processGetShipUnitLabel( String v_tc_lpn_id)  {
		loggerObj.debug( "Process Get ship label : " + v_tc_lpn_id );
		TransactionGetShipUnitLabelLabel gsl = new TransactionGetShipUnitLabelLabel( cps, loggerObj, scv, v_tc_lpn_id );
		gsl.getShipUnitLabelMsgScandata();
	}
	
	private void processLoadTrailer( String v_tc_shipment_id )  {
		loggerObj.debug( "Process Load Trailer : " + v_tc_shipment_id );
		TransactionLoadShipUnitsForTrailer gsl = new TransactionLoadShipUnitsForTrailer( cps, loggerObj, scv, v_tc_shipment_id );
		gsl.processLoadShipUnitsForTrailer();
	}

	private void processManifestTrailer( String v_tc_shipment_id )  {
		loggerObj.debug( "Process Manifest Trailer : " + v_tc_shipment_id );
		TransactionManifestTrailer gsl = new TransactionManifestTrailer( cps, loggerObj, scv, v_tc_shipment_id );
		gsl.manifestTrailerMsgScandata(1);
	}
	
	private void processLoadAndInvoiceTrailer( String v_tc_shipment_id )  {
		loggerObj.debug( "Process Manifest Trailer : " + v_tc_shipment_id );
		TransactionInvoiceTrailer gsl = new TransactionInvoiceTrailer( cps, loggerObj, scv, v_tc_shipment_id );
		gsl.manifestTrailerMsgScandata(0);
	}
}
