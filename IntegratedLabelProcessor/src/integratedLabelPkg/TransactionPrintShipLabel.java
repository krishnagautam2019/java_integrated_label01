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
import javax.print.PrintService;
import javax.print.PrintServiceLookup;
import javax.print.SimpleDoc;
import javax.print.attribute.HashPrintRequestAttributeSet;
import javax.print.attribute.PrintRequestAttributeSet;
import javax.print.attribute.standard.Copies;
import javax.print.attribute.standard.JobName;

import org.apache.logging.log4j.Logger;

import oracle.ucp.jdbc.PoolDataSource;

public class TransactionPrintShipLabel {
	
	private DatabaseConnectionPoolSupport cps;
	private PoolDataSource pds;
	private Logger loggerObj;
	private ScandataCommunicationVariables scv;
	//private PrinterSupport printers;
	private String tc_lpn_id;
	private String printer_name;
	public int errorCode;
	
	public TransactionPrintShipLabel ( DatabaseConnectionPoolSupport vcps, Logger vLoggerObj, ScandataCommunicationVariables vscv, String v_tc_lpn_id, String v_printer_name ) {
		this.cps = vcps;
		this.pds = this.cps.getPoolDataSource();
		this.loggerObj = vLoggerObj;
		this.scv = vscv;
		//this.printers = v_printers;
		this.tc_lpn_id = v_tc_lpn_id;
		this.printer_name = v_printer_name;
		this.errorCode = -1;
	}
	
