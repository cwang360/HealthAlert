
//import libraries/header files for ML
#include <TensorFlowLite.h>
#include <tensorflow/lite/micro/all_ops_resolver.h>
#include <tensorflow/lite/micro/micro_error_reporter.h>
#include <tensorflow/lite/micro/micro_interpreter.h>
#include <tensorflow/lite/schema/schema_generated.h>
#include <tensorflow/lite/version.h>

#include <Arduino_LSM9DS1.h> //IMU library
#include <ArduinoBLE.h> //bluetooth library
#include <Arduino_HTS221.h> //temperature and humidity sensor library

#include "model.h" //trained model for classifying tremors

const int UPDATE_FREQUENCY = 2000;
long previousMillis = 0;

const float accelerationThreshold = 2.5; // threshold of significant in G's
const int numSamples = 119;

int samplesRead = numSamples;
int tremorCount = 0;
int totalCount = 0;

//Fall detection
const float movementThreshold = 1.6; // threshold for movement
const float fallAcceleration = 3.0; //falling threshold
int fallTime = 0;
bool fell = false;
bool danger = false;

//buzzer pin
int buzzer = 4;

// global variables used for TensorFlow Lite (Micro)
tflite::MicroErrorReporter tflErrorReporter;

// pull in all the TFLM ops, you can remove this line and
// only pull in the TFLM ops you need, if would like to reduce
// the compiled size of the sketch.
tflite::AllOpsResolver tflOpsResolver;

const tflite::Model* tflModel = nullptr;
tflite::MicroInterpreter* tflInterpreter = nullptr;
TfLiteTensor* tflInputTensor = nullptr;
TfLiteTensor* tflOutputTensor = nullptr;

// Create a static memory buffer for TFLM, the size may need to
// be adjusted based on the model you are using
constexpr int tensorArenaSize = 8 * 1024;
byte tensorArena[tensorArenaSize];

// array to map gesture index to a name
const char* GESTURES[] = {
  "tremor",
  "noise"
};

float results[] = {
  0,
  0
};

#define NUM_GESTURES (sizeof(GESTURES) / sizeof(GESTURES[0]))

/***********************BLE************************************/

BLEService tempService("181A"); // create service
// create characteristic and allow remote device to read and write
BLEIntCharacteristic tempCharacteristic("2A6E",  BLERead | BLENotify);
// create characteristic and allow remote device to get notifications and read the value
BLEIntCharacteristic humidityCharacteristic("2A6F",  BLERead | BLENotify);

BLEService imuService("281A"); // create service
// create characteristic and allow remote device to read and write
BLEIntCharacteristic fallCharacteristic("4A6E",  BLERead | BLENotify);
// create characteristic and allow remote device to get notifications and read the value
BLEIntCharacteristic tremorCharacteristic("4A6F", BLERead | BLENotify);

/*
GREEN A2
YELLOW A1
RED A0
*/

