package integratedLabelPkg;

class ScandataCommunicationVariables {
	public String W3c_XML_Schema;
	public String Scandata_WTM_Schema;
	public String W3c_XML_Schema_Instance;
	public String Scandata_WTM;
	public String Scandata_URL;
	public int max_cartons_in_request;
	
	public ScandataCommunicationVariables ( String w3c_xml_schema, String scandata_wtm_schema, String w3c_xml_schema_instance, String scandata_wtm, String scandata_url, int v_max_cartons_in_request ) {
	    this.W3c_XML_Schema = w3c_xml_schema;
	    this.Scandata_WTM_Schema = scandata_wtm_schema;
	    this.W3c_XML_Schema_Instance = w3c_xml_schema_instance;
	    this.Scandata_WTM = scandata_wtm;
	    this.Scandata_URL = scandata_url;
	    this.max_cartons_in_request = v_max_cartons_in_request;
	}
	
	public ScandataCommunicationVariables ( ) {
	    this.W3c_XML_Schema = "http://ScanData.com/WTM/XMLSchemas/WTM_XMLSchema_14.00.0000.xsd";
	    this.Scandata_WTM_Schema = "http://jwe-rwscna-q01/WTMSERVICE/WTMService.asmx?WSDL";
	    this.W3c_XML_Schema_Instance = "http://ScanData.com/WTM/XMLSchemas/WTM_XMLSchema_14.00.0000.xsd";
	    this.Scandata_WTM = "http://ScanData.com/WTM/";
	    this.Scandata_URL = "http://jwe-rwscna-q01/WTMSERVICE/WTMService.asmx";
	    this.max_cartons_in_request = 100;
	    //loggerObj.trace ( "New Scandata communication variable created." );
	}
}
