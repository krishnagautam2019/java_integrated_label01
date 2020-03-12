package integratedLabelPkg;

import java.io.BufferedReader;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.UnsupportedEncodingException;
import java.net.MalformedURLException;
import java.net.URL;
import java.net.URLConnection;
import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.SQLException;
import java.sql.Types;
import java.util.Locale;

import javax.print.Doc;
import javax.print.DocFlavor;
import javax.print.DocPrintJob;
import javax.print.PrintException;
import javax.print.SimpleDoc;
import javax.print.attribute.HashPrintRequestAttributeSet;
import javax.print.attribute.PrintRequestAttributeSet;
import javax.print.attribute.standard.Copies;
import javax.print.attribute.standard.JobName;

import org.apache.logging.log4j.Logger;

import oracle.ucp.jdbc.PoolDataSource;

public class TransactionPrintShipLabel {
	
	private PoolDataSource pds;
	private Logger loggerObj;
	private ScandataCommunicationVariables scv;
	private PrinterSupport printers;
	private String tc_lpn_id;
	private String printer_name;
	public int errorCode;
	
	public TransactionPrintShipLabel ( PoolDataSource vpds, Logger vLoggerObj, ScandataCommunicationVariables vscv, PrinterSupport v_printers, String v_tc_lpn_id, String v_printer_name ) {
		this.pds = vpds;
		this.loggerObj = vLoggerObj;
		this.scv = vscv;
		this.printers = v_printers;
		this.tc_lpn_id = v_tc_lpn_id;
		this.printer_name = v_printer_name;
		this.errorCode = -1;
	}
	
	public void printShipLabel () {
		String v_label_url = get_label_url_from_db( tc_lpn_id );
		
		if ( v_label_url.substring(0,4).contentEquals( "http" ) ) {
			errorCode = 0;
		} else if ( v_label_url.substring(1,4).contentEquals( "0" ) ) {
			errorCode = 1;
		} else if ( v_label_url.contentEquals( tc_lpn_id ) ) {
			//so no tracking nbr or a label exists 
			//create a new request to scandata
			TransactionCreateShipUnit csu = new TransactionCreateShipUnit( pds, loggerObj, scv, tc_lpn_id );
			csu.createShipUnitMsgScandata();
			if ( csu.errorCode == 0 ) {
				errorCode = 0;
				v_label_url = csu.labelUrl;
			} else {
				//print the error happened label
				errorCode = 2;
				loggerObj.debug ( "Carton : " + tc_lpn_id + " had error " + csu.errorCode );
			}
		} else if ( ( ! v_label_url.contentEquals( "0" ) ) && ( ! v_label_url.substring(0,4).contentEquals( "http" ) ) ) {
			//so we got a tracking number but no label
			//request a new label from scandata
			TransactionGetShipUnitLabelLabel gsu = new TransactionGetShipUnitLabelLabel( pds, loggerObj, scv, tc_lpn_id );
			gsu.getShipUnitLabelMsgScandata();
			if ( gsu.errorCode == 0 ) {
				errorCode = 0;
				v_label_url = gsu.labelUrl;
			} else {
				//print the error happened label
				errorCode = 3;
				loggerObj.debug ( "Carton : " + tc_lpn_id + " had error " + gsu.errorCode );
			}
		}
		 
		String labelData = new String();
		
		//have the label url lets retrieve the data from scandata server
		if ( ( errorCode == 0 ) && ( v_label_url.substring(0,4).contentEquals( "http" ) ) ) {
			labelData = get_label_data_from_scandata( v_label_url );
		} else if ( errorCode == 1 ) {
			//print carton doesn't exists label
			loggerObj.debug ( "Carton doesn't exist : " + tc_lpn_id + ", errorCode : " + errorCode );
		} else if ( errorCode == 2 ) {
			//print can't create ship unit label
			loggerObj.debug ( "Carton doesn't exist : " + tc_lpn_id + ", errorCode : " + errorCode );
		} else if ( errorCode == 3 ) {
			//print can't retrieve label data from scandata
			loggerObj.debug ( "Carton doesn't exist : " + tc_lpn_id + ", errorCode : " + errorCode );
		} else {
			//undefined error happened 
			loggerObj.debug ( "Carton doesn't exist : " + tc_lpn_id + ", errorCode : " + errorCode );
		}
		
		//print the label
		if ( ! labelData.isEmpty() ) {
			print_label_to_printer( labelData, printer_name );
		}
	}
	
	private String get_label_url_from_db ( String v_tc_lpn_id ) {
		
		loggerObj.debug( "Get the label URL for carton : " + v_tc_lpn_id );
		
		try {
			Connection dbConn = pds.getConnection();
			String labelUrl = new String();
			
			try {	
				if ( dbConn != null ) {
					CallableStatement cstmt = dbConn.prepareCall("{? = call wmsops.jc_scandata_utils.get_label_url_for_carton(?)}");
					cstmt.registerOutParameter( 1, Types.VARCHAR );
					cstmt.setString( 2, v_tc_lpn_id );
					cstmt.executeUpdate();
					labelUrl = cstmt.getString(1);
				}
			} catch (SQLException e) {
				e.printStackTrace();
			} finally {
				if ( dbConn != null) {
					dbConn.close();
					dbConn = null;
				}
			}
			//System.out.println( clobToString( msgClobData ) );
			return labelUrl;
		} catch ( SQLException e ) {
			loggerObj.error( "Issue with executing SQL statement.\n", e );
		}
		return null;		
	}

	private String get_label_data_from_scandata( String v_label_url ) {
		
		loggerObj.debug( "Trying to retrieve label data for : " + v_label_url );
		
		String labeldata = new String();
		
		try {
			URL urlObject = new URL( v_label_url );
			
			URLConnection urlConnection = urlObject.openConnection();
			InputStream inputStream = urlConnection.getInputStream();
			BufferedReader br = new BufferedReader( new InputStreamReader( inputStream ) );

			StringBuilder resultStringBuilder = new StringBuilder();
			String inputLine;
			
			while ( ( inputLine = br.readLine() ) != null ) {
				resultStringBuilder.append(inputLine).append("\n");
			}
			
			labeldata = resultStringBuilder.toString();
			return labeldata;
		} catch ( MalformedURLException e ) {
			loggerObj.error( "Error in retriving label from scandata.\n", e );
		} catch ( IOException e ) {
			loggerObj.error( "Error in retriving label from scandata.\n", e );
		}
		
		return labeldata;
	}

	private void print_label_to_printer( String labelData, String v_printer_name ) {
		
		loggerObj.debug( "Printer the label data on : " + v_printer_name );
		loggerObj.trace( "label Data is : \n" + labelData );
		
		try {
			InputStream is = new ByteArrayInputStream(labelData.getBytes("UTF8"));

			PrintRequestAttributeSet aset = new HashPrintRequestAttributeSet();
			aset.add( new JobName( tc_lpn_id + "_integrated_label" , Locale.getDefault() ) );
			aset.add( new Copies(1) );

			DocFlavor flavor = DocFlavor.INPUT_STREAM.AUTOSENSE;
			Doc doc = new SimpleDoc(is, flavor, null);
			
			DocPrintJob job = printers.printServices[printers.getPrinterIndex(v_printer_name)].createPrintJob();
			job.print( doc, aset );
			
			is.close();
		} catch ( UnsupportedEncodingException e ) {
			loggerObj.error( "Printing error. \n", e );
		} catch ( PrintException e ) {
			loggerObj.error( "Printing error. \n", e );
		} catch ( IOException e ) {
			loggerObj.error( "Printing error. \n", e );
		}
	}

}