	public void printShipLabel () {
		loggerObj.info( tc_lpn_id + " : printShipLabel"  );
		
		//this segment could commented after unit testing.
		try {
			String connName  = pds.getConnectionPoolName();
			int avlConnCount = pds.getAvailableConnectionsCount();
			int brwConnCount = pds.getBorrowedConnectionsCount();
			loggerObj.debug( tc_lpn_id + " : " + connName + " has Available connections: " + avlConnCount + "; Borrowed connections: " + brwConnCount );
		} catch( SQLException se ) {
			loggerObj.error("Unable to get connection Pool Details. \n",se);
		}
		
		String v_label_url = new String();
		String ship_via = get_ship_via_for_carton( tc_lpn_id );
		loggerObj.debug( tc_lpn_id + " : ship_via for carton is :" + ship_via );
		
		//restart the connection data pool is 
		if ( ship_via.isEmpty() || ship_via == null ) {
			pds = cps.restartPoolDataSource(); 
			ship_via = get_ship_via_for_carton( tc_lpn_id );
			loggerObj.debug( tc_lpn_id + " : ship_via for carton is :" + ship_via );
		}

		if ( ship_via.contentEquals( "ERRR" ) ) {
			//print error label
			String labelData = get_label_err_generic(tc_lpn_id, "Ship via retruned as ERRR, contact WMS Support");
			print_label_to_printer( labelData, printer_name );
			return;
		} else if ( ship_via.contentEquals( "LOAD" ) ) {
			//print carton loaded label
			String labelData = get_label_err_loaded(tc_lpn_id);
			print_label_to_printer( labelData, printer_name );
			return;
		} else if ( ship_via.contentEquals( "SHPD" ) ) {
			//print error label
			String labelData = get_label_err_shipped(tc_lpn_id);
			print_label_to_printer( labelData, printer_name );
			return;				
		} else if ( ship_via.contentEquals( "INTL" ) ) {
			//print error label
			String labelData = get_label_international_carton(tc_lpn_id);
			print_label_to_printer( labelData, printer_name );
			return;				
		} else if ( ship_via.contentEquals( "CLSD" ) ) {
			//print error label
			String labelData = get_label_closed_store(tc_lpn_id);
			print_label_to_printer( labelData, printer_name );
			return;				
		} else if ( ship_via.contentEquals( "NSTR" ) ) {
			//print error label
			String labelData = get_label_new_store(tc_lpn_id);
			print_label_to_printer( labelData, printer_name );
			return;
		} else if ( ship_via.contentEquals( "LTLR" ) ) {
			//print error label
			String labelData = get_label_ltl_route(tc_lpn_id);
			print_label_to_printer( labelData, printer_name );
			return;		
		}  else if ( ship_via.contentEquals( "DFLT" ) ) {
			//print error label
			String labelData = get_label_err_generic(tc_lpn_id, "Ship via retruned as DFLT, contact WMS Support");
			print_label_to_printer( labelData, printer_name );
			return;
		} else if ( ship_via.contentEquals( "UGRD" ) ) {
			loggerObj.info( tc_lpn_id + " , ship_via :  " + ship_via + " : Inititing new UpgradeShipUnit transaction with scandata for carton." );
			
			TransactionUpgradeShipUnit usu = new TransactionUpgradeShipUnit( cps, loggerObj, scv, tc_lpn_id, ship_via );
			usu.upgradeShipUnitMsgScandata();
			if ( usu.errorCode == 0 ) {
				errorCode = 0;
				v_label_url = usu.labelUrl;
			} else {
				//print the error happened label
				errorCode = 1;
				loggerObj.info ( "Carton : " + tc_lpn_id + " had error " + usu.errorCode );
			}
		}
		
		//if non of the previous scenarios caught the carton
		if ( errorCode < 0 ) {
			//lets check if the carton already has a label
			v_label_url = get_label_url_from_db( tc_lpn_id );
			loggerObj.debug( tc_lpn_id + " : response from db for label data : " + v_label_url );
			
			//if no data is returned from the database then
			if ( v_label_url.length() <= 1 && v_label_url.contentEquals( "0" ) ) {
				errorCode = 2;
				
			//if a actual label url is available from the database
			} else if ( v_label_url.substring(0,4).contentEquals( "http" ) ) {
				errorCode = 0;
				
			//this data condition is fulfilled by coalesce( l1.tracking_nbr, l1.tc_lpn_id, '0000' )
			} else if ( v_label_url.substring(1,4).contentEquals( "0000" ) ) {
				errorCode = 3;
			
			//so no tracking nbr or a label exists
			//create a new request to scandata
			} else if ( v_label_url.contentEquals( tc_lpn_id ) ) {
				loggerObj.info( tc_lpn_id + " , ship_via :  " + ship_via + " : Inititing new CreateShipUnit transaction with scandata for carton." );
					
				TransactionCreateShipUnit csu = new TransactionCreateShipUnit( cps, loggerObj, scv, tc_lpn_id, ship_via );
				csu.createShipUnitMsgScandata();
				if ( csu.errorCode == 0 ) {
					errorCode = 0;
					v_label_url = csu.labelUrl;
				} else {
					//print the error happened label
					errorCode = 4;
					loggerObj.info ( "Carton : " + tc_lpn_id + " had error " + csu.errorCode );
				}
			
			//tracking number exists, but no url
			} else if ( ( ! v_label_url.contentEquals( "0" ) ) && ( ! v_label_url.substring(0,4).contentEquals( "http" ) ) ) {
				//so we got a tracking number but no label
				//request a new label from scandata
				TransactionGetShipUnitLabelLabel gsu = new TransactionGetShipUnitLabelLabel( cps, loggerObj, scv, tc_lpn_id );
				gsu.getShipUnitLabelMsgScandata();
				if ( gsu.errorCode == 0 ) {
					errorCode = 0;
					v_label_url = gsu.labelUrl;
				} else {
					//print the error happened label
					errorCode = 5;
					loggerObj.info ( "Carton : " + tc_lpn_id + " had error " + gsu.errorCode );
				}
			}
		}
		
		
		String labelData = new String();
		
		//have the label url lets retrieve the data from scandata server
		if ( ( errorCode == 0 ) && ( v_label_url.substring(0,4).contentEquals( "http" ) ) ) {
			labelData = get_label_data_from_scandata( v_label_url );
		} else if ( errorCode == 1 ) {
			//print can't create ship unit label
			loggerObj.debug ( tc_lpn_id + " : error occured during upgrade transaction, errorCode : " + errorCode );
			labelData = get_label_err_generic(tc_lpn_id, tc_lpn_id + " Print errorCode : " + errorCode + ". Contact WMS Support");
		} else if ( errorCode == 2 ) {
			//print carton doesn't exists label
			loggerObj.debug ( tc_lpn_id + " : function get_label_url_from_db didnt return any data, errorCode : " + errorCode );
			labelData = get_label_err_generic(tc_lpn_id, tc_lpn_id + " Print errorCode : " + errorCode + ". Contact WMS Support");
		} else if ( errorCode == 3 ) {
			//print can't retrieve label data from scandata
			loggerObj.debug ( tc_lpn_id + " : function get_label_url_from_db returned 0000, errorCode : " + errorCode );
			labelData = get_label_err_generic(tc_lpn_id, tc_lpn_id + " Print errorCode : " + errorCode + ". Contact WMS Support");
		} else if ( errorCode == 4 ) {
			//print can't retrieve label data from scandata
			loggerObj.debug ( tc_lpn_id + " : error occured during create ship unit transaction, errorCode : " + errorCode );
			labelData = get_label_err_generic(tc_lpn_id, tc_lpn_id + " Print errorCode : " + errorCode + ". Contact WMS Support");
		} else if ( errorCode == 5 ) {
			//print can't retrieve label data from scandata
			loggerObj.debug ( tc_lpn_id + " : error occured during get ship label transaction, errorCode : " + errorCode );
			labelData = get_label_err_generic(tc_lpn_id, tc_lpn_id + " Print errorCode : " + errorCode + ". Contact WMS Support");
		} else {
			//undefined error happened 
			loggerObj.debug ( tc_lpn_id + " : unhandled error occured trying to generate carton label, errorCode : " + errorCode );
			labelData = get_label_err_generic(tc_lpn_id, tc_lpn_id + " Print errorCode : " + errorCode + ". Contact WMS Support");
		}
		
		//print the label
		if ( ! labelData.isEmpty() ) {
			print_label_to_printer( labelData, printer_name );
		}
		
		//this segment could commented after unit testing.
		try {
			String connName  = pds.getConnectionPoolName();
			int avlConnCount = pds.getAvailableConnectionsCount();
			int brwConnCount = pds.getBorrowedConnectionsCount();
			loggerObj.debug( tc_lpn_id + " : " + connName + " has Available connections: " + avlConnCount + "; Borrowed connections: " + brwConnCount );
		} catch( SQLException se ) {
			loggerObj.error("Unable to get connection Pool Details. \n",se);
		}
	}
	
