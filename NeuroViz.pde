import arduinoscope.*;
import processing.serial.*;
import controlP5.*;
import mindset.*;
import java.io.*;


/**** MindSetBTViewer.pde ****
** Modified from TestOscope.pde by Sean M. Montgomery 2010/09
** Arduinoscope program written for use with NeuroSky MindSet and 
** the MindSet Java library written by Robert King.
**
** -- Select the serialPort and plotVars to display (See User 
**   Selected Setup Variables below.)
** -- Data may be written to a csv file using the "RECORD" button.
** -- y-axis scale may be adjusted using the "*2" and "/2" buttons.
** -- y-axis scale and offset defaults may be adjusted in code below.
******************************/


/**** User Selected Setup Variables ****/

/***************************************/
// Use serialPort to select the correct serial port of your MindSet.
// See list printed on program start for serial port options.
String serialPort = "COM3"; 

/* plotVars determines which variables are plotted and in which order
Options are:
Raw
BatteryLevel
ErrorRate
Attention
Meditation
Delta
Theta
Alpha1
Alpha2
Beta1
Beta2
Gamma1
Gamma2
*/

/* Define which variables display on screen*/
String[] plotVars = {"Raw", "Attention", "Meditation", "ErrorRate"};

/*Define which data to log (time stamps not optional)*/
String[] recordVars = {"Raw", "BatteryLevel","ErrorRate","Attention","Meditation","Delta","Theta","Alpha1","Alpha2","Beta1","Beta2","Gamma1","Gamma2"};


// yOffsets sets the y-axis offset for each plotVar
// offset the raw data (1st variable) by half the default scope resolution
// to prevent negative values from extending into other windows
int[] yOffsets = {512,1,1,1,1,1,1,1,1,1};

// yFactors sets the default y-axis scale for each plotVar
// yFactors can also be adjusted using buttons in the display window
float[] yFactors = {1f,1*8f,1*8f,1*8f,1f,1f,1f,1f,1f,1f,1f,1f,1f,1f,1f,1f}; 

// Directory and name of your saved MindSet data. Make sure you 
// have write privileges to that location.
//if PC
//String saveDir = "C:\\Users\\Bobby\\My Documents\\Processing\\MindSetBTViewer\\Results\\";

//if OSX
//String saveDir = "C:\\Users\\Bobby\\My Documents\\Processing\\MindSetBTViewer\\Results\\";
String saveDir = "C:\\Users\\rbeaton\\Documents\\Results\\";

String[] fName = {saveDir, "MindSetData", nf(year(),4), nf(month(),2), nf(day(),2), 
  nf(hour(),2), nf(minute(),2), nf(second(),2), "csv"};
String saveFileName = join(fName, '.');

// Choose window dimensions in number of pixels
int windowWidth = 1200; 
int windowHeight = 800;


/*******************************************/
/**** END User Selected Setup Variables ****/

int stamps = 1;
int answer = 1;

int numScopes = plotVars.length;

// all plots default to off
int plotRaw = -1;
int plotBatteryLevel = -1;
int plotErrorRate = -1;
int plotAttention = -1;
int plotMeditation = -1;
int plotDelta = -1;
int plotTheta = -1;
int plotAlpha1 = -1;
int plotAlpha2 = -1;
int plotBeta1 = -1;
int plotBeta2 = -1;
int plotGamma1 = -1;
int plotGamma2 = -1;
/* User-defined metrics here */
//int plotEngagement = -1;

// all records default to off
int recordRaw = -1;
int recordBatteryLevel = -1;
int recordErrorRate = -1;
int recordAttention = -1;
int recordMeditation = -1;
int recordDelta = -1;
int recordTheta = -1;
int recordAlpha1 = -1;
int recordAlpha2 = -1;
int recordBeta1 = -1;
int recordBeta2 = -1;
int recordGamma1 = -1;
int recordGamma2 = -1;
/* User-defined metrics here */
//int recordEngagement = -1;

boolean saveDataBool = false; // wait until user turns on recording
boolean firstSave = true; // data has not been saved yet

MindSet mindset; 

