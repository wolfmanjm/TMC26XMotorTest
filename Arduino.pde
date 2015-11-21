/*
 TMC26XMotorTest.pde - - TMC26X Stepper Tester for Processing

 Copyright (c) 2011, Interactive Matter, Marcus Nowotny

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.

 */

String channelAStatus = null;
String channelBStatus = null;
String temperatureStatus = null;
boolean motor_connected = false;

RadioButton serialButtons;
Button serialOkButton;
Button helpButton;
Textarea statusArea;

int activePortIndex = -1;
int microstepping = 32;


String identString = "Smoothie";
int connectTimeout = 10 * 1000; //how long do we wait until the Arduino is connected
String[] ports = {"/dev/ttyUSB0", "/dev/ttyUSB1", "/dev/ttyACM0", "/dev/ttyACM1"};
StringBuilder serialStringBuilder = new StringBuilder();

void setupSerialConfig()
{
    Tab defaultTab = controlP5.getTab("default");
    //add the list of serial interfaces - it get's populated later
    serialButtons = controlP5.addRadioButton("serialport", 200, 100 + TMCLogo.height * 2 + 50);
    serialConfigElements.add(serialButtons);
    serialButtons.getCaptionLabel().set("Select Serial Port");
    serialButtons.showBar();
    serialButtons.moveTo(defaultTab);
    //ad the ok button
    serialOkButton = controlP5.addButton("serialOk").setValue(1).setPosition(200, height - 300).setSize(30, 30);
    serialConfigElements.add(serialOkButton);
    serialOkButton.setCaptionLabel("OK");
    runToggle.moveTo(defaultTab);
    //add the status area
    statusArea = controlP5.addTextarea("statusArea", "", 200, height - 250, 300, 50);
    serialConfigElements.add(statusArea);
    statusArea.moveTo(defaultTab);

    //helpButton =  controlP5.addButton("help").setValue(1).setPosition(200, height-50).setSize(80, 30);
    //serialConfigElements.add(helpButton);
    //helpButton.moveTo(defaultTab);


    //finally update the list of serial ports
    updateSerialPortList();
}

void updateSerialPortList()
{
    //first remove all present serial ports
    List items = serialButtons.getItems();
    for (Object i : items) {
        Toggle item = (Toggle) i;
        serialButtons.removeItem(item.getName());
    }

    //add the serial ports
    //ports = Serial.list();

    for (int i = 0; i < ports.length; i++) {
        serialButtons.addItem(ports[i], i);
    }
    serialButtons.setValue(-1);
    serialOkButton.setVisible(false);
}

void serialport(int value)
{
    //ok button is only active if a serial port is selected
    serialOkButton.setVisible(value > -1);
    if (value > -1) {
        statusArea.setText("");
    }
    activePortIndex = value;
}

void serialOk(int value)
{

    String error = null;
    if (value != 0 && activePortIndex > -1) {
        try {
            arduinoPort = new Serial(this, ports[activePortIndex], 115200);
            int timeStarted = millis();
            StringBuilder identBuffer = new StringBuilder();
            while (!motor_connected && (millis() - timeStarted) < connectTimeout) {
                if (arduinoPort.available () > 0) {
                    char c = arduinoPort.readChar();
                    identBuffer.append(c);
                    if (c == '\n') {
                        if (identString.contains(identString)) {
                            motor_connected = true;
                            toggleUi(true);
                            return;
                        }
                        identBuffer = new StringBuilder();
                    }
                }
            }
        } catch (RuntimeException e) {
            //we simply do nothing
            //TODO set status label
            error = "There was a problem with serial port " + ports[activePortIndex] + ": " + e.getMessage();
        }
        //ok appearantly we did not find an motor tester - so lets deselect that port
        if (error == null) {
            error = "Could not find Smoothie on serial port " + ports[activePortIndex];
        }
        statusArea.setText(error);
        Toggle selected = serialButtons.getItem(activePortIndex);
        selected.setState(false);
        serialOkButton.setVisible(false);
    }
}

