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

public class TransactionCreateShipUnit {
	
	private PoolDataSource pds;
	private Logger loggerObj;
	private ScandataCommunicationVariables scv;
	private String tc_lpn_id;
	private String ship_via;
	public int errorCode;
	public String labelUrl;
	
	public TransactionCreateShipUnit ( PoolDataSource vpds, Logger vLoggerObj, ScandataCommunicationVariables vscv, String v_tc_lpn_id ) {
		this.pds = vpds;
		this.loggerObj = vLoggerObj;
		this.scv = vscv;
		this.tc_lpn_id = v_tc_lpn_id;
		this.ship_via = "";
		this.errorCode = -1;
		this.labelUrl = new String();
	}
	
	public TransactionCreateShipUnit ( PoolDataSource vpds, Logger vLoggerObj, ScandataCommunicationVariables vscv, String v_tc_lpn_id, String v_ship_via ) {
		this.pds = vpds;
		this.loggerObj = vLoggerObj;
		this.scv = vscv;
		this.tc_lpn_id = v_tc_lpn_id;
		this.ship_via = v_ship_via;
		this.errorCode = -1;
		this.labelUrl = new String();
	}
	
	public void createShipUnitMsgScandata () {
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
	        
	        SOAPMessage request = createShipUnitCreateRequest( tc_lpn_id, ship_via ); //carton, weight, warehouse, client, dstcar, dstsrv, shipPoint, billingAccount, srvlvl, sddflg);
	        //just for testing and develoipment
	        //String soap_request = Convertor.convertSOAPToString(request);
	        //System.out.println( soap_request );

	        
	        SOAPMessage response = soapConnection.call( request, url );
	        String soap_response = Convertor.convertSOAPToString( response );
	        //System.out.println( soap_response );
	        //return soap_response;
	        
	        //time to process the process the return
	        //upload all the response xml to db to process
	        createShipUnitProcessResponse( soap_response );
	        //System.out.println( labelUrl );
		} catch ( UnsupportedOperationException e ) {
			loggerObj.error ( "Soap message communication issue.\n", e );
		} catch (SOAPException e) {
			loggerObj.error ( "Soap message communication issue.\n", e );
		} catch (MalformedURLException e) {
			loggerObj.error ( "Soap message communication issue.\n", e );
		} catch (IOException e) {
			loggerObj.error ( "Soap message communication issue.\n", e );
		} catch (Exception e) {
			loggerObj.error ( "Soap message communication issue.\n", e );
		}
		
	}

	private SOAPMessage createShipUnitCreateRequest ( String v_tc_lpn_id, String v_ship_via ) {
		
		loggerObj.debug( "createShipUnitCreateRequest for : " + v_tc_lpn_id );
		
		try {
			MessageFactory messageFactory = MessageFactory.newInstance();
			
			SOAPMessage soapMessage = messageFactory.createMessage();
	        SOAPPart soapPart = soapMessage.getSOAPPart();
	       
	        //StreamSource msgContent = new StreamSource( getcreateShipUnitMsgData ( v_tc_lpn_id ) );
	        Document doc = Convertor.convertStringToDocument( createShipUnitGetMsgData ( v_tc_lpn_id, v_ship_via ) );
	        DOMSource domSource = new DOMSource( doc );
	        soapPart.setContent( domSource );
	        return soapMessage;
	        
		} catch ( SOAPException e ) {
			loggerObj.error( "Soap exception.\n", e );
		} catch ( Exception e ) {
			loggerObj.error( "Soap exception.\n", e );
		}
		
		return null;
	}

	private String createShipUnitGetMsgData ( String v_tc_lpn_id, String v_ship_via ) {
		
		loggerObj.debug( "createShipUnitGetMsgData for : " + v_tc_lpn_id );
		
		try {
			Connection dbConn = pds.getConnection();
			Clob msgClobData = dbConn.createClob();
			
			try {	
				if ( dbConn != null ) {
					if ( v_ship_via != null && !v_ship_via.isEmpty() ) {
						CallableStatement cstmt = dbConn.prepareCall("{? = call wmsops.jc_scnadata_itgl_msgs_gen.jc_scnd_msg_create_ship_via(?,?)}");
						cstmt.registerOutParameter( 1, Types.CLOB );
						cstmt.setString( 2, v_tc_lpn_id );
						cstmt.setString( 3, v_ship_via );
						cstmt.executeUpdate();
						msgClobData = cstmt.getClob(1);						
					} else {
						CallableStatement cstmt = dbConn.prepareCall("{? = call wmsops.jc_scnadata_itgl_msgs_gen.jc_scnd_msg_create_ship_via(?)}");
						cstmt.registerOutParameter( 1, Types.CLOB );
						cstmt.setString( 2, v_tc_lpn_id );
						cstmt.executeUpdate();
						msgClobData = cstmt.getClob(1);
					}
				}
			} catch (SQLException e) {
				e.printStackTrace();
			} finally {
				if ( dbConn != null) {
					dbConn.close();
					dbConn = null;
				}
			}
			//System.out.println( Convertor.convertClobToString( msgClobData ) );
			return Convertor.convertClobToString( msgClobData );
		} catch ( SQLException e ) {
			loggerObj.error( "Statement execute error.\n", e );
		} catch ( Exception e ) {
			loggerObj.error( "Statement execute error.\n", e );
		}
		return null;
	}
	
	private void createShipUnitProcessResponse ( String v_soap_response ) {
		
		loggerObj.debug( "createShipUnitProcessResponse" );
		loggerObj.trace( "v_soap_response" + v_soap_response );
		
		try {
			Connection dbConn = pds.getConnection();
			String msgResponse = new String();
			
			try {	
				if ( dbConn != null ) {
					CallableStatement cstmt = dbConn.prepareCall("{? = call wmsops.jc_scandata_response_process.process_create_ship_reponse(?)}");
					cstmt.registerOutParameter( 1, Types.VARCHAR );
					cstmt.setString( 2, v_soap_response );
					cstmt.executeUpdate();
					msgResponse = cstmt.getString( 1 );
					
					if ( msgResponse.substring(0,4).contentEquals( "http" ) ) {
						errorCode = 0;
						labelUrl = msgResponse;
					} else {
						errorCode = Integer.parseInt(msgResponse);
					}
				}
			} catch ( SQLException e ) {
				loggerObj.error( "Statement execute error.\n", e );
			} finally {
				if ( dbConn != null) {
					dbConn.close();
					dbConn = null;
				}
			}
		} catch ( SQLException e ) {
			loggerObj.error( "Statement execute error.\n", e );
		}
	}

}
