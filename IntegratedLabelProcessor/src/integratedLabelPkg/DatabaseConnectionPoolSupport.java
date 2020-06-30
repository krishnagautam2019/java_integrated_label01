package integratedLabelPkg;

import java.sql.SQLException;

import oracle.ucp.jdbc.PoolDataSource;
import oracle.ucp.jdbc.PoolDataSourceFactory;

import org.apache.logging.log4j.Logger;

public class DatabaseConnectionPoolSupport {

	private PoolDataSource pds;
	private Logger loggerObj;
	
	private static String dbUrl = "jdbc:oracle:thin:@//jxr3-scan.jcrew.com:1521/rwmsp_app.jcrew.com";
	private static String dbUsername = "wmsops";
	private static String dbPassword = "o1p2s3wms";
	
	private static String  dbConnectionPoolName = "IntegratedLabelThread";
	private static Integer dbInitialPoolSize = 2;
	private static Integer dbMinPoolSize = 2;
	private static Integer dbMaxPoolSize = 40;
	
	/*
	DatabaseConnectionPoolSupport () {
		if ( this.pds == null) {
			try {
				this.pds = initializeConnectionPool();
			} catch ( Exception e ) {
				loggerObj.error( "Exception in trying to create DB connection. \n", e );
			}	
		}
	}
	*/

	DatabaseConnectionPoolSupport ( Logger v_loggerObj ) {
		this.loggerObj = v_loggerObj;
		
		if ( this.pds == null) {
			try {
				this.pds = initializeConnectionPool();
			} catch ( Exception e ) {
				loggerObj.error( "Exception in trying to create DB connection. \n", e );
			}	
		} 
	}
	
	DatabaseConnectionPoolSupport ( PoolDataSource v_pds, Logger v_loggerObj ) {
		this.loggerObj = v_loggerObj;
		
		if ( v_pds == null) {
			try {
				this.pds = initializeConnectionPool();
			} catch ( Exception e ) {
				loggerObj.error( "Exception in trying to create DB connection. \n", e );
			}	
		} else {
			this.pds = v_pds;
		}
	}
	
	public PoolDataSource getPoolDataSource() {
		
		if ( this.pds == null) {
			try {
				this.pds = initializeConnectionPool();
			} catch ( Exception e ) {
				loggerObj.error( "Exception in trying to create DB connection. \n", e );
			}	
		} 
		
		return this.pds;
	}
	
	public PoolDataSource restartPoolDataSource() {
		
		try {
			this.pds = initializeConnectionPool();
		} catch ( Exception e ) {
			loggerObj.error( "Exception in trying to create DB connection. \n", e );
		}	
		
		return this.pds;
	}
	
	private PoolDataSource initializeConnectionPool() {
		
		try {
			PoolDataSource localPds = PoolDataSourceFactory.getPoolDataSource();
			
			//Setting connection properties of the data source
			localPds.setConnectionFactoryClassName( "oracle.jdbc.pool.OracleDataSource" );
			
            //options for prod
			localPds.setURL( dbUrl );
			localPds.setUser( dbUsername );
			localPds.setPassword( dbPassword );
			
			//Setting pool properties
			localPds.setInitialPoolSize( dbInitialPoolSize );
			localPds.setMinPoolSize( dbMinPoolSize );
			localPds.setMaxPoolSize( dbMaxPoolSize );
			localPds.setAbandonedConnectionTimeout ( 10 );
			localPds.setTimeToLiveConnectionTimeout ( 600 );
			localPds.setConnectionPoolName ( dbConnectionPoolName );
			
			loggerObj.debug ( "Opening a new DB connection pool" );
			
			return localPds;
		} catch ( SQLException e ) {
			loggerObj.error( "Error trying initialize Connection Pool", e );
		}
		
		return null;
	}

}