int last_time= 0;
boolean requested= false;
void decodeSerial()
{
    if (motor_connected) {
        int now= millis();
        if((now - last_time) < 100) return;
        if(!requested) {
            // request status in machine readable format
            requested= true;
            send("M911.1 P1 X0");
        }
        while (arduinoPort.available() > 0) {
            char c = arduinoPort.readChar();
            serialStringBuilder.append(c);
            if (c == '\n') {
                if(decodeSerial(serialStringBuilder.toString())){
                    last_time= now;
                    requested= false;
                }
                serialStringBuilder = new StringBuilder();
            }
        }
    }
}

void sendCommand(String command)
{
    //println("sendCommand: ", command);
    executeSerialCommand(command);
}

boolean decodeSerial(String line)
{
    if (line.startsWith("#")) {
        settingStatus = true;
        String status = line.substring(1);
        StringTokenizer statusTokenizer = new StringTokenizer(status, ",");
        while (statusTokenizer.hasMoreTokens ()) {
            String statusToken = statusTokenizer.nextToken();
            if ("s".equals(statusToken)) {
                runToggle.setValue(0);
            } else if ("r".equals(statusToken)) {
                runToggle.setValue(1);
            } else if (statusToken.startsWith("e")) {
                int enabled = getValueOfToken(statusToken, 1);
                if (enabled != 0) {
                    enabledToggle.setValue(1);
                } else {
                    enabledToggle.setValue(0);
                }
            } else if (statusToken.startsWith("S")) {
                speedSlider.setValue(getValueOfToken(statusToken, 1));
            } else if (statusToken.startsWith("m")) {
                microstepping = getValueOfToken(statusToken, 1);
                microsteppingButtons.activate("m_1/" + String.valueOf(microstepping));
            } else if (statusToken.startsWith("sg")) {
                addStallGuardReading(getValueOfToken(statusToken, 2));
            } else if (statusToken.startsWith("p")) {
                addPositionReading((getValueOfToken(statusToken, 1)/microstepping)%1024);
            } else if (statusToken.startsWith("k")) {
                addCurrentReading(getValueOfToken(statusToken, 1));
            } else if (statusToken.startsWith("t")) {
                sgtSlider.setValue(getValueOfToken(statusToken, 1));
            } else if (statusToken.startsWith("f")) {
                sgFilterToggle.setValue(getValueOfToken(statusToken, 1));
            } else if (statusToken.startsWith("d")) {
                setDirection(getValueOfToken(statusToken, 1));
            } else if (statusToken.startsWith("c")) {
                setCurrent(getValueOfToken(statusToken, 1));
            } else if (statusToken.startsWith("a")) {
                if (statusToken.charAt(1) == 'o') {
                    channelAStatus = "Open Load";
                } else if (statusToken.charAt(1) == 'g') {
                    channelAStatus = "Short to Ground!";
                } else {
                    channelAStatus = null;
                }
            } else if (statusToken.startsWith("b")) {
                if (statusToken.charAt(1) == 'o') {
                    channelBStatus = "Open Load";
                } else if (statusToken.charAt(1) == 'g') {
                    channelBStatus = "Short to Ground!";
                } else {
                    channelBStatus = null;
                }
            } else if (statusToken.startsWith("x")) {
                if (statusToken.charAt(1) == 'w') {
                    temperatureStatus = "Prewarning!";
                } else if (statusToken.charAt(1) == 'e') {
                    temperatureStatus = "Error";
                } else {
                    temperatureStatus = null;
                }
            } else if (statusToken.startsWith("Cm")) {
                //chopper mode is currently ignored
            } else if (statusToken.startsWith("Co")) {
                constantOffSlider.setValue(getValueOfToken(statusToken, 2));
            } else if (statusToken.startsWith("Cb")) {
                blankTimeSlider.setValue(getValueOfToken(statusToken, 2));
            } else if (statusToken.startsWith("Cs")) {
                hysteresisStartSlider.setValue(getValueOfToken(statusToken, 2));
            } else if (statusToken.startsWith("Ce")) {
                hysteresisEndSlider.setValue(getValueOfToken(statusToken, 2));
            } else if (statusToken.startsWith("Cd")) {
                setHystDecrement(getValueOfToken(statusToken, 2));
            } else if ("Ke+".equals(statusToken)) {
                coolStepActiveToggle.setValue(1);
            } else if ("Ke-".equals(statusToken)) {
                coolStepActiveToggle.setValue(0);
            } else if (statusToken.startsWith("Kl")) {
                coolStepMinSlider.setValue(getValueOfToken(statusToken, 2));
            } else if (statusToken.startsWith("Ku")) {
                coolStepMaxSlider.setValue(getValueOfToken(statusToken, 2));
            } else if (statusToken.startsWith("Kn")) {
                coolStepDecrementButtons.activate(getValueOfToken(statusToken, 2));
            } else if (statusToken.startsWith("Ki")) {
                coolStepIncrementButtons.activate(getValueOfToken(statusToken, 2));
            } else if (statusToken.startsWith("Km")) {
                coolStepMinButtons.activate(getValueOfToken(statusToken, 2));
            }
        }
        settingStatus = false;
        return true;

    } else {
        println(line);
        return false;
    }
}