Oscilloscope[] scopes = new Oscilloscope[numScopes];
Serial port;
ControlP5 controlP5;
PrintWriter output = null;

int LINE_FEED=10; 
int[] vals;
int[] vals2;


/*******************************************/
/**** Setup Code ****/
void setup() {
  size(windowWidth, windowHeight, P2D);
  background(0);

  controlP5 = new ControlP5(this);

  int[] dimv = new int[2];
  dimv[0] = width-130; // 130 margin for text
  dimv[1] = height/scopes.length;

  // setup vals from serial
  vals = new int[scopes.length];
  vals2 = new int[recordVars.length];


  for (int i=0;i<scopes.length;i++){
    int[] posv = new int[2];
    posv[0]=0;
    posv[1]=dimv[1]*i;

    // random color, that will look nice and be visible
    scopes[i] = new Oscilloscope(this, posv, dimv);
    scopes[i].setLine_color(color((int)random(255), (int)random(127)+127, 255)); 

    // yFactor buttons
    controlP5.addButton("*2 " + i,1,dimv[0]+10,posv[1]+20,20,20).setId(i);  
    controlP5.addButton("/2 " + i,1,dimv[0]+10,posv[1]+70,20,20).setId(20+i);
  }
  
  /* Define buttons */
  controlP5.addButton("Record",1,dimv[0]+85,5,40,20).setId(1000);
  controlP5.controller("Record").setColorBackground( color( 0, 255 , 0 ) );
  controlP5.controller("Record").setColorLabel(0);
  
  controlP5.addButton("Pause",1,dimv[0]+85,30,40,20).setId(1100);
  controlP5.addButton("Start",1,dimv[0]+85,55,40,20).setId(1200);
  controlP5.addButton("Answer",1,dimv[0]+85,80,40,20).setId(1300);
  controlP5.addButton("Stop",1,dimv[0]+85,105,40,20).setId(1400);  

  controlP5.addTextlabel("NOTRECORDING")
                    .setText("NOT RECORDING DATA.  PRESS \"RECORD\" TO BEGIN.")
                    .setPosition(150,50)
                    .setFont(createFont("Georgia",32))
                    .setColorValue(0xffff0000)
                    ;
  controlP5.controller("NOTRECORDING").show();                  
  
  controlP5.addTextlabel("RECORDING")
                    .setText(" RECORDING DATA")
                    .setPosition(400,50)
                    .setFont(createFont("Georgia",32))
                    .setColorValue(0xff7fff00)
                    ;
  controlP5.controller("RECORDING").hide();                  

                    
  // setup serial port     
  println(Serial.list());
  //port = new Serial(this, Serial.list()[serialPortNum], 57600);
  // clear and wait for linefeed
  //port.clear();
  //port.bufferUntil(LINE_FEED);

  /* Establish connection to Mindset*/
  mindset = new MindSet(this);
  mindset.connect(serialPort);  
  
  
  ParsePlotVars();
  ParseRecordVars();
}

