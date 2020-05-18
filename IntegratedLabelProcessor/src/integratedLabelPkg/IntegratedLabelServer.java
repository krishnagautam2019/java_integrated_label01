package integratedLabelPkg;

import org.apache.logging.log4j.Logger;

import oracle.ucp.jdbc.PoolDataSource;
import oracle.ucp.jdbc.PoolDataSourceFactory;

import java.net.ServerSocket;
import java.sql.SQLException;
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
		PrinterSupport printers = new PrinterSupport();
        ExecutorService executor = Executors.newFixedThreadPool(10);
        PoolDataSource pds = connectionInit();
        
		//once the thread has been spawned lets get a connection pool going
		if ( pds == null) {
			try {
				pds = connectionInit();
			} catch ( Exception e ) {
				loggerObj.error( "Exception in trying to create DB connection. \n", e );
			}	
		}
        
        try {
            while (true) {
                new IntegratedLabel_IPC_Thread( listener.accept(), clientNumber++, loggerObj, pds, executor, scv, printers ).run();
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
	
	private static PoolDataSource connectionInit() {
		
		try {
			PoolDataSource localPds = PoolDataSourceFactory.getPoolDataSource();
			
			//Setting connection properties of the data source
			localPds.setConnectionFactoryClassName("oracle.jdbc.pool.OracleDataSource");
			
            ///*
            //options for prod
			localPds.setURL("jdbc:oracle:thin:@//jxr3-scan.jcrew.com:1521/rwmsq1_app.jcrew.com");
			localPds.setUser("wmsops");
			localPds.setPassword("o1p2s3wms");
            //*/
            
            /*
            // options for qa
            localPds.setURL("jdbc:oracle:thin:@//jxr3-scan.jcrew.com:1521/rwmsq1_app.jcrew.com");
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
}