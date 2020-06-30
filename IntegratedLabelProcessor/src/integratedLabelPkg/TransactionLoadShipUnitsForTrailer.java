package integratedLabelPkg;

import java.io.IOException;
import java.net.HttpURLConnection;
import java.net.MalformedURLException;
import java.net.URL;
import java.sql.CallableStatement;
import java.sql.Clob;
import java.sql.Connection;
import java.sql.SQLException;
import java.sql.Types;

import javax.xml.soap.MessageFactory;
import javax.xml.soap.SOAPConnection;
import javax.xml.soap.SOAPConnectionFactory;
import javax.xml.soap.SOAPException;
import javax.xml.soap.SOAPMessage;
import javax.xml.soap.SOAPPart;
import javax.xml.transform.dom.DOMSource;

import org.apache.logging.log4j.Logger;
import org.w3c.dom.Document;

import oracle.ucp.jdbc.PoolDataSource;

public class TransactionLoadShipUnitsForTrailer {
	
	private DatabaseConnectionPoolSupport cps;
	private PoolDataSource pds;
	private Logger loggerObj;
	private ScandataCommunicationVariables scv;
	private String tc_shipment_id;
	private int total_lpn_count;
	private int loaded_lpn_count;
	public int errorCode;
	
	public TransactionLoadShipUnitsForTrailer ( DatabaseConnectionPoolSupport vcps, Logger vLoggerObj, ScandataCommunicationVariables vscv, String v_tc_shipment_id ) {
		this.cps = vcps;
		this.pds = this.cps.getPoolDataSource();
		this.loggerObj = vLoggerObj;
		this.scv = vscv;
		this.tc_shipment_id = v_tc_shipment_id;
		this.total_lpn_count = 0;
		this.loaded_lpn_count = 0;
		this.errorCode = -1;
	}
	
	public void processLoadShipUnitsForTrailer () {
		
		//get the number of invoiced cartons for the trailer
		total_lpn_count = get_invoiced_cartons_for_shipment( tc_shipment_id );
		
		if ( total_lpn_count > 0 ) {
			//some invoiced cartons exists
			errorCode = 0;
		} else { 
			errorCode = total_lpn_count;
		}
			
		if ( errorCode == 0 ) {
			loaded_lpn_count = load_all_cartons_in_scandata( tc_shipment_id, total_lpn_count, scv.max_cartons_in_request );
		}
		
		if ( total_lpn_count == loaded_lpn_count ) {
			errorCode = 0;
		}
				
	}
	
	private int get_invoiced_cartons_for_shipment ( String v_tc_shipment_id ) {
		
		loggerObj.info( v_tc_shipment_id + " : get_invoiced_cartons_for_shipment" );
		
		int v_carton_count = 0;
		
		try {
			Connection dbConn = pds.getConnection();
			
			try {	
				if ( dbConn != null ) {
					CallableStatement cstmt = dbConn.prepareCall("{? = call wmsops.jc_scandata_utils.get_invoiced_carton_count(?)}");
					cstmt.registerOutParameter( 1, Types.INTEGER );
					cstmt.setString( 2, v_tc_shipment_id );
					cstmt.executeUpdate();
					v_carton_count = cstmt.getInt(1);
				}
			} catch ( SQLException e ) {
				loggerObj.error ( this.tc_shipment_id + " : Unable to get cstmt to execute get_invoiced_carton_count.\n", e );
			} finally {
				if ( dbConn != null) {
					dbConn.close();
					dbConn = null;
				}
			}
			
			//loggerObj.debug ( clobToString( msgClobData ) );
			return v_carton_count;
		
		} catch ( SQLException e1 ) {
			loggerObj.error ( this.tc_shipment_id + " : Unable to execute statement.\n", e1 );
		}

		return v_carton_count;
	}

	private int load_all_cartons_in_scandata( String v_tc_shipment_id, int v_total_lpn_count, int v_max_cartons_in_request ) {
		
		loggerObj.info( this.tc_shipment_id + ": load_all_cartons_in_scandata" );
		
		int total_msgs = (int) Math.ceil(( (double) v_total_lpn_count )/v_max_cartons_in_request);
		int loaded_cartons = 0;
		
		for( int i=1; i<=total_msgs; i++ ) {
			String soap_response = load_ship_units_msg_scandata( v_tc_shipment_id, i );
			
			if ( ! soap_response.contentEquals( "0" ) ) {
				//process the response now
				int response_value = loadShipUnitProcessResponse( soap_response, v_tc_shipment_id + i );

				if ( response_value == -547 ) {
					//response had error indicating that loading already finished
					loaded_cartons = v_total_lpn_count;
					i = total_msgs + 1;
				} else {
					loaded_cartons = loaded_cartons + response_value;
				}
			} 
		}
		
		return loaded_cartons;
	}
	
