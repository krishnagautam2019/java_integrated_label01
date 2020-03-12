package integratedLabelPkg;

import oracle.ucp.jdbc.PoolDataSource;
import oracle.ucp.jdbc.PoolDataSourceFactory;

import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.RandomAccessFile;

import java.sql.SQLException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

import org.apache.logging.log4j.Logger;

//this is main thread that would normally read the file
class IntegratedLabel_IPC_Thread implements Runnable {
	
	private String pipeName;
	private PoolDataSource pds;
	private Logger loggerObj;
    private static int ipcMaxIdleTime = 3000; //wait maximum 3000 millis
	
	IntegratedLabel_IPC_Thread ( Logger vlogger, String vPipeName ) {
		this.loggerObj = vlogger;
		this.pipeName = vPipeName;
	}
	
	public void run() {
		loggerObj.trace ( " In the IPC thread" );
		
		//once the thread has been spawned lets get a connection pool going
		if ( pds == null) {
			try {
				pds = connectionInit();
			} catch ( Exception e ) {
				loggerObj.error( "Exception in trying to create DB connection. \n", e );
			}	
		}
		
		//lets create a new thread pool for processing the inputs received
		ScandataCommunicationVariables scv = new ScandataCommunicationVariables();
		PrinterSupport printers = new PrinterSupport();
		ExecutorService executor = Executors.newFixedThreadPool(10);
		
		
		//get to to main part of the program
		try {
			//start reading from the pipe here
			//open or re-open the file after 3 seconds
            for ( ; ; ) {
            	loggerObj.info ( "IPC File : " + pipeName );
                RandomAccessFile pipe = new RandomAccessFile( pipeName, "r" );
                String ipcLine = null;  
                int ipcIdleTime = 0;

                for( ; ipcIdleTime < ipcMaxIdleTime; ) {
                      ipcLine = pipe.readLine();         
       
                      //Take care to check the line -
                      //it is null when the pipe has no more available data. 
                      if( ipcLine != null ) {
                    	  
                    	  loggerObj.debug( "ipcLine : " + ipcLine );  
                    	  
                    	  //call the executor service 
                    	  Runnable processMsgTask = new ProcessIpcMessage( pds, loggerObj, ipcLine, scv, printers );
          				  loggerObj.trace( "Calling insert executor with " + ipcLine );
          				  executor.execute( processMsgTask );
          				
          				  ipcIdleTime = 0;
                      } else {
                    	  Thread.sleep( 100 );
                          ipcIdleTime += 100;  
                     }
                }
                
                //here - we got NULL line, re-open the RandomAccessFile  again
                //lets try to close the previously opened pipe
                try {
                	pipe.close();
                } finally {
        			loggerObj.error( "Unable to close the IPC file" );
        		}
            }            			
		} catch ( FileNotFoundException e ) {
			//catch exception in opening the named pipe
			loggerObj.error( "Issue with reading the IPC file. \n", e );
		} catch ( IOException e ) {
			//catch exception in reading the named pipe
			loggerObj.error( "Issue with reading the IPC file. \n", e );
		} catch ( InterruptedException e ) {
			//exception occurred during trying to put the thread to sleep
			loggerObj.error( "Issue with reading the IPC file. \n", e );
		} finally {
			try {
				executor.shutdown();
				executor.awaitTermination(1, TimeUnit.SECONDS);
			} catch ( InterruptedException e ) {
				loggerObj.error( "Issue closing the excutor service. \n", e );
			}
			
			loggerObj.debug( "Closed the file access, wil try to open a new one." );
		}
	}
	
	private PoolDataSource connectionInit() {
		
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
