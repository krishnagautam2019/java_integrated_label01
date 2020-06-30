package integratedLabelPkg;

import javax.print.DocFlavor;
import javax.print.PrintService;
import javax.print.PrintServiceLookup;

public class PrinterSupport {
	
	public PrintService[] printServices;
	public String[] printerNames;
	
	PrinterSupport () {
		initializePrinterVariables();
	}
	
	PrinterSupport ( PrintService[] v_printServices, String[] v_printerNames ) {
		this.printServices = v_printServices;
		this.printerNames = v_printerNames;
	}
	
	public void initializePrinterVariables() {
		//discover all the printers that can be printed to 
		printServices = PrintServiceLookup.lookupPrintServices(DocFlavor.SERVICE_FORMATTED.PRINTABLE, null);
		
		int i = 0;
        printerNames = new String[printServices.length];
        for (PrintService printer : printServices) {
            //System.out.println("Printer: " + printer.getName()); 
        	printerNames[i] = printer.getName();
        	i = i + 1;
        }
	}
	
	public int getPrinterIndex( String v_printer_name ) {
        int j =0 ;
        int arrLength = printerNames.length;
        int resultIndex = 0;
        
        while ( j < arrLength ) {
        	if ( printerNames[j].contentEquals( v_printer_name ) ) {
        		resultIndex = j;
        		return resultIndex;
        	} else {
        		j = j + 1;
        	}
        }
        
        return resultIndex;
	}

}