void setup() {
  Serial.begin(9600);
  while (!Serial);

  
  pinMode(buzzer, OUTPUT); //buzzer

  //LEDs
  pinMode(A0, OUTPUT);
  pinMode(A1, OUTPUT);
  pinMode(A2, OUTPUT);

  //push button control
  pinMode(3, INPUT);

  digitalWrite(A1, HIGH); //Yellow indicates setting up/initializing
  digitalWrite(A2, LOW); //green indicates bluetooth connected
  digitalWrite(A0, LOW); //red indicates problem

  // initializing
  if (!IMU.begin()) {
    Serial.println("Failed to initialize IMU!");
    digitalWrite(A0, HIGH);
    while (1);
  }
  if (!HTS.begin()) {
    Serial.println("Failed to initialize humidity temperature sensor!");
    digitalWrite(A0, HIGH);
    while (1);
  }

  if (!BLE.begin()) {
    Serial.println("starting BLE failed!");
    digitalWrite(A0, HIGH);
    while (1);
  }

  /*********************TensorFlow*******************************************/

  // print out the samples rates of the IMUs
  Serial.print("Accelerometer sample rate = ");
  Serial.print(IMU.accelerationSampleRate());
  Serial.println(" Hz");
  Serial.print("Gyroscope sample rate = ");
  Serial.print(IMU.gyroscopeSampleRate());
  Serial.println(" Hz");

  Serial.println();

  // get the TFL representation of the model byte array
  tflModel = tflite::GetModel(model);
  if (tflModel->version() != TFLITE_SCHEMA_VERSION) {
    Serial.println("Model schema mismatch!");
    while (1);
  }

  // Create an interpreter to run the model
  tflInterpreter = new tflite::MicroInterpreter(tflModel, tflOpsResolver, tensorArena, tensorArenaSize, &tflErrorReporter);

  // Allocate memory for the model's input and output tensors
  tflInterpreter->AllocateTensors();

  // Get pointers for the model's input and output tensors
  tflInputTensor = tflInterpreter->input(0);
  tflOutputTensor = tflInterpreter->output(0);


  /*******BLE**************************************************************************/
  // set the local name peripheral advertises
  BLE.setLocalName("Nano33BLESENSE");
  // set the UUID for the service this peripheral advertises:
  BLE.setAdvertisedService(tempService);

  // add the characteristics to the service
  tempService.addCharacteristic(tempCharacteristic);
  tempService.addCharacteristic(humidityCharacteristic);

  // add the service
  BLE.addService(tempService);

  tempCharacteristic.writeValue(0);
  humidityCharacteristic.writeValue(0);

    // set the UUID for the service this peripheral advertises:
  BLE.setAdvertisedService(imuService);

  // add the characteristics to the service
  imuService.addCharacteristic(fallCharacteristic);
  imuService.addCharacteristic(tremorCharacteristic);

  // add the service
  BLE.addService(imuService);

  fallCharacteristic.writeValue(0);
  tremorCharacteristic.writeValue(0);
  
  // start advertising
  BLE.advertise();

  Serial.println("Bluetooth device active, waiting for connections...");
}