	private String get_label_url_from_db ( String v_tc_lpn_id ) {
		
		loggerObj.info( v_tc_lpn_id + " : get_label_url_from_db" );
		
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
			loggerObj.error( this.tc_lpn_id + " :Issue with executing SQL function get_label_url_for_carton.\n", e );
		}
		return null;		
	}

	private String get_label_data_from_scandata( String v_label_url ) {
		
		loggerObj.info( this.tc_lpn_id + " : Trying to retrieve label data for : " + v_label_url );
		
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
			
			br.close();
			
			labeldata = resultStringBuilder.toString();
			return labeldata;
		} catch ( MalformedURLException e ) {
			loggerObj.error( this.tc_lpn_id + " :Error in retriving label from scandata.\n", e );
		} catch ( IOException e ) {
			loggerObj.error( this.tc_lpn_id + " :Error in retriving label from scandata.\n", e );
		} 
		
		return labeldata;
	}

	private void print_label_to_printer( String labelData, String v_printer_name ) {
		
		loggerObj.info( this.tc_lpn_id + " : Print the label data on : " + v_printer_name );
		//loggerObj.debug( "label Data is : \n" + labelData );
		
		try {
			InputStream is = new ByteArrayInputStream(labelData.getBytes("UTF8"));

			DocFlavor flavor = DocFlavor.INPUT_STREAM.AUTOSENSE;
			Doc doc = new SimpleDoc(is, flavor, null);

			PrintRequestAttributeSet aset = new HashPrintRequestAttributeSet();
			//aset.add(new PrinterName(v_printer_name, null));
			aset.add( new JobName( tc_lpn_id + "_integrated_label" , Locale.getDefault() ) );
			aset.add( new Copies(1) );
			
			PrintService[] pservices = PrintServiceLookup.lookupPrintServices(null,null);
			//loggerObj.debug( this.tc_lpn_id + " : Printers deducted " + pservices.length );
			
	        // Retrieve a print service from the array
			PrintService service = null;
			for (int index = 0; service == null && index < pservices.length; index++) {
				
				//:q
				loggerObj.debug( this.tc_lpn_id + " : Printer index trace index " + index + " : " + pservices[index].getName().toUpperCase() );
	            
				if (pservices[index].getName().toUpperCase().indexOf(v_printer_name) >= 0) {
	            	//loggerObj.debug( this.tc_lpn_id + " : Printer index is " + index );
	                service = pservices[index];
	    			DocPrintJob job = service.createPrintJob();
	    			job.print( doc, aset );
	            }
	        }
			
			is.close();
			loggerObj.info( this.tc_lpn_id + " : Printing completed." );
		} catch ( UnsupportedEncodingException e ) {
			loggerObj.error( this.tc_lpn_id + " : Printing error. \n", e );
		} catch ( PrintException e ) {
			loggerObj.error( this.tc_lpn_id + " : Printing error. \n", e );
		} catch ( IOException e ) {
			loggerObj.error( this.tc_lpn_id + " : Printing error. \n", e );
		}
	}

	private String get_ship_via_for_carton ( String v_tc_lpn_id ) {
		
		loggerObj.info( v_tc_lpn_id + " : get_ship_via_for_carton." );
		
		try {
			Connection dbConn = pds.getConnection();
			String ship_via = new String();
			
			try {	
				if ( dbConn != null ) {
					CallableStatement cstmt = dbConn.prepareCall("{? = call wmsops.jc_scandata_utils.get_ship_via_for_carton(?)}");
					cstmt.registerOutParameter( 1, Types.VARCHAR );
					cstmt.setString( 2, v_tc_lpn_id );
					cstmt.executeUpdate();
					ship_via = cstmt.getString(1);
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
			return ship_via;
		} catch ( SQLException e ) {
			loggerObj.error( v_tc_lpn_id + " : Issue with executing SQL function get_ship_via_for_carton.\n", e );
		}
		return null;		
	}
	
	private String get_label_err_loaded ( String v_tc_lpn_id ) {
		loggerObj.info( v_tc_lpn_id + "is already loaded; genrating error label." );
		
		String label_data = "^XA^XZ";
		try {
			Connection dbConn = pds.getConnection();
			try {	
				if ( dbConn != null ) {
					CallableStatement cstmt = dbConn.prepareCall("{? = call wmsops.jc_scandata_gen_labels.jc_scnd_gen_lbl_loaded(?)}");
					cstmt.registerOutParameter( 1, Types.VARCHAR );
					cstmt.setString( 2, v_tc_lpn_id );
					cstmt.executeUpdate();
					label_data = cstmt.getString(1);
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
			return label_data;
		} catch ( SQLException e ) {
			loggerObj.error( v_tc_lpn_id + " : Issue with executing SQL function jc_scnd_gen_lbl_loaded.\n", e );
		}
		return label_data;		
	}

	private String get_label_err_shipped ( String v_tc_lpn_id ) {
		loggerObj.info( v_tc_lpn_id + "is already shipped; genrating error label." );
		
		String label_data = "^XA^XZ";
		try {
			Connection dbConn = pds.getConnection();
			try {	
				if ( dbConn != null ) {
					CallableStatement cstmt = dbConn.prepareCall("{? = call wmsops.jc_scandata_gen_labels.jc_scnd_gen_lbl_shipped(?)}");
					cstmt.registerOutParameter( 1, Types.VARCHAR );
					cstmt.setString( 2, v_tc_lpn_id );
					cstmt.executeUpdate();
					label_data = cstmt.getString(1);
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
			return label_data;
		} catch ( SQLException e ) {
			loggerObj.error( v_tc_lpn_id + " : Issue with executing SQL function jc_scnd_gen_lbl_shipped.\n", e );
		}
		return label_data;		
	}
	
	private String get_label_international_carton ( String v_tc_lpn_id ) {
		loggerObj.info( v_tc_lpn_id + "is a international carton; cannot generate inetegrated label fot it. Carton needs to be on a statndard UPS inetrnational ship_via." );
		
		String label_data = "^XA^XZ";
		try {
			Connection dbConn = pds.getConnection();
			try {	
				if ( dbConn != null ) {
					CallableStatement cstmt = dbConn.prepareCall("{? = call wmsops.jc_scandata_gen_labels.jc_scnd_gen_lbl_intl(?)}");
					cstmt.registerOutParameter( 1, Types.VARCHAR );
					cstmt.setString( 2, v_tc_lpn_id );
					cstmt.executeUpdate();
					label_data = cstmt.getString(1);
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
			return label_data;
		} catch ( SQLException e ) {
			loggerObj.error( v_tc_lpn_id + " : Issue with executing SQL function jc_scnd_gen_lbl_intl.\n", e );
		}
		return label_data;		
	}
	
	private String get_label_closed_store ( String v_tc_lpn_id ) {
		loggerObj.info( v_tc_lpn_id + "is a carton for a closed store; carton assigned to route CL." );
		
		String label_data = "^XA^XZ";
		try {
			Connection dbConn = pds.getConnection();
			try {	
				if ( dbConn != null ) {
					CallableStatement cstmt = dbConn.prepareCall("{? = call wmsops.jc_scandata_gen_labels.jc_scnd_gen_lbl_clsd_store(?)}");
					cstmt.registerOutParameter( 1, Types.VARCHAR );
					cstmt.setString( 2, v_tc_lpn_id );
					cstmt.executeUpdate();
					label_data = cstmt.getString(1);
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
			return label_data;
		} catch ( SQLException e ) {
			loggerObj.error( v_tc_lpn_id + " : Issue with executing SQL function jc_scnd_gen_lbl_clsd_store.\n", e );
		}
		return label_data;		
	}

	private String get_label_new_store ( String v_tc_lpn_id ) {
		loggerObj.info( v_tc_lpn_id + "is a carton for a new store; Integrated Labels are not generated for them by design." );
		
		String label_data = "^XA^XZ";
		try {
			Connection dbConn = pds.getConnection();
			try {	
				if ( dbConn != null ) {
					CallableStatement cstmt = dbConn.prepareCall("{? = call wmsops.jc_scandata_gen_labels.jc_scnd_gen_lbl_new_store(?)}");
					cstmt.registerOutParameter( 1, Types.VARCHAR );
					cstmt.setString( 2, v_tc_lpn_id );
					cstmt.executeUpdate();
					label_data = cstmt.getString(1);
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
			return label_data;
		} catch ( SQLException e ) {
			loggerObj.error( v_tc_lpn_id + " : Issue with executing SQL function jc_scnd_gen_lbl_new_store.\n", e );
		}
		return label_data;		
	}

	private String get_label_ltl_route ( String v_tc_lpn_id ) {
		loggerObj.info( v_tc_lpn_id + " : LTL Route carton; Integrated Labels are not generated for them by design." );
		
		String label_data = "^XA^XZ";
		try {
			Connection dbConn = pds.getConnection();
			try {	
				if ( dbConn != null ) {
					CallableStatement cstmt = dbConn.prepareCall("{? = call wmsops.jc_scandata_gen_labels.jc_scnd_gen_lbl_ltl_route(?)}");
					cstmt.registerOutParameter( 1, Types.VARCHAR );
					cstmt.setString( 2, v_tc_lpn_id );
					cstmt.executeUpdate();
					label_data = cstmt.getString(1);
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
			return label_data;
		} catch ( SQLException e ) {
			loggerObj.error( v_tc_lpn_id + " : Issue with executing SQL function jc_scnd_gen_lbl_new_store.\n", e );
		}
		return label_data;		
	}

	private String get_label_err_generic ( String v_tc_lpn_id, String labelErrorMsg ) {
		loggerObj.info( v_tc_lpn_id + " : encountered an unidentified error during integrated label generation. Generating generic error label." );
		
		String labelErrorMsg2 = labelErrorMsg;
		if ( labelErrorMsg == null || labelErrorMsg.length() == 0 ){
			labelErrorMsg2 = "unkown error; contact wms support";
		}
		String label_data = "^XA^XZ";
		try {
			Connection dbConn = pds.getConnection();
			try {	
				if ( dbConn != null ) {
					CallableStatement cstmt = dbConn.prepareCall("{? = call wmsops.jc_scandata_gen_labels.jc_scnd_gen_err_lbl_generic(?,?)}");
					cstmt.registerOutParameter( 1, Types.VARCHAR );
					cstmt.setString( 2, v_tc_lpn_id );
					cstmt.setString( 3, labelErrorMsg2 );
					cstmt.executeUpdate();
					label_data = cstmt.getString(1);
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
			return label_data;
		} catch ( SQLException e ) {
			loggerObj.error( v_tc_lpn_id + " : Issue with executing SQL function jc_scnd_gen_err_lbl_generic.\n", e );
		}
		return label_data;		
	}
	
}