/*******************************************/
/**** Setup scopes drawing display ****/
void draw() {
  background(0);

  for (int i=0;i<scopes.length;i++){

    scopes[i].addData(int(vals[i] * yFactors[i]) + yOffsets[i]);
    scopes[i].draw();

    scopes[i].drawBounds();   
    stroke(255);

    int[] pos = scopes[i].getPos();
    int[] dim = scopes[i].getDim();

    // separator lines
    line(0, pos[1], width, pos[1]);

    if (true) {
      // yfactor text
      fill(255);
      text("y * " + yFactors[i], dim[0] + 10,pos[1] + 60); 
    }
    
    // variable name text
    fill(scopes[i].getLine_color());
    text(plotVars[i], dim[0] + 10, pos[1] + 15);
  }    

  // draw text seperator, based on first scope
  int[] dim = scopes[0].getDim();
  stroke(255);
  line(dim[0], 0, dim[0], height);

  // update buttons
  if (true) {
    controlP5.draw();
  }
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
void mindSetRawEvent(MindSet ms){
  if (plotRaw >= 0) {
    vals[plotRaw] = ms.getCurrentRawData();
  }
  if (recordRaw >= 0) {
    vals2[recordRaw] = ms.getCurrentRawData();
  }
  if (saveDataBool)
  {
    SaveData();
  }
  println(ms.data.alpha1);
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
void mindSetEvent(MindSet ms) {
  if (plotBatteryLevel >= 0)
    vals[plotBatteryLevel] = ms.data.batteryLevel;
  if (plotErrorRate >= 0)
    vals[plotErrorRate] = ms.data.errorRate;
  if (plotAttention >= 0)
    vals[plotAttention] = ms.data.attention;
  if (plotMeditation >= 0)
    vals[plotMeditation] = ms.data.meditation;
  if (plotDelta >= 0)
    vals[plotDelta] = ms.data.delta;
  if (plotTheta >= 0)
    vals[plotTheta] = ms.data.theta;
  if (plotAlpha1 >= 0)
    vals[plotAlpha1] = ms.data.alpha1;
  if (plotAlpha2 >= 0)
    vals[plotAlpha2] = ms.data.alpha2;
  if (plotBeta1 >= 0)
    vals[plotBeta1] = ms.data.beta1;
  if (plotBeta2 >= 0)
    vals[plotBeta2] = ms.data.beta2;
  if (plotGamma1 >= 0)
    vals[plotGamma1] = ms.data.gamma1;
  if (plotGamma2 >= 0)
    vals[plotGamma2] = ms.data.gamma2;
//  if (plotEngagement >=0)
//    vals[plotEngagement] = max(ms.data.beta1, ms.data.beta2)/(max(ms.data.alpha1, ms.data.alpha2) + ms.data.theta);

  if (recordBatteryLevel >= 0)
    vals2[recordBatteryLevel] = ms.data.batteryLevel;
  if (recordErrorRate >= 0)
    vals2[recordErrorRate] = ms.data.errorRate;
  if (recordAttention >= 0)
    vals2[recordAttention] = ms.data.attention;
  if (recordMeditation >= 0)
    vals2[recordMeditation] = ms.data.meditation;
  if (recordDelta >= 0)
    vals2[recordDelta] = ms.data.delta;
  if (recordTheta >= 0)
    vals2[recordTheta] = ms.data.theta;
  if (recordAlpha1 >= 0)
    vals2[recordAlpha1] = ms.data.alpha1;
  if (recordAlpha2 >= 0)
    vals2[recordAlpha2] = ms.data.alpha2;
  if (recordBeta1 >= 0)
    vals2[recordBeta1] = ms.data.beta1;
  if (recordBeta2 >= 0)
    vals2[recordBeta2] = ms.data.beta2;
  if (recordGamma1 >= 0)
    vals2[recordGamma1] = ms.data.gamma1;
  if (recordGamma2 >= 0)
    vals2[recordGamma2] = ms.data.gamma2;
//  if (recordEngagement >= 0)
//    vals2[recordEngagement] = max(ms.data.beta1, ms.data.beta2)/(max(ms.data.alpha1, ms.data.alpha2) + ms.data.theta);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
void SaveData() {
  // save all plotVars
  output.print(System.currentTimeMillis() / 1000L + ", ");
  output.print(minute() + ":" + second() + ":" + millis() + ":" + ", ");
  output.print(join(nf(vals2,0),',')); 
  output.println(""); 
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
// handles button clicks
void controlEvent(ControlEvent theEvent) {
  int id = theEvent.controller().id();

  if (id < 20) { // increase yFactor
    yFactors[id] = yFactors[id] * 2;
  } 
  else if (id < 40){ // decrease yFactor
    yFactors[id-20] = yFactors[id-20] / 2;
  } 
  else if ( id == 1100) { // pause display
    for (int i=0; i<numScopes; i++) {
      scopes[i].setPause(!scopes[i].isPause());
    }
  }
  else if (id == 1200) { // adds begin stamp into results file
     if (saveDataBool == true){
        output.println("########## BEGIN STAMP FOR PART " + stamps + " ##########");     }
  }  

  else if (id == 1300) { // adds answer stamp into results file
     if (saveDataBool == true){
        output.println("########## ANSWER STAMP FOR QUESTION " + answer + " ##########");     }
        answer++;
  } 

  else if (id == 1400) { // adds stop stamp into results file
     if (saveDataBool == true){
        output.println("########## STOP STAMP FOR PART " + stamps + " ##########");     }
        answer = 1;
        stamps++; 
  }   
  
  
  else if (id == 1000) { // Record/Stop button
    if (saveDataBool == false) // Start Recording
    {
      try {
        output = new PrintWriter(new FileWriter(saveFileName, true));
      } 
      catch (IOException e) {
        e.printStackTrace(); 
        print("ERROR: e.printStackTrace(); ");
      }
      
      if (firstSave) {
        output.print("unixTimestamp, stdTimestamp, ");
        output.print(join(recordVars,','));
        output.println("");
        firstSave = false;
      }

      saveDataBool = true;
      controlP5.controller("Record").setCaptionLabel("Stop");
      controlP5.controller("Record").setColorBackground( color( 255,0,0 ) );
      controlP5.controller("NOTRECORDING").hide();
      controlP5.controller("RECORDING").show(); 
     } 
    

    else { // Stop Recording
      saveDataBool = false;
      output.flush();
      output.close();
      controlP5.controller("Record").setCaptionLabel("Record");
      controlP5.controller("Record").setColorBackground( color( 0,255,0 ) );
      controlP5.controller("NOTRECORDING").show();
      controlP5.controller("RECORDING").hide(); 
      
    }
  } // id == 1000
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
void ParsePlotVars() {
  for (int i=0; i<plotVars.length; i++) {
    if (plotVars[i].equals("Raw"))
      plotRaw = i;
    else if (plotVars[i].equals("BatteryLevel"))
      plotBatteryLevel = i;
    else if (plotVars[i].equals("ErrorRate"))
      plotErrorRate = i;
    else if (plotVars[i].equals("Attention"))
      plotAttention = i;
    else if (plotVars[i].equals("Meditation"))
      plotMeditation = i;
    else if (plotVars[i].equals("Delta"))
      plotDelta = i;
    else if (plotVars[i].equals("Theta"))
      plotTheta = i;
    else if (plotVars[i].equals("Alpha1"))
      plotAlpha1 = i;
    else if (plotVars[i].equals("Alpha2"))
      plotAlpha2 = i;
    else if (plotVars[i].equals("Beta1"))
      plotBeta1 = i;
    else if (plotVars[i].equals("Beta2"))
      plotBeta2 = i;
    else if (plotVars[i].equals("Gamma1"))
      plotGamma1 = i;
    else if (plotVars[i].equals("Gamma2"))
      plotGamma2 = i;
//    else if (plotVars[i].equals("Engagement"))
//      plotEngagement = i;  
  }
}

void ParseRecordVars() {
  for (int i=0; i<recordVars.length; i++) {
    if (recordVars[i].equals("Raw"))
      recordRaw = i;
    else if (recordVars[i].equals("BatteryLevel"))
      recordBatteryLevel = i;
    else if (recordVars[i].equals("ErrorRate"))
      recordErrorRate = i;
    else if (recordVars[i].equals("Attention"))
      recordAttention = i;
    else if (recordVars[i].equals("Meditation"))
      recordMeditation = i;
    else if (recordVars[i].equals("Delta"))
      recordDelta = i;
    else if (recordVars[i].equals("Theta"))
      recordTheta = i;
    else if (recordVars[i].equals("Alpha1"))
      recordAlpha1 = i;
    else if (recordVars[i].equals("Alpha2"))
      recordAlpha2 = i;
    else if (recordVars[i].equals("Beta1"))
      recordBeta1 = i;
    else if (recordVars[i].equals("Beta2"))
      recordBeta2 = i;
    else if (recordVars[i].equals("Gamma1"))
      recordGamma1 = i;
    else if (recordVars[i].equals("Gamma2"))
      recordGamma2 = i;
//    else if (recordVars[i].equals("Engagement"))
//      recordEngagement = i;  
  }
}