void loop() {

    BLEDevice central = BLE.central();  // Wait for a BLE central to connect

  // If central is connected to peripheral
  if (central) {
    Serial.println("Central connected");
    digitalWrite(A1, LOW);
    digitalWrite(A2, HIGH);
    while (central.connected()) {
      fallDetection();
      long currentMillis = millis();
      // Check temperature & humidity with UPDATE_FREQUENCY
      if (currentMillis - previousMillis >= UPDATE_FREQUENCY) {
        previousMillis = currentMillis;
        int temperature = (int) HTS.readTemperature();
        int humidity = (int) HTS.readHumidity();
        tempCharacteristic.writeValue(temperature);
        humidityCharacteristic.writeValue(humidity);
        fallCharacteristic.writeValue(danger);
        
        /*******************Tremor checking *****************************************/
          float aX, aY, aZ, gX, gY, gZ;
          if(tremorCount>0){
            totalCount += 1;
            if(totalCount == 6 && tremorCount >=3){
              tremorCharacteristic.writeValue(1);
              Serial.println("SEIZURE WARNING");
              buzzerAlert();
            }
          }
          // wait for significant motion
          while (samplesRead == numSamples) {
            if (IMU.accelerationAvailable()) {
              // read the acceleration data
              IMU.readAcceleration(aX, aY, aZ);
        
              // sum up the absolutes
              float aSum = fabs(aX) + fabs(aY) + fabs(aZ);
        
              // check if it's above the threshold
              if (aSum >= accelerationThreshold) {
                // reset the sample read count
                samplesRead = 0;
                break;
              }
            }
          }
        
          // check if the all the required samples have been read since
          // the last time the significant motion was detected
          while (samplesRead < numSamples) {
            // check if new acceleration AND gyroscope data is available
            if (IMU.accelerationAvailable() && IMU.gyroscopeAvailable()) {
              // read the acceleration and gyroscope data
              IMU.readAcceleration(aX, aY, aZ);
              IMU.readGyroscope(gX, gY, gZ);
        
              // normalize the IMU data between 0 to 1 and store in the model's
              // input tensor
              tflInputTensor->data.f[samplesRead * 6 + 0] = (aX + 4.0) / 8.0;
              tflInputTensor->data.f[samplesRead * 6 + 1] = (aY + 4.0) / 8.0;
              tflInputTensor->data.f[samplesRead * 6 + 2] = (aZ + 4.0) / 8.0;
              tflInputTensor->data.f[samplesRead * 6 + 3] = (gX + 2000.0) / 4000.0;
              tflInputTensor->data.f[samplesRead * 6 + 4] = (gY + 2000.0) / 4000.0;
              tflInputTensor->data.f[samplesRead * 6 + 5] = (gZ + 2000.0) / 4000.0;
        
              samplesRead++;
        
              if (samplesRead == numSamples) {
                // Run inferencing
                TfLiteStatus invokeStatus = tflInterpreter->Invoke();
                if (invokeStatus != kTfLiteOk) {
                  Serial.println("Invoke failed!");
                  while (1);
                  return;
                }
        
                // Loop through the output tensor values from the model
                for (int i = 0; i < NUM_GESTURES; i++) {
                  Serial.print(GESTURES[i]);
                  Serial.print(": ");
                  results[i] = tflOutputTensor->data.f[i];
                  Serial.println(tflOutputTensor->data.f[i], 6);
                }
                if(results[0]>results[1]){
                  Serial.println("Tremor Alert");
                  tremorCount += 1;
                }
                Serial.println();
              }
            }
          }

        /*******************End Tremor Checking **************************************/
      }
    }
    Serial.println("Central disconnected");
    digitalWrite(A2, LOW);
    digitalWrite(A1, HIGH);
  }
}

/*************Helper Functions *********************************************/

void fallDetection(){
    float aX, aY, aZ, gX, gY, gZ;

  // wait for significant motion
    if (IMU.accelerationAvailable()) {
      // read the acceleration data
      IMU.readAcceleration(aX, aY, aZ);

      // sum up the absolutes
      float aSum = fabs(aX) + fabs(aY) + fabs(aZ);

      if (aSum >= fallAcceleration){
        Serial.println(fallTime);
        fallTime += 1;
      }else{
        fallTime = 0;
      }
      if (fallTime>10){
        Serial.println("Fall");
        fell = true; 
      }
      if(fell && fallTime == 0){
        for(int i = 0; i<20; i++){
          delay(500);
          digitalWrite(buzzer,HIGH);
          delay(100);
          digitalWrite(buzzer,LOW);
          Serial.println(danger);
          // read the acceleration data
          IMU.readAcceleration(aX, aY, aZ);
          // sum up the absolutes
          float aSum2 = fabs(aX) + fabs(aY) + fabs(aZ);
          if(aSum2 >= movementThreshold){//movement
            //Serial.println(aSum2);
            danger = false;
            break;
          }
          danger = true;
        }
        fell = false;
        if(danger){
          Serial.println("DANGER");
          fallCharacteristic.writeValue(danger);
          buzzerAlert();
        }
      }
     
    }
}

void buzzerAlert(){
  while(digitalRead(3) != 1){//while button not pushed
   
        //output an frequency
  
    for(int i=0;i<200;i++){
      digitalWrite(buzzer,HIGH);
      delay(1);
      digitalWrite(buzzer,LOW);
      delay(1);
    }
    
    //output another frequency
    
    for(int i=0;i<100;i++){
      digitalWrite(buzzer,HIGH);
      delay(2);
      digitalWrite(buzzer,LOW);
      delay(2);
    }
  }
  danger = false;
  totalCount = 0;
  tremorCount = 0;
    

}