int getValueOfToken(String token, int position)
{
    String value = token.substring(position);
    try {
        return Integer.valueOf(value);
    } catch (NumberFormatException e) {
        println("Unable to decode '" + value + "'of '" + token + "' !");
        return 0;
    }
}

void drawSerial()
{
    //draw the logo and some epxlaining text while setting up the serial port
    if (!motor_connected) {
        image(TMCLogo, 200, 100);
        fill(uiTextColor);
        text("Select the serial port where your Arduino is connected\nIf in doubt check it in the Arduino IDE.\nThe Motor Tester will automatically verify if it can find an Motor tester ath the port.", 200, 100 + TMCLogo.height + 50);
    }
}

void help(float value)
{
    if (value != 0) {
        link(helpUrl);
    }
}


// M911.3 Pn Onnn Qnnn setStallGuardThreshold O=stall_guard_threshold, Q=stall_guard_filter_enabled
// M911.3 Pn Hnnn Innn Jnnn Knnn Lnnn setCoolStepConfiguration H=lower_SG_threshold, I=SG_hysteresis, J=current_decrement_step_size, K=current_increment_step_size, L=lower_current_limit
// M911.3 Pn S0 Unnn Vnnn Wnnn Xnnn Ynnn setConstantOffTimeChopper  U=constant_off_time, V=blank_time, W=fast_decay_time_setting, X=sine_wave_offset, Y=use_current_comparator
// M911.3 Pn S1 Unnn Vnnn Wnnn Xnnn Ynnn setSpreadCycleChopper  U=constant_off_time, V=blank_time, W=hysteresis_start, X=hysteresis_end, Y=hysteresis_decrement
// M911.3 Pn S2 Zn setRandomOffTime Z=on|off Z1 is on Z0 is off
// M911.3 Pn S3 Zn setDoubleEdge Z=on|off Z1 is on Z0 is off
// M911.3 Pn S4 Zn setStepInterpolation Z=on|off Z1 is on Z0 is off
// M911.3 Pn S5 Zn setCoolStepEnabled Z=on|off Z1 is on Z0 is off

// translate command to gcode equivalent
String inputBuffer;
int direction = 0;
int targetSpeed = 100; // steps/sec

int chopperMode = 0; //0 for spread, 1 for constant off
int t_off = 2;
int t_blank = 2;
int h_start = 8;
int h_end = 6;
int h_decrement = 0;

int sgThreshold = 4;
int sgFilter = 0;

int lower_SG_threshold = 0;
int upper_SG_threshold = 0;
int number_of_SG_readings = 0;
int current_increment_step_size = 0;
int lower_current_limit = 0;