	private String load_ship_units_msg_scandata( String v_tc_shipment_id, int msg_part ) {
        
		loggerObj.info( v_tc_shipment_id + " : part : " + msg_part + " loadShipUnitCreateRequest" );
		
		URL url;
        
        //Create SOAP Connection
        SOAPConnectionFactory soapConnectionFactory;
        SOAPConnection soapConnection;
        
		try {
			soapConnectionFactory = SOAPConnectionFactory.newInstance();
			soapConnection = soapConnectionFactory.createConnection();
			
			//Send SOAP Message to SOAP Server
	        url = new URL( scv.Scandata_URL );
	        HttpURLConnection con = (HttpURLConnection) url.openConnection();
	        con.connect();
	        
	        SOAPMessage request = loadShipUnitCreateRequest( v_tc_shipment_id, msg_part ); //carton, weight, warehouse, client, dstcar, dstsrv, shipPoint, billingAccount, srvlvl, sddflg);
	        //just for testing and development
	        //String soap_request = Convertor.convertSOAPToString(request);
	        //System.out.println( soap_request );

	        
	        SOAPMessage response = soapConnection.call( request, url );
	        String soap_response = Convertor.convertSOAPToString( response );
	        //System.out.println( soap_response );
	        return soap_response;
	        
	        //time to process the process the return
	        //upload all the response xml to db to process
	        //loadShipUnitProcessResponse( soap_response );
	        //System.out.println( labelUrl );
		} catch ( UnsupportedOperationException e ) {
			loggerObj.error ( this.tc_shipment_id + " : Soap message communication issue.\n", e );
		} catch (SOAPException e) {
			loggerObj.error ( this.tc_shipment_id + " : Soap message communication issue.\n", e );
		} catch (MalformedURLException e) {
			loggerObj.error ( this.tc_shipment_id + " : Soap message communication issue.\n", e );
		} catch (IOException e) {
			loggerObj.error ( this.tc_shipment_id + " : Soap message communication issue.\n", e );
		} catch (Exception e) {
			loggerObj.error ( this.tc_shipment_id + " : Soap message communication issue.\n", e );
		}		
	
		return "0";
	}

	private SOAPMessage loadShipUnitCreateRequest ( String v_tc_shipment_id, int msg_part ) {
		
		loggerObj.info( this.tc_shipment_id + " :, part : " + "msg_part : " + msg_part + "\n" + "loadShipUnitCreateRequest" );
		
		try {
			MessageFactory messageFactory = MessageFactory.newInstance();
			
			SOAPMessage soapMessage = messageFactory.createMessage();
	        SOAPPart soapPart = soapMessage.getSOAPPart();
	       
	        //StreamSource msgContent = new StreamSource( getcreateShipUnitMsgData ( v_tc_lpn_id ) );
	        Document doc = Convertor.convertStringToDocument( loadShipUnitGetMsgData ( v_tc_shipment_id, msg_part ) );
	        DOMSource domSource = new DOMSource( doc );
	        soapPart.setContent( domSource );
	        return soapMessage;
	        
		} catch ( SOAPException e ) {
			loggerObj.error ( this.tc_shipment_id + " : Soap message communication issue.\n", e );
		} catch (Exception e) {
			loggerObj.error ( this.tc_shipment_id + " : Soap message communication issue.\n", e );
		}
		
		return null;
	}

	private String loadShipUnitGetMsgData ( String v_tc_shipment_id, int msg_part ) {
		
		loggerObj.info( this.tc_shipment_id + " :, part : " + "msg_part : " + msg_part + "\n" + "loadShipUnitGetMsgData." );
		
		try {
			Connection dbConn = pds.getConnection();
			Clob msgClobData = dbConn.createClob();
			
			try {	
				if ( dbConn != null ) {
					CallableStatement cstmt = dbConn.prepareCall("{? = call wmsops.jc_scandata_itgl_msgs_gen.jc_scnd_msg_load_ship(?,?)}");
					cstmt.registerOutParameter( 1, Types.CLOB );
					cstmt.setString( 2, v_tc_shipment_id );
					cstmt.setInt( 3, msg_part );
					cstmt.executeUpdate();
					msgClobData = cstmt.getClob(1);
				}
			} catch ( SQLException e ) {
				loggerObj.error( this.tc_shipment_id + " : Error in data retrival jc_scnd_msg_load_ship.\n", e );
			} finally {
				if ( dbConn != null) {
					dbConn.close();
					dbConn = null;
				}
			}
			//System.out.println( clobToString( msgClobData ) );
			return Convertor.convertClobToString( msgClobData );
		} catch ( SQLException e ) {
			loggerObj.error( this.tc_shipment_id + " : Error in data retrival jc_scnd_msg_load_ship.\n", e );
		} catch ( Exception e ) {
			loggerObj.error( this.tc_shipment_id + " : Error in data retrival jc_scnd_msg_load_ship.\n", e );
		}
		return null;
	}

	private int loadShipUnitProcessResponse ( String v_soap_response, String v_shipment_part ) {
		
		loggerObj.info(  this.tc_shipment_id + " :, part : " + "v_shipment_part : " + v_shipment_part + "\n" + "loadShipUnitProcessResponse" );
		loggerObj.debug( this.tc_shipment_id + " :, part : " + "v_shipment_part : " + v_shipment_part + "\n" + v_soap_response );
		
		int v_loaded_cartons_in_msg = 0;
		
		try {
			Connection dbConn = pds.getConnection();
			
			try {	
				if ( dbConn != null ) {
					CallableStatement cstmt = dbConn.prepareCall("{? = call wmsops.jc_scandata_response_process.process_load_ship_reponse(?,?)}");
					cstmt.registerOutParameter( 1, Types.INTEGER );
					cstmt.setString( 2, v_soap_response );
					cstmt.setString( 3, v_shipment_part );
					cstmt.executeUpdate();
					v_loaded_cartons_in_msg = cstmt.getInt( 1 );
				}
			} catch ( SQLException e ) {
				loggerObj.error( "SQL Error.\n", e );
			} finally {
				if ( dbConn != null) {
					dbConn.close();
					dbConn = null;
				}
			}
		} catch ( SQLException e ) {
			loggerObj.error( this.tc_shipment_id + " :, part : " + "v_shipment_part : " + v_shipment_part + " : SQL Error in process_load_ship_reponse.\n", e );
		}
		
		return v_loaded_cartons_in_msg;
	}

	
}
