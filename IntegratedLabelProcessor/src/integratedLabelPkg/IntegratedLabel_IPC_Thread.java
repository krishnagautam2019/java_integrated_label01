package integratedLabelPkg;

import oracle.ucp.jdbc.PoolDataSource;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.Socket;
import java.net.SocketException;
import java.util.concurrent.ExecutorService;

import org.apache.logging.log4j.Logger;

//this is main thread that would normally read the file
class IntegratedLabel_IPC_Thread implements Runnable {
	
    private Socket socket;
    private int clientNumber;
	private PoolDataSource pds;
	private Logger loggerObj;
	private ExecutorService executor;
	private ScandataCommunicationVariables scv;
	//private PrinterSupport printers;
    //private static int ipcMaxIdleTime = 3000; //wait maximum 3000 millis
	
	IntegratedLabel_IPC_Thread ( Socket socket, int clientNumber, Logger vlogger, PoolDataSource vpds, ExecutorService vexecutor, ScandataCommunicationVariables vscv ) {
		boolean keepAliveToggle = true;
        try {
			this.loggerObj = vlogger;
			this.socket = socket;
			this.clientNumber = clientNumber;
			this.pds = vpds;
			this.executor = vexecutor;
			//this.printers = vprinters;
			this.scv = vscv;
			this.pds = vpds;
			
			if(keepAliveToggle) {
				loggerObj.debug("Keep alive Toggle is ON");
				if(!socket.getKeepAlive()) {
					socket.setKeepAlive(true);
					//loggerObj.debug("Keep Alive was OFF; has been switched ON");
				}
			} else {
				//loggerObj.debug("Keep Alive toggle is OFF");
				if(socket.getKeepAlive()) {
					//loggerObj.debug("Keep Alive is ON; setting it off");
					socket.setKeepAlive(false);
				}
			}
			//loggerObj.info("New connection with client# " + clientNumber + " at " + socket);
			//loggerObj.info("Log Level:" + loggerObj.getName() + " " +loggerObj.getLevel());
		} catch (SocketException e) {
			loggerObj.error("Exception in opening Socket. \n",e);
		}
	}
	
    public void run() {
		
		String ipcLine = "0";
		
        try {
            BufferedReader in = new BufferedReader( new InputStreamReader(socket.getInputStream()));
			
            // Get messages from the client, line by line; return them
            // only one message is going to ever come through so no while loop where
            //while (true) {
                
				StringBuilder requestLine = new StringBuilder();
				while (true) {
					int inputChar = in.read();
					if (inputChar == '\r' || inputChar == '\n' || inputChar == 3) {
						//do not add the last hex character to the string
						//requestLine.append((char) inputChar);
						break;
					}
					requestLine.append((char) inputChar);
					//loggerObj.trace(requestLine.toString());
				}
				ipcLine = requestLine.toString();
				loggerObj.debug(ipcLine);
									
				if( ipcLine != null ) {
                	  
					loggerObj.debug( "ipcLine : " + ipcLine );  
                	
                	//call the executor service 
                	Runnable processMsgTask = new ProcessIpcMessage( pds, loggerObj, ipcLine, scv );
      				loggerObj.trace( "Calling insert executor with " + ipcLine );
      				executor.execute( processMsgTask );
                  }
            //}
        } catch (IOException e) {
        	loggerObj.error("Error handling client# " + clientNumber + ": " + ipcLine + "\n", e);
        } finally {
            try {
                socket.close();
            } catch (IOException e) {
            	loggerObj.error("Couldn't close a socket, what's going on?",e);
            }
			loggerObj.debug("Connection with client# " + clientNumber + " closed");
        }   
    }	
}