void executeSerialCommand(String cmd)
{

    inputBuffer = cmd;

    //simple run & stop commands
    switch(inputBuffer.charAt(0)) {
        case 'r':
            // start motor
            send("M1910 X" + 2000000000 * direction + " F" + targetSpeed);
            break;
        case 's':
            // stop motor
            send("M1910.1");
            break;
        case 'S': {
            targetSpeed = decode(1); // revs/min
            targetSpeed = targetSpeed * (200 * microstepping) / 60; // convert to steps/sec
            send("M1910.1");
            send("M1910 X" + 2000000000 * direction + " F" + targetSpeed);
        }
        break;
        case 'm': {
            microstepping = decode(1);
            send("M909 A" + microstepping);
        }
        break;
        case 't': {
            int threshold = decode(1);
            send("M911.3 P1 O" + threshold);
            // setStallGuardThreshold
        }
        break;
        case 'f': {
            int filter = decode(1);
            send("M911.3 P1 Q" + filter);
            // setStallGuardFilter(filter);
        }
        break;
        case 'd': {
            int value = decode(1);
            if (value < 0) {
                direction = -1;
            } else {
                direction = 1;
            }
        }
        break;
        case 'c': {
            int current = decode(1);
            send("M906 A" + current);
        }
        break;
        case 'e': {
            int enabled = decode(1);
            if (enabled == 1) {
                send("M17");
            } else {
                send("M18");
            }
        }
        break;
        case 'C':
            switch(inputBuffer.charAt(1)) {
                case 'o': {
                    int value = decode(2);
                    if (value > 0 && value < 16) {
                        t_off = value;
                        updateChopper();
                    }
                }
                break;
                case 'b': {
                    int value = decode(2);
                    if (value >= 0 && value <= 3) {
                        t_blank = value;
                        updateChopper();
                    }
                }
                break;
                case 's': {
                    int value = decode(2);
                    if (value >= 0 && value <= 8) {
                        h_start = value;
                        updateChopper();
                    }
                }
                break;
                case 'e': {
                    int value = decode(2);
                    if (value >= -3 && value <= 12) {
                        h_end = value;
                        updateChopper();
                    }
                }
                break;
                case 'd': {
                    int value = decode(2);
                    if (value >= 0 && value <= 3) {
                        h_decrement = value;
                        updateChopper();
                    }
                }
                break;
            }
            break;
        case 'K':
            switch(inputBuffer.charAt(1)) {
                case '+':
                    send("M911.3 P1 S5 Z1");
                    //tmc26XStepper.setCoolStepEnabled(true);
                    break;
                case '-':
                    send("M911.3 P1 S5 Z0");
                    //tmc26XStepper.setCoolStepEnabled(false);
                    break;
                case 'l': {
                    int value = decode(2);
                    if (value >= 0 && value < 480) {
                        lower_SG_threshold = value;
                        updateCoolStep();
                    }
                }
                break;
                case 'u': {
                    int value = decode(2);
                    if (value >= 0 && value < 480) {
                        upper_SG_threshold = value;
                        updateCoolStep();
                    }
                }
                break;
                case 'n': {
                    int value = decode(2);
                    if (value >= 0 && value < 4) {
                        number_of_SG_readings = value;
                        updateCoolStep();
                    }
                }
                break;
                case 'i': {
                    int value = decode(2);
                    if (value >= 0 && value < 4) {
                        current_increment_step_size = value;
                        updateCoolStep();
                    }
                }
                break;
                case 'm': {
                    int value = decode(2);
                    if (value >= 0 && value < 2) {
                        lower_current_limit = value;
                        updateCoolStep();
                    }
                }
                break;
            }
            break;
    }
}

int decode(int startPosition)
{
    int result = 0;
    boolean negative = false;
    if (inputBuffer.charAt(startPosition) == '-') {
        negative = true;
        startPosition++;
    }
    for (int i = startPosition; i < inputBuffer.length() && inputBuffer.charAt(i) != 0; i++) {
        int number = inputBuffer.charAt(i);
        //this very dumb approac can lead to errors, but we expect only numbers after the command anyway
        if (number <= '9' && number >= '0') {
            result *= 10;
            result += number - '0';
        }
    }
    if (negative) {
        return -result;
    } else {
        return result;
    }
}

void updateChopper()
{
    send("M911.3 P1 S1 U" + t_off + " V" + t_blank + " W" + h_start + " X" + h_end + " Y" + h_decrement);
}

void updateCoolStep()
{
    send("M911.3 P1 H" + lower_SG_threshold + " I" + upper_SG_threshold + " J" + number_of_SG_readings + " K" + current_increment_step_size + " L" + lower_current_limit);
}

void send(String s)
{
    if (motor_connected) {
        arduinoPort.write(s + "\n");
    }
    println("gcode: " + s);
}