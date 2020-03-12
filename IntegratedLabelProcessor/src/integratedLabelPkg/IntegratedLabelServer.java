package integratedLabelPkg;

import org.apache.logging.log4j.Logger;
import org.apache.logging.log4j.LogManager;

/**
 * The program is runs in an infinite loop, so shutdown in platform dependent.
 * If you ran it from a console window with the "java" interpreter, Ctrl+C
 * generally will shut it down.
**/
public class IntegratedLabelServer {
	
	private static final Logger loggerObj = LogManager.getLogger( IntegratedLabelServer.class.getName() );

    /**
     * Application method to run the server runs in an infinite loop listening
     * on port 37000. When a connection is requested, it spawns a new thread to
     * do the servicing and immediately returns to listening. The server keeps a
     * unique client number for each client that connects just to show
     * interesting logging messages. It is certainly not necessary to do this.
     **/
	public static void main( String[] args ) throws Exception {
    	
		loggerObj.info ( "The Integrated Label server is running.");
		
		//setup environment variables or parameters
		String pipeName = args[0];
		if ( ( pipeName.length() <= 0 ) || pipeName.isEmpty() ) {
			pipeName = "/apps/IPC_wms_app/integratedLabelIPC_Pipe01";
		}
    	
		int clientNumber = 0;
		try {
			//todo: respawn the thread after it ties
			//System.out.println ( "Spawning the IPC threrad # " + clientNumber++ );
			loggerObj.info ( "Spawning the IPC threrad # " + clientNumber++ );
			new IntegratedLabel_IPC_Thread( loggerObj, pipeName ).run();
		} finally {
			loggerObj.info ( "Exiting the program entirelly.");
		}
	}
}