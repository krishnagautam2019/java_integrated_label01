package integratedLabelPkg;

import org.apache.logging.log4j.Logger;


import java.net.ServerSocket;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

import org.apache.logging.log4j.LogManager;

/**
 * The program is runs in an infinite loop, so shutdown in platform dependent.
 * If you ran it from a console window with the "java" interpreter, Ctrl+C
 * generally will shut it down.
**/
public class IntegratedLabelServer {
	
	private static final Integer threadPoolSize = 10;
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
			
        int clientNumber = 0;
        
        //lets create a new thread pool for processing the inputs received
		ServerSocket listener = new ServerSocket(37000);
		ScandataCommunicationVariables scv = new ScandataCommunicationVariables();
		//PrinterSupport printers = new PrinterSupport();
        ExecutorService executor = Executors.newFixedThreadPool( threadPoolSize );
        DatabaseConnectionPoolSupport cps = new DatabaseConnectionPoolSupport( loggerObj );
        
        try {
            while (true) {
                new IntegratedLabel_IPC_Thread( listener.accept(), clientNumber++, loggerObj, cps, executor, scv ).run();
                loggerObj.info("The server is now listening on port 37000.");
                
                if ( clientNumber == 9998 ) {
                	clientNumber = 0;
                }
            }
        } finally {
            listener.close();
			try {
				executor.shutdown();
				executor.awaitTermination(1, TimeUnit.SECONDS);
			} catch ( InterruptedException e ) {
				loggerObj.error( "Issue closing the excutor service. \n", e );
			}
		}

	}
	
}