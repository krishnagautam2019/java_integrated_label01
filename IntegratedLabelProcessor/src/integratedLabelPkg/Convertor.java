package integratedLabelPkg;

import java.io.Reader;
import java.io.StringReader;
import java.io.StringWriter;
import java.sql.Clob;

import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.soap.SOAPMessage;
import javax.xml.transform.Source;
import javax.xml.transform.Transformer;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.stream.StreamResult;

import org.w3c.dom.Document;
import org.xml.sax.InputSource;

public class Convertor {

	public static String convertSOAPToString( SOAPMessage soapMsg ) throws Exception {
        TransformerFactory transformerFactory = TransformerFactory.newInstance();
        Transformer transformer = transformerFactory.newTransformer();
        
        Source sourceContent = soapMsg.getSOAPPart().getContent();
        
        StringWriter soap_msg = new StringWriter();
        transformer.transform(sourceContent, new StreamResult(soap_msg));
        
        return soap_msg.toString();
    }

	public static String convertClobToString ( Clob inClob ) throws Exception {
		//convert clob to string type
		Reader r = inClob.getCharacterStream();
		StringBuffer buffer = new StringBuffer();
		int ch;
		while ( ( ch = r.read() ) != -1 ) {
			buffer.append( "" + (char) ch );
		}
		
		return buffer.toString();
	}
	
	public static Document convertStringToDocument( String xmlStr ) throws Exception {
        DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();  
        DocumentBuilder builder;  
        
        builder = factory.newDocumentBuilder();
        Document doc = builder.parse( new InputSource( new StringReader( xmlStr ) ) ); 
        return doc;
    }
	
}
